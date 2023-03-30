module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../worker/cutlist/cutlist_generate_worker'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../model/geom/size3d'

  class SmartTool < Kuix::KuixTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include CutlistObserverHelper

    VK_TAB = 9
    if Sketchup.platform == :platform_osx
      VK_NUMPAD0 = 48
      VK_NUMPAD1 = 49
      VK_NUMPAD2 = 50
      VK_NUMPAD3 = 51
      VK_NUMPAD4 = 52
      VK_NUMPAD5 = 53
      VK_NUMPAD6 = 54
      VK_NUMPAD7 = 55
      VK_NUMPAD8 = 56
      VK_NUMPAD9 = 57
    else
      VK_NUMPAD0 = 0x60
      VK_NUMPAD1 = 0x61
      VK_NUMPAD2 = 0x62
      VK_NUMPAD3 = 0x63
      VK_NUMPAD4 = 0x64
      VK_NUMPAD5 = 0x65
      VK_NUMPAD6 = 0x66
      VK_NUMPAD7 = 0x67
      VK_NUMPAD8 = 0x68
      VK_NUMPAD9 = 0x69
    end

    MESSAGE_TYPE_DEFAULT = 0
    MESSAGE_TYPE_ERROR = 1
    MESSAGE_TYPE_WARNING = 2
    MESSAGE_TYPE_SUCCESS = 3

    ACTION_NONE = -1

    COLOR_MESSAGE_TEXT_ERROR = Sketchup::Color.new('#d9534f').freeze
    COLOR_MESSAGE_TEXT_WARNING = Sketchup::Color.new('#997404').freeze
    COLOR_MESSAGE_TEXT_SUCCESS = Sketchup::Color.new('#569553').freeze
    COLOR_MESSAGE_BACKGROUND = Sketchup::Color.new(255, 255, 255, 200).freeze
    COLOR_MESSAGE_BACKGROUND_ERROR = COLOR_MESSAGE_TEXT_ERROR.blend(Sketchup::Color.new('white'), 0.2).freeze
    COLOR_MESSAGE_BACKGROUND_WARNING = Sketchup::Color.new('#ffe69c').freeze
    COLOR_MESSAGE_BACKGROUND_SUCCESS = COLOR_MESSAGE_TEXT_SUCCESS.blend(Sketchup::Color.new('white'), 0.2).freeze

    def initialize(quit_on_esc = true, quit_on_undo = false)
      super

      # Setup action stack
      @action_stack = []

      # Create cursors
      @cursor_select_error = create_cursor('select-error', 4, 4)

    end

    def get_stripped_name
      # Implemented in derived class
    end

    # -- UI stuff --

    def get_unit(view = nil)
      return @unit unless @unit.nil?
      return 3 if view && Sketchup.active_model.nil?
      view = Sketchup.active_model.active_view if view.nil?
      if view.vpheight > 2000
        @unit = 8
      elsif view.vpheight > 1000
        @unit = 6
      elsif view.vpheight > 500
        @unit = 4
      else
        @unit = 3
      end
      @unit
    end

    def setup_entities(view)

      @canvas.layout = Kuix::BorderLayout.new

      unit = get_unit(view)

      @top_panel = Kuix::Panel.new
      @top_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      @top_panel.layout = Kuix::BorderLayout.new
      @canvas.append(@top_panel)

      # Status panel

      @message_panel = Kuix::Panel.new
      @message_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      @message_panel.layout = Kuix::InlineLayout.new(false, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @message_panel.padding.set_all!(unit * 2)
      @message_panel.visible = false
      @top_panel.append(@message_panel)

      @message_panel_lbl = Kuix::Label.new
      @message_panel_lbl.border.set_all!(unit / 4)
      @message_panel_lbl.padding.set!(unit * 1.5, unit * 2, unit, unit * 2)
      @message_panel_lbl.text_size = unit * 3
      @message_panel.append(@message_panel_lbl)

      # Actions panel

      actions = Kuix::Panel.new
      actions.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      actions.layout = Kuix::BorderLayout.new
      actions.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
      @top_panel.append(actions)

      actions_lbl = Kuix::Label.new
      actions_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
      actions_lbl.padding.set!(0, unit * 4, 0, unit * 4)
      actions_lbl.set_style_attribute(:color, Sketchup::Color.new(214, 212, 205))
      actions_lbl.text = Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.title").upcase
      actions_lbl.text_size = unit * 3
      actions_lbl.text_bold = true
      actions.append(actions_lbl)

      actions_btns_panel = Kuix::Panel.new
      actions_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      actions_btns_panel.layout = Kuix::InlineLayout.new(true, 0, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      actions.append(actions_btns_panel)

      @action_buttons = []
      get_action_defs.each { |action_def|

        action = action_def[:action]
        modifiers = action_def[:modifiers]

        data = {
          :action => action,
          :modifier_buttons => [],
        }

        actions_btn = Kuix::Button.new
        actions_btn.layout = Kuix::BorderLayout.new
        actions_btn.border.set!(0, unit / 4, 0, unit / 4)
        actions_btn.min_size.set_all!(unit * 9)
        actions_btn.set_style_attribute(:border_color, Sketchup::Color.new(62, 59, 51).blend(Sketchup::Color.new('white'), 0.8))
        actions_btn.set_style_attribute(:border_color, Sketchup::Color.new(214, 212, 205), :hover)
        actions_btn.set_style_attribute(:border_color, Sketchup::Color.new(247, 127, 0), :selected)
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205), :hover)
        actions_btn.set_style_attribute(:background_color, Sketchup::Color.new(247, 127, 0), :selected)
        lbl = actions_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}"), unit * 3)
        lbl.padding.set!(0, unit * (modifiers.is_a?(Array) ? 1 : 4), 0, unit * 4)
        lbl.set_style_attribute(:color, Sketchup::Color.new(214, 212, 205))
        lbl.set_style_attribute(:color, Sketchup::Color.new(62, 59, 51), :hover)
        lbl.set_style_attribute(:color, Sketchup::Color.new(255, 255, 255), :selected)
        actions_btn.data = data
        actions_btn.on(:click) { |button|
          set_root_action(action)
        }
        actions_btn.on(:enter) { |button|
          set_message(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_status"))
        }
        actions_btn.on(:leave) { |button|
          set_message('')
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
            actions_modifier_btn.border.set_all!(unit / 2)
            actions_modifier_btn.padding.set!(0, unit * 2, 0, unit * 2)
            actions_modifier_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205))
            actions_modifier_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'), :hover)
            actions_modifier_btn.set_style_attribute(:background_color, Sketchup::Color.new(247, 127, 0).blend(Sketchup::Color.new('white'), 0.5), :selected)
            actions_modifier_btn.data = { :modifier => modifier }
            lbl = actions_modifier_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_modifier_#{modifier}"), unit * 3)
            lbl.set_style_attribute(:color, Sketchup::Color.new(62, 59, 51), :hover)
            actions_modifier_btn.on(:click) { |button|
              set_root_action(action, modifier)
            }
            actions_modifiers.append(actions_modifier_btn)

            data[:modifier_buttons].push(actions_modifier_btn)

          }

        end

        @action_buttons.push(actions_btn)

      }

      # Help Button

      help_btn = Kuix::Button.new
      help_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
      help_btn.layout = Kuix::GridLayout.new
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255))
      help_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205), :hover)
      lbl = help_btn.append_static_label(Plugin.instance.get_i18n_string("default.help"), unit * 3)
      lbl.min_size.set!(unit * 15, 0)
      lbl.padding.set!(0, unit * 4, 0, unit * 4)
      lbl.set_style_attribute(:color, Sketchup::Color.new(62, 59, 51))
      help_btn.on(:click) { |button|
        Plugin.instance.open_docs_page("tool.smart-#{get_stripped_name}")
      }
      actions.append(help_btn)

    end

    # -- Status --

    def set_message(text, type = MESSAGE_TYPE_DEFAULT)
      return unless @message_panel && text.is_a?(String)
      @message_panel_lbl.text = text
      @message_panel_lbl.visible = !text.empty?
      @message_panel.visible = @message_panel_lbl.visible?
      case type
      when MESSAGE_TYPE_ERROR
        @message_panel_lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_ERROR)
        @message_panel_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_ERROR)
        @message_panel_lbl.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_ERROR)
      when MESSAGE_TYPE_WARNING
        @message_panel_lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_WARNING)
        @message_panel_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_WARNING)
        @message_panel_lbl.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_WARNING)
      when MESSAGE_TYPE_SUCCESS
        @message_panel_lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_SUCCESS)
        @message_panel_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_SUCCESS)
        @message_panel_lbl.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_SUCCESS)
      else
        @message_panel_lbl.set_style_attribute(:color, nil)
        @message_panel_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND)
        @message_panel_lbl.set_style_attribute(:border_color, Sketchup::Color.new)
      end
    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      []
    end

    def get_action_status(action)
      return '' if action.nil?
      Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_status") + '.'
    end

    def get_action_cursor(action, modifier)
      @cursor_select_error
    end

    def store_action(action)
      # Implemented in derived class : @@action = action
    end

    def fetch_action
      # Implemented in derived class : @@action
    end

    def store_action_modifier(action, modifier)
      # Implemented in derived class : @@action_modifiers[action] = modifier
    end

    def fetch_action_modifier(action)
      # Implemented in derived class : @@action_modifiers[action]
    end

    def get_startup_action
      fetch_action.nil? ? get_action_defs.first[:action] : fetch_action
    end

    def set_action(action, modifier = nil)

      # Store settings in class variable
      store_action(action)
      store_action_modifier(action, modifier)

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
      Sketchup.set_status_text(get_action_status(action), SB_PROMPT)
      set_root_cursor(get_action_cursor(action, modifier))

      # Fire event
      onActionChange(action, modifier) if self.respond_to?(:onActionChange)

    end

    def set_root_action(action, modifier = nil)
      @action_stack.clear

      # Select a default action
      if action.nil?
        action = get_action_defs.first[:action]
      end

      # Select a default modifier if exists
      if modifier.nil?
        modifier = fetch_action_modifier(action)
        if modifier.nil?
          action_def = get_action_defs.select { |action_def| action_def[:action] == action }.first
          unless action_def.nil?
            modifiers = action_def[:modifiers]
            modifier = modifiers.first if modifiers.is_a?(Array)
          end
        end
      end

      push_action(action, modifier)
    end

    def push_action(action, modifier = nil)
      @action_stack.push({
                           :action => action,
                           :modifier_stack => modifier ? [ modifier ] : []
                         })
      set_action(action, modifier)
    end

    def pop_action
      @action_stack.pop if @action_stack.length > 1
      set_action(@action_stack.last[:action], @action_stack.last[:modifier_stack].last)
    end

    def push_action_modifier(modifier)
      return if @action_stack.empty?
      @action_stack.last[:modifier_stack].push(modifier)
      set_action(@action_stack.last[:action], modifier)
    end

    def pop_action_modifier
      return if @action_stack.empty?
      @action_stack.last[:modifier_stack].pop
      set_action(@action_stack.last[:action], @action_stack.last[:modifier_stack].last)
    end

    def is_action_none?
      fetch_action == ACTION_NONE
    end

    # -- Events --

    def onActivate(view)
      super

      # Retrive pick helper
      @pick_helper = view.pick_helper

      set_root_action(get_startup_action)

    end

    def onResume(view)
      set_root_action(fetch_action, fetch_action_modifier(fetch_action))  # Force SU status text
    end

    protected

    def _reset(view)
      set_message('')
    end

    def _instances_to_paths(instances, instance_paths, entities, path)
      entities.each do |entity|
        return if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
        if entity.visible? && _layer_visible?(entity.layer, path.empty?)
          if entity.is_a?(Sketchup::ComponentInstance)
            if instances.include?(entity)
              instance_paths << path + [ entity ]
            else
              _instances_to_paths(instances, instance_paths, entity.definition.entities, path + [entity ])
            end
          elsif entity.is_a?(Sketchup::Group)
            _instances_to_paths(instances, instance_paths, entity.entities, path + [entity ])
          end
        end
      end
    end

    def _get_part_entity_path_from_path(path)
      part_path = path
      path.reverse_each { |entity|
        return part_path if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        part_path = part_path.slice(0...-1)
      }
    end

    def _compute_part_from_path(path)
      return nil unless path.is_a?(Array)

      entity = path.last
      return nil unless entity.is_a?(Sketchup::Drawingelement)

      worker = CutlistGenerateWorker.new({}, entity, path.slice(0...-1))
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

      part
    end

  end

end
