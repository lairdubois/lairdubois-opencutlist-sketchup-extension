module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class CurveManipulator < TransformationManipulator

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
      @z_max = nil
      @segments = nil
      @plane_manipulator = nil
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

    def z_max
      @z_max ||= points.max { |p1, p2| p1.z <=> p2.z }.z
      @z_max
    end

    def plane
      plane_manipulator.plane
    end

    def normal
      plane_manipulator.normal
    end

    def segments
      @segments ||= points.each_cons(2).to_a.flatten(1)
      @segments
    end

    # -----

    def plane_manipulator
      @plane_manipulator ||= PlaneManipulator.new(Geom.fit_plane_to_points(points))
      @plane_manipulator
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
