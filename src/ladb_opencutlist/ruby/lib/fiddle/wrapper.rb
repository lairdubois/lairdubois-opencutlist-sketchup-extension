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
    @lib_dir = nil

    def loaded?
      @lib_loaded
    end

    def available?
      _load_lib
      loaded?
    end

    def unload
      return unless @lib_loaded
      @lib_loaded = false
      @lib_dir = nil
      @handler.handlers.each { |h| h.close unless h.close_enabled? } unless @handler.nil?
      GC.start
    end

    def lib_dir
      _load_lib
      @lib_dir
    end

    protected

    def _lib_name
      'NoName'
    end

    def _lib_c_functions
      # Keep simple C syntax (without var names and void in args) to stay compatible with SketchUp 2017
      []
    end

    def _load_lib
      return if @lib_loaded

      begin

        case Sketchup.platform
        when :platform_osx
          lib_dir = File.join(Ladb::OpenCutList::PLUGIN_DIR, 'bin', 'osx', 'lib')
          lib_file = "lib#{_lib_name}.dylib"
        when :platform_win
          lib_dir = File.join(Ladb::OpenCutList::PLUGIN_DIR, 'bin', 'win', 'lib')
          lib_file = "#{_lib_name}.dll"
        else
          raise "Invalid platform : #{Sketchup.platform}"
        end

        lib_path = File.join(lib_dir, lib_file)

        raise "'#{_lib_name}' lib not found : #{lib_path}" unless File.exist?(lib_path)

        if Ladb::OpenCutList::Plugin::IS_RBZ

          # Copy lib to temp dir for 2 reasons:
          # - The system locks the file after loading. By uploading a copy, the file can still be updated.
          # - Fiddle lib loader seems to have troubles with non-ASCII encoded path :( -> temp dir is short file name compatible.

          tmp_lib_dir = File.join(Ladb::OpenCutList::PLUGIN.temp_dir, 'fiddle')
          tmp_lib_path = File.join(tmp_lib_dir, "#{Ladb::OpenCutList::EXTENSION_BUILD}_#{lib_file}")

          # Create the directory if it doesn't exist
          Dir.mkdir(tmp_lib_dir) unless Dir.exist?(tmp_lib_dir)

          # Copy lib unless it exists to avoid error if already loaded and locked by the system.)
          # A size mismatch means a previous copy was truncated (ex: interrupted by an antivirus) -> copy again.
          FileUtils.copy_file(lib_path, tmp_lib_path) unless File.exist?(tmp_lib_path) && File.size(tmp_lib_path) == File.size(lib_path)

        else

          # Load lib from SRC
          tmp_lib_path = lib_path

        end

        # Load lib
        dlload(tmp_lib_path)

        # Bind c functions
        _lib_c_functions.each do |function|
          extern function
        end

        @lib_loaded = true
        @lib_dir = lib_dir

      rescue Exception => e
        message = nil
        if Sketchup.platform == :platform_win
          error_code = tmp_lib_path.nil? ? nil : _win32_load_error_code(tmp_lib_path)
          case error_code
          when 4551 # ERROR_SYSTEM_INTEGRITY_POLICY_VIOLATION
            message = "Windows Smart App Control blocks the OpenCutList native libraries because they are not digitally signed yet.\nTo resolve this issue, turn off Smart App Control (Windows Security > App & browser control > Smart App Control settings), then restart SketchUp.\nIf this computer is managed by an organization, please contact your IT administrator."
          when 1260 # ERROR_ACCESS_DISABLED_BY_POLICY
            message = "A software restriction policy (AppLocker or SRP) of this computer blocks the OpenCutList native library '#{lib_file}'.\nTo resolve this issue, please contact your IT administrator to allow the '#{lib_dir}' and '#{File.dirname(tmp_lib_path)}' folders, then restart SketchUp."
          when 126 # ERROR_MOD_NOT_FOUND
            message = "A system dependency of the OpenCutList native library '#{lib_file}' is missing (Microsoft Visual C++ Runtime).\nTo resolve this issue, install the Microsoft Visual C++ Redistributable available here :\nhttps://aka.ms/vs/17/release/vc_redist.x64.exe\nthen restart SketchUp."
          when 225 # ERROR_VIRUS_INFECTED
            message = "Your antivirus blocks the OpenCutList native library '#{lib_file}'.\nTo resolve this issue, check your antivirus protection history, restore and allow this file (and the '#{File.dirname(tmp_lib_path)}' folder), then restart SketchUp."
          else
            message = "To resolve this issue, try installing the Microsoft Visual C++ Redistributable available here :\nhttps://aka.ms/vs/17/release/vc_redist.x64.exe"
          end
          message = "Windows error code : #{error_code}\n#{message}" unless error_code.nil?
        end
        Ladb::OpenCutList::PLUGIN.dump_exception(e, true, message)
        @lib_loaded = false
        @lib_dir = nil
      end

    end

    # Fiddle maps unknown Windows errors to EINVAL ("Invalid argument").
    # Retry with LoadLibraryW to retrieve the real error code (ex: 126 = missing dependency, 225 = antivirus, 1260 or 4551 = system policy).
    def _win32_load_error_code(lib_path)
      kernel32 = ::Fiddle.dlopen('kernel32')
      load_library = ::Fiddle::Function.new(kernel32['LoadLibraryW'], [ ::Fiddle::TYPE_VOIDP ], ::Fiddle::TYPE_VOIDP)
      handle = load_library.call((lib_path.tr('/', '\\') + "\0").encode('UTF-16LE'))
      if handle.to_i != 0
        free_library = ::Fiddle::Function.new(kernel32['FreeLibrary'], [ ::Fiddle::TYPE_VOIDP ], ::Fiddle::TYPE_INT)
        free_library.call(handle)
        return nil
      end
      ::Fiddle.win32_last_error
    rescue Exception
      nil
    end

end

end
