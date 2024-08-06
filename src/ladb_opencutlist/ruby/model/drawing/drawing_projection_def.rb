module Ladb::OpenCutList

  require_relative '../../lib/geometrix/finder/curve_finder'

  class DrawingProjectionDef

    attr_reader :drawing_def, :transformation, :bounds, :max_depth, :layer_defs
    attr_accessor :shell_def

    def initialize(drawing_def, max_depth = 0)

      @drawing_def = drawing_def

      @transformation = IDENTITY
      @bounds = Geom::BoundingBox.new

      @max_depth = max_depth

      @layer_defs = []

      @shell_def = nil  # Stay nil if not computed

    end

    # -----

    def shell_def
      raise 'shell_def must be computed' if @shell_def.nil?
      @shell_def
    end

    # -----

    def translate_to!(point)
      t = Geom::Transformation.translation(Geom::Vector3d.new(point.to_a))
      unless t.identity?

        ti = t.inverse

        @transformation *= t

        unless @bounds.empty?
          min = @bounds.min.transform(ti)
          max = @bounds.max.transform(ti)
          @bounds.clear
          @bounds.add(min, max)
        end

        @layer_defs.each do |layer_def|
          layer_def.poly_defs.each do |poly_def|
            poly_def.points.each do |point|
              point.transform!(ti)
            end
          end
        end

        unless @shell_def.nil?
          @shell_def.shape_defs.each do |shape_def|
            shape_def.outer_poly_def.points.each do |point|
              point.transform!(ti)
            end
            shape_def.holes_poly_defs.each do |poly_def|
              poly_def.points.each do |point|
                point.transform!(ti)
              end
            end
          end
        end

      end

    end

  end

  # -----

  class DrawingProjectionLayerDef

    TYPE_DEFAULT = 0
    TYPE_UPPER = 1
    TYPE_OUTER = 2
    TYPE_HOLES = 3
    TYPE_OPEN_PATH = 4
    TYPE_CLOSED_PATH = 5

    attr_reader :depth, :type, :name, :poly_defs

    def initialize(depth, type, name, poly_defs)
      @depth = depth
      @type = type
      @name = name
      @poly_defs = poly_defs
    end

    def type_upper?
      @type == TYPE_UPPER || @type == TYPE_OUTER
    end

    def type_outer?
      @type == TYPE_OUTER
    end

    def type_holes?
      @type == TYPE_HOLES
    end

    def type_path?
      type_open_path? || type_closed_path?
    end

    def type_open_path?
      @type == TYPE_OPEN_PATH
    end

    def type_closed_path?
      @type == TYPE_CLOSED_PATH
    end

  end

  class DrawingProjectionShellDef

    attr_reader :shape_defs

    def initialize

      @shape_defs = []

    end

    def manifold?
      @shape_defs.length > 1
    end

    def perforated?
      !@shape_defs.index(&:perforated?).nil?
    end

  end

  class DrawingProjectionShapeDef

    attr_accessor :outer_poly_def
    attr_reader :holes_poly_defs

    def initialize

      @outer_poly_def = nil # DrawingProjectionPolyDef
      @holes_poly_defs = [] # Array<DrawingProjectionPolyDef>

    end

    def perforated?
      @holes_poly_defs.any?
    end

  end

  class DrawingProjectionPolyDef

    attr_reader :points

    def initialize(points)
      @points = points
    end

    def closed?
      false
    end

    def curve_def
      if @curve_def.nil?
        @curve_def = Geometrix::CurveFinder.find_curve_def(points, closed?)
      end
      @curve_def
    end

  end

  class DrawingProjectionPolylineDef < DrawingProjectionPolyDef

    def initialize(points)
      super
    end

    def start_point
      @points.first
    end

    def end_point
      @points.last
    end

    def segments
      if @segments.nil?
        @segments = @points.each_cons(2).to_a.flatten
      end
      @segments
    end

  end

  class DrawingProjectionPolygonDef < DrawingProjectionPolyDef

    def initialize(points, ccw)
      super(points)
      @ccw = ccw
    end

    def closed?
      true
    end

    def ccw?
      @ccw
    end

    def segments
      if @segments.nil?
        @segments = (@points + [ @points.first ]).each_cons(2).to_a.flatten # Append first point at the end to close loop
      end
      @segments
    end

  end

end