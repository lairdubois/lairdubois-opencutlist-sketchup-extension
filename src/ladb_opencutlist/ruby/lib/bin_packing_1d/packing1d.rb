# frozen_string_literal: true

module Ladb::OpenCutList
  #
  # Module implementing 1D BinPacking
  #
  module BinPacking1D
    #
    # Error used by Timer when execution of algorithm
    # takes too long (defined in Option).
    #
    class TimeoutError < StandardError
    end

    # No errors during packing.
    ERROR_NONE = 0
    # Error when no bin for packing available.
    ERROR_NO_BIN = 1
    # Error when no boxes for packing available.
    ERROR_NO_BOX = 2
    # Error in parameters.
    ERROR_PARAMETERS = 3
    # Error when no placement possible, e.g. boxes larger than bin.
    ERROR_NO_PLACEMENT_POSSIBLE = 4
    # Error that needs further debugging.
    ERROR_BAD_ERROR = 5
    # Error in step by step run
    ERROR_STEP_BY_STEP = 6

    # A large saw kerf warning.
    WARNING_SAW_KERF_LARGE = 0
    # A large trimsize warning.
    WARNING_TRIM_SIZE_LARGE = 1
    # A box with zero or negative length.
    WARNING_ILLEGAL_SIZED_BOX = 2
    # A bin with zero or negative length.
    WARNING_ILLEGAL_SIZED_BIN = 3
    # Error when subset sum takes too long.
    WARNING_TIMEOUT = 4
    # Solution may not be optimal (not reliable).
    WARNING_SUBOPTIMAL = 6

    # If trimsize/saw kerf > SIZE_WARNING_FACTOR*largest leftover.
    SIZE_WARNING_FACTOR = 0.25

    # Default allocated computation time in seconds for DP algorithm.
    MAX_TIME = 3

    # Epsilon precision for comparison.
    # Smaller than this is considered zero.
    EPS = 0.0001

    # With more than this number of parts, parts will
    # be split into groups and each group optimized on its own.
    MAX_PARTS = 250

    # Algorithm used is a modified Subset Sum.
    ALG_SUBSET_OPT_V1 = 1
    ALG_SUBSET_OPT_V2 = 2
    # Algorithm used is first fit decreasing (FFD).
    ALG_FFD = 3

    # Type of a new bin.
    BIN_TYPE_AUTO_GENERATED = 0
    # Type of leftover/scrap bin.
    BIN_TYPE_USER_DEFINED = 1

    #
    # Exception raised in this module.
    #
    class Packing1DError < StandardError
    end

    #
    # Bin Packing in 1D
    #
    class Packing1D
      # Program options, passed to most subclasses.
      attr_accessor :options

      #
      # Initialize a new Packing1D object, only
      # called by subclasses.
      #
      def initialize(options = nil)
        @options = options
      end

      #
      # Prints a message when debug option is on or
      # when called with option true.
      #
      def dbg(msg, debug = false)
        # assuming @options exists
        return if @options.nil?

        puts("#{msg}\n") if debug || @options.debug
      end
    end
  end
end
