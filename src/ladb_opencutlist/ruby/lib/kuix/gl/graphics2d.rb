module Ladb::OpenCutList::Kuix

  class Graphics2d < Graphics

    def initialize(view)
      super(view)
      @origin = Point2d.new
    end

    def translate(dx, dy)
      @origin.translate!(dx, dy)
    end

    # -- Drawing --

    def draw_rect(x, y, width, height, background_color = nil)
      set_drawing_color(background_color) if background_color
      @view.draw2d(GL_QUADS, Bounds2d.new(
        @origin.x + x,
        @origin.y + y,
        width,
        height
      ).get_points)
    end

    def draw_bordered_rect(x, y, width, height, background_color, border, border_color)
      if border_color
        set_drawing_color(border_color)
        self.draw_rect(x, y, width - border.right, border.top)
        self.draw_rect(x + width - border.right, y, border.right, height - border.bottom)
        self.draw_rect(x + border.left, y + height - border.bottom, width - border.left, border.bottom)
        self.draw_rect(x, y + border.top, border.left, height - border.top)
      end
      if background_color
        self.draw_rect(x + border.left, y + border.top, width - border.left - border.right, height - border.top - border.bottom, background_color)
      end
    end

  end

end