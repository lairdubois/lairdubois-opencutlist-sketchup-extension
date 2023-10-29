module Ladb::OpenCutList::Kuix

  class Progress < Entity2d

    attr_reader :min, :max, :value

    def initialize(min = 0.0, max = 1.0)
      super(id)

      @min = min
      @max = max
      @value = 0.0

    end

    # -- PROPERTIES --

    def value=(value)
      @value = value
      invalidate
    end

    # -- RENDER --

    def paint_content(graphics)

      width = (@bounds.width - @margin.left - @border.left - @margin.right - @border.right) * @value / (@max - @min)
      height = @bounds.height - @margin.top - @border.top - @margin.bottom - @border.bottom

      graphics.draw_rect(0, 0, width, height, @color)
      super
    end

  end

end