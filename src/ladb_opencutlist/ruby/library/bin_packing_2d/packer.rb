module BinPacking2D
  class Packer < Packing2D
  
    attr_accessor :sawkerf, :original_bins, :unplaced_boxes,
      :score, :split, :performance

    def initialize(options)
      @@debugging = options[:debugging]

      @sawkerf = options[:kerf]
      @trimsize = options[:trimming]
      @rotatable = options[:rotatable]
      @score = -1
      @split = -1

      @original_bins = []
      @unplaced_boxes = []
      @bins = []
      @b_x = 0
      @b_y = 0
      @b_w = 0
      @b_l = 0

      @packed = false
      @performance = nil
    end

    # Preprocess boxes by turning them into supergroups, that is
    # horizontal or vertical stripes of identical boxes up to the
    # maximum length of the standard bin
    #
    def preprocess_supergroups(boxes, stack_horizontally)
      sboxes = []
      if stack_horizontally
        maxlength = @b_l - 2 * @trimsize
        # make groups of same width and stack them horizontally
        # up to maxlength
        width_groups = boxes.group_by { |b| [b.width] }
        width_groups.each do |k, v|
          if v.length() > 1
            nb = BinPacking2D::Box.new(0, k[0])
            sboxes << nb
            v = v.sort_by { |b| [b.length] }.reverse
            v.each do |box|
              if !nb.stack_length(box, @sawkerf, maxlength)
                added = false
                sboxes.each do |s|
                  if !added && s.stack_length(box, @sawkerf, maxlength)
                    added = true
                  end
                end
                if !added
                  nb = BinPacking2D::Box.new(0, k[0])
                  sboxes << nb
                  nb.stack_length(box, @sawkerf, maxlength)
                end
              end
            end
          else
            sboxes << v[0]
          end
        end
      else
        maxwidth = @b_w - 2 * @trimsize
        # make groups of same length and stack them vertically
        # up to maxwidth
        length_groups = boxes.group_by { |b| [b.length, b.width] }
        length_groups.each do |k, v|
          if v.length() > 1
            nb = BinPacking2D::Box.new(k[0], 0)
            sboxes << nb
            v = v.sort_by { |b| [b.width] }.reverse
            v.each do |box|
              if !nb.stack_width(box, @sawkerf, maxwidth)
                added = false
                sboxes.each do |s|
                  if !added && s.stack_width(box, @sawkerf, maxwidth)
                    added = true
                  end
                end
                if !added
                  nb = BinPacking2D::Box.new(k[0], 0)
                  sboxes << nb
                  nb.stack_width(box, @sawkerf, maxwidth)
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
    def postprocess_supergroups(bins, stack_horizontally)
      if stack_horizontally
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
                  y += b.width + @sawkerf
                  if cut_counts > 0
                    bin.add_cut(BinPacking2D::Cut.new(b.x, b.y + b.width, b.length, true, b.index, false))
                    cut_counts = cut_counts - 1
                  end
                else
                  x += b.length + @sawkerf
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
                  x += b.length + @sawkerf
                  if cut_counts > 0
                    bin.add_cut(BinPacking2D::Cut.new(b.x + b.length, b.y, b.width, false, b.index, false))
                    cut_counts = cut_counts - 1
                  end
                else
                  y += b.width + @sawkerf
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

    # Postprocess bounding boxes because some horizontal/vertical may go
    # through the entire bin, but are not necessary.
    # This function trims the lower and right side of the bin by producing
    # a longest bottom part and a shorter vertical right side part
    #
    # THIS is also a good place to remove too small boxes (< 2*sawkerf)
    # which are really waste and not leftovers
    #
    def postprocess_bounding_box(bins, box = nil)
      # box is optional and will be used to decide how to split 
      # the bottom/right part of the bounding box, depending on a 
      # next candidate box.
      bins.each do |bin|
        bin.crop_to_bounding_box(@sawkerf, box)
      end
    end

    # Assign leftovers to original bins.
    # This function will be called at least once at the end of packing
    #
    def assign_leftovers_to_bins(bins, original_bins)

      # add the leftovers (bin in bins) to the parent bin, but only if
      # they are larger and longer than the sawkerf
      original_bins.each_with_index do |bin, index|
        bin.leftovers = []
        bins.each do |b|
          if b.index == index && b.width >= sawkerf && b.length >= sawkerf
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
        if !fits
          @unplaced_boxes << box
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

      db "start -->"

      # bins are numbered in sequence, this is the next available index
      next_bin_index = bins.length

      # remember original length/width of first bin, aka reference bin
      @b_l = bins[0].length
      @b_w = bins[0].width
      @b_x = bins[0].x
      @b_y = bins[0].y

      # keep a copy of the original bins to collect all relevant info
      bins.each do |bin|
        b = bin.get_copy
        b.set_strategy(get_strategy_str(@score, @split))
        # the original bins are not cleaned but they know about the trimming size
        b.trimsize = @trimsize
        b.trimmed = true
        @original_bins << b
        # trim bins, this reduces the available space
        bin.trim_rough_bin(@trimsize)
      end

      # remove boxes that are too large to fit a single bin
      boxes = remove_too_large_boxes(boxes, bins)

      # preprocess supergroups
      boxes = preprocess_supergroups(boxes, options[:stacking_horizontally]) if options[:stacking]

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
          if options[:intermediary_bounding_box_optimization]
            assign_leftovers_to_bins(bins, @original_bins)
            postprocess_bounding_box(@original_bins, box)
            bins = collect_leftovers(@original_bins)
            i, using_rotated = s.find_position_for_box(box, bins, @rotatable, @score)
          end
          if i == -1
            if options[:stacking] && options[:break_stacking_if_needed]
              # try to break up this box if it is a supergroup
              if box.is_superbox
                sboxes = box.break_up_supergroup
                boxes += sboxes
                next
              end
            end
            cs = BinPacking2D::Bin.new(@b_l, @b_w, @b_x, @b_y, next_bin_index)
            cs.strategy = get_strategy_str(@score, @split)
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
            cs, sb = cs.split_horizontally(box.width, @sawkerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x, cs.y + box.width, cs.length, true, cs.index))
            # leftover returns to bins
            bins << sb
          end
          if box.length < cs.length # this will split into left (the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @sawkerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x + box.length, cs.y, cs.width, false, cs.index))
            bins << sr
          end
        else
          if box.length < cs.length # this will split into left (containes the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @sawkerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x + box.length, cs.y, cs.width, false, cs.index))
            bins << sr
          end
          if box.width < cs.width # this will split into top (the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @sawkerf)
            @original_bins[cs.index].add_cut(BinPacking2D::Cut.new(cs.x, cs.y + box.width, cs.length, true, cs.index))
            bins << sb
          end
        end
        # cs is the piece of bin that contains exactly the box, but is not used since the box has already been added
      end

      # postprocess supergroups: boxes in @original_bins.boxes
      postprocess_supergroups(@original_bins, options[:stacking_horizontally]) if options[:stacking]

      # assign leftovers to the original bins, here mainly for drawing purpose
      assign_leftovers_to_bins(bins, @original_bins)

      # compute the bounding box and fix bottom and right leftovers
      if options[:final_bounding_box_optimization]
        postprocess_bounding_box(@original_bins)
      end
      
      # need to put this somewhere
      @unplaced_boxes.each do |box|
        puts "unplaced box #{box.length} #{box.width}"
      end
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
        p = BinPacking2D::Performance.new(@score, @split)

        @original_bins.each do |bin|
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
        end

        p.largest_leftover = largest_bin
        p.nb_bins = @original_bins.length
        return p
      else
        return nil
      end
    end
  end
end
