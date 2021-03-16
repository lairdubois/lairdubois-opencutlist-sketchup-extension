module Ladb::OpenCutList::BinPacking1D

  #
  # Core computing for 1D Bin Packing.
  #
  class PackerDP < Packer

    #
    # Clones the boxes and leftovers for a single run.
    # Splits up boxes if containing more than MAX_PARTS,
    # in which case bin packing may take too much time.
    #
    def clone_split(boxes, leftovers)
      length = boxes.size
      boxes_clone = []
      #
      # We don't need a deep clone of boxes, because they
      # will receive their position once the best packing
      # has been found.
      #
      if length < MAX_PARTS
        boxes_clone = [boxes.clone]
      else
        # Try to avoid having only small or only large parts
        # in the slices.
        index_half = (boxes.length/2).round + 1
        boxes = boxes.each_slice(index_half).to_a
        boxes.map(&:compact!)
        boxes = boxes[0].zip(boxes[1]).flatten
        boxes_clone = boxes.each_slice(MAX_PARTS).to_a
      end
      #
      # we absolutely need deep clones of leftovers!
      # because they will be changed during bin packing.
      #
      leftovers_clone = []
      leftovers.each do |leftover|
        leftovers_clone << Bin.new(leftover.length, BIN_TYPE_LO, @options)
      end
      [boxes_clone, leftovers_clone]
    end

    #
    # run the bin packing optimization.
    #
    def run
      @gstat[:algorithm] = ALG_SUBSET_SUM
      err = ERROR_NONE

      # Not a super precise way of measuring compute time.
      @start_time = Time.now
      remove_unfit

      if @boxes.size == 0
        @unplaced_boxes = @unfit_boxes if @unfit_boxes.size > 0
        prepare_results
        return ERROR_NO_BIN
      end

      begin
        bclone, lclone = clone_split(@boxes, @leftovers)
        #
        # Watchdog for excessive computation time
        #
        if @options.max_time && (Time.now - @start_time > @options.max_time)
          raise(TimeoutError, 'Timeout expired ...')
        end

        bins, err = pack(bclone, lclone)

        if err == ERROR_NONE
          # Tidy up the best result so far
          @bins = bins
          @unused_bins += lclone
          @leftovers = []

          # Remove from boxes all elements that have been packed into bins
          @bins.each do |bin|
            bin.boxes.each do |box|
              @boxes.delete(box)
            end
          end
          @unplaced_boxes = @boxes + @unfit_boxes
        elsif err == ERROR_NO_BIN
          if !bins.empty?
            # Found placements, but no more bins available
            err = ERROR_NONE
            @bins = bins
            @leftovers = lclone
            @bins.each do |bin|
              bin.boxes.each do |box|
                @boxes.delete(box)
              end
            end
            @unplaced_boxes = @boxes + @unfit_boxes
            @boxes = []
          end
        end
      rescue TimeoutError => err
        puts ("Rescued in Packer: #{err.inspect}")
        return ERROR_TIMEOUT
      rescue Packing1DError => err
        puts ("Rescued in Packer: #{err.inspect}")
        return ERROR_BAD_ERROR
      end

      prepare_results if err == ERROR_NONE
      err
    end

    #
    # Takes a list of chunk (of parts MAX_PARTS long)
    # a list of leftovers and prepares packing.
    #
    def pack(chunk, leftovers)
      bins = []

      # Chunks of boxes, normally we only have one unless
      # we have more than MAX_PARTS.
      chunk.each_with_index do |boxes, idx|
        using_std_bin = leftovers.empty?
        # Slicing may add nil objects, remove them
        boxes.compact!

        # Remove all boxes assigned to the last bin so far
        # and add them to the current group
        # this is only used when the input is split into
        # more than one chunk of at most MAX_PARTS boxes
        # we do this to prevent an almost empty last bin
        # of the first chunk.
        if (idx > 0) && !bins.empty?
          bin = bins.pop
          boxes += bin.boxes
        end

        # Getting all the lengths of the boxes.
        # From here on we work only with the lengths, not the
        # boxes themselves.
        lengths = boxes.collect(&:length)

        # Run this loop until
        # . lengths is empty
        # . or running out of bins
        until lengths.empty?
          if leftovers.empty?
            if @options.base_bin_length > EPS
              bin = Bin.new(@options.base_bin_length, BIN_TYPE_NEW , @options)
              using_std_bin = true
              target_length = bin.netlength
            else
              # Returning what we have found so far
              # all placed boxes are in the bins (tc_28.txt)
              return [bins, ERROR_NO_BIN]
            end
          else
            # Take the next leftover bin
            bin = leftovers.shift
            target_length = bin.netlength
          end

          # Filter lengths to match and sort by decreasing length
          valid_lengths = lengths.select{|el| el <= target_length}
          valid_lengths.sort!.reverse!

          if valid_lengths.empty?
            if not using_std_bin
              @unused_bins << bin
              next
            else
              return [bins, ERROR_NONE]
            end
          end

          # This is the core algorithm, finding subsetsums
          # of lengths that best match the target size
          if @gstat[:nb_input_boxes] > MAX_PARTS
            # Last element is the smallest one.
            epsilon = 0.95*valid_lengths.last
          else
            epsilon = 0.0
          end
          y, y_list = allsubsetsums(valid_lengths, target_length, @options.saw_kerf, epsilon)
          if y.zero?
            # Should only happen if we have a very wide
            # saw kerf and we cannot fit any box.
            # see tc_4.txt
            # returning whatever was found, not sure this really works!
            if using_std_bin
              return [bins, ERROR_NONE]
            end
          else
            # Remove objects from bins having the adequate lengths
            # and add them to the bin
            y_list.each do |found_length|
              # Get index of first element having a matching lengths
              # TODO: precision definition, make sure we are not missing
              # a box because of precision, before
              # i = boxes.index { |x| x.length == found_length}
              i = boxes.index { |x| (x.length - found_length).abs < EPS}
              if !i.nil?
                bin.add(boxes[i])
                d = boxes.delete_at(i)
                if d.nil?
                  raise(Packing1DError, "Box is gone!")
                end
                # Remove this length (found_length) from the ones we
                # are looking for
                lengths.delete_at(lengths.index(found_length) || lengths.length)
              end
            end
            # Add this completed bin to the bins
            bins << bin
          end
        end
      end
      # We now have bins, q still contains all boxes,
      # gets fixed by the receiver.
      [bins, ERROR_NONE]
    end

    #
    # Compute all subset sums given a list of
    # lengths (x_list), a sum (target) and a
    # positive epsilon which helps not being
    # too greedy.
    #
    def allsubsetsums(x_list, target, saw_kerf, epsilon)
      se = { 0 => [] }
      max = 0
      x_list.each do |x|
        te = {}
        se.each do |y, y_list|
          length = y_list.reduce(&:+).to_f + x + y_list.length*saw_kerf
          if length > target
            next
          else
            if y + x > max
              max = y + x
            end
          end
          # New target that can be reached
          te.store(y + x, y_list + [x])
          if @options.max_time && (Time.now - @start_time > @options.max_time)
            raise(TimeoutError, 'Timeout expired ...!')
          end
        end
        # Merge te with se, resolve conflicts by
        # keeping the key with the least number of parts
        se.merge!(te) { |_k, v1, v2| v1.length < v2.length ? v1 : v2 }

        # The first max to reach the sum within a term of epsilon
        # (depending on the size of the smallest element) will
        # be returned. this avoids being too greedy and doing
        # too much computation
        if max <= target && max >= target - epsilon
          return se.max_by{|k, v| k}
        end
      end

      return se.max_by{|k, v| k}
    end
  end
end
