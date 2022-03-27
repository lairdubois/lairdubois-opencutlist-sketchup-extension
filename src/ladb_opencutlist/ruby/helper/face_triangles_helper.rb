module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'

  require_relative '../utils/point3d_utils'
  require_relative '../utils/transformation_utils'

  module FaceTrianglesHelper

    include LayerVisibilityHelper

    def _compute_children_faces_triangles(view, entities, transformation = nil)
      triangles = []
      entities.each { |entity|
        next if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            triangles.concat(_compute_face_triangles(view, entity, transformation))
          elsif entity.is_a?(Sketchup::Group)
            triangles.concat(_compute_children_faces_triangles(view, entity.entities, TransformationUtils::multiply(transformation, entity.transformation)))
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.definition.behavior.cuts_opening?
            triangles.concat(_compute_children_faces_triangles(view, entity.definition.entities, TransformationUtils::multiply(transformation, entity.transformation)))
          end
        end
      }
      triangles
    end

    #
    # Returns face triangles as array of points offseted toward camera
    #
    def _compute_face_triangles(view, face, transformation = nil)

      # Thank you @thomthom for this piece of code ;)

      if face.deleted?
        return false
      end

      mesh = face.mesh(0) # POLYGON_MESH_POINTS
      points = mesh.points

      Point3dUtils::offset_toward_camera(view, points)
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