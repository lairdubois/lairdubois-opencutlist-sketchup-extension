module Ladb::OpenCutList

  module BinPacking1D
  
    BAR_TYPE_NEW = 0
    BAR_TYPE_LO = 1
    BAR_TYPE_UNFIT = 2

    ERROR_NONE = 0
    ERROR_SUBOPT = 1
    ERROR_NO_BIN = 2
    ERROR_NO_PLACEMENT_POSSIBLE = 3
    ERROR_BAD_ERROR = 4
    ERROR_TIME_EXCEEDED = 5
    ERROR_NO_PARTS = 6
    ERROR_NOT_IMPLEMENTED = 7
    
    WARNING_SAW_KERF_SMALL = 0
    WARNING_TRIM_SIZE_LARGE = 1

    MAX_TIME = 10

    EPS = 1e-9 # smaller than this is considered zero

    # with more than this number of parts, we split into
    # groups and optimize each group
    MAX_PARTS = 205

    class Packing1D

      def self.valid_max_time(max_time)
        if max_time >= 0 and max_time <= MAX_TIME
          return max_time
        else
          return MAX_TIME
        end
      end
      
      def self.valid_tuning_level(level)
        if level >= 0 and level <= 2
          return level
        else
          return 1
        end
      end
      
      def to_ls(nb)
        return nb.to_l.to_s
        #return nb.to_s
      end
    end
  end
end
