module Ladb::OpenCutList::BinPacking1D
  #
  # Implements an element to pack into a Bin
  #
  class Box < Packing1D
  
    # position of the box inside the enclosing bin
    attr_accessor :x
    
    # length of this box
    attr_reader :length
    
    # reference to an external object. This value is kept
    # during optimization.
    attr_reader :data
    
    #
    # initialize the box, ensure that it has a length > 0
    #
    def initialize(length = 0, data = nil)
      @x = 0.0
      @length = length*1.0
      if @length <= 0
        raise(Packing1DError, "Trying to initialize a box with zero or negative length")
      end
      @data = data
    end
  end
end
