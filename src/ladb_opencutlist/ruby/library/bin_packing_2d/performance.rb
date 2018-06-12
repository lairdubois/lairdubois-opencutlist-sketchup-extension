module BinPacking2D
  class Performance < Packing2D
    attr_accessor :largest_leftover, :cutlength, :nb_bins, :nb_leftovers,
      :v_cutlength, :h_cutlength, :h_length, :v_length, :max_x, :max_y, :packing_quality

    def initialize()
      @largest_leftover = nil
      @cutlength = 0
      @nb_bins = 0
      @nb_leftovers = 0
      @h_cutlength = 0
      @v_cutlength = 0
      @h_length = 0
      @v_length = 0
      @max_x = 0
      @max_y = 0
      @packing_quality = 0
    end

  end
end
