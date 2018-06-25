module Ladb::OpenCutList::BinPacking2D

  # This class has two purposes:
  #
  # 1. it represents a single bin object that knows how to split itself
  # 2. it is a placeholder for placed boxes/cuts.
  #

  class Bin < Packing2D

    attr_accessor :boxes, :cuts, :leftovers, :length, :width, :x, :y, :length_cuts, :trimmed, :trimsize, :index, :type
    attr_reader :efficiency, :total_length_cuts

    def initialize(length, width, x, y, index, type)
      @length = length
      @width = width
      @index = index
      @type = type
      @x = x
      @y = y
      @max_x = 0
      @max_y = 0
      @boxes = []
      @cuts = []
      @total_length_cuts = 0
      @efficiency = 0
      @leftovers = []
      @trimmed = false
      @trimsize = 0
      @bbox_done = true
    end

    def get_copy
      b = Bin.new(@length, @width, @x, @y, @index, @type)
      b.trimmed = @trimmed
      b.trimsize = @trimsize
      return b
    end

    # Trim the bin's all four edges by trimsize, not recording
    # the cuts.
    # The trimming is usually necessary on sheet good to get
    # a clean edge.
    #
    def trim_rough_bin(trimsize)
      if trimsize > 0
        @trimsize = trimsize
        @length = @length - 2 * @trimsize
        @width = @width - 2 * @trimsize
        @x = @trimsize
        @y = @trimsize
        @cleaned = true
      end
    end

    # Split the bin vertically at v considering the saw_kerf.
    # Creates and returns a sl = left bin and sr = right bin
    #
    def split_vertically(v, saw_kerf)
      sl = self.clone
      sl.length = v
      sr = self.clone
      if @length > v
        sr.length -= v + saw_kerf
        sr.x += v + saw_kerf
      else
        sr.length = 0
        sr.width = 0
        sr.x += v + saw_kerf
      end
      return sl, sr
    end

    # Split the bin bin horizontally at h considering the saw_kerf.
    # Creates and returns a st = top bin and sb = bottom bin
    #
    def split_horizontally(h, saw_kerf)
      st = self.clone
      st.width = h
      sb = self.clone
      if @width > h
        sb.width -= h + saw_kerf
        sb.y += h + saw_kerf
      else
        sb.length = 0
        sb.width = 0
        s.y += h + saw_kerf
      end
      return st, sb
    end

    # Returns whether the bin should be split horizontally/vertically
    # or vertically/horizontally.
    # The result depends on the split heuristic.
    #
    def split_horizontally_first?(box, split)
      w = @width - box.width
      l = @length - box.length

      case split
      when SPLIT_SHORTERLEFTOVER_AXIS
        decision = (w <= l)
      when SPLIT_LONGERLEFTOVER_AXIS
        decision = (w > l)
      when SPLIT_MINIMIZE_AREA
        decision = (l * box.width > box.length * w)
      when SPLIT_MAXIMIZE_AREA
        decision = (l * box.width <= box.length * w)
      when SPLIT_SHORTER_AXIS
        decision = (@length <= @width)
      when SPLIT_LONGER_AXIS
        decision = (@length > @width)
      else
        decision = true
      end

      return decision
    end

    # Computes whether a given box fits
    #
    def encloses?(box)
      return (@length >= box.length && @width >= box.width)
    end

    # Computes whether a given "rotated" box will fit
    # into this bin
    #
    def encloses_rotated?(box)
      return @length >= box.width && @width >= box.length
    end

    # Adds a box to the bin once it was placed
    #
    def add_box(box)
      # keep track of bounding box lower right corner
      @max_x = [@max_x, box.x + box.length].max
      @max_y = [@max_y, box.y + box.width].max
      # mark bounding box as dirty
      @bbox_done = false
      @boxes << box
    end

    # Adds a cut to this bin
    #
    def add_cut(cut)
      @cuts << cut
    end

    # Crop a bin to a smaller size. Used by the bounding box part
    # of the algorithm in packer
    #
    def crop(max_x, max_y)
      if @x + @length > max_x
        @length = max_x - @x
      end
      if @y + @width > max_y
        @width = max_y - @y
      end
    end

    # Crop all leftovers to the bounding box of all packed boxes, add
    # necessary cuts and new leftovers.
    # This function assumes that leftovers have been assigned correctly
    # to the bin prior to calling it.
    #
    def crop_to_bounding_box(saw_kerf, box)
      unless @bbox_done
        # trim all cuts that go beyond max_y and max_y
        @cuts.each do |cut|
          if cut.is_horizontal && cut.x + cut.length > @max_x
            cut.length = @max_x - cut.x
          end
          if !cut.is_horizontal && cut.y + cut.length > @max_y
            cut.length = @max_y - cut.y
          end
        end

        leftovers = []

        sr = (@length - 2 * @trimsize - @max_x) * @width
        sb = @length * (@width - 2 * @trimsize - @max_y)

        cut_horizontal = true

        if !box.nil?
          if box.length <= @length && box.width <= (@width - 2 * @trimsize - @max_y)
            # cut first horizontal
            cut_horizontal = true
          elsif box.length <= (@width - 2 * @trimsize - @max_y) && box.width < @width
            # cut first vertical
            cut_horizontal = false
          elsif sb >= sr
            # cut first horizontal
            cut_horizontal = true
          else
            cut_horizontal = false
          end
        elsif sb >= sr
          cut_horizontal = true
        else
          # FIXME in 1.5.1
          # cut_horizontal = false
          # this seems to exhibit some strange behaviour!
          # the idea is that we perform the bounding box by increasing
          # the area of the larger of the two leftovers, but this tends
          # to break the selection of the best packing in packengine
          cut_horizontal = true
         end

        # Pick the cut sequence that will maximize area of larger leftover area.
        # Probably needs to follow split strategy using score object, maybe later.
        #
        # This may also lead to degenerate pieces, will have to fix them in packer
        #
        if cut_horizontal
          # add a new horizontal cut and make a new bottom leftover
          if @max_y <= @width
            c = Cut.new(@x + @trimsize, @max_y, @length - 2 * @trimsize, true)
            hl = Bin.new(@length - 2 * @trimsize, @width - @max_y - saw_kerf - @trimsize,
                                       @x + @trimsize, @max_y + saw_kerf, @index, @type)
            add_cut(c)
            leftovers << hl if hl.length > 0 && hl.width > 0
          end
          # add a new vertical cut and make a new right side vertical leftover
          if @max_x <= @length
            c = Cut.new(@max_x, @y + @trimsize, @max_y - @trimsize, false)
            vl = Bin.new(@length - @max_x - @trimsize - saw_kerf, @max_y - @trimsize,
                                       @max_x + saw_kerf, @y + @trimsize, @index, @type)
            add_cut(c)
            leftovers << vl if vl.length > 0 && vl.width > 0
          end
        else
          # add a new vertical cut and make a new right side vertical leftover
          if @max_x <= @length
            c = Cut.new(@max_x, @y + @trimsize, @width - 2 * @trimsize, false)
            vl = Bin.new(@length - @max_x - @trimsize - saw_kerf, @width - 2 * @trimsize,
                                       @max_x + saw_kerf, @y + @trimsize, @index, @type)
            add_cut(c)
            leftovers << vl if vl.length > 0 && vl.width > 0
          end
          if @max_y <= @width
            c = Cut.new(@x + @trimsize, @max_y, @max_x - @trimsize, true)
            hl = Bin.new(@max_x - @trimsize, @width - @max_y - saw_kerf - @trimsize,
                                       @x + @trimsize, @max_y + saw_kerf, @index, @type)
            add_cut(c)
            leftovers << hl if hl.length > 0 && hl.width > 0
          end
        end

        # crop the leftovers to the bounding box
        @leftovers.each do |b|
          b.crop(@max_x, @max_y)
          if b.length > 0 && b.width > 0
            leftovers << b
          end
        end
        @leftovers = leftovers
        @bbox_done = true
      end
    end

    # Returns percentage of coverage by boxes not including
    # waste area from saw_kerf
    #
    def compute_efficiency
      boxes_area = 0
      @boxes.each { |box| boxes_area += box.area }
      @efficiency = boxes_area * 100.0 / area
    end

    # Returns total horizontal and vertical cut lengths
    #
    def total_cutlengths
      h_cuts = 0
      v_cuts = 0
      @cuts.each do |cut|
        h_cuts += cut.get_h_cutlength()
        v_cuts += cut.get_v_cutlength()
      end
      @total_length_cuts = h_cuts + v_cuts
    end

    # Returns total horizontal and vertical length of
    # contained boxes.
    #
    def total_boxlengths
      h = 0
      v = 0
      @boxes.each do |box|
        h += box.length
        v += box.width
      end
      return h, v
    end

    # Returns the largest leftover bin in this bin
    # Assumes that leftovers have already been assigned
    # to this bin.
    #
    def largest_leftover
      largest_bin = nil
      largest_area = 0
      @leftovers.each do |b|
        a = b.area
        if a > largest_area
          largest_bin = b
          largest_area = a
        end
      end
      return largest_bin
    end

    def area
      return @length * @width
    end

  end

end
