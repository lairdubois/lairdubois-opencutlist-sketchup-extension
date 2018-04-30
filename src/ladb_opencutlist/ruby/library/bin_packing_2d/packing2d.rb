module BinPacking2D
  class Packing2D

    @@debugging = false
    
    SCORE_BESTAREA_FIT = 0
    SCORE_BESTSHORTSIDE_FIT = 1
    SCORE_BESTLONGSIDE_FIT = 2
    SCORE_WORSTAREA_FIT = 3
    SCORE_WORSTSHORTSIDE_FIT = 4
    SCORE_WORSTLONGSIDE_FIT = 5

    SPLIT_SHORTERLEFTOVER_AXIS = 0
    SPLIT_LONGERLEFTOVER_AXIS = 1
    SPLIT_MINIMIZE_AREA = 2
    SPLIT_MAXIMIZE_AREA = 3 
    SPLIT_SHORTER_AXIS = 4
    SPLIT_LONGER_AXIS = 5
    
    def get_strategy_str(score, split)
      score_string = [
        "Best Area Fit", 
        "Best Short Side Fit",
        "Best Long Side Fit",
        "Worst Area Fit",
        "Worst Short Side Fit",
        "Worst Long Side Fit"]
      split_string = [
        "Shorter Leftover Axis",
        "Longer Leftover Axis",
        "Minimize Area",
        "Maximize Area",
        "Shorter Axis",
        "Longer Axis"]
      return "#{score}/#{split} #{'%25s' % score_string[score]} / #{'%21s' % split_string[split]}"
    end
    
    def db(str)
      if @@debugging then
        puts " " + str
      end
    end
    
    def pstr(str)
      puts " " + str
    end
    
    # convert to model units
    def cu(l)
      return l.to_l.to_s
    end
    
    # convert to mm for html export
    def cmm(l)
      return l.to_l.to_mm
    end
  end
end