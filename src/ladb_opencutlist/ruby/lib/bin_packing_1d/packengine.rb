# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking1D
  require_relative 'packing1d'
  require_relative 'options'
  require_relative 'packer'
  require_relative 'packerdp'
  require_relative 'packerffd'
  require_relative 'box'
  require_relative 'bin'

  #
  # Setup and run bin packing in 1D.
  #
  class PackEngine < Packing1D

    #
    # Initialize a new PackEngine with options.
    #
    def initialize(options)
      super(options)
      @leftovers = []
      @boxes = []
      @warnings = []
      @largest_bin = 0.0

      @packerFFD = nil
      @packerDP = nil
      @errDP = ERROR_NONE
      @errFFD = ERROR_NONE

      #@min_nb_bins = {}
      @done = false
      @warnings = []
      @errors = []

      @step = 0
    end

    #
    # Add offcut Bins.
    #
    def add_bin(length)
      if length <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BIN
      else
        newbin = Bin.new(length, BIN_TYPE_LO, @options)
        # Sorting may not be necessary, algorithm will pick largest available
        @leftovers.push(newbin).sort_by!(&:length)
      end
    end

    #
    # Add a Box to be packed into Bins.
    #
    def add_box(length, data = nil)
      if length <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BOX if length <= 0
      else
        @boxes << Box.new(length, data)
      end
    end

    #
    # Check if Bins are available for packing.
    #
    def bins_available?
      if @options.base_bin_length - (2 * @options.trimsize) > EPS
        @largest_bin = @options.base_bin_length
        #@min_nb_bins[@options.base_bin_length] = 0
      end
      @leftovers.each do |leftover|
        @largest_bin = [@largest_bin, leftover.length].max
        #@min_nb_bins[leftover.length] = 0
      end

      @errors << ERROR_NO_BIN if @options.base_bin_length < EPS && @leftovers.empty?
      @errors.empty?
    end

    #
    # Returns true if input is somewhat valid.
    #
    def valid_input?
      max_dim = [@options.base_bin_length, @largest_bin].max

      # these are most likely errors, even if there could be some cases
      # where it might still work
      @errors << ERROR_PARAMETERS if @options.saw_kerf >= max_dim
      @errors << ERROR_PARAMETERS if (@options.trimsize * 2.0) >= max_dim

      @errors << ERROR_NO_BOX if @boxes.empty?

      puts("errors found so far: #{@errors}")

      # if @options.trimsize > (SIZE_WARNING_FACTOR * @largest_bin)
      #   @warnings << WARNING_TRIM_SIZE_LARGE
      # end
      # if @options.saw_kerf > EPS && @options.saw_kerf > (SIZE_WARNING_FACTOR * @largest_bin)
      #   @warnings << WARNING_SAW_KERF_LARGE
      # end

      @errors.empty?
    end

    #
    # Prints mains stats about the packers.
    #
    def print_packers(packers)
      return unless @options.debug
      return if packers.nil?

      packers.each_with_index do |packer, _i|
        next if packer.nil?

        gstat = packer.gstat
        next if gstat.nil?

        s = "#{format('%2d', gstat[:algorithm])} "\
            "#{format('%10.2f', gstat[:overall_efficiency])} " \
            "#{format('%11.2f', gstat[:largest_leftover])} " \
            "#{format('%6d', gstat[:nb_packed_bins])} " \
            "#{format('%6d', gstat[:nb_unplaced_boxes])} "
        dbg(s)
      end
      dbg(' alg.    eff.       leftL      #bins  #unplaced_boxes')
    end

    # Sets the global start time.
    #
    def start_timer
      dbg("-> start of packing with #{@boxes.size} box(es), #{@leftovers.size} bin(s)")
      @start_time = Time.now
    end

    #
    # Prints total time used since start_timer.
    #
    def stop_timer(msg)
      dbg("-> end of packing(s) time = #{format('%6.4f', (Time.now - @start_time))} s, " + msg)
    end

    #
    #
    #
    def is_done
      return @done
    end

    #
    #
    #
    def has_errors
      return !@errors.empty?
    end

    #
    #
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
      return @errors
    end

    #
    #
    #
    def get_warnings
      return @warnings
    end

    #
    # Get number of estimated steps. In each step a single bin will be packed.
    #
    def get_estimated_steps
      # DP algorithm cannot be broken into smaller parts, therefore 4 steps
      return 4
    end

    #
    #
    #
    def packings_done?
      return (@errDP == ERROR_NONE || @errFFD == ERROR_NONE)
    end

    #
    # Selects best packer and returns it or nil.
    #
    def best_solution(packerFFD, packerDP)
      return packerDP if @errFFD == ERROR_BAD_ERROR and @errDP == ERROR_NONE
      return packerFFD if @errDP == ERROR_BAD_ERROR and @errFFD == ERROR_NONE
      return nil if @errDP == ERROR_BAD_ERROR and @errFFD == ERROR_BAD_ERROR

      packers = [packerDP, packerFFD]
      packers_with_zero_left = packers.select { |packer| packer.gstat[:nb_unplaced_boxes] == 0 }
      packers = packers_with_zero_left unless packers_with_zero_left.empty?
      print_packers(packers)
      packers.min_by { |packer| [packer.gstat[:nb_packed_bins], -packer.gstat[:overall_efficiency], packer.gstat[:nb_unplaced_boxes], -packer.gstat[:largest_leftover]] }
    end

    #
    # Use first fit decreasing algorithm.
    #
    def packFFD
      begin
        @packerFFD = PackerFFD.new(@options)
        @packerFFD.add_leftovers(@leftovers)
        @packerFFD.add_boxes(@boxes)
        @errFFD = @packerFFD.run
      rescue Packing1DError => e
        puts("Rescued in PackEngine packerFFD: #{e.inspect}")
        @errFFD = ERROR_BAD_ERROR
      end
    end

    #
    # Run a dynamic programming version of subset sum
    #
    def packDP
      begin
        @packerDP = PackerDP.new(@options)
        @packerDP.add_leftovers(@leftovers)
        @packerDP.add_boxes(@boxes)
        @errDP = @packerDP.run
      rescue Packing1DError => e
        puts("Rescued in PackEngine packerDP: #{e.inspect}")
        @errDP = ERROR_BAD_ERROR
      rescue TimeoutError => e
        puts("Rescued in PackEngine: #{e.inspect}")
        # TODO: packengine timeout error, we should return the best solution found so far
        # but this is dangerous, since it can lead to different versions.
        @warnings << WARNING_SUBOPT
        @warnings << WARNING_TIMEOUT
        @errDP = ERROR_BAD_ERROR
      end
    end

    #
    # Alternative to start, run, finish.
    #
    def runall
      start
      until is_done || has_errors
        run
      end
      if has_errors
        err = get_errors.first
        return nil, err
      else
        return finish
      end
    end

    #
    # Start phase of algorithm, checking for valid input.
    #
    def start
      return unless bins_available?
      return if !valid_input?
      # Not a super precise way of measuring compute time.
      start_timer
      @step = 1
    end

    #
    # Run FFD first, then DP.
    #
    def run
      if @step == 0
        # means start has not run yet!
        @errors << ERROR_STEP_BY_STEP
        return
      end
      if @step == 1
        packFFD
        @step += 1
      elsif @step == 2
        packDP
        @step += 1
      elsif packings_done? and @step == 3
        @done = true
      else
        @errors << ERROR_NO_PLACEMENT_POSSIBLE
      end
    end

    #
    # Finish this run, select best solution.
    #
    def finish
      if !@done
        @errors << ERROR_STEP_BY_STEP
        return
      end
      packer = best_solution(@packerFFD, @packerDP)
      if packer.nil?
        @errors << ERROR_BAD_ERROR
        return [nil, get_errors.first]
      end
      stop_timer("FFD = #{@packerFFD.bins.length}, DP = #{@packerDP.bins.length}")

      # if get_warnings.size > 0
      #   get_warnings.each do |w|
      #     puts("warning = #{w}")
      #   end
      # end
      @errors << ERROR_NONE if ! has_errors
      return [packer, get_errors.first]
    end
  end
end
