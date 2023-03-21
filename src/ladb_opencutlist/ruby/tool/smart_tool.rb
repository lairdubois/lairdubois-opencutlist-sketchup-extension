module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../worker/cutlist/cutlist_generate_worker'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../model/geom/size3d'

  class SmartAxesTool < Kuix::KuixTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include CutlistObserverHelper

    STATUS_TYPE_DEFAULT = 0
    STATUS_TYPE_ERROR = 1
    STATUS_TYPE_WARNING = 2
    STATUS_TYPE_SUCCESS = 3

    ACTION_NONE = -1

    COLOR_STATUS_TEXT_ERROR = Sketchup::Color.new('#d9534f').freeze
    COLOR_STATUS_TEXT_WARNING = Sketchup::Color.new('#997404').freeze
    COLOR_STATUS_TEXT_SUCCESS = Sketchup::Color.new('#5cb85c').freeze
    COLOR_STATUS_BACKGROUND = Sketchup::Color.new(255, 255, 255, 200).freeze
    COLOR_STATUS_BACKGROUND_ERROR = COLOR_STATUS_TEXT_ERROR.blend(Sketchup::Color.new('white'), 0.2).freeze
    COLOR_STATUS_BACKGROUND_WARNING = Sketchup::Color.new('#ffe69c').freeze
    COLOR_STATUS_BACKGROUND_SUCCESS = COLOR_STATUS_TEXT_SUCCESS.blend(Sketchup::Color.new('white'), 0.2).freeze

    @@action = nil
    @@action_modifier = nil

    def initialize
      super(true, true)

      # Setup action stack
      @action_stack = []

    end

    # -- UI stuff --

    def setup_entities(view)

      @canvas.layout = Kuix::BorderLayout.new

      unit = view.vpheight < 800 ? 4 : 8

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
        UI.openURL('https://docs.opencutlist.org')  # TODO
      }
      panel_north.append(help_btn)

      # Status panel

      @status = Kuix::Panel.new
      @status.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      @status.layout = Kuix::InlineLayout.new(false, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @status.padding.set_all!(unit * 3)
      @status.visible = false
      panel_south.append(@status)

      @status_lbl = Kuix::Label.new
      @status_lbl.text_size = unit * 3
      @status.append(@status_lbl)

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
      get_action_defs.each { |action_def|

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

    # -- Status --

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

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      []
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
      # TODO

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

    private

    def _reset(view)
      set_status('')
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

              # TODO

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

  end

end
