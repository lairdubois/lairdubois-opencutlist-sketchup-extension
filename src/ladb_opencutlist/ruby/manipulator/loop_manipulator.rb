module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class LoopManipulator < TransformationManipulator

    attr_reader :loop

    def initialize(loop, transformation = Geom::Transformation.new)
      super(transformation)
      @loop = loop
    end

    # -----

    def reset_cache
      super
      @points = nil
      @segments = nil
      @edge_and_arc_manipulators = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(LoopManipulator)
      @loop == other.loop && super
    end

    # -----

    def points
      if @points.nil?
        @points = @loop.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if flipped?
      end
      @points
    end

    def segments
      if @segments.nil?
        @segments = []
        @loop.edges.each do |edge|
          @segments.concat(EdgeManipulator.new(edge, @transformation).segment)
        end
      end
      @segments
    end

    # -----

    def edge_and_arc_manipulators
      if @edge_and_arc_manipulators.nil?
        captured_curves = []
        @edge_and_arc_manipulators = []
        @loop.edges.each do |edge|
          if edge.curve.is_a?(Sketchup::ArcCurve) && edge.curve.normal.parallel?(@loop.face.normal)
            unless captured_curves.include?(edge.curve)
              @edge_and_arc_manipulators << ArcCurveManipulator.new(edge.curve, @transformation)
              captured_curves << edge.curve
            end
          else
            @edge_and_arc_manipulators << EdgeManipulator.new(edge, @transformation)
          end
        end
      end
      @edge_and_arc_manipulators
    end

    # -----

    def to_s
      [
        "LOOP",
        "- #{@loop.count_edges} edges",
      ].join("\n")
    end

  end

end
