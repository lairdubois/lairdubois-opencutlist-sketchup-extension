module Ladb::OpenCutList::BinPacking1D
  #
  # Implements an element to pack into a Bin.
  #
  class Box < Packing1D
  
    # Position of the box inside the enclosing bin.
    attr_accessor :x
    
    # Length of this box.
    attr_reader :length
    
    # Reference to an external object. This value is kept
    # during optimization.
    attr_reader :data
    
    #
    # Initialize a new Box, ensure that it has a length > 0.
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
