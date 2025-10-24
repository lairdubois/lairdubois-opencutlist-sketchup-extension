module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color

    def initialize(id = nil)
      super(id)

      @background_color = nil
      @triangles = [] # Array<Geom::Point3d>
      @quads = [] # Array<Geom::Point3d>

      @_triangle_points = []
      @_quad_points = []

    end

    def add_triangles(triangles) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 3' if triangles.length % 3 != 0
      @triangles.concat(triangles)
    end

    def add_quads(quads) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 4' if quads.length % 4 != 0
      @quads.concat(quads)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      super
      @_triangle_points = @triangles.map { |point| point.transform(transformation * @transformation) }
      @extents.add(@_triangle_points) unless @_triangle_points.empty?
      @_quad_points = @quads.map { |point| point.transform(transformation * @transformation) }
      @extents.add(@_quad_points) unless @_quad_points.empty?
    end

    # -- RENDER --

    def paint_content(graphics)
      graphics.draw_triangles(
        points: @_triangle_points,
        fill_color: @background_color
      ) unless @_triangle_points.empty?
      graphics.draw_quads(
        points: @_quad_points,
        fill_color: @background_color
      ) unless @_quad_points.empty?
      super
    end

  end

end