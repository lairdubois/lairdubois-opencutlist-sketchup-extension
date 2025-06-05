module Ladb::OpenCutList::Kuix

  class Anchor

    TOP = 1
    LEFT = 2
    BOTTOM = 3
    RIGHT = 4
    TOP_LEFT = 5
    TOP_RIGHT = 6
    BOTTOM_LEFT = 7
    BOTTOM_RIGHT = 8
    CENTER = 9

    attr_reader :position

    def initialize(position = TOP_LEFT)
      set!(position)
    end

    def set!(position = TOP_LEFT)
      @position = position
      self
    end

    def copy!(anchor)
      set!(anchor.position) if anchor.respond_to?(:position)
    end

    # -- Properties --

    def top?
      @position == TOP_LEFT || @position == TOP || @position == TOP_RIGHT
    end

    def right?
      @position == TOP_RIGHT || @position == RIGHT || @position == BOTTOM_RIGHT
    end

    def bottom?
      @position == BOTTOM_LEFT || @position == BOTTOM || @position == BOTTOM_RIGHT
    end

    def left?
      @position == TOP_RIGHT || @position == LEFT || @position == BOTTOM_LEFT
    end

    def horizontal_center?
      @position == LEFT || @position == CENTER || @position == RIGHT
    end

    def vertical_center?
      @position == TOP || @position == CENTER || @position == BOTTOM
    end

    # --

    def to_s
      "#{self.class.name} (position=#{position})"
    end

  end

end