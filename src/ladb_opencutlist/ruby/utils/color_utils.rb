module Ladb::OpenCutList

  class ColorUtils

    COLOR_BLACK = Sketchup::Color.new.freeze

    def self.color_relative_luminance(color)
      return 0 unless color.is_a?(Sketchup::Color)
      (0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue) / 255.0
    end

    def self.color_is_dark?(color)
      color_relative_luminance(color) <= 0.5
    end

    def self.color_darken(color, amount = 0.2)
      return color unless color.is_a?(Sketchup::Color)
      return color unless amount.is_a?(Float)
      color.blend(COLOR_BLACK, 1.0 - [ 1, [ 0, amount ].max ].min)
    end

    def self.color_visible_over_white(color, luminance_threshold = 0.6, dark_amount = 0.2)
      l = color_relative_luminance(color)
      return color if l < luminance_threshold
      amount = dark_amount * (l - luminance_threshold) / (1 - luminance_threshold)
      color_darken(color, amount)
    end

    def self.color_to_hex(color)
      return nil unless color.is_a?(Sketchup::Color)
      "#%02x%02x%02x" % [ color.red, color.green, color.blue ]
    end

  end

end

