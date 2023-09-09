module Ladb::OpenCutList

  require_relative 'manipulator'
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
      @face == other.face && (@transformation * other.transformation.inverse).identity?
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

    def outer_loop_points(reset_cache = false)
      if @outer_loop_points.nil? || !reset_cache
        @outer_loop_points = @face.outer_loop.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @outer_loop_points.reverse! if TransformationUtils.flipped?(@transformation)
      end
      @outer_loop_points
    end

    def plane(reset_cache = false)
      if @plane.nil? || !reset_cache
        @plane = Geom.fit_plane_to_points(outer_loop_points(reset_cache))
      end
      @plane
    end

    def plane_point(reset_cache = false)
      if @plane_point.nil? || !reset_cache
        @plane_point = Geom::Point3d.new(plane[0..2].map { |v| v * plane.last })
      end
      @plane_point
    end

    def plane_vector(reset_cache = false)
      if @plane_vector.nil? || !reset_cache
        @plane_vector = Geom::Vector3d.new(plane[0..2])
      end
      @plane_vector
    end

    def normal(reset_cache = false)
      if @normal.nil? || !reset_cache
        @normal = Geom::Vector3d.new(plane(reset_cache)[0..2])
      end
      @normal
    end

    def triangles(reset_cache = false)
      if @triangles.nil? || !reset_cache
        @triangles = _compute_face_triangles(@face, @transformation)
      end
      @triangles

    end

    def longest_outer_edge
      _find_longest_outer_edge(@face, @transformation)
    end

  end

end
