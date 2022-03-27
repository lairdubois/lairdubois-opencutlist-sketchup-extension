module Ladb::OpenCutList

  class ColorUtils

    def self.color_is_dark?(color)
      (0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue) <= 128
    end

  end

end

