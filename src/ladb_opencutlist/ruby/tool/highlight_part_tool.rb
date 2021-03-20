module Ladb::OpenCutList

  require_relative '../gl/gl_button'
  require_relative '../model/cutlist/cutlist'

  class HighlightPartTool < CutlistObserver

    COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze
    COLOR_FACE_HOVER = Sketchup::Color.new(0, 62, 255, 200).freeze
    COLOR_FACE_HOVER_SMILAR = Sketchup::Color.new(0, 62, 255, 128).freeze
    COLOR_TEXT_BG = Sketchup::Color.new(255, 255, 255, 191).freeze
    COLOR_TEXT = Sketchup::Color.new(0, 0, 0, 255).freeze
    COLOR_DRAWING = Sketchup::Color.new(255, 255, 255, 255).freeze
    COLOR_DRAWING_AUTO_ORIENTED = Sketchup::Color.new(123, 213, 239, 255).freeze

    PATH_OFFSETS_FRONT_ARROW = [
        [ false ,     0 , 1/3.0 , 1 ],
        [ true  , 1/2.0 , 1/3.0 , 1 ],
        [ true  , 1/2.0 ,     0 , 1 ],
        [ true  ,     1 , 1/2.0 , 1 ],
        [ true  , 1/2.0 ,     1 , 1 ],
        [ true  , 1/2.0 , 2/3.0 , 1 ],
        [ true  ,     0 , 2/3.0 , 1 ],
    ]
    PATH_OFFSETS_BACK_ARROW = [
        [ false ,     0 , 1/3.0 , 0 ],
        [ true  , 1/2.0 , 1/3.0 , 0 ],
        [ true  , 1/2.0 ,     0 , 0 ],
        [ true  ,     1 , 1/2.0 , 0 ],
        [ true  , 1/2.0 ,     1 , 0 ],
        [ true  , 1/2.0 , 2/3.0 , 0 ],
        [ true  ,     0 , 2/3.0 , 0 ],
    ]

    FONT_TEXT = 'Verdana'

    def initialize(cutlist, group, parts, instance_count, maximize_on_quit)
      @cutlist = cutlist
      @group = group
      @parts = parts
      @instance_count = instance_count
      @maximize_on_quit = maximize_on_quit

      # Add tool as observer of the cutlist
      @cutlist.add_observer(self)

      @text_line_1 = ''
      @text_line_2 = ''
      @text_line_3 = ''

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

      @initial_model_transparency = false
      @buttons = []
      @hover_part = nil
      @hover_pick_path = nil

      model = Sketchup.active_model
      if model

        view = model.active_view

        @draw_defs = []

        # Compute draw defs
        @parts.each { |part|

          group = part.group

          draw_def = {
              :part => part,
              :face_triangles => [],
              :face_color => COLOR_FACE,
              :line_color => part.auto_oriented ? COLOR_DRAWING_AUTO_ORIENTED : COLOR_DRAWING,
              :front_arrow_points => [],
              :back_arrow_points => [],
          }
          @draw_defs << draw_def

          part.def.instance_infos.each { |serialized_path, instance_info|

            # Compute instance faces triangles
            draw_def[:face_triangles].concat(_compute_children_faces_tirangles(view, instance_info.entity.definition.entities, instance_info.transformation))

            # Compute back and front face arrows
            if group.material_type != MaterialAttributes::TYPE_HARDWARE && group.material_type != MaterialAttributes::TYPE_UNKNOWN

              order = [ 1, 2, 3 ]
              if part.auto_oriented
                instance_info.size.dimensions_to_normals.each_with_index do |(dimension, normal), index|
                  normal == 'x' ? order[0] = index + 1 : normal == 'y' ? order[1] = index + 1 : order[2] = index + 1
                end
              end

              # Compute front faces arrows
              draw_def[:front_arrow_points] << _path(instance_info.definition_bounds, PATH_OFFSETS_FRONT_ARROW, true, instance_info.transformation, order)

              # Compute back faces cross
              draw_def[:back_arrow_points] << _path(instance_info.definition_bounds, PATH_OFFSETS_BACK_ARROW, true, instance_info.transformation, order)

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
      _update_text_lines
    end

    def deactivate(view)
      onQuit(view)
    end

    def suspend(view)
      view.invalidate
    end

    def resume(view)
      view.invalidate
    end

    def draw(view)

      # Draw defs
      @draw_defs.each do |draw_def|

        # Draw faces
        face_color = draw_def[:face_color]
        if @hover_part
          if @hover_part == draw_def[:part]
            face_color = COLOR_FACE_HOVER
          elsif @hover_part.definition_id == draw_def[:part].definition_id
            face_color = COLOR_FACE_HOVER_SMILAR
          end
        end
        view.drawing_color = face_color
        view.draw(GL_TRIANGLES, draw_def[:face_triangles])

        # Draw arrows
        view.line_width = 3
        view.drawing_color = draw_def[:line_color]
        view.line_stipple = ''
        draw_def[:front_arrow_points].each { |points|
          view.draw(GL_LINES, points)
        }
        view.line_stipple = '-'
        draw_def[:back_arrow_points].each { |points|
          view.draw(GL_LINES, points)
        }

      end

      # Draw text lines and buttons (only if Sketchup > 2016)
      if Sketchup.version_number >= 16000000
        bg_height = 30 + (@text_line_2.empty? ? 0 : 20) + (@text_line_3.empty? ? 0 : 30)
        _draw_rect(view, 0, view.vpheight - bg_height, view.vpwidth, bg_height, COLOR_TEXT_BG)
        unless @text_line_1.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 30 - (@text_line_2.empty? ? 0 : 20) - (@text_line_3.empty? ? 0 : 30), 0), @text_line_1, @line_1_text_options)
        end
        unless @text_line_2.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 20 - (@text_line_3.empty? ? 0 : 30), 0), @text_line_2, @line_2_text_options)
        end
        unless @text_line_3.nil?
          view.draw_text(Geom::Point3d.new(view.vpwidth / 2, view.vpheight - 30, 0), @text_line_3, @line_3_text_options)
        end
        @buttons.each { |button|
          button.draw(view)
        }

      end

    end

    # -- Menu --

    if Sketchup.version.to_i < 15
      # Compatible with SketchUp 2014 and older:
      def getMenu(menu)
        build_menu(menu)
      end
    else
      # Only works with SketchUp 2015 and newer:
      def getMenu(menu, flags, x, y, view)
        _pick_hover_part(x, y, view) unless view.nil?
        build_menu(menu, view)
      end
    end

    def build_menu(menu, view = nil)
      if @hover_part
        hover_part_id = @hover_part.id
        hover_part_material_type = @hover_part.group.material_type
        item = menu.add_item("[#{@hover_part.number}] #{@hover_part.name}") {}
        menu.set_validation_proc(item) { MF_GRAYED }
        menu.add_separator
        menu.add_item(Plugin.instance.get_i18n_string('tab.cutlist.edit_part_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'general', dontGenerate: true }")
        }
        menu.add_item(Plugin.instance.get_i18n_string('tab.cutlist.edit_part_axes_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'axes', dontGenerate: true }")
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('tab.cutlist.edit_part_size_increase_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'size_increase', dontGenerate: true }")
        }
        menu.set_validation_proc(item) {
          if hover_part_material_type == MaterialAttributes::TYPE_SOLID_WOOD ||
              hover_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD ||
              hover_part_material_type == MaterialAttributes::TYPE_DIMENSIONAL
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('tab.cutlist.edit_part_edges_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'edges', dontGenerate: true }")
        }
        menu.set_validation_proc(item) {
          if hover_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
      elsif view
        menu.add_item(Plugin.instance.get_i18n_string('default.close')) {
          _quit(view)
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
      _pick_hover_part(x, y, view)
      if @hover_part
        UI.beep
        return
      end
      _quit(view)
    end

    def onMouseMove(flags, x, y, view)
      @buttons.each { |button|
        if button.onMouseMove(flags, x, y, view)
          return
        end
      }

      _pick_hover_part(x, y, view)

    end

    def onMouseLeave(view)
      _reset(view)
    end

    def onCancel(flag, view)
      _quit(view)
    end

    def onQuit(view)

      # Restore initial transparency mode
      view.model.rendering_options["ModelTransparency"] = @initial_model_transparency

      # Invalidate view
      view.invalidate

      # Add tool as observer of the cutlist
      @cutlist.remove_observer(self)

    end

    def onInvalidateCutlist(cutlist)
      model = Sketchup.active_model
      _quit(model.active_view) if model
    end

    private

    def _update_text_lines

      part = @hover_part ? @hover_part : (@parts.length == 1 ? @parts.first : nil)
      if part

        instance_count = part.instance_count_by_part * part.count - part.unused_instance_count

        @text_line_1 = "[#{part.number}] #{part.name}"
        @text_line_2 = part.tags.join(' | ')
        @text_line_3 = "#{ part.length_increased ? '*' : '' }#{part.length.to_s} x #{ part.width_increased ? '*' : '' }#{part.width.to_s} x #{ part.thickness_increased ? '*' : '' }#{part.thickness.to_s}" +
            (part.final_area.nil? ? '' : " (#{part.final_area})") +
            " | #{instance_count.to_s} #{Plugin.instance.get_i18n_string(instance_count > 1 ? 'default.instance_plural' : 'default.instance_single')}" +
            " | #{(part.material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : part.material_name)}"

      elsif @group

        @text_line_1 = (@group.material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : @group.material_name + (@group.std_dimension.empty? ? '' : ' / ' + @group.std_dimension))
        @text_line_2 = ''
        @text_line_3 = @instance_count.to_s + ' ' + Plugin.instance.get_i18n_string(@instance_count > 1 ? 'default.instance_plural' : 'default.instance_single')

      else

        @text_line_1 = ''
        @text_line_2 = ''
        @text_line_3 = @instance_count.to_s + ' ' + Plugin.instance.get_i18n_string(@instance_count > 1 ? 'default.instance_plural' : 'default.instance_single')

      end

    end

    def _reset(view)
      if @hover_part
        @hover_part = nil
        @hover_pick_path = nil
        _update_text_lines
        view.invalidate
      end
    end

    def _quit(view)

      # Maximize dialog if needed
      if @maximize_on_quit
        Plugin.instance.show_dialog('cutlist', false)
      end

      # Unselect tool
      view.model.select_tool(nil)  # Desactivate the tool on click

    end

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

    def _draw_rect(view, x, y, width, height, color)
      @points = [
          Geom::Point3d.new(        x ,          y , 0),
          Geom::Point3d.new(x + width ,          y , 0),
          Geom::Point3d.new(x + width , y + height , 0),
          Geom::Point3d.new(        x , y + height , 0)
      ]
      view.drawing_color = color
      view.draw2d(GL_QUADS, @points)
    end

    def _pick_hover_part(x, y, view)
      if @pick_helper.do_pick(x, y) > 0

        active_path = Sketchup.active_model.active_path.nil? ? [] : Sketchup.active_model.active_path

        @pick_helper.count.times { |pick_path_index|

          pick_path = @pick_helper.path_at(pick_path_index)
          if pick_path == @hover_pick_path
            return  # Previously detected path, stop process to optimize.
          end
          if pick_path

            # Cleanup pick path to keep only ComponentInstances and Groups
            path = active_path
            pick_path.each { |entity|
              if entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
                path.push(entity);
              end
            }

            serialized_path = PathUtils.serialize_path(path)

            @parts.each do |part|
              part.def.entity_serialized_paths.each { |sp|
                if serialized_path.start_with?(sp)
                  @hover_part = part
                  @hover_pick_path = pick_path
                  _update_text_lines
                  view.invalidate
                  return
                end
              }
            end

          end

        }
      end
      _reset(view)
    end

  end

end
