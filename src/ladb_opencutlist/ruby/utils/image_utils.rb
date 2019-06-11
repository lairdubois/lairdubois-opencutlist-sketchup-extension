module Ladb::OpenCutList

  require_relative '../plugin'

  class ImageUtils

    def self.rotate(in_file, angle, out_file = nil)
      self.convert(in_file, "-rotate \"#{angle}\"", out_file)
    end

    def self.colorize(in_file, color, out_file = nil)
      self.convert(in_file, "-type GrayscaleAlpha -colorize #{color.red / 2.55},#{color.green / 2.55},#{color.blue / 2.55}", out_file)
    end

    def self.modulate(in_file, colorize_deltas, out_file = nil)
      self.convert(in_file, "-set option:modulate:colorspace hsl -modulate #{colorize_deltas[1] + 100},#{colorize_deltas[2] + 100},#{colorize_deltas[0] + 100}", out_file)
    end

    # -----

    def self.convert(in_file, options, out_file = nil)

      # Force out_file to be in_file if nil
      out_file = in_file if out_file.nil?

      bin_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', 'bin'))
      case Plugin.instance.current_os

        when :MAC

          bin_dir = File.join(bin_dir, 'osx')
          convert_path = File.join(bin_dir, 'bin', 'convert')

          # Make sure it's executable before we try to run it
          File.chmod(0755, convert_path)

          # Prepend the environment variables we need
          lib_path = "DYLD_LIBRARY_PATH=\"#{File.join(bin_dir, 'lib')}\""

        when :WIN

          bin_dir = File.join(bin_dir, 'x86')
          convert_path = File.absolute_path(File.join(bin_dir, 'convert.exe'))
          lib_path = ''

        else
          raise "This platform doesn't support ImageMagick."

      end

      # Create 'convert' command
      cmd = [ lib_path, "\"#{convert_path}\"", "\"#{in_file}\"", options, "\"#{out_file}\""].join(' ')

      # System call
      system(cmd)

    end

  end

end



