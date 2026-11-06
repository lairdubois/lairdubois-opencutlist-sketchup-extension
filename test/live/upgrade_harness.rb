# Live harness of the self-updater : runs Updater#download_and_install
# (the production code, real Sketchup::Http) against test/live/upgrade_server.rb,
# one scenario per injected fault. Installs into a fake Plugins folder under
# Sketchup.temp_dir : the installer block mimics Sketchup.install_from_archive
# (overwrites, never removes) — the real one would install into the real Plugins.
#
# 1. outside SketchUp : ruby test/live/upgrade_server.rb
# 2. in SketchUp (Ruby console or Claude Bridge) :
#      load '<repo>/test/live/upgrade_harness.rb'
#      UpgradeHarness.run                        # every scenario, ~2 min (gc_unreferenced waits for the timeout)
#      UpgradeHarness.run(only: %w[stall pause])
#      UpgradeHarness.report                     # poll until :done
#
# Asynchronous : run returns at once, scenarios are chained by the download callbacks.
module UpgradeHarness

  REPO = File.expand_path('../..', __dir__)
  PLUGIN_ID = 'ladb_opencutlist'

  require 'fileutils'
  require File.join(REPO, 'src/ladb_opencutlist/ruby/lib/rubyzip/zip')
  load File.join(REPO, 'src/ladb_opencutlist/ruby/updater/updater.rb')

  Updater = Ladb::OpenCutList::Updater
  Zip = Ladb::OpenCutList::Zip

  # scenario => expected outcome (:installed, :refused = error + previous version intact, :observe = report only)
  SCENARIOS = {
    'ok' => :installed,
    'chunked' => :installed,
    'gzip' => :installed,
    'redirect' => :installed,
    'slow' => :installed,
    'gc' => :installed,                 # slow + GC.start at each progress : the updater keeps the request alive
    'gc_unreferenced' => :observe,      # slow + GC.start, request referenced by nothing (the pre-fix code)
    'not_found' => :refused,
    'server_error' => :refused,
    'html' => :refused,
    'empty' => :refused,
    'truncated' => :refused,
    'truncated_chunked' => :refused,
    'corrupt' => :refused,
    'slow_chunked' => :installed,       # idle timeout 2 s : progress callbacks keep it alive without a total size
    'pause' => :installed,              # idle timeout 5 s, 3 s pause mid-transfer
    'stall' => :refused,                # idle timeout 5 s : the watchdog gives up
    'wrong_build' => :refused,          # the ok archive, but the manifest announces another build
  }.freeze
  DEFAULT = SCENARIOS.keys.freeze

  # Shortened idle timeouts (seconds), the others use Updater::IDLE_TIMEOUT
  IDLE_TIMEOUTS = { 'slow_chunked' => 2, 'pause' => 5, 'stall' => 5 }.freeze

  def self.run(port: 8787, only: nil, timeout: 60, rbz: File.join(REPO, 'dist', "#{PLUGIN_ID}.rbz"))
    @port = port
    @timeout = timeout
    @registrar, @build = Zip::File.open(rbz) { |zip_file| [ zip_file.read("#{PLUGIN_ID}.rb"), Updater.read_build(zip_file, PLUGIN_ID) ] }
    @queue = (only || DEFAULT).dup
    @results = []
    @current = nil
    @done = false
    UI.start_timer(0, false) { _next }
    "#{@queue.size} scenarios started"
  end

  def self.report
    lines = (@results || []).map do |r|
      "#{r[:pass] ? 'PASS' : 'FAIL'} #{r[:name].ljust(18)} #{r[:outcome].to_s.ljust(9)} #{r[:seconds].round(1).to_s.rjust(5)} s  progress=#{r[:progress]} total=#{r[:totals].uniq.first(2).inspect}  #{r[:detail]}"
    end
    lines << "... running #{@current[:name]}" unless @current.nil?
    lines << "#{@results.count { |r| r[:pass] }}/#{@results.size} passed" if @done
    { :done => @done, :report => lines.join("\n") }
  end

  def self.results
    @results
  end

  # -----

  def self._next
    name = @queue.shift
    return @done = true if name.nil?

    dir = File.join(Sketchup.temp_dir, 'ocl_upgrade_harness', name)
    FileUtils.rm_rf(dir)
    plugins_dir = File.join(dir, 'Plugins')
    plugin_dir = File.join(plugins_dir, PLUGIN_ID)
    FileUtils.mkdir_p(File.join(plugin_dir, 'ruby'))
    File.write(File.join(plugins_dir, "#{PLUGIN_ID}.rb"), '# registrar old')
    File.write(File.join(plugin_dir, 'ruby', 'plugin.rb'), '# plugin old')
    File.write(File.join(plugin_dir, 'stale.rb'), '# stale')

    path = { 'gc' => 'slow', 'gc_unreferenced' => 'slow', 'wrong_build' => 'ok' }.fetch(name, name)
    url = "http://127.0.0.1:#{@port}/#{path}?harness=1"
    @current = { :name => name, :dir => dir, :plugins_dir => plugins_dir, :started => Time.now, :progress => 0, :totals => [] }
    @watchdog = UI.start_timer(@timeout, false) { _finish(name, :timeout) }

    if name == 'gc_unreferenced'
      _start_unreferenced(name, url)
    else
      expected_build = name == 'wrong_build' ? '200001010000' : @build
      updater = Updater.new(plugin_dir, log_file: File.join(dir, 'upgrade.log'), expected_build: expected_build, &_extract(plugins_dir))
      @current[:updater] = updater
      on_progress = lambda do |_current, total|
        @current[:progress] += 1
        @current[:totals] << total
        GC.start if name == 'gc'
      end
      updater.download_and_install(url, File.join(dir, 'downloads'), on_progress: on_progress, idle_timeout: IDLE_TIMEOUTS.fetch(name, Updater::IDLE_TIMEOUT)) { |error| _finish(name, error) }
    end
  rescue Exception => e
    _finish(name, e)
  end

  # The pre-fix pattern : nothing keeps the request once start returns
  def self._start_unreferenced(name, url)
    request = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
    request.set_download_progress_callback do |_current, total|
      @current[:progress] += 1 unless @current.nil?
      @current[:totals] << total unless @current.nil?
      GC.start
    end
    request.start { |_request, response| _finish(name, :downloaded, "HTTP #{response.status_code}, #{response.body.bytesize} bytes") }
    request = nil
  end

  # Unzips like Sketchup.install_from_archive : overwrites, never removes
  def self._extract(plugins_dir)
    lambda do |rbz_file|
      Zip::File.open(rbz_file) do |zip_file|
        zip_file.each do |entry|
          next unless entry.file?
          path = File.join(plugins_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(path))
          File.open(path, 'wb') { |f| f.write(zip_file.read(entry)) }
        end
      end
      true
    end
  end

  def self._finish(name, error, detail = nil)
    return if @current.nil? || @current[:name] != name   # Late callback of a timed out scenario
    current = @current
    @current = nil
    UI.stop_timer(@watchdog) unless @watchdog.nil?
    current[:updater].cancel if error == :timeout && !current[:updater].nil?

    plugins_dir = current[:plugins_dir]
    plugin_dir = File.join(plugins_dir, PLUGIN_ID)
    registrar = File.join(plugins_dir, "#{PLUGIN_ID}.rb")
    registrar_content = File.exist?(registrar) ? File.binread(registrar) : nil
    stale = File.exist?(File.join(plugin_dir, 'stale.rb'))
    leftovers = Dir.children(plugins_dir).select { |n| n.end_with?(Updater::BACKUP_SUFFIX) }
    is_new = registrar_content == @registrar && !stale && File.file?(File.join(plugin_dir, 'ruby', 'plugin.rb')) && leftovers.empty?
    is_old = registrar_content == '# registrar old' && stale && leftovers.empty?

    outcome = case error
              when nil then :installed
              when Symbol then error
              else :refused
              end
    expected = SCENARIOS[name]
    pass = case expected
           when :installed then outcome == :installed && is_new
           when :refused then outcome == :refused && is_old
           else true
           end
    detail ||= error.is_a?(Exception) ? "#{error.class.name.split('::').last}: #{error.message}" : nil
    detail = "#{detail} [disk : #{is_new ? 'new' : (is_old ? 'old' : 'MIXED')}]" if expected != :observe || outcome != :downloaded

    @results << {
      :name => name, :outcome => outcome, :pass => pass, :detail => detail,
      :seconds => Time.now - current[:started], :progress => current[:progress], :totals => current[:totals],
      :log => current[:updater].nil? ? [] : current[:updater].log,
    }
    UI.start_timer(0.5, false) { _next }
  end

end
