module Ladb::OpenCutList::BinPacking2D

  #
  # Implements a subdivision of the bin by guillotine cuts.
  # It gives the contained box an x, y reference and the necessary
  # cuts to place the box at the top left corner.
  #
  class Leftover < Packing2D

    # Position and size of the leftover.
    attr_reader :x, :y, :length, :width

    # Level of the leftover.
    attr_reader :level

    #
    # Initializes a new leftover.
    #
    def initialize(x, y, length, width, level, options)
      super(options)

      @x = x
      @y = y
      @length = length
      @width = width
      @level = level
    end

    #
    # Trims the top level leftover of a bin.
    # These cuts are NOT recorded/counted.
    #
    def trim()
      @x += @options.trimsize
      @y += @options.trimsize
      @length -= 2*@options.trimsize
      @width -= 2*@options.trimsize
      return valid?
    end

    #
    # Resizes the leftover such that the lower right
    # corner is at max_x, max_y.
    #
    def resize_to(max_x, max_y)
      @length = [max_x - @x, 0].max if @x + @length > max_x
      @width = [max_y - @y, 0].max if @y + @width > max_y
      return valid?
    end

    #
    # Sets the length of a leftover.
    #
    def set_length(length)
      @length = length
    end

    #
    # Sets the width of a leftover.
    #
    def set_width(width)
      @width = width
    end

    #
    # Returns true if this leftover has a valid size, i.e
    # slightly larger than nothing in both dimensions.
    #
    def valid?
      if @length <= 0 && @length >= -@options.saw_kerf - EPS
        @length = 0
      end
      if @width <= 0 && @width >= -@options.saw_kerf - EPS
        @width = 0
      end
      return (@length > 0 && @width > 0)
      #if !valid
      # puts("#{@length}, #{@width}")
      # raise(Packing2DError, "Invalid leftovers with possibly negative size!")
      #end
      # return useable?
    end

    #
    # Returns true if this leftover is useable.
    #
    def UNUSED_useable?
      return (@length > 0 && @width > 0)
    end

    #
    # Returns the area.
    #
    def area()
      return @length * @width
    end

    #
    # Returns the heuristic score for placing a box inside this leftover
    # or MAX_INT if it does not fit.
    #
    def heuristic_score(box_length, box_width)
      # First test ensures that box will fit into leftover.
      if @length - box_length >= -EPS && @width - box_width >= -EPS
        case @options.score
          when SCORE_BESTAREA_FIT
            # Returns the amount of waste produced, smaller is better
            return @length * @width - box_length * box_width
          when SCORE_BESTSHORTSIDE_FIT
            # Returns the smallest difference in one dimension.
            return [@length - box_length, @width - box_width].min
          when SCORE_BESTLONGSIDE_FIT
            # Returns the largest difference in one dimension.
            return [@length - box_length, @width - box_width].max
          when SCORE_WORSTAREA_FIT
            return -(@length * @width - box_length * box_width)
          when SCORE_WORSTSHORTSIDE_FIT
            return [@length - box_length, @width - box_width].max
          when SCORE_WORSTLONGSIDE_FIT
            return [@length - box_length, @width - box_width].min
        end
      else
        return MAX_INT
      end
    end

    #
    # Adapted score for box using selected heuristic.
    #
    def score(bin_index, leftover_index, box)

      s = []
      #dbg(" #{@level} " + to_str(), true)
      s1 = heuristic_score(box.length, box.width)
      if s1 < MAX_INT
        # Make score lower if one of the dimensions matches with a preference to length.
        # TODO leftover.score: check if matching should be aligned with shape of bin.
        s1 = EPS if (@length - box.length).abs <= EPS
        s1 = EPS if (@width - box.width).abs <= EPS
        # Not a so good idea
        #s1 = s1/2 if @options.stacking == STACKING_LENGTH && box.length < box.width
        s << [leftover_index, s1, NOT_ROTATED, @level]
      end
      if box.rotatable
        s2 = heuristic_score(box.width, box.length)
        if s2 < MAX_INT
          s2 = EPS if (@length - box.width).abs <= EPS
          s2 = EPS if (@width - box.length).abs <= EPS
          #s2 = s2/2 if @options.stacking == STACKING_WIDTH && box.width < box.length
          s << [leftover_index, s2, ROTATED, @level]
        end
      end
      #puts("scores for #{box.length}, #{box.width} in #{@length}, #{@width}")
      #s.each do |e|
      #  puts("lo=#{e[0]}, s=#{e[1]}, r=#{e[2]}, #{@level}")
      #end
      return s
    end

    #
    # Returns true if order of guillotine cut is horizontal, then vertical,
    # false otherwise.
    #
    def split_horizontally_first?(box)
      #
      # When stacking is on, always do the first cut in the direction of stacking, always!
      #
=begin
      # Does not work well in practice!
      if (@x - @options.trimsize).abs < EPS && @options.stacking == STACKING_LENGTH
        return true
      elsif (@y - @options.trimsize).abs < EPS && @options.stacking == STACKING_WIDTH
        return false
      end
=end
      case @options.split
      when SPLIT_SHORTERLEFTOVER_AXIS
        return (@length - box.length < @width - box.width)
      when SPLIT_LONGERLEFTOVER_AXIS
        return (@length - box.length >= @width - box.width)
      when SPLIT_MINIMIZE_AREA
        return (@length * (@width - box.width) < @width * (@length - box.length))
      when SPLIT_MAXIMIZE_AREA
        return (@length * (@width - box.width) >= @width * (@length - box.length))
      when SPLIT_SHORTER_AXIS
        return (box.length < box.width)
      when SPLIT_LONGER_AXIS
        return (box.length >= box.width)
      when SPLIT_HORIZONTAL_FIRST
        return true
      when SPLIT_VERTICAL_FIRST
        return false
      else
        raise(Packing2DError, "Split heuristic not implemented in bin.select_horizontal_first!")
      end
    end

    #
    # Splits this leftover at position x, y by a vertical, then a horizontal cut.
    # x, y represents a position in absolute coordinates.
    # Returns the leftovers and the cuts.
    #
    # Positions the box inside the leftover and splits it horizontally first.
    #
    def split_horizontal_first(x, y, box=nil)
=begin
      if !box.nil?
        box.set_position(@x, @y)
        x = box.x + box.length
        y = box.y + box.width
      end
=end
      if x > @x + @length + EPS || y > @y + @width + EPS
        #dbg(to_str(), true)
        #dbg("#{x}, #{y}", true)
        raise(Packing2DError, "Splitting outside of this leftover in split_horizontal_first! #{@options.signature}")
      end

      new_cuts = []
      new_leftovers = []

      # Horizontal cut.
      if (@y + @width - y).abs >= EPS
        cf = Cut.new(@x, y, @length, true, @level)
        #dbg("    " + cf.to_str())
        new_cuts << cf
      end

      # Bottom leftover.
      lb = Leftover.new(@x, y + @options.saw_kerf, @length, @y + @width - y - @options.saw_kerf, @level, @options)
      new_leftovers << lb

      # Vertical cut.
      if (@x + @length - x).abs >= EPS
        cs = Cut.new(x, @y, y - @y, false, @level)
        #dbg("    " + cs.to_str())
        new_cuts << cs
      end

      # Right leftover.
      lr = Leftover.new(x + @options.saw_kerf, @y, @x + @length - x - @options.saw_kerf, y - @y, @level+1, @options)
      new_leftovers << lr

      # Unmake it if it is a superbox.
      new_boxes, more_cuts = unmake_superbox(box)
      new_cuts += more_cuts

      return [new_leftovers, new_cuts, new_boxes]
    end

    #
    # Splits this leftover at position x, y by a vertical, then a horizontal cut.
    # Returns the leftovers, the cuts and the unpacked boxes.
    #
    def split_vertical_first(x, y, box=nil)

=begin
      # Without box, splits the leftover at position x and y.
      if !box.nil?
        box.set_position(@x, @y)
        x = box.x + box.length
        y = box.y + box.width
      end
=end
      if x > @x + @length + EPS || y > @y + @width + EPS
        puts("x = #{x}, bin x = #{@x}, length = #{@length}, y = #{y}, bin y = #{@y} width = #{@width}")
        raise(Packing2DError, "Splitting outside of this leftover in split_vertical_first! #{@options.signature}")
      end

      new_cuts = []
      new_leftovers = []

      # Vertical cut.
      if (@x + @length - x).abs >= EPS
        cf = Cut.new(x, @y, @width, false, @level)
        #dbg("    " + cf.to_str())
        new_cuts << cf
      end

      # Right leftover.
      lr = Leftover.new(x + @options.saw_kerf, @y, @x + @length - x - @options.saw_kerf, @width, @level, @options)
      new_leftovers << lr

      # Horizontal cut.
      if (@y + @width - y).abs >= EPS
        cs = Cut.new(@x, y, x - @x, true, @level)
        #dbg("    " + cs.to_str())
        new_cuts << cs
      end

      # Bottom leftover.
      lb = Leftover.new(@x, y + @options.saw_kerf, x - @x, @y + @width - y - @options.saw_kerf, @level+1, @options)
      new_leftovers << lb

      # Unmake it if a superbox, does nothing if box.nil?
      new_boxes, more_cuts = unmake_superbox(box)
      new_cuts += more_cuts

      return [new_leftovers, new_cuts, new_boxes]
    end


    #
    # Unmakes a superbox, adding the necessary cuts.
    #
    def unmake_superbox(sbox)
      return [[], []] if sbox.nil?

      unpacked_boxes = []
      new_cuts = []

      if sbox.is_a?(SuperBox)
        if sbox.sboxes.size == 1
          single_box = sbox.sboxes.shift()
          #dbg("    single " + single_box.to_str())
          single_box.set_position(sbox.x, sbox.y)
          unpacked_boxes << single_box
        else
          #dbg("    multiple " + sbox.to_str(), true)
          if (@options.stacking == STACKING_LENGTH && !sbox.rotated) ||
            (@options.stacking == STACKING_WIDTH && sbox.rotated)
            top_box = sbox.sboxes.shift()
            #dbg(top_box.to_str())
            top_box.set_position(sbox.x, sbox.y)
            offset = sbox.x + top_box.length
            unpacked_boxes << top_box
            sbox.sboxes.each do |box|
              new_cuts << Cut.new(offset, sbox.y, sbox.width, false, @level)
              offset += @options.saw_kerf
              box.set_position(offset, sbox.y)
              unpacked_boxes << box
              offset += box.length
            end
          elsif (@options.stacking == STACKING_LENGTH && sbox.rotated) ||
            (@options.stacking == STACKING_WIDTH && !sbox.rotated)
            top_box = sbox.sboxes.shift()
            top_box.set_position(sbox.x, sbox.y)
            offset = sbox.y + top_box.width
            unpacked_boxes << top_box
            sbox.sboxes.each do |box|
              new_cuts << Cut.new(sbox.x, offset, sbox.length, true, @level)
              offset += @options.saw_kerf
              box.set_position(sbox.x, offset)
              unpacked_boxes << box
              offset += box.width
            end
          end
        end
      elsif sbox.is_a?(Box)
        #dbg("    simple " + sbox.to_str())
        unpacked_boxes << sbox
      else
        raise(Packing2DError, "Unpacking weird stuff in bin.unmake_superbox!")
      end
      return [unpacked_boxes, new_cuts]
    end

    #
    # Debugging!
    #
    def to_str()
      s = "lft : #{'%5d' % object_id} [#{'%9.2f' % @x}, #{'%9.2f' % @y}, #{'%9.2f' % @length}, #{'%9.2f' % @width}], "
      s += "lvl = #{'%3d' % @level}, area = #{'%12.2f' % area()}"
      return s
    end

    def to_term()
      dbg("    leftover " + to_str())
    end

    def to_octave()
      return "rectangle(\"Position\", [#{@x},#{@y},#{@length},#{@width}], \"Facecolor\", grey); # empty leftover\n"
    end
  end
end
