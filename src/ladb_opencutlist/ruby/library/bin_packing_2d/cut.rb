module BinPacking2D
  class Cut < Packing2D
    attr_accessor :x, :y, :position, :length, :horizontal, :index

    def initialize(x, y, position, length, horizontal, index)
      @x = x
      @y = y
      @position = position
      @length = length
      @horizontal = horizontal
      @index = index
    end
    
    def print
      f = '%6.0f'
      if @horizontal then
        db "cut H #{f % @x} #{f % @y} l: #{f % @length}"
      else
        db "cut V #{f % @x} #{f % @y} l: #{f % @length}"
      end
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