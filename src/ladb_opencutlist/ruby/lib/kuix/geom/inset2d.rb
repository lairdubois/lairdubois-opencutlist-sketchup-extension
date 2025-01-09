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
    end

    def set_all!(value = 0)
      set!(value, value, value, value)
    end

    def copy!(inset)
      set!(inset.top, inset.right, inset.bottom, inset.left)
    end

    # --

    def to_s
      "#{self.class.name} (top=#{@top}, right=#{@right}, bottom=#{@bottom}, left=#{@left})"
    end

  end

end