module Ladb::OpenCutList::Kuix

  class Polyline < Entity3d

    attr_accessor :color
    attr_accessor :line_width, :line_stipple
    attr_accessor :on_top
    attr_accessor :closed

    def initialize(id = nil)
      super(id)

      @color = nil
      @line_width = 1
      @line_stipple = LINE_STIPPLE_SOLID
      @on_top = false
      @points = [] # Array<Geom::Point3d>
      @closed = false

      @_points = []

    end

    def add_points(points) # Array<Geom::Point3d>
      @points.concat(points)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      super
      transformation = transformation * @transformation unless @transformation.identity?
      if transformation.identity?
        @_points = @points
      else
        @_points = @points.map { |point| point.transform(transformation) }
      end
      @extents.add(@_points) unless @on_top || @_points.empty?
    end

    # -- RENDER --

    def paint_content(graphics)
      if @_points.any?
        if @on_top
          points2d = @_points.map { |point| graphics.view.screen_coords(point) }
          graphics.set_drawing_color(@color)
          graphics.set_line_width(@line_width)
          graphics.set_line_stipple(@line_stipple)
          graphics.view.draw2d(@closed ? GL_LINE_LOOP : GL_LINE_STRIP, points2d)
        else
          graphics.set_drawing_color(@color)
          graphics.set_line_width(@line_width)
          graphics.set_line_stipple(@line_stipple)
          graphics.view.draw(@closed ? GL_LINE_LOOP : GL_LINE_STRIP, @_points)
          # graphics.draw_polyline(
          #   points: @_points,
          #   color: @color,
          #   line_width: @line_width,
          #   line_stipple: @line_stipple
          # )
        end
      end
      super
    end

  end

end