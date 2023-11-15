module Ladb::OpenCutList

  module PixelConverterHelper

    # Convert pixel float value to inch
    def _to_inch(pixel_value)
      pixel_value.to_f / 7 # 840px = 120" ~ 3m
    end

    # Convert inch float value to pixel
    def _to_px(inch_value)
      inch_value.to_f * 7 # 840px = 120" ~ 3m
    end

  end

end
