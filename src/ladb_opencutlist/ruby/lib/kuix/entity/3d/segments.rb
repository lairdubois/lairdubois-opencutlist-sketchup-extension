module Ladb::OpenCutList::Kuix

  class Segments < Entity3d

    attr_accessor :color
    attr_accessor :line_width, :line_stipple

    def initialize(id = nil)
      super(id)

      @color = nil
      @line_width = 1
      @line_stipple = ''
      @segments = [] # Array<Geom::Point3d>

      @points = []

    end

    def add_segments(segments) # Array<Geom::Point3d>
      raise 'Points count must be a multiple of 2' if segments.length % 2 != 0
      @segments.concat(segments)
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @points = @segments.map { |point|
        point.transform(transformation * @transformation)
      }
      super
    end

    # -- RENDER --

    def paint_content(graphics)
      graphics.draw_lines(@points, @color, @line_width, @line_stipple)
      super
    end

  end

end