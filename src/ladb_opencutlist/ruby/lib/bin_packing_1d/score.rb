module Ladb::OpenCutList::BinPacking1D

  class Score < Packing1D

    MAX_INT = (2 ** (0.size * 8 - 2) - 1)

    def find_position_for_box (box, bins)

      # find best position to do!
      best_index = -1
      best_length = MAX_INT
      bins.each_with_index do |bin, index|
        if bin.length == box.length then
          return index
        end
        if bin.encloses?(box) then
          if bin.length < best_length || bin.index < best_index then
            best_index = index
            best_length = bin.length
          end
        end
      end
      return best_index
    end
    
  end
end
