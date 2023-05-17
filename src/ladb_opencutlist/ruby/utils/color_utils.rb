module Ladb::OpenCutList

  class ColorUtils

    def self.color_is_dark?(color)
      (0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue) <= 128
    end

    def self.color_to_hex(color)
      return nil unless color.is_a?(Sketchup::Color)
      "#%02x%02x%02x" % [ color.red, color.green, color.blue ]
    end

  end

end

