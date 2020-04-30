module Ladb::OpenCutList

  require_relative '../../utils/string_utils'

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

    def to_s
      'Size2d(' + @length.to_l.to_s + ', ' + @width.to_l.to_s + ')'
    end

  end

end
