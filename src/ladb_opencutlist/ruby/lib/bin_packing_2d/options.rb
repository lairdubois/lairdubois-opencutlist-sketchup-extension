module Ladb::OpenCutList::BinPacking2D

  class Options < Packing2D

    attr_accessor :base_bin_length, :base_bin_width, :has_grain, :saw_kerf, :trimsize, :stacking, :break_stacking_if_needed, :bbox_optimization, :presort
    
    def initialize()
      @base_bin_length = 0.0
      @base_bin_width = 0.0
      @has_grain = true
      @saw_kerf = 0.0
      @trimsize = 0.0
      @stacking = STACKING_NONE
      @break_stacking_if_needed = true
      @bbox_optimization = BBOX_OPTIMIZATION_NONE
      @presort = PRESORT_INPUT_ORDER
    end
    
  end

end