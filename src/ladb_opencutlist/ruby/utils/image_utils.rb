module Ladb::OpenCutList

  require_relative '../plugin'

  class ImageUtils

    def self.exe(in_file, options, out_file = nil)

      is_mac = Plugin.instance.current_os == :MAC

      exe_dir = File.join(File.dirname(__FILE__), '/../../bin', (is_mac ? 'osx' : 'x86'))
      exe = File.join(exe_dir, (is_mac ? "bin/convert" : "convert.exe"))

      if is_mac

        # Make sure it's executable before we try to run it
        File.chmod(0755, exe)

        # Prepend the environment variables we need
        exe = "DYLD_LIBRARY_PATH=\"#{File.join(exe_dir, 'lib')}\" \"#{exe}\""

      else
        exe = "\"#{exe}\""
      end

      cmd = "#{exe} \"#{in_file}\" #{options} \"#{out_file.nil? ? in_file : out_file}\""
      system(cmd)

    end

    def self.rotate(in_file, angle, out_file = nil)
      self.exe(in_file, "-rotate \"#{angle}\"", out_file)
    end

    def self.colorize(in_file, color, out_file = nil)
      self.exe(in_file, "-colorize #{color.red / 2.55},#{color.green / 2.55},#{color.blue / 2.55}", out_file)
    end

    def self.modulate(in_file, colorize_deltas, out_file = nil)
      self.exe(in_file, "-colorize 255,0,0 -set option:modulate:colorspace hsl -modulate #{colorize_deltas[2] + 100},#{colorize_deltas[1] + 100},#{colorize_deltas[0] + 100}", out_file)
    end

  end

end



