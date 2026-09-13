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

      @_paths = []

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

    # -- PROPERTIES --

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

      super
    end

    # -- RENDER --

    def paint_itself(graphics)
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