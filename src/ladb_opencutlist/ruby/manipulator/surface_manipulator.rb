module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative '../helper/layer_visibility_helper'

  class SurfaceManipulator < Manipulator

    include LayerVisibilityHelper

    attr_reader :faces

    def initialize(transformation = IDENTITY)
      super
      @faces = Set.new
    end

    # -----

    def populate_from_face(face)
      explored_faces = Set.new
      faces_to_explore = [ face ]
      until faces_to_explore.empty?
        current_face = faces_to_explore.pop
        current_face.edges.each do |edge|
          next unless edge.soft?
          @faces.add(current_face)
          edge.faces.each do |f|
            next if f == current_face
            next unless f.visible? && _layer_visible?(f.layer)
            next if explored_faces.include?(f)
            faces_to_explore.push(f)
          end
        end
        explored_faces.add(current_face)
      end
      self
    end

    # -----

    def reset_cache
      super
      @flat = nil
      @outer_loops_points = nil
      @bounds = nil
    end

    # -----

    def include?(face)
      @faces.include?(face)
    end

    def flat?
      @flat ||= @faces.each_cons(2).all? { |face_a, face_b| face_a.normal.parallel?(face_b.normal) }
    end

    # -----

    def outer_loops_points
      @outer_loops_points ||= begin
        @outer_loops_points = @faces.flat_map { |face| face.outer_loop.vertices.map { |vertex| vertex.position.transform(@transformation) } }
        @outer_loops_points.reverse! if flipped?
        @outer_loops_points
      end
    end

    def bounds
      @bounds ||= Geom::BoundingBox.new.add(outer_loops_points)
    end

    # -----

    def to_s
      [
        "SURFACE",
        "- #{@faces.count} faces",
      ].join("\n")
    end

  end

end
