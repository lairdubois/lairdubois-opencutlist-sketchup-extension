module Ladb::OpenCutList

  module BinPacking2D

    PRESORT_INPUT_ORDER = 0
    PRESORT_WIDTH_DECR = 1
    PRESORT_LENGTH_DECR = 2
    PRESORT_AREA_DECR = 3
    PRESORT_PERIMETER_DECR = 4

    STACKING_NONE = 0
    STACKING_LENGTH = 1
    STACKING_WIDTH = 2

    BBOX_OPTIMIZATION_NONE = 0
    BBOX_OPTIMIZATION_ONLY_FINAL = 1
    BBOX_OPTIMIZATION_ALWAYS = 2

    SCORE_BESTAREA_FIT = 0
    SCORE_BESTSHORTSIDE_FIT = 1
    SCORE_BESTLONGSIDE_FIT = 2
    SCORE_WORSTAREA_FIT = 3
    SCORE_WORSTSHORTSIDE_FIT = 4
    SCORE_WORSTLONGSIDE_FIT = 5

    SPLIT_SHORTERLEFTOVER_AXIS = 0
    SPLIT_LONGERLEFTOVER_AXIS = 1
    SPLIT_MINIMIZE_AREA = 2
    SPLIT_MAXIMIZE_AREA = 3
    SPLIT_SHORTER_AXIS = 4
    SPLIT_LONGER_AXIS = 5

    BIN_TYPE_AUTO_GENERATED  = 0
    BIN_TYPE_USER_DEFINED = 1

    ERROR_NONE = 0
    ERROR_NO_BIN = 1
    ERROR_NO_PLACEMENT_POSSIBLE = 2
    ERROR_BAD_ERROR = 3

    class Packing2D

      def self.valid_presort(presort)
        if presort
          i_presort = presort.to_i
          if i_presort < PRESORT_INPUT_ORDER or i_presort > PRESORT_PERIMETER_DECR
            PRESORT_INPUT_ORDER
          end
          i_presort
        else
          PRESORT_INPUT_ORDER
        end
      end

      def self.valid_stacking(stacking)
        if stacking
          i_stacking = stacking.to_i
          if i_stacking < STACKING_NONE or i_stacking > STACKING_WIDTH
            STACKING_NONE
          end
          i_stacking
        else
          STACKING_NONE
        end
      end

      def self.valid_bbox_optimization(bbox_optimization)
        if bbox_optimization
          i_bbox_optimization = bbox_optimization.to_i
          if i_bbox_optimization < BBOX_OPTIMIZATION_NONE or i_bbox_optimization > BBOX_OPTIMIZATION_ALWAYS
            BBOX_OPTIMIZATION_NONE
          end
          i_bbox_optimization
        else
          BBOX_OPTIMIZATION_NONE
        end
      end

    end

  end

end
