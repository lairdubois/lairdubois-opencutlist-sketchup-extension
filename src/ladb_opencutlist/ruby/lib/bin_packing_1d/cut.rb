module Ladb::OpenCutList::BinPacking1D

  class Cut < Packing1D

    attr_accessor :x, :index

    def initialize(x, index)
      @x = x
      @index = index
    end
    
    def print
      pstr "cut V #{'%6.0f' % @x}"
    end
    
    def label
        #if @horizontal then
        #  "#{@length} at [#{@x},#{@y}]"
        #else
        #  "#{@length} at [#{@x},#{@y}]"
        #end
    end
    
  end
end