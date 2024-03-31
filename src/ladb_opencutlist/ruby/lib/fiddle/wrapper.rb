module Ladb::OpenCutList

  module Fiddle
  end

end

module Ladb::OpenCutList::Fiddle

  require 'fiddle'
  require 'fiddle/import'

  module Wrapper
    include Fiddle::Importer

    @lib_loaded = false

    def loaded?
      @lib_loaded
    end

    def available?
      _load_lib
      loaded?
    end

    def reload
      return unless @lib_loaded
      @lib_loaded = false
      @handler.handlers.each {|h| h.close unless h.close_enabled? } unless @handler.nil?
      GC.start
      _load_lib
    end

    protected

    def _lib_name
      'NoName'
    end

    def _lib_c_functions
      []
    end

    def _load_lib
      return if @lib_loaded

      begin

        case Sketchup.platform
        when :platform_osx
          lib_dir = File.join(Ladb::OpenCutList::PLUGIN_DIR,'bin', 'osx', 'lib')
          lib_file = "lib#{_lib_name}.dylib"
        when :platform_win
          lib_dir = File.join(Ladb::OpenCutList::PLUGIN_DIR,'bin', 'win', 'lib')
          lib_file = "#{_lib_name}.dll"
        else
          raise "Invalid platform : #{Sketchup.platform}"
        end

        lib_path = File.join(lib_dir, lib_file)

        raise "'#{_lib_name}' lib not found : #{lib_path}" unless File.exist?(lib_path)

        begin

          # Load lib (from default extension path)
          dlload(lib_path)

        rescue Fiddle::DLError => e

          # Fiddle lib loader seems to have troubles with non-ASCII encoded path :(
          # Workaround : Try to copy and load lib file from temp folder

          tmp_lib_path = File.join(Dir.tmpdir, lib_file)

          # Copy lib
          FileUtils.copy_file(lib_path, tmp_lib_path)

          # Load lib
          dlload(tmp_lib_path)

        end

        # Keep simple C syntax (without var names and void in args) to stay compatible with SketchUp 2017
        _lib_c_functions.each do |function|
          extern function
        end

        @lib_loaded = true

      rescue Exception => e
        Ladb::OpenCutList::PLUGIN.dump_exception(e, true, Sketchup.platform == :platform_win ? "To resolve this issue, try installing the Microsoft Visual C++ Redistributable available here :\nhttps://aka.ms/vs/17/release/vc_redist.x64.exe" : nil)
        @lib_loaded = false
      end

    end

end

end
