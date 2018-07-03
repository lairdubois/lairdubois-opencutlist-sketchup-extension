module Ladb::OpenCutList::BinPacking2D

  MATCH_PERFECT = 0
  MATCH_W_OR_L = 2
  MATCH_INSIDE = 4
  NO_MATCH = 8

  ORIENTATION_NORMAL = 0
  ORIENTATION_ROTATED = 1
  ORIENTATION_INTERNALLY_ROTATED = 2
  ORIENTATION_EXPLODED = 3

  POSITION_NOT_FOUND = -1

  class Score < Packing2D

    # this may not be a good idea, verify please!
    MAX_INT = (2 ** (0.size * 8 - 2) - 1)

    def initialize(options)
      @trimsize = options.trimsize
      @rotatable = !options.has_grain
      @stacking = options.stacking
    end

    # Find next box is used to select a better next box to fit
    # kind of bypassing the presort.
    #
    def find_next_box(boxes, bins)
      return POSITION_NOT_FOUND,POSITION_NOT_FOUND if bins.length == 0
      j_selected = POSITION_NOT_FOUND
      k_selected = POSITION_NOT_FOUND
      y_pos = MAX_INT
      smallest_diff = MAX_INT 
      orientation = ORIENTATION_NORMAL
     
      boxes.each_with_index do |box, j|
        bins.each_with_index do |bin, k|
          if bin.x >= @trimsize && box.width == bin.width && box.length <= bin.length
            diff = bin.length - box.length
            if diff < smallest_diff && bin.y < y_pos
              y_pos = bin.y
              smallest_diff = diff 
              j_selected = j
              k_selected = k
              orientation = ORIENTATION_NORMAL
            end
          elsif bin.x >= @trimsize && @rotatable && box.length == bin.width && box.width <= bin.length
            diff = bin.width - box.width
            if diff < smallest_diff && bin.y < y_pos
              y_pos = bin.y
              j_selected = j
              k_selected = k
              smallest_diff = diff 
              orientation = ORIENTATION_ROTATED
            end
          end
        end
      end
      return j_selected,k_selected,orientation
    end
    
    # Given a box, find the best suited bin
    #
    def find_position_for_box(box, bins, score)

      # scores for the box in all available bins
      scores = []

      # nothing to do, let's not waste time here
      return [-1, MAX_INT, NO_MATCH, ORIENTATION_NORMAL] if bins.empty?
      
      bins.each_with_index do |bin, index| # this is array index, not container bin index!!

        iscores = []
        iscores << [-1, MAX_INT, NO_MATCH, ORIENTATION_NORMAL]

        if bin.encloses?(box)
          r = score_by_heuristic(box, bin, score)
          if box.width == bin.width && box.length == bin.length
            match_score = MATCH_PERFECT
            r = 0
          elsif box.width == bin.width || box.length == bin.length
            match_score = MATCH_W_OR_L
            r = 1
          else
            match_score = MATCH_INSIDE
          end
          iscores << [index, r, match_score, ORIENTATION_NORMAL]
        end
        if @rotatable && bin.encloses_rotated?(box) 
          b = box.copy
          b.rotate
          r = score_by_heuristic(b, bin, score)
          if b.width == bin.width && b.length == bin.length
            match_score = MATCH_PERFECT
            r = 0
          elsif b.width == bin.width || b.length == bin.length
            match_score = MATCH_W_OR_L
            r = 1
          else
            match_score = MATCH_INSIDE
          end
          iscores << [index, r, match_score, ORIENTATION_ROTATED]
        end
        
        if @rotatable && box.is_a?(SuperBox) && bin.encloses_internally_rotated?(box)
          b = box.copy
          b.internal_rotate
          r = score_by_heuristic(b, bin, score)
          if b.width == bin.width && b.length == bin.length
            match_score = MATCH_PERFECT
            r = 0
          elsif b.width == bin.width || b.length == bin.length
            match_score = MATCH_W_OR_L
            r = 1
          else
            match_score = MATCH_INSIDE
          end
          iscores << [index, r, match_score, ORIENTATION_INTERNALLY_ROTATED]
        end  
      
        iscores = iscores.sort_by { |e| [e[1], e[2], e[3]]  }
        scores << iscores[0]
      end

      scores = scores.sort_by { |e| [e[1], e[2], e[3]] }
      return scores[0][0], scores[0][3]
    end
    
    private
    
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

  end

end
