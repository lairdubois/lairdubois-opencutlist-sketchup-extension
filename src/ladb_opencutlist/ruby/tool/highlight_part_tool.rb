module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../utils/point3d_utils'
  require_relative '../model/cutlist/cutlist'

  class HighlightPartTool < Kuix::KuixTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include CutlistObserverHelper

    COLOR_FACE = Sketchup::Color.new(255, 0, 0, 128).freeze
    COLOR_FACE_HOVER = Sketchup::Color.new(0, 62, 255, 200).freeze
    COLOR_FACE_HOVER_SMILAR = Sketchup::Color.new(0, 62, 255, 128).freeze
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
      super(true, true)

      @cutlist = cutlist
      @group = group
      @parts = parts
      @instance_count = instance_count
      @maximize_on_quit = maximize_on_quit

      # Add tool as observer of the cutlist
      @cutlist.add_observer(self)

      @initial_model_transparency = false

      @hover_part = nil
      @picked_path = nil

      model = Sketchup.active_model
      if model

        view = model.active_view

        # Compute draw defs
        @draw_defs = []
        @parts.each { |part|

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
            draw_def[:face_triangles].concat(_compute_children_faces_triangles(instance_info.entity.definition.entities, instance_info.transformation))

            # Compute back and front face arrows
            if part.group.material_type != MaterialAttributes::TYPE_HARDWARE

              order = [ 1, 2, 3 ]
              if part.auto_oriented
                instance_info.size.dimensions_to_axes.each_with_index do |(dimension, normal), index|
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

      end

    end

    # -- UI stuff --

    def setup_entities(view)

      @canvas.layout = Kuix::BorderLayout.new

      unit = [ [ view.vpheight / 150, 8 ].min, 4 * UI.scale_factor ].max

      panel = Kuix::Entity2d.new
      panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      panel.layout = Kuix::BorderLayout.new
      panel.padding.set_all!(unit)
      panel.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 200))
      @canvas.append(panel)

        # Labels

        lbls = Kuix::Entity2d.new
        lbls.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        lbls.layout = Kuix::InlineLayout.new(false, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        panel.append(lbls)

          @lbl_1 = Kuix::Label.new
          @lbl_1.text_size = unit * 4
          lbls.append(@lbl_1)

          @lbl_2 = Kuix::Label.new
          @lbl_2.text_size = unit * 2
          lbls.append(@lbl_2)

          @lbl_3 = Kuix::Label.new
          @lbl_3.text_size = unit * 3
          lbls.append(@lbl_3)

        # Buttons

        btn_border = unit / 2
        btn_min_width = unit * 30
        btn_min_height = unit * 10
        btn_bg_color = Sketchup::Color.new('white')
        btn_bg_active_color = Sketchup::Color.new(200, 200, 200, 255)
        btn_border_color = Sketchup::Color.new(220, 220, 220, 255)
        btn_border_hover_color = Sketchup::Color.new(128, 128, 128, 255)
        btn_border_selected_color = Sketchup::Color.new(0, 0, 255, 255)

        btns = Kuix::Entity2d.new
        btns.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
        btns.layout = Kuix::InlineLayout.new(true, unit, Kuix::Anchor.new(Kuix::Anchor::BOTTOM_RIGHT))
        panel.append(btns)

          btn_1 = Kuix::Button.new
          btn_1.layout = Kuix::BorderLayout.new
          btn_1.border.set_all!(btn_border)
          btn_1.min_size.set!(btn_min_width, btn_min_height)
          btn_1.set_style_attribute(:background_color, btn_bg_color)
          btn_1.set_style_attribute(:background_color, btn_bg_active_color, :active)
          btn_1.set_style_attribute(:border_color, btn_border_color)
          btn_1.set_style_attribute(:border_color, btn_border_hover_color, :hover)
          btn_1.set_style_attribute(:border_color, btn_border_selected_color, :selected)
          btn_1.on(:click) do |button|
            view.model.rendering_options["ModelTransparency"] = !view.model.rendering_options["ModelTransparency"]
            button.selected = view.model.rendering_options["ModelTransparency"]
          end
          btn_1.selected = view.model.rendering_options["ModelTransparency"]
          btns.append(btn_1)

            btn_1_lbl = Kuix::Label.new
            btn_1_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
            btn_1_lbl.text = Plugin.instance.get_i18n_string('tool.highlight.transparency')
            btn_1_lbl.text_size = unit * 3
            btn_1.append(btn_1_lbl)

          btn_2 = Kuix::Button.new
          btn_2.layout = Kuix::BorderLayout.new
          btn_2.border.set_all!(btn_border)
          btn_2.min_size.set!(btn_min_width, btn_min_height)
          btn_2.set_style_attribute(:background_color, btn_bg_color)
          btn_2.set_style_attribute(:background_color, btn_bg_active_color, :active)
          btn_2.set_style_attribute(:border_color, btn_border_color)
          btn_2.set_style_attribute(:border_color, btn_border_hover_color, :hover)
          btn_2.on(:click) do |button|
            view.zoom_extents
          end
          btns.append(btn_2)

            btn_2_lbl = Kuix::Label.new
            btn_2_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
            btn_2_lbl.text = Plugin.instance.get_i18n_string('tool.highlight.zoom_extents')
            btn_2_lbl.text_size = unit * 3
            btn_2.append(btn_2_lbl)

    end

    # -- Tool stuff --

    def activate
      super
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
      super
      onQuit(view)
    end

    def draw(view)

      # Draw defs
      @draw_defs.each do |draw_def|

        # Draw arrows
        view.line_width = 3
        view.drawing_color = draw_def[:line_color]
        view.line_stipple = Kuix::LINE_STIPPLE_SOLID
        draw_def[:front_arrow_points].each { |points|
          view.draw(GL_LINES, points)
        }
        view.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        draw_def[:back_arrow_points].each { |points|
          view.draw(GL_LINES, points)
        }

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

      end

      super
    end

    # -- Menu --

    def getMenu(menu, flags, x, y, view)
      _pick_hover_part(x, y, view) unless view.nil?
      build_menu(menu, view)
    end

    def build_menu(menu, view = nil)
      if @hover_part
        hover_part_id = @hover_part.id
        hover_part_material_type = @hover_part.group.material_type
        item = menu.add_item("[#{@hover_part.number}] #{@hover_part.name}") {}
        menu.set_validation_proc(item) { MF_GRAYED }
        menu.add_separator
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_properties')) {
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'general', dontGenerate: true }")
        }
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_axes_properties')) {
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'axes', dontGenerate: true }")
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_size_increase_properties')) {
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'size_increase', dontGenerate: true }")
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
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_edges_properties')) {
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'edges', dontGenerate: true }")
        }
        menu.set_validation_proc(item) {
          if hover_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_faces_properties')) {
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{hover_part_id}', tab: 'faces', dontGenerate: true }")
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

    def onLButtonUp(flags, x, y, view)
      return true if super
      _pick_hover_part(x, y, view)
      if @hover_part
        UI.beep
        return true
      end
      _quit(view)
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      _pick_hover_part(x, y, view)
    end

    def onMouseLeave(view)
      return true if super
      _reset(view)
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

        @lbl_1.visible = true
        @lbl_2.visible = !part.tags.empty?
        @lbl_3.visible = true

        @lbl_1.text = "[#{part.number}] #{part.name}"
        @lbl_2.text = part.tags.join(' | ')
        @lbl_3.text = "#{ part.length_increased ? '*' : '' }#{part.length.to_s} x #{ part.width_increased ? '*' : '' }#{part.width.to_s} x #{ part.thickness_increased ? '*' : '' }#{part.thickness.to_s}" +
            (part.final_area.nil? ? '' : " (#{part.final_area})") +
            " | #{instance_count.to_s} #{Plugin.instance.get_i18n_string(instance_count > 1 ? 'default.instance_plural' : 'default.instance_single')}" +
            " | #{(part.material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : part.material_name)}"

      elsif @group

        @lbl_1.visible = true
        @lbl_2.visible = false
        @lbl_3.visible = true

        @lbl_1.text = (@group.material_name.empty? ? Plugin.instance.get_i18n_string('tab.cutlist.material_undefined') : @group.material_name + (@group.std_dimension.empty? ? '' : ' / ' + @group.std_dimension))
        @lbl_2.text = ''
        @lbl_3.text = @instance_count.to_s + ' ' + Plugin.instance.get_i18n_string(@instance_count > 1 ? 'default.instance_plural' : 'default.instance_single')

      else

        @lbl_1.visible = false
        @lbl_2.visible = false
        @lbl_3.visible = true

        @lbl_1.text = ''
        @lbl_2.text = ''
        @lbl_3.text = @instance_count.to_s + ' ' + Plugin.instance.get_i18n_string(@instance_count > 1 ? 'default.instance_plural' : 'default.instance_single')

      end

    end

    def _reset(view)
      if @hover_part
        @hover_part = nil
        @picked_path = nil
        _update_text_lines
        view.invalidate
      end
    end

    def _quit(view)

      # Maximize dialog if needed
      if @maximize_on_quit
        Plugin.instance.show_tabs_dialog('cutlist', false)
      end

      # Unselect tool
      view.model.select_tool(nil)  # Desactivate the tool on click

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
      Point3dUtils::transform_points(points, transformation)
      points
    end

    def _pick_hover_part(x, y, view)
      if @pick_helper.do_pick(x, y) > 0

        active_path = Sketchup.active_model.active_path.nil? ? [] : Sketchup.active_model.active_path

        @pick_helper.count.times { |pick_path_index|

          pick_path = @pick_helper.path_at(pick_path_index)
          if pick_path == @picked_path
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
                  @picked_path = pick_path
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
