module Ladb::OpenCutList::BinPacking2D

  class Performance < Packing2D

    attr_accessor :largest_leftover_length, :largest_leftover_width, :nb_bins, :nb_boxes_packed, :nb_leftovers

    def initialize()
      @largest_leftover_length = 0
      @largest_leftover_width = 0
      @nb_bins = 0
      @nb_boxes_packed = 0
      @nb_leftovers = 0
      @packing_quality = 0
    end

  end

end
