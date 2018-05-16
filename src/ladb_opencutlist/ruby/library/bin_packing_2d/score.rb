module BinPacking2D
  class Score < Packing2D

    # this may not be a good idea, verify please!
    MAX_INT = (2 ** (0.size * 8 - 2) - 1)

    # Compute score by heuristic. The lower the score the better the fit
    #
    def score_by_heuristic(box, bin, score)
      case score
      when SCORE_BESTAREA_FIT
        return bin.length * bin.width - box.length * box.width
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

    # Given a box, find the best suited bin
    #
    def find_position_for_box(box, bins, rotatable, score)
      scores = []

      bins.each_with_index do |bin, index|
        r1 = MAX_INT
        r2 = MAX_INT
        perfect_match = false
        match = false
        perfect_match_rotated = false
        match_rotated = false
        if bin.encloses?(box)
          r1 = score_by_heuristic(box, bin, score)
          match = true
          if box.width == bin.width || box.length == bin.length
            r1 = 0
            perfect_match = true
            s = [index, 0, false]
          end
        elsif rotatable && bin.encloses_rotated?(box)
          b = box.clone
          b.rotate
          r2 = score_by_heuristic(b, bin, score)
          match_rotated = true
          if (b.width == bin.width || b.length == bin.length)
            r2 = 0
            perfect_match_rotated = true
            s = [index, 0, true]
          end
        else
          db "not a perfect match - nothing to do"
        end
        if perfect_match
          s = [index, 0, false]
        elsif perfect_match_rotated
          s = [index, 0, true]
        elsif match && match_rotated
          if r1 < r2
            s = [index, r1, false]
          else
            s = [index, r2, true]
          end
        elsif match
          s = [index, r1, false]
        elsif match_rotated
          s = [index, r2, true]
        else
          s = [-1, r1, false] # this means we have no match whatsoever for this bin
        end
        scores << s
      end

      scores = scores.sort_by { |e| [e[1], bins[e[0]].length] }
      return scores[0][0], scores[0][2]
    end
  end
end
