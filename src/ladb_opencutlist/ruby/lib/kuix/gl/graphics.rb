module Ladb::OpenCutList::Kuix

  class Graphics

    attr_reader :view

    def initialize(view)
      @view = view
    end

    # -- Manipulation --

    def screen_coords(point)
      @view.screen_coords(point)
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

  end

end