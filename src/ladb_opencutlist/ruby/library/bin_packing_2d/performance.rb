module BinPacking2D
  class Performance < Packing2D
    attr_accessor :score, :split, :largest_leftover, :cutlength, :nb_bins, :nb_leftovers,
      :v_cutlength, :h_cutlength, :h_length, :v_length

    def initialize(score, split)
      @score = score
      @split = split
      @largest_leftover = nil
      @cutlength = 0
      @nb_bins = 0
      @nb_leftovers = 0
      @h_cutlength = 0
      @v_cutlength = 0
      @h_length = 0
      @v_length = 0
    end
    
    def width
      return @largest_leftover.width
    end
    
    def length
      return @largest_leftover.length
    end

    def print
      pstr "#{get_strategy_str(@score,@split)} #{'%3d' % nb_bins} #{cu(@largest_leftover.length)} " + \
        "#{cu(@largest_leftover.width)} #{cu(@cutlength)} #{cu(@h_cutlength)} " + \
        "#{cu(@h_length)} #{cu(@v_cutlength)} #{cu(@v_length)} #{'%3d' % @nb_leftovers}"
    end
      
  end
end