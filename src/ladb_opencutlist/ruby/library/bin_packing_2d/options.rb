module Ladb::OpenCutList::BinPacking2D

  class Options < Packing2D

    attr_accessor :base_bin_length, :base_bin_width, :rotatable, :saw_kerf, :trimming, :stacking, :break_stacking_if_needed, :bbox_optimization, :presort
    
    def initialize()
      @base_bin_length = 0.0
      @base_bin_width = 0.0
      @rotatable = false
      @saw_kerf = 0.0
      @trimming = 0.0
      @stacking = STACKING_NONE
      @break_stacking_if_needed = true
      @bbox_optimization = BBOX_OPTIMIZATION_NONE
      @presort = PRESORT_INPUT_ORDER
    end
    
  end

end