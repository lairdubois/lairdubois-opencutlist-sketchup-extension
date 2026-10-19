module Ladb::OpenCutList::Kuix

  class Motif2d < Entity2d

    attr_reader :patterns_transformation
    attr_accessor :line_width, :line_stipple

    def initialize(patterns = [], id = nil)
      super(id)

      @patterns = patterns  # Normalized Array<Array<Kuix::Point2d>>
      @patterns_transformation = Geom::Transformation.new

      @line_width = 1
      @line_stipple = LINE_STIPPLE_SOLID

      @paths = []

    end

    # -- STATIC --

    def self.patterns_from_svg_path(path)
      patterns = []
      pattern = []
      path.scan(Regexp.new('([ML])(\d+(?:\.\d+)*),(\d(?:\.\d+)*)')) do |m|
        if m[0] == 'M'
          pattern = []
          patterns.push(pattern)
        end
        if m[0] == 'M' || m[0] == 'L'
          pattern << Point2d.new(m[1].to_f, m[2].to_f)
        end
      end
      patterns
    end

    # -- PROPERTIES --

    def patterns_transformation=(value)
      return if @patterns_transformation == value
      @patterns_transformation = value
      invalidate
    end

    # -- LAYOUT --

    def do_layout

      content_size = self.content_size

      @paths.clear
      @patterns.each do |pattern|
        points = []
        pattern.each do |pattern_point|
          pt = Geom::Point3d.new(pattern_point.x, pattern_point.y, 0)
          pt.transform!(@patterns_transformation) unless @patterns_transformation.identity?
          points << Geom::Point3d.new(pt.x * content_size.width, pt.y * content_size.height, 0)
        end
        @paths << points
      end

      super
    end

    # -- RENDER --

    def paint_content(graphics)
      @paths.each do |points|
        graphics.draw_line_strip(
          points: points,
          color: @color,
          line_width: @line_width,
          line_stipple: @line_stipple
        )
      end
      super
    end

  end

  class RectangleMotif2d < Motif2d

    def initialize(id = nil)
      super([[

               [ 0, 0 ],
               [ 1, 0 ],
               [ 1, 1 ],
               [ 0, 1 ],
               [ 0, 0 ],

             ]], id)
    end

  end

end