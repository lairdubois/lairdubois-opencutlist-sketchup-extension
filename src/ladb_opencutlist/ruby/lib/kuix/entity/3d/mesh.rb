module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color
    attr_accessor :on_top

    def initialize(id = nil)
      super(id)

      @background_color = nil
      @on_top = false

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

    def do_layout_content(transformation)
      if transformation.identity?
        @_triangle_points = @triangles
        @_quad_points = @quads
      else
        @_triangle_points = @triangles.map { |point| point.transform(transformation) }
        @_quad_points = @quads.map { |point| point.transform(transformation) }
      end
      @extents.add(@_triangle_points) unless @_triangle_points.empty?
      @extents.add(@_quad_points) unless @_quad_points.empty?
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      if @on_top
        begin
          graphics.set_drawing_color(@background_color) if @background_color.is_a?(Sketchup::Color)
          graphics.view.draw2d(GL_TRIANGLES, @_triangle_points.map { |point| graphics.view.screen_coords(point) })
        end unless @_triangle_points.empty?
        begin
          graphics.set_drawing_color(@background_color) if @background_color.is_a?(Sketchup::Color)
          graphics.view.draw2d(GL_QUADS, @_quad_points.map { |point| graphics.view.screen_coords(point) })
        end unless @_quad_points.empty?
      else
        graphics.draw_triangles(
          points: @_triangle_points,
          fill_color: @background_color
        ) unless @_triangle_points.empty?
        graphics.draw_quads(
          points: @_quad_points,
          fill_color: @background_color
        ) unless @_quad_points.empty?
      end
      super
    end

  end

end