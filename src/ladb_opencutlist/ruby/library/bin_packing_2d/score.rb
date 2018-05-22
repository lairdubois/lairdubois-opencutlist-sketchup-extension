module BinPacking2D
  class Score < Packing2D

    # this may not be a good idea, verify please!
    MAX_INT = (2 ** (0.size * 8 - 2) - 1)

    MATCH_PERFECT = 0
    MATCH_W_OR_L = 1
    MATCH_INSIDE = 2
    NO_MATCH = 3
    
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
        match_score = NO_MATCH
        match_rotated = false

        if bin.encloses?(box)
          r1 = score_by_heuristic(box, bin, score)
          if box.width == bin.width && box.length == box.length
            match_score = MATCH_PERFECT
          elsif box.width == bin.width || box.length == bin.length
            match_score = MATCH_W_OR_L
          else
            match_score = MATCH_INSIDE
          end
        elsif rotatable && bin.encloses_rotated?(box)
          b = box.clone
          b.rotate
          r2 = score_by_heuristic(b, bin, score)
          match_rotated = true
          if box.width == bin.width && box.length == box.length
            match_score = MATCH_PERFECT
          elsif box.width == bin.width || box.length == bin.length
            match_score = MATCH_W_OR_L
          else
            match_score = MATCH_INSIDE
          end
        else
          match_score = NO_MATCH
        end
        
        if match_rotated
          s = [index, r2, match_score, true]
        elsif match_score != NO_MATCH
          s = [index, r1, match_score, false]
        else
          s = [-1, r1, match_score, false]
        end
        scores << s
      end

      # sort by best match score ascending, then heuristic score
      scores = scores.sort_by { |e| [e[2], e[1]] }
      return scores[0][0], scores[0][3]
    end
  end
end
