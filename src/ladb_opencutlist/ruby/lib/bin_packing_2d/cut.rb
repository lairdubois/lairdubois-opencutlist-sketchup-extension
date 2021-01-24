module Ladb::OpenCutList::BinPacking2D

  #
  # Implements a guillotine cut.
  #
  class Cut < Packing2D

    # Starting position of the cut and its length.
    attr_reader :x, :y, :length

    # Direction of the guillotine cut (see Packing2D).
    attr_reader :is_horizontal

    # Is this a top level through cut?
    attr_reader :is_through
    attr_reader :level
    attr_reader :is_final

    #
    # Initializes a new Cut.
    #
    def initialize(x, y, length, horizontal, level)
      super(nil)
      @x = x
      @y = y
      @length = length
      @is_horizontal = horizontal
      @is_through = false
      @is_final = false
      @level = level
    end

    #
    # Sets a new length for this cut. Used by bounding box.
    #
    def set_length(length)
      @length = length
    end

    #
    # Sets the index of this cut. The index cannot be set
    # at creation of the cut, because it is not set by
    # leftover, but by the bin.
    #
    def UNUSED_set_index(index)
      @index = index
    end

    #
    # Returns true if this cut is valid.
    #
    def valid?
      return @length > 0
    end

    #
    # Marks this cut as a through cut (top level).
    #
    def mark_through
      @is_through = true
    end

    #
    # Marks this cut as a final bounding box cut.
    #
    def mark_final
      @is_through = true
      @is_final = true
    end

    def UNUSED_includes?(other)
      if is_horizontal
        if (@y - other.y).abs <= EPS && other.x <= @x && @length >= other.length
          return true
        end
      else
        if (@x - other.x).abs <= EPS && other.y <= @y && @length >= other.length
          return true
        end
      end
      return false
    end

    #
    # Resizes this cut to the bounding box and
    # returns true if the cut is inside of it.
    #
    def resize_to(max_x, max_y)
      # TODO rewrite this, must be a better way to resize_to!
      # Starting point of the cut is well inside of the bounding box
      if @x < max_x && @y < max_y
        if @is_horizontal && @x + @length > max_x
          set_length(max_x - @x)
        elsif !@is_horizontal && @y + @length > max_y
          set_length(max_y - @y)
        end
        return valid?
      elsif @is_horizontal && (@y - max_y).abs <= EPS
        return false
      elsif !@is_horizontal && (@x - max_x).abs <= EPS
        return false
      end
      return false
    end

    #
    # Debugging!
    #
    def to_str
      @is_horizontal ? dir = "H": dir = "V"
      return "cut : #{'%5d' % object_id} [#{'%9.2f' % @x}, #{'%9.2f' % @y}, #{'%9.2f' % @length}], #{dir}, #{'%3d' % @level}, #{@is_through}, #{@is_final}]"
    end

    def to_octave
      linewidth = 2
      if @is_horizontal
        return "line([#{@x}, #{@x + @length}], [#{@y}, #{@y}], \"color\", red, \"linewidth\", #{linewidth}) # horizontal cut"
      else
        return "line([#{@x}, #{@x}], [#{y}, #{@y + @length}], \"color\", red,  \"linewidth\", #{linewidth}) # vertical cut"
      end
    end
  end
end
