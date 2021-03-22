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
      @nb_input_boxes = 0

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
    # Adds a Box to be packed into Bins.
    #
    def add_box(length, width, rotatable = true, data = nil)
      if length <= 0 || width <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BOX
      else
        @boxes << Box.new(length, width, rotatable, data)
      end
    end

    #
    # Dumps the packing.
    #
    def dump
      puts("# OpenCutList BinPacking2D Dump")
      if @options.rotatable
        rotatable_str = "r"
      else
        rotatable_str = "nr"
      end
      puts("#{@options.saw_kerf}, #{@options.trimsize}, #{rotatable_str}")
      puts("#{@options.base_length} #{@options.base_width}")
      @bins.each do |bin|
        puts("#{bin.length} #{bin.width}")
      end
      @boxes.each do |box|
        puts("#{box.length} #{box.width} #{box.rotatable}")
      end
      puts("==")
    end

    #
    # Returns true if input is somewhat valid.
    #
    def valid_input?
      if @boxes.empty?
        @errors << ERROR_NO_BOX
      else
        @nb_input_boxes = @boxes.size
      end
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
      # 6 * 6 * 6 = 216 => 216 * 1 or 3, Max 648 possibilities.
      presort = (PRESORT_WIDTH_DECR..PRESORT_SHORTEST_SIDE_DECR).to_a # 6
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a # 6
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a # 6
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
      split = (SPLIT_MINIMIZE_AREA..SPLIT_LONGER_AXIS).to_a # 4
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
    def print_intermediate_packers(packers, level = @level, no_footer = false)
      return unless @options.debug
      return if packers.nil?

      packers.each_with_index do |packer, i|
        #print_intermediate_packers([packer.previous_packer], level - 1, true) unless packer.previous_packer.nil?
        stat = packer.stat
        next if stat.nil?

        s = "#{'%3d' % level}/#{'%4d' % i}  " \
            "#{'%12.2f' % stat[:used_area]} " \
            "#{'%5.2f' % stat[:efficiency]}" \
            "#{'%5d' % stat[:nb_cuts]} " \
            "#{'%4d' % stat[:nb_h_through_cuts]} " \
            "#{'%4d' % stat[:nb_v_through_cuts]} " \
            "#{'%11.2f' % stat[:largest_bottom_part]} " \
            "#{'%11.2f' % stat[:length_cuts]} " \
            "#{'%6d' % stat[:nb_leftovers]} " \
            "#{'%8.5f' % stat[:l_measure]}" \
            "#{'%4d' % packer.gstat[:nb_unplaced_boxes]}" \
            "#{'%22s' % stat[:signature]}" \
            "#{'%3d' % stat[:rank]}"
        dbg(s)
      end
      dbg("  packer      usedArea   eff  #cuts thru h/v      bottA        cutL  #left " \
      "l_meas.                signature rank") if !no_footer
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
            "#{'%12.2f' % gstat[:largest_bottom_parts]} " \
            "#{'%6d' % gstat[:total_nb_cuts]} " \
            "#{'%6d' % gstat[:nb_through_cuts]}" \
            "#{'%7.4f' % gstat[:total_l_measure]}" \
            "#{'%12.2f' % gstat[:total_length_cuts]}" \
            "#{'%3d' % gstat[:rank]}"
      dbg(s)
      packer.all_signatures
      end
      dbg("   packer    packed/unused/inv.   packed/unplac./inv.  #left " \
          "  leftoverA  #cuts  #thru    ∑Lm       ∑cutL rank")
    end

    #
    # Updates the global ranking per packing.
    #
    def update_rank_per_packing(packers, crit, ascending)
      crit_coll = packers.collect { |packer| packer.gstat[crit] }.uniq.sort
      crit_coll.reverse! if !ascending

      ranks = crit_coll.map { |e| crit_coll.index(e) + 1}
      h = Hash[[crit_coll, ranks].transpose]
      packers.each do |b|
        b.gstat[:rank] += h[b.gstat[crit]]
      end
    end

    #
    # Selects the best packer among a list of potential packers.
    # This step is done at the end of packing to select the best packing
    # from a short list of packers. Only uses global statistics about the
    # packers.
    #
    def select_best_packing(packers)
      return nil if packers.size == 0

      stacking_pref = packers[0].options.stacking_pref
      update_rank_per_packing(packers, :largest_bottom_parts, false)

      case stacking_pref
      when STACKING_LENGTH
        update_rank_per_packing(packers, :nb_through_cuts, false)
      when STACKING_WIDTH
        update_rank_per_packing(packers, :nb_through_cuts, false)
      end

      packers.sort_by! { |packer| [packer.gstat[:rank], packer.gstat[:total_l_measure], packer.gstat[:nb_leftovers]] }
      print_final_packers(packers)
      packers.first
    end

    #
    # Updates @stat[:rank] of each individual packer.
    #
    def update_rank_per_bin(packers, crit, ascending)
      crit_coll = packers.collect { |packer| packer.stat[crit] }.uniq.sort
      crit_coll.reverse! if !ascending
      ranks = crit_coll.map { |e| crit_coll.index(e) + 1}
      h = Hash[[crit_coll, ranks].transpose]
      packers.each do |b|
        b.stat[:rank] += h[b.stat[crit]]
      end
    end

    #
    # Filter best packings. Packings are sorted according to several
    # criteria, the packing with the lowest sum of ranks is the
    # winner!
    #
    def select_best_x_packings(packers)
      #print_intermediate_packers(packers)
      zero_left = false
      packers = packers.compact
      return nil if packers.empty?

      stacking_pref = packers[0].options.stacking_pref

      best_packers = []

      # Check if there is at least one Packer with zero unplaced_boxes.
      packers_with_zero_left = packers.select { |packer| packer.gstat[:nb_unplaced_boxes] == 0 }
      dbg("packers with zero left = #{packers_with_zero_left.size}")

      # If that is the case, keep only Packers that did manage to pack all Boxes.
      if packers_with_zero_left.size > 0
        zero_left = true
        packers = packers_with_zero_left
      end

      # L_measure is a measure that uniquely identifies the shape of
      # a packing if it is not perfectly compact, i.e. = 0. Select unique
      # l_measure Packers, sort best_packers by ascending l_measure.
      packers_group = packers.group_by { |packer| packer.stat[:l_measure] }
      packers_group.keys.sort.each_with_index do |k, i|
        if zero_left
          b = packers_group[k].sort_by { |p| [p.gstat[:total_l_measure], -p.gstat[:largest_bottom_parts]] }.first
        else
          b = packers_group[k].sort_by { |p| [-p.stat[:efficiency], p.stat[:l_measure]] }.first
        end
        b.stat[:rank] = i + 1
        best_packers << b
      end

      # Select best Packers for this level/Bin using the following unweighted criteria.
      # Try to maximize the used area, i.e. area of packed Boxes. This does minimize at the
      # same time the area of unused Boxes. It is equal to efficiency.
      update_rank_per_bin(packers, :used_area, false)

      case stacking_pref
      when STACKING_NONE
        update_rank_per_bin(packers, :total_length_cuts, true)
      when STACKING_LENGTH
        update_rank_per_bin(packers, :nb_h_through_cuts, false)
        update_rank_per_bin(packers, :largest_bottom_part, false)
      when STACKING_WIDTH
        update_rank_per_bin(packers, :nb_v_through_cuts, false)
      when STACKING_ALL
        update_rank_per_bin(packers, :nb_h_through_cuts, false)
        update_rank_per_bin(packers, :largest_bottom_part, false)
      end

      # Sort the Packers by their rank.
      best_packers.sort_by! { |packer| packer.stat[:rank] }

      print_intermediate_packers(best_packers.slice(0, @nb_best_selection))

      # Return a list of possible candidates for the next Bin to pack.
      best_packers = best_packers.slice(0, @nb_best_selection)
      best_packers
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

        # A new packer is created for each signature
        packer = Packer.new(options)

        if previous_packer.nil?
          # The first level packer gets copies of all bins and boxes
          @bins.each do |bin|
            packer.add_bin(Bin.new(bin.length, bin.width, bin.type, options, bin.index))
          end
          @boxes.each do |box|
            packer.add_box(Box.new(box.length, box.width, box.rotatable, box.data))
          end
        else
          # The second level packer will retrieve unplaced boxes and unused bins
          # from his predecessor
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
    # Checks if Bins are available for Packer, removes
    # Boxes that are too large to fit any Bin, removes
    # Bins that are too small to enclose any Box.
    #
    def bins_available?
      @next_bin_index = 0

      # If base Bin is possible, start with this size
      if @options.base_length - 2 * @options.trimsize > EPS &&  @options.base_width - 2 * @options.trimsize > EPS
        @max_length_bin = @options.base_length
        @max_width_bin = @options.base_width
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

      # Only these Bins are valid
      @bins = valid_bins

      # If we have no Bins at all, add a Bin to start with.
      if @bins.empty? && @options.base_length - 2 * @options.trimsize > EPS && @options.base_width - 2 * @options.trimsize > EPS
        new_bin = Bin.new(@options.base_length, @options.base_width, BIN_TYPE_AUTO_GENERATED, @options)
        @next_bin_index = new_bin.set_index(@next_bin_index)
        @max_length_bin = @options.base_length - 2 * @options.trimsize
        @max_width_bin = @options.base_width - 2 * @options.trimsize
        @bins << new_bin
      end
      @boxes, @invalid_boxes = @boxes.partition { |box| box.fits_into?(@max_length_bin, @max_width_bin) }

      # There are no Boxes left to fit
      if @boxes.empty?
        @errors << ERROR_NO_PLACEMENT_POSSIBLE
        return false
      end
      # No Bins to pack Boxes
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
      return nil, @errors.first if !valid_input? && @errors.size > 0

      return nil, @errors.first if !bins_available?

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
      # signatures = [[2,0,2,1]]

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
        @warnings << WARNING_ILLEGAL_SIZED_BOX
        last_packers.each { |packer| packer.add_invalid_boxes(@invalid_boxes) }
      end
      if !@invalid_bins.empty?
        @warnings << WARNING_ILLEGAL_SIZED_BIN
        last_packers.each { |packer| packer.add_invalid_bins(@invalid_bins) }
      end

      # Get the best packer
      opt = select_best_packing(last_packers)
      stop_timer(signatures.size, "#{last_packers[0].packed_bins.size} bin(s)")

      # Check validity by checking if we still have all boxes :-)
      begin
        opt.no_box_left_behind(@nb_input_boxes)
      rescue Packing2DError => e
        dump
        puts("Rescued in PackEngine: #{e.inspect}")
        @errors << ERROR_BAD_ERROR
        return nil, ERROR_BAD_ERROR
      end

      @errors << ERROR_NONE if @errors.empty?
      return opt, @errors.first
    end
  end
end
