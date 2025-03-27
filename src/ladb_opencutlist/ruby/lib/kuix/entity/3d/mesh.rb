module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color

    def initialize(id = nil)
      super(id)

      @background_color = nil
      @triangles = [] # Array<Geom::Point3d>

      @_points = []

    end

    def add_triangles(triangles) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 3' if triangles.length % 3 != 0
      @triangles.concat(triangles)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      super
      @_points = @triangles.map { |point| point.transform(transformation * @transformation) }
      @extents.add(@_points) unless @_points.empty?
    end

    # -- RENDER --

    def paint_content(graphics)
      graphics.draw_triangles(
        points: @_points,
        fill_color: @background_color
      )
      super
    end

  end

end