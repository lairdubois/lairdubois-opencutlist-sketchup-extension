module Ladb::OpenCutList::BinPacking2D
  
  class Box < Packing2D

    attr_reader :length, :width, :x, :y, :rotated, :data, :sboxes, :is_superbox

    def initialize(length, width, data = nil)
      @length = length
      @width = width
      @x = 0
      @y = 0
      @rotated = false
      @data = data
      @sboxes = []
      @is_superbox = false
      @stack_is_horizontal = true
    end

    # Sets the position and the index of a box
    # called when placed in packer
    #
    def set_position(x, y)
      @x = x
      @y = y
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

    # Break up a superbox into array of contained boxes. 
    # When called, we know that we are a a superbox, no need to check
    #
    def break_up_supergroup
      boxes = []
      @sboxes.each do |box|
        boxes << box
      end
      return boxes
    end

    # Reduce the size of a supergroup. If it contains more than
    # 2 elements, remove just the last one. 
    # When called, we know that we are a a superbox, no need to check
    #
    def reduce_supergroup(saw_kerf)
      boxes = []
      if @sboxes.length() > 2
        *@sboxes, last = @sboxes
        if @stack_is_horizontal
          @length = @length - last.length - saw_kerf
        else
          @width = @width - last.width - saw_kerf
        end
        boxes.unshift(last)
        boxes.unshift(self) # we are still a valid superbox
      else
        @sboxes.each do |box|
          boxes.unshift(box)
        end
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

    # Returns if a box will fit a bin that has not yet been created
    def fits_into_bin?(length, width, trimsize, rotatable)
      (@length <= length - 2 * trimsize && @width <= width - 2 * trimsize) || (@rotatable and @length <= width - 2 * trimsize && @width <= length - 2 * trimsize)
    end
  end
end
