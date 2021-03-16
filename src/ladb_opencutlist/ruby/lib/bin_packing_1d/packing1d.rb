module Ladb::OpenCutList

  #
  # Module implementing 1D BinPacking
  #
  module BinPacking1D

    # Number of bytes of computer running code
    # from https://gist.github.com/pithyless/9738125
    N_BYTES = [42].pack('i').size

    # Number of bits
    N_BITS = N_BYTES * 16

    # Largest integer on this platform
    MAX_INT = 2**(N_BITS - 2) - 1

    #
    # Error used by Timer when execution of algorithm
    # takes too long (defined in Option).
    #
    class TimeoutError < StandardError
    end

    # Type of a new bin.
    BIN_TYPE_NEW = 0
    # Type of leftover/scrap bin.
    BIN_TYPE_LO = 1

    # No errors during packing.
    ERROR_NONE = 0
    # Solution may not be optimal.
    ERROR_SUBOPT = 1
    # No bins available for packing.
    ERROR_NO_BIN = 2
    # Bad parameter
    ERROR_PARAMETERS = 3
    # Catch for bad errors with unknown cause.
    ERROR_BAD_ERROR = 4
    # No boxes available to pack.
    ERROR_NO_BOX = 5
    # Error when subsetsum takes too long.
    ERROR_TIMEOUT = 6

    # A large saw kerf warning.
    WARNING_SAW_KERF_LARGE = 0
    # A large trimsize warning.
    WARNING_TRIM_SIZE_LARGE = 1
    # A box with zero or negative length.
    WARNING_ILLEGAL_SIZED_BOX = 2
    # A bin with zero or negative length.
    WARNING_ILLEGAL_SIZED_BIN = 3
    # A suboptimal algorithm was used.
    WARNING_ALGORITHM_FFD = 4

    # If trimsize/saw kerf > SIZE_WARNING_FACTOR*largest leftover.
    SIZE_WARNING_FACTOR = 0.25

    # Default allocated computation time in seconds.
    MAX_TIME = 3

    # Epsilon precision for comparison.
    # Smaller than this is considered zero.
    EPS = 0.0001

    # With more than this number of parts, we split into
    # groups and optimize each group.
    MAX_PARTS = 80

    # Algorithm used is subset sum.
    ALG_SUBSET_SUM = 1
    # Algorithm used is FFD.
    ALG_FFD = 2

    #
    # Exception raised in this module.
    #
    class Packing1DError < StandardError
    end

    #
    # Top level class (abstract class)
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
      def dbg(msg, dbg=false)
        # assuming @options exists
        if dbg
          puts msg + "\n"
        else
          puts msg + "\n" if @options.debug
        end
      end
    end
  end
end
