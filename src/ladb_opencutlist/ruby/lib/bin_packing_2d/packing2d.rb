module Ladb::OpenCutList
  module BinPacking2D

    # Number of bytes of computer running code
    # from https://gist.github.com/pithyless/9738125
    N_BYTES = [42].pack("i").size

    # Number of bits.
    N_BITS = N_BYTES * 16

    # Largest integer on this platform. This is actually wrong since
    # ruby merged Fixnum and Bignum into Integer. We just want a rather
    # large number.
    MAX_INT = 2 ** (N_BITS - 2) - 1

    # Working precision to compare decimal inches (this represents around
    # 0.00254 mm)
    EPS = 0.0001

    # Used by Box to find out if it is different from other Box.
    DIFF_PERCENTAGE_BOX = 0.05

    # Maximum time for execution, beyond that interrupt.
    MAX_TIME = 30

    # Number of best solution to carry over for each bin.
    BEST_X_SMALL = 3
    BEST_X_LARGE = 2
    # With less than this Boxes, use BEST_X_SMALL to keep Packers.
    MAX_BOXES_TIME = 30

    # Bin has illegal size <= 0, has been ignored.
    WARNING_ILLEGAL_SIZED_BIN = 0
    # Box has illegal size <= 0, has been ignored.
    WARNING_ILLEGAL_SIZED_BOX = 1

    # No error.
    ERROR_NONE = 0
    # Timeout error.
    ERROR_TIMEOUT = 1
    # Error when no bin for packing available.
    ERROR_NO_BIN = 2
    # Error when no boxes for packing available.
    ERROR_NO_BOX = 3
    # Error when no placement possible, e.g. boxes larger than bin.
    ERROR_NO_PLACEMENT_POSSIBLE = 4
    # Error that needs further debugging.
    ERROR_BAD_ERROR = 5
    # Error in parameters.
    ERROR_PARAMETERS = 6
    # Error in input.
    ERROR_INVALID_INPUT = 7

    # Type of standard bin.
    BIN_TYPE_AUTO_GENERATED = 0
    # Type of leftover bin.
    BIN_TYPE_USER_DEFINED = 1

    # Do not presort input. Should NOT be used since results
    # are random!
    PRESORT_INPUT_ORDER = 0
    # Sort by width decreasing.
    PRESORT_WIDTH_DECR = 1
    # Sort by length decreasing.
    PRESORT_LENGTH_DECR = 2
    # Sort by area decreasing.
    PRESORT_AREA_DECR = 3
    # Sort by perimeter decreasing.
    PRESORT_PERIMETER_DECR = 4
    # Sort by longest side increasing.
    PRESORT_LONGEST_SIDE_DECR = 5
    # Sort by shortest side increasing.
    PRESORT_SHORTEST_SIDE_DECR = 6
    PRESORT = ["input", "width", "length", "area", "longest", "shortest", "perimeter"]

    # Score heuristics for fitting boxes into bins.
    SCORE_BESTAREA_FIT = 0
    SCORE_BESTSHORTSIDE_FIT = 1
    SCORE_BESTLONGSIDE_FIT = 2
    SCORE_WORSTAREA_FIT = 3
    SCORE_WORSTSHORTSIDE_FIT = 4
    SCORE_WORSTLONGSIDE_FIT = 5
    SCORE = [" best area", "short side", "long side", "worst area", "worst short side", "worst long side"]

    # Splitting strategies defining the order of the guillotine cuts.
    SPLIT_SHORTERLEFTOVER_AXIS = 0
    SPLIT_LONGERLEFTOVER_AXIS = 1
    SPLIT_MINIMIZE_AREA = 2
    SPLIT_MAXIMIZE_AREA = 3
    SPLIT_SHORTER_AXIS = 4
    SPLIT_LONGER_AXIS = 5
    SPLIT_HORIZONTAL_FIRST = 6
    SPLIT_VERTICAL_FIRST = 7
    SPLIT = ["shorter leftover", "longer leftover", "min. area", "max. area", "shorter axis", "longer axis", "horizontal_first", "vertical_first"]

    # Do not try to stack boxes.
    STACKING_NONE = 0
    # Stack boxes lengthwise by grouping common widths.
    STACKING_LENGTH = 1
    # Stack boxes widthwise by grouping common lengths.
    STACKING_WIDTH = 2
    # Stack none, length and width.
    STACKING_ALL = 3
    STACKING = ["do not care", "lengthwise", "widthwise", "stacking all"]

    # Orientation of a box. Better for sorting than boolean value.
    NOT_ROTATED = 0
    ROTATED = 1

    # Optimization levels.
    OPT_MEDIUM = 0
    OPT_ADVANCED = 1
    OPTIMIZATION = ["light", "advanced"]
    #
    # Exception raised in this module.
    #
    class Packing2DError < StandardError
    end

    #
    # Top level class (abstract class)
    #
    class Packing2D
      attr_accessor :options

      #
      # Initializes the abstract object.
      #
      def initialize(options = nil)
        @options = options
      end

      #
      # Prints very verbose debugging messages when global
      # option debug == true or when called with parameter
      # debug = true.
      #
      def dbg(msg, debug = false)
        # Assuming @options exists.
        if debug
          puts(msg)
        elsif !@options.nil? && @options.debug
          puts(msg)
        end
        STDOUT.flush
      end
    end
  end
end
