module Ladb::OpenCutList::BinPacking2D

  #
  # Core computing for 2D Bin Packing.
  #
  class Packer < Packing2D

    # Array of input bins and boxes.
    attr_reader :bins, :boxes

    # Maximum sizes for stacking into the current Bin.
    attr_reader :stacking_maxlength, :stacking_maxwidth

    # Running index for all Bins, zero based.
    attr_reader :next_bin_index

    # Number of valid Boxes at start.
    attr_reader :nb_input_boxes

    # List of valid Boxes at start.
    attr_reader :nb_valid_boxes

    # List of unplaced boxes because too large to fit or because
    # of a lack of available Bins.
    attr_reader :unplaced_boxes

    # List of Boxes that cannot be placed into the current Bin.
    attr_reader :invalid_boxes

    # List of Bins that have been used in packing.
    attr_accessor :packed_bins

    # List of Bins that were not used for packing.
    attr_reader :unused_bins

    # List of Bins that were deemed invalid for packing.
    attr_reader :invalid_bins

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
      @invalid_bins = []

      @boxes = []
      @unplaced_boxes = []
      @invalid_boxes = []

      @stacking_maxlength = 0
      @stacking_maxwidth = 0

      @previous_packer = nil

      # Statistics per Packer, points to current_bin.
      @stat = nil

      # Statistics collected for final report.
      @gstat = {}
      @gstat[:nb_input_boxes] = 0
      @gstat[:nb_packed_boxes] = 0
      @gstat[:nb_invalid_boxes] = 0
      @gstat[:nb_packed_bins] = 0
      @gstat[:nb_unused_bins] = 0
      @gstat[:nb_invalid_bins] = 0
      @gstat[:nb_leftovers] = 0
      @gstat[:total_length_cuts] = 0
      @gstat[:total_nb_cuts] = 0
      @gstat[:nb_through_cuts] = 0
      @gstat[:total_l_measure] = 0
      @gstat[:area_unplaced_boxes] = 0
      @gstat[:all_largest_area] = 0
      @gstat[:largest_bottom_parts] = 0
      @gstat[:rank] = 0
    end

    #
    # Links this packer to a previous packer, i.e.
    # takes over unplaced_boxes, invalid_boxes, unused bins
    # and packed bins.
    # Must make deep copies of unplaced boxes and unused bins
    # because these will be used in multiple packings.
    #
    def link_to(previous_packer)
      # Previous_packer is never nil?
      @previous_packer = previous_packer
      @next_bin_index = previous_packer.next_bin_index

      # Packed bins will not get modified anymore, no need to make own instances
      @previous_packer.packed_bins.each do |bin|
        @packed_bins << bin
      end

      # Make copies of unused bins so that each packer has its own instances
      @previous_packer.unused_bins.each do |bin|
        new_bin = Bin.new(bin.length, bin.width, bin.type, @options, 0)
        @next_bin_index = new_bin.set_index(bin.index)
        @bins << new_bin
      end

      # Theses bins will not be used anymore, thus no need to clone them.
      @previous_packer.invalid_bins.each do |bin|
        @invalid_bins << bin
      end

      # Make copies of unplaced boxes so that each packer has its own instances.
      @previous_packer.unplaced_boxes.each do |box|
        new_box = Box.new(box.length, box.width, box.rotatable, box.data)
        new_box.set_rotated if box.rotated?
        @boxes << new_box
      end

      # Invalid boxes for one bin, may be valid for the next bin.
      @previous_packer.invalid_boxes.each do |box|
        new_box = Box.new(box.length, box.width, box.rotatable, box.data)
        @boxes << new_box
      end

      # Update start statistics for this packer
      @gstat[:nb_input_boxes] = @previous_packer.gstat[:nb_input_boxes]
      @gstat[:nb_leftovers] = @previous_packer.gstat[:nb_leftovers]
      @gstat[:nb_packed_boxes] = @previous_packer.gstat[:nb_packed_boxes]
      @gstat[:total_length_cuts] = @previous_packer.gstat[:total_length_cuts]
      @gstat[:total_nb_cuts] = @previous_packer.gstat[:total_nb_cuts]
      @gstat[:nb_through_cuts] = @previous_packer.gstat[:nb_through_cuts]
      @gstat[:all_largest_area] = @previous_packer.gstat[:all_largest_area]
      @gstat[:total_l_measure] = @previous_packer.gstat[:total_l_measure]
    end

    #
    # Adds a Bin to this Packer.
    #
    def add_bin(bin)
      @bins << bin
      @next_bin_index += 1 if @previous_packer.nil?
    end

    #
    # Adds a Box to this Packer.
    #
    def add_box(box)
      @boxes << box
    end

    #
    # Adds a list of invalid Boxes (too large to fit any Bin) to this Packer.
    # TODO: We do not yet make a distinction between invalid and unplaceable box in the GUI.
    #
    def add_invalid_boxes(invalid_boxes)
      @invalid_boxes += invalid_boxes
      gstat[:nb_invalid_boxes] += invalid_boxes.size
      @unplaced_boxes += invalid_boxes
    end

    def add_invalid_bins(invalid_bins)
      @invalid_bins += invalid_bins
      gstat[:nb_invalid_bins] += invalid_bins.size
      @unused_bins += invalid_bins
    end

    #
    # Returns true if standard Bins can be infinitely added.
    #
    def bins_can_be_added?
      (@options.base_length - 2 * @options.trimsize > EPS && @options.base_width - 2 * @options.trimsize > EPS) || !@bins.empty?
    end

    #
    # Presorts the boxes to be packed.
    #
    def sort_boxes
      case @options.presort
      when PRESORT_WIDTH_DECR
        @boxes.sort_by! { |box| [-box.width, -box.length] }
      when PRESORT_LENGTH_DECR
        @boxes.sort_by! { |box| [-box.length, -box.width] }
      when PRESORT_AREA_DECR
        @boxes.sort_by! { |box| [-box.width * box.length, -box.length] }
      when PRESORT_LONGEST_SIDE_DECR
        @boxes.sort_by! { |box| [-[box.length, box.width].max, [box.length, box.width].max] }
      when PRESORT_SHORTEST_SIDE_DECR
        @boxes.sort_by! { |box| [-[box.length, box.width].min, [box.length, box.width].max] }
      when PRESORT_PERIMETER_DECR
        @boxes.sort_by! { |box| [-box.length - box.width, -box.length] }
      when PRESORT_ALTERNATING_WIDTHS
        w_max = @boxes.max_by(&:width)
        wl, ws = @boxes.partition { |box| box.width >= (@_maxwidth - w_max.width) }
        wl.sort_by! { |box| -box.width }
        ws.sort_by! { |box| -box.width }
        if wl.empty? || ws.empty?
          @options.presort = PRESORT_WIDTH_DECR
          sort_boxes
        elsif ws.size >= wl.size
          @boxes = ws.zip(wl).flatten!.compact
        else
          @boxes = wl.zip(ws).flatten!.compact
        end
      when PRESORT_ALTERNATING_LENGTHS
        l_max = @boxes.max_by(&:length)
        ll, ls = @boxes.partition { |box| box.length >= (@_maxlength - l_max.length) }
        ll.sort_by! { |box| -box.length }
        ls.sort_by! { |box| -box.length }
        if ll.empty? || ls.empty?
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
    # TODO: try to rebalance stacks, this leads to more compact bounding boxes!
    #
    def make_superboxes_length
      # Trying to make them as long as possible
      @boxes.each do |box|
        if box.rotatable && box.length < box.width
          box.rotate
        end
      end

      # Stack the boxes by decreasing length.
      @boxes.sort_by!(&:length).reverse!

      sboxes = []
      until @boxes.empty?
        sbox = SuperBox.new(@stacking_maxlength, @stacking_maxwidth, @options.saw_kerf)
        sbox.add_first_box(@boxes.shift)
        sboxes << sbox
        @boxes = sbox.stack_length(@boxes) unless @boxes.empty?
      end
      @boxes = sboxes
    end

    #
    # Takes boxes with same length/width and tries to stack them so
    # that they will be placed as a single box.
    #
    def make_superboxes_width
      # Trying to make them as wide as possible
      @boxes.each do |box|
        box.rotate if box.rotatable && box.width < box.length
      end

      # Start with width decreasing!
      @boxes.sort_by!(&:width).reverse!

      sboxes = []
      until @boxes.empty?
        box = @boxes.shift
        sbox = SuperBox.new(@stacking_maxlength, @stacking_maxwidth, @options.saw_kerf)
        sbox.add_first_box(box)
        sboxes << sbox
        @boxes = sbox.stack_width(@boxes) unless @boxes.empty?
      end
      @boxes = sboxes
    end

    #
    # Unmakes all superboxes.
    # This must be done at the end of packing and between packings, to restore
    # unpacked boxes to their original state .
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
      exploded_boxes
    end

    #
    # Preprocesses the list of Boxes by
    # . removing Boxes that are too large and place them into @unplaced_boxes
    # . stack bins if options is on
    # . presort parts for packing
    #
    def can_be_packed?(current_bin)
      return false if current_bin.nil?

      # Compute maximal stacking length/width.
      @stacking_maxlength = current_bin.length - 2 * @options.trimsize
      @stacking_maxwidth = current_bin.width - 2 * @options.trimsize

      # Depending on Bin, some Boxes may be placeable.
      @boxes += @invalid_boxes
      @invalid_boxes = []
      @boxes, @invalid_boxes = @boxes.partition { |box| box.fits_into?(@stacking_maxlength, @stacking_maxwidth) }

      return false if @boxes.empty?

      case @options.stacking
      when STACKING_LENGTH
        make_superboxes_length
      when STACKING_WIDTH
        make_superboxes_width
      end
      sort_boxes

      true
    end

    #
    # Gets the next available bin from the offcuts or produce one.
    #
    def get_next_bin
      bin = nil
      if !@bins.empty?
        bin = @bins.shift
      elsif bins_can_be_added?
        bin = Bin.new(@options.base_length, @options.base_width, BIN_TYPE_AUTO_GENERATED, @options)
        @next_bin_index = bin.set_index(@next_bin_index)
      end
      bin
    end

    #
    # Top level packing algorithm for a single Bin.
    #
    def pack
      # Remember the number of valid input boxes. Invalid boxes have been
      # removed by Packengine and will be re-added at the end.
      @gstat[:nb_input_boxes] = @boxes.size if @previous_packer.nil?

      current_bin = nil
      nb_packed_boxes = 0
      loop do
        # Get the next Bin. If there are offcuts, this will be the smallest
        # in area, if not it will be a standard Bin, or nil if no Bin can be
        # produced. At this point we do not yet have Superboxes!
        current_bin = get_next_bin
        # Packing cannot proceed, return with what we have.
        return ERROR_NO_PLACEMENT_POSSIBLE if current_bin.nil?
        # Partition the Boxes into @boxes and @invalid_boxes, those that cannot
        # fit into this bin, also makes SuperBoxes if required.
        if can_be_packed?(current_bin)
          nb_packed_boxes = pack_single(current_bin)
          # @boxes contains all Boxes that have NOT been placed, they may be
          # Superboxes. This packer is now done!

          if nb_packed_boxes > 0
            current_bin.final_bounding_box
            current_bin.keep_signature(@options.signature)
            @packed_bins << current_bin
            @unplaced_boxes = unmake_superboxes(@boxes)
            if !@invalid_boxes.empty?
              @unplaced_boxes += @invalid_boxes
              @invalid_boxes = []
            end
            postprocess(current_bin)
            @unused_bins += @bins
            @bins = []
            @boxes = []
            return ERROR_NONE
          end
        elsif current_bin.type == BIN_TYPE_USER_DEFINED
          # Boxes cannot fit into Bin, mark this Bin as unused.
          @unused_bins << current_bin
          @boxes = unmake_superboxes(@boxes)
          if !bins_can_be_added?
            # We are done with packing.
            @unplaced_boxes = @boxes
            if !@invalid_boxes.empty?
              @unplaced_boxes += @invalid_boxes
              @invalid_boxes = []
            end
            @boxes = []
            return ERROR_NO_BIN
          else
            # Reassign invalid boxes to boxes and hope they will find a Bin.
            # This is the case when an offcut cannot fit any Box, but a
            # Standard Bin can still be generated.
            @boxes += @invalid_boxes
            @invalid_boxes = []
          end
        else
          # Silently drop the last Bin, not used.
          return ERROR_NO_BIN
        end
      end
      ERROR_NO_PLACEMENT_POSSIBLE
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
          # Remove this until version 2.1 and further tests.
=begin
          if current_bin.boxes.size > 1 && box.different?(previous_box)
            current_bin.bounding_box(box, false)
            # This would be a good place to make a rectangle merge, but
            # 26.txt shows that this is not possible!
            # Only recompute bounding box when no merge is possible!
          end
=end
          score = current_bin.best_ranked_score(box)

          # No placement possible in current bin.
          if score.nil?
            #
            # Step 1: if this box is a superbox, reduce it by one. Push
            #         remaining superbox back onto the stack of boxes.
            #
            if box.is_a?(SuperBox)
              front, sbox = box.reduce
              # Push the remaining sbox back onto the stack, it was not consumed
              @boxes.unshift(sbox) unless sbox.nil?
              @boxes.unshift(front)
            else
              unused_boxes << box
            end
            #
            # At least one score was found, so there is a leftover or bin with
            # space for the current box.
            #
          else
            # Safety nets, should never happen!
            raise(Packing2DError, "No bin in packer.pack to add to #{@options.signature}!") if current_bin.nil?
            raise(Packing2DError, "No box in packer.pack to add #{@options.signature}!") if box.nil?

            leftover_index = score[0]
            box.rotate if score[2] == ROTATED
            # Caution! once the box has been placed, the leftover index is NOT VALID anymore!
            current_bin.add_box(box, leftover_index)
            previous_box = box
            nb_placed_boxes += 1
          end
        end
      rescue Packing2DError => e
        puts("Running signature #{@options.signature}")
        puts("Rescued in Packer #{e.inspect}")
        puts(e.backtrace)
        return ERROR_BAD_ERROR
      end

      @boxes = unused_boxes
      nb_placed_boxes
    end

    #
    # Collects all pieces per bin, runs statistics.
    # TODO: packer.postprocess verify that we havent lost any boxes in the packing process
    #
    def postprocess(current_bin)
      current_bin.summarize
      # Get statistics from Bin, add our own.
      @stat = current_bin.stat
      @gstat[:area_unplaced_boxes] = @unplaced_boxes.inject(0) { |sum, box| sum + box.area }
      @gstat[:nb_unplaced_boxes] = @unplaced_boxes.size
      @gstat[:nb_invalid_boxes] += @invalid_boxes.size
      @gstat[:area_unplaced_boxes] += @invalid_boxes.inject(0) { |sum, box| sum + box.area }
      @gstat[:nb_packed_bins] = @packed_bins.size
      @gstat[:nb_unused_bins] = @unused_bins.size
      @gstat[:nb_leftovers] += current_bin.stat[:nb_leftovers]
      @gstat[:nb_packed_boxes] += current_bin.stat[:nb_packed_boxes]
      @gstat[:nb_invalid_bins] += @invalid_bins.size
      @gstat[:total_length_cuts] += @stat[:length_cuts]
      @gstat[:total_nb_cuts] += @stat[:nb_cuts]
      @gstat[:nb_through_cuts] += @stat[:nb_h_through_cuts] + @stat[:nb_v_through_cuts]
      @gstat[:total_l_measure] += @stat[:l_measure]
      @gstat[:all_largest_area] += current_bin.stat[:outer_leftover_area]
      @gstat[:largest_bottom_parts] += current_bin.stat[:largest_bottom_part]
    end

    #
    # Checks if all Boxes
    #
    def no_box_left_behind(must_have_nb)
      have_nb = @gstat[:nb_packed_boxes] + @gstat[:nb_invalid_boxes] + @gstat[:nb_unplaced_boxes]
      if have_nb != must_have_nb
        p(to_str)
        raise(Packing2DError, "Lost boxes in packing process have=#{have_nb} <> must_have=#{must_have_nb}!")
      end
    end

    def all_signatures
      @packed_bins.each do |bin|
        dbg("#{bin.stat[:signature]}, L=#{bin.length}, W=#{bin.width}")
      end
    end

    #
    # Sorts used bins by efficiency. Done by interface, currently unused
    # (see packengine.rb).
    #
    def sort_bins_by_efficiency
      @packed_bins.sort_by! { |bin| -bin.stat[:efficiency] }
    end

    #
    # Debugging! Prints stuff to terminal.
    #
    def to_str
      debug_old = @options.debug
      @options.set_debug(true)

      dbg("-> Packing Summary")
      @packed_bins.each do |bin|
        dbg("\n   single packer stats #{bin.index}")
        dbg("    nb_packed_boxes            #{"%5d" % bin.stat[:nb_packed_boxes]}")
        dbg("    efficiency                #{"%6.2f" % bin.stat[:efficiency]}")
        dbg("    nb_leftovers               #{"%5d" % bin.stat[:nb_leftovers]}")
        dbg("    outer leftover      #{"%12.2f" % bin.stat[:outer_leftover_area]}")
        dbg("    length_cuts         #{"%12.2f" % bin.stat[:length_cuts]}")
        dbg("    nb_cuts                    #{"%5d" % bin.stat[:nb_cuts]}")
        dbg("    nb_h_through_cuts          #{"%5d" % bin.stat[:nb_h_through_cuts]}")
        dbg("    nb_v_through_cuts          #{"%5d" % bin.stat[:nb_v_through_cuts]}")

        dbg("\n")
        bin.to_term
      end

      dbg("\n   general stats (accumulated)")
      dbg("    nb_input_boxes             #{"%5d" % @gstat[:nb_input_boxes]}")
      dbg("    nb_invalid_boxes           #{"%5d" % @gstat[:nb_invalid_boxes]}")
      dbg("    nb_packed_boxes            #{"%5d" % @gstat[:nb_packed_boxes]}")
      dbg("    nb_unplaced_boxes          #{"%5d" % @gstat[:nb_unplaced_boxes]}")
      dbg("    nb_packed_bins             #{"%5d" % @gstat[:nb_packed_bins]}")
      dbg("    nb_unused_bins             #{"%5d" % @gstat[:nb_unused_bins]}")
      dbg("    nb_invalid_bins            #{"%5d" % @gstat[:nb_invalid_bins]}")
      dbg("    nb_leftovers               #{"%5d" % @gstat[:nb_leftovers]}")
      dbg("    all_largest_area    #{"%12.2f" % @gstat[:all_largest_area]}")
      dbg("    total_length_cuts   #{"%12.2f" % @gstat[:total_length_cuts]}")
      dbg("    total_nb_cuts              #{"%5d" % @gstat[:total_nb_cuts]}")
      dbg("    nb_through_cuts            #{"%5d" % @gstat[:nb_through_cuts]}")
      #dbg("    avg compactness           #{"%6.2f" % (@gstat[:total_compactness] / @gstat[:nb_packed_bins])}")

      dbg("\n   unused bins")
      @unused_bins.each do |bin|
        dbg("    #{bin.to_str}")
      end

      dbg("\n   invalid bins")
      @invalid_bins.each do |bin|
        dbg("    #{bin.to_str}")
      end

      dbg("\n   unplaced boxes")
      @unplaced_boxes.each do |box|
        dbg("    #{box.to_str}")
      end

      dbg("\n   invalid boxes")
      @invalid_boxes.each do |box|
        dbg("    #{box.to_str}")
      end

      @options.set_debug(debug_old)
    end

    #
    # Debugging!
    #
    def signature
      "packer id=#{@options.signature}"
    end

    #
    # Prints the packing as a Matlab/Octave graphics.
    #
    def octave(id, directory = "./results")
      dbg("-> printing octave")
      # FileUtils.rm_f Dir.glob("#{directory}/res*.m")
      @packed_bins.each do |bin|
        dbg("   bin #{bin.index}")
        filename = "#{directory}/res_#{id}_#{bin.index}.m"
        f = File.open(filename, "w")
        bin.octave(f)
      end
    end
  end
end
