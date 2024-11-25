module Ladb::OpenCutList

  require_relative '../../utils/string_utils'

  class Size2d

    attr_reader :length, :width

    def initialize(length = 0, width = 0)
      if length.is_a?(String)    # String representation of a size "LxL"
        s_length, s_width = StringUtils.split_dxd(length)
        length = s_length.to_l
        width = s_width.to_l
      elsif length.is_a?(Array) && length.length >= 2  # Array(2) of inch float
        f_length, f_width = length
        length = f_length.to_l
        width = f_width.to_l
      end
      @length = length.to_l
      @width = width.to_l
    end

    # -----

    def increment_length(inc)
      @length += inc
      @length = @length.to_l
    end

    def increment_width(inc)
      @width += inc
      @width = @width.to_l
    end

    # -----

    def area
      @length * @width
    end

    # -----

    def ==(o)
      o.class == self.class && o.length == @length && o.width == @width
    end

  end

end

