# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking2D
  #
  # Implements storage for guillotine cuts.
  #
  class Cut < Packing2D
    # Starting position of this Cut and its length.
    attr_reader :x_pos, :y_pos, :length

    # Direction of this guillotine Cut (see Packing2D).
    attr_reader :is_horizontal

    # Is this a top level through Cut?
    attr_reader :is_through

    # Level of the Cut.
    attr_reader :level

    # True if this Cut is the final bounding box Cut.
    attr_reader :is_final

    #
    # Initializes a new Cut.
    #
    def initialize(x, y, length, horizontal, level)
      super(nil)
      @x_pos = x
      @y_pos = y
      @length = length
      @is_horizontal = horizontal
      @is_through = false
      @is_final = false
      @level = level
    end

    #
    # Sets a new length for this Cut. Used by bounding box.
    #
    def update_length(length)
      @length = length
    end

    #
    # Returns true if this Cut is valid.
    #
    def valid?
      @length > 0
    end

    #
    # Marks this Cut as a through Cut (top level).
    #
    def mark_through
      @is_through = true
    end

    #
    # Marks this Cut as the final bounding box Cut (outermost two cuts).
    #
    def mark_final
      @is_through = true
      @is_final = true
    end

    #
    # Resizes this Cut to the bounding box and
    # returns true if the Cut is inside of it.
    #
    def resize_to(max_x, max_y)
      # Starting point of the cut is well inside of the bounding box
      return false unless @x_pos < max_x && @y_pos < max_y

      if @is_horizontal && @x_pos + @length > max_x
        update_length(max_x - @x_pos)
      elsif !@is_horizontal && @y_pos + @length > max_y
        update_length(max_y - @y_pos)
      end
      valid?
    end

    #
    # Debugging!
    #
    def to_str
      dir = @is_horizontal ? 'H' : 'V'
      s = "cut : #{format('%5d', object_id)} [#{format('%9.2f', @x_pos)}, "
      s += "#{format('%9.2f', @y_pos)}, #{format('%9.2f', @length)}], "
      s + "#{dir}, #{format('%3d', @level)}, #{@is_through}, #{@is_final}]"
    end
  end
end
