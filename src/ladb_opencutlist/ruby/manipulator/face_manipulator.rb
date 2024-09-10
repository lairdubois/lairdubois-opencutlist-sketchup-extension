module Ladb::OpenCutList

  require_relative 'transformation_manipulator'
  require_relative 'loop_manipulator'
  require_relative '../helper/entities_helper'
  require_relative '../helper/face_triangles_helper'

  class FaceManipulator < TransformationManipulator

    include EntitiesHelper
    include FaceTrianglesHelper

    attr_reader :face
    attr_accessor :surface_manipulator

    def initialize(face, transformation = IDENTITY)
      super(transformation)
      @face = face
      @surface_manipulator = nil
    end

    # -----

    def reset_cache
      super
      @outer_loop_points = nil
      @z_max = nil
      @plane = nil
      @plane_point = nil
      @plane_vector = nil
      @normal = nil
      @triangles = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(FaceManipulator)
      @face == other.face && super
    end

    def coplanar?(other)
      return false unless other.is_a?(FaceManipulator)
      (other.plane_point - plane_point).length == 0 && plane_vector.samedirection?(other.plane_vector)
    end

    def parallel?(other)
      return normal.samedirection?(other.normal) if other.respond_to?(:normal)
      return normal.samedirection?(other) if other.is_a?(Geom::Vector3d)
      false
    end

    def perpendicular?(other)
      return normal.perpendicular?(other.normal) if other.respond_to?(:normal)
      return normal.perpendicular?(other) if other.is_a?(Geom::Vector3d)
      false
    end

    def angle_between(other)
      return normal.angle_between(other.normal) if other.respond_to?(:normal)
      return normal.angle_between(other) if other.is_a?(Geom::Vector3d)
      nil
    end

    def belongs_to_a_surface?
      @face.edges.index { |edge| edge.soft? }
    end

    # -----

    def outer_loop_points
      if @outer_loop_points.nil?
        @outer_loop_points = LoopManipulator.new(@face.outer_loop, @transformation).points
      end
      @outer_loop_points
    end

    def z_max
      if @z_max.nil?
        @z_max = outer_loop_points.max { |p1, p2| p1.z <=> p2.z }.z
      end
      @z_max
    end

    def plane
      if @plane.nil?
        @plane = Geom.fit_plane_to_points(outer_loop_points)
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

    def mesh
      if @mesh.nil?
        @mesh = @face.mesh(4) # PolygonMeshPoints | PolygonMeshNormals
        @mesh.transform!(@transformation)
      end
      @mesh
    end

    def triangles
      if @triangles.nil?
        @triangles = _compute_face_triangles(@face, @transformation)
      end
      @triangles
    end

    def longest_outer_edge
      _find_longest_outer_edge(@face, @transformation)
    end

    def has_cuts_opening?
      @face.get_glued_instances.select { |entity| entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening? }.any?
    end

    # -----

    def loop_manipulators
      if @loop_manipulators.nil?
        @loop_manipulators = @face.loops.map { |loop| LoopManipulator.new(loop, @transformation) }
      end
      @loop_manipulators
    end

    # -----

    def to_s
      [
        "FACE",
        "- #{@face.loops.length} loops",
        "- plane = #{plane}",
      ].join("\n")
    end

  end

end
