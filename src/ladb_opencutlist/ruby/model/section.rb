module Ladb::OpenCutList

  class Section

    attr_accessor :width, :height

    def initialize(width = 0, height = 0)
      if width.is_a? String
        a = width.split('x')
        if a.length == 2
          @width = a[0].strip.to_l
          @height = a[1].strip.to_l
        else
          @width = 0
          @height = 0
        end
      else
        @width = width
        @height = height
      end
    end

    def to_s
      @width.to_l.to_s + ' x ' + @height.to_l.to_s
    end

  end

end
