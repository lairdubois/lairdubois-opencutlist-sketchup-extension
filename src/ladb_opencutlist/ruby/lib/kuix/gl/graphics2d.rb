module Ladb::OpenCutList::Kuix

  class Graphics2d < Graphics

    def initialize(view)
      super
      @origin = Point2d.new
    end

    def translate(dx, dy)
      @origin.translate!(dx, dy)
    end

    # -- Drawing --

    def draw_text(
      x:,
      y:,
      text:,
      text_options:
    )
      @view.draw_text(Geom::Point3d.new(@origin.x + x, @origin.y + y, 0), text, text_options)
    end

    def draw_line_strip(
      points:,
      color: nil,
      line_width: nil,
      line_stipple: LINE_STIPPLE_SOLID
    )
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw2d(GL_LINE_STRIP, points.map { |point| Geom::Point3d.new(@origin.x + point.x, @origin.y + point.y, 0) })
    end

    def draw_line_loop(
      points:,
      color: nil,
      line_width: nil,
      line_stipple: LINE_STIPPLE_SOLID
    )
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw2d(GL_LINE_LOOP, points.map { |point| Geom::Point3d.new(@origin.x + point.x, @origin.y + point.y, 0) })
    end

    def draw_triangle(
      x1:,
      y1:,
      x2:,
      y2:,
      x3:,
      y3:,
      fill_color: nil
    )
      set_drawing_color(fill_color) if fill_color
      @view.draw2d(GL_TRIANGLES, [
        Geom::Point3d.new(@origin.x + x1, @origin.y + y1, 0),
        Geom::Point3d.new(@origin.x + x2, @origin.y + y2, 0),
        Geom::Point3d.new(@origin.x + x3, @origin.y + y3, 0)
      ])
    end

    def draw_rect(
      x:,
      y:,
      width:,
      height:,
      fill_color: nil
    )
      set_drawing_color(fill_color) if fill_color
      @view.draw2d(GL_QUADS, Bounds2d.new(
        @origin.x + x,
        @origin.y + y,
        width,
        height
      ).get_quad)
    end

  end

end