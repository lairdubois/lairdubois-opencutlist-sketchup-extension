module Ladb::OpenCutList::BinPacking2D
  require_relative "packing2d"
  require_relative "options"
  require_relative "box"
  require_relative "superbox"
  require_relative "leftover"
  require_relative "bin"
  require_relative "cut"
  require_relative "packer"

  #
  # Error used by custom Timer when execution of algorithm
  # takes too long (defined in Option).
  #
  class TimeoutError < StandardError
  end

  #
  # Setup and run bin packing in 2D.
  #
  class PackEngine < Packing2D

    # List of warnings.
    attr_reader :warnings

    # Error code to be returned.
    attr_reader :errors

    # List of boxes to pack.
    attr_reader :boxes

    # List of bins.
    attr_reader :bins

    attr_reader :next_bin_index

    # Start time of the packing.
    attr_reader :start_time

    # Level of packing, i.e. nb of Bins packed so far.
    attr_reader :level

    #
    # Initializes a new PackEngine with Options.
    #
    def initialize(options)
      super

      @bins = []
      @invalid_bins = []
      @boxes = []
      @invalid_boxes = []

      @max_length_bin = 0
      @max_width_bin = 0

      @level = 0
      @nb_best_selection = BEST_X_LARGE

      @warnings = []
      @errors = []
    end

    #
    # Adds an offcut bin.
    #
    def add_bin(length, width, type = BIN_TYPE_USER_DEFINED)
      if length <= 0 || width <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BIN
      else
        @bins << Bin.new(length, width, type, @options)
      end
    end

    #
    # Adds a box to be packed into bins.
    #
    def add_box(length, width, rotatable = true, data = nil)
      if length <= 0 || width <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BOX
      else
        @boxes << Box.new(length, width, rotatable, data)
      end
    end

    #
    # Returns true if input is somewhat valid.
    #
    def valid_input?
      @errors << ERROR_NO_BOX if @boxes.empty?
      @errors << ERROR_NO_BIN if (@options.base_length < EPS || @options.base_width < EPS) && @bins.empty?
      @errors.empty?
    end

    #
    # Sets the global start time.
    #
    def start_timer(sigsize)
      dbg("-> start of packing with #{@boxes.size} box(es), #{@bins.size} bin(s) with #{sigsize} signatures")
      @start_time = Time.now
    end

    #
    # Prints total time used since start_timer.
    #
    def stop_timer(signature_size, msg)
      dbg("-> end of packing(s) nb = #{signature_size}, time = #{"%6.4f" % (Time.now - @start_time)} s, " + msg)
    end

    #
    # Builds the large signature set.
    #
    def make_signatures_large
      # Signature size will be the product of all possibilities
      # 8 * 6 * 8 = 384 => 384 * 1 or 3, Max 1152 possibilities.
      presort = (PRESORT_WIDTH_DECR..PRESORT_PERIMETER_DECR).to_a # 8
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a # 6
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a # 8
      stacking = if @options.stacking_pref <= STACKING_WIDTH
          [@options.stacking_pref]
        else
          (STACKING_NONE..STACKING_WIDTH).to_a
        end
      presort.product(score, split, stacking)
    end

    #
    # Builds the small signature set.
    #
    def make_signatures_medium
      # Signature size will be the product of all possibilities
      # 4 * 4 * 4 = 64 => 64 * 1 or 3, Max 192 possibilities
      presort = (PRESORT_WIDTH_DECR..PRESORT_AREA_DECR).to_a # 3
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTAREA_FIT).to_a # 4
      split = (SPLIT_MINIMIZE_AREA..SPLIT_VERTICAL_FIRST).to_a # 4
      stacking = if @options.stacking_pref <= STACKING_WIDTH
          [@options.stacking_pref]
        else
          (STACKING_NONE..STACKING_WIDTH).to_a
        end
      presort.product(score, split, stacking)
    end

    #
    # Prints intermediate packings.
    #
    def print_intermediate_packers(packers, level = @level)
      return unless @options.debug
      return if packers.nil?

      packers.each_with_index do |packer, i|
        # print_intermediate_packers([packer.previous_packer], level - 1) unless packer.previous_packer.nil?
        stat = packer.stat
        next if stat.nil?

        s = "#{'%3d' % level}/#{'%4d' % i}  " \
            "#{'%12.2f' % stat[:used_area]} " \
            "#{'%5.2f' % stat[:efficiency]}" \
            "#{'%5d' % stat[:nb_cuts]} " \
            "#{'%4d' % stat[:nb_h_through_cuts]} " \
            "#{'%4d' % stat[:nb_v_through_cuts]} " \
            "#{'%11.2f' % stat[:outer_leftover_area]} " \
            "#{'%11.2f' % stat[:length_cuts]} " \
            "#{'%6d' % stat[:nb_leftovers]} " \
            "#{'%8.5f' % stat[:l_measure]}" \
            "#{'%4d' % packer.gstat[:nb_unplaced_boxes]}" \
            "#{'%22s' % stat[:signature]}" \
            "#{'%3d' % stat[:rank]}"
      dbg(s)
      end
      dbg("  packer      usedArea   eff  #cuts thru h/v      leftA        cutL  #left " \
      "l_meas.                signature rank")
    end

    #
    # Prints final packings.
    #
    def print_final_packers(packers)
      return unless @options.debug
      return if packers.nil?
      packers.each_with_index do |packer, i|
        gstat = packer.gstat
        next if gstat.nil?

        s = "final /#{'%2d' % i}  " \
            "#{'%6d' % gstat[:nb_packed_bins]} " \
            "#{'%6d' % gstat[:nb_unused_bins]} " \
            "#{'%6d' % gstat[:nb_invalid_bins]} " \
            "#{'%6d' % gstat[:nb_packed_boxes]} " \
            "#{'%6d' % gstat[:nb_invalid_boxes]} " \
            "#{'%6d' % gstat[:nb_unplaced_boxes]} " \
            "#{'%6d' % gstat[:nb_leftovers]} " \
            "#{'%12.2f' % gstat[:all_largest_area]} " \
            "#{'%6d' % gstat[:total_nb_cuts]} " \
            "#{'%6d' % gstat[:nb_through_cuts]}" \
            "#{'%7.4f' % gstat[:total_l_measure]}" \
            "#{'%12.2f' % gstat[:total_length_cuts]}"
      dbg(s)
      end
      dbg("   packer    packed/unused/inv.   packed/unused/inv.  #left " \
          "   leftoverA  #cuts  #thru    ∑Lm       ∑cutL")
    end

    #
    # Selects the best packer among a list of potential packers.
    # This step is done at the end of packing to select the best packing
    # from a short list of packers. Only uses global statistics about the
    # packers.
    #
    def select_best_packing(packers)
      return nil if packers.size == 0
      packers.sort_by! { |packer| [-packer.gstat[:all_largest_area], packer.gstat[:total_l_measure], packer.gstat[:total_length_cuts]]}
      print_final_packers(packers)
      packers.first
    end

    #
    # Filter best packings. Packings are sorted according to several
    # criteria, the packing with the lowest sum of ranks is the
    # winner!
    #
    def select_best_x_packings(packers)
      packers = packers.compact
      return nil if packers.empty?

      best_packers = []

      # Check if there is at least one Packer with zero unplaced_boxes.
      packers_with_zero_left = packers.select { |packer| packer.gstat[:nb_unplaced_boxes] == 0 }
      dbg("packers with zero left = #{packers_with_zero_left.size}")

      # If that is the case, keep only Packers that did manage to pack all Boxes.
      if packers_with_zero_left.size > 0
        packers = packers_with_zero_left
      end

      # L_measure is a measure that uniquely identifies the shape of
      # a packing. Select unique l_measure Packers, sort best_packers
      # with ascending l_measure.
      p = packers.group_by { |packer| packer.stat[:l_measure] }
      p.keys.sort.each_with_index do |k, i|
        b = p[k].first
        b.stat[:rank] = i + 1
        best_packers << b
      end

      # Select best Packers for this level/Bin using the following three unweighted criteria.
      # Try to maximize the used area, i.e. area of packed Boxes.
      best_packers.sort_by! { |packer| -packer.stat[:used_area] }
      best_packers.each_with_index do |b, i|
        b.stat[:rank] += i + 1
      end

      # Try to maximize the area outside of the bounding box. We presume this
      # a more useful waste.
      best_packers.sort_by! { |packer| -packer.stat[:outer_leftover_area] }
      best_packers.each_with_index do |b, i|
        b.stat[:rank] += i + 1
      end

      # Try to maximize the number of through cuts. We presume that more through
      # cuts make the cutting diagram easier to cut.
      best_packers.sort_by! { |packer| (-packer.stat[:nb_h_through_cuts] - packer.stat[:nb_v_through_cuts]) }
      best_packers.each_with_index do |b, i|
        b.stat[:rank] += i + 1
      end

      # Sort the Packers by their rank.
      best_packers.sort_by! { |packer| packer.stat[:rank] }

      print_intermediate_packers(best_packers)

      # Return a list of possible candidates for the next Bin to pack.
      best_packers.slice(0, @nb_best_selection)
    end

    #
    # Packs next bin, starting from a set of previous bins.
    # This builds up a tree of packings where at each level
    # the attempted packings are given by the signatures.
    # Returns a list of packings.
    #
    def pack(previous_packers, signatures)
      @level += 1
      packers = []
      if previous_packers.nil?
        packers = pack_next_bin(nil, signatures)
      else
        previous_packers.each do |previous_packer|
          packers += pack_next_bin(previous_packer, signatures)
        end
      end
      return packers
    end

    #
    # Packs next Bins, returns a list of Packers.
    #
    def pack_next_bin(previous_packer, signatures)
      packers = []

      signatures.each do |signature|
        options = @options.clone
        options.presort, options.score, options.split, options.stacking = signature

        packer = Packer.new(options)
        if previous_packer.nil?
          @bins.each do |bin|
            packer.add_bin(Bin.new(bin.length, bin.width, bin.type, options, bin.index))
          end
          @boxes.each do |box|
            packer.add_box(Box.new(box.length, box.width, box.rotatable, box.data))
          end
        else
          packer.link_to(previous_packer)
        end
        err = packer.pack
        packers << packer if err == ERROR_NONE
      end
      return packers
    end

    #
    # Checks if packing is done.
    #
    def packings_done?(packers)
      return true if packers.nil? || packers.empty?

      packers.each do |packer|
        # at least one Packer has no Boxes left.
        return false unless packer.unplaced_boxes.empty?
      end
      true
    end

    #
    # Checks if Bins are available for Packer.
    #
    def bins_available?
      @next_bin_index = 0

      if @options.base_length >= EPS && @options.base_width >= EPS
        @max_length_bin = @options.base_length - 2 * @options.trimsize
        @max_width_bin = @options.base_width - 2 * @options.trimsize
      end

      # Offcuts (user defined bins) are used in increasing order of area.
      @bins.sort_by! { |bin| [bin.length * bin.width] }
      valid_bins = []
      until @bins.empty?
        bin = @bins.shift
        valid = false
        @boxes.each do |box|
          if box.fits_into?(bin.length - 2 * @options.trimsize, bin.width - 2 * @options.trimsize)
            valid = true
            break
          end
        end
        if valid
          @max_length_bin = [@max_length_bin, bin.length - 2 * @options.trimsize].max
          @max_width_bin = [@max_width_bin, bin.width - 2 * @options.trimsize].max
          @next_bin_index = bin.set_index(@next_bin_index)
          valid_bins << bin
        else
          @invalid_bins << bin
        end
      end
      @bins = valid_bins
      if @bins.empty? && @options.base_length - 2 * @options.trimsize > EPS && @options.base_width - 2 * @options.trimsize > EPS
        # If we have no Bins at all, add a Bin to start with.
        new_bin = Bin.new(@options.base_length, @options.base_width, BIN_TYPE_AUTO_GENERATED, @options)
        @next_bin_index = new_bin.set_index(@next_bin_index)
        @max_length_bin = @options.base_length - 2 * @options.trimsize
        @max_width_bin = @options.base_width - 2 * @options.trimsize
        @bins << new_bin
      end
      @boxes, @invalid_boxes = @boxes.partition { |box| box.fits_into?(@max_length_bin, @max_width_bin) }
      if @boxes.empty?
        @errors << ERROR_NO_PLACEMENT_POSSIBLE
        return false
      end
      if @bins.empty?
        @errors << ERROR_NO_BIN
        return false
      end
      true
    end

    #
    # Checks for consistency, creates multiple Packers and runs them.
    # Returns best packing by selecting best packing at each stage.
    #
    def run
      return nil, @errors[0] if !valid_input? && @errors.size > 0

      if !bins_available?
        return nil, @errors.first
      end

      case @options.optimization
      when OPT_MEDIUM
        signatures = make_signatures_medium
        @nb_best_selection = BEST_X_SMALL
      when OPT_ADVANCED
        signatures = make_signatures_large
        @nb_best_selection = BEST_X_SMALL if @boxes.size < MAX_BOXES_TIME
      else
        @errors << ERROR_INVALID_INPUT
        return nil, @errors.first
      end

      # Use this to run exactly one signature
      # Parameters are presort, score, split, stacking
      #signatures = [[2,5,6,0]]

      # Not a super precise way of measuring compute time.
      start_timer(signatures.size)

      begin
        packers = pack(nil, signatures)
        if packers.empty?
          @errors << ERROR_NO_PLACEMENT_POSSIBLE
          return nil, @errors.first
        end

        while !packings_done?(packers)
          packers = select_best_x_packings(packers)
          last_packers = packers
          packers = pack(packers, signatures)
        end

        if !packers.nil? && !packers.empty?
          last_packers = select_best_x_packings(packers)
        end
      rescue TimeoutError => e
        puts ("Rescued in PackEngine: #{e.inspect}")
        # TODO: packengine timeout error, we should return the best solution found so far
        # but this is dangerous, since it can lead to different versions.
        @errors << ERROR_TIMEOUT
        return nil, @errors.first
      rescue Packing2DError => e
        puts ("Rescued in PackEngine: #{e.inspect}")
        puts e.backtrace
        @errors << ERROR_BAD_ERROR
        return nil, @errors.first
      end

      # TODO: We do not yet make a distinction between invalid and unplaceable box in the GUI.
      # invalid_bins and invalid_boxes here are global! they cannot fit each other
      if !@invalid_boxes.empty?
        last_packers.each do |packer|
          packer.add_invalid_boxes(@invalid_boxes)
          packer.add_invalid_bins(@invalid_bins)
        end
      end
      opt = select_best_packing(last_packers)
      stop_timer(signatures.size, "#{last_packers[0].packed_bins.size} bin(s)")
      # last_packings is an array of 1-3 packings! depending on the BEST_X in options.rb.
      # For now, just returning the "best" one.
      # WARNING: Packers, essentially a list of packed Bins containers, are NOT sorted by efficiency!
      @errors << ERROR_NONE
      return opt, @errors.first
    end
  end
end
