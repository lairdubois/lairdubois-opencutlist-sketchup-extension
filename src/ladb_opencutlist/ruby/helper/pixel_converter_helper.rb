module Ladb::OpenCutList

  module PixelConverterHelper

    @@_pixel_to_inch_factor = 7  # default : 840px = 120" ~ 3m

    def _set_pixel_to_inch_factor(factor)
      @@_pixel_to_inch_factor = factor
    end

    # Convert pixel float value to inch
    def _to_inch(pixel_value)
      pixel_value.to_f / @@_pixel_to_inch_factor
    end

    # Convert inch float value to pixel
    def _to_px(inch_value)
      inch_value.to_f * @@_pixel_to_inch_factor
    end

  end

end
