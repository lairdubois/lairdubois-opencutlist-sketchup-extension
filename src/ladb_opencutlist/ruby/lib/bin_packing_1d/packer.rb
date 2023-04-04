# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking1D
  #
  # Core computing for 1D Bin Packing.
  #
  class Packer < Packing1D
    # Boxes to be packed.
    attr_reader :boxes

    # Leftover bins to use first. These are used first
    # even if this does not lead to an optimal solution.
    attr_reader :leftovers

    # Resulting bins containing boxes.
    attr_reader :bins

    # Boxes that could not be packed into bins, because
    # of a lack of bins/leftovers.
    attr_reader :unplaced_boxes

    # Leftovers which have nave not been used.
    attr_reader :unused_bins

    attr_reader :error

    # General statistics object for the packer.
    attr_reader :gstat

    # Start time of the packing.
    attr_reader :start_time

    #
    # Initialize a Packer object with options.
    #
    def initialize(options)
      super(options)

      # Boxes to pack.
      @boxes = []

      # Offcuts after packing.
      @leftovers = []

      # Bins used to pack.
      @bins = []

      # Boxes that could not be placed.
      @unplaced_boxes = []

      # Offcut bins that were not used.
      @unused_bins = []

      # Boxes that are rejected because too large!
      @unfit_boxes = []

      # Smallest box length to pack.
      @smallest = 0

      # Remember last error
      @error = nil

      # Statistics collected for final report.
      @gstat = {}
      @gstat[:nb_input_boxes] = 0 # Total number of boxes to pack
      @gstat[:nb_valid_boxes] = 0 # Number of valid boxes, i.e. not too large
      @gstat[:nb_packed_bins] = 0
      @gstat[:nb_unplaced_boxes] = 0
      @gstat[:largest_leftover] = 0
      @gstat[:overall_efficiency] = 0 # Overall efficiency [0,100] as a percentage of used/waste.
      @gstat[:algorithm] = nil
    end

    #
    # Add a box to be packed. Should not be empty, but
    # no verification made here.
    #
    def add_boxes(boxes)
      boxes.each do |box|
        @boxes << box.clone
      end
      @gstat[:nb_input_boxes] = @boxes.size
    end

    #
    # Add leftovers/scrap bins. Possibly empty, in that
    # case @options.base_bin_length should be positive.
    #
    def add_leftovers(leftovers)
      leftovers.each do |leftover|
        @leftovers << Bin.new(leftover.length, BIN_TYPE_USER_DEFINED, @options)
      end
      return if !@leftovers.empty? || @options.base_bin_length >= EPS

      raise(Packing1DError, 'No leftovers and base_bin_length too small!')
    end

    #
    # Run the bin packing optimization.
    #
    def run
      ERROR_BAD_ERROR
    end

    #
    # Removes boxes that cannot possibly fit into a
    # leftover or base_bin_length.
    #
    def remove_unfit
      #
      # Check if @boxes fit within either bins in @leftovers
      # or @options.base_bin_length.
      #
      available_lengths = @leftovers.collect(&:net_length)
      available_lengths << (@options.base_bin_length - (2 * @options.trimsize))
      max_length = available_lengths.max
      @boxes, @unfit_boxes = @boxes.partition { |box| box.length <= max_length }
      @gstat[:nb_valid_boxes] = @boxes.size
    end

    #
    # Prepare final results once solution found.
    #
    def prepare_results
      net_used = 0
      length = 0
      nb_packed_boxes = 0
      @bins.each do |bin|
        bin.sort_boxes
        net_used += bin.net_used
        length += bin.length
        nb_packed_boxes += bin.boxes.size
        @gstat[:largest_leftover] = [@gstat[:largest_leftover], bin.current_leftover].max
      end

      @bins = @bins.sort_by { |bin| -bin.efficiency }
      @gstat[:overall_efficiency] = 100 * (net_used / length) if length > EPS
      @gstat[:nb_packed_bins] = @bins.size

      @gstat[:nb_unplaced_boxes] = @unplaced_boxes.size
      if @gstat[:nb_input_boxes] - @unplaced_boxes.size != nb_packed_boxes
        raise(Packing1DError, 'Lost boxes during packing!')
      end

      # WHY? do we ever have a leftover left here? yes, when no placement
      # was possible, because of a too large trimming size, ...
      raise(Packing1DError, 'Leftovers not assigned!') unless @leftovers.empty?
    end

    #
    # Overall efficiency
    #
    def overall_efficiency
      @gstat[:overall_efficiency]
    end

    def to_str
      s = "  nb bins #{@bins.length}\n  " \
          "overall efficiency #{format('%6.2f', @gstat[:overall_efficiency])} %\n"

      @bins.each do |bin|
        s += "#{bin.to_str}\n"
      end
      s += "  unplaced boxes[#{@unplaced_boxes.size}]:"
      @unplaced_boxes.each do |box|
        s += " #{format('%6.1f', box.length)}"
      end
      s += "\n  unused bins[#{@unused_bins.size}]:"
      @unused_bins.each do |bin|
        s += " #{format('%6.1f', bin.length)}"
      end
      s += "\n  leftover[#{@leftovers.size}]:\n"
      @leftovers.each do |leftover|
        s += "    unused #{leftover.length}\n"
      end
      s
    end
  end
end
