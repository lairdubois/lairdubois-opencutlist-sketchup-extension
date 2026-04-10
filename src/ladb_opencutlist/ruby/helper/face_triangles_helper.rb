module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'
  require_relative 'material_attributes_caching_helper'

  require_relative '../utils/transformation_utils'

  module FaceTrianglesHelper

    include LayerVisibilityHelper
    include MaterialAttributesCachingHelper

    def _compute_children_faces_triangles(entities, transformation = nil, filtered_faces = nil)
      triangles = []
      entities.each { |entity|
        next if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there are a lot of edges
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            triangles.concat(_compute_face_triangles(entity, transformation)) if filtered_faces.nil? || filtered_faces.include?(entity)
          elsif entity.respond_to?(:definition)
            material = entity.material
            material_attributes = _get_material_attributes(material)
            next if material_attributes.type == MaterialAttributes::TYPE_MACHINING || material_attributes.type == MaterialAttributes::TYPE_HARDWARE
            next if !(definition = entity.definition).group? && !definition.behavior.cuts_opening?
            triangles.concat(_compute_children_faces_triangles(definition.entities, TransformationUtils::multiply(transformation, entity.transformation), filtered_faces))
          end
        end
      }
      triangles
    end

    #
    # Returns face triangles as array of points
    #
    def _compute_face_triangles(face, transformation = nil)

      # Thank you, @thomthom for this piece of code ;)

      return [] if face.deleted?

      mesh = face.mesh(0) # POLYGON_MESH_POINTS
      mesh.transform!(transformation) if transformation.is_a?(Geom::Transformation)

      mesh.polygons.flat_map do |polygon|
        polygon.map { |index| mesh.point_at(index.abs) }  # Indicies can be negative to indicate edge smoothing.
      end
    end

  end

end