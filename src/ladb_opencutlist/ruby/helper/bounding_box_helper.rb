module Ladb::OpenCutList

  require_relative 'layer0_caching_helper'
  require_relative 'layer_visibility_helper'
  require_relative 'material_attributes_caching_helper'

  module BoundingBoxHelper

    include Layer0CachingHelper
    include LayerVisibilityHelper
    include MaterialAttributesCachingHelper

    def _compute_faces_bounds(definition_or_group, transformation = IDENTITY)
      bounds = Geom::BoundingBox.new
      definition_or_group.entities.each { |entity|
        next if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there are a lot of edges
        if entity.visible? && _layer_visible?(entity.layer)
          case entity
          when Sketchup::Face
            face_bounds = entity.bounds
            min = face_bounds.min.transform(transformation)
            max = face_bounds.max.transform(transformation)
            face_bounds = Geom::BoundingBox.new
            face_bounds.add(min, max)
            bounds.add(face_bounds)
          when Sketchup::ComponentInstance
            next if entity.material && ((ma = _get_material_attributes(entity.material)).type == MaterialAttributes::TYPE_MACHINING || ma.type == MaterialAttributes::TYPE_HARDWARE) && !entity.name.strip.empty?
            next if !(definition = entity.definition).group? && !definition.behavior.cuts_opening?
            bounds.add(_compute_faces_bounds(entity.definition, transformation * entity.transformation))
          end
        end
      }
      bounds
    end

  end

end