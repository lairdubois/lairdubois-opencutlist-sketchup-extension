module Ladb
  module Toolbox
    class HighlightPartTool

      COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze
      COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze

      def initialize(name, length, width, thickness, instance_defs)
        @name = name
        @dimensions = '(' + length.to_s + ' x ' + width.to_s + ' x ' + thickness.to_s + ')'
        @face_triangles_cache = []
        model = Sketchup.active_model
        if model
          view = model.active_view
          instance_defs.each { |instance_def|
            _compute_children_faces_tirangles(view, instance_def.entity.definition.entities, instance_def.transformation)
          }
        end
      end

      def activate
        model = Sketchup.active_model
        if model
          view = model.active_view
          view.invalidate
        end
      end

      def desactivate(view)
        view.invalidate
      end

      def resume(view)
        view.invalidate
      end

      def draw(view)
        view.drawing_color = COLOR_FACE
        view.draw(GL_TRIANGLES, @face_triangles_cache)
        view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 50, 0), @name, color: COLOR_TEXT, size: 20, align: TextAlignCenter)
        view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 25, 0), @dimensions, color: COLOR_TEXT, size: 15, align: TextAlignCenter)
      end

      def onLButtonUp(flags, x, y, view)
        Sketchup.active_model.select_tool(nil)  # Desactivate the tool on click
        view.invalidate
      end

      private

      def _compute_children_faces_tirangles(view, entities, transformation = nil)
        entities.each { |entity|
          if entity.is_a? Sketchup::Face
            _compute_face_triangles(view, entity, transformation)
          elsif entity.is_a? Sketchup::Group
            _compute_children_faces_tirangles(view, entity.entities, transformation ? transformation * entity.transformation : entity.transformation)
          elsif entity.is_a? Sketchup::ComponentInstance and entity.definition.behavior.cuts_opening?
            _compute_children_faces_tirangles(view, entity.definition, transformation ? transformation * entity.transformation : entity.transformation)
          end
        }
      end

      def _compute_face_triangles(view, face, transformation = nil)

        if face.deleted?
          return false
        end

        mesh = face.mesh(0) # POLYGON_MESH_POINTS

        # offset_toward_camera
        offset_direction = view.camera.direction.reverse!
        points = mesh.points
        points.map { |point|
          point = point.position if point.respond_to?(:position)
          # Model.pixels_to_model converts argument to integers.
          size = view.pixels_to_model(2, point) * 0.01
          point.offset(offset_direction, size)
        }

        unless transformation.nil?
          points.each { |point|
            point.transform!(transformation)
          }
        end

        triangles = []
        mesh.polygons.each { |polygon|
          polygon.each { |index|
            # Indicies start at 1 and can be negative to indicate edge smoothing.
            # Must take this into account when looking up the points in our array.
            triangles << points[index.abs - 1]
          }
        }
        @face_triangles_cache.concat(triangles)

      end

    end
  end
end