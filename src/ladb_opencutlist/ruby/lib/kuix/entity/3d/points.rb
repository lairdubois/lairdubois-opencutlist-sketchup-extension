module Ladb::OpenCutList::Kuix

  class Points < Entity3d

    attr_accessor :size
    attr_accessor :style
    attr_accessor :fill_color, :stroke_color
    attr_accessor :stroke_width

    def initialize(id = nil)
      super(id)

      @size = 6
      @style = POINT_STYLE_PLUS
      @fill_color = nil
      @stroke_color = COLOR_BLACK
      @stroke_width = 1
      @points = [] # Array<Geom::Point3d>

      @_points = []

    end

    def add_point(point) # Geom::Point3d
      @points.push(point)
    end

    def add_points(points) # Array<Geom::Point3d>
      @points.concat(points)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      super
      @_points = @points.map { |point| point.transform(transformation * @transformation) }
    end

    # -- RENDER --

    def paint_content(graphics)
      graphics.draw_points(
        points: @_points,
        size: @size,
        style: @style,
        fill_color: @fill_color,
        stroke_color: @stroke_color,
        stroke_width: @stroke_width
      )
      super
    end

  end

end