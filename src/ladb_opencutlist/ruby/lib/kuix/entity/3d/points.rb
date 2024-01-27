module Ladb::OpenCutList::Kuix

  class Points < Entity3d

    attr_accessor :size
    attr_accessor :style
    attr_accessor :color
    attr_accessor :line_width, :line_stipple

    def initialize(id = nil)
      super(id)

      @size = 6
      @style = POINT_STYLE_PLUS
      @color = nil
      @line_width = 2
      @line_stipple = LINE_STIPPLE_SOLID
      @points = [] # Array<Geom::Point3d>

      @_points = []

    end

    def add_points(points) # Array<Geom::Point3d>
      @points.concat(points)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @_points = @points.map { |point|
        point.transform(transformation * @transformation)
      }
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      graphics.draw_points(@_points, @size, @style, @color, @line_width, @line_stipple)
      super
    end

  end

end