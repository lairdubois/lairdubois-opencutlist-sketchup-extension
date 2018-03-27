require_relative 'tool'
require_relative '../gl/gl_button'
require_relative '../gl/gl_button'

module Ladb
  module Toolbox
    class HighlightPartTool < Tool

      COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze
      COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
      COLOR_BORDER = Sketchup::Color.new(0, 0, 0, 255).freeze
      COLOR_FILL = Sketchup::Color.new(255, 255, 255, 128).freeze

      def initialize(plugin, text_line_1, text_line_2, instance_defs)
        super(plugin)
        @text_line_1 = text_line_1
        @text_line_2 = text_line_2
        @instance_defs = instance_defs

        model = Sketchup.active_model

        @initial_model_transparency = model ? model.rendering_options["ModelTransparency"] : false

        # Setup
        @face_triangles_cache = []
        @buttons = []
        if model

          view = model.active_view

          instance_defs.each { |instance_def|
            _compute_children_faces_tirangles(view, instance_def.entity.definition.entities, instance_def.transformation)
          }

          # Define buttons
          @buttons.push(GLButton.new(view, @plugin.get_i18n_string('tool.highlight.transparency'), 130, 50, 120, 40) do |flags, x, y, view|
            view.model.rendering_options["ModelTransparency"] = !view.model.rendering_options["ModelTransparency"]
          end)
          @buttons.push(GLButton.new(view, @plugin.get_i18n_string('tool.highlight.zoom_extents'), 260, 50, 120, 40) do |flags, x, y, view|
            view.zoom_extents
          end)

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
        view.model.rendering_options["ModelTransparency"] = @initial_model_transparency
        view.invalidate
      end

      def resume(view)
        view.invalidate
      end

      def draw(view)
        view.drawing_color = COLOR_FACE
        view.draw(GL_TRIANGLES, @face_triangles_cache)
        view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 53, 0), @text_line_1, color: COLOR_TEXT, size: 20, align: TextAlignCenter)
        view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 28, 0), @text_line_2, color: COLOR_TEXT, size: 15, align: TextAlignCenter)
        @buttons.each { |button|
          button.draw(view)
        }
      end

      def onLButtonDown(flags, x, y, view)
        @buttons.each { |button|
          if button.onLButtonDown(flags, x, y, view)
            return
          end
        }
      end

      def onLButtonUp(flags, x, y, view)
        @buttons.each { |button|
          if button.onLButtonUp(flags, x, y, view)
            return
          end
        }
        view.model.rendering_options["ModelTransparency"] = @initial_model_transparency
        view.model.select_tool(nil)  # Desactivate the tool on click
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        @buttons.each { |button|
          if button.onMouseMove(flags, x, y, view)
            return
          end
        }
      end

      private

      def _draw_button(view, x, y, width, height, text = nil, border_color = nil, fill_color = nil)
        points = [
            Geom::Point3d.new(x         , y         , 0),
            Geom::Point3d.new(x + width , y         , 0),
            Geom::Point3d.new(x + width , y + height, 0),
            Geom::Point3d.new(x         , y + height, 0)
        ]
        unless fill_color.nil?
          view.drawing_color = fill_color
          view.draw2d(GL_QUADS, points)
        end
        unless border_color.nil?
          view.drawing_color = border_color
          view.draw2d(GL_LINE_LOOP, points)
        end
        unless text.nil?
          view.draw_text(Geom::Point3d.new(x + width / 2, y + (height - 20) / 2, 0), text, color: COLOR_TEXT, size: 15, align: TextAlignCenter)
        end
      end

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