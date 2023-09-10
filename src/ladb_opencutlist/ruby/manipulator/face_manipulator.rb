module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative 'loop_manipulator'
  require_relative '../helper/entities_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../utils/transformation_utils'

  class FaceManipulator < Manipulator

    include EntitiesHelper
    include FaceTrianglesHelper

    attr_reader :face

    def initialize(face, transformation = Geom::Transformation.new)
      super(transformation)
      @face = face
    end

    # -----

    def reset_cache
      super
      @outer_loop_points = nil
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
      return false unless other.is_a?(FaceManipulator)
      normal.samedirection?(other.normal)
    end

    # -----

    def outer_loop_points
      if @outer_loop_points.nil?
        @outer_loop_points = @face.outer_loop.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @outer_loop_points.reverse! if TransformationUtils.flipped?(@transformation)
      end
      @outer_loop_points
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
        @normal = Geom::Vector3d.new(plane[0..2])
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
