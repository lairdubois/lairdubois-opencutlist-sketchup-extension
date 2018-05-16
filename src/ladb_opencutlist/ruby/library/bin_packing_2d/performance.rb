module BinPacking2D
  class Performance < Packing2D
    attr_accessor :score, :split, :largest_leftover, :cutlength, :nb_bins, :nb_leftovers,
      :v_cutlength, :h_cutlength, :h_length, :v_length, :max_x, :max_y

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
      @max_x = 0
      @max_y = 0
    end

    def print
      puts " #{get_strategy_str(@score, @split)} #{"%3d" % nb_bins} #{cu(@largest_leftover.length)} " + "#{cu(@largest_leftover.width)} #{cu(@cutlength)} " + "#{cu(@v_cutlength)} #{cu(@v_length)} #{cu(@largest_leftover.area())}"
    end
  end
end
