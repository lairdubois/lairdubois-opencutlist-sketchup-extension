module Ladb::OpenCutList::Kuix

  class Anchor

    TOP_LEFT = 0
    TOP_CENTER = 1
    TOP_RIGHT = 2
    CENTER_RIGHT = 3
    BOTTOM_RIGHT = 4
    BOTTOM_CENTER = 5
    BOTTOM_LEFT = 6
    CENTER_LEFT = 7
    CENTER = 8

    attr_reader :position

    def initialize(position = TOP_LEFT)
      set!(position)
    end

    def set!(position = TOP_LEFT)
      @position = position
    end

    def copy!(anchor)
      set!(anchor.position)
    end

    # -- Properties --

    def top?
      @position == TOP_LEFT || @position == TOP_CENTER || @position == TOP_RIGHT
    end

    def right?
      @position == TOP_RIGHT || @position == CENTER_RIGHT || @position == BOTTOM_RIGHT
    end

    def bottom?
      @position == BOTTOM_LEFT || @position == BOTTOM_CENTER || @position == BOTTOM_RIGHT
    end

    def left?
      @position == TOP_RIGHT || @position == CENTER_LEFT || @position == BOTTOM_LEFT
    end

    def horizontal_center?
      @position == CENTER_LEFT || @position == CENTER || @position == CENTER_RIGHT
    end

    def vertical_center?
      @position == TOP_CENTER || @position == CENTER || @position == BOTTOM_CENTER
    end

    # --

    def to_s
      "#{self.class.name} (position=#{position})"
    end

  end

end