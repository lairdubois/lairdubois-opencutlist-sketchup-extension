module Ladb::OpenCutList::Kuix

  class Segments < Entity3d

    attr_accessor :color
    attr_accessor :line_width, :line_stipple
    attr_accessor :on_top

    def initialize(id = nil)
      super(id)

      @color = nil
      @line_width = 1
      @line_stipple = LINE_STIPPLE_SOLID
      @on_top = false
      @segments = [] # Array<Geom::Point3d>

      @_points = []

    end

    def add_segments(segments) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 2' if segments.length % 2 != 0
      @segments.concat(segments)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @_points = @segments.map { |point|
        point.transform(transformation * @transformation)
      }
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      if @on_top
        points2d = @_points.map { |point| graphics.view.screen_coords(point) }
        graphics.set_drawing_color(@color)
        graphics.set_line_width(@line_width)
        graphics.set_line_stipple(@line_stipple)
        graphics.view.draw2d(GL_LINE_STRIP, points2d)
      else
        graphics.draw_lines(@_points, @color, @line_width, @line_stipple)
      end
      super
    end

  end

end