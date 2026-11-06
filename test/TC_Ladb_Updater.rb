require 'testup/testcase'
require 'tmpdir'
require 'fileutils'

require_relative '../src/ladb_opencutlist/ruby/updater/updater'
require_relative '../src/ladb_opencutlist/ruby/lib/rubyzip/zip'

# The self-updater install pipeline, on a fake Plugins folder : the installer
# block stands in for Sketchup.install_from_archive. Whatever happens, the
# extension folder must hold either the previous version intact or the new
# one complete.
#
#   ruby test/headless/run.rb test/TC_Ladb_Updater.rb
class TC_Ladb_Updater < TestUp::TestCase

  Updater = Ladb::OpenCutList::Updater
  Zip = Ladb::OpenCutList::Zip

  PLUGIN_ID = 'ladb_opencutlist'
  BUILD = '202611061200'

  def setup
    @root = Dir.mktmpdir('ocl_upgrade_test')
    @plugins_dir = File.join(@root, 'Plugins')
    @plugin_dir = File.join(@plugins_dir, PLUGIN_ID)
    _write_version(@plugins_dir, 'old')
    File.write(File.join(@plugin_dir, 'stale.rb'), 'stale')   # Removed from the new version
    @rbz_file = _build_rbz('new')
  end

  def teardown
    FileUtils.rm_rf(@root) unless @root.nil?
  end

  # -- Helpers --

  # Writes the registrar + plugin.rb of a version under dir
  def _write_version(dir, version)
    FileUtils.mkdir_p(File.join(dir, PLUGIN_ID, 'ruby'))
    File.write(File.join(dir, "#{PLUGIN_ID}.rb"), "# registrar #{version}")
    File.write(File.join(dir, PLUGIN_ID, 'ruby', 'plugin.rb'), "# plugin #{version}")
  end

  def _build_rbz(version, entries = nil, compression_method: Zip::Entry::DEFLATED)
    entries ||= {
      "#{PLUGIN_ID}.rb" => "# registrar #{version}",
      "#{PLUGIN_ID}/ruby/plugin.rb" => "# plugin #{version} " + ('x' * 64),
      "#{PLUGIN_ID}/ruby/constants.rb" => "module Ladb::OpenCutList\n    EXTENSION_VERSION = '8.0.0'.freeze\n    EXTENSION_BUILD = '#{BUILD}'.freeze   ## /!\\ Auto-generated line, do not edit ##\nend\n",
    }
    @rbz_count = (@rbz_count || 0) + 1
    rbz_file = File.join(@root, "#{version}_#{@rbz_count}.rbz")
    Zip::File.open(rbz_file, create: true) do |zip_file|
      entries.each do |name, content|
        zip_file.get_output_stream(name, compression_method: compression_method) { |os| os.write(content) }
      end
    end
    rbz_file
  end

  # Unzips like install_from_archive : overwrites, never removes
  def _extract
    lambda do |rbz_file|
      Zip::File.open(rbz_file) do |zip_file|
        zip_file.each do |entry|
          next unless entry.file?
          path = File.join(@plugins_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(path))
          File.binwrite(path, zip_file.read(entry))
        end
      end
      true
    end
  end

  def _updater(backup: true, expected_build: nil, &block)
    Updater.new(@plugin_dir, backup: backup, expected_build: expected_build, &(block || _extract))
  end

  def _version_on_disk
    registrar = File.read(File.join(@plugins_dir, "#{PLUGIN_ID}.rb"))
    plugin = File.read(File.join(@plugin_dir, 'ruby', 'plugin.rb'))
    [ registrar[/registrar (\w+)/, 1], plugin[/plugin (\w+)/, 1] ]
  end

  def _assert_old_version_intact
    assert_equal([ 'old', 'old' ], _version_on_disk)
    assert(File.exist?(File.join(@plugin_dir, 'stale.rb')), 'previous version files lost')
    _assert_no_backup_left
  end

  def _assert_no_backup_left
    leftovers = Dir.children(@plugins_dir).select { |name| name.end_with?(Updater::BACKUP_SUFFIX) }
    assert(leftovers.empty?, "backup left : #{leftovers.inspect}")
  end

  # -- Download --

  def test_check_response
    Updater.check_response(200, 'PK')
    assert_raises(Updater::DownloadError) { Updater.check_response(404, '<html>Not found</html>') }
    assert_raises(Updater::DownloadError) { Updater.check_response(302, '') }
    assert_raises(Updater::DownloadError) { Updater.check_response(0, nil) }
    assert_raises(Updater::DownloadError) { Updater.check_response(200, '') }
  end

  def test_progress_step_unknown_total
    assert_equal(0, Updater.progress_step(1000, 0))
    assert_equal(0, Updater.progress_step(1000, nil))
    assert_equal(0, Updater.progress_step(1000, -1))
    assert_equal(2, Updater.progress_step(50, 100))
    assert_equal(5, Updater.progress_step(200, 100))  # More than announced
  end

  # -- Archive --

  def test_archive_html_page
    File.write(@rbz_file, '<html><body>Download page</body></html>')
    assert_raises(Updater::InvalidArchiveError) { _updater.check_archive(@rbz_file) }
  end

  def test_archive_truncated
    data = File.binread(@rbz_file)
    File.binwrite(@rbz_file, data[0, data.bytesize / 2])
    assert_raises(Updater::InvalidArchiveError) { _updater.check_archive(@rbz_file) }
  end

  def test_archive_altered_content
    rbz_file = _build_rbz('new', nil, compression_method: Zip::Entry::STORED)
    data = File.binread(rbz_file)
    index = data.index('xxxx')
    data[index] = 'y'
    File.binwrite(rbz_file, data)
    assert_raises(Updater::InvalidArchiveError) { _updater.check_archive(rbz_file) }
  end

  def test_archive_of_another_extension
    rbz_file = _build_rbz('new', { 'other_extension.rb' => '#', 'other_extension/main.rb' => '#' })
    assert_raises(Updater::InvalidArchiveError) { _updater.check_archive(rbz_file) }
  end

  def test_archive_valid
    assert(_updater.check_archive(@rbz_file))
  end

  def test_archive_expected_build
    assert(_updater(expected_build: BUILD).check_archive(@rbz_file))
    assert(_updater(expected_build: BUILD.to_i).check_archive(@rbz_file), 'build given as a JSON number')
    assert(_updater(expected_build: '').check_archive(@rbz_file), 'empty build = not checked')
  end

  def test_archive_unexpected_build
    error = assert_raises(Updater::InvalidArchiveError) { _updater(expected_build: '202601010000').check_archive(@rbz_file) }
    assert_includes(error.message, "Unexpected build #{BUILD} (expected 202601010000)")
  end

  def test_archive_build_missing
    rbz_file = _build_rbz('new', { "#{PLUGIN_ID}.rb" => '#', "#{PLUGIN_ID}/ruby/plugin.rb" => '#' })
    error = assert_raises(Updater::InvalidArchiveError) { _updater(expected_build: BUILD).check_archive(rbz_file) }
    assert_includes(error.message, 'Unexpected build none')
  end

  def test_install_unexpected_build_touches_nothing
    called = false
    updater = Updater.new(@plugin_dir, expected_build: '202601010000') { |_| called = true }
    assert_raises(Updater::InvalidArchiveError) { updater.install(@rbz_file) }
    refute(called, 'installer called on an unexpected build')
    _assert_old_version_intact
  end

  # -- Install --

  def test_install_removes_stale_files
    updater = _updater
    updater.install(@rbz_file)
    assert_equal([ 'new', 'new' ], _version_on_disk)
    refute(File.exist?(File.join(@plugin_dir, 'stale.rb')), 'stale file kept')
    _assert_no_backup_left
  end

  def test_install_invalid_archive_touches_nothing
    File.write(@rbz_file, 'garbage')
    called = false
    updater = _updater { |_| called = true }
    assert_raises(Updater::InvalidArchiveError) { updater.install(@rbz_file) }
    refute(called, 'installer called on an invalid archive')
    _assert_old_version_intact
  end

  def test_install_raising_restores
    updater = _updater { |_| raise 'Unable to unzip' }
    assert_raises(RuntimeError) { updater.install(@rbz_file) }
    _assert_old_version_intact
  end

  def test_install_cancelled_restores
    updater = _updater { |_| raise Interrupt }
    assert_raises(Interrupt) { updater.install(@rbz_file) }
    _assert_old_version_intact
  end

  def test_install_returning_false_restores
    updater = _updater { |_| false }
    assert_raises(Updater::IncompleteInstallError) { updater.install(@rbz_file) }
    _assert_old_version_intact
  end

  def test_install_leaving_nothing_restores
    updater = _updater { |_| true }  # "Succeeds" without writing a file
    assert_raises(Updater::IncompleteInstallError) { updater.install(@rbz_file) }
    _assert_old_version_intact
  end

  def test_install_partial_restores
    updater = _updater do |_|
      FileUtils.mkdir_p(@plugin_dir)
      File.write(File.join(@plugins_dir, "#{PLUGIN_ID}.rb"), '# registrar new')
      raise 'Disk full'
    end
    assert_raises(RuntimeError) { updater.install(@rbz_file) }
    _assert_old_version_intact
  end

  def test_install_without_backup_keeps_stale_files
    updater = _updater(backup: false)
    updater.install(@rbz_file)
    assert_equal([ 'new', 'new' ], _version_on_disk)
    assert(File.exist?(File.join(@plugin_dir, 'stale.rb')))
  end

  def test_install_rename_refused_keeps_stale_files
    updater = _updater
    def updater.backup_installed_files
      _log('rename refused')
      nil
    end
    updater.install(@rbz_file)
    assert_equal([ 'new', 'new' ], _version_on_disk)
    assert(File.exist?(File.join(@plugin_dir, 'stale.rb')))
  end

  # -- Response --

  Response = Struct.new(:status_code, :body)

  def test_install_response_ok
    downloads_dir = File.join(@root, 'downloads')
    error = _updater.install_response(Response.new(200, File.binread(@rbz_file)), downloads_dir, 1234)
    assert_nil(error)
    assert_equal([ 'new', 'new' ], _version_on_disk)
    assert(Dir.children(downloads_dir).empty?, 'downloaded archive kept')
  end

  def test_install_response_http_error
    updater = _updater
    error = updater.install_response(Response.new(404, '<html>Not found</html>'), File.join(@root, 'downloads'))
    assert_kind_of(Updater::DownloadError, error)
    assert_includes(updater.log.first, 'HTTP 404')
    _assert_old_version_intact
  end

  def test_install_response_cancelled
    error = _updater { |_| raise Interrupt }.install_response(Response.new(200, File.binread(@rbz_file)), File.join(@root, 'downloads'))
    assert_kind_of(Interrupt, error)
    _assert_old_version_intact
  end

  # -- Log --

  def test_log_file
    log_file = File.join(@root, 'OpenCutList', 'upgrade.log')
    updater = Updater.new(@plugin_dir, log_file: log_file, &_extract)
    updater.log_context(:from => '1.0', :sketchup => '26.2')
    updater.install(@rbz_file)
    lines = File.readlines(log_file)
    assert(lines.first =~ /\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d === from=1.0 sketchup=26.2$/, lines.first)
    assert(lines.any? { |line| line.end_with?(" Installed\n") }, lines.join)
    assert_equal(updater.log.size, lines.size)
  end

  def test_log_file_trimmed
    log_file = File.join(@root, 'upgrade.log')
    File.write(log_file, "old line\n" * (Updater::LOG_MAX_SIZE / 9 + 10))
    Updater.new(@plugin_dir, log_file: log_file).log_context(:a => 1)
    data = File.read(log_file)
    assert(data.bytesize < Updater::LOG_MAX_SIZE, "#{data.bytesize} bytes")
    assert(data.start_with?("old line\n"), 'not restarted on a whole line')
    assert(data.end_with?("=== a=1\n"))
  end

  def test_log_file_unwritable
    log_file = File.join(@rbz_file, 'upgrade.log')  # Under a file : can't be created
    updater = Updater.new(@plugin_dir, log_file: log_file, &_extract)
    updater.install(@rbz_file)
    assert_equal([ 'new', 'new' ], _version_on_disk)
  end

  def test_discard_backup_left_by_previous_upgrade
    FileUtils.mkdir_p(@plugin_dir + Updater::BACKUP_SUFFIX)
    File.write(File.join(@plugins_dir, "#{PLUGIN_ID}.rb" + Updater::BACKUP_SUFFIX), '#')
    _updater.discard_backup
    _assert_no_backup_left
  end

end
