module BinPacking2D
  class Cut < Packing2D
    attr_accessor :x, :y, :primary, :length, :horizontal, :index

    def initialize(x, y, length, horizontal, index, primary=true)
      @x = x
      @y = y
      @length = length
      @primary = primary
      @horizontal = horizontal
      @index = index
    end
    
    def print
      f = '%6.0f'
      if @horizontal then
        db "cut H #{f % @x} #{f % @y} l: #{f % @length} i: #{@index}"
      else
        db "cut V #{f % @x} #{f % @y} l: #{f % @length} i: #{@index}"
      end
    end
    
    def get_v_cutlength
      return length if !@horizontal
      return 0
    end

    def get_h_cutlength
      return length if @horizontal
      return 0
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