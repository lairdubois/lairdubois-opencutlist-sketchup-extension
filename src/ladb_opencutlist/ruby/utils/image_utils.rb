module Ladb::OpenCutList

  require_relative '../plugin'

  class ImageUtils

    def self.rotate(in_file, angle, out_file = nil)
      self.convert(in_file, "-rotate \"#{angle}\"", out_file)
    end

    # -----

    def self.system_call(cmd)

      # Inspired by https://forums.sketchup.com/t/running-external-program-without-flashing-command-line/70734/8
      cmd = cmd.gsub('"', '""')

      file = Tempfile.new(["cmd", ".vbs"])
      file.write("Set WshShell = CreateObject(\"WScript.Shell\")\n")
      file.write("WshShell.Run \"#{cmd}\", 0, True\n")
      file.write("WScript.Quit\n")
      file.close

      # Should this fail, revert to old style!
      if !system("wscript.exe #{file.path}")
        system(cmd)
      end
    end

    def self.convert(in_file, options, out_file = nil)

      # Force out_file to be in_file if nil
      out_file = in_file if out_file.nil?

      bin_dir = File.join(PLUGIN_DIR,'bin')
      case Sketchup.platform

        when :platform_osx

          bin_dir = File.join(bin_dir, 'osx')
          convert_path = File.join(bin_dir, 'bin', 'convert')

          # Make sure it's executable before we try to run it
          File.chmod(0755, convert_path)

          # Prepend the environment variables we need
          lib_path = "DYLD_LIBRARY_PATH=\"#{File.join(bin_dir, 'lib')}\""

          cmd = [lib_path, "\"#{convert_path}\"", "\"#{in_file}\"", options, "\"#{out_file}\""].join(' ')
          system(cmd)

        when :platform_win

          bin_dir = File.join(bin_dir, 'win')
          convert_path = File.absolute_path(File.join(bin_dir, 'convert.exe'))

          cmd = ["\"#{convert_path}\"", "\"#{in_file}\"", options, "\"#{out_file}\""].join(' ')
          self.system_call(cmd)

        else
          raise "This platform doesn't support ImageMagick."

      end

    end

  end

end
