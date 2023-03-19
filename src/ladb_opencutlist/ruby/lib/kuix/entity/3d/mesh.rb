module Ladb::OpenCutList::Kuix

  class Mesh < Entity3d

    attr_accessor :background_color

    def initialize(id = nil)
      super(id)

      @background_color = nil
      @triangles = []

      @points = []

    end

    def add_trangles(triangles) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 3' if triangles.length % 3 != 0
      @triangles.concat(triangles)
    end

    # -- LAYOUT --

    def do_layout
      @points = @triangles.map { |point| @transformation.nil? ? point : point.transform(@transformation) }
      super
    end

    # -- Render --

    def paint_content(graphics)
      graphics.draw_triangles(@points, @background_color)
      super
    end

  end

end