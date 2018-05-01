module BinPacking2D
  class Box < Packing2D
    attr_accessor :length, :width, :x, :y, :index, :rotated, :superbox, :sboxes

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
    end

    def add(box, sawkerf, maxlength)
      if box.length + @length + sawkerf > maxlength
        return false
      else
        @length += sawkerf if @length > 0
        @length += box.length
        @sboxes << box
        @superbox = true
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
    
    def flip
      # flip is like rotated, but it does not mark the object as rotated
      @width, @length = [@length, @width]
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
      "#{length} x #{width} - #{@number}" + (@rotated ? " r" : "")
    end
  end
end
