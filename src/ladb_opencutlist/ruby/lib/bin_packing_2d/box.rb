module Ladb::OpenCutList::BinPacking2D
  
  class Box < Packing2D

    attr_reader :length, :width, :x, :y, :is_rotated, :data

    def initialize(length, width, data = nil)
      @length = length
      @width = width
      @x = 0
      @y = 0
      @is_rotated = false
      @data = data
    end

    def copy
      return self.clone
    end
    
    # Sets the position and the index of a box
    # called when placed in packer
    #
    def set_position(x, y)
      @x = x
      @y = y
    end

    def area
      return @length * @width
    end

    # Rotate the box, used when grain direction does not matter
    #
    def rotate
      @width, @length = [@length, @width]
      @is_rotated = !@is_rotated
      return self
    end

    # Returns if box has been rotated
    #
    def is_rotated?
      return @is_rotated
    end

    # Returns if a box will fit a bin that has not yet been created
    def fits_into_bin?(length, width, trimsize, rotatable)
      (@length <= length - 2 * trimsize && @width <= width - 2 * trimsize) || (@rotatable and @length <= width - 2 * trimsize && @width <= length - 2 * trimsize)
    end
    
  end
end
