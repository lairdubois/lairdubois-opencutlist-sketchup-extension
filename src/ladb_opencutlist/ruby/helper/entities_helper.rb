module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'

  module EntitiesHelper

    include LayerVisibilityHelper

    def _find_largest_face(entity, transformation = IDENTITY)
      return [ nil, [] ] unless entity.visible? && _layer_visible?(entity.layer)

      face = nil
      inner_path = []
      if entity.is_a?(Sketchup::Face)
        face = entity
        inner_path = [ face ]
      elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentDefinition)
        transformation = transformation * entity.transformation if entity.is_a?(Sketchup::Group)
        face_area = 0
        entity.entities.each do |e|
          next if e.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges

          f, p = _find_largest_face(e, transformation)
          unless f.nil?
            f_area = f.area(transformation)
            if face_area == 0 || f_area.round(4) >= face_area.round(4)
              face = f
              face_area = f_area
              inner_path = [ entity ] + p
            end
          end

        end
      elsif entity.is_a?(Sketchup::ComponentInstance)
        face, p = _find_largest_face(entity.definition, transformation * entity.transformation)
        inner_path = [ entity ] + p
      end

      [ face, inner_path ]
    end

    def _find_longest_outer_edge(face, transformation = IDENTITY)
      return nil unless face.is_a?(Sketchup::Face)

      edge = nil
      edge_length = 0

      face.outer_loop.edges.each do |e|
        next if !e.visible? || e.smooth? || e.soft? # TODO manage if all edges of loop are hidden, smooth or soft

        e_length = e.length(transformation)
        if edge_length == 0 || e_length.round(4) >= edge_length.round(4)
          edge = e
          edge_length = e_length
        end

      end

      edge
    end

  end

end

