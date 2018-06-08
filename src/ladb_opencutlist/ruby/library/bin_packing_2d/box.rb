module BinPacking2D
  class Box < Packing2D
  
    attr_reader :rotated, :part, :is_superbox, :sboxes, :length, :width, :x, :y, :index

    def initialize(length, width, part = nil)
      @length = length
      @width = width
      @x = 0
      @y = 0
      @index = 0
      @rotated = false
      @part = part
      @sboxes = []
      @is_superbox = false
      @stack_is_horizontal = true
    end

    def get_export
      return cmm(@x), cmm(@y), cmm(@length), cmm(@width), @rotated, @number
    end
    
    def set_position(x, y, index)
      @x = x
      @y = y
      @index = index
    end

    # Stack box horizontally. The container box is the bounding
    # box of the contained boxes in @sboxes
    #
    def stack_length(box, saw_kerf, max)
      return false if box.width != @width

      if box.length + @length > max
        return false
      else
        @length += saw_kerf if @length > 0
        @length += box.length
        @sboxes << box
        @is_superbox = true
        return true
      end
    end

    # Stack box vertically. The container box is the bounding
    # box of the contained boxes in @sboxes
    #
    def stack_width(box, saw_kerf, max)
      return false if box.length != @length

      if box.width + @width > max
        return false
      else
        @width += saw_kerf if @width > 0
        @width += box.width
        @sboxes << box
        @is_superbox = true
        @stack_is_horizontal = false
        return true
      end
    end

    # Break up a superbox into its child boxes. When called, we know that
    # it is a superbox, no need to check
    #
    def break_up_supergroup
      boxes = []
      @sboxes.each do |box|
        boxes << box
      end
      return boxes
    end

    def area
      return @length * @width
    end

    # Rotate the box, used when grain direction does not matter
    #
    def rotate
      @width, @length = [@length, @width]
      @rotated = !@rotated
      return self
    end

    # Returns if box has been rotated
    #
    def rotated?
      return @rotated
    end

    def print
      db ("box #{cu(@x)} #{cu(@y)} #{cu(@length)} #{cu(@width)}" + (@rotated ? " r" : ""))
    end

    def label
      length = cu(@length)
      width = cu(@width)
      return "#{length} x #{width}" + (@rotated ? " r" : "")
    end
  end
end
