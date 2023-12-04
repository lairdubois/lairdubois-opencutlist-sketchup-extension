module Ladb::OpenCutList

  class DrawingProjectionDef

    attr_reader :max_depth, :layer_defs

    def initialize(max_depth = 0)
      @max_depth = max_depth
      @layer_defs = []
    end

  end

  class DrawingProjectionLayerDef

    LAYER_POSITION_TOP = 0
    LAYER_POSITION_INSIDE = 1
    LAYER_POSITION_BOTTOM = 2

    attr_reader :depth, :position, :polygon_defs

    def initialize(position, depth, polygon_defs)
      @position = position
      @depth = depth
      @polygon_defs = polygon_defs
    end

    def top?
      @position == LAYER_POSITION_TOP
    end

    def inside?
      @position == LAYER_POSITION_INSIDE
    end

    def bottom?
      @position == LAYER_POSITION_BOTTOM
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