module Ladb::OpenCutList

  class Size2d

    attr_accessor :length, :width, :orig_length, :orig_width
    attr_reader :orig_length, :orig_width
    
    def initialize(length = 0, width = 0)
      if length.is_a? String
        puts "str #{length}"
        a = length.split('x')
        if a.length == 2
          @orig_length = a[0].strip
          @orig_width = a[1].strip
          puts "length #{@orig_length} width #{@orig_width}"
          @length = a[0].strip.to_l
          @width = a[1].strip.to_l
        else
          puts "just length #{length}"
          @length = 0
          @width = 0
        end
      else
        puts "number length #{length} width #{width}"
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
