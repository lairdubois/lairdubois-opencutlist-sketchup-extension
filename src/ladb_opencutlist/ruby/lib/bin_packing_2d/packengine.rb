# frozen_string_literal: true

#
# Top level entry point to Bin Packing
#
module Ladb::OpenCutList::BinPacking2D
  require_relative 'packing2d'
  require_relative 'options'
  require_relative 'box'
  require_relative 'superbox'
  require_relative 'leftover'
  require_relative 'bin'
  require_relative 'cut'
  require_relative 'packer'
  #
  # TimeoutError: Error used by custom Timer when execution of algorithm
  # takes too long (defined in Option).
  #
  class TimeoutError < StandardError
  end

  #
  # Packing2D: Setup and run bin packing in 2D.
  #
  class PackEngine < Packing2D
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

      @total_area = 0
      @signatures = nil
      @last_packers = nil
      @step = 0
      @packers = nil

      @done = false
      @warnings = []
      @errors = []
    end

    #
    # Adds an off-cut bin.
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
    def add_box(length, width, rotatable = true, cid = nil, data = nil)
      if length <= 0 || width <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BOX
      else
        @total_area += (length * width)
        @boxes << Box.new(length, width, rotatable, cid, data)
      end
    end

    #
    # Dumps the packing.
    #
    def dump
      puts('# OpenCutList BinPacking2D Dump')
      rotatable_str = if @options.rotatable
                        'r'
                      else
                        'nr'
                      end
      puts("#{@options.saw_kerf}, #{@options.trimsize}, #{rotatable_str}")
      # At least one bin has been made, so we don't need to add it here
      @bins.each do |bin|
        puts("#{bin.length} #{bin.width}")
      end
      @boxes.each do |box|
        puts("#{box.length} #{box.width} #{box.rotatable}")
      end
      puts('==')
    end

    #
    # Checks if Bins are available for Packer, removes
    # Boxes that are too large to fit any Bin, removes
    # Bins that are too small to enclose any Box.
    #
    def bins_available?
      @next_bin_index = 0

      # If base Bin is possible, start with this size
      if (@options.base_length - (2 * @options.trimsize)) > EPS && (@options.base_width - (2 * @options.trimsize)) > EPS
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
          if box.fits_into?(bin.length - (2 * @options.trimsize), bin.width - (2 * @options.trimsize))
            valid = true
            break
          end
        end
        if valid
          @max_length_bin = [@max_length_bin, bin.length - (2 * @options.trimsize)].max
          @max_width_bin = [@max_width_bin, bin.width - (2 * @options.trimsize)].max
          @next_bin_index = bin.update_index(@next_bin_index)
          valid_bins << bin
        else
          @invalid_bins << bin
        end
      end

      # Only these Bins are valid
      @bins = valid_bins

      # If we have no Bins at all, add a Bin to start with.
      if @bins.empty? && (@options.base_length - (2 * @options.trimsize) > EPS) && \
         (@options.base_width - (2 * @options.trimsize) > EPS)
        new_bin = Bin.new(@options.base_length, @options.base_width, BIN_TYPE_AUTO_GENERATED, @options)
        @next_bin_index = new_bin.update_index(@next_bin_index)
        @max_length_bin = @options.base_length - (2 * @options.trimsize)
        @max_width_bin = @options.base_width - (2 * @options.trimsize)
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
    # Returns true if input is somewhat valid.
    #
    def valid_input?
      max_dim = [@options.base_length, @options.base_width, @max_length_bin, @max_width_bin].max

      # these are most likely errors, even if there could be some cases
      # where it might still work
      @errors << ERROR_PARAMETERS if @options.saw_kerf >= max_dim
      @errors << ERROR_PARAMETERS if (@options.trimsize * 2.0) >= max_dim

      @errors << ERROR_NO_BOX if @boxes.empty?
      @nb_input_boxes = @boxes.size

      @errors.empty?
    end

    #
    # Prints intermediate packings.
    #
    def print_intermediate_packers(packers, level = @level, no_footer = false)
      return unless @options.debug

      return if packers.nil?

      packers.each_with_index do |packer, i|
        # print_intermediate_packers([packer.previous_packer], level - 1, true) unless packer.previous_packer.nil?
        stat = packer.stat
        next if stat.nil?

        s = "#{format('%3d', level)}/#{format('%4d', i)}  " \
            "#{format('%12.2f', stat[:used_area])} " \
            "#{format('%5.2f', stat[:efficiency])}" \
            "#{format('%5d', stat[:nb_cuts])} " \
            "#{format('%4d', stat[:nb_h_through_cuts])} " \
            "#{format('%4d', stat[:nb_v_through_cuts])} " \
            "#{format('%11.2f', stat[:largest_leftover_area])} " \
            "#{format('%11.2f', stat[:length_cuts])} " \
            "#{format('%6d', stat[:nb_leftovers])} " \
            "#{format('%8.5f', stat[:l_measure])}" \
            "#{format('%2d', stat[:h_together])}" \
            "#{format('%2d', stat[:v_together])}" \
            "#{format('%4d', packer.gstat[:nb_unplaced_boxes])}" \
            "#{format('%22s', stat[:signature])}" \
            "#{format('%4d', stat[:rank])}"
        dbg(s)
      end
      return if no_footer

      dbg('  packer      usedArea   eff  #cuts thru h/v      bottA        cutL  #left ' \
          'l_meas. h_t v_t                signature  rank')
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

        s = "final /#{format('%2d', i)}  " \
            "#{format('%6d', gstat[:nb_packed_bins])} " \
            "#{format('%6d', gstat[:nb_unused_bins])} " \
            "#{format('%6d', gstat[:nb_invalid_bins])} " \
            "#{format('%6d', gstat[:nb_packed_boxes])} " \
            "#{format('%6d', gstat[:nb_invalid_boxes])} " \
            "#{format('%6d', gstat[:nb_unplaced_boxes])} " \
            "#{format('%6d', gstat[:nb_leftovers])} " \
            "#{format('%12.2f', gstat[:largest_leftover_area])} " \
            "#{format('%6d', gstat[:total_nb_cuts])} " \
            "#{format('%6d', gstat[:nb_through_cuts])}" \
            "#{format('%2d', gstat[:cuts_together_count])}" \
            "#{format('%10.5f', gstat[:total_l_measure])}" \
            "#{format('%12.2f', gstat[:total_length_cuts])}" \
            "#{format('%3d', gstat[:rank])}"
        dbg(s)
      end
      dbg('   packer    packed/unused/inv.   packed/unplac./inv.  #left   ' \
          'leftoverA  #cuts  #thru tg    ∑Lm       ∑cutL rank')
    end

    #
    # Set the global start time.
    #
    def start_timer(sigsize)
      dbg("-> start of packing with #{@boxes.size} box(es), #{@bins.size} bin(s) with #{sigsize} signatures")
      @start_time = Time.now
    end

    #
    # Print total time used since start_timer.
    #
    def stop_timer(signature_size, msg)
      dbg("-> end of packing(s) nb = #{signature_size}, time = #{format('%6.4f', (Time.now - @start_time))} s, " + msg)
    end

    #
    # Return value of done.
    #
    def done?
      @done
    end

    #
    # Return true if at least one error.
    #
    def errors?
      !@errors.empty?
    end

    #
    # Return all errors, worst in front.
    #
    def get_errors
      returned_errors = [ERROR_NONE, ERROR_NO_BIN, ERROR_PARAMETERS,
                         ERROR_NO_PLACEMENT_POSSIBLE, ERROR_BAD_ERROR]
      if (@errors & returned_errors).size != @errors.size
        # delete this value and put in front if errors contain
        # more than what should be returned
        @errors.delete(ERROR_BAD_ERROR)
        @errors.unshift(ERROR_BAD_ERROR)
      end
      @errors
    end

    #
    # Return warnings.
    #
    def get_warnings
      @warnings
    end

    #
    # Get number of estimated steps. In each step a single bin will be packed.
    #
    def get_estimated_steps
      e = if @options.base_length > 0 && @options.base_width > 0
            ((@total_area * 1.5) / (@options.base_length * @options.base_width)).ceil
          else
            @bins.size
          end
      [e, @signatures.size]
    end

    #
    # Check if packing is done.
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
    # Update the global ranking per packing.
    #
    def update_rank_per_packing(packers, criterion, ascending)
      criterion_coll = packers.collect { |packer| packer.gstat[criterion] }.uniq.sort
      criterion_coll.reverse! unless ascending

      ranks = criterion_coll.map { |e| criterion_coll.index(e) + 1 }
      h = Hash[[criterion_coll, ranks].transpose]
      packers.each do |b|
        b.gstat[:rank] += h[b.gstat[criterion]]
      end
    end

    #
    # Select the best packer among a list of potential packers.
    # This step is done at the end of packing to select the best packing
    # from a short list of packers. Only uses global statistics about the
    # packers.
    #
    def select_best_packing(packers)
      return nil if packers.empty?

      if packers[0].gstat[:nb_packed_bins] == 1
        packers.sort_by! do |packer|
          [-packer.gstat[:largest_leftover_area],
           packer.gstat[:total_l_measure]]
        end
      else
        packers.sort_by! do |packer|
          [-packer.gstat[:largest_bottom_parts],
           packer.gstat[:total_length_cuts],
           -packer.gstat[:cuts_together_count]]
        end
      end
      print_final_packers(packers)
      packers.first
    end

    #
    # Update @stat[:rank] of each individual packer.
    #
    def update_rank_per_bin(packers, criterion, ascending)
      criterion_coll = packers.collect { |packer| packer.stat[criterion] }.uniq.sort
      criterion_coll.reverse! unless ascending
      ranks = criterion_coll.map { |e| criterion_coll.index(e) + 1 }
      h = Hash[[criterion_coll, ranks].transpose]
      packers.each do |b|
        b.stat[:rank] += h[b.stat[criterion]]
      end
    end

    #
    # Filter best packings. Packings are sorted according to several
    # criteria, the packing with the lowest sum of ranks is the
    # winner!
    #
    def select_best_x_packings(packers)
      packers = packers.compact
      return nil if packers.empty?

      stacking_pref = packers[0].options.stacking_pref
      # rotatable = packers[0].options.rotatable
      # nb_packed = packers[0].stat[:nb_packed_boxes]

      # Check if there is at least one Packer with zero unplaced_boxes.
      packers_with_zero_left = packers.select { |p| p.gstat[:nb_unplaced_boxes] == 0 }
      dbg("packers with zero left = #{packers_with_zero_left.size}")

      # If that is the case, keep only Packers that did manage to pack all Boxes.
      packers = packers_with_zero_left unless packers_with_zero_left.empty?
      print_intermediate_packers(packers)

      # L_measure is a measure that uniquely identifies the shape of
      # a packing if it is not perfectly compact, i.e. = 0.
      best_packers = [
        packers.min_by { |p| p.stat[:l_measure] },
        packers.min_by { |p| p.stat[:nb_cuts] },
        packers.min_by { |p| p.stat[:nb_leftovers] },
        packers.max_by { |p| p.stat[:efficiency] },
        packers.max_by { |p| p.stat[:largest_leftover_area] }
      ]

      # Make sure they are unique if we have more than one
      best_packers.uniq!{ |p| p.object_id } if best_packers.length > 1

      dbg("best packers = #{best_packers.size}")

      # Select best Packers for this level/Bin using the following unweighted criteria.
      # Try to maximize the used area, i.e. area of packed Boxes. This does minimize at the
      # same time the area of unused Boxes. It is equal to efficiency within a group
      # of the same l_measure.

      update_rank_per_bin(best_packers, :l_measure, true)
      update_rank_per_bin(best_packers, :nb_leftovers, true)
      update_rank_per_bin(best_packers, :efficiency, false)
      update_rank_per_bin(best_packers, :largest_leftover_area, false)

      case stacking_pref
      when STACKING_LENGTH
        update_rank_per_bin(best_packers, :nb_h_through_cuts, false)
        update_rank_per_bin(best_packers, :nb_v_through_cuts, false)
        update_rank_per_bin(best_packers, :h_together, false)
      when STACKING_WIDTH
        update_rank_per_bin(best_packers, :nb_v_through_cuts, false)
        update_rank_per_bin(best_packers, :nb_h_through_cuts, false)
        update_rank_per_bin(best_packers, :v_together, false)
      when STACKING_ALL
        update_rank_per_bin(best_packers, :v_together, false)
        update_rank_per_bin(best_packers, :h_together, false)
        update_rank_per_bin(best_packers, :nb_h_through_cuts, false)
        update_rank_per_bin(best_packers, :nb_v_through_cuts, false)
      else # same as STACKING_NONE
        update_rank_per_bin(best_packers, :nb_h_through_cuts, false)
        update_rank_per_bin(best_packers, :nb_v_through_cuts, false)
      end

      # Return a list of possible candidates for the next Bin to pack.
      best_packers.sort_by! { |packer| packer.stat[:rank] }
      best_packers.slice(0, @nb_best_selection)
    end

    #
    # Build the large signature set.
    #
    def make_signatures_large
      # Signature size will be the product of all possibilities
      # 8 * 6 * 6 = 288 => 288 * 1 or 3, Max 864 possibilities.
      presort = (PRESORT_WIDTH_DECR..PRESORT_LARGEST_DIFF_DECR).to_a # 8
      score = (SCORE_BESTAREA_FIT..SCORE_BESTLENGTH_FIT).to_a # 6
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a # 6
      stacking = if @options.stacking_pref <= STACKING_WIDTH
                   [@options.stacking_pref]
                 else
                   (STACKING_NONE..STACKING_WIDTH).to_a
                 end
      presort.product(score, split, stacking)
    end

    #
    # Build the small signature set.
    #
    def make_signatures_medium
      # Signature size will be the product of all possibilities
      # 4 * 4 * 4 = 64 => 64 * 1 or 3, Max 192 possibilities
      presort = (PRESORT_WIDTH_DECR..PRESORT_AREA_DECR).to_a # 4
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
    # Pack next bin, starting from a set of previous bins.
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
      packers
    end

    #
    # Pack next Bins, returns a list of Packers.
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
            packer.add_box(Box.new(box.length, box.width, box.rotatable, box.cid, box.data))
          end
        else
          # The second level packer will retrieve unplaced boxes and unused bins
          # from his predecessor
          packer.link_to(previous_packer)
        end
        err = packer.pack
        packers << packer if err == ERROR_NONE
      end
      packers
    end

    #
    # Run all steps at once.
    #
    def runall
      start
      run until done? || errors?
      if errors?
        err = get_errors.first
        [nil, err]
      else
        finish
      end
    end

    #
    # Checks for consistency, creates multiple Packers and runs them.
    # Returns best packing by selecting best packing at each step.
    #
    def start
      return unless bins_available?
      return unless valid_input?

      case @options.optimization
      when OPT_MEDIUM
        @signatures = make_signatures_medium
        @nb_best_selection = BEST_X_SMALL
      when OPT_ADVANCED
        @signatures = make_signatures_large
        @nb_best_selection = BEST_X_SMALL if @boxes.size < MAX_BOXES_TIME
      else
        @errors << ERROR_INVALID_INPUT
        return
      end

      # Use this to run exactly one signature
      # Parameters are presort, score, split, stacking
      # @signatures = [[5,0,3,0]]

      # Not a super precise way of measuring compute time.
      start_timer(@signatures.size)
      @step = 1
    end

    #
    # Run by packing 1 bin at a time.
    #
    def run
      if @step == 0
        @errors << ERROR_STEP_BY_STEP
        return
      end
      begin
        if @step == 1
          @packers = pack(nil, @signatures)
          if @packers.empty?
            @errors << ERROR_NO_PLACEMENT_POSSIBLE
            @done = true
          end
          @step += 1
        else
          if packings_done?(@packers)
            @done = true
            @last_packers = select_best_x_packings(@packers) if (!@packers.nil?) && (!@packers.empty?)
          else
            @packers = select_best_x_packings(@packers)
            @last_packers = @packers
            @packers = pack(@packers, @signatures)
          end
          @step += 1
        end
      rescue TimeoutError => e
        puts("Rescued in PackEngine: #{e.inspect}")
        # TODO: packengine timeout error, we should return the best solution found so far
        # but this is dangerous, since it can lead to different versions.
        @errors << ERROR_TIMEOUT
        return nil, @errors.first
      rescue Packing2DError => e
        puts("Rescued in PackEngine: #{e.inspect}")
        puts e.backtrace
        @errors << ERROR_BAD_ERROR
        return nil, @errors.first
      end
    end

    def finish
      # TODO: We do not yet make a distinction between invalid and not placeable box in the GUI.
      # invalid_bins and invalid_boxes here are global! they cannot fit each other

      # Cannot finish on unfinished packing!
      unless @done
        @errors << ERROR_STEP_BY_STEP
        return
      end
      unless @invalid_boxes.empty?
        @warnings << WARNING_ILLEGAL_SIZED_BOX
        @last_packers.each { |packer| packer.add_invalid_boxes(@invalid_boxes) }
      end
      unless @invalid_bins.empty?
        @warnings << WARNING_ILLEGAL_SIZED_BIN
        @last_packers.each { |packer| packer.add_invalid_bins(@invalid_bins) }
      end

      # Get the best packer
      opt = select_best_packing(@last_packers)
      stop_timer(@signatures.size, "#{@last_packers[0].packed_bins.size} bin(s)")

      # Check validity by checking if we still have all boxes :-)
      # Invalid boxes have been removed before running the algorithm!
      begin
        opt.no_box_left_behind(@nb_input_boxes)
      rescue Packing2DError => e
        dump
        puts("Rescued in PackEngine: #{e.inspect}")
        @errors << ERROR_BAD_ERROR
        [nil, get_errors.first]
      end

      opt.packed_bins.each(&:mark_keep)

      @errors << ERROR_NONE unless errors?
      [opt, get_errors.first]
    end
  end
end
