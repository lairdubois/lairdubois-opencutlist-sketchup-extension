module Ladb::OpenCutList

  class Size2d

    attr_accessor :length, :width

    def initialize(length = 0, width = 0)
      if length.is_a? String
        a = length.split('x')
        if a.length == 2
          @length = a[0].strip.to_l
          @width = a[1].strip.to_l
        else
          @length = 0
          @width = 0
        end
      else
        @length = length
        @width = width
      end
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
