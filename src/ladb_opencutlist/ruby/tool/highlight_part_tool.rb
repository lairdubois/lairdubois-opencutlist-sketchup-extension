module Ladb::OpenCutList

  require_relative '../gl/gl_button'

  class HighlightPartTool

    COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze
    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze

    FONT_TEXT = 'Verdana'

    def initialize(line_1_text, line_2_text, line_3_text, instance_infos)
      @line_1_text = line_1_text
      @line_2_text = line_2_text
      @line_3_text = line_3_text
      @instance_infos = instance_infos

      # Define text options
      @line_1_text_options = {
          color: COLOR_TEXT,
          font: FONT_TEXT,
          size: Plugin.instance.current_os == :MAC ? 20 : 15,
          align: TextAlignCenter
      }
      @line_2_text_options = {
          color: COLOR_TEXT,
          font: FONT_TEXT,
          size: Plugin.instance.current_os == :MAC ? 12 : 8,
          align: TextAlignCenter
      }
      @line_3_text_options = {
          color: COLOR_TEXT,
          font: FONT_TEXT,
          size: Plugin.instance.current_os == :MAC ? 15 : 10,
          align: TextAlignCenter
      }
      button_text_options = {
          color: COLOR_TEXT,
          font: FONT_TEXT,
          size: Plugin.instance.current_os == :MAC ? 15 : 12,
          align: TextAlignCenter
      }

      model = Sketchup.active_model

      @initial_model_transparency = false
      @face_triangles_cache = []
      @buttons = []
      if model

        view = model.active_view

        # Compute instance faces triangles
        instance_infos.each { |instance_info|
          _compute_children_faces_tirangles(view, instance_info.entity.definition.entities, instance_info.transformation)
        }

        # Define buttons
        @buttons.push(GLButton.new(view, Plugin.instance.get_i18n_string('tool.highlight.transparency'), 130, 50, 120, 40, button_text_options) do |flags, x, y, view|
          view.model.rendering_options["ModelTransparency"] = !view.model.rendering_options["ModelTransparency"]
        end)
        @buttons.push(GLButton.new(view, Plugin.instance.get_i18n_string('tool.highlight.zoom_extents'), 260, 50, 120, 40, button_text_options) do |flags, x, y, view|
          view.zoom_extents
        end)

      end

    end

    # -- Tool stuff --

    def activate
      model = Sketchup.active_model
      if model

        # Save the initial model transparency state
        @initial_model_transparency = model.rendering_options["ModelTransparency"]

        # Invalidate view
        model.active_view.invalidate

      end
    end

    def desactivate(view)
      view.model.rendering_options["ModelTransparency"] = @initial_model_transparency
      view.invalidate
    end

    def suspend(view)
      view.invalidate
    end

    def resume(view)
      view.invalidate
    end

    def draw(view)
      view.drawing_color = COLOR_FACE
      view.draw(GL_TRIANGLES, @face_triangles_cache)
      if Sketchup.version_number >= 16000000
        unless @line_1_text.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 30 - (@line_2_text.empty? ? 0 : 20) - (@line_3_text.empty? ? 0 : 30), 0), @line_1_text, @line_1_text_options)
        end
        unless @line_2_text.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 20 - (@line_3_text.empty? ? 0 : 30), 0), @line_2_text, @line_2_text_options)
        end
        unless @line_3_text.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 30, 0), @line_3_text, @line_3_text_options)
        end
        @buttons.each { |button|
          button.draw(view)
        }
      end
    end

    # -- Events --

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

    def _compute_children_faces_tirangles(view, entities, transformation = nil)
      entities.each { |entity|
        if entity.is_a? Sketchup::Face and entity.visible?
          _compute_face_triangles(view, entity, transformation)
        elsif entity.is_a? Sketchup::Group and entity.visible?
          _compute_children_faces_tirangles(view, entity.entities, transformation ? transformation * entity.transformation : entity.transformation)
        elsif entity.is_a? Sketchup::ComponentInstance and entity.visible? and entity.definition.behavior.cuts_opening?
          _compute_children_faces_tirangles(view, entity.definition.entities, transformation ? transformation * entity.transformation : entity.transformation)
        end
      }
    end

    def _compute_face_triangles(view, face, transformation = nil)

      # Thank you @thomthom for this piece of code ;)

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