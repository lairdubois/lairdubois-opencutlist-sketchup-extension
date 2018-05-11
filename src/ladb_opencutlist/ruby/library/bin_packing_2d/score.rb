module BinPacking2D
  class Score < Packing2D
    attr_accessor :length, :width, :index, :x, :y, :boxes, :cuts

    MAX_INT = (2 ** (0.size * 8 - 2) - 1)

    def score_by_heuristic(box, bin, heuristic)
      case heuristic
      when SCORE_BESTAREA_FIT
        return bin.length * bin.width - box.length* box.width
      when SCORE_BESTSHORTSIDE_FIT
        return [(bin.length - box.length).abs, (bin.width - box.width).abs].min 
      when SCORE_BESTLONGSIDE_FIT
        return [(bin.length - box.length).abs, (bin.width - box.width).abs].max 
      when SCORE_WORSTAREA_FIT
        return -score_by_heuristic(box, bin, SCORE_BESTAREA_FIT)
      when SCORE_WORSTSHORTSIDE_FIT
        return -score_by_heuristic(box, bin, SCORE_BESTSHORTSIDE_FIT)
      when SCORE_WORSTLONGSIDE_FIT
        return -score_by_heuristic(box, bin, SCORE_BESTLONGSIDE_FIT)
      end
    end
    
    def find_position_for_box (box, bins, rotatable, heuristic)
      best_score = MAX_INT
      best_score_r = MAX_INT
      best_bin = MAX_INT
      best_index = -1
      best_index_r = -1
      using_rotated = false
      bins.each_with_index do |bin, index|
        if  box.length == bin.length && box.width == bin.width
          return index, false
        end
        if bin.encloses?(box)
          score = score_by_heuristic(box, bin, heuristic) 
          if score < best_score 
            best_score = score
            best_index = index
            best_bin = bin.index
          elsif score == best_score 
            if bin.index < best_bin  
              best_score = score
              best_index = index
              best_bin = bin.index
            end
          end
        end    
        if rotatable && bin.encloses_rotated?(box) 
          b = box.clone
          b.rotate
          score = score_by_heuristic(b, bin, heuristic)
        if score < best_score 
            best_score_r = score
            best_index_r = index
            using_rotated = true
          end
        end
      end
      db "#{best_index} #{best_index_r} #{rotatable}"
      if rotatable 
        if best_index == best_index_r && best_index != -1 
          db "found #{best_index} #{using_rotated}"
          return best_index, false
        elsif best_index == -1 && best_index_r != -1 
          db "found #{best_index_r} #{using_rotated}"
          return best_index_r, true
        end
      end
      return best_index, false 
    end
    
  end
end
