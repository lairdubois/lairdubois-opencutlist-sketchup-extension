module Ladb::OpenCutList::BinPacking2D

  # A ContainerBin represents an panel of sheet good containing:
  # . all the boxes that were placed by the algorithm
  # . all the leftovers
  # . all the guillotine cuts
  # The ContainerBin has a type telling whether it is a standard
  # sized panel (or custom sized panel) OR a user defined offcut
  # The ContainerBin can return a Bin, which is the object that
  # actually gets divided by successive placements and cuts and
  # whose descendents end up being the leftovers
  #
  
  class ContainerBin < Packing2D

    attr_accessor :length, :width, :trimsize, :index, :type, :boxes, :cuts, :leftovers
    attr_reader :total_length_cuts, :efficiency

    def initialize(length, width, trimsize, index, type)
      @length = length
      @width = width
      @trimsize = trimsize
      @index = index
      @type = type
      @x = 0
      @y = 0

      @boxes = []
      @cuts = []
      @leftovers = []

      @total_length_cuts = 0
      @efficiency = 0

      @max_x = 0
      @max_y = 0
      @bbox_done = true
    end

    def copy
      return ContainerBin.new(@length, @width, @trimsize, @index, @type)
    end
    
    # get_bin returns a new trimmed bin the exact size of this ContainerBin
    #
    def get_bin
      b = Bin.new(@length, @width, 0, 0, @index, @type)
      b.trim_rough_bin(@trimsize)
      return b
    end
    
    # Adds a box to the bin once it has been placed
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

        cut_horizontal = true # we always do this if this the final bbox cut

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
          cut_horizontal = false
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

    # Returns the area of this ContainerBin. It is the
    # raw area, NOT the trimmed one.
    #
    def area
      return @length * @width
    end

  end

end
