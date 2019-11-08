module Ladb::OpenCutList::BinPacking1D

  class Options < Packing1D

    attr_accessor :base_bin_length, :saw_kerf
    
    def initialize()
      @base_bin_length = 0.0
      @saw_kerf = 0.0
    end
    
  end

end