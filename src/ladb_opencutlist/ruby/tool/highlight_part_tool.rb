module Ladb::OpenCutList

  require_relative '../gl/gl_button'

  class HighlightPartTool

    COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze
    COLOR_FACE_HOVER = Sketchup::Color.new(247, 127, 0, 255).freeze
    COLOR_FACE_HOVER_SMILAR = Sketchup::Color.new(247, 127, 0, 128).freeze
    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
    COLOR_DRAWING = Sketchup::Color.new(255, 255, 255, 255).freeze
    COLOR_DRAWING_AUTO_ORIENTED = Sketchup::Color.new(123, 213, 239, 255).freeze

    #f77f00

    PATH_OFFSETS_FRONT_ARROW = [
        [ false ,     0 , 1/3.0 , 0 ],
        [ true  , 1/2.0 , 1/3.0 , 0 ],
        [ true  , 1/2.0 ,     0 , 0 ],
        [ true  ,     1 , 1/2.0 , 0 ],
        [ true  , 1/2.0 ,     1 , 0 ],
        [ true  , 1/2.0 , 2/3.0 , 0 ],
        [ true  ,     0 , 2/3.0 , 0 ],
    ]
    PATH_OFFSETS_BACK_CROSS = [
        [ false , 0 , 0 , 1 ],
        [ true  , 1 , 1 , 1 ],
        [ false , 1 , 0 , 1 ],
        [ true  , 0 , 1 , 1 ],
    ]

    FONT_TEXT = 'Verdana'

    def initialize(line_1_text, line_2_text, line_3_text, displayed_parts)
      @line_1_text = line_1_text
      @line_2_text = line_2_text
      @line_3_text = line_3_text
      @displayed_parts = displayed_parts

      # Define text options
      @part_text_options = {
          color: COLOR_TEXT,
          font: FONT_TEXT,
          size: Plugin.instance.current_os == :MAC ? 20 : 15,
          align: TextAlignCenter
      }
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


      @initial_model_transparency = false
      @buttons = []
      @hover_part = nil
      @hover_entity = nil

      model = Sketchup.active_model
      if model

        view = model.active_view

        @draw_defs = []

        # Compute draw defs
        @displayed_parts.each { |displayed_part|

          group = displayed_part[:group]
          part = displayed_part[:part]

          draw_def = {
              :part => part,
              :face_triangles => [],
              :face_color => COLOR_FACE,
              :line_color => part[:auto_oriented] ? COLOR_DRAWING_AUTO_ORIENTED : COLOR_DRAWING,
              :arrow_points => [],
              :cross_points => [],
          }
          @draw_defs << draw_def

          instance_infos = displayed_part[:instance_infos]
          instance_infos.each { |instance_info|

            # Compute instance faces triangles
            draw_def[:face_triangles].concat(_compute_children_faces_tirangles(view, instance_info.entity.definition.entities, instance_info.transformation))

            if group[:material_type] != MaterialAttributes::TYPE_UNKNOW

              order = [ 1, 2, 3 ]
              if part[:auto_oriented]
                instance_info.size.dimensions_to_normals.each_with_index do |(dimension, normal), index|
                  normal == 'x' ? order[0] = index + 1 : normal == 'y' ? order[1] = index + 1 : order[2] = index + 1
                end
              end

              # Compute front faces arrows
              draw_def[:arrow_points] << _path(instance_info.definition_bounds, PATH_OFFSETS_FRONT_ARROW, true, instance_info.transformation, order)

              # Compute back faces cross
              draw_def[:cross_points] << _path(instance_info.definition_bounds, PATH_OFFSETS_BACK_CROSS, false, instance_info.transformation, order)

            end

          }

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

        # Retrive pick helper
        @pick_helper = Sketchup.active_model.active_view.pick_helper

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

      @draw_defs.each do |draw_def|

        # Draw faces
        face_color = draw_def[:face_color]
        if @hover_part
          if @hover_part == draw_def[:part]
            face_color = COLOR_FACE_HOVER
          elsif @hover_part[:definition_id] == draw_def[:part][:definition_id]
            face_color = COLOR_FACE_HOVER_SMILAR
          end
        end
        view.drawing_color = face_color
        view.draw(GL_TRIANGLES, draw_def[:face_triangles])

        view.line_width = 3
        view.drawing_color = draw_def[:line_color]

        view.line_stipple = ''
        draw_def[:arrow_points].each { |points|
          view.draw(GL_LINES, points)
        }

        view.line_stipple = '_'
        draw_def[:cross_points].each { |points|
          view.draw(GL_LINES, points)
        }

      end

      if Sketchup.version_number >= 16000000
        unless @hover_part.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, 10, 0), "[#{@hover_part[:number]}] #{@hover_part[:definition_id]}" , @part_text_options)
        end
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
      if @hover_part

        Plugin.instance.execute_command('cutlist_part_toggle_front', {
            'definition_id' => @hover_part[:definition_id],
            'serialized_path' => @hover_part[:entity_serialized_paths].first    # TODO
        })

        return
      end
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

      # Try to pick a part
      @pick_helper.do_pick(x, y)
      @pick_helper.count.times { |pick_path_index|

        path = @pick_helper.path_at(pick_path_index)
        if path
          path.reverse.each { |entity|
            if entity.is_a? Sketchup::ComponentInstance
              @displayed_parts.each do |displayed_part|
                part = displayed_part[:part]
                part[:entity_ids].each { |entity_id|
                  if entity.entityID == entity_id
                    @hover_part = part
                    @hover_entity = entity
                    view.invalidate
                    return
                  end
                }
              end
            end
          }
        end

      }
      if @hover_part
        @hover_part = nil
        @hover_entity = nil
        view.invalidate
      end

    end

    private

    # -- GL utils --

    def _offset_toward_camera(view, *args)
      if args.size > 1
        return offset_toward_camera(args)
      end
      points = args.first
      offset_direction = view.camera.direction.reverse!
      points.map { |point|
        point = point.position if point.respond_to?(:position)
        # Model.pixels_to_model converts argument to integers.
        size = view.pixels_to_model(2, point) * 0.01
        point.offset(offset_direction, size)
      }
    end

    def _transform_points(points, transformation)
      return false if transformation.nil?
      points.each { |point| point.transform!(transformation) }
      true
    end

    def _compute_children_faces_tirangles(view, entities, transformation = nil)
      triangles = []
      entities.each { |entity|
        if entity.is_a? Sketchup::Face and entity.visible?
          triangles.concat(_compute_face_triangles(view, entity, transformation))
        elsif entity.is_a? Sketchup::Group and entity.visible?
          triangles.concat(_compute_children_faces_tirangles(view, entity.entities, transformation ? transformation * entity.transformation : entity.transformation))
        elsif entity.is_a? Sketchup::ComponentInstance and entity.visible? and entity.definition.behavior.cuts_opening?
          triangles.concat(_compute_children_faces_tirangles(view, entity.definition.entities, transformation ? transformation * entity.transformation : entity.transformation))
        end
      }
      triangles
    end

    def _compute_face_triangles(view, face, transformation = nil)

      # Thank you @thomthom for this piece of code ;)

      if face.deleted?
        return false
      end

      mesh = face.mesh(0) # POLYGON_MESH_POINTS
      points = mesh.points

      _offset_toward_camera(view, points)
      _transform_points(points, transformation)

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

    def _path(bounds, offsets, loop, transformation, order = [ 1 , 2 , 3 ])
      origin = bounds.min
      points = []
      offsets.each do |offset|
        if offset[0] && (points.length % 2 == 0)
          points << points.last.clone
        end
        points << origin + Geom::Vector3d.new(bounds.width * offset[order[0]], bounds.height * offset[order[1]], bounds.depth * offset[order[2]])
      end
      if loop
        if points.length > 1
          points << points.last.clone
        end
        points << points.first.clone
      end
      _transform_points(points, transformation)
      points
    end

  end

end