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

    def draw_line_strip(points, color = nil, line_width = nil, line_stripple = '')
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stripple) if line_stripple
      @view.draw2d(GL_LINE_STRIP, points.map { |point| Geom::Point3d.new(@origin.x + point.x, @origin.y + point.y, 0) })
    end

    def draw_line_loop(points, color = nil, line_width = nil, line_stripple = '')
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stripple) if line_stripple
      @view.draw2d(GL_LINE_LOOP, points.map { |point| Geom::Point3d.new(@origin.x + point.x, @origin.y + point.y, 0) })
    end

    def draw_triangle(x1, y1, x2, y2, x3, y3, color = nil)
      set_drawing_color(color) if color
      @view.draw2d(GL_TRIANGLES, [
        Geom::Point3d.new(@origin.x + x1, @origin.y + y1, 0),
        Geom::Point3d.new(@origin.x + x2, @origin.y + y2, 0),
        Geom::Point3d.new(@origin.x + x3, @origin.y + y3, 0)
      ])
    end

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