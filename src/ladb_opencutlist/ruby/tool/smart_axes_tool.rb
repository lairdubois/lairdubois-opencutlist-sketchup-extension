module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/geom/size3d'
  require_relative '../worker/cutlist/cutlist_generate_worker'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'

  class SmartAxesTool < Kuix::KuixTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include CutlistObserverHelper

    STATUS_TYPE_DEFAULT = 0
    STATUS_TYPE_ERROR = 1
    STATUS_TYPE_WARNING = 2
    STATUS_TYPE_SUCCESS = 3

    ACTION_NONE = -1
    ACTION_SWAP_LENGTH_WIDTH = 0
    ACTION_SWAP_FRONT_BACK = 1
    ACTION_SWAP_AUTO = 2

    ACTION_MODIFIER_CLOCKWISE = 0
    ACTION_MODIFIER_ANTICLOCKWIZE = 1

    ACTIONS = [
      { :action => ACTION_SWAP_LENGTH_WIDTH, :modifiers => [ ACTION_MODIFIER_CLOCKWISE, ACTION_MODIFIER_ANTICLOCKWIZE ] },
      { :action => ACTION_SWAP_FRONT_BACK },
      { :action => ACTION_SWAP_AUTO }
    ]

    COLOR_STATUS_TEXT_ERROR = Sketchup::Color.new('#d9534f').freeze
    COLOR_STATUS_TEXT_WARNING = Sketchup::Color.new('#997404').freeze
    COLOR_STATUS_TEXT_SUCCESS = Sketchup::Color.new('#5cb85c').freeze
    COLOR_STATUS_BACKGROUND = Sketchup::Color.new(255, 255, 255, 200).freeze
    COLOR_STATUS_BACKGROUND_ERROR = COLOR_STATUS_TEXT_ERROR.blend(Sketchup::Color.new('white'), 0.2).freeze
    COLOR_STATUS_BACKGROUND_WARNING = Sketchup::Color.new('#ffe69c').freeze
    COLOR_STATUS_BACKGROUND_SUCCESS = COLOR_STATUS_TEXT_SUCCESS.blend(Sketchup::Color.new('white'), 0.2).freeze

    COLOR_MESH = Sketchup::Color.new(0, 62, 255, 100).freeze
    COLOR_ARROW = Sketchup::Color.new(255, 255, 255).freeze
    COLOR_ARROW_AUTO_ORIENTED = Sketchup::Color.new(123, 213, 239, 255).freeze
    COLOR_BOX = Sketchup::Color.new(0, 0, 255).freeze

    @@action = nil
    @@action_modifier = nil

    def initialize
      super(true, true)

      model = Sketchup.active_model
      if model

        # Create cursors
        @cursor_swap_length_width_clockwise = create_cursor('swap-length-width-clockwise', 4, 4)
        @cursor_swap_length_width_anticlockwise = create_cursor('swap-length-width-anticlockwise', 4, 4)
        @cursor_swap_front_back = create_cursor('swap-front-back', 4, 4)
        @cursor_swap_auto = create_cursor('swap-auto', 4, 4)
        @cursor_select_error = create_cursor('select-error', 4, 4)

      end

      # Setup action stack
      @action_stack = []

    end

    # -- UI stuff --

    def setup_entities(view)

      @canvas.layout = Kuix::BorderLayout.new

      unit = [ [ view.vpheight / 150, 8 ].min, 3 * UI.scale_factor ].max

      panel_north = Kuix::Panel.new
      panel_north.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      panel_north.layout = Kuix::InlineLayout.new(true, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER_RIGHT))
      panel_north.padding.set_all!(unit)
      @canvas.append(panel_north)

      panel_south = Kuix::Panel.new
      panel_south.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      panel_south.layout = Kuix::BorderLayout.new
      @canvas.append(panel_south)

      # Help Button

      help_btn = Kuix::Button.new
      help_btn.layout = Kuix::GridLayout.new
      help_btn.border.set_all!(unit / 2)
      help_btn.padding.set!(unit, unit * 4, unit, unit * 4)
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200, 255), :active)
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200, 255).blend(Sketchup::Color.new('white'), 0.2), :hover)
      help_btn.set_style_attribute(:border_color, Sketchup::Color.new(200, 200, 200, 255), :hover)
      help_btn.append_static_label(Plugin.instance.get_i18n_string("default.help"), unit * 3)
      help_btn.on(:click) { |button|
        Plugin.instance.open_docs_page('smart-axes-tool')
      }
      panel_north.append(help_btn)

      # Status panel

      @status = Kuix::Panel.new
      @status.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      @status.layout = Kuix::InlineLayout.new(false, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @status.padding.set_all!(unit * 2)
      @status.visible = false
      panel_south.append(@status)

      @status_lbl = Kuix::Label.new
      @status_lbl.text_size = unit * 3
      @status.append(@status_lbl)

      # Part panel

      @part_panel = Kuix::Panel.new
      @part_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      @part_panel.layout = Kuix::InlineLayout.new(false, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @part_panel.padding.set_all!(unit * 2)
      @part_panel.visible = false
      @part_panel.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 128))
      panel_south.append(@part_panel)

      @part_panel_lbl_1 = Kuix::Label.new
      @part_panel_lbl_1.text_size = unit * 4
      @part_panel.append(@part_panel_lbl_1)

      @part_panel_lbl_2 = Kuix::Label.new
      @part_panel_lbl_2.text_size = unit * 3
      @part_panel.append(@part_panel_lbl_2)

      # Actions panel

      actions = Kuix::Panel.new
      actions.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      actions.layout = Kuix::BorderLayout.new
      actions.padding.set_all!(unit * 2)
      actions.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      panel_south.append(actions)

      actions_lbl = Kuix::Label.new
      actions_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
      actions_lbl.padding.set!(0, unit * 4, 0, unit * 4)
      actions_lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action').upcase
      actions_lbl.text_size = unit * 3
      actions_lbl.text_bold = true
      actions.append(actions_lbl)

      actions_btns_panel = Kuix::Panel.new
      actions_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      actions_btns_panel.layout = Kuix::InlineLayout.new(true, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      actions.append(actions_btns_panel)

      @action_buttons = []
      ACTIONS.each { |action_def|

        action = action_def[:action]
        modifiers = action_def[:modifiers]
        default_modifier = modifiers.is_a?(Array) ? modifiers.first : nil

        data = {
          :action => action,
          :modifier_buttons => [],
          :last_modifier => default_modifier
        }

        actions_btn = Kuix::Button.new
        actions_btn.layout = Kuix::BorderLayout.new
        actions_btn.min_size.set_all!(unit * 10)
        actions_btn.border.set_all!(unit / 2)
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(240, 240, 240))
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(220, 220, 220).blend(Sketchup::Color.new('white'), 0.2), :hover)
        actions_btn.set_style_attribute(:border_color, Sketchup::Color.new(220, 220, 220), :hover)
        actions_btn.set_style_attribute(:border_color, Sketchup::Color.new(0, 0, 255), :selected)
        actions_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_axes.action_#{action}"), unit * 3).padding.set!(0, unit * 4, 0, unit * 4)
        actions_btn.data = data
        actions_btn.on(:click) { |button|
          set_root_action(action, data[:last_modifier])
        }
        actions_btns_panel.append(actions_btn)

        if modifiers.is_a?(Array)

          actions_modifiers = Kuix::Panel.new
          actions_modifiers.layout = Kuix::GridLayout.new(modifiers.length, 0)
          actions_modifiers.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
          actions_modifiers.padding.set_all!(unit)
          actions_btn.append(actions_modifiers)

          modifiers.each { |modifier|

            actions_modifier_btn = Kuix::Button.new
            actions_modifier_btn.layout = Kuix::BorderLayout.new
            actions_modifier_btn.padding.set!(0, unit * 2, 0, unit * 2)
            actions_modifier_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'))
            actions_modifier_btn.set_style_attribute(:background_color, Sketchup::Color.new(200, 200, 200).blend(Sketchup::Color.new('white'), 0.2), :hover)
            actions_modifier_btn.set_style_attribute(:background_color, Sketchup::Color.new(0, 0, 255).blend(Sketchup::Color.new('white'), 0.2), :selected)
            actions_modifier_btn.data = { :modifier => modifier }
            actions_modifier_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_axes.action_modifier_#{modifier}"), unit * 3)
            actions_modifier_btn.on(:click) { |button|
              data[:last_modifier] = modifier
              set_root_action(action, modifier)
            }
            actions_modifiers.append(actions_modifier_btn)

            data[:modifier_buttons].push(actions_modifier_btn)

          }

        end

        @action_buttons.push(actions_btn)

      }

    end

    # -- Setters --

    def set_status(text, type = STATUS_TYPE_DEFAULT)
      return unless @status && text.is_a?(String)
      @status_lbl.text = text
      @status_lbl.visible = !text.empty?
      @status.visible = @status_lbl.visible?
      case type
      when STATUS_TYPE_ERROR
        @status_lbl.set_style_attribute(:color, COLOR_STATUS_TEXT_ERROR)
        @status.set_style_attribute(:background_color, COLOR_STATUS_BACKGROUND_ERROR)
      when STATUS_TYPE_WARNING
        @status_lbl.set_style_attribute(:color, COLOR_STATUS_TEXT_WARNING)
        @status.set_style_attribute(:background_color, COLOR_STATUS_BACKGROUND_WARNING)
      when STATUS_TYPE_SUCCESS
        @status_lbl.set_style_attribute(:color, COLOR_STATUS_TEXT_SUCCESS)
        @status.set_style_attribute(:background_color, COLOR_STATUS_BACKGROUND_SUCCESS)
      else
        @status_lbl.set_style_attribute(:color, nil)
        @status.set_style_attribute(:background_color, COLOR_STATUS_BACKGROUND)
      end
    end

    def set_part(text_1, text_2 = '')
      return unless @part_panel && text_1.is_a?(String) && text_2.is_a?(String)
      @part_panel_lbl_1.text = text_1
      @part_panel_lbl_1.visible = !text_1.empty?
      @part_panel_lbl_2.text = text_2
      @part_panel_lbl_2.visible = !text_2.empty?
      @part_panel.visible = @part_panel_lbl_1.visible? || @part_panel_lbl_2.visible?
    end

    def set_action(action, modifier = nil)

      @@action = action
      @@action_modifier = modifier

      # Update buttons
      if @action_buttons
        @action_buttons.each do |button|
          button.selected = button.data[:action] == action
          button.data[:modifier_buttons].each do |modifier_button|
            modifier_button.selected = button.data[:action] == action && modifier_button.data[:modifier] == modifier
          end
        end
      end

      # Update status text and root cursor
      case action
      when ACTION_SWAP_LENGTH_WIDTH
        Sketchup.set_status_text(
          Plugin.instance.get_i18n_string('tool.smart_axes.status_swap_length_width') +
            ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_1') +
            ' | ' + Plugin.instance.get_i18n_string("default.constrain_key") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.status_toggle_clockwise'),
          SB_PROMPT)
        set_root_cursor(is_action_modifier_anticlockwise? ? @cursor_swap_length_width_anticlockwise : @cursor_swap_length_width_clockwise)
      when ACTION_SWAP_FRONT_BACK
        Sketchup.set_status_text(
          Plugin.instance.get_i18n_string('tool.smart_axes.status_swap_front_back') +
            ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_0'),
          SB_PROMPT)
        set_root_cursor(@cursor_swap_front_back)
      when ACTION_SWAP_AUTO
        Sketchup.set_status_text(
          Plugin.instance.get_i18n_string('tool.smart_axes.status_swap_auto') +
            ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_0') +
            ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_1'),
          SB_PROMPT)
        set_root_cursor(@cursor_swap_auto)
      else
        Sketchup.set_status_text('', SB_PROMPT)
        set_root_cursor(@cursor_select_error)
      end

    end

    def set_root_action(action, modifier = nil)
      @action_stack.clear
      push_action(action, modifier)
    end

    def push_action(action, modifier = nil)
      @action_stack.push({
                           :action => action,
                           :modifier_stack => modifier ? [ modifier] : []
                         })
      set_action(@action_stack.last[:action], @action_stack.last[:modifier_stack].last)
    end

    def pop_action
      @action_stack.pop if @action_stack.length > 1
      set_action(@action_stack.last[:action], @action_stack.last[:modifier_stack].last)
    end

    def push_action_modifier(modifier)
      @action_stack.last[:modifier_stack].push(modifier)
      set_action(@action_stack.last[:action], @action_stack.last[:modifier_stack].last)
    end

    def pop_action_modifier
      @action_stack.last[:modifier_stack].pop if @action_stack.last[:modifier_stack].length > 1
      set_action(@action_stack.last[:action], @action_stack.last[:modifier_stack].last)
    end

    def is_action_none?
      @@action == ACTION_NONE
    end

    def is_action_swap_length_width?
      @@action == ACTION_SWAP_LENGTH_WIDTH
    end

    def is_action_swap_front_back?
      @@action == ACTION_SWAP_FRONT_BACK
    end

    def is_action_swap_auto?
      @@action == ACTION_SWAP_AUTO
    end

    def is_action_modifier_clockwise?
      @@action_modifier == ACTION_MODIFIER_CLOCKWISE
    end

    def is_action_modifier_anticlockwise?
      @@action_modifier == ACTION_MODIFIER_ANTICLOCKWIZE
    end

    # -- Events --

    def onActivate(view)
      super

      # Retrive pick helper
      @pick_helper = view.pick_helper

      start_action = @@action.nil? ? ACTIONS.first[:action] : @@action
      start_action_modifier = start_action == ACTIONS.first[:action] && @@action_modifier.nil? ? ACTIONS.first[:modifiers].is_a?(Array) ? ACTIONS.first[:modifiers].first : nil : @@action_modifier
      set_root_action(start_action, start_action_modifier)

    end

    def onResume(view)
      set_root_action(@@action, @@action_modifier)  # Force SU status text
    end

    def onKeyDown(key, repeat, flags, view)
      return if super
      if key == CONSTRAIN_MODIFIER_KEY && is_action_swap_length_width?
        push_action_modifier(is_action_modifier_clockwise? ? ACTION_MODIFIER_ANTICLOCKWIZE : ACTION_MODIFIER_CLOCKWISE)
      elsif key == COPY_MODIFIER_KEY && !is_action_swap_length_width?
        push_action(ACTION_SWAP_LENGTH_WIDTH, ACTION_MODIFIER_CLOCKWISE)
      elsif key == ALT_MODIFIER_KEY && !is_action_swap_front_back?
        push_action(ACTION_SWAP_FRONT_BACK)
      end
    end

    def onKeyUp(key, repeat, flags, view)
      return if super
      if key == CONSTRAIN_MODIFIER_KEY && is_action_swap_length_width?
        pop_action_modifier
      elsif key == COPY_MODIFIER_KEY && is_action_swap_length_width?
        pop_action
      elsif key == ALT_MODIFIER_KEY && is_action_swap_front_back?
        pop_action
      end
    end

    def onLButtonDown(flags, x, y, view)
      return if super
      @is_down = true
      _handle_mouse_event(x, y, view, :l_button_down)
    end

    def onLButtonUp(flags, x, y, view)
      return if super
      @is_down = false
      _handle_mouse_event(x, y, view, :l_button_up)
    end

    def onLButtonDoubleClick(flags, x, y, view)
      return if super
      _handle_mouse_event(x, y, view, :l_button_dblclick)
    end

    def onMouseMove(flags, x, y, view)
      return if super
      _handle_mouse_event(x, y, view, :move)
    end

    def onMouseLeave(view)
      return if super
    end

    private

    def _reset(view)
      set_status('')
      set_part('')
      if @picked_path
        @is_down = false
        @picked_path = nil
        @space.remove_all
        view.invalidate
      end
    end

    def _handle_mouse_event(x, y, view, event = nil)
      if @pick_helper.do_pick(x, y) > 0
        @pick_helper.count.times { |pick_path_index|

          picked_path = @pick_helper.path_at(pick_path_index)
          if picked_path == @picked_path && event == :move
            return  # Previously detected path, stop process to optimize.
          end
          if picked_path && picked_path.last.is_a?(Sketchup::Face)

            @picked_path = picked_path.clone

            picked_entity_path = _get_part_entity_path_from_path(picked_path)
            picked_entity = picked_path.last
            if picked_entity

              entity = picked_entity
              path = picked_entity_path.slice(0..-2)

              part = _blop(entity, path)
              if part && event ==:move

                if is_action_swap_auto? && !part.auto_oriented && part.def.size.length > part.def.size.width && part.def.size.width > part.def.size.thickness
                  set_status("✔ #{Plugin.instance.get_i18n_string('tool.smart_axes.success.part_oriented')}", STATUS_TYPE_SUCCESS)
                  return
                end

                definition = view.model.definitions[part.def.definition_id]
                if definition && definition.count_used_instances > 1
                  set_status("⚠️ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count => definition.count_used_instances - 1 })}", STATUS_TYPE_WARNING)
                else
                  set_status('')
                end

              end
              if part && (event == :l_button_up || event == :l_button_dblclick)

                definition = view.model.definitions[part.def.definition_id]

                unless definition.nil?

                  ti = nil
                  if is_action_swap_length_width?
                    if is_action_modifier_anticlockwise?
                      ti = Geom::Transformation.axes(
                        ORIGIN,
                        part.def.size.normals[1],
                        AxisUtils.flipped?(part.def.size.normals[1], part.def.size.normals[0], part.def.size.normals[2]) ? part.def.size.normals[0].reverse : part.def.size.normals[0],
                        part.def.size.normals[2]
                      )
                    else
                      ti = Geom::Transformation.axes(
                        ORIGIN,
                        AxisUtils.flipped?(part.def.size.normals[1], part.def.size.normals[0], part.def.size.normals[2]) ? part.def.size.normals[1].reverse : part.def.size.normals[1],
                        part.def.size.normals[0],
                        part.def.size.normals[2]
                      )
                    end
                  elsif is_action_swap_front_back?
                    ti = Geom::Transformation.axes(
                      ORIGIN,
                      part.def.size.normals[0],
                      AxisUtils.flipped?(part.def.size.normals[0], part.def.size.normals[1], part.def.size.normals[2].reverse) ? part.def.size.normals[1].reverse : part.def.size.normals[1],
                      part.def.size.normals[2].reverse
                    )
                  elsif is_action_swap_auto?

                    instance_info = part.def.instance_infos.values.first
                    oriented_size = Size3d.create_from_bounds(instance_info.definition_bounds, part.def.scale, true)

                    ti = Geom::Transformation.axes(
                      ORIGIN,
                      AxisUtils.flipped?(oriented_size.normals[0], oriented_size.normals[1], oriented_size.normals[2]) ? oriented_size.normals[0].reverse : oriented_size.normals[0],
                      oriented_size.normals[1],
                      oriented_size.normals[2]
                    )

                  end
                  unless ti.nil?

                    t = ti.inverse

                    # Start undoable model modification operation
                    view.model.start_operation('OpenCutList - Part Swap', true, false, false)

                    # Transform definition's entities
                    entities = definition.entities
                    entities.transform_entities(t, entities.to_a)

                    # Inverse transform definition's instances
                    definition.instances.each { |instance|
                      instance.transformation *= ti
                    }

                    definition_attributes = DefinitionAttributes.new(definition)
                    definition_attributes.orientation_locked_on_axis = true
                    definition_attributes.write_to_attributes

                    # Commit model modification operation
                    view.model.commit_operation

                    _blop(entity, path)

                  end

                end

              end

              return

            elsif picked_entity_path
              _reset(view)
              set_status("⚠️ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", STATUS_TYPE_ERROR)
              return
            end

          end

        }
      end
      _reset(view)
      UI.beep if event == :l_button_up
    end

    def _get_part_entity_path_from_path(path)
      part_path = path.to_a
      path.reverse_each { |entity|
        return part_path if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        part_path.pop
      }
    end

    def _blop(entity, path)

      worker = CutlistGenerateWorker.new({}, entity, path)
      cutlist = worker.run

      part = nil
      cutlist.groups.each { |group|
        group.parts.each { |p|
          if p.def.definition_id == entity.definition.name
            part = p
            break
          end
        }
        break unless part.nil?
      }

      if part

        # Display part infos
        infos = [ "#{part.length} x #{part.width} x #{part.thickness}" ]
        infos << part.material_name unless part.material_name.empty?
        infos << ">|<" if part.flipped
        set_part(
          "#{part.name}",
          "#{infos.join(' | ')}"
        )

        instance_info = part.def.instance_infos.values.first

        # Create drawing helpers

        @space.remove_all

        arrow_color = part.auto_oriented ? COLOR_ARROW_AUTO_ORIENTED : COLOR_ARROW
        arrow_line_width = 2
        arrow_offset = Sketchup.active_model.active_view.pixels_to_model(1, ORIGIN)

        part_helper = Kuix::Group.new
        part_helper.transformation = instance_info.transformation
        @space.append(part_helper)

          # Mesh
          mesh = Kuix::Mesh.new
          mesh.add_trangles(_compute_children_faces_triangles(instance_info.entity.definition.entities))
          mesh.background_color = COLOR_MESH
          part_helper.append(mesh)

          # Back arrow
          arrow = Kuix::Arrow.new
          arrow.pattern_transformation = instance_info.size.oriented_transformation if part.auto_oriented
          arrow.bounds.origin.copy!(instance_info.definition_bounds.min.offset(Geom::Vector3d.new(0, 0, -arrow_offset)))
          arrow.bounds.size.copy!(instance_info.definition_bounds)
          arrow.color = arrow_color
          arrow.line_width = arrow_line_width
          arrow.line_stipple = '-'
          part_helper.append(arrow)

          # Front arrow
          arrow = Kuix::Arrow.new
          arrow.pattern_transformation = instance_info.size.oriented_transformation if part.auto_oriented
          arrow.pattern_transformation *= Geom::Transformation.translation(Z_AXIS)
          arrow.bounds.origin.copy!(instance_info.definition_bounds.min.offset(Geom::Vector3d.new(0, 0, arrow_offset)))
          arrow.bounds.size.copy!(instance_info.definition_bounds)
          arrow.color = arrow_color
          arrow.line_width = arrow_line_width
          part_helper.append(arrow)

          # Bounding box helper
          box_helper = Kuix::BoxHelper.new
          box_helper.bounds.origin.copy!(instance_info.definition_bounds.min)
          box_helper.bounds.size.copy!(instance_info.definition_bounds)
          box_helper.color = COLOR_BOX
          box_helper.line_width = 2
          box_helper.line_stipple = '-'
          part_helper.append(box_helper)

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          part_helper.append(axes_helper)

      end

      part
    end

  end

end
