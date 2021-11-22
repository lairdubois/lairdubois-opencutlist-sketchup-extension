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
    # List of warnings.
    attr_reader :warnings

    #
    # Initialize a new PackEngine with options.
    #
    def initialize(options)
      super(options)
      @leftovers = []
      @boxes = []
      @warnings = []
      @largest_bin = 0.0
      @min_nb_bins = {}
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
    # Finds and update the min/max leftover and base bin length.
    #
    def update_max_bin
      if @options.base_bin_length > EPS
        @largest_bin = @options.base_bin_length
        @min_nb_bins[@options.base_bin_length] = 0
      end
      @leftovers.each do |leftover|
        @largest_bin = [@largest_bin, leftover.length].max
        @min_nb_bins[leftover.length] = 0
      end
    end

    #
    # Returns true if saw_kerf has a reasonnable length.
    # May be large, but must be smaller than the largest bin.
    #
    def valid_saw_kerf
      (@options.saw_kerf < [@options.base_bin_length, @largest_bin].max)
    end

    #
    # Returns true if trimsize has a reasonnable length.
    # May be large, but must be smaller than the largest bin.
    #
    def valid_trimsize
      ((@options.trimsize * 2.0) < [@options.base_bin_length, @largest_bin].max)
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

    #
    # Selects best packer and returns it or nil.
    #
    def best_solution(packerFFD, packerDP)
      return packerDP if packerFFD.nil?

      return packerFFD if packerDP.nil?

      packers = [packerDP, packerFFD]

      packers_with_zero_left = packers.select { |packer| packer.gstat[:nb_unplaced_boxes] == 0 }
      packers = packers_with_zero_left unless packers_with_zero_left.empty?

      print_packers(packers)
      packers.min_by { |packer| [packer.gstat[:nb_packed_bins], -packer.gstat[:overall_efficiency], packer.gstat[:nb_unplaced_boxes], -packer.gstat[:largest_leftover]] }
    end

    #
    # Checks for consistency, creates a Packer and runs it.
    #
    def run(start_msg = 'Optimizing', end_msg = 'Optimization done')
      status = 0
      if Object.const_defined?('Sketchup')
        start_time = Time.now
        status = 1
        Sketchup.status_text = "#{start_msg} #{'.' * status}"
      end

      error = ERROR_BAD_ERROR
      @options.set_debug(false)
      update_max_bin

      # Check for boxes and bins
      return nil, ERROR_NO_BOX if @boxes.empty?

      return nil, ERROR_NO_BIN if @options.base_bin_length < EPS && @leftovers.empty?

      # Check parameters
      return nil, ERROR_PARAMETERS unless valid_trimsize

      @warnings << WARNING_TRIM_SIZE_LARGE if @options.trimsize > (SIZE_WARNING_FACTOR * @largest_bin)

      return nil, ERROR_PARAMETERS unless valid_saw_kerf

      @warnings << WARNING_SAW_KERF_LARGE if @options.saw_kerf > EPS \
        && @options.saw_kerf > (SIZE_WARNING_FACTOR * @largest_bin)

      # Run first fit decreasing, because it's so simple
      begin
        packerFFD = PackerFFD.new(@options)
        packerFFD.add_leftovers(@leftovers)
        packerFFD.add_boxes(@boxes)
        errFFD = packerFFD.run
      rescue Packing1DError => e
        puts("Rescued in PackEngine packerFFD: #{e.inspect}")
        errFFD = ERROR_BAD_ERROR
        packerFFD = nil
      end

      # Run a dynamic programming version of subset sum
      begin
        packerDP = PackerDP.new(@options)
        packerDP.add_leftovers(@leftovers)
        packerDP.add_boxes(@boxes)
        errDP = packerDP.run(start_msg, 1)
      rescue Packing1DError => e
        puts("Rescued in PackEngine packerDP: #{e.inspect}")
        errDP = ERROR_BAD_ERROR
        packerDP = nil
      end

      packer = nil
      if errDP == ERROR_NONE
        if errFFD == ERROR_NONE
          packer = best_solution(packerFFD, packerDP)
          error = ERROR_NONE
        else
          packer = packerDP
          error = errDP
        end
      else
        packer = packerFFD
        error = errFFD
      end

      # dbg(packer.to_str)
      if packer.nil?
        error = ERROR_BAD_ERROR
      elsif status > 0
        msg = "#{end_msg} : #{format('%4.1f', (Time.now - start_time))} s"
        if Object.const_defined?('Sketchup')
          Sketchup.status_text = msg
        else
          puts(msg)
        end
      end
      [packer, error]
    end
  end
end
