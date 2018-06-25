module Ladb::OpenCutList::BinPacking2D

  class Packer < Packing2D

    attr_accessor :saw_kerf, :original_bins, :unplaced_boxes, :unused_bins, :score, :split, :performance

    def initialize(options)
      @saw_kerf = options.saw_kerf
      @trimsize = options.trimming
      @rotatable = options.rotatable
      @score = -1
      @split = -1

      @original_bins = []
      @unplaced_boxes = []
      @unused_bins = []

      @b_x = 0
      @b_y = 0
      @b_w = 0
      @b_l = 0
      @stacking_maxlength = 0
      @stacking_maxwidth = 0

      @performance = nil
    end

    # Pack boxes in available bins with given heuristics for the
    # in placement (score) and splitting (split).
    # If stacking is desired, then preprocess/postprocess supergroups.
    #
    def pack(bins, boxes, score, split, options)
      s = Score.new
      @score = score
      @split = split

      # remember original length/width of first bin, aka reference bin
      @b_l = options.base_bin_length
      @b_w = options.base_bin_width
      @b_x = 0
      @b_y = 0

      # bins are numbered in sequence, this is the next available index
      if bins.nil? || bins.empty?
        next_bin_index = 0
        # make sure we have at least one panel, otherwise stacking will try to break
        # stacks just for fun and give suboptimal solutions
        bins << Bin.new(@b_l, @b_w, @b_x, @b_y, next_bin_index, BIN_TYPE_AUTO_GENERATED)
        next_bin_index += 1
      else
        bins.each do |bin|
          @stacking_maxlength = bin.length unless bin.length <= @stacking_maxlength
          @stacking_maxwidth = bin.width unless bin.width <= @stacking_maxwidth
        end
        next_bin_index = bins.length
      end

      # keep a copy of the original bins to collect all relevant info
      unless bins.empty?
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
      boxes = preprocess_supergroups(boxes, options.stacking) if options.stacking != STACKING_NONE

      # sort boxes width/length decreasing (other heuristics like
      # by decreasing area/perimeter would also be possible)
      case options.presort
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
          if options.bbox_optimization == BBOX_OPTIMIZATION_ALWAYS
            assign_leftovers_to_bins(bins, @original_bins)
            postprocess_bounding_box(@original_bins, box)
            bins = collect_leftovers(@original_bins)
            i, using_rotated = s.find_position_for_box(box, bins, @rotatable, @score)
          end
          if i == -1
            if options.stacking != STACKING_NONE && options.break_stacking_if_needed
              # try to break up this box if it is a supergroup
              if box.is_superbox
                sboxes = box.break_up_supergroup
                boxes += sboxes
                next
              end
              # FIXME in 1.5.1 it would be nice to only break up part of the superbox
              #if box.is_superbox
              #  sboxes = box.reduce_supergroup(@saw_kerf)
              #  boxes.unshift(*sboxes) # prepend the boxes, this does not guarantee that order is preserved
              #  next
              #end
            end
            # only create a new bin if this box will fit into it
            if box.fits_into_bin?(@b_l, @b_w, @trimsize, @rotatable)
              cs = Bin.new(@b_l, @b_w, @b_x, @b_y, next_bin_index, BIN_TYPE_AUTO_GENERATED)
              cs.trimsize = @trimsize
              cs.trimmed = true
              @original_bins << cs.get_copy
              cs.trim_rough_bin(@trimsize)
              next_bin_index += 1
            else
              # this will never happen if the above FIXME is not implemented, because
              # the superbox will have been brocken down by now
              if box.is_superbox
                #sboxes = box.break_up_supergroup()
                #@unplaced_boxes.unshift(*sboxes)
                @unplaced_boxes << box
              else
                @unplaced_boxes << box
              end
              next
            end
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
        box.set_position(cs.x, cs.y)
        @original_bins[cs.index].add_box(box)

        # split horizontally first
        if cs.split_horizontally_first?(box, @split)
          if box.width < cs.width # this will split into top (contains the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @saw_kerf)
            @original_bins[cs.index].add_cut(Cut.new(cs.x, cs.y + box.width, cs.length, true))
            # leftover returns to bins
            bins << sb
          end
          if box.length < cs.length # this will split into left (the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @saw_kerf)
            @original_bins[cs.index].add_cut(Cut.new(cs.x + box.length, cs.y, cs.width, false))
            bins << sr
          end
        else
          if box.length < cs.length # this will split into left (containes the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @saw_kerf)
            @original_bins[cs.index].add_cut(Cut.new(cs.x + box.length, cs.y, cs.width, false))
            bins << sr
          end
          if box.width < cs.width # this will split into top (the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @saw_kerf)
            @original_bins[cs.index].add_cut(Cut.new(cs.x, cs.y + box.width, cs.length, true))
            bins << sb
          end
        end
        # cs is the piece of bin that contains exactly the box, but is not used since the box has already been added
      end

      # postprocess supergroups: boxes in @original_bins.boxes
      postprocess_supergroups(@original_bins, options.stacking) if options.stacking != STACKING_NONE

      # assign leftovers to the original bins, here mainly for drawing purpose
      assign_leftovers_to_bins(bins, @original_bins)

      # compute the bounding box and fix bottom and right leftovers
      postprocess_bounding_box(@original_bins) if options.bbox_optimization != BBOX_OPTIMIZATION_NONE

      # unpacked boxes are in @unpacked_boxes

      @performance = get_performance
    end

    private

    # Preprocess boxes by turning them into supergroups, that is
    # into length or width stripes of identical boxes up to the
    # maximum length of the standard bin
    #
    def preprocess_supergroups(boxes, stacking)
      sboxes = []

      if stacking == STACKING_LENGTH
        maxlength = [(@b_l - 2 * @trimsize).abs, (@stacking_maxlength - 2 * @trimsize).abs].max
        # compute groups of same width and stack them lengthwise
        # up to maxlength
        width_groups = boxes.group_by { |b| [b.width] }
        width_groups.each do |k, v|
          if v.length() > 1
            v = v.sort_by { |b| [b.length] }.reverse
            superbox = Box.new(0, k[0])
            until v.empty?
              box = v.shift
              if box.length <= maxlength
                # try to stack it, if it fails
                if !superbox.stack_length(box, @saw_kerf, maxlength)
                  # close this superbox
                  sboxes << superbox
                  # and create a new one
                  superbox = Box.new(0, k[0])
                  # this should alway succeed, because box.length <= maxlength
                  superbox.stack_length(box, @saw_kerf, maxlength)
                end
              else
                # box is larger than the maxlength to stack, let packer handle it
                sboxes << box
              end
            end
            # close the last superbox created if it is not empty
            if superbox.sboxes.length() > 0
              sboxes << superbox
            end
           else
            sboxes << v[0]
          end
        end
      else
        maxwidth = [(@b_w - 2 * @trimsize).abs, (@stacking_maxwidth - 2 * @trimsize).abs].max
        # make groups of same length and stack them widthwise
        # up to maxwidth
        length_groups = boxes.group_by { |b| [b.length] }
        length_groups.each do |k, v|
          if v.length() > 1
            v = v.sort_by { |b| [b.width] }.reverse
            superbox = Box.new(k[0], 0)
            until v.empty?
              box = v.shift
                if box.width <= maxwidth
                  if !superbox.stack_width(box, @saw_kerf, maxwidth)
                    sboxes << superbox
                    superbox = Box.new(k[0], 0)
                    superbox.stack_width(box, @saw_kerf, maxwidth)
                  end
                else
                  sboxes << box
                end
              end
              if superbox.sboxes.length() > 0
                sboxes << superbox
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
    def postprocess_supergroups(bins, stacking)
      if stacking == STACKING_LENGTH
        bins.each do |bin|
          new_boxes = []
          bin.boxes.each do |sbox|
            if sbox.is_superbox
              x = sbox.x
              y = sbox.y
              cut_counts = sbox.sboxes.length() - 1
              sbox.sboxes.each do |b|
                b.set_position(x, y)
                if sbox.rotated
                  b.rotate
                  y += b.width + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(Cut.new(b.x, b.y + b.width, b.length, true, false))
                    cut_counts = cut_counts - 1
                  end
                else
                  x += b.length + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(Cut.new(b.x + b.length, b.y, b.width, false, false))
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
                b.set_position(x, y)
                if sbox.rotated
                  b.rotate
                  x += b.length + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(Cut.new(b.x + b.length, b.y, b.width, false, false))
                    cut_counts = cut_counts - 1
                  end
                else
                  y += b.width + @saw_kerf
                  if cut_counts > 0
                    bin.add_cut(Cut.new(b.x, b.y + b.width, b.length, true, false))
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
      standard_bin = Bin.new(@b_l, @b_w, 0, 0, 0, BIN_TYPE_AUTO_GENERATED)
      boxes_that_fit = []
      boxes.each_with_index do |box, i|
        box_fits = false
        bins.each do |bin|
          if bin.encloses?(box)
            box_fits = true
          elsif (@rotatable && bin.encloses_rotated?(box))
            box.rotate
            box_fits = true
          end
        end
        if box_fits
          boxes_that_fit << box
        elsif standard_bin.encloses?(box)
          boxes_that_fit << box
        elsif (@rotatable && standard_bin.encloses_rotated?(box))
          box.rotate
          boxes_that_fit << box
        else
          @unplaced_boxes << box
        end
      end
      return boxes_that_fit
    end

    # Compute some statistics that will be stored in the
    # performance object
    #
    def get_performance
      largest_bin = nil
      largest_area = 0

      p = Performance.new

      bins = []
      
      # we split the bins into ones that contain boxes and ones
      # that do not contain boxes
      @original_bins.each do |bin|
        if bin.boxes.empty? # a bin without boxes has not been used
          @unused_bins << bin
        else
          p.nb_boxes_packed += bin.boxes.length
          p.nb_leftovers += bin.leftovers.length
          bin.total_cutlengths
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

      p.largest_leftover_length = largest_bin.length unless largest_bin.nil?
      p.largest_leftover_width = largest_bin.width unless largest_bin.nil?

      p.nb_bins = @original_bins.length
      return p
    end

  end

end
