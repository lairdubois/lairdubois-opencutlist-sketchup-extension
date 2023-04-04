module Ladb::OpenCutList::Kuix

  class Lines3d < Entity3d

    attr_accessor :pattern_transformation
    attr_accessor :color
    attr_accessor :line_width, :line_stipple

    def initialize(pattern = [], is_loop = true, id = nil)
      super(id)

      @pattern = pattern
      @pattern_transformation = Geom::Transformation.new
      @is_loop = is_loop

      @color = nil
      @line_width = 1
      @line_stipple = ''

      @points = []

    end

    # -- LAYOUT --

    def do_layout(transformation)
      @points.clear
      @pattern.each do |pattern_point|
        pt = Geom::Point3d.new(pattern_point)
        pt.transform!(@pattern_transformation) unless @pattern_transformation.identity?
        point = Geom::Point3d.new(@bounds.x + pt.x * @bounds.width, @bounds.y + pt.y * @bounds.height, @bounds.z + pt.z * @bounds.depth)
        point.transform!(transformation * @transformation)
        @points << point
      end
      super
    end

    # -- Render --

    def paint_content(graphics)
      if @is_loop
        graphics.draw_line_loop(@points, @color, @line_width, @line_stipple)
      else
        graphics.draw_lines(@points, @color, @line_width, @line_stipple)
      end
      super
    end

  end

end