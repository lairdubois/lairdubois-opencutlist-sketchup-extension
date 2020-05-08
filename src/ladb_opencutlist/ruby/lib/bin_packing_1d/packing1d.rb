module Ladb::OpenCutList

  #
  # Module implementing 1D BinPacking
  #
  module BinPacking1D
  
    # a new bin.
    BIN_TYPE_NEW = 0
    # a leftover/scrap bin.
    BIN_TYPE_LO = 1

    # no errors during packing.
    ERROR_NONE = 0
    # solution may not be optimal.
    ERROR_SUBOPT = 1
    # no bins available for packing.
    ERROR_NO_BIN = 2
    # NOT USED, instead returns ERROR_NO_BIN
    ERROR_NO_PLACEMENT_POSSIBLE = 3
    # catch for bad errors with unknown cause.
    ERROR_BAD_ERROR = 4
    # time exceeded during computation.
    ERROR_TIME_EXCEEDED = 5
    # no boxes available to pack.
    ERROR_NO_PARTS = 6
    
    # a very small saw kerf.
    WARNING_SAW_KERF_SMALL = 0
    
    # trimsize
    WARNING_TRIM_SIZE_LARGE = 1
    
    # a box with zero or negative length.
    WARNING_ILLEGAL_SIZED_BOX = 2
    
    # a bin with zero or negative length.
    WARNING_ILLEGAL_SIZED_BIN = 3
    
    # factor for checking trimsize. 
    MAX_TRIMSIZE_FACTOR = 5

    # default tuning level.
    DEFAULT_TUNING_LEVEL = 2
    
    # default allocated computation time in seconds.
    MAX_TIME = 7

    # epsilon precision for comparison. 
    # Smaller than this is considered zero.
    EPS = 1e-9 

    # with more than this number of parts, we split into
    # groups and optimize each group
    MAX_PARTS = 205

    #
    # Exception raised in this module.
    #
    class Packing1DError < StandardError
    end
    
    #
    # Top level class (abstract class)
    #
    class Packing1D

      # program options, passed to most subclasses.
      attr_accessor :options
      
      #
      # initialize a new Packing1D object, only
      # called by subclasses.
      #
      def initialize(options = nil)
        @options = options
      end
      
      # converts a number to a string. Used in Sketchup
      # to convert internall representation to model units.
      def to_ls(nb)
        return nb.to_l.to_s
        #return nb.to_s
      end
      
      # dbg prints a message when debug option is on.
      def dbg(msg)
        # assuming @options exists
        puts msg + "\n" if @options.debug
      end
    end
  end
end
