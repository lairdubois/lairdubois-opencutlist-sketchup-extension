module Ladb::OpenCutList::BinPacking1D

  class Options
    attr_accessor :std_length, :saw_kerf, :trim_size,
                  :bar_width, :bar_height, :tuning_level,
                  :max_time, :debug
    
    def initialize
      @std_length = 0.0
      @saw_kerf = 0.0
      @trim_size = 0.0
      @bar_width = 0.0
      @bar_height = 0.0
      @tuning_level = 0 # not yet completely defined, 0, 1, 2
      @max_time = 10
      
      @debug = true
    end
  end

end