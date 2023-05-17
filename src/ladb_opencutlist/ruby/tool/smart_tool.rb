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

    MESSAGE_TYPE_DEFAULT = 0
    MESSAGE_TYPE_ERROR = 1
    MESSAGE_TYPE_WARNING = 2
    MESSAGE_TYPE_SUCCESS = 3

    ACTION_NONE = -1

    COLOR_BRAND = Sketchup::Color.new(247, 127, 0).freeze
    COLOR_BRAND_DARK = Sketchup::Color.new(62, 59, 51)
    COLOR_BRAND_LIGHT = Sketchup::Color.new(214, 212, 205)

    COLOR_MESSAGE_TEXT_ERROR = Sketchup::Color.new('#d9534f').freeze
    COLOR_MESSAGE_TEXT_WARNING = Sketchup::Color.new('#997404').freeze
    COLOR_MESSAGE_TEXT_SUCCESS = Sketchup::Color.new('#569553').freeze
    COLOR_MESSAGE_BACKGROUND = Sketchup::Color.new(255, 255, 255, 200).freeze
    COLOR_MESSAGE_BACKGROUND_ERROR = COLOR_MESSAGE_TEXT_ERROR.blend(COLOR_WHITE, 0.2).freeze
    COLOR_MESSAGE_BACKGROUND_WARNING = Sketchup::Color.new('#ffe69c').freeze
    COLOR_MESSAGE_BACKGROUND_SUCCESS = COLOR_MESSAGE_TEXT_SUCCESS.blend(COLOR_WHITE, 0.2).freeze

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

    def get_text_unit_factor
      case Plugin.instance.language
      when 'ar'
        return 1.5
      else
        return 1.0
      end
    end

    def setup_entities(view)

      # @canvas.layout = Kuix::BorderLayout.new
      @canvas.layout = Kuix::StaticLayout.new

      unit = get_unit(view)

      # -- TOP

      @top_panel = Kuix::Panel.new
      @top_panel.layout_data = Kuix::StaticLayoutData.new(0, 0, 1.0, -1)
      @top_panel.layout = Kuix::BorderLayout.new
      @canvas.append(@top_panel)

        # Actions panel

        actions = Kuix::Panel.new
        actions.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        actions.layout = Kuix::BorderLayout.new
        actions.set_style_attribute(:background_color, COLOR_BRAND_DARK)
        @top_panel.append(actions)

          actions_lbl = Kuix::Label.new
          actions_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
          actions_lbl.padding.set!(0, unit * 4, 0, unit * 4)
          actions_lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
          actions_lbl.text = Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.title").upcase
          actions_lbl.text_size = unit * 3 * get_text_unit_factor
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
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_DARK.blend(COLOR_WHITE, 0.8))
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND, :selected)
            lbl = actions_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}"), unit * 3 * get_text_unit_factor)
            lbl.padding.set!(0, unit * (modifiers.is_a?(Array) ? 1 : 4), 0, unit * 4)
            lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            lbl.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            lbl.set_style_attribute(:color, COLOR_WHITE, :selected)
            actions_btn.data = data
            actions_btn.on(:click) { |button|
              set_root_action(action)
            }
            actions_btn.on(:enter) { |button|
              notify_message(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_status"))
            }
            actions_btn.on(:leave) { |button|
              hide_message
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
                actions_modifier_btn.layout = Kuix::StaticLayout.new
                actions_modifier_btn.border.set_all!(unit / 2)
                actions_modifier_btn.padding.set_all!(unit * 2)
                actions_modifier_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT)
                actions_modifier_btn.set_style_attribute(:background_color, COLOR_WHITE, :hover)
                actions_modifier_btn.set_style_attribute(:background_color, COLOR_WHITE, :selected)
                actions_modifier_btn.data = { :modifier => modifier }
                actions_modifier_btn.on(:click) { |button|
                  set_root_action(action, modifier)
                }
                actions_modifiers.append(actions_modifier_btn)

                child = get_action_modifier_btn_child(action, modifier)
                if child
                  child.layout_data = Kuix::StaticLayoutData.new(0.5, 0.5, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
                  child.text_size = @unit * 3 if child.respond_to?(:text_size=)
                  child.min_size.width = @unit * 3 unless child.is_a?(Kuix::Label)
                  child.min_size.height = @unit * 3
                  child.set_style_attribute(:color, COLOR_BRAND_DARK)
                  actions_modifier_btn.append(child)
                end

                data[:modifier_buttons].push(actions_modifier_btn)

              }

            end

            @action_buttons.push(actions_btn)

          }

          # Help Button

          help_btn = Kuix::Button.new
          help_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
          help_btn.layout = Kuix::GridLayout.new
          help_btn.set_style_attribute(:background_color, COLOR_WHITE)
          help_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
          lbl = help_btn.append_static_label(Plugin.instance.get_i18n_string("default.help").upcase, unit * 3 * get_text_unit_factor)
          lbl.min_size.set!(unit * 15, 0)
          lbl.padding.set!(0, unit * 4, 0, unit * 4)
          lbl.set_style_attribute(:color, COLOR_BRAND_DARK)
          help_btn.on(:click) { |button|
            Plugin.instance.open_docs_page("tool.smart-#{get_stripped_name}")
          }
          actions.append(help_btn)

        # Infos panel

        @infos_panel = Kuix::Panel.new
        @infos_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        @infos_panel.layout = Kuix::InlineLayout.new(true, @unit * 3, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        @infos_panel.min_size.set_all!(@unit * 4)
        @infos_panel.padding.set_all!(@unit * 2)
        @infos_panel.hittable = false
        @infos_panel.visible = false
        @infos_panel.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 85))
        @top_panel.append(@infos_panel)

          @infos_lbl_1 = Kuix::Label.new
          @infos_lbl_1.text_size = @unit * 3 * get_text_unit_factor
          @infos_lbl_1.text_bold = true
          @infos_panel.append(@infos_lbl_1)

        # Message panel

        @message_panel = Kuix::Panel.new
        @message_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
        @message_panel.layout = Kuix::InlineLayout.new(false, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        @message_panel.padding.set_all!(unit * 2)
        @message_panel.hittable = false
        @message_panel.visible = false
        @top_panel.append(@message_panel)

          @message_lbl = Kuix::Label.new
          @message_lbl.border.set_all!(unit / 4)
          @message_lbl.padding.set!(unit * 1.5, unit * 2, unit, unit * 2)
          @message_lbl.text_size = unit * 3 * get_text_unit_factor
          @message_panel.append(@message_lbl)

      # -- MINITOOL

      @minitool_panel = Kuix::Panel.new
      @minitool_panel.layout_data = Kuix::StaticLayoutData.new(1.0, 0.5, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER_RIGHT))
      @minitool_panel.layout = Kuix::GridLayout.new(1, 2, 0, unit)
      @minitool_panel.margin.right = unit * 2
      @canvas.append(@minitool_panel)

        setup_minitools_btns(view)

    end

    def setup_minitools_btns(view)

      # Transparency
      @transparency_minitool_btn = append_minitool_btn('M0,0.2L0.6,0L1,0.2L0.4,0.4L0,0.2 M0.5,0.6333L0.6,0.6 M0.6,0.6L0.7,0.65 M0.6,0.1L0.6,0.2 M0.6,0.3L0.6,0.4 M0.6,0.5L0.6,0.6 M0.8,0.7L0.9,0.75 M0.4,0.6667L0.3,0.7 M0.2,0.7333L0.1,0.7667 M0.4,0.4L0.4,1 M0,0.2L0,0.8L0.4,1L1,0.8L1,0.2') do |button|
        view.model.rendering_options["ModelTransparency"] = !view.model.rendering_options["ModelTransparency"]
      end
      @transparency_minitool_btn.selected = view.model.rendering_options['ModelTransparency']

      # Zoom extends
      append_minitool_btn('M0,0.3L0,0L0.3,0 M0.7,0L1,0L1,0.3 M1,0.7L1,1L0.7,1 M0.3,1L0,1L0,0.7 M0.2,0.3L0.5,0.2L0.8,0.3L0.5,0.4L0.2,0.3 M0.2,0.3L0.2,0.7L0.5,0.8L0.8,0.7L0.8,0.3 M0.5,0.4L0.5,0.8') do |button|
        view.zoom_extents
      end

    end

    def append_minitool_btn(icon, &block)

      minitool_btn = Kuix::Button.new
      minitool_btn.layout = Kuix::GridLayout.new
      minitool_btn.border.set_all!(@unit * 0.5)
      minitool_btn.padding.set_all!(@unit * 2)
      minitool_btn.min_size.set!(@unit * 5, @unit * 5)
      minitool_btn.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 0.5))
      minitool_btn.set_style_attribute(:background_color, COLOR_WHITE, :hover)
      minitool_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :active)
      minitool_btn.set_style_attribute(:border_color, Sketchup::Color.new(255, 255, 255, 0.5))
      minitool_btn.set_style_attribute(:border_color, COLOR_WHITE, :hover)
      minitool_btn.set_style_attribute(:border_color, COLOR_BRAND_LIGHT, :active)
      minitool_btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
      minitool_btn.on([ :click, :doubleclick ], &block)
      @minitool_panel.append(minitool_btn)

        motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(icon))
        motif.line_width = @unit <= 4 ? 0.5 : 1
        motif.set_style_attribute(:color, COLOR_BRAND_DARK)
        minitool_btn.append(motif)

      minitool_btn
    end

    # -- Show --

    def notify_message(text, type = MESSAGE_TYPE_DEFAULT)
      return unless @message_panel && text.is_a?(String)
      @message_lbl.text = text
      @message_panel.visible = !text.empty?
      case type
      when MESSAGE_TYPE_ERROR
        @message_lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_ERROR)
        @message_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_ERROR)
        @message_lbl.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_ERROR)
      when MESSAGE_TYPE_WARNING
        @message_lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_WARNING)
        @message_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_WARNING)
        @message_lbl.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_WARNING)
      when MESSAGE_TYPE_SUCCESS
        @message_lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_SUCCESS)
        @message_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_SUCCESS)
        @message_lbl.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_SUCCESS)
      else
        @message_lbl.set_style_attribute(:color, nil)
        @message_lbl.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND)
        @message_lbl.set_style_attribute(:border_color, Sketchup::Color.new)
      end
    end

    def hide_message
      @message_panel.visible = false
    end

    def notify_infos(text_1, infos = [])
      return unless @infos_panel && text_1.is_a?(String) && infos.is_a?(Array)
      @infos_panel.remove_all
      unless text_1.empty?
        @infos_lbl_1.text = text_1
        @infos_panel.append(@infos_lbl_1)
      end
      infos.each do |info|
        if info.is_a?(String)
          entity = Kuix::Label.new
          entity.text_size = @unit * 3 * get_text_unit_factor
          entity.text = info
        elsif info.is_a?(Kuix::Entity2d)
          entity = info
          entity.min_size.set_all!(@unit * get_text_unit_factor * 4)
          entity.line_width = @unit <= 4 ? 0.5 : 1
          entity.set_style_attribute(:color, COLOR_BLACK)
        else
          next
        end
        entity.border.set!(0, 0, 0, @unit / 4)
        entity.padding.set!(0, 0, 0, @unit * 3)
        entity.set_style_attribute(:border_color, COLOR_DARK_GREY)
        @infos_panel.append(entity)
      end
      @infos_panel.visible = !text_1.empty? || !infos.empty?
    end

    def hide_infos
      @infos_panel.visible = false
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

    def get_action_modifier_btn_child(action, modifier)
      nil
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
      pop_to_root_cursor

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
            modifier = action_def[:startup_modifier]
            if modifier.nil?
              modifiers = action_def[:modifiers]
              modifier = modifiers.first if modifiers.is_a?(Array)
            end
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

    # -- Menu --

    def getMenu(menu, flags, x, y, view)
      onMouseMove(flags, x, y, view)  # Simulate mouse move
      populate_menu(menu)
    end

    def populate_menu(menu)
      menu.add_item(Plugin.instance.get_i18n_string('default.close')) {
        quit
      }
    end

    # -- Events --

    def onActivate(view)
      super

      # Create pick helpers
      @pick_helper = view.pick_helper
      @input_point = Sketchup::InputPoint.new

      # Set startup cursor
      set_root_action(get_startup_action)

      # Observe rendering options events
      view.model.rendering_options.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing rendering options events
      view.model.rendering_options.remove_observer(self)

    end

    def onResume(view)
      super
      set_root_action(fetch_action, fetch_action_modifier(fetch_action))  # Force SU status text
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if key == 9 || key == 25  # TAB key doesn't generate "onKeyDown" event and SHIFT + TAB = 25 on Mac

        action_defs = get_action_defs
        action = fetch_action
        action_index = action_defs.index { |action_def| action_def[:action] == action }
        unless action_index.nil?

          if is_key_down?(COPY_MODIFIER_KEY)

            # Select next modifier if exists

            modifier = fetch_action_modifier(action)
            unless modifier.nil? || action_defs[action_index][:modifiers].nil?

              modifier_index = action_defs[action_index][:modifiers].index(modifier)
              unless modifier_index.nil?

                next_modifier_index = (modifier_index + (is_key_down?(CONSTRAIN_MODIFIER_KEY) ? -1 : 1)) % action_defs[action_index][:modifiers].length
                next_modifier = action_defs[action_index][:modifiers][next_modifier_index]
                set_root_action(action, next_modifier)

                return true
              end

            end

          else

            # Select next action

            next_action_index = (action_index + (is_key_down?(CONSTRAIN_MODIFIER_KEY) ? -1 : 1)) % action_defs.length
            next_action = action_defs[next_action_index][:action]
            set_root_action(next_action, fetch_action_modifier(next_action))

            return true
          end

        end

      elsif key == VK_UP || key == VK_DOWN
        if @active_part_entity_path
          _pick_deeper(key == VK_UP ? 1 : -1)
        end
        return true
      end
      return false
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      unless is_action_none?

        @input_point.pick(view, x, y)

        # SKETCHUP_CONSOLE.clear
        # puts "# INPUT"
        # puts "  Face = #{@input_point.face}"
        # puts "  Edge = #{@input_point.edge} -> onface? = #{@input_point.edge ? @input_point.edge.used_by?(@input_point.face) : ''}"
        # puts "  Vertex = #{@input_point.vertex} -> onface? = #{@input_point.vertex ? @input_point.vertex.used_by?(@input_point.face) : ''}"
        # puts "  InstancePath = #{@input_point.instance_path.to_a.join(' -> ')}"
        # puts "  Transformation = #{@input_point.transformation}"

        unless @input_point.face.nil?

          input_face_path = nil
          input_face = @input_point.face
          input_edge = @input_point.vertex ? @input_edge : @input_point.edge  # Try to keep previous edge when vertex is picked
          input_vertex = @input_point.vertex

          # @input_face_path = nil
          # @input_face = @input_point.face
          # @input_edge = @input_point.edge unless @input_point.vertex  # Try to keep previous edge when vertex is picked
          # @input_vertex = @input_point.vertex

          if @input_point.instance_path.leaf == input_face
            input_face_path = @input_point.instance_path.to_a
          elsif @input_point.instance_path.leaf.respond_to?(:used_by?) && @input_point.instance_path.leaf.used_by?(input_face)
            input_face_path = @input_point.instance_path.to_a[0...-1] + [ input_face ]
          else

            if @pick_helper.do_pick(x, y)

              # Input point gives a face without instance path
              # Let's try to use pick helper to pick the face path
              @pick_helper.count.times do |index|
                if @pick_helper.leaf_at(index) == input_face
                  input_face_path = @pick_helper.path_at(index)
                  break
                end
              end

              unless input_edge.nil?

                # Input point give an edge but on an other face
                # Let's try to use pick helper to pick an edge used by the input face
                @pick_helper.count.times do |index|
                  if @pick_helper.leaf_at(index).is_a?(Sketchup::Edge) && @pick_helper.leaf_at(index).visible? && @pick_helper.leaf_at(index).used_by?(input_face)
                    input_edge = @pick_helper.leaf_at(index)
                    break
                  end
                end

              end

            end

          end

          # Exit if picked elements are the same
          return true if input_face_path == @input_face_path && input_face == @input_face && input_edge == @input_edge && input_vertex == @input_vertex

          @input_face_path = input_face_path
          @input_face = input_face
          @input_edge = input_edge
          @input_vertex = input_vertex

        else
          @input_face_path = nil
          @input_face = nil
          @input_edge = nil
          @input_vertex = nil
        end

        # puts "# OUTPUT"
        # puts "  Face = #{@input_face}"
        # puts "  Edge = #{@input_edge} -> onface? = #{@input_edge ? @input_edge.used_by?(@input_face) : ''}"
        # puts "  Vertex = #{@input_vertex} -> onface? = #{@input_vertex ? @input_vertex.used_by?(@input_face) : ''}"
        # puts "  FacePath = #{@input_face_path ? @input_face_path.join(' -> ') : ''}"

      end
      false
    end

    def onMouseWheel(flags, delta, x, y, view)
      return true if super
      if flags & COPY_MODIFIER_MASK == COPY_MODIFIER_MASK
        if @active_part_entity_path
          _pick_deeper(delta)
        end
        return true
      end
    end

    def onRenderingOptionsChanged(rendering_options, type)
      if type == Sketchup::RenderingOptions::ROPSetModelTransparency && @transparency_minitool_btn
        @transparency_minitool_btn.selected = rendering_options['ModelTransparency']
      end
    end

    # -----

    protected

    def _refresh_active_part(highlighted = false)
      _set_active_part(@active_part_entity_path, _generate_part_from_path(@active_part_entity_path), highlighted)
    end

    def _reset_active_part
      _set_active_part(nil, nil)
    end

    def _set_active_part(part_entity_path, part, highlighted = false)

      @active_part_entity_path = part_entity_path
      @active_part = part

      _reset_ui

    end

    def _can_pick_deeper?
      !@pick_helper.nil? && !@active_part_entity_path.nil?
    end

    def _pick_deeper(delta = 1)
      if _can_pick_deeper?

        picked_paths = []
        picked_part_entity_paths = []
        @pick_helper.count.times do |index|
          path = @pick_helper.path_at(index)
          part_entity_path = _get_part_entity_path_from_path(path.clone)
          unless part_entity_path.nil? || picked_part_entity_paths.include?(part_entity_path)
            picked_paths << path
            picked_part_entity_paths << part_entity_path
          end
        end

        # Try to retrieve current index
        active_index = picked_part_entity_paths.map { |path| path.last }.index(@active_part_entity_path.last)
        if active_index

          # Compute the new index
          new_index = (active_index + delta) % picked_part_entity_paths.length

          # Compute the new part
          picked_part_entity_path = picked_part_entity_paths[new_index]
          part = _generate_part_from_path(picked_part_entity_path)
          if part
            _set_active_part(picked_part_entity_path, part)
          end

        end

      end
    end

    def _reset_ui

      # Clear Kuix space
      clear_space

      # Reset cursor
      pop_to_root_cursor

      # Hide previous overlays
      hide_message
      hide_infos

    end

    def _instances_to_paths(instances, instance_paths, entities, path = [])
      entities.each do |entity|
        next if entity.is_a?(Sketchup::Edge) || entity.is_a?(Sketchup::Face)   # Minor Speed improvement
        if entity.visible? && _layer_visible?(entity.layer, path.empty?)
          if entity.is_a?(Sketchup::ComponentInstance)
            if instances.include?(entity)
              instance_paths << path + [ entity ]
            else
              _instances_to_paths(instances, instance_paths, entity.definition.entities, path + [ entity ])
            end
          elsif entity.is_a?(Sketchup::Group)
            _instances_to_paths(instances, instance_paths, entity.entities, path + [ entity ])
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

    def _generate_part_from_path(path)
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
