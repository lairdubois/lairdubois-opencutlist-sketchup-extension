module Ladb::OpenCutList

  require_relative '../../utils/string_utils'
  require_relative '../../utils/dimension_utils'

  class Section

    attr_reader :width, :height

    def initialize(width = 0, height = 0)
      if width.is_a?(String)
        s_width, s_height = StringUtils.split_dxd(width)
        width = s_width.to_l
        height = s_height.to_l
      elsif width.is_a?(Array) && width.length >= 2  # Array(2) of inch float
        f_width, f_height = width
        width = f_width.to_l
        height = f_height.to_l
      end
      @width = width
      @height = height
    end

    # -----

    def ==(o)
      o.class == self.class && o.width == @width && o.height == @height
    end

    # -----

    def to_ocl_precision_s
      DimensionUtils.to_ocl_precision_s(@width) + ' x ' + DimensionUtils.to_ocl_precision_s(@height)
    end

    def to_s
      @width.to_l.to_s + ' x ' + @height.to_l.to_s
    end

  end

end
