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
      raise "face must be a Sketchup::Face." unless face.is_a?(Sketchup::Face)
      @face = face
      @surface_manipulator = nil
    end

    # -----

    def reset_cache
      super
      @z_max = nil
      @normal = nil
      @triangles = nil
      @outer_loop_manipulator = nil
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

    def z_max
      @z_max ||= outer_loop_manipulator.points.max { |p1, p2| p1.z <=> p2.z }.z
      @z_max
    end

    def mesh
      @mesh ||= @face.mesh(4).transform!(@transformation) # PolygonMeshPoints | PolygonMeshNormals
      @mesh
    end

    def triangles
      @triangles ||= _compute_face_triangles(@face, @transformation)
      @triangles
    end

    def longest_outer_edge
      _find_longest_outer_edge(@face, @transformation)
    end

    def has_cuts_opening?
      @face.get_glued_instances.select { |entity| entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening? }.any?
    end

    # -----

    def outer_loop_manipulator
      @outer_loop_manipulator ||= LoopManipulator.new(@face.outer_loop, @transformation)
      @outer_loop_manipulator
    end

    def loop_manipulators
      @loop_manipulators ||= @face.loops.map { |loop| LoopManipulator.new(loop, @transformation) }
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
