module Ladb::OpenCutList::Kuix

  class Graphics

    attr_reader :view

    def initialize(view)
      @view = view
    end

    # -- Drawing --

    def set_drawing_color(color)
      @view.drawing_color = color
    end

    def set_line_width(line_width)
      @view.line_width = line_width
    end

    def set_line_stipple(line_stipple)
      @view.line_stipple = line_stipple
    end

    def draw_text(x, y, text, text_options)
      @view.draw_text(Geom::Point3d.new(@origin.x + x, @origin.y + y, 0), text, text_options)
    end

  end

end