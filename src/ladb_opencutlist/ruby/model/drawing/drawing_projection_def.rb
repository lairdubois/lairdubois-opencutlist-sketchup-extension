module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../lib/geometrix/finder/curve_finder'

  class DrawingProjectionDef < DataContainer

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

  class DrawingProjectionLayerDef < DataContainer

    TYPE_DEFAULT = 0
    TYPE_UPPER = 1
    TYPE_OUTER = 2
    TYPE_HOLES = 3
    TYPE_OPEN_PATHS = 4
    TYPE_CLOSED_PATHS = 5
    TYPE_BORDERS = 6

    attr_reader :depth, :type, :name, :color, :poly_defs

    def initialize(depth, type, poly_defs, name = nil, color = nil)
      @depth = depth
      @type = type
      @poly_defs = poly_defs
      @name = name
      @color = color
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

    def type_borders?
      @type == TYPE_BORDERS
    end

    def type_paths?
      type_open_paths? || type_closed_paths?
    end

    def type_open_paths?
      @type == TYPE_OPEN_PATHS
    end

    def type_closed_paths?
      @type == TYPE_CLOSED_PATHS
    end

    def has_name?
      @name.is_a?(String) && !@name.empty?
    end

    def has_color?
      @color.is_a?(Sketchup::Color)
    end

  end

  class DrawingProjectionShellDef < DataContainer

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

  class DrawingProjectionShapeDef < DataContainer

    attr_accessor :outer_poly_def
    attr_reader :holes_poly_defs

    def initialize

      @outer_poly_def = nil # DrawingProjectionPolygonDef
      @holes_poly_defs = [] # Array<DrawingProjectionPolygonDef>

    end

    def perforated?
      @holes_poly_defs.any?
    end

  end

  class DrawingProjectionPolyDef < DataContainer

    attr_reader :points

    def initialize(points)
      @points = points
    end

    def closed?
      false
    end

    def curve_def
      @curve_def ||= Geometrix::CurveFinder.find_curve_def(points, closed?)
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
      @segments ||= @points.each_cons(2).to_a.flatten
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
      @segments ||= (@points + [ @points.first ]).each_cons(2).to_a.flatten # Append first point at the end to close loop
      @segments
    end

  end

end