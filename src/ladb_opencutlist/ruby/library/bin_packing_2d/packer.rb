module BinPacking2D
  class Packer < Packing2D
  
    attr_accessor :saw_kerf, :original_bins, :unplaced_boxes, :unused_bins, :score, :split, :performance

    def initialize(options)
    
      @saw_kerf = options[:saw_kerf]
      @trimsize = options[:trimming]
      @rotatable = options[:rotatable]
      @score = -1
      @split = -1

      @original_bins = []
      @unplaced_boxes = []
      @unused_bins = []
      @bins = []
      @b_x = 0
      @b_y = 0
      @b_w = 0
      @b_l = 0

      @packed = false
      @performance = nil
    end

    # Preprocess boxes by turning them into supergroups, that is
    # into length or width stripes of identical boxes up to the
    # maximum length of the standard bin
    #
    def preprocess_supergroups(boxes, stack_length)
      sboxes = []
      if stack_length == STACKING_LENGTH
        maxlength = @b_l - 2 * @trimsize
        # make groups of same width and stack them lengthwise
        # up to maxlength
        width_groups = boxes.group_by { |b| [b.width] }
        width_groups.each do |k, v|
          if v.length() > 1
            nb = BinPacking2D::Box.new(0, k[0])
            sboxes << nb
            v = v.sort_by { |b| [b.length] }.reverse
            v.each do |box|
              if !nb.stack_length(box, @saw_kerf, maxlength)
                added = false
                sboxes.each do |s|
                  if !added && s.stack_length(box, @saw_kerf, maxlength)
                    added = true
                  end
                end
                if !added
                  nb = BinPacking2D::Box.new(0, k[0])
                  sboxes << nb
                  nb.stack_length(box, @saw_kerf, maxlength)
                end
              end
            end
          else
            sboxes << v[0]
          end
        end
      else
        maxwidth = @b_w - 2 * @trimsize
        # make groups of same length and stack them widthwise
        # up to maxwidth
        length_groups = boxes.group_by { |b| [b.length] }
        length_groups.each do |k, v|
          if v.length() > 1
            nb = BinPacking2D::Box.new(k[0], 0)
            sboxes << nb
            v = v.sort_by { |b| [b.width] }.reverse
            v.each do |box|
              if !nb.stack_width(box, @saw_kerf, maxwidth)
                added = false
                sboxes.each do |s|
                  if !added && s.stack_width(box, @saw_kerf, maxwidth)
                    added = true
                  end
                end
                if !added
                  nb = BinPacking2D::Box.new(k[0], 0)
                  sboxes << nb
                  nb.stack_width(box, @saw_kerf, maxwidth)
                end
              end
            end
          else
            sboxes << v[0]
          end
        end
      end
      return sboxes
    end

    # Postprocess supergroups by extracting the original boxes from the
    # superboxes and adding the necessary cuts.
    #
    # This function will change the instance variables
    # @cuts and @boxes from each bin in bins
    #
    def postprocess_supergroups(bins, stack_length)
      if stack_length == STACKING_LENGTH
        bins.each do |bin|
          new_boxes = []
          bin.boxes.each do |sbox|
            if sbox.is_superbox
              x = sbox.x
              y = sbox.y
              cut_counts = sbox.sboxes.length() - 1
              sbox.sboxes.each do |b|
                b.set_position(x, y, sbox.index)
                if sbox.rotated
                  b.rotate
                  y += b.width + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(BinPacking2D::Cut.new(b.x, b.y + b.width, b.length, true, b.index, false))
                    cut_counts = cut_counts - 1
                  end
                else
                  x += b.length + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(BinPacking2D::Cut.new(b.x + b.length, b.y, b.width, false, b.index, false))
                    cut_counts = cut_counts - 1
                  end
                end
                new_boxes << b
              end
            else
              new_boxes << sbox
            end
          end
          bin.boxes = new_boxes
        end
      else
        bins.each do |bin|
          new_boxes = []
          bin.boxes.each do |sbox|
            if sbox.is_superbox
              x = sbox.x
              y = sbox.y
              cut_counts = sbox.sboxes.length() - 1
              sbox.sboxes.each do |b|
                b.set_position(x, y, sbox.index)
                if sbox.rotated
                  b.rotate
                  x += b.length + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(BinPacking2D::Cut.new(b.x + b.length, b.y, b.width, false, b.index, false))
                    cut_counts = cut_counts - 1
                  end
                else
                  y += b.width + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(BinPacking2D::Cut.new(b.x, b.y + b.width, b.length, true, b.index, false))
                    cut_counts = cut_counts - 1
                  end
                end
                new_boxes << b
              end
            else
              new_boxes << sbox
            end
          end
          bin.boxes = new_boxes
        end
      end
    end

    # Postprocess bounding boxes because some length/width cuts may go
    # through the entire bin, but are not necessary.
    # This function trims the lower/right side of the bin by producing
    # a longer bottom part and a shorter vertical right side part or
    # inversely. 
    #
    # THIS is also a good place to remove too small boxes (< 2*saw_kerf)
    # which are really waste and not leftovers
    #
    def postprocess_bounding_box(bins, box = nil)
      # box is optional and will be used to decide how to split 
      # the bottom/right part of the bounding box, depending on a 
      # next candidate box.
      bins.each do |bin|
        bin.crop_to_bounding_box(@saw_kerf, box)
      end
    end

    # Assign leftovers to original bins.
    # This function will be called at least once at the end of packing
    #
    def assign_leftovers_to_bins(bins, original_bins)

      # add the leftovers (bin in bins) to the parent bin, but only if
      # they are larger and longer than the saw_kerf
      original_bins.each_with_index do |bin, index|
        bin.leftovers = []
        bins.each do |b|
          if b.index == index && b.width >= saw_kerf && b.length >= saw_kerf
            bin.leftovers << b
          end
        end
      end
    end

    # Collect leftovers from all original bins and return them
    #
    def collect_leftovers(original_bins)
      leftovers = []
      original_bins.each do |bin|
        leftovers += bin.leftovers
      end
      return leftovers
    end

    # Remove boxes that are too large to fit the available bins
    # If a box only fits rotated, rotate it
    #
    def remove_too_large_boxes(boxes, bins)
      standard_bin = BinPacking2D::Bin.new(@b_l, @b_w, 0, 0, 0, PANEL_TYPE_NEW)
      fitting_boxes = []
      boxes.each_with_index do |box, i|
        fits = false
        bins.each do |bin|
          if bin.encloses?(box)
            fits = true
          elsif (@rotatable && bin.encloses_rotated?(box))
            box.rotate
            fits = true
          end
        end
        if !fits # box does not fit one that is available, but maybe fits standard bin
          if standard_bin.encloses?(box)
            fitting_boxes << box
          elsif (@rotatable && bin.encloses_rotated?(box))
            box.rotate
            fitting_boxes << box
          else
            @unplaced_boxes << box
          end
        else
          fitting_boxes << box
        end
      end
      return fitting_boxes
    end

    # Pack boxes in available bins with given heuristics for the
    # in placement (score) and splitting (split).
    # If stacking is desired, then preprocess/postprocess supergroups.
    #
    def pack(bins, boxes, score, split, options)
      s = BinPacking2D::Score.new
      @score = score
      @split = split

      # bins are numbered in sequence, this is the next available index
      if bins.nil? || bins.empty?
        next_bin_index = 0
      else
        next_bin_index = bins.length
      end

      # remember original length/width of first bin, aka reference bin
      @b_l = options[:base_sheet_length]
      @b_w = options[:base_sheet_width]
      @b_x = 0
      @b_y = 0
      
      # keep a copy of the original bins to collect all relevant info
      if !bins.empty?
        bins.each do |bin|
          b = bin.get_copy
          # the original bins are not cleaned but they know about the trimming size
          b.trimsize = @trimsize
          b.trimmed = true
          @original_bins << b
          # trim bins, this reduces the available space
          bin.trim_rough_bin(@trimsize)
        end
      end

      # remove boxes that are too large to fit a single bin
      boxes = remove_too_large_boxes(boxes, bins)

      # preprocess supergroups
      boxes = preprocess_supergroups(boxes, options[:stacking]) if options[:stacking] != STACKING_NONE

      # sort boxes width/length decreasing (other heuristics like
      # by decreasing area/perimeter would also be possible)
      case options[:presort]
      when PRESORT_WIDTH_DECR
        boxes = boxes.sort_by { |b| [b.width, b.length] }.reverse
      when PRESORT_LENGTH_DECR
        boxes = boxes.sort_by { |b| [b.length, b.width] }.reverse
      when PRESORT_AREA_DECR
        boxes = boxes.sort_by { |b| [b.width * b.length] }.reverse
      when PRESORT_PERIMETER_DECR
        boxes = boxes.sort_by { |b| [b.length + b.width] }.reverse
      when PRESORT_INPUT_ORDER
        # do nothing
      else
        boxes = boxes.sort_by { |b| [b.width, b.length] }.reverse
      end

      until boxes.empty?
        # get next box to place
        # alternating between big and small boxes might be an idea?
        box = boxes.shift

        # find best position for given box in collection of bins
        i, using_rotated = s.find_position_for_box(box, bins, @rotatable, @score)
        if i == -1
          if options[:bbox_optimization] == BBOX_OPTIMIZATION_ALWAYS
            assign_leftovers_to_bins(bins, @original_bins)
            postprocess_bounding_box(@original_bins, box)
            bins = collect_leftovers(@original_bins)
            i, using_rotated = s.find_position_for_box(box, bins, @rotatable, @score)
          end
          if i == -1
            if options[:stacking] != STACKING_NONE && options[:break_stacking_if_needed]
              # try to break up this box if it is a supergroup
              if box.is_superbox
                sboxes = box.reduce_supergroup(@saw_kerf)
                boxes.unshift(*sboxes) # prepend the boxes, this does not guarantee that order is preserved
                next
              end
            end
            cs = BinPacking2D::Bin.new(@b_l, @b_w, @b_x, @b_y, next_bin_index, PANEL_TYPE_NEW)
            cs.trimsize = @trimsize
            cs.trimmed = true
            @original_bins << cs.get_copy

            cs.trim_rough_bin(@trimsize)
            next_bin_index += 1
          else
            box.rotate if using_rotated
            cs = bins[i]
            bins.delete_at(i)
          end
        else
          box.rotate if using_rotated
          cs = bins[i]
          bins.delete_at(i)
        end

        # the box will be placed at the top/left corner of the bin, get its index
        # and added to the original bin
        box.set_position(cs.x, cs.y, cs.index)
        @original_bins[cs.index].addbox(box)

        # split horizontally first
        if cs.split_horizontally_first?(box, @split)
          if box.width < cs.width # this will split into top (contains the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @saw_kerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x, cs.y + box.width, cs.length, true, cs.index))
            # leftover returns to bins
            bins << sb
          end
          if box.length < cs.length # this will split into left (the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @saw_kerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x + box.length, cs.y, cs.width, false, cs.index))
            bins << sr
          end
        else
          if box.length < cs.length # this will split into left (containes the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @saw_kerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x + box.length, cs.y, cs.width, false, cs.index))
            bins << sr
          end
          if box.width < cs.width # this will split into top (the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @saw_kerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x, cs.y + box.width, cs.length, true, cs.index))
            bins << sb
          end
        end
        # cs is the piece of bin that contains exactly the box, but is not used since the box has already been added
      end

      # postprocess supergroups: boxes in @original_bins.boxes
      postprocess_supergroups(@original_bins, options[:stacking]) if options[:stacking] != STACKING_NONE

      # assign leftovers to the original bins, here mainly for drawing purpose
      assign_leftovers_to_bins(bins, @original_bins)

      # compute the bounding box and fix bottom and right leftovers
      postprocess_bounding_box(@original_bins) if options[:bbox_optimization] != BBOX_OPTIMIZATION_NONE
      
      # unpacked boxes are in @unpacked_boxes
      
      @packed = true
      @performance = get_performance
    end

    # Compute some statistics that will be stored in the
    # performance object
    #
    def get_performance
      if @packed
        largest_bin = nil
        largest_area = 0
        p = BinPacking2D::Performance.new()

        @unused_bins = []
        bins = []
        @original_bins.each do |bin|
          if bin.boxes.empty? # a bin without boxes has not been used
            @unused_bins << bin
          else
            p.h_length, p.v_length = bin.total_boxlengths()
            p.h_cutlength, p.v_cutlength = bin.total_cutlengths()
            p.cutlength = p.h_cutlength + p.v_cutlength
            p.nb_leftovers += bin.leftovers.length

            bin.leftovers.each do |b|
              a = b.area
              if a > largest_area
                largest_bin = b
                largest_area = a
              end
            end
            bin.compute_efficiency
            
            bins << bin
          end
        end
        @original_bins = bins

        p.largest_leftover = largest_bin
        p.nb_bins = @original_bins.length
        return p
      else
        return nil
      end
    end
    
  end
end
