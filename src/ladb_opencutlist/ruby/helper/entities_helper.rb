module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'

  module EntitiesHelper

    include LayerVisibilityHelper

    def _find_largest_face(entity, transformation = nil)
      return [ nil, [] ] unless entity.visible? && _layer_visible?(entity.layer)

      face = nil
      path = []
      if entity.is_a?(Sketchup::Face)
        face = entity
        path = [ face ]
      elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentDefinition)
        transformation = TransformationUtils::multiply(transformation, entity.transformation) if entity.is_a?(Sketchup::Group)
        face_area = 0
        face_min = nil
        entity.entities.each do |e|
          next if e.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges

          f, p = _find_largest_face(e, transformation)
          unless f.nil?
            f_area = transformation ? f.area(transformation) : f.area
            f_min = f.bounds.min
            if (f_area - face_area).abs < 0.0001 && (face_min.nil? || face_min < f_min) || f_area > face_area
              face = f
              face_area = f_area
              face_min = f_min
              path = [ entity ] + p
            end
          end

        end
      elsif entity.is_a?(Sketchup::ComponentInstance)
        face, p = self._find_largest_face(entity.definition, TransformationUtils::multiply(transformation, entity.transformation))
        path = [ entity ] + p
      end

      [ face, path ]
    end

    def _find_longest_outer_edge(face, transformation = nil)
      return nil unless face.is_a?(Sketchup::Face)

      edge = nil
      edge_length = 0
      edge_min = nil

      face.outer_loop.edges.each do |e|
        next if !e.visible? || e.smooth? || e.soft? # TODO manage if all edges of loop are hidden, smooth or soft

        e_length = transformation ? e.length(transformation) : e.length
        e_min = e.start.position < e.end.position ? e.start.position : e.end.position
        e_point, e_vector = e.line
        if (e_length - edge_length).abs < 0.0001 && (edge_min.nil? || edge_min < e_min || e_vector.parallel?(X_AXIS)) || e_length > edge_length
          edge = e
          edge_length = e_length
          edge_min = e_min
        end

      end

      edge
    end

  end

end

