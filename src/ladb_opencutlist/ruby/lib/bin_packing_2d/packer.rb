module Ladb::OpenCutList::BinPacking2D

  class Packer < Packing2D

    attr_accessor :saw_kerf, :container_bins, :unplaced_boxes, :unused_bins, :score, :split, :performance

    def initialize(options, processor)
    
      @saw_kerf = options.saw_kerf
      @trimsize = options.trimsize
      @has_grain = options.has_grain
      @stacking = options.stacking
      @break_stacking_if_needed = options.break_stacking_if_needed
      @bbox_optimization = options.bbox_optimization
      
      @scorer = Score.new(options)
      
      @score = -1
      @split = -1

      @container_bins = []
      @unused_bins = []
      @unplaced_boxes = []

      @b_x = 0
      @b_y = 0
      @b_l = options.base_bin_length
      @b_w = options.base_bin_width

      @processor = processor
      @performance = nil

    end
    
    # Pack boxes in available bins with given heuristics for the
    # in placement (score) and splitting (split).
    # If stacking is desired, then preprocess/postprocess supergroups.
    #
    def pack(container_bins, boxes, score, split)
      bins = []

      @score = score
      @split = split

      # bins are numbered in sequence, this is the next available index
      next_bin_index = 1
      if container_bins.nil? || container_bins.empty?
        # if we have no cutoffs then 
        # make sure we have at least one panel, otherwise stacking will try to break
        # stacks just for fun and give suboptimal solutions
        cb = ContainerBin.new(@b_l, @b_w, @trimsize, next_bin_index, BIN_TYPE_AUTO_GENERATED)
        @container_bins << cb
        next_bin_index += 1
      else
        container_bins.each do |cb|
          cb.index = next_bin_index
          @container_bins << cb
          next_bin_index += 1
        end
      end

      # make a bin from each container bins already created
      @container_bins.each do |cb|
        bins << cb.get_bin
      end

      until boxes.empty?

        # get next box to place, this overwrites the pre-sorting

        j, k, orientation = @scorer.find_next_box(boxes, bins)
        if j == POSITION_NOT_FOUND
          box = boxes.shift
          # find best position for given box in collection of bins
          i, orientation = @scorer.find_position_for_box(box, bins, @score)
        else
          box = boxes[j]
          boxes.delete_at(j)
          i = k
        end

        if i == POSITION_NOT_FOUND
          if @bbox_optimization == BBOX_OPTIMIZATION_ALWAYS
            assign_leftovers(bins, @container_bins)
            postprocess_bounding_box(@container_bins, box)
            bins = collect_leftovers(@container_bins)
            i, orientation = @scorer.find_position_for_box(box, bins, @score)
          end
          # still no position to place found
          if i == POSITION_NOT_FOUND
            if @stacking != STACKING_NONE && @break_stacking_if_needed
              # try to break up this box if it is a supergroup
              if box.is_a?(SuperBox)
                boxes += box.boxes
                next
              end
            end
            # only create a new bin if this box will fit into it
            if box.fits_into_bin?(@b_l, @b_w, @trimsize, !@has_grain)
              cb = ContainerBin.new(@b_l, @b_w, @trimsize, next_bin_index, BIN_TYPE_AUTO_GENERATED)
              @container_bins << cb
              cs = cb.get_bin
              next_bin_index += 1
            else
              @unplaced_boxes << box
              next
            end
          else
            if orientation == ORIENTATION_ROTATED
              box.rotate 
            elsif orientation == ORIENTATION_INTERNALLY_ROTATED  
              box.internal_rotate
            elsif orientation == ORIENTATION_EXPLODED
              b = box.boxes
              box = b[0]
              boxes = b.drop(1) + boxes
            end
            cs = bins[i]
            bins.delete_at(i)
          end
        else
          if orientation == ORIENTATION_ROTATED
            box.rotate 
          elsif orientation == ORIENTATION_INTERNALLY_ROTATED  
            box.internal_rotate
          elsif orientation == ORIENTATION_EXPLODED
            b = box.boxes
            box = b[0]
            boxes = b.drop(1) + boxes
          end
          cs = bins[i]
          bins.delete_at(i)
        end

        # the box will be placed at the top/left corner of the bin, get its index
        # and added to the original bin
        box.set_position(cs.x, cs.y)
        add_box_to_container(box, cs.index)

        # split horizontally first
        if cs.split_horizontally_first?(box, @split, @stacking)
          if box.width < cs.width # this will split into top (contains the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @saw_kerf)
            add_cut_to_container(Cut.new(cs.x, cs.y + box.width, cs.length, true), cs.index)
            # leftover returns to bins
            bins << sb
          end
          if box.length < cs.length # this will split into left (the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @saw_kerf)
            add_cut_to_container(Cut.new(cs.x + box.length, cs.y, cs.width, false), cs.index)
            bins << sr
          end
        else
          if box.length < cs.length # this will split into left (containes the box), right (goes to leftover)
            cs, sr = cs.split_vertically(box.length, @saw_kerf)
            add_cut_to_container(Cut.new(cs.x + box.length, cs.y, cs.width, false), cs.index)
            bins << sr
          end
          if box.width < cs.width # this will split into top (the box), bottom (goes to leftover)
            cs, sb = cs.split_horizontally(box.width, @saw_kerf)
            add_cut_to_container(Cut.new(cs.x, cs.y + box.width, cs.length, true), cs.index)
            bins << sb
          end
        end
        # cs is the piece of bin that contains exactly the box, but is not used since the box has already been added
      end

      # postprocess supergroups: boxes in @container_bins.boxes
      if @stacking == STACKING_LENGTH
        @processor.explode_sboxes_lengthwise(@container_bins)
      elsif @stacking == STACKING_WIDTH
        @processor.explode_sboxes_widthwise(@container_bins)
      end
      
      # assign leftovers to the original bins, here mainly for drawing purpose
      assign_leftovers(bins, @container_bins)

      # compute the bounding box and fix bottom and right leftovers
      postprocess_bounding_box(@container_bins) if @bbox_optimization != BBOX_OPTIMIZATION_NONE

      # unpacked boxes are in @unpacked_boxes

      @performance = get_performance
    end

    private

    def add_box_to_container(box, index)
      @container_bins.each do |bin|
        if bin.index == index
          bin.add_box(box)
          return
        end
      end
      # error bin.index was not found
    end
    
    def add_cut_to_container(cut, index)
      @container_bins.each do |bin|
        if bin.index == index
          bin.cuts << cut
          return
        end
      end
      # error bin.index was not found
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
    def postprocess_bounding_box(container_bins, box = nil)
      # box is optional and will be used to decide how to split
      # the bottom/right part of the bounding box, depending on a
      # next candidate box.
      container_bins.each do |cb|
        cb.crop_to_bounding_box(@saw_kerf, box)
      end
    end

    # Assign leftovers to original bins.
    # This function will be called at least once at the end of packing
    #
    def assign_leftovers(bins, container_bins)

      # add the leftovers (bin in bins) to the container bin, but only if
      # they are larger and longer than the saw_kerf
      container_bins.each do |bin|
        bin.leftovers = []
        bins.each do |b|
          if b.index == bin.index && b.width >= saw_kerf && b.length >= saw_kerf
            bin.leftovers << b
          end
        end
      end
    end

    # Collect leftovers from all original bins and return them
    #
    def collect_leftovers(container_bins)
      leftovers = []
      container_bins.each do |bin|
        leftovers += bin.leftovers
      end
      return leftovers
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
      @container_bins.each do |bin|
        if bin.boxes.empty? # a ContainerBin without boxes has not been used
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
      @container_bins = bins
      p.largest_leftover_area = largest_area unless largest_bin.nil?
      p.largest_leftover_length = largest_bin.length unless largest_bin.nil?
      p.largest_leftover_width = largest_bin.width unless largest_bin.nil?

      p.nb_bins = @container_bins.length
      return p
    end

  end

end
