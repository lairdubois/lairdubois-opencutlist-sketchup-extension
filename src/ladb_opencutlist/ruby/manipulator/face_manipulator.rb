module Ladb::OpenCutList

  require_relative 'plane_manipulator'
  require_relative 'loop_manipulator'
  require_relative '../helper/face_matcher_helper'
  require_relative '../lib/geometrix/geometrix'

  class FaceManipulator < PlaneManipulator

    include FaceMatcherHelper

    attr_reader :face
    attr_accessor :surface_manipulator

    def initialize(face, transformation = IDENTITY, material = nil, layer = nil)
      raise "face must be a Sketchup::Face." unless face.is_a?(Sketchup::Face)
      super(face.plane, transformation, _combine_material(face.material, material), _combine_layer(face.layer, layer))
      @face = face
      @surface_manipulator = nil
    end

    # -----

    def reset_cache
      super
      @normal = nil
      @triangles = nil
      @centroid = nil
      @pole_of_inaccessibility = nil
      @outer_loop_manipulator = nil
      @inner_loop_manipulators = nil
      @loop_manipulators = nil
      @signatures = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(FaceManipulator)
      @face == other.face && super
    end

    def belongs_to_a_surface?
      @face.edges.any?(&:soft?)
    end

    # -----

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
      @centroid ||= Geometrix::PointFinder.find_centroid(outer_loop_manipulator.points)
    end

    def pole_of_inaccessibility
      @pole_of_inaccessibility ||= begin

                                     # find_pole_of_inaccessibility only considers X and Y point coordinates : project loops into the face's plane local space
                                     t = Geom::Transformation.new(position, normal)
                                     ti = t.inverse

                                     pole = Geometrix::PointFinder.find_pole_of_inaccessibility(
                                       outer_loop_manipulator.points.map { |point| point.transform(ti) },
                                       inner_loop_manipulators.map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ti) } }
                                     )

                                     pole.nil? ? nil : pole.transform(t)
                                   end
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

    def signature(mirror: true)
      @signatures ||= {}
      @signatures[mirror] = _face_signature(self, mirror: mirror) unless @signatures.key?(mirror)
      @signatures[mirror]
    end

    # -----

    def outer_loop_manipulator
      @outer_loop_manipulator ||= LoopManipulator.new(@face.outer_loop, @transformation, material, layer)
    end

    def inner_loop_manipulators
      @inner_loop_manipulators ||= @face.loops
                                        .reject { |loop| loop.outer? }
                                        .map { |loop| LoopManipulator.new(loop, @transformation, material, layer) }
    end

    def loop_manipulators
      @loop_manipulators ||= [ outer_loop_manipulator ] + inner_loop_manipulators
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
