module Ladb::OpenCutList

  require 'fileutils'
  require 'zlib'

  # Installs a downloaded RBZ over the installed extension (self-updater).
  #
  # Sketchup.install_from_archive overwrites files but never removes stale ones :
  # the installed files are moved aside first, then put back if the install fails
  # or leaves an incomplete extension on disk. The previous version is deleted only
  # once the new one is in place.
  #
  # Every step is appended to a log file kept outside the extension folder (wiped
  # by native updates), to diagnose the upgrades that fail on users' computers.
  #
  # Install is pure Ruby apart from the installer block (Sketchup.install_from_archive
  # by default) : testable outside SketchUp, see test/TC_Ladb_Updater.rb.
  # Download goes through Sketchup::Http : see test/live/upgrade_harness.rb.
  class Updater

    BACKUP_SUFFIX = '.upgrade_backup'.freeze

    PROGRESS_STEPS = 5

    IDLE_TIMEOUT = 30   # Seconds without receiving data before giving up a download

    LOG_MAX_SIZE = 256 * 1024   # Bytes, the oldest half is dropped beyond

    class Error < StandardError; end
    class DownloadError < Error; end
    class InvalidArchiveError < Error; end
    class IncompleteInstallError < Error; end

    # Lines describing what happened, to dump in the console
    attr_reader :log, :log_file

    # plugin_dir : the installed extension folder (<Plugins>/<plugin_id>), next to its registrar
    # backup : false to leave the installed files in place (run from the sources)
    # log_file : file the log lines are appended to (nil = memory only)
    # expected_build : EXTENSION_BUILD the archive must hold (the manifest's), nil = not checked
    def initialize(plugin_dir, backup: true, log_file: nil, expected_build: nil, &installer)
      @plugin_dir = plugin_dir
      @plugin_id = File.basename(plugin_dir)
      @backup = backup
      @log_file = log_file
      @expected_build = expected_build.nil? || expected_build.to_s.empty? ? nil : expected_build.to_s
      @installer = installer || lambda { |rbz_file| Sketchup.install_from_archive(rbz_file) }
      @log = []
      @request = nil
    end

    # Writes a header line (versions, platform…) opening a new upgrade attempt in the log
    def log_context(context)
      _log("=== #{context.map { |k, v| "#{k}=#{v}" }.join(' ')}")
    end

    # -- Download --

    # Raises DownloadError unless the HTTP response can hold an archive
    def self.check_response(status_code, body)
      raise DownloadError, "HTTP status #{status_code}" unless status_code == 200
      raise DownloadError, 'Empty response' if body.nil? || body.empty?
    end

    # Returns the 0..PROGRESS_STEPS step reached, 0 while the total size is unknown (no Content-Length)
    def self.progress_step(current, total)
      return 0 unless total.is_a?(Numeric) && total > 0
      [ current * PROGRESS_STEPS / total, PROGRESS_STEPS ].min
    end

    # Downloads then installs the RBZ. Asynchronous : on_done is called once, with
    # nil on success, or the exception that stopped the upgrade (Interrupt when the
    # user cancels, DownloadError when no data came for idle_timeout seconds).
    # on_progress is called with (current, total) at each progress step.
    # Keep a reference to the installer until on_done : it holds the request, and a
    # request no longer referenced can be garbage collected before the download ends.
    def download_and_install(url, downloads_dir, on_progress: nil, idle_timeout: IDLE_TIMEOUT, &on_done)
      _log("Download #{url}")
      started = Time.now
      last_activity = Time.now
      last_step = 0
      received = nil
      last_total = nil
      finished = false

      # Sketchup::Http never times out : a stalled transfer would keep the upgrade pending forever
      @watchdog = UI.start_timer(1, true) {
        next if finished || Time.now - last_activity < idle_timeout
        finished = true
        _log("No data received for #{idle_timeout} s (#{received.nil? ? 'nothing' : "#{received} of #{last_total.inspect} bytes"} received after #{(Time.now - started).round(1)} s)")
        cancel
        on_done.call(DownloadError.new("No data received for #{idle_timeout} s"))
      }

      @request = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
      @request.set_download_progress_callback do |current, total|
        last_activity = Time.now
        received = current
        last_total = total
        step = self.class.progress_step(current, total)
        if step > last_step
          last_step = step
          on_progress.call(current, total) unless on_progress.nil?
        end
      end
      @request.start do |_request, response|
        if finished
          _log("Late response ignored (HTTP #{response.status_code})")
          next
        end
        finished = true
        _stop_watchdog
        @request = nil
        _log("Downloaded in #{(Time.now - started).round(1)} s")

        # Leave the request callback before installing
        # (timer with modal bug workaround https://ruby.sketchup.com/UI.html#start_timer-class_method)
        timer_running = false
        UI.start_timer(0, false) {
          next if timer_running
          timer_running = true
          on_done.call(install_response(response, downloads_dir, last_total))
        }

      end
    end

    # Cancels a running download (on_done is not called)
    def cancel
      _stop_watchdog
      return if @request.nil?
      @request.cancel
      @request = nil
      _log('Download cancelled')
    end

    # Returns nil once installed, or the exception that stopped it
    def install_response(response, downloads_dir, announced_size = nil)
      rbz_file = nil
      body = response.body
      _log("Response : HTTP #{response.status_code}, #{body.nil? ? 0 : body.bytesize} bytes received, #{announced_size.inspect} announced")
      self.class.check_response(response.status_code, body)
      FileUtils.mkdir_p(downloads_dir)
      rbz_file = File.join(downloads_dir, "#{@plugin_id}.rbz")
      File.open(rbz_file, 'wb') { |f| f.write(body) }
      install(rbz_file)
      nil
    rescue Exception => e
      _log("Upgrade stopped (#{e.class}: #{e.message})")
      e
    ensure
      # An antivirus may still lock the fresh download : temp dir is cleaned at next start anyway
      begin
        File.unlink(rbz_file) if !rbz_file.nil? && File.exist?(rbz_file)
      rescue => e
        _log("Unable to remove the downloaded archive (#{e.message})")
      end
    end

    # -- Install --

    # Returns normally only when the new version is on disk. On failure, the
    # previous version is put back and the exception raised again (Interrupt
    # when the user cancels the install).
    def install(rbz_file)
      check_archive(rbz_file)
      _log('Archive checked')
      backup_dir = backup_installed_files
      begin
        result = @installer.call(rbz_file)
        raise IncompleteInstallError, 'Install refused by SketchUp' if result == false
        raise IncompleteInstallError, 'Extension files missing after install' unless installed?
      rescue Exception => e
        _log("Install failed (#{e.class}: #{e.message}), #{backup_dir.nil? ? 'no backup to restore' : 'restoring the previous version'}")
        restore_installed_files(backup_dir)
        raise
      end
      _log('Installed')
      discard_backup
      true
    end

    # Raises InvalidArchiveError unless the archive holds the extension, every entry
    # matches its size and CRC (truncated or altered download), and it holds the
    # expected build (stale cache, wrong channel, manifest published before the archive).
    # The build is read from the archive rather than hashed : the RBZ is signed after
    # the build, so its final hash can't go into the manifest.
    def check_archive(rbz_file)
      require_relative '../lib/rubyzip/zip'
      Zip::File.open(rbz_file) do |zip_file|
        [ "#{@plugin_id}.rb", "#{@plugin_id}/ruby/plugin.rb" ].each do |name|
          raise InvalidArchiveError, "Not an #{@plugin_id} archive (#{name} missing)" if zip_file.find_entry(name).nil?
        end
        zip_file.each do |entry|
          next unless entry.file?
          data = zip_file.read(entry)
          raise InvalidArchiveError, "Corrupted archive (#{entry.name})" unless data.bytesize == entry.size && Zlib.crc32(data) == entry.crc
        end
        unless @expected_build.nil?
          build = self.class.read_build(zip_file, @plugin_id)
          raise InvalidArchiveError, "Unexpected build #{build || 'none'} (expected #{@expected_build})" unless build == @expected_build
        end
      end
      true
    rescue InvalidArchiveError
      raise
    rescue Exception => e  # Zip, Zlib or IO errors
      raise InvalidArchiveError, "Invalid archive (#{e.message})"
    end

    # Returns the EXTENSION_BUILD written in the archive's constants.rb, or nil
    def self.read_build(zip_file, plugin_id)
      entry = zip_file.find_entry("#{plugin_id}/ruby/constants.rb")
      return nil if entry.nil?
      zip_file.read(entry).force_encoding('UTF-8')[/EXTENSION_BUILD\s*=\s*['"](\w+)['"]/, 1]
    end

    def installed?
      File.file?(registrar_path) && File.file?(File.join(@plugin_dir, 'ruby', 'plugin.rb'))
    end

    # -- Backup --

    # The registrar is copied without its '.rb' extension to keep SketchUp from loading it
    def backup_paths
      [ @plugin_dir + BACKUP_SUFFIX, registrar_path + BACKUP_SUFFIX ]
    end

    # Returns the backup dir, or nil if the installed files are left in place
    # (backup disabled, or rename refused by the system)
    def backup_installed_files
      return nil unless @backup
      backup_dir, registrar_backup = backup_paths
      discard_backup
      FileUtils.copy_file(registrar_path, registrar_backup)
      File.rename(@plugin_dir, backup_dir)
      _log('Installed files moved aside')
      backup_dir
    rescue => e
      _log("Unable to backup installed files, stale files will be kept (#{e.message})")
      nil
    end

    def restore_installed_files(backup_dir)
      return if backup_dir.nil?
      _, registrar_backup = backup_paths
      FileUtils.rm_rf(@plugin_dir) if File.exist?(@plugin_dir)
      File.rename(backup_dir, @plugin_dir)
      FileUtils.copy_file(registrar_backup, registrar_path)
      File.unlink(registrar_backup)
      _log('Previous version restored')
    rescue => e
      _log("Unable to restore the previous version (#{e.message})")
    end

    # Removes previous version files (also called at startup, after an upgrade that could not remove them)
    def discard_backup
      backup_paths.each do |path|
        next unless File.exist?(path)
        FileUtils.rm_rf(path)
        _log("Previous version files removed (#{File.basename(path)})")
      end
    rescue => e
      _log("Unable to remove previous version files (#{e.message})")
    end

    private

    def _stop_watchdog
      return if @watchdog.nil?
      UI.stop_timer(@watchdog)
      @watchdog = nil
    end

    def registrar_path
      "#{@plugin_dir}.rb"
    end

    def _log(message)
      @log << message
      _append_to_log_file(message) unless @log_file.nil?
    end

    def _append_to_log_file(message)
      FileUtils.mkdir_p(File.dirname(@log_file))
      if File.exist?(@log_file) && File.size(@log_file) > LOG_MAX_SIZE
        data = File.binread(@log_file)
        data = data[data.bytesize / 2..-1]
        data = data[(data.index("\n") || -1) + 1..-1]   # Restart on a whole line
        File.binwrite(@log_file, data)
      end
      File.open(@log_file, 'a') { |f| f.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} #{message}") }
    rescue => e
      @log << "Unable to write the log file (#{e.message})"
    end

  end

end
