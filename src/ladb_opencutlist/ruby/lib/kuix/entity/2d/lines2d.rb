module Ladb::OpenCutList::Kuix

  class Lines2d < Entity2d

    attr_reader :pattern_transformation
    attr_accessor :line_width

    def initialize(patterns = [], is_loop = false, id = '')
      super(id)

      @patterns = patterns  # Normalized Array<Array<Kuix::Point2d>>
      @pattern_transformation = Geom::Transformation.new

      @line_width = 1

      @lines = []

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

    # -- Properties --

    def pattern_transformation=(value)
      return if @pattern_transformation == value
      @pattern_transformation = value
      invalidate
    end

    # -- LAYOUT --

    def do_layout

      content_size = self.content_size

      @lines.clear
      @patterns.each do |pattern|
        points = []
        pattern.each do |pattern_point|
          pt = Geom::Point3d.new(pattern_point.x, pattern_point.y, 0)
          pt.transform!(@pattern_transformation) unless @pattern_transformation.identity?
          points << Geom::Point3d.new(pt.x * content_size.width, pt.y * content_size.height, 0)
        end
        @lines.push(points)
      end

      super
    end

    # -- Render --

    def paint_content(graphics)
      if @is_loop
        graphics.draw_line_loop(@points, @color, @line_width)
      else
        @lines.each { |points| graphics.draw_line_strip(points, @color, @line_width) }
      end
      super
    end

  end

end