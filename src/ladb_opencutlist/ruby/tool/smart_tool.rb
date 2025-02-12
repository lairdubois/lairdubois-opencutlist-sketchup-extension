module Ladb::OpenCutList

  require 'timeout'
  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../helper/sanitizer_helper'
  require_relative '../worker/cutlist/cutlist_generate_worker'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../model/geom/size3d'

  class SmartTool < Kuix::KuixTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include SanitizerHelper
    include CutlistObserverHelper

    MESSAGE_TYPE_DEFAULT = 0
    MESSAGE_TYPE_ERROR = 1
    MESSAGE_TYPE_WARNING = 2
    MESSAGE_TYPE_SUCCESS = 3

    ACTION_NONE = -1

    COLOR_BRAND = Sketchup::Color.new(247, 127, 0).freeze
    COLOR_BRAND_DARK = Sketchup::Color.new(62, 59, 51).freeze
    COLOR_BRAND_LIGHT = Sketchup::Color.new(214, 212, 205).freeze

    COLOR_MESSAGE_TEXT_ERROR = Sketchup::Color.new('#d9534f').freeze
    COLOR_MESSAGE_TEXT_WARNING = Sketchup::Color.new('#997404').freeze
    COLOR_MESSAGE_TEXT_SUCCESS = Sketchup::Color.new('#569553').freeze
    COLOR_MESSAGE_BACKGROUND = Sketchup::Color.new(255, 255, 255, 230).freeze
    COLOR_MESSAGE_BACKGROUND_ERROR = COLOR_MESSAGE_TEXT_ERROR.blend(Kuix::COLOR_WHITE, 0.2).freeze
    COLOR_MESSAGE_BACKGROUND_WARNING = Sketchup::Color.new('#ffe69c').freeze
    COLOR_MESSAGE_BACKGROUND_SUCCESS = COLOR_MESSAGE_TEXT_SUCCESS.blend(Kuix::COLOR_WHITE, 0.2).freeze

    def initialize(quit_on_esc = true, quit_on_undo = false)
      super

      # Action
      @current_action = nil

      # Setup action stack
      @action_stack = []

      # Create cursors
      @cursor_select_error = create_cursor('select-error', 0, 0)

      # Mouse
      @last_mouse_x = 0
      @last_mouse_y = 0

    end

    def get_stripped_name
      # Implemented in derived class
    end

    # -- UI stuff --

    def get_unit(view = nil)
      return @unit unless @unit.nil?
      return 3 if view && Sketchup.active_model.nil?
      view = Sketchup.active_model.active_view if view.nil?
      if view.respond_to?(:device_height)
        device_height = view.device_height  # SU 2025+
      else
        device_height = view.vpheight
      end
      if device_height > 2000
        @unit = 8
      elsif device_height > 1000
        @unit = 6
      elsif device_height > 500
        @unit = 4
      else
        @unit = 3
      end
      @unit /= UI.scale_factor(view) if view.respond_to?(:device_height)  # SU 2025 workaround
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

      @canvas.layout = Kuix::StaticLayout.new

      unit = get_unit(view)

      # -- TOP

      @top_panel = Kuix::Panel.new
      @top_panel.layout_data = Kuix::StaticLayoutData.new(0, 0, 1.0, -1)
      @top_panel.layout = Kuix::BorderLayout.new
      @canvas.append(@top_panel)

        # Actions panel

        actions_panel = Kuix::Panel.new
        actions_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        actions_panel.layout = Kuix::BorderLayout.new
        actions_panel.set_style_attribute(:background_color, COLOR_BRAND_DARK)
        @actions_panel = actions_panel
        @top_panel.append(actions_panel)

          actions_lbl = Kuix::Label.new
          actions_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
          actions_lbl.padding.set!(0, unit * 4, 0, unit * 4)
          actions_lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
          actions_lbl.text = Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.title").upcase
          actions_lbl.text_size = unit * 3 * get_text_unit_factor
          actions_lbl.text_bold = true
          actions_panel.append(actions_lbl)

          actions_btns_panel = Kuix::Panel.new
          actions_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
          actions_btns_panel.layout = Kuix::InlineLayout.new(true, 0, Kuix::Anchor.new(Kuix::Anchor::CENTER))
          actions_panel.append(actions_btns_panel)

          @action_buttons = []
          @actions_options_panels = []
          get_action_defs.each do |action_def|

            action = action_def[:action]

            data = {
              :action => action
            }

            actions_btn = Kuix::Button.new
            actions_btn.layout = Kuix::BorderLayout.new
            actions_btn.border.set!(0, unit / 4, 0, unit / 4)
            actions_btn.min_size.set_all!(unit * 10)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_DARK.blend(Kuix::COLOR_WHITE, 0.8))
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND, :selected)
            lbl = actions_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}"), unit * 3 * get_text_unit_factor)
            lbl.padding.set!(0, unit * 4, 0, unit * 4)
            lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            lbl.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            lbl.set_style_attribute(:color, Kuix::COLOR_WHITE, :selected)
            actions_btn.data = data
            actions_btn.on(:click) { |button|
              set_root_action(action)
            }
            actions_btn.on(:enter) { |button|
              show_message(Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_status"))
            }
            actions_btn.on(:leave) { |button|
              hide_message
            }
            actions_btns_panel.append(actions_btn)
            @action_buttons.push(actions_btn)

            # Options Panels

            options = action_def[:options]
            if options.is_a?(Hash)

              actions_options_panel = Kuix::Panel.new
              actions_options_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
              actions_options_panel.layout = Kuix::InlineLayout.new(true, unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
              actions_options_panel.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
              actions_options_panel.min_size.set!(0, unit * 10)
              actions_options_panel.data = { :action => action }
              @actions_options_panels.push(actions_options_panel)

              options.each do |option_group, options|

                lbl = Kuix::Label.new
                lbl.text = Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_option_group_#{option_group}")
                lbl.text_bold = true
                lbl.text_size = unit * 3 * get_text_unit_factor
                if actions_options_panel.child
                  lbl.margin.left = unit * 3
                  lbl.border.left = unit * 0.2
                  lbl.padding.left = unit * 3
                  lbl.set_style_attribute(:border_color, Kuix::COLOR_BLACK)
                end
                actions_options_panel.append(lbl)

                options.each do |option|

                  btn = Kuix::Button.new
                  btn.layout = Kuix::GridLayout.new
                  btn.set_style_attribute(:background_color, Sketchup::Color.new(240, 240, 240))
                  btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE, :selected)
                  btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
                  btn.set_style_attribute(:background_color, COLOR_BRAND, :active)
                  btn.set_style_attribute(:border_color, COLOR_BRAND, :hover)
                  btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
                  btn.border.set_all!(unit * 0.5)
                  btn.data = { :option_group => option_group, :option => option }
                  btn.selected = fetch_action_option_enabled(action, option_group, option)
                  btn.on(:click) { |button|
                    if get_action_option_group_unique?(action, option_group)
                      b = button.parent.child
                      until b.nil? do
                        if b.is_a?(Kuix::Button)&& !b.data.nil? && b.data[:option_group] == option_group
                          b.selected = false
                        end
                        b = b.next
                      end
                      button.selected = true
                      store_action_option_value(action, option_group, option)
                      set_root_action(fetch_action)
                    else
                      button.selected = !button.selected?
                      store_action_option_value(action, option_group, option, button.selected?)
                    end
                  }
                  btn.on(:enter) { |button|
                    show_message(get_action_option_status(action, option_group, option))
                  }
                  btn.on(:leave) { |button|
                    hide_message
                  }
                  actions_options_panel.append(btn)

                    child = get_action_option_btn_child(action, option_group, option)
                    if child
                      if child.is_a?(Kuix::Label)
                        child.text_size = unit * 3 * get_text_unit_factor if child.respond_to?(:text_size=)
                        child.padding.set!(unit, unit * 2, unit, unit * 2)
                        child.min_size.width = unit * 6
                      elsif child.is_a?(Kuix::Motif2d)
                        child.line_width = @unit <= 4 ? 0.5 : 1.0
                        child.margin.set_all!(unit)
                        child.min_size.width = unit * 4
                      end
                      child.set_style_attribute(:color, Kuix::COLOR_BLACK)
                      child.set_style_attribute(:color, Kuix::COLOR_WHITE, :active)
                      btn.append(child)

                    end

                end

              end

              if get_action_options_modal?(action)

                btn = Kuix::Button.new
                btn.layout = Kuix::GridLayout.new
                btn.set_style_attribute(:background_color, Sketchup::Color.new(240, 240, 240))
                btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
                btn.set_style_attribute(:background_color, COLOR_BRAND, :active)
                btn.set_style_attribute(:border_color, COLOR_BRAND, :hover)
                btn.border.set_all!(unit * 0.5)
                btn.on(:click) { |button|
                  Plugin.instance.show_modal_dialog("smart_#{get_stripped_name}_tool_action_#{action}", { :action => action })
                }
                actions_options_panel.append(btn)

                  child = Kuix::Label.new("#{Plugin.instance.get_i18n_string('tool.default.more')}...")
                  child.text_size = unit * 3 * get_text_unit_factor
                  child.padding.set!(unit, unit * 2, unit, unit * 2)
                  child.set_style_attribute(:color, Kuix::COLOR_BLACK)
                  child.set_style_attribute(:color, Kuix::COLOR_WHITE, :active)
                  btn.append(child)

              end

            end

          end

          # Help Button

          help_btn = Kuix::Button.new
          help_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
          help_btn.layout = Kuix::GridLayout.new
          help_btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
          help_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
          lbl = help_btn.append_static_label(Plugin.instance.get_i18n_string("default.help").upcase, unit * 3 * get_text_unit_factor)
          lbl.min_size.set!(unit * 15, 0)
          lbl.padding.set!(0, unit * 4, 0, unit * 4)
          lbl.set_style_attribute(:color, COLOR_BRAND_DARK)
          help_btn.on(:click) { |button|
            Plugin.instance.open_docs_page("tool.smart-#{get_stripped_name}")
          }
          actions_panel.append(help_btn)

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

      # -- NOTIFICATION

      @notification_panel = Kuix::Panel.new
      @notification_panel.layout_data = Kuix::StaticLayoutData.new(0.5, 1.0, -1, -1, Kuix::Anchor.new(Kuix::Anchor::BOTTOM_CENTER))
      @notification_panel.layout = Kuix::InlineLayout.new(false, unit)
      @notification_panel.margin.bottom = unit * 2
      @notification_panel.visible = false
      @canvas.append(@notification_panel)

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
      minitool_btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE, :hover)
      minitool_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :active)
      minitool_btn.set_style_attribute(:border_color, Sketchup::Color.new(255, 255, 255, 0.5))
      minitool_btn.set_style_attribute(:border_color, Kuix::COLOR_WHITE, :hover)
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

    def show_message(text, type = MESSAGE_TYPE_DEFAULT)
      return unless @message_panel && text.is_a?(String)

      case type
      when MESSAGE_TYPE_ERROR
        background_color = COLOR_MESSAGE_BACKGROUND_ERROR
        border_color = COLOR_MESSAGE_TEXT_ERROR
        text_color = COLOR_MESSAGE_TEXT_ERROR
      when MESSAGE_TYPE_WARNING
        background_color = COLOR_MESSAGE_BACKGROUND_WARNING
        border_color = COLOR_MESSAGE_TEXT_WARNING
        text_color = COLOR_MESSAGE_TEXT_WARNING
      when MESSAGE_TYPE_SUCCESS
        background_color = COLOR_MESSAGE_BACKGROUND_SUCCESS
        border_color = COLOR_MESSAGE_TEXT_SUCCESS
        text_color = COLOR_MESSAGE_TEXT_SUCCESS
      else
        background_color = COLOR_MESSAGE_BACKGROUND
        border_color = Kuix::COLOR_BLACK
        text_color = Kuix::COLOR_BLACK
      end

      @message_lbl.text = text
      @message_panel.visible = !text.empty?
      @message_lbl.set_style_attribute(:color, text_color)
      @message_lbl.set_style_attribute(:background_color, background_color)
      @message_lbl.set_style_attribute(:border_color, border_color)

    end

    def hide_message
      @message_panel.visible = false
    end

    def show_tooltip(items, type = MESSAGE_TYPE_DEFAULT)

      remove_tooltip

      unit = get_unit
      case type
      when MESSAGE_TYPE_ERROR
        background_color = COLOR_MESSAGE_BACKGROUND_ERROR
        border_color = COLOR_MESSAGE_TEXT_ERROR
        text_color = COLOR_MESSAGE_TEXT_ERROR
      when MESSAGE_TYPE_WARNING
        background_color = COLOR_MESSAGE_BACKGROUND_WARNING
        border_color = COLOR_MESSAGE_TEXT_WARNING
        text_color = COLOR_MESSAGE_TEXT_WARNING
      when MESSAGE_TYPE_SUCCESS
        background_color = COLOR_MESSAGE_BACKGROUND_SUCCESS
        border_color = COLOR_MESSAGE_TEXT_SUCCESS
        text_color = COLOR_MESSAGE_TEXT_SUCCESS
      else
        background_color = COLOR_MESSAGE_BACKGROUND
        border_color = Kuix::COLOR_BLACK
        text_color = Kuix::COLOR_BLACK
      end

      box = Kuix::Panel.new
      box.layout_data = Kuix::StaticLayoutData.new(0, 0, -1, -1, Kuix::Anchor.new(Kuix::Anchor::TOP_LEFT))
      box.layout = Kuix::InlineLayout.new(false, unit)
      box.border.set_all!(unit / 4)
      box.padding.set_all!(unit * 1.5)
      box.hittable = false
      box.set_style_attribute(:background_color, background_color)
      box.set_style_attribute(:border_color, border_color)

        items = [ items ] if items.is_a?(String)
        items.each do |item|
          next if item.nil?

          if item.is_a?(String)

            if item == '-'

              sep = Kuix::Panel.new
              sep.border.top = unit / 4
              sep.set_style_attribute(:border_color, text_color)

              box.append(sep)

              next
            end

            is_title = item.start_with?('#')
            item = item[1..-1] if is_title

            lbl = Kuix::Label.new
            lbl.text = item
            lbl.text_bold = true if is_title
            lbl.text_size = unit * (is_title || items.one? ? 3 : 2.5) * get_text_unit_factor
            lbl.text_align = TextAlignLeft
            lbl.set_style_attribute(:color, text_color)

            box.append(lbl)

          elsif item.is_a?(Array)

            panel = Kuix::Panel.new
            panel.layout = Kuix::InlineLayout.new(true, @unit * 1.5)

            item.each do |sub_item|

              if sub_item.is_a?(Kuix::Motif2d)
                sub_item.padding.set_all!(@unit)
                sub_item.min_size.set_all!(@unit * get_text_unit_factor * 3)
                sub_item.line_width = @unit <= 4 ? 0.5 : 1
                sub_item.set_style_attribute(:background_color, text_color)
                sub_item.set_style_attribute(:color, Kuix::COLOR_WHITE)
                panel.append(sub_item)
              end

            end

            box.append(panel)

          elsif item.is_a?(Kuix::Entity2d)

            item.min_size.set_all!(@unit * get_text_unit_factor * 4)
            item.set_style_attribute(:color, text_color)

            box.append(item)

          end

        end

      @tooltip_box = box

      move_tooltip(@last_mouse_x, @last_mouse_y)

      @canvas.append(box)

    end

    def remove_tooltip
      return if @tooltip_box.nil?
      @tooltip_box.remove
      @tooltip_box = nil
    end

    def hide_tooltip
      return if @tooltip_box.nil?
      @tooltip_box.visible = false
    end

    def reveal_tooltip
      return if @tooltip_box.nil?
      @tooltip_box.visible = true
    end

    def move_tooltip(mouse_x, mouse_y)
      unless @tooltip_box.nil?
        @tooltip_box.visible = true
        @tooltip_box.layout_data.x = mouse_x + 10 * UI.scale_factor
        @tooltip_box.layout_data.y = mouse_y + (32 + 10) * UI.scale_factor
        @tooltip_box.invalidate
      end
    end

    def notify(text, type = MESSAGE_TYPE_DEFAULT, button_defs = [], timeout = 5) # buttons = [ { :label => BTN_TEXT, :block => BTN_BLOCK } ]
      return unless @notification_panel && text.is_a?(String)

      unit = get_unit

      # Box

      box = Kuix::Button.new
      box.layout = Kuix::BorderLayout.new(unit * 2, unit * 2)
      box.border.set_all!(unit / 4)
      box.padding.top = unit * 3
      case type
      when MESSAGE_TYPE_ERROR
        box.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_ERROR)
        box.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_ERROR)
      when MESSAGE_TYPE_WARNING
        box.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_WARNING)
        box.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_WARNING)
      when MESSAGE_TYPE_SUCCESS
        box.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND_SUCCESS)
        box.set_style_attribute(:border_color, COLOR_MESSAGE_TEXT_SUCCESS)
      else
        box.set_style_attribute(:background_color, COLOR_MESSAGE_BACKGROUND)
        box.set_style_attribute(:border_color, Sketchup::Color.new)
      end

        # Label

        lbl = Kuix::Label.new
        lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
        lbl.margin.left = unit * 4
        lbl.text_size = unit * 3.5 * get_text_unit_factor
        lbl.text = text
        case type
        when MESSAGE_TYPE_ERROR
          lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_ERROR)
        when MESSAGE_TYPE_WARNING
          lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_WARNING)
        when MESSAGE_TYPE_SUCCESS
          lbl.set_style_attribute(:color, COLOR_MESSAGE_TEXT_SUCCESS)
        else
          lbl.set_style_attribute(:color, nil)
        end
        box.append(lbl)

        # Progress

        progress = Kuix::Progress.new(0, timeout)
        progress.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
        progress.min_size.height = unit
        progress.set_style_attribute(:color, Sketchup::Color.new(0, 0, 0, 30))
        progress.value = timeout
        box.append(progress)

      # Timer

      progress_timer_seconds = 0.1
      progress_timer_id = 0
      close_lambda = lambda {

        # Stop animation timer
        UI.stop_timer(progress_timer_id)

        # Remove message box
        box.remove

        # Hide notification panel if no more child
        @notification_panel.visible = false if @notification_panel.last_child.nil?

      }
      advance_lambda = lambda {
        if box.in_dom?

          # Decrment progress
          progress.value -= progress_timer_seconds

          # Check completed
          if progress.value <= 0
            close_lambda.call
          end

        else
          close_lambda.call
        end
      }
      start_lambda = lambda {
        progress_timer_id = UI.start_timer(progress_timer_seconds, true, &advance_lambda)
      }
      pause_lambda = lambda {
        UI.stop_timer(progress_timer_id)
        progress.value = timeout
      }

      box.on(:click) { close_lambda.call }
      box.on(:enter) { pause_lambda.call }
      box.on(:leave) { start_lambda.call }

      # Buttons

      if button_defs.is_a?(Array) && !button_defs.empty?

        btn_panel = Kuix::Panel.new
        btn_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
        btn_panel.layout = Kuix::GridLayout.new(button_defs.count, 1, unit * 2)
        btn_panel.margin.right = unit * 3

        button_defs.each do |button_def|

          btn = Kuix::Button.new
          btn.layout = Kuix::BorderLayout.new
          btn.padding.set!(unit * 2, unit * 4, unit * 2, unit * 4)
          btn.border.set_all!(unit / 4)
          btn.append_static_label(button_def[:label], unit * 3.5 * get_text_unit_factor)
          btn.set_style_attribute(:background_color, Kuix::COLOR_LIGHT_GREY)
          btn.set_style_attribute(:background_color, Kuix::COLOR_MEDIUM_GREY, :hover)
          btn.set_style_attribute(:border_color, Kuix::COLOR_DARK_GREY)
          btn.on(:click) { |button|
            button_def[:block].call unless button_def[:block].nil?
            close_lambda.call
          }
          btn.on(:enter) { pause_lambda.call }
          btn.on(:leave) { start_lambda.call }
          btn_panel.append(btn)

        end

        box.append(btn_panel)

      end

      @notification_panel.append(box)
      @notification_panel.visible = !@notification_panel.last_child.nil?

      start_lambda.call

    end

    def notify_success(text, button_defs = [])
      notify('✔ ' + text, MESSAGE_TYPE_SUCCESS, button_defs)
    end

    def notify_errors(errors) # errors = [ [ I18N_PATH_KEY, { :VAR1 => value1, :VAR2 => value2, ... } ], ... ]
      errors.each do |error|
        if error.is_a?(Array)
          path_key = error[0]
          vars = error[1]
        else
          path_key = error
          vars = nil
        end
        notify('⚠ ' + Plugin.instance.get_i18n_string(path_key, vars), MESSAGE_TYPE_ERROR)
      end
    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :options => { OPTION_GROUP_1 => [ OPTION_1, OPTION_2 ] } }>
      []
    end

    def get_action_status(action)
      return '' if action.nil?
      Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_status")
    end

    def get_action_option_status(action, option_group, option)
      return '' if action.nil? || option_group.nil? || option.nil?
      Plugin.instance.get_i18n_string("tool.smart_#{get_stripped_name}.action_option_#{option_group}_#{option}_status")
    end

    def get_action_cursor(action)
      @cursor_select_error
    end

    def get_action_options_modal?(action)
      false
    end

    def get_action_option_group_unique?(action, option_group)
      false
    end

    def get_action_option_btn_child(action, option_group, option)
      nil
    end

    def store_action(action)
      Plugin.instance.write_default("settings.smart_#{get_stripped_name}_last_action", action)
      @current_action = action
    end

    def fetch_action
      return @current_action unless @current_action.nil?
      @current_action = Plugin.instance.read_default("settings.smart_#{get_stripped_name}_last_action")
      @current_action = get_action_defs.first[:action] if get_action_defs.find { |action_def| action_def[:action] == @current_action }.nil?
      @current_action
    end

    def store_action_option_value(action, option_group, option, value = nil)
      dictionary = "tool_smart_#{get_stripped_name}_options"
      section = "action_#{action}"
      preset = Plugin.instance.get_global_preset(dictionary, nil, section)
      if get_action_option_group_unique?(action, option_group)
        preset.store(option_group.to_s, option)
      else
        preset.store(option.to_s, value)
      end
      Plugin.instance.set_global_preset(dictionary, preset, nil, section)
    end

    def fetch_action_option_value(action, option_group, option = nil)
      dictionary = "tool_smart_#{get_stripped_name}_options"
      section = "action_#{action}"
      preset = Plugin.instance.get_global_preset(dictionary, nil, section)
      return nil if preset.nil?
      return preset.fetch(option_group.to_s, nil) if get_action_option_group_unique?(action, option_group)
      return preset.fetch(option.to_s, nil) unless option.nil?
      nil
    end

    def fetch_action_option_enabled(action, option_group, option)
      value = fetch_action_option_value(action, option_group, option)
      return false if value.nil?
      return option == value if get_action_option_group_unique?(action, option_group)
      return value if value.is_a?(TrueClass)
      false
    end

    def get_startup_action
      fetch_action.nil? ? get_action_defs.first[:action] : fetch_action
    end

    def set_action(action)

      # Hide possible modal
      Plugin.instance.hide_modal_dialog

      # Store settings in class variable
      store_action(action)

      # Update buttons
      if @action_buttons
        @action_buttons.each do |button|
          button.selected = button.data[:action] == action
        end
      end

      # Update options panel
      @actions_options_panels.each do |actions_options_panel|
        if actions_options_panel.data[:action] == action
          @actions_panel.append(actions_options_panel)
        else
          actions_options_panel.remove
        end
      end

      # Update status text and root cursor
      Sketchup.set_status_text(get_action_status(action), SB_PROMPT)
      set_root_cursor(get_action_cursor(action))
      pop_to_root_cursor

      # Fire event
      onActionChange(action) if self.respond_to?(:onActionChange)

    end

    def set_root_action(action)
      @action_stack.clear

      # Select a default action
      if action.nil?
        action = get_action_defs.first[:action]
      end

      push_action(action)
    end

    def push_action(action)
      @action_stack.push({ :action => action })
      set_action(action)
    end

    def pop_action
      @action_stack.pop if @action_stack.length > 1
      set_action(@action_stack.last[:action])
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
      if @active_part
        active_part_id = @active_part.id
        active_part_material_type = @active_part.group.material_type
        item = menu.add_item(_get_active_part_name) {}
        menu.set_validation_proc(item) { MF_GRAYED }
        menu.add_separator
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_properties')) {
          _select_active_part_entity
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'general', dontGenerate: false }")
        }
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_axes_properties')) {
          _select_active_part_entity
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'axes', dontGenerate: false }")
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_size_increase_properties')) {
          _select_active_part_entity
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'size_increase', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SOLID_WOOD ||
            active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD ||
            active_part_material_type == MaterialAttributes::TYPE_DIMENSIONAL
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_edges_properties')) {
          _select_active_part_entity
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'edges', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_faces_properties')) {
          _select_active_part_entity
          Plugin.instance.execute_tabs_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'faces', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
      else
        menu.add_item(Plugin.instance.get_i18n_string('default.close')) {
          quit
        }
      end
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

      # Add event callbacks
      @event_callback = Plugin.instance.add_event_callback(PluginObserver::ON_GLOBAL_PRESET_CHANGED) do |params|
        if params[:dictionary] == "tool_smart_#{get_stripped_name}_options" && params[:section] == "action_#{fetch_action}"
          @actions_options_panels.each do |actions_options_panel|

            action = actions_options_panel.data[:action]
            b = actions_options_panel.child
            until b.nil? do
              if b.is_a?(Kuix::Button) && !b.data.nil?
                b.selected = fetch_action_option_enabled(action, b.data[:option_group], b.data[:option])
              end
              b = b.next
            end

          end
        end
      end

    end

    def onDeactivate(view)
      super

      # Stop observing rendering options events
      view.model.rendering_options.remove_observer(self)

      # Hide possible modal
      Plugin.instance.hide_modal_dialog

      # Remove event callbacks
      Plugin.instance.remove_event_callback(PluginObserver::ON_GLOBAL_PRESET_CHANGED, @event_callback)

    end

    def onResume(view)
      super
      set_root_action(fetch_action)  # Force SU status text
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if key == 9 || key == 25  # TAB key doesn't generate "onKeyDown" event and SHIFT + TAB = 25 on Mac

        action_defs = get_action_defs
        action = fetch_action
        action_index = action_defs.index { |action_def| action_def[:action] == action }
        unless action_index.nil?

          if is_key_down?(COPY_MODIFIER_KEY)

            # Select next "modifier" if exists

            unless action_defs[action_index][:options].nil? || action_defs[action_index][:options].empty?

              modifier_option_group = action_defs[action_index][:options].keys.first
              modifier_options = action_defs[action_index][:options][modifier_option_group]

              modifier_option = modifier_options.detect { |option| fetch_action_option_enabled(action, modifier_option_group, option) }
              modifier_option_index = modifier_options.index(modifier_option)
              unless modifier_option_index.nil?

                next_modifier_option_index = (modifier_option_index + (is_key_down?(CONSTRAIN_MODIFIER_KEY) ? -1 : 1)) % modifier_options.length
                next_modifier_option = modifier_options[next_modifier_option_index]

                @actions_options_panels.each do |actions_options_panel|
                  if actions_options_panel.data[:action] == action

                    b = actions_options_panel.child
                    until b.nil? do
                      if b.is_a?(Kuix::Button) && b.data[:option_group] == modifier_option_group && b.data[:option] == next_modifier_option
                        b.fire(:click, flags)
                        break
                      end
                      b = b.next
                    end

                  end
                end

                return true
              end

            end

          else

            # Select next action

            next_action_index = (action_index + (is_key_down?(CONSTRAIN_MODIFIER_KEY) ? -1 : 1)) % action_defs.length
            next_action = action_defs[next_action_index][:action]
            set_root_action(next_action)

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

      @last_mouse_x = x
      @last_mouse_y = y

      if super
        hide_tooltip
        return true
      end

      # Tooltip
      move_tooltip(x, y)

      # Action
      unless is_action_none?

        @input_point.pick(view, x, y)

        # SKETCHUP_CONSOLE.clear
        # puts "# INPUT"
        # puts "  Face = #{@input_point.face}"
        # puts "  Edge = #{@input_point.edge} -> onface? = #{@input_point.edge && @input_point.face ? @input_point.edge.used_by?(@input_point.face) : ''}"
        # puts "  Vertex = #{@input_point.vertex} -> onface? = #{@input_point.vertex && @input_point.face ? @input_point.vertex.used_by?(@input_point.face) : ''}"
        # puts "  InstancePath = #{@input_point.instance_path.to_a}"
        # puts "  Transformation = #{@input_point.transformation}"

        if !@input_point.face.nil?

          input_context_path = nil
          input_face_path = nil
          input_face = @input_point.face
          input_edge = @input_point.edge
          input_vertex = @input_point.vertex

          if @input_point.instance_path.leaf == input_face || @input_point.instance_path.leaf.respond_to?(:used_by?) && @input_point.instance_path.leaf.used_by?(input_face)
            input_context_path = @input_point.instance_path.to_a[0...-1]
          else

            if @pick_helper.do_pick(x, y)

              # Input point gives a face without instance path
              # Let's try to use pick helper to pick the face path
              @pick_helper.count.times do |index|
                if @pick_helper.leaf_at(index) == input_face
                  input_context_path = @pick_helper.path_at(index)[0...-1]
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

          # Exit if picked elements are the same as previous
          return true if input_context_path == @input_context_path && input_face == @input_face && input_edge == @input_edge && input_vertex == @input_vertex

          @input_context_path = input_context_path
          @input_face_path = input_context_path && input_face ? input_context_path + [ input_face ] : nil
          @input_face = input_face
          @input_edge_path = input_context_path && input_edge ? input_context_path + [ input_edge ] : nil
          @input_edge = input_edge
          @input_vertex = input_vertex

        elsif !@input_point.edge.nil?

          input_context_path = nil
          input_edge = @input_point.edge

          if @input_point.instance_path.leaf == input_edge || @input_point.instance_path.leaf.respond_to?(:used_by?) && @input_point.instance_path.leaf.used_by?(input_edge)
            input_context_path = @input_point.instance_path.to_a[0...-1]
          else

            if @pick_helper.do_pick(x, y)

              # Input point gives a face without instance path
              # Let's try to use pick helper to pick the face path
              @pick_helper.count.times do |index|
                if @pick_helper.leaf_at(index) == input_edge
                  input_context_path = @pick_helper.path_at(index)[0...-1]
                  break
                end
              end

            end

          end

          # Exit if picked edge is the same as previous
          return true if input_context_path == @input_context_path && input_edge == @input_edge

          @input_context_path = input_context_path
          @input_face_path = nil
          @input_face = nil
          @input_edge_path = input_context_path && input_edge ? input_context_path + [ input_edge ] : nil
          @input_edge = input_edge
          @input_vertex = nil

        elsif !@input_point.vertex.nil?

          input_context_path = nil
          input_face = nil
          input_edge = nil
          input_vertex = @input_point.vertex

          if @input_point.instance_path.leaf == input_vertex
            input_context_path = @input_point.instance_path.to_a[0...-1]
          else

            if @pick_helper.do_pick(x, y)

              # Input point gives a vertex without instance path
              # Let's try to use pick helper to pick the face path
              @pick_helper.count.times do |index|
                if @pick_helper.leaf_at(index).respond_to?(:used_by?) && @pick_helper.leaf_at(index).used_by?(input_vertex)
                  input_context_path = @pick_helper.path_at(index)[0...-1]
                  break
                end
              end

            end

          end

          input_face = @input_face if input_vertex.faces.include?(@input_face)
          input_face = input_vertex.faces.first if input_face.nil?

          input_edge = @input_edge if input_vertex.edges.include?(@input_edge)
          input_edge = input_vertex.edges.first if input_edge.nil?

          # Exit if picked vertex is the same as previous
          return true if input_context_path == @input_context_path && input_face == @input_face && input_edge == @input_edge && input_vertex == @input_vertex

          @input_context_path = input_context_path
          @input_face_path = input_context_path && input_face ? input_context_path + [ input_face ] : nil
          @input_face = input_face
          @input_edge_path = input_context_path && input_edge ? input_context_path + [ input_edge ] : nil
          @input_edge = input_edge
          @input_vertex = input_vertex

        else

          @input_context_path = nil
          @input_face_path = nil
          @input_face = nil
          @input_edge_path = nil
          @input_edge = nil
          @input_vertex = nil

        end

        # puts "# OUTPUT"
        # puts "  Face = #{@input_face}"
        # puts "  Edge = #{@input_edge} -> onface? = #{@input_edge && @input_face ?  @input_edge.used_by?(@input_face) : ''}"
        # puts "  Vertex = #{@input_vertex} -> onface? = #{@input_vertex && @input_face ? @input_vertex.used_by?(@input_face) : ''}"
        # puts "  ContextPath = #{@input_context_path}"
        # puts "  FacePath = #{@input_face_path}"
        # puts "  EdgePath = #{@input_edge_path}"

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

    def _refresh_active_edge(highlighted = false)
      _set_active_context(@active_context_path, highlighted)
    end

    def _reset_active_edge
      _set_active_context(nil)
    end

    def _set_active_context(context_path, highlighted = false)

      @active_context_path = context_path

      _reset_ui

    end

    def _refresh_active_face(highlighted = false)
      _set_active_face(@input_face_path, @input_face, highlighted)
    end

    def _reset_active_face
      _set_active_face(nil, nil)
    end

    def _set_active_face(face_path, face, highlighted = false)

      @active_face_path = face_path
      @active_face = face

      _reset_ui

    end

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

    def _get_active_part_name(sanitize_for_filename = false)
      return nil unless @active_part.is_a?(Part)
      "#{@active_part.saved_number && @active_part.number == @active_part.saved_number ? "#{@active_part.number} - " : ''}#{sanitize_for_filename ? _sanitize_filename(@active_part.name) : @active_part.name}"
    end

    def _get_active_part_size
      return nil unless @active_part.is_a?(Part)
      "#{@active_part.length} x #{@active_part.width} x #{@active_part.thickness}"
    end

    def _get_active_part_material_name
      return nil unless @active_part.is_a?(Part) && !@active_part.material_name.empty?
      "#{@active_part.material_name.strip} (#{Plugin.instance.get_i18n_string("tab.materials.type_#{@active_part.group.material_type}")})"
    end

    def _get_active_part_icons
      return nil unless @active_part.is_a?(Part)
      if @active_part.flipped || @active_part.resized || @active_part.auto_oriented
        icons = []
        icons << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2')) if @active_part.flipped
        icons << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.6,0L0.4,0 M0.6,0.4L0.8,0.2L0.5,0.2 M0.8,0.2L0.8,0.5 M0.8,0L1,0L1,0.2 M1,0.4L1,0.6 M1,0.8L1,1L0.8,1 M0.2,0L0,0L0,0.2 M0,1L0,0.4L0.6,0.4L0.6,1L0,1')) if @active_part.resized
        icons << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.642,0.349L0.642,0.752 M0.541,0.45L0.642,0.349L0.743,0.45 M0.292,0.954L0.642,0.752 M0.43,0.991L0.292,0.954L0.329,0.816 M0.991,0.954L0.642,0.752 M0.853,0.991L0.991,0.954L0.954,0.816 M0.477,0.001L0.584,0.091L0.494,0.198 M0.001,0.477L0.091,0.584L0.198,0.494 M0.091,0.584L0.108,0.456L0.157,0.338L0.235,0.235L0.338,0.157L0.456,0.108L0.584,0.091')) if @active_part.auto_oriented
        return icons
      end
      nil
    end

    def _select_active_part_entity
      model = Sketchup.active_model
      if model && @active_part_entity_path.is_a?(Array) && @active_part_entity_path.length > 0
        selection = model.selection
        selection.clear
        selection.add(@active_part_entity_path.last)
      end
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
      remove_tooltip

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
