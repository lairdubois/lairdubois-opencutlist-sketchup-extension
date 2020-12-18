module Ladb::OpenCutList::BinPacking2D

  require_relative 'packing2d'
  require_relative 'box'
  require_relative 'superbox'
  require_relative 'leftover'
  require_relative 'bin'
  require_relative 'cut'
  require_relative 'packer'
  require_relative 'options'

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

    # Start time of the packing.
    attr_reader :start_time

    #
    # Initializes a new PackEngine with Options.
    #
    def initialize(options)
      super

      @bins = []
      @boxes = []

      @warnings = []
      @errors = []

      @run_id = 0
    end

    #
    # Adds an offcut bin.
    #
    def add_bin(length, width, type = BIN_TYPE_USER_DEFINED)
      if length <= 0 || width <= 0 then
        @warnings << WARNING_ILLEGAL_SIZED_BIN
      else
        @bins << Bin.new(length, width, type, @options)
      end
    end

    #
    # Adds a box to be packed into bins.
    #
    def add_box(length, width, rotatable=true, data = nil)
      if length <= 0 || width <= 0 then
        @warnings << WARNING_ILLEGAL_SIZED_BOX
      else
        @boxes << Box.new(length, width, rotatable, data)
      end
    end

    #
    # Returns true if input is somewhat valid.
    #
    def valid_input?
      if @boxes.empty?
        @errors << ERROR_NO_BOX
      end
      if (@options.base_length < EPS || @options.base_width < EPS) && @bins.empty?
        @errors << ERROR_NO_BIN
      end
      return @errors.empty?
    end

    #
    # Sets the global start time.
    #
    def start_timer(sigsize)
      dbg("-> start of packing with #{@boxes.size} box(es), #{@bins.size} bin(s) with #{sigsize} signatures", true)
      @start_time = Time.now
    end

    #
    # Prints total time used since start_timer.
    #
    def stop_timer(signature_size, msg)
      dbg("-> end of packing(s) nb = #{signature_size}, time = #{'%6.4f' % (Time.now - @start_time)} s, " + msg, true)
    end

    #
    # Builds the large signature set.
    #
    def get_signatures_large
      presort = (PRESORT_WIDTH_DECR..PRESORT_LONGEST_SIDE_DECR).to_a
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_VERTICAL_FIRST).to_a
      if @options.stacking_pref <= STACKING_WIDTH
        stacking = [@options.stacking_pref]
      else
        stacking = (STACKING_LENGTH..STACKING_WIDTH).to_a
      end
      return presort.product(score, split, stacking)
    end

    #
    # Builds the medium signature set.
    #
    def get_signatures_medium
      presort = (PRESORT_WIDTH_DECR..PRESORT_LONGEST_SIDE_DECR).to_a
      score = (SCORE_BESTAREA_FIT..SCORE_BESTLONGSIDE_FIT).to_a
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_VERTICAL_FIRST).to_a
      if @options.stacking_pref <= STACKING_WIDTH
        stacking = [@options.stacking_pref]
      else
        stacking = (STACKING_LENGTH..STACKING_WIDTH).to_a
      end
      return presort.product(score, split, stacking)
    end

    #
    # Builds the small signature set.
    #
    def get_signatures_small
      # signature size will be
      # 2 presort
      # 4 score
      # 2 split
      # 1 or 2 stacking
      # = 2*4*2*1 =
      presort = (PRESORT_WIDTH_DECR..PRESORT_AREA_DECR).to_a
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTAREA_FIT).to_a
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGERLEFTOVER_AXIS).to_a
      if @options.stacking_pref <= STACKING_WIDTH
        stacking = [@options.stacking_pref]
      else
        stacking = (STACKING_NONE..STACKING_WIDTH).to_a
      end
      return presort.product(score, split, stacking)
    end

    #
    # Prints packings
    #
    def print_packings(packings)
      dbg("-> print_packings", true)
      return if packings.nil?
      packings.each do |packing|
        stat = packing.stat
        gstat = packing.gstat
        next if stat.nil?
        s = "#{'%4d' % gstat[:nb_packed_bins]} "
        s += "#{'%12.2f' % stat[:area_unplaced_boxes]} "
        s += "#{'%12.2f' % stat[:compactness]} "
        s += "#{'%8.2f' % stat[:l_measure]} "
        s += "#{'%4d' % stat[:nb_cuts]} "
        s += "#{'%12.2f' % stat[:largest_leftover_area]} "
        s += "#{'%15.2f' % stat[:total_length_cuts]} "
        s += "#{'%6d' % stat[:nb_leftovers]}"
        s += "#{'%22s' % stat[:signature]}"
        dbg(s, true)
      end
      dbg("   bins  unpacked  compactness      l_m   nbcuts max_leftover     cutlength leftovers          signature", true)
    end

    def update_ranking_by(packings, criterion, find_min)
      #print_packings(packings)
      if find_min
        packings.sort_by!{ |p| p.stat[criterion] }
      else
        packings.sort_by!{ |p| -p.stat[criterion] }
      end

      rank = 1
      last_n = nil
      packings.each do |p|
        last_n = p if last_n.nil?
        if (p.stat[criterion] - last_n.stat[criterion]).abs <= EPS
          p.stat[:rank] += rank
        else
          last_n = p
          rank +=1
          p.stat[:rank] += rank
        end
      end
      #packings.each_with_index do |p, i|
      #  puts("#{'%20.8f' % p.stat[criterion]} => #{'%3d' % p.stat[:rank]}")
      #end
    end
    #
    # Filter best packings. Only compare packings that pack the maximum possible
    # boxes in the minimum number of bins, everything else is rejected.
    #
    def filter_best_packing(packings)
      return nil if packings.empty?
      # Get the packing with the least area of unplaced boxes
      # order unplaced, compactness, length_cuts, l_measure, nb_leftovers
      #print_packings(packings)
      # Fill out start ranking
      ranking = {}
      packings.each do |p|
        ranking[p] = 0
      end
      find_min = true
      # If a packing can pack everything, then it is a winner!
      # There may be more than one.
      zero_left = packings.select{ |p| p.stat[:area_unplaced_boxes] <= EPS }
      if !zero_left.empty?
        packings = zero_left

      else
        update_ranking_by(packings, :area_unplaced_boxes, find_min)
      end

      # All criterias are equal for now.
      update_ranking_by(packings, :l_measure, !find_min)
      update_ranking_by(packings, :compactness, !find_min)
      update_ranking_by(packings, :total_length_cuts, find_min)
      update_ranking_by(packings, :nb_cuts, find_min)
      update_ranking_by(packings, :largest_leftover_area, !find_min)
      update_ranking_by(packings, :nb_leftovers, find_min)

      # Determine the overall winner
      packings.sort_by!{ |p| p.stat[:rank] }
      #puts("winner")
      #print_packings(packings)
      best = packings[0]

=begin
      best.each_with_index do |b, i|
        to_html(b, @run_id*100+i)
      end
=end

      # This should never happen!
      if packings.empty?
        raise(Packing2DError, "Empty packings!")
      else
        return best
      end
    end

    #
    # Packs the first bin, returns a list of packings.
    #
    def pack_next_bin(previous_packer, signatures)
      packings = []

      signatures.each do |signature|
        options = @options.clone
        options.presort, options.score, options.split, options.stacking = signature

        packer = Packer.new(options)
        if previous_packer.nil?
          @bins.each do |bin|
            packer.add_bin(Bin.new(bin.length, bin.width, bin.type, options))
          end
          @boxes.each do |box|
            packer.add_box (Box.new(box.length, box.width, box.rotatable, box.data))
          end
        else
          packer.link_to(previous_packer)
        end
        err = packer.pack
        packings << packer if err == ERROR_NONE
      end
      @run_id += 1
      return packings
    end

    #
    # Prints input in martin's universal bin packing format.
    #
    def print_input
      r = @options.rotatable ? "r" : "nr"
      puts("\# -- start of input --")
      puts("#{@options.saw_kerf},#{@options.trimsize},#{r}")
      puts("#{@options.base_length} #{@options.base_width}")
      @bins.each do |bin|
        puts("#{bin.length} #{bin.width}")
      end
      @boxes.each do |box|
        puts("#{box.length} #{box.width} 1")
      end
      puts("==")
      puts("optimization = #{@options.optimization}")
      puts("\# -- end of input --")
    end

    def to_html(packing, id)
      res = Export.new(packing.packed_bins)
      html = res.to_html(packing.options, 0.2)
      File.write("results/res_#{id}.html", html)
    end
    #
    # Checks for consistency, creates multiple Packers and runs them.
    # Returns best packing by selecting best packing at each stage.
    #
    def run

      # print_input

      dbg(@options.to_str, true)

      return nil, ERROR_INVALID_INPUT if !valid_input?

      case @options.optimization
      when OPT_LIGHT
        signatures = get_signatures_small
      when OPT_MEDIUM
        signatures = get_signatures_medium
      when OPT_ADVANCED
        signatures = get_signatures_large
      else
        return nil, ERROR_INVALID_INPUT
      end

      # parameters are presort, score, split, stacking
      #signatures = [[2,0,3,1]]

      # Not a super precise way of measuring compute time.
      start_timer(signatures.size)

      begin
        packings = pack_next_bin(nil, signatures)
        return nil, ERROR_NO_PLACEMENT_POSSIBLE if packings.empty?

        current_packer = filter_best_packing(packings)
        last_packer = current_packer

        while current_packer.unplaced_boxes.size > 0
          packings = pack_next_bin(current_packer, signatures)
          current_packer = filter_best_packing(packings)
          break if current_packer.nil?
          last_packer = current_packer
        end

      rescue TimeoutError => err
        puts ("Rescued in PackEngine: #{err.inspect}")
        # TODO: packengine timeout error, we should return the best solution found so far
        # but this is dangerous, since it can lead to different versions.
        @errors << ERROR_TIMEOUT
      rescue Packing2DError => err
        puts ("Rescued in PackEngine: #{err.inspect}")
        puts err.backtrace
        @errors << ERROR_BAD_ERROR
      end

      @options.debug = true
      stop_timer(signatures.size, "#{last_packer.packed_bins.size} bin(s)")
      #last_packer.octave(1)
      #last_packer.to_term
      #last_packer.sort_bins_by_efficiency #=> deadly to check how algorithm works!
      return last_packer, ERROR_NONE
    end
  end
end
