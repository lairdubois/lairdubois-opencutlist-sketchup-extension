module BinPacking2D
  class Performance < Packing2D
    attr_accessor :score, :split, :largest_leftover, :cut_length, :nb_bins, :nb_leftovers

    def initialize(score, split)
      @score = score
      @split = split
      @largest_leftover = nil
      @cut_length = 0
      @nb_bins = 0
      @nb_leftovers = 0
    end
    
    def width
      return @largest_leftover.width
    end
    
    def length
      return @largest_leftover.length
    end

    def print
      pstr "#{get_strategy_str(@score,@split)} #{'%3d' % nb_bins} #{cu(@largest_leftover.length)} " + \
        "#{cu(@largest_leftover.width)} #{cu(@cut_length)} #{'%3d' % @nb_leftovers}"
    end
      
  end
end