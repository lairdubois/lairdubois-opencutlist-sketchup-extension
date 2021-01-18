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

      @estimated_nb_bins = 0
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
      problem_type
      return @errors.empty?
    end

    def problem_type
      total_area = @boxes.inject(0) { |sum, b| sum + b.area() }
      if (@options.base_length >= EPS && @options.base_width >= EPS)
        @estimated_nb_bins = total_area/(@options.base_length*@options.base_width)
        if @estimated_nb_bins > 3
          puts("   r = #{'%4.2f' % @estimated_nb_bins} => potentially problematic problem!")
        else
          puts("   r = #{'%4.2f' % @estimated_nb_bins} => common problem!")
        end
      end
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
      presort = (PRESORT_WIDTH_DECR..PRESORT_ALTERNATING_WIDTHS).to_a
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a
      split = (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a
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
      # signature size will be the product of all possibilities
      # 4 * 4 * 2 = 32 => 32 * 1 or 3
      presort = (PRESORT_WIDTH_DECR..PRESORT_AREA_DECR).to_a #.to_a # 4
      score = (SCORE_BESTAREA_FIT..SCORE_WORSTAREA_FIT).to_a # 4
      split = (SPLIT_MINIMIZE_AREA..SPLIT_VERTICAL_FIRST).to_a # 4
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
    def print_packings(packings, level=0)
      return if packings.nil?
      if level == 0
        dbg("-> print_packings", true)
      end
      packings.each do |packer|
        if !packer.previous_packer.nil?
          print_packings([packer.previous_packer], level+1)
        end
        stat = packer.stat
        gstat = packer.gstat
        next if stat.nil?
        s = "#{'%2d' % level}  "
        s += "#{'%4d' % gstat[:nb_packed_bins]} "
        s += "#{'%12.2f' % stat[:area_unplaced_boxes]} "
        s += "#{'%12.2f' % stat[:compactness]} "
        s += "#{'%8.2f' % (stat[:l_measure]/100000)} "
        s += "#{'%4d' % stat[:nb_cuts]} "
        s += "#{'%12.2f' % stat[:largest_leftover_area]} "
        s += "#{'%15.2f' % stat[:total_length_cuts]} "
        s += "#{'%6d' % stat[:nb_leftovers]}"
        s += "#{'%22s' % stat[:signature]}"
        s += "#{'%4d' % gstat[:rank]}"
        dbg(s, true)
      end
      if level == 0
        dbg("   bins  unpacked  compactness      l_m   nbcuts max_leftover     cutlength leftovers          signature", true)
      end
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
          p.gstat[:rank] += rank
        else
          last_n = p
          rank += 1
          p.gstat[:rank] += rank
        end
      end
    end

    #
    # Filter best packings. Packings are sorted according to several
    # criterias, the packing with the lowest sum of ranks is the
    # winner!
    #
    def filter_best_packing(packings)
      return nil if packings.empty?
      find_min = true
      # If a packing can pack everything, then it is a potential winner!
      # There may be more than one.
      zero_left = packings.select{ |p| p.stat[:area_unplaced_boxes] <= EPS }
      if !zero_left.empty?
        packings = zero_left
      else
        update_ranking_by(packings, :area_unplaced_boxes, find_min)
      end

      # All criterias are equal for now.
      if [STACKING_LENGTH, STACKING_WIDTH].include?(@options.stacking_pref)
        #update_ranking_by(packings, :l_measure, !find_min)
        update_ranking_by(packings, :compactness, !find_min)
        #update_ranking_by(packings, :nb_cuts, find_min)
        update_ranking_by(packings, :nb_leftovers, find_min)
        #update_ranking_by(packings, :total_length_cuts, find_min)
      else
        update_ranking_by(packings, :compactness, !find_min)
        #update_ranking_by(packings, :l_measure, !find_min)
        #update_ranking_by(packings, :area_unplaced_boxes, find_min)
        #update_ranking_by(packings, :total_length_cuts, find_min)
        #update_ranking_by(packings, :largest_leftover_area, !find_min)
        #update_ranking_by(packings, :nb_leftovers, find_min)
        #update_ranking_by(packings, :efficiency, !find_min)
        #update_ranking_by(packings, :total_length_cuts, find_min)
        #update_ranking_by(packings, :nb_cuts, find_min)
        #update_ranking_by(packings, :nb_leftovers, find_min)
      end

=begin
      best.each_with_index do |b, i|
        to_html(b, @run_id*100+i)
      end
=end

      # This should never happen!
      if packings.empty?
        raise(Packing2DError, "Empty packings!")
      else
        # Determine the overall winner
        #print_packings(packings)
        p = packings.group_by { |packing| packing.gstat[:rank] }
        best_3 = []
        p.keys[0..2].each do |key|
          best_3 << p[key].first
        end
        best_3.sort_by! { |packing| -packing.gstat[:total_compactness] }
        #print_packings(best_3)
        return best_3
      end
    end

    def pack_next(previous_packings, signatures)
      packings = []
      if previous_packings.nil?
        packings = pack_next_bin(nil, signatures)
      else
        previous_packings.each do |previous_packer|
          packings += pack_next_bin(previous_packer, signatures)
        end
      end
      @run_id += 1
      return packings
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

    def packings_done(packers)
      if packers.nil?
        return true
      end
      packers.each do |packer|
        # at least one packing has no boxes left
        if packer.unplaced_boxes.size == 0
          return true
        end
      end
      return false
    end

    #
    # Checks for consistency, creates multiple Packers and runs them.
    # Returns best packing by selecting best packing at each stage.
    #
    def run

      #print_input

      dbg(@options.to_str, true)

      return nil, ERROR_INVALID_INPUT if !valid_input?

      if @estimated_nb_bins > 3 && @options.optimization == OPT_ADVANCED
        @options.set_optimization(OPT_LIGHT)
        @warnings << "reduced optimization level"
      end
      case @options.optimization
      when OPT_LIGHT
        signatures = get_signatures_small
      when OPT_ADVANCED
        signatures = get_signatures_large
      else
        return nil, ERROR_INVALID_INPUT
      end

      # parameters are presort, score, split, stacking
      #signatures = [[1,0,2,0]]

      # Not a super precise way of measuring compute time.
      start_timer(signatures.size)

      begin
        packings = pack_next(nil, signatures)
        return nil, ERROR_NO_PLACEMENT_POSSIBLE if packings.empty?

        packings = filter_best_packing(packings)
        while !packings_done(packings)
          last_packings = packings
          packings = pack_next(packings, signatures)
          packings = filter_best_packing(packings)
        end
        last_packings = packings if packings != nil

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

      #print_packings(last_packings)
      @options.set_debug(true)
      stop_timer(signatures.size, "#{last_packings[0].packed_bins.size} bin(s)")
      #last_packer.octave(1)
      #last_packer.to_term
      #last_packer.sort_bins_by_efficiency #=> deadly to check how algorithm works!
      last_packings.map(&:finish)
      return last_packings[0], ERROR_NONE
    end
  end
end
