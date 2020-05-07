module Ladb::OpenCutList::BinPacking1D
  class Box < Packing1D
    attr_accessor :x, :length, :data
                  
    def initialize(length, data = nil)
      @x = 0
      @length = length 
      @data = data
    end
  end
end
