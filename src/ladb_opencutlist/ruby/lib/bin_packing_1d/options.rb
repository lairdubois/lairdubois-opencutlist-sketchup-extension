module Ladb::OpenCutList::BinPacking1D

  class Options
    attr_accessor :base_bin_length, :saw_kerf, :trimsize,
                  :tuning_level,:max_time, :debug
    
    def initialize
      @base_bin_length = 0.0
      @saw_kerf = 0.0
      @trimsize = 0.0
      @tuning_level = 0 # not yet completely defined, 0, 1, 2
      @max_time = 10
      
      @debug = true
    end
  end

end