module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class CurveManipulator < TransformationManipulator

    attr_reader :curve

    def initialize(curve, transformation = IDENTITY)
      super(transformation)
      @curve = curve
    end

    # -----

    def reset_cache
      super
      @points = nil
      @segments = nil
    end

    # -----

    def closed?
      @curve.vertices.first == @curve.vertices.last
    end

    # -----

    def points
      if @points.nil?
        @points = @curve.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if flipped?
      end
      @points
    end

    def segments
      if @segments.nil?
        @segments = points.each_cons(2).to_a.flatten(1)
      end
      @segments
    end

    # -----

    def to_s
      [
        "CURVE",
        "- #{@curve.count_edges} edges",
      ].join("\n")
    end

  end

end
