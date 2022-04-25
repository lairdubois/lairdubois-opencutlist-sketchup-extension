# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking2D
  #
  # Implements a subdivision of the bin by guillotine cuts.
  # It gives the contained box an x, y reference and the necessary
  # cuts to place the box at the top left corner.
  #
  class Leftover < Packing2D
    # Position and size of this Leftover.
    attr_reader :x_pos, :y_pos, :length, :width

    # Level of this Leftover.
    attr_reader :level

    # Keep this leftover
    attr_reader :keep

    #
    # Initializes a new Leftover.
    #
    def initialize(x, y, length, width, level, _keep, options)
      super(options)

      @x_pos = x
      @y_pos = y
      @length = length
      @width = width
      @keep = true
      @level = level
    end

    #
    # Trims the top level Leftover of a Bin. These Cut s are NOT recorded/counted.
    #
    def trim
      @x_pos += @options.trimsize
      @y_pos += @options.trimsize
      @length -= 2 * @options.trimsize
      @width -= 2 * @options.trimsize
      usable?
    end

    #
    # Resizes the Leftover such that the lower right corner is at most at
    # position max_x, max_y, may be smaller!
    #
    def resize_to(max_x, max_y)
      @length = [max_x - @x_pos, @length].min
      @width = [max_y - @y_pos, @width].min
      usable?
    end

    #
    # Returns true if this Leftover has a valid size, i.e
    # slightly larger than nothing in both dimensions.
    #
    def usable?
      @length > @options.saw_kerf && @width > @options.saw_kerf
    end

    #
    # Mark leftovers to keep on bins.
    #
    def mark_keep
      @keep = false if (@length < @options.min_length) || (@width < @options.min_width)
    end

    #
    # Returns the area of this Leftover.
    #
    def area
      @length * @width
    end

    #
    # Returns the heuristic score for placing a Box inside this Leftover
    # or MAX_INT if it does not fit.
    #
    def heuristic_score(box_length, box_width)
      # First test ensures that box will fit into leftover.
      if @length - box_length >= -EPS && @width - box_width >= -EPS
        case @options.score
        when SCORE_BESTAREA_FIT
          # Returns the amount of waste produced, smaller is better
          (box_length * box_width) - (@length * @width)
        when SCORE_BESTSHORTSIDE_FIT
          # Returns the smallest difference in one dimension.
          [(box_length - @length).abs, (box_width - @width).abs].min
        when SCORE_BESTLONGSIDE_FIT
          # Returns the largest difference in one dimension.
          [(box_length - @length).abs, (box_width - @width).abs].max
        when SCORE_WORSTAREA_FIT
          -((box_length * box_width) - (@length * @width))
        when SCORE_BESTWIDTH_FIT
          (box_width - @width).abs
        when SCORE_BESTLENGTH_FIT
          (box_length - @length).abs
        else
          MAX_INT
        end
      else
        MAX_INT
      end
    end

    #
    # Adapted score for box using selected heuristic.
    #
    def score(leftover_index, box)
      s = []
      s1 = heuristic_score(box.length, box.width)
      if s1 < MAX_INT
        # Make score lower if one of the dimensions matches with a preference to length.
        # TODO: leftover.score: check if matching should be aligned with shape of bin.
        s1 = -MAX_INT if (@length - box.length).abs <= EPS || (@width - box.width).abs <= EPS
        s << [leftover_index, s1, NOT_ROTATED, @level]
      end
      if box.rotatable
        s2 = heuristic_score(box.width, box.length)
        if s2 < MAX_INT
          s2 = -MAX_INT if (@length - box.width).abs <= EPS || (@width - box.length).abs <= EPS
          s << [leftover_index, s2, ROTATED, @level]
        end
      end
      s
    end

    #
    # Returns true if order of guillotine Cut is horizontal, then vertical,
    # false otherwise.
    #
    def split_horizontally_first?(box)
      #
      # When stacking is on, one would be tempted to always do the first cut
      # in the direction of stacking, always!
      # Does not work well in practice!
      #
      case @options.split
      when SPLIT_SHORTERLEFTOVER_AXIS
        @length - box.length <= @width - box.width
      when SPLIT_LONGERLEFTOVER_AXIS
        @length - box.length > @width - box.width
      when SPLIT_MINIMIZE_AREA
        @length * (@width - box.width) <= @width * (@length - box.length)
      when SPLIT_MAXIMIZE_AREA
        @length * (@width - box.width) > @width * (@length - box.length)
      when SPLIT_SHORTER_AXIS
        box.length < box.width
      when SPLIT_LONGER_AXIS
        box.length >= box.width
      when SPLIT_HORIZONTAL_FIRST
        true
      when SPLIT_VERTICAL_FIRST
        false
      else
        raise(Packing2DError, 'Split heuristic not implemented in bin.select_horizontal_first!')
      end
    end

    #
    # Splits this Leftover at position x, y by a vertical, then a horizontal cut.
    # x, y represents a position in absolute coordinates.
    # Returns the Leftover s and the Cut s.
    #
    def split_horizontal_first(x, y, box = nil)
      # Trying to split outside of this leftover!
      if x > @x_pos + @length + EPS || y > @y_pos + @width + EPS
        raise(Packing2DError, "Splitting outside of this leftover in split_horizontal_first! #{@options.signature}")
      end

      new_cuts = []
      new_leftovers = []

      # Horizontal cut.
      if (@y_pos + @width - y).abs >= EPS
        cf = Cut.new(@x_pos, y, @length, true, @level)
        new_cuts << cf
      end

      # Bottom leftover.
      lb = Leftover.new(@x_pos, y + @options.saw_kerf, @length, @y_pos + @width - y - @options.saw_kerf,
                        @level, true, @options)
      new_leftovers << lb

      # Vertical cut.
      if (@x_pos + @length - x).abs >= EPS
        cs = Cut.new(x, @y_pos, y - @y_pos, false, @level)
        new_cuts << cs
      end

      # Right leftover.
      lr = Leftover.new(x + @options.saw_kerf, @y_pos, @x_pos + @length - x - @options.saw_kerf, y - @y_pos,
                        @level + 1, true, @options)
      new_leftovers << lr

      # If the Box is a Superbox, unmake it!
      new_boxes, more_cuts = unmake_superbox(box)
      new_cuts += more_cuts

      [new_leftovers, new_cuts, new_boxes]
    end

    #
    # Splits this Leftover at position x, y by a vertical, then a horizontal cut.
    # Returns the leftovers, the cuts and the unpacked boxes.
    #
    def split_vertical_first(x, y, box = nil)
      if x > @x_pos + @length + EPS || y > @y_pos + @width + EPS
        puts("x = #{x}, bin x = #{@x_pos}, length = #{@length}, y = #{y}, bin y = #{@y_pos} width = #{@width}")
        raise(Packing2DError, "Splitting outside of this leftover in split_vertical_first! #{@options.signature}")
      end

      new_cuts = []
      new_leftovers = []

      # Vertical cut.
      if (@x_pos + @length - x).abs >= EPS
        cf = Cut.new(x, @y_pos, @width, false, @level)
        new_cuts << cf
      end

      # Right leftover.
      lr = Leftover.new(x + @options.saw_kerf, @y_pos, @x_pos + @length - x - @options.saw_kerf, @width,
                        @level, true, @options)
      new_leftovers << lr

      # Horizontal cut.
      if (@y_pos + @width - y).abs >= EPS
        cs = Cut.new(@x_pos, y, x - @x_pos, true, @level)
        new_cuts << cs
      end

      # Bottom leftover.
      lb = Leftover.new(@x_pos, y + @options.saw_kerf, x - @x_pos, @y_pos + @width - y - @options.saw_kerf,
                        @level + 1, true, @options)
      new_leftovers << lb

      # Unmake it if a Superbox, does nothing if box.nil?
      new_boxes, more_cuts = unmake_superbox(box)
      new_cuts += more_cuts

      [new_leftovers, new_cuts, new_boxes]
    end

    #
    # Unmakes a Superbox, adding the necessary Cut s.
    #
    def unmake_superbox(sbox)
      return [[], []] if sbox.nil?

      unpacked_boxes = []
      new_cuts = []

      if sbox.instance_of?(SuperBox)
        if sbox.sboxes.size == 1
          single_box = sbox.sboxes.shift
          single_box.set_position(sbox.x_pos, sbox.y_pos)
          unpacked_boxes << single_box
        elsif sbox.unbreakable
          unpacked_boxes << sbox
        elsif (@options.stacking == STACKING_LENGTH && !sbox.rotated) ||
              (@options.stacking == STACKING_WIDTH && sbox.rotated)
          top_box = sbox.sboxes.shift
          top_box.set_position(sbox.x_pos, sbox.y_pos)
          offset = sbox.x_pos + top_box.length
          unpacked_boxes << top_box
          sbox.sboxes.each do |box|
            new_cuts << Cut.new(offset, sbox.y_pos, sbox.width, false, @level)
            offset += @options.saw_kerf
            box.set_position(offset, sbox.y_pos)
            unpacked_boxes << box
            offset += box.length
          end
        elsif (@options.stacking == STACKING_LENGTH && sbox.rotated) ||
              (@options.stacking == STACKING_WIDTH && !sbox.rotated)
          top_box = sbox.sboxes.shift
          top_box.set_position(sbox.x_pos, sbox.y_pos)
          offset = sbox.y_pos + top_box.width
          unpacked_boxes << top_box
          sbox.sboxes.each do |box|
            new_cuts << Cut.new(sbox.x_pos, offset, sbox.length, true, @level)
            offset += @options.saw_kerf
            box.set_position(sbox.x_pos, offset)
            unpacked_boxes << box
            offset += box.width
          end
        end
      elsif sbox.instance_of?(Box)
        unpacked_boxes << sbox
      else
        raise(Packing2DError, 'Unpacking weird stuff in bin.unmake_superbox!')
      end
      [unpacked_boxes, new_cuts]
    end

    #
    # Debugging!
    #
    def to_str
      s = "lft : #{format('%5d', object_id)} [#{format('%9.2f', @x_pos)}, "
      s += "#{format('%9.2f', @y_pos)}, #{format('%9.2f', @length)}, "
      s += "#{format('%9.2f', @width)}], lvl = #{format('%3d', @level)}, "
      s + "area = #{format('%12.2f', area)}"
    end
  end
end
