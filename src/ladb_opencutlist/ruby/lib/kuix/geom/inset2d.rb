module Ladb::OpenCutList::Kuix

  class Inset2d

    attr_accessor :top, :right, :bottom, :left

    def initialize(top = 0, right = 0, bottom = 0, left = 0)
      set!(top, right, bottom, left)
    end

    def set!(top = 0, right = 0, bottom = 0, left = 0)
      @top = top
      @right = right
      @bottom = bottom
      @left = left
      self
    end

    def set_all!(value = 0)
      set!(value, value, value, value)
    end

    def copy!(inset)
      set!(
        inset.respond_to?(:top) ? inset.top : 0,
        inset.respond_to?(:right) ? inset.right : 0,
        inset.respond_to?(:bottom) ? inset.bottom : 0,
        inset.respond_to?(:left) ? inset.left : 0
      )
    end

    # --

    def to_s
      "#{self.class.name} (top=#{@top}, right=#{@right}, bottom=#{@bottom}, left=#{@left})"
    end

  end

end