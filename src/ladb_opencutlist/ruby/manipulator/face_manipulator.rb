module Ladb::OpenCutList

  require_relative 'transformation_manipulator'
  require_relative 'plane_manipulator'
  require_relative 'loop_manipulator'
  require_relative '../helper/entities_helper'
  require_relative '../helper/face_triangles_helper'

  class FaceManipulator < PlaneManipulator

    include EntitiesHelper
    include FaceTrianglesHelper

    attr_reader :face
    attr_accessor :surface_manipulator

    def initialize(face, transformation = IDENTITY)
      super(face.plane, transformation)
      @face = face
      @surface_manipulator = nil
    end

    # -----

    def reset_cache
      super
      @outer_loop_points = nil
      @z_max = nil
      @normal = nil
      @triangles = nil
      @loop_manipulators = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(FaceManipulator)
      @face == other.face && super
    end

    def belongs_to_a_surface?
      @face.edges.index { |edge| edge.soft? }
    end

    # -----

    def outer_loop_points
      @outer_loop_points = LoopManipulator.new(@face.outer_loop, @transformation).points if @outer_loop_points.nil?
      @outer_loop_points
    end

    def z_max
      @z_max = outer_loop_points.max { |p1, p2| p1.z <=> p2.z }.z if @z_max.nil?
      @z_max
    end

    def mesh
      @mesh = @face.mesh(4).transform!(@transformation) if @mesh.nil? # PolygonMeshPoints | PolygonMeshNormals
      @mesh
    end

    def triangles
      @triangles = _compute_face_triangles(@face, @transformation) if @triangles.nil?
      @triangles
    end

    def longest_outer_edge
      _find_longest_outer_edge(@face, @transformation)
    end

    # -----

    def loop_manipulators
      @loop_manipulators = @face.loops.map { |loop| LoopManipulator.new(loop, @transformation) } if @loop_manipulators.nil?
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
