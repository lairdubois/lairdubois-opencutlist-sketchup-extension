module Ladb::OpenCutList::BinPacking2D

  class Bin < Packing2D

    attr_accessor :length, :width, :x, :y, :index, :type, :trimsize

    def initialize(length, width, x, y, index, type)
      @length = length
      @width = width
      @index = index
      @type = type
      @x = x
      @y = y
    end

    # Trim the bin's four edges by trimsize, not recording
    # the cuts!
    # The trimming is usually necessary on sheet good to get
    # a clean edge. We don't trim (silently) if the trimsize 
    # is just some funky value! 
    #
    def trim_rough_bin(trimsize)
      if trimsize > 0 && trimsize <= 0.5*[@length, @width].min
        @length = @length - 2 * trimsize
        @width = @width - 2 * trimsize
        @x = trimsize
        @y = trimsize
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
    def split_horizontally_first?(box, split, stacking)
    
      return false if stacking == STACKING_WIDTH
      #return true if stacking == STACKING_LENGTH
      
      l = @length - box.length
      w = @width - box.width

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

    # Returns whether a given box fits within this Bin.
    #
    def encloses?(box)
      return (@length >= box.length && @width >= box.width)
    end

    # Returns whether a given "rotated" box will fit
    # into this Bin.
    #
    def encloses_rotated?(box)
      return (@length >= box.width && @width >= box.length)
    end
    
    # Returns whether a given box will fit into this Bin
    # when it is internally rotated
    #
    def encloses_internally_rotated?(box)
      if box.is_a?(SuperBox) && box.all_same?
        length, width = box.internally_rotated_dimensions()
        return (@length >= length && @width >= width)
      else
        return false
      end
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

    def area
      return @length * @width
    end
    
  end

end
