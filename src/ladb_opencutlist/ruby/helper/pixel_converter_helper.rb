module Ladb::OpenCutList

  module PixelConverterHelper

    DEFAULT_PIXEL_TO_INCH_FACTOR = 8  # default : 960px = 120" ~ 3m -> factor = 8

    @@_pixel_to_inch_factor = DEFAULT_PIXEL_TO_INCH_FACTOR

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
