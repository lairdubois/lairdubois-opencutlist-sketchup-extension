module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'

  require_relative '../utils/point3d_utils'
  require_relative '../utils/transformation_utils'

  module FaceTrianglesHelper

    include LayerVisibilityHelper

    def _compute_children_faces_triangles(entities, transformation = nil, filtered_faces = nil)
      triangles = []
      entities.each { |entity|
        next if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            triangles.concat(_compute_face_triangles(entity, transformation)) if filtered_faces.nil? || filtered_faces.include?(entity)
          elsif entity.is_a?(Sketchup::Group)
            triangles.concat(_compute_children_faces_triangles(entity.entities, TransformationUtils::multiply(transformation, entity.transformation), filtered_faces))
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
            triangles.concat(_compute_children_faces_triangles(entity.definition.entities, TransformationUtils::multiply(transformation, entity.transformation), filtered_faces))
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
      points = mesh.points

      Point3dUtils::transform_points(points, transformation)

      triangles = []
      mesh.polygons.each { |polygon|
        polygon.each { |index|
          # Indicies start at 1 and can be negative to indicate edge smoothing.
          # Must take this into account when looking up the points in our array.
          triangles << points[index.abs - 1]
        }
      }

      triangles
    end

  end

end