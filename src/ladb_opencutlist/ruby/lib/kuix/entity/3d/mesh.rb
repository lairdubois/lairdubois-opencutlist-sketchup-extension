module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color

    def initialize(id = nil)
      super(id)

      @background_color = nil

      @points = []

    end

    # -- LAYOUT --

    def do_layout
      @points.clear
      super
    end

    # -- Render --

    def paint_content(graphics)
      graphics.draw_line_loop(@points, @color, @line_width, @line_stipple)
      super
    end

  end

end