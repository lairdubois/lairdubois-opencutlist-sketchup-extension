module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative '../helper/layer_visibility_helper'

  class SurfaceManipulator < TransformationManipulator

    include LayerVisibilityHelper

    attr_reader :faces

    def initialize(transformation = IDENTITY)
      super
      @faces = []
    end

    # -----

    def populate_from_face(face)
      explored_faces = Set.new
      faces_to_explore = [ face ]
      until faces_to_explore.empty?
        current_face = faces_to_explore.pop
        current_face.edges.each do |edge|
          next unless edge.soft?
          faces.push(current_face)
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
      @outer_loops_points = nil
      @bounds = nil
      @z_min = nil
      @z_max = nil
    end

    # -----

    def include?(face)
      @faces.include?(face)
    end

    def flat?
      @faces.each_cons(2) { |face_a, face_b| return false unless face_a.normal.parallel?(face_b.normal) }
      true
    end

    # -----

    def outer_loops_points
      if @outer_loops_points.nil?
        @outer_loops_points = @faces.flat_map { |face| face.outer_loop.vertices.map { |vertex| vertex.position.transform(@transformation) } }
        @outer_loops_points.reverse! if flipped?
      end
      @outer_loops_points
    end

    def bounds
      @bounds ||= Geom::BoundingBox.new.add(outer_loops_points)
      @bounds
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
