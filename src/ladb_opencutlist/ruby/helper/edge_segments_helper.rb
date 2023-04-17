module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'

  require_relative '../utils/point3d_utils'
  require_relative '../utils/transformation_utils'

  module EdgeSegmentsHelper

    include LayerVisibilityHelper

    def _compute_children_edge_segments(entities, transformation = nil, filtered_edges = nil)
      segments = []
      entities.each { |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Edge)
            segments.concat(_compute_edge_segment(entity, transformation)) if filtered_edges.nil? || filtered_edges.include?(entity)
          elsif entity.is_a?(Sketchup::Group)
            segments.concat(_compute_children_edge_segments(entity.entities, TransformationUtils::multiply(transformation, entity.transformation), filtered_edges))
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
            segments.concat(_compute_children_edge_segments(entity.definition.entities, TransformationUtils::multiply(transformation, entity.transformation), filtered_edges))
          end
        end
      }
      segments
    end

    #
    # Returns edge line as array of points
    #
    def _compute_edge_segment(edge, transformation = nil)

      if edge.deleted?
        return []
      end

      points = [
        edge.start.position.to_a,
        edge.end.position.to_a
      ]

      Point3dUtils::transform_points(points, transformation)

      points
    end

  end

end