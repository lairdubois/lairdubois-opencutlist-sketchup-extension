module BinPacking2D
  class Cut < Packing2D
  
    attr_accessor :x, :y, :length, :width, :is_horizontal, :index, :is_primary

    def initialize(x, y, length, is_horizontal, index, is_primary = true)
      @x = x
      @y = y
      @length = length
      @is_primary = is_primary
      @is_horizontal = is_horizontal
      @index = index
    end
    
    def get_v_cutlength
      return length if !@is_horizontal
      return 0
    end

    def get_h_cutlength
      return length if @is_horizontal
      return 0
    end

  end
end
