module Ladb::OpenCutList

  class DrawingProjectionDef

    attr_reader :max_depth, :layer_defs

    def initialize(max_depth = 0)
      @max_depth = max_depth
      @layer_defs = []
    end

  end

  class DrawingProjectionLayerDef

    TYPE_DEFAULT = 0
    TYPE_OUTER = 1
    TYPE_HOLES = 2

    attr_reader :depth, :type, :polygon_defs

    def initialize(depth, type, polygon_defs)
      @depth = depth
      @type = type
      @polygon_defs = polygon_defs
    end

    def outer?
      @type == TYPE_OUTER
    end

    def holes?
      @type == TYPE_HOLES
    end

  end

  class DrawingProjectionPolygonDef

    attr_reader :points

    def initialize(points, is_outer)
      @points = points
      @is_outer = is_outer
    end

    def outer?
      @is_outer
    end

    def segments
      if @segments.nil?
        @segments = (@points + [ @points.first ]).each_cons(2).to_a.flatten # Append first point at the end to close loop
      end
      @segments
    end

    def loop_def
      if @loop_def.nil?

        require_relative '../../lib/geometrix/finder/loop_finder'

        @loop_def = Geometrix::LoopFinder.find_loop_def(points)

      end
      @loop_def
    end

  end

end