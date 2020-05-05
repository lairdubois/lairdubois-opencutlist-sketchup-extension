module Ladb::OpenCutList

  require_relative 'layer0_caching_helper'

  module BoundingBoxHelper

    include Layer0CachingHelper

    def _compute_faces_bounds(definition_or_group, transformation = nil)
      bounds = Geom::BoundingBox.new
      definition_or_group.entities.each { |entity|
        next if entity.is_a? Sketchup::Edge   # Minor Speed imrovement when there's a lot of edges
        if entity.visible? and (entity.layer.visible? or entity.layer.equal?(@layer0))
          if entity.is_a? Sketchup::Face
            face_bounds = entity.bounds
            if transformation
              min = face_bounds.min.transform(transformation)
              max = face_bounds.max.transform(transformation)
              face_bounds = Geom::BoundingBox.new
              face_bounds.add(min, max)
            end
            bounds.add(face_bounds)
          elsif entity.is_a? Sketchup::Group
            bounds.add(_compute_faces_bounds(entity, transformation ? transformation * entity.transformation : entity.transformation))
          elsif entity.is_a? Sketchup::ComponentInstance and entity.definition.behavior.cuts_opening?
            bounds.add(_compute_faces_bounds(entity.definition, transformation ? transformation * entity.transformation : entity.transformation))
          end
        end
      }
      bounds
    end

  end

end