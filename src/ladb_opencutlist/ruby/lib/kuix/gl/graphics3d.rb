module Ladb::OpenCutList::Kuix

  class Graphics3d < Graphics

    def initialize(view)
      super(view)
    end

    # -- Drawing --

    def draw_lines(points, color = nil, line_width = nil, line_stipple = nil)
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw_lines(points)
    end

    def draw_polyline(points, color = nil, line_width = nil, line_stipple = nil)
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw_polyline(points)
    end

    def draw_line_loop(points, color = nil, line_width = nil, line_stipple = nil)
      set_drawing_color(color) if color
      set_line_width(line_width) if line_width
      set_line_stipple(line_stipple) if line_stipple
      @view.draw(GL_LINE_LOOP, points)
    end

  end

end