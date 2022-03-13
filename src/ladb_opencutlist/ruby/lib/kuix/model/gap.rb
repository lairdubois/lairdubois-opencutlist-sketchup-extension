module Ladb::OpenCutList::Kuix

  class Gap

    attr_accessor :horizontal, :vertical

    def initialize(horizontal = 0, vertical = 0)
      set(horizontal, vertical)
    end

    def set(horizontal = 0, vertical = 0)
      @horizontal = horizontal
      @vertical = vertical
    end

    def copy(gap)
      set(gap.horizontal, gap.vertical)
    end

    # --

    def to_s
      "#{self.class.name} (horizontal=#{@horizontal}, vertical=#{@vertical})"
    end

  end

end