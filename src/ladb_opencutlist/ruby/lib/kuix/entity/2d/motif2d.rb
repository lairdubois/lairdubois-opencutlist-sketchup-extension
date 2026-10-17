module Ladb::OpenCutList::Kuix

  class Motif2d < Entity2d

    attr_reader :patterns_transformation
    attr_reader :filled  # Filled : each pattern is triangulated and painted as a surface instead of a line strip
    attr_accessor :line_width, :line_stipple

    def initialize(patterns = [], id = nil)
      super(id)

      @patterns = patterns  # Normalized Array<Array<Kuix::Point2d>>
      @patterns_transformation = Geom::Transformation.new

      @line_width = 1
      @line_stipple = LINE_STIPPLE_SOLID
      @filled = false

      @_paths = []
      @_triangles = []

    end

    # -- STATIC --

    # Parses a subset of the SVG path syntax into patterns.
    # Supported : absolute M, L, H, V, Z commands, implicit repetition of the previous command,
    # numbers with or without leading zero (0.75 or .75), optional separators.
    # Ex : 'M0,0.75L0.25,1 M1,0L0.75,0L0.75,1L1,1L1,0' or compact 'M0,.75L.25,1M1,0H.75V1H1Z'
    def self.patterns_from_svg_path(path)
      patterns = []
      pattern = nil
      x = y = nil
      command = nil
      tokens = path.scan(/[MLHVZ]|-?(?:\d+(?:\.\d*)?|\.\d+)/)
      until tokens.empty?

        command = tokens.shift if tokens.first =~ /[MLHVZ]/

        if command == 'Z'
          if pattern && pattern.length > 1
            first = pattern.first
            last = pattern.last
            pattern << Point2d.new(first.x, first.y) unless first.x == last.x && first.y == last.y
            x, y = first.x, first.y
          end
          pattern = nil
          command = nil # Z takes no argument
        end

        arity = case command
                when 'M', 'L'
                  2
                when 'H', 'V'
                  1
                else
                  0
                end
        values = []
        values << tokens.shift.to_f while values.length < arity && tokens.first && tokens.first !~ /[MLHVZ]/
        if arity == 0 || values.length < arity
          tokens.shift while tokens.first && tokens.first !~ /[MLHVZ]/ # Skip stray numbers
          next
        end

        if command == 'M'
          x, y = values
          pattern = [ Point2d.new(x, y) ]
          patterns << pattern
          command = 'L' # Subsequent pairs are implicit L
          next
        end

        next if x.nil? # Drawing before any M is ignored
        if pattern.nil? # Drawing after Z starts from the current point
          pattern = [ Point2d.new(x, y) ]
          patterns << pattern
        end

        case command
        when 'L'
          x, y = values
        when 'H'
          x = values[0]
        when 'V'
          y = values[0]
        end
        pattern << Point2d.new(x, y)

      end
      patterns
    end

    # Triangulates a simple polygon (convex or concave, any winding) by ear clipping.
    # The closing point is optional. Collinear and repeated points are dropped.
    # Returns a flat Array of points, 3 per triangle, empty if the polygon has no area.
    # A self-intersecting polygon does not fail : its remaining part is fanned.
    def self.triangulate(points, epsilon = 1e-9)

      pts = []
      points.each do |point|
        pts << point unless pts.last && (pts.last.x - point.x).abs <= epsilon && (pts.last.y - point.y).abs <= epsilon
      end
      pts.pop while pts.length > 1 && (pts.last.x - pts.first.x).abs <= epsilon && (pts.last.y - pts.first.y).abs <= epsilon
      return [] if pts.length < 3

      cross = lambda { |a, b, c| (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) }

      area2 = 0.0
      pts.each_with_index { |a, i| b = pts[(i + 1) % pts.length]; area2 += a.x * b.y - b.x * a.y }
      return [] if area2.abs <= epsilon

      indices = (0...pts.length).to_a
      indices.reverse! if area2 < 0 # Counter-clockwise from here

      triangles = []
      until indices.length < 3
        n = indices.length
        ear = nil
        n.times do |i|
          a, b, c = pts[indices[(i - 1) % n]], pts[indices[i]], pts[indices[(i + 1) % n]]
          turn = cross.call(a, b, c)
          if turn.abs <= epsilon
            ear = [ i, false ] # Collinear : removed without triangle
            break
          end
          next if turn < 0 # Reflex
          inside = indices.any? do |index|
            p = pts[index]
            next false if p.equal?(a) || p.equal?(b) || p.equal?(c)
            cross.call(a, b, p) >= -epsilon && cross.call(b, c, p) >= -epsilon && cross.call(c, a, p) >= -epsilon
          end
          next if inside
          ear = [ i, true ]
          break
        end
        if ear.nil? # Self-intersecting : fan the rest
          (1...(n - 1)).each { |i| triangles.push(pts[indices[0]], pts[indices[i]], pts[indices[i + 1]]) }
          break
        end
        i, emit = ear
        triangles.push(pts[indices[(i - 1) % n]], pts[indices[i]], pts[indices[(i + 1) % n]]) if emit
        indices.delete_at(i)
      end
      triangles
    end

    # -- PROPERTIES --

    def filled=(value)
      return if @filled == value
      @filled = value
      invalidate
    end

    def patterns_transformation=(value)
      return if @patterns_transformation == value
      @patterns_transformation = value
      invalidate
    end

    # -- LAYOUT --

    def do_layout

      content_size = self.content_size
      no_pattern_transform = @patterns_transformation.identity?

      @_paths.clear
      @patterns.each do |pattern|
        points = []
        pattern.each do |pattern_point|
          pt = Geom::Point3d.new(pattern_point.x, pattern_point.y, 0)
          pt.transform!(@patterns_transformation) unless no_pattern_transform
          points << Geom::Point3d.new(pt.x * content_size.width, pt.y * content_size.height, 0)
        end
        @_paths << points
      end

      @_triangles = @filled ? @_paths.map { |points| Motif2d.triangulate(points) } : []

      super
    end

    # -- RENDER --

    def paint_itself(graphics)
      if @filled
        @_triangles.each do |points|
          graphics.draw_triangles(points: points, fill_color: @color) unless points.empty?
        end
        return super
      end
      @_paths.each do |points|
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