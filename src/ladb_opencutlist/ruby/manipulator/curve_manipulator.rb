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
      @z_max = nil
      @plane = nil
      @plane_point = nil
      @plane_vector = nil
      @normal = nil
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

    def z_max
      if @z_max.nil?
        @z_max = points.max { |p1, p2| p1.z <=> p2.z }.z
      end
      @z_max
    end

    def plane
      if @plane.nil?
        @plane = Geom.fit_plane_to_points(points)
      end
      @plane
    end

    def plane_point
      if @plane_point.nil?
        @plane_point = Geom::Point3d.new(plane[0..2].map { |v| v * plane.last })
      end
      @plane_point
    end

    def plane_vector
      if @plane_vector.nil?
        @plane_vector = Geom::Vector3d.new(plane[0..2])
      end
      @plane_vector
    end

    def normal
      if @normal.nil?
        @normal = plane_vector.normalize
      end
      @normal
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
