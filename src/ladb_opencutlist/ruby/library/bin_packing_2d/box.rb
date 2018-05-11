module BinPacking2D
  class Box < Packing2D
    attr_accessor :length, :width, :x, :y, :index, :rotated, :number, :superbox, :sboxes, :stack_horizontal

    def initialize(length, width, number)
      @length = length
      @width = width
      @x = 0
      @y = 0
      @index = 0
      @rotated = false
      @number = number
      @sboxes = []
      @superbox = false
      @stack_horizontal = true
    end
    
    def stack_length(box, sawkerf, max)
      return false if box.width != @width
      
      if box.length + @length > max
        return false
      else
        @length += sawkerf if @length > 0
        @length += box.length
        @sboxes << box
        @superbox = true
        return true
      end
    end
    
    def stack_width(box, sawkerf, max)
      return false if box.length != @length
      
      if box.width + @width > max
        return false
      else
        @width += sawkerf if @width > 0
        @width += box.width
        @sboxes << box
        @superbox = true
        @stack_horizontal = false
        return true
      end
    end
    
    def area
      return @length * @width
    end

    def rotate
      @width, @length = [@length, @width]
      @rotated = !@rotated
      return self
    end

    def rotated?
      return @rotated
    end

    def too_large?(l, w, rotatable)
      if rotatable
        return !((@length <= l && @width <= w) || (@length <= w && @width <= l))
      end
      return !(@length <= l && @width <= w)
    end

    def print
      db ("box #{cu(@x)} #{cu(@y)} #{cu(@length)} #{cu(@width)}" + (@rotated ? " r" : ""))
    end
    
    def print_without_position
      f = '%6.0f'
      db "box #{f % @length} #{f % @width}" + (@rotated ? " r" : "")
    end

    def label
      length = cu(@length)
      width = cu(@width)
      return "#{length} x #{width}" + (@rotated ? " r" : "")
    end
    
  end
end
