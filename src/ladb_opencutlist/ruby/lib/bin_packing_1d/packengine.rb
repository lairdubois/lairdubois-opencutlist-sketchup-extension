# frozen_string_literal: true

#
# Main Driver for BinPacking1D
#
module Ladb::OpenCutList::BinPacking1D
  #
  # Implements the main running function.
  #
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
      @largest_bin = 0.0

      @packer_ffd = nil
      @error_ffd = ERROR_BAD_ERROR
      @packer_dp_v1 = nil
      @error_dp_v1 = ERROR_BAD_ERROR
      @packer_dp_v2 = nil
      @error_dp_v2 = ERROR_BAD_ERROR

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
        new_bin = Bin.new(length, BIN_TYPE_USER_DEFINED, @options)
        # No need to sort, algorithm will pick largest available
        @leftovers.push(new_bin)
      end
    end

    #
    # Add a Box to be packed into Bins.
    #
    def add_box(length, cid = nil, data = nil)
      if length <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BOX if length <= 0
      else
        @boxes << Box.new(length, cid, data)
      end
    end

    #
    # Check if Bins are available for packing.
    #
    def bins_available?
      @largest_bin = @options.base_bin_length if @options.base_bin_length - (2 * @options.trimsize) > EPS
      @leftovers.each do |leftover|
        @largest_bin = [@largest_bin, leftover.length].max
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

        s = "#{format('%2d', gstat[:algorithm])} " \
            "#{format('%10.2f', gstat[:overall_efficiency])} " \
            "#{format('%11.2f', gstat[:largest_leftover])} " \
            "#{format('%6d', gstat[:nb_packed_bins])} " \
            "#{format('%6d', gstat[:nb_unplaced_boxes])} "
        dbg(s)
      end
      dbg(' alg.    eff.       Lleft      #bins  #unplaced_boxes')
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
    def stop_timer(packers)
      s = "-> end of packing(s) time = #{format('%6.4f', (Time.now - @start_time))} s, "
      packers.each do |packer|
        s += packer.bins.length.to_s
      end
      dbg(s)
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
      # DP algorithm cannot be broken into smaller parts, therefore 4 steps
      5
    end

    #
    # Return true if packing successfully finished.
    #
    def packings_done?
      (@error_dp_v1 == ERROR_NONE || @error_dp_v2 == ERROR_NONE || @error_ffd == ERROR_NONE)
    end

    #
    # Selects best packer and returns it or nil.
    #
    def best_solution(packers)
      valid_packers = []
      # Remove possible nil entries
      packers.compact!
      packers.each do |packer|
        valid_packers << packer if packer.error == ERROR_NONE
      end

      return nil if valid_packers.empty?

      packers_with_zero_left = valid_packers.select { |packer| packer.gstat[:nb_unplaced_boxes] == 0 }
      packers = if packers_with_zero_left.empty?
                  valid_packers
                else
                  packers_with_zero_left
                end
      print_packers(packers)
      packers.min_by { |packer| packer.gstat[:nb_packed_bins] }
    end

    #
    # Use first fit decreasing algorithm.
    #
    def pack_ffd
      packer_ffd = nil
      begin
        packer_ffd = PackerFFD.new(@options)
        return ERROR_BAD_ERROR if packer_ffd.nil?

        packer_ffd.add_leftovers(@leftovers)
        packer_ffd.add_boxes(@boxes)
        err_ffd = packer_ffd.run
      rescue Packing1DError => e
        puts("Rescued in PackEngine packerFFD: #{e.inspect}")
        err_ffd = ERROR_BAD_ERROR
      end
      [packer_ffd, err_ffd]
    end

    #
    # Run a dynamic programming version of subset sum
    #
    def pack_dp(variant)
      packer_dp = nil
      begin
        packer_dp = PackerDP.new(@options)
        return ERROR_BAD_ERROR if packer_dp.nil?

        packer_dp.add_leftovers(@leftovers)
        packer_dp.add_boxes(@boxes)
        err_dp = packer_dp.run(variant)
      rescue Packing1DError => e
        puts("Rescued in PackEngine packerDP: #{e.inspect}")
        err_dp = ERROR_BAD_ERROR
      rescue TimeoutError => e
        puts("Rescued in PackEngine: #{e.inspect}")
        # TODO: packengine timeout error, we should return the best solution found so far
        # but this is dangerous, since it can lead to different versions.
        @warnings << WARNING_SUBOPTIMAL
        @warnings << WARNING_TIMEOUT
        err_dp = ERROR_BAD_ERROR
      end
      [packer_dp, err_dp]
    end

    #
    # Alternative to start, run, finish.
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
    # Start phase of algorithm, checking for valid input.
    #
    def start
      return unless bins_available?

      return unless valid_input?

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
        @packer_ffd, @error_ffd = pack_ffd
        @step += 1
      elsif @step == 2
        @packer_dp_v1, @error_dp_v1 = pack_dp(ALG_SUBSET_OPT_V1)
        @step += 1
      elsif @step == 3 && @error_dp_v1 == ERROR_NONE
        @packer_dp_v2, @error_dp_v2 = pack_dp(ALG_SUBSET_OPT_V2)
        @step += 1
      elsif packings_done? && @step >= 3
        @done = true
      else
        @errors << ERROR_NO_PLACEMENT_POSSIBLE
      end
    end

    #
    # Finish this run, select best solution.
    #
    def finish
      unless @done
        @errors << ERROR_STEP_BY_STEP
        return
      end
      packers = [@packer_ffd, @packer_dp_v1, @packer_dp_v2]
      packer = best_solution(packers)

      if packer.nil?
        @errors << ERROR_BAD_ERROR
        return [nil, get_errors.first]
      end
      stop_timer(packers)

      @errors << ERROR_NONE unless errors?
      [packer, get_errors.first]
    end
  end
end
