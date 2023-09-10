module Ladb::OpenCutList

  require_relative 'manipulator'

  class ArcCurveManipulator < Manipulator

    attr_reader :arc_curve

    def initialize(arc_curve, transformation = Geom::Transformation.new)
      super(transformation)
      @arc_curve = arc_curve
    end

    # -----

    def reset_cache
      super
    end

    # -----

    def start
      points.first
    end

    def end
      points.last
    end

    def points
      if @points.nil?
        @points = @arc_curve.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if TransformationUtils.flipped?(@transformation)
      end
      @points
    end

    def segments
      if @segments.nil?
        @segments = []
        @arc_curve.each_edge do |edge|
          @segments.concat(EdgeManipulator.new(edge, @transformation).segment)
        end
      end
      @segments
    end

    # -----

    def reversed_in?(face)
      @arc_curve.first_edge.reversed_in?(face)
    end

    # -----

    def to_s
      "CURVE from #{self.start} -> #{self.end} #{@arc_curve.count_edges} edges"
    end

  end

end
