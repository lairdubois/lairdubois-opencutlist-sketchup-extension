module Ladb::OpenCutList::BinPacking2D

  #
  # Core computing for 2D Bin Packing.
  #
  class Packer < Packing2D

    # Array of input bins and boxes.
    attr_reader :bins, :boxes

    # Maximum sizes for stacking.
    attr_reader :stacking_maxlength, :stacking_maxwidth

    # Running index for all bins, zero based.
    attr_reader :next_bin_index

    # Number of valid boxes at start.
    attr_reader :nb_input_boxes

    # List of valid boxes at start.
    attr_reader :nb_valid_boxes

    # List of unplaced boxes because too large to fit or because
    # of a lack of available bins.
    attr_reader :unplaced_boxes

    # List of boxes that cannot be placed into any bin.
    attr_reader :invalid_boxes

    # List of bins that have been used in packing.
    attr_accessor :packed_bins

    # List of bins that were not used for packing.
    attr_reader :unused_bins

    # Statistic objects for this packing.
    attr_reader :stat, :gstat

    # Link to previous packer, one is used per bin.
    # N-th packer is linked to previous packer.
    attr_reader :previous_packer

    def initialize(options)
      super

      @bins = []
      @next_bin_index = 0
      @packed_bins = []
      @unused_bins = []

      @boxes = []
      @unplaced_boxes = []
      @invalid_boxes = []

      @stacking_maxlength = 0
      @stacking_maxwidth = 0

      @min_length = 0
      @min_width = 0

      @previous_packer = nil

      # statistic per packer/bin
      @stat = nil

      # statistic collected for final report
      @gstat = {}
      @gstat[:nb_input_boxes] = 0
      @gstat[:nb_invalid_boxes] = 0
      @gstat[:nb_packed_boxes] = 0
      @gstat[:nb_packed_bins] = 0
      @gstat[:nb_unused_bins] = 0
      @gstat[:nb_leftovers] = 0
      @gstat[:rank] = 0
      @gstat[:total_compactness] = 0
      @gstat[:longest_leftover] = 0
      @gstat[:largest_leftover] = 0
    end

    #
    # Links this packer to a previous packer, i.e.
    # takes over unplaced_boxes, invalid_boxes, unused bins
    # and packed bins.
    # Must make deep copies of unplaced boxes and unused bins
    # because these will be used in multiple packings.
    #
    def link_to(previous_packer)
      if !previous_packer.nil?
        @previous_packer = previous_packer
        @next_bin_index = previous_packer.next_bin_index

        @previous_packer.packed_bins.each do |bin|
          @packed_bins << bin
        end

        @previous_packer.unused_bins.each do |bin|
          new_bin = Bin.new(bin.length, bin.width, bin.type, @options)
          @next_bin_index = new_bin.set_index(bin.index)
          @bins << new_bin
        end

        @previous_packer.unplaced_boxes.each do |box|
          new_box = Box.new(box.length, box.width, box.rotatable, box.data)
          @boxes << new_box
        end

        @previous_packer.invalid_boxes.each do |box|
          @invalid_boxes << box
        end

        # Update start statistics for this packer
        @gstat[:nb_invalid_boxes] = @previous_packer.gstat[:nb_invalid_boxes]
        @gstat[:nb_input_boxes] = @previous_packer.gstat[:nb_input_boxes]
        @gstat[:nb_leftovers] = @previous_packer.gstat[:nb_leftovers]
        @gstat[:nb_packed_boxes] = @previous_packer.gstat[:nb_packed_boxes]
        @gstat[:total_compactness] = @previous_packer.gstat[:total_compactness]
      end
    end

    #
    # Adds a bin to the packer.
    #
    def add_bin(bin)
      @bins << bin
    end

    #
    # Adds a box to the packer.
    #
    def add_box(box)
      @boxes << box
    end

    #
    # Returns true if standard bins can be infinitely added.
    #
    def can_add_bins?()
      return (@options.base_length >= EPS && @options.base_width >= EPS)
    end

    #
    # Removes boxes that are too large to fit into any bin.
    #
    def clean_boxes()

      # Previous packer has already cleaned, do not execute.
      return true if !@previous_packer.nil?

      @gstat[:nb_input_boxes] = @boxes.size

      @boxes, @invalid_boxes = @boxes.partition { |box| box.fits_into?(@stacking_maxlength, @stacking_maxwidth) }

      @gstat[:nb_invalid_boxes] = @invalid_boxes.size

      if @boxes.size + @gstat[:nb_invalid_boxes] != @gstat[:nb_input_boxes]
        raise(Packing2DError, "Too many boxes in packer.clean_boxes #{@options.signature}!")
      end

      # Execution can continue if we have at least 1 valid box.
      return (@boxes.size > 0)
    end

    #
    # Presorts the boxes to be packed.
    #
    def sort_boxes()

      case @options.presort
      when PRESORT_INPUT_ORDER
      when PRESORT_WIDTH_DECR
        @boxes.sort_by! { |box| [-box.width, -box.length] }
      when PRESORT_LENGTH_DECR
        @boxes.sort_by! { |box| [-box.length, -box.width] }
      when PRESORT_AREA_DECR
        @boxes.sort_by! { |box| [-box.width * box.length] }
      when PRESORT_LONGEST_SIDE_DECR
        @boxes.sort_by! { |box| [-[box.length, box.width].max] }
      when PRESORT_SHORTEST_SIDE_DECR
        @boxes.sort_by! { |box| [-[box.length, box.width].min] }
      when PRESORT_PERIMETER_DECR
        @boxes.sort_by! { |box| [-box.length - box.width] }
      when PRESORT_ALTERNATING_WIDTHS
        w_max = @boxes.max_by { |box| box.width}
        wl, ws = @boxes.partition { |box| box.width >= (@stacking_maxwidth - w_max.width) }
        wl.sort_by! { |box| -box.width }
        ws.sort_by! { |box| -box.width }
        if wl.size == 0 || ws.size == 0
          @options.presort = PRESORT_WIDTH_DECR
          sort_boxes
        elsif ws.size >= wl.size
          @boxes = ws.zip(wl).flatten!.compact
        else
          @boxes = wl.zip(ws).flatten!.compact
        end
      when PRESORT_ALTERNATING_LENGTHS
        l_max = @boxes.max_by { |box| box.length}
        ll, ls = @boxes.partition { |box| box.length >= (@stacking_maxlength - l_max.length) }
        ll.sort_by! { |box| -box.length }
        ls.sort_by! { |box| -box.length }
        if ll.size == 0 || ls.size == 0
          @options.presort = PRESORT_ALTERNATING_WIDTHS
          sort_boxes
        elsif ls.size >= ll.size
          @boxes = ls.zip(ll).flatten!.compact
        else
          @boxes = ll.zip(ls).flatten!.compact
        end
      else
        raise(Packing2DError, "Presorting option not available in packer.sort_boxes!")
      end
    end

    #
    # Takes boxes with same length/width and tries to stack them so
    # that they will be placed as a single box, horizontally or vertically, thus
    # reducing the number of cuts.
    # TODO try to rebalance stacks, this leads to more compact bounding boxes!
    #
    def make_superboxes_length()
      # Trying to make them as long as possible
      @boxes.each do |box|
        if box.rotatable && box.length < box.width
          box.rotate
        end
      end

      # Stack the boxes by decreasing length.
      @boxes.sort_by!(&:length).reverse!

      sboxes = []
      while !@boxes.empty?
      box = @boxes.shift
        sbox = SuperBox.new(@stacking_maxlength, @stacking_maxwidth, @options.saw_kerf)
        sbox.add_first_box(box)
        sboxes << sbox
        if !@boxes.empty?
          @boxes = sbox.stack_length(@boxes)
        end
      end
      @boxes = sboxes
    end

    #
    # Takes boxes with same length/width and tries to stack them so
    # that they will be placed as a single box.
    #
    def make_superboxes_width()
      # Trying to make them as wide as possible
      @boxes.each do |box|
        if box.rotatable && box.width < box.length
          box.rotate
        end
      end

      # Start with width decreasing!
      @boxes.sort_by!(&:width) .reverse!

      sboxes = []
      while !@boxes.empty?
        box = @boxes.shift
        sbox = SuperBox.new(@stacking_maxlength, @stacking_maxwidth, @options.saw_kerf)
        sbox.add_first_box(box)
        sboxes << sbox
        if !@boxes.empty?
          @boxes = sbox.stack_width(@boxes)
        end
      end
      @boxes = sboxes
    end

    #
    # Unmakes all superboxes.
    # This must be done at the end of packing, to restore unpacked boxes to
    # their original state and between packings.
    #
    def unmake_superboxes(unplaced_boxes)
      exploded_boxes = []
      unplaced_boxes.each do |box|
        if box.is_a?(SuperBox)
          exploded_boxes += box.sboxes
        else
          exploded_boxes << box
        end
      end
      return unplaced_boxes
    end

    #
    # Preprocesses the list of boxes by
    # . removing boxes that are too large and place them into @unplaced_boxes
    # . make sure that we have at least one bin
    # . stack bins if options is on
    # . presort parts for packing
    #
    def preprocess()

      # Compute maximal stacking length/width.
      if can_add_bins?
        @stacking_maxlength = @options.base_length - 2 * @options.trimsize
        @stacking_maxwidth = @options.base_width - 2 * @options.trimsize
      end

      if @bins.empty?
        if can_add_bins?
          # If we have no bins at all, add a bin to start with.
          new_bin = Bin.new(@options.base_length, @options.base_width, BIN_TYPE_AUTO_GENERATED, @options)
          @next_bin_index = new_bin.set_index(@next_bin_index)
          @bins << new_bin
        else
          # Cannot proceed with no bins.
          return false
        end
      else
        # Offcuts are used in increasing order of area.
        @bins.sort_by! { |bin| [bin.length * bin.width]}
        @bins.each do |bin|
          # Assign index to each user defined bin.
          @next_bin_index = bin.set_index(@next_bin_index)
          # Adjust maximal stacking length/width, offcut may be larger than standard bin!
          @stacking_maxlength = [@stacking_maxlength, bin.length - 2 * @options.trimsize].max
          @stacking_maxwidth = [@stacking_maxwidth, bin.width - 2 * @options.trimsize].max
        end
      end

      return false if !clean_boxes

      # TODO packer.superboxes stacked boxes maybe need their own sorting!
      case @options.stacking
      when STACKING_LENGTH
        make_superboxes_length()
      when STACKING_WIDTH
        make_superboxes_width()
      end
      sort_boxes()
      return true
    end

    #
    # Gets the next available bin from the offcuts or produce one.
    #
    def get_next_bin()
      bin = nil
      if !@bins.empty?
        bin = @bins.shift
      elsif can_add_bins?
        bin = Bin.new(@options.base_length, @options.base_width, BIN_TYPE_AUTO_GENERATED, @options)
        @next_bin_index = bin.set_index(@next_bin_index)
      end
      return bin
    end

    #
    # Top level packing algorithm for a single Bin.
    #
    def pack()

      current_bin = nil
      nb_placed_boxes = 0
      loop do
        return ERROR_NO_PLACEMENT_POSSIBLE if !preprocess()
        current_bin = get_next_bin
        return ERROR_NO_BIN if current_bin.nil?
        nb_placed_boxes = pack_single(current_bin)
        if nb_placed_boxes == 0 && (can_add_bins? || @bins.size > 0)
          @unused_bins << current_bin
        else
          break
        end
      end
      if nb_placed_boxes > 0
        current_bin.final_bounding_box
        current_bin.keep_signature(@options.signature)
        # Special case with an offcut, the current bin may hold no boxes!!
        @packed_bins << current_bin
        @unplaced_boxes = @boxes
        @unplaced_boxes = unmake_superboxes(@unplaced_boxes)
        postprocess(current_bin)
        @unused_bins += @bins
        @bins = []
        @boxes = []
      else
        return ERROR_NO_PLACEMENT_POSSIBLE
      end
      return ERROR_NONE
    end

    #
    # Packs boxes into a single bin, returns unused boxes.
    #
    def pack_single(current_bin)

      nb_placed_boxes = 0
      # List of boxes that could not be placed during this run.
      unused_boxes = []

      previous_box = nil
      begin
        until @boxes.empty?
          # Select next box and get ranked score from current_bin.
          box = @boxes.shift

          # Recompute bounding box, while packing!
          if current_bin.boxes.size() > 1 && !box.equal?(previous_box)
            current_bin.bounding_box(box, false)
            # This would be a good place to make a rectangle merge, but
            # 26.txt shows that this is not possible!
            # Only recompute bounding box when no merge is possible!
          end
          score = current_bin.best_ranked_score(box)

          # No placement possible in current bin.
          if score.nil?
            #
            # Step 1: if this box is a superbox, reduce it by one. Push
            #         remaining superbox back onto the stack of boxes.
            #
            if box.is_a?(SuperBox)
              front, sbox = box.reduce
              if !sbox.nil?
                # Push the remaining sbox back onto the stack, it was not consumed
                @boxes.unshift(sbox)
              end
              @boxes.unshift(front)
            else
              unused_boxes << box
            end
          #
          # At least one score was found, so there is a leftover or bin with
          # space for the current box.
          #
          else
            # Safety nets.
            if current_bin.nil?
              raise(Packing2DError, "No bin in packer.pack to add to #{@options.signature}!")
            end
            if box.nil?
              raise(Packing2DError, "No box in packer.pack to add #{@options.signature}!")
            end

            leftover_index = score[0]
            box.rotate if score[2] == ROTATED
            # Caution! once the box has been placed, the leftover index is NOT VALID anymore!
            current_bin.add_box(box, leftover_index, @min_length, @min_width)
            previous_box = box
            nb_placed_boxes += 1
          end
        end

      rescue Packing2DError => err
        puts("Running signature #{@options.signature}")
        puts("Rescued in Packer #{err.inspect}")
        puts err.backtrace
        return ERROR_BAD_ERROR
      end

      @boxes = unused_boxes
      return nb_placed_boxes
    end

    #
    # Collects all pieces per bin, runs statistics.
    # TODO packer.postprocess verify that we havent lost any boxes in the packing process
    #
    def postprocess(current_bin)

      current_bin.summarize

      # Get statistics from bin, add our own.
      @stat = current_bin.stat
      @stat[:area_unplaced_boxes] = @unplaced_boxes.inject(0) { |sum, box| sum + box.area }
      @stat[:nb_unplaced_boxes] = @unplaced_boxes.size

      @gstat[:nb_invalid_boxes] = @invalid_boxes.size
      @gstat[:nb_packed_bins] = @packed_bins.size
      @gstat[:nb_leftovers] += current_bin.stat[:nb_leftovers]
      @gstat[:nb_packed_boxes] += current_bin.boxes.size
      @gstat[:nb_unused_bins] = @unused_bins.size
      @gstat[:total_compactness] += @stat[:compactness]
      @gstat[:longest_leftover] = @stat[:longest_leftover]
      @gstat[:largest_leftover] = @stat[:largest_leftover]

    end

    #
    # We do not yet make a difference between invalid and unplaceable box
    # in the GUI.
    #
    def finish()
      @unplaced_boxes += @invalid_boxes if invalid_boxes.size() > 0
    end

    #
    # Sorts used bins by efficiency. Done by interface, currently unused
    # (see packengine.rb).
    #
    def sort_bins_by_efficiency()
      @packed_bins.sort_by! { |bin| -bin.stat[:efficiency] }
    end

    #
    # Debugging! Prints stuff to terminal.
    #
    def to_term()

      debug_old = @options.debug
      @options.set_debug(true)

      dbg("-> packing summary")
      @packed_bins.each do |bin|
        dbg("\n   single packing stats")
        dbg("    compactness               #{'%6.2f' % bin.stat[:compactness]}")
        dbg("    total_length_cuts   #{'%12.2f' % bin.stat[:total_length_cuts]}")
        dbg("    l_measure           #{'%12.2f' % bin.stat[:l_measure]}")
        dbg("    efficiency                #{'%6.2f' % bin.stat[:efficiency]}")
        dbg("    nb_leftovers               #{'%5d' % bin.stat[:nb_leftovers]}")
        bin.to_term
      end

      dbg("\n   general stats (accumulated)")
      dbg("    nb_input_boxes            #{'%5d' % @gstat[:nb_input_boxes]}")
      dbg("    nb_invalid_boxes          #{'%5d' % @gstat[:nb_invalid_boxes]}")
      dbg("    nb_packed_boxes           #{'%5d' % @gstat[:nb_packed_boxes]}")
      dbg("    nb_unplaced_boxes         #{'%5d' % @stat[:nb_unplaced_boxes]}")
      dbg("    nb_packed_bins            #{'%5d' % @gstat[:nb_packed_bins]}")
      dbg("    nb_unused_bins            #{'%5d' % @gstat[:nb_unused_bins]}")
      dbg("    nb_leftovers              #{'%5d' % @gstat[:nb_leftovers]}")

      dbg("\n   unused bins")
      @unused_bins.each do |bin|
        dbg("    " + bin.to_str)
      end

      dbg("\n   unplaced boxes")
      @unplaced_boxes.each do |box|
        dbg("    " + box.to_str)
      end

      dbg("\n   invalid boxes")
      @invalid_boxes.each do |box|
        dbg("      " + box.to_str)
      end

      @options.set_debug(debug_old)
    end

    #
    # Debugging!
    #
    def to_str()
      return "packer id=#{@options.fingerprint}"
    end

    #
    # Prints the packing as a Matlab/Octave graphics.
    #
    def octave(id, directory="./results")
      dbg("-> printing octave")
      #FileUtils.rm_f Dir.glob("#{directory}/res*.m")
      @packed_bins.each do |bin|
        dbg("   bin #{bin.index}")
        filename = "#{directory}/res_#{id}_#{bin.index}.m"
        f = File.open(filename, 'w')
        bin.octave(f)
      end
    end
  end

end
