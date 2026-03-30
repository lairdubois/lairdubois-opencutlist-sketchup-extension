module Ladb::OpenCutList

  require_relative 'plane_manipulator'
  require_relative 'loop_manipulator'
  require_relative '../lib/geometrix/finder/circle_finder'

  class FaceManipulator < PlaneManipulator

    attr_reader :face
    attr_accessor :surface_manipulator

    def initialize(face, transformation = IDENTITY, material = nil)
      raise "face must be a Sketchup::Face." unless face.is_a?(Sketchup::Face)
      super(face.plane, transformation, material)
      @face = face
      @surface_manipulator = nil
    end

    # -----

    def reset_cache
      super
      @normal = nil
      @triangles = nil
      @centroid = nil
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

    def material
      @material ||= @face.material
    end

    def bounds
      outer_loop_manipulator.bounds
    end

    def mesh
      @mesh ||= @face.mesh(4).transform!(@transformation) # PolygonMeshPoints | PolygonMeshNormals
    end

    def triangles
      @triangles ||= mesh.polygons.flat_map do |polygon|
        polygon.map { |index| mesh.point_at(index.abs) }
      end
    end

    def centroid
      @centroid ||= Geometrix::CentroidFinder.find_centroid(outer_loop_manipulator.points)
    end

    def longest_outer_edge
      @longest_outer_edge ||= begin
                                edges = @face.outer_loop.edges
                                visible_edges = edges.reject { |e| !e.visible? || e.smooth? || e.soft? }

                                candidates = (visible_edges.empty? ? edges : visible_edges)
                                               .group_by { |e| e.length(@transformation).round(4) }
                                               .max_by { |length, _| length }
                                               .last

                                candidates.min_by { |e|
                                  _, v = e.line
                                  v.reverse! if e.reversed_in?(@face)
                                  v.angle_between(X_AXIS).abs
                                }
                              end
    end

    def has_cuts_opening?
      @face.get_glued_instances.select { |entity| entity.respond_to?(:definition) && entity.definition.behavior.cuts_opening? }.any?
    end

    def has_inner_loops?
      @face.loops.length > 1
    end

    # -----

    def outer_loop_manipulator
      @outer_loop_manipulator ||= LoopManipulator.new(@face.outer_loop, @transformation, material)
    end

    def loop_manipulators
      @loop_manipulators ||= @face.loops.map { |loop| loop.outer? ? outer_loop_manipulator : LoopManipulator.new(loop, @transformation, material) }
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
