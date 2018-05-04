module BinPacking1D
  class Box < Packing1D
  
    attr_accessor :length, :x, :index, :number

    def initialize(length, number)
      @length = length
      @x = 0
      @index = 0
      @number = number
    end
    
=begin
def print
      f = '%6.0f'
      pstr "box #{f % @x} #{f % @length} #{f % @index}"
    end
    
    def label
      f = '%6.0f'
      "#{f % @length}"
    end
=end

  end
end
