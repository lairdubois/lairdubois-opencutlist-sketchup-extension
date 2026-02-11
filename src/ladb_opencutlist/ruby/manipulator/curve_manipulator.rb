module Ladb::OpenCutList

  require_relative 'manipulator'

  class CurveManipulator < Manipulator

    attr_reader :curve

    def initialize(curve, transformation = IDENTITY)
      super(transformation)
      raise "curve must be a Sketchup::Curve." unless curve.is_a?(Sketchup::Curve)
      @curve = curve
    end

    # -----

    def reset_cache
      super
      @points = nil
      @bounds = nil
      @segments = nil
      @plane_manipulator = nil
    end

    # -----

    def closed?
      @curve.vertices.first == @curve.vertices.last
    end

    # -----

    def points
      @points ||= begin
        @points = @curve.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if flipped?
        @points
      end
    end

    def bounds
      @bounds ||= Geom::BoundingBox.new.add(points)
    end

    def plane
      plane_manipulator.plane
    end

    def normal
      plane_manipulator.normal
    end

    def segments
      @segments ||= points.each_cons(2).to_a.flatten(1)
    end

    # -----

    def plane_manipulator
      @plane_manipulator ||= PlaneManipulator.new(Geom.fit_plane_to_points(points), IDENTITY)
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
