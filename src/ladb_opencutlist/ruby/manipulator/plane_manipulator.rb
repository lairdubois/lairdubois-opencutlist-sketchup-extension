module Ladb::OpenCutList

  require_relative 'manipulator'

  class PlaneManipulator < Manipulator

    def initialize(plane, transformation = IDENTITY)
      super(transformation)
      raise "Bad plane data structure. Must be an Array." unless plane.is_a?(Array)
      if plane.length == 2
        raise "Bad plane data structure. Must be [ Geom::Point3d, Geom::Vector3d ]." unless plane[0].is_a?(Geom::Point3d) && plane[1].is_a?(Geom::Vector3d)
        @plane_point = plane[0]
        @plane_vector = plane[1]
      elsif plane.length == 4
        raise "Bad plane data structure. Must be [ Float, Float, Float, Float ]." unless plane[0].is_a?(Float) && plane[1].is_a?(Float) && plane[2].is_a?(Float) && plane[3].is_a?(Float)
        @plane_point = Geom::Point3d.new(plane[0..2].map { |v| v * -plane.last })
        @plane_vector = Geom::Vector3d.new(plane[0..2])
      end
    end

    # -----

    def reset_cache
      super
      @plane = nil
      @position = nil
      @normal = nil
    end

    # -----

    def coplanar?(other)
      return normal.samedirection?(other.normal) && other.position.on_plane?(plane) if other.respond_to?(:position) && other.respond_to?(:normal)
      false
    end

    # -----

    def plane
      @plane ||= [ position, normal ]
      @plane
    end

    def position
      @position ||= @plane_point.transform(@transformation)
      @position
    end

    def normal
      @normal ||= @plane_vector.transform(@transformation).normalize
      @normal
    end

    # -----

    def to_s
      [
        "PLANE",
        "- position = #{position}",
        "- normal = #{normal}",
      ].join("\n")
    end

  end

end
