module Ladb::OpenCutList

  require_relative '../utils/string_utils'

  class Size2d

    attr_accessor :length, :width

    def initialize(length = 0, width = 0)
      if length.is_a? String
        s_length, s_width = StringUtils.split_dxd(length)
        length = s_length.to_l
        width = s_width.to_l
      end
      @length = length
      @width = width
    end

    # -----

    def area
      @length * @width
    end

    def area_m2
      @length.to_m * @width.to_m
    end

    # -----

    def to_s
      'Size2d(' + @length.to_l.to_s + ', ' + @width.to_l.to_s + ')'
    end

  end

end
