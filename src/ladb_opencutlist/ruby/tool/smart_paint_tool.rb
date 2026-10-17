module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/kuix'
  require_relative '../utils/path_utils'
  require_relative '../utils/color_utils'
  require_relative '../utils/material_utils'
  require_relative '../helper/face_triangles_helper'
  require_relative '../model/attributes/material_attributes'
  require_relative '../worker/cutlist/cutlist_generate_worker'

  class SmartPaintTool < SmartTool

    ACTION_PAINT_PARTS = 0
    ACTION_PAINT_EDGES = 1
    ACTION_PAINT_FACES = 2
    ACTION_PICK = 3
    ACTION_PAINT_CLEAN = 4

    ACTION_OPTION_INSTANCES = 'instances'
    ACTION_OPTION_EDGES = 'edges'
    ACTION_OPTION_FACES = 'faces'

    ACTION_OPTION_INSTANCES_1 = 0
    ACTION_OPTION_INSTANCES_ALL = 1

    ACTION_OPTION_EDGES_1 = 0
    ACTION_OPTION_EDGES_2 = 1
    ACTION_OPTION_EDGES_4 = 2

    ACTION_OPTION_FACES_1 = 0
    ACTION_OPTION_FACES_2 = 1

    ACTIONS = [
      {
        :action => ACTION_PAINT_PARTS,
        :options => {
          ACTION_OPTION_INSTANCES => [ ACTION_OPTION_INSTANCES_1, ACTION_OPTION_INSTANCES_ALL ]
        }
      },
      {
        :action => ACTION_PAINT_EDGES,
        :options => {
          ACTION_OPTION_EDGES => [ ACTION_OPTION_EDGES_1, ACTION_OPTION_EDGES_2, ACTION_OPTION_EDGES_4 ]
        }
      },
      {
        :action => ACTION_PAINT_FACES,
        :options => {
          ACTION_OPTION_FACES => [ ACTION_OPTION_FACES_1, ACTION_OPTION_FACES_2 ]
        }
      },
      {
        :action => ACTION_PICK
      },
      {
        :action => ACTION_PAINT_CLEAN
      }
    ].freeze

    COLOR_MATERIAL_TYPES = {
      MaterialAttributes::TYPE_UNKNOWN => Sketchup::Color.new(128, 128, 128).freeze,
      MaterialAttributes::TYPE_SOLID_WOOD => Sketchup::Color.new(76, 175, 80).freeze,
      MaterialAttributes::TYPE_SHEET_GOOD => Sketchup::Color.new(237, 162, 0).freeze,
      MaterialAttributes::TYPE_DIMENSIONAL => Sketchup::Color.new(245, 89, 172).freeze,
      MaterialAttributes::TYPE_HARDWARE => Sketchup::Color.new(0, 0, 0).freeze,
      MaterialAttributes::TYPE_EDGE => Sketchup::Color.new(102, 142, 238).freeze,
      MaterialAttributes::TYPE_VENEER => Sketchup::Color.new(131, 56, 236).freeze
    }

    @@action_materials = {} # { action => Sketchup::Material }
    @@action_filters = {}   # { action => Array<MaterialAttributes:TYPE> }

    @@filters = nil

    def initialize(

                   tab_name_to_show_on_quit: nil,

                   material: nil,

                   current_action: nil

    )

      super(
        tab_name_to_show_on_quit: tab_name_to_show_on_quit,
        current_action: current_action
      )

      # Keep the given material
      @startup_material = material

      # Setup default filter if not set
      if @@filters.nil?
        @@filters = {}
        for type in 0..COLOR_MATERIAL_TYPES.length - 1
          @@filters[type] = true
        end
      end

    end

    def get_stripped_name
      'paint'
    end

    def setup_entities(view)
      super

      # Materials panel

      # Below the notifications, the validation and the status. Its static container
      # gives it the bottom width : the bottom panel would take its preferred one.
      materials_container = Kuix::Panel.new
      materials_container.layout = Kuix::StaticLayout.new
      @bottom_panel.append(materials_container)

      @materials_panel = Kuix::Panel.new
      @materials_panel.layout_data = Kuix::StaticLayoutData.new(0, 0, 1.0, -1)
      @materials_panel.layout = Kuix::BorderLayout.new
      materials_container.append(@materials_panel)

      # Material Infos panel

      @material_infos_panel = Kuix::Panel.new
      @material_infos_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      @material_infos_panel.layout = Kuix::InlineLayout.new(true, @unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @material_infos_panel.padding.set_all!(@unit * 2)
      @material_infos_panel.visible = false
      @material_infos_panel.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 85))
      @materials_panel.append(@material_infos_panel)

        @material_infos_lbl_1 = Kuix::Label.new
        @material_infos_lbl_1.text_size = @unit * 3 * get_text_unit_factor
        @material_infos_lbl_1.text_bold = true
        @material_infos_panel.append(@material_infos_lbl_1)

        @material_infos_lbl_2 = Kuix::Label.new
        @material_infos_lbl_2.text_size = @unit * 3 * get_text_unit_factor
        @material_infos_panel.append(@material_infos_lbl_2)

      # Materials Add button

      @materials_add_btn = Kuix::Button.new
      @materials_add_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
      @materials_add_btn.layout = Kuix::StaticLayout.new
      @materials_add_btn.min_size.set!(@unit * 8, @unit * 8)
      @materials_add_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
      @materials_add_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
      @materials_add_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :active)
      @materials_add_btn.on(:click) { |button|
        if is_action_paint_edges?
          type = MaterialAttributes::TYPE_EDGE
        elsif is_action_paint_faces?
          type = MaterialAttributes::TYPE_VENEER
        else
          type = MaterialAttributes::TYPE_UNKNOWN
        end
        PLUGIN.execute_tabs_dialog_command_on_tab('materials', 'new_material', "{ type: #{type} }")
      }
      @materials_panel.append(@materials_add_btn)

        motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.5L0.5,0.5L0.5,0L0.5,0.5L1,0.5L0.5,0.5L0.5,1'))
        motif.layout_data = Kuix::StaticLayoutData.new(0.5, 0, @unit * 10, @unit * 10, Kuix::Anchor.new(Kuix::Anchor::TOP))
        motif.padding.set_all!(@unit * 2)
        motif.line_width = @unit <= 4 ? 1 : 2
        motif.set_style_attribute(:color, COLOR_BRAND_LIGHT)
        motif.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
        @materials_add_btn.append(motif)

      # Materials Buttons panel

      @materials_btns_panel = Kuix::ScrollPanel.new
      @materials_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      @materials_btns_panel.set_style_attribute(:background_color, COLOR_BRAND_DARK)
      @materials_panel.append(@materials_btns_panel)

      # Materials East panel

      east_panel = Kuix::Panel.new
      east_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
      east_panel.layout = Kuix::BorderLayout.new
      @materials_panel.append(east_panel)

        # Materials Filters button

        @materials_filters_btn = Kuix::Button.new
        @materials_filters_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        @materials_filters_btn.layout = Kuix::StaticLayout.new
        @materials_filters_btn.min_size.set!(@unit * 8, @unit * 8)
        @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
        @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
        @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :active)
        @materials_filters_btn.set_style_attribute(:background_color, COLOR_BRAND, :selected)
        @materials_filters_btn.on(:click) { |button|
          @materials_filters_panel.visible = !@materials_filters_panel.visible?
          button.selected = @materials_filters_panel.visible?
        }
        east_panel.append(@materials_filters_btn)

          panel = Kuix::Panel.new
          panel.layout_data = Kuix::StaticLayoutData.new(0.5, 0, 0, @unit * 10, Kuix::Anchor.new(Kuix::Anchor::TOP))
          panel.layout = Kuix::InlineLayout.new
          @materials_filters_btn.append(panel)

            motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.4,1L0.4,0.5L0.1,0.2L0.1,0L0.9,0L0.9,0.2L0.6,0.5L0.6,0.9L0.4,1'))
            motif.padding.set_all!(@unit * 2)
            motif.min_size.set_all!(@unit * 6)
            motif.line_width = @unit <= 4 ? 1 : 2
            motif.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            motif.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            motif.set_style_attribute(:color, Kuix::COLOR_WHITE, :selected)
            panel.append(motif)

            @materials_filters_btn_lbl = Kuix::Label.new('glop')
            @materials_filters_btn_lbl.padding.set!(0, @unit * 2, 0, 0)
            @materials_filters_btn_lbl.text_size = @unit * 3
            @materials_filters_btn_lbl.visible = false
            @materials_filters_btn_lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            @materials_filters_btn_lbl.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            @materials_filters_btn_lbl.set_style_attribute(:color, Kuix::COLOR_WHITE, :selected)
            panel.append(@materials_filters_btn_lbl)

        scroll_btns = Kuix::Panel.new
        scroll_btns.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
        scroll_btns.layout = Kuix::GridLayout.new(1, 2)
        scroll_btns.visible = false
        east_panel.append(scroll_btns)
        @materials_btns_panel.bind_scroll_btns_panel(scroll_btns)

          btn = Kuix::Button.new
          btn.layout = Kuix::StaticLayout.new
          btn.min_size.set!(@unit * 8, @unit * 8)
          btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
          btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
          scroll_btns.append(btn)
          @materials_btns_panel.bind_scroll_up_btn(btn)

            motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L1,1L0.5,0L0,1Z'))
            motif.padding.set_all!(@unit * 2)
            motif.min_size.set_all!(@unit * 6)
            motif.line_width = @unit <= 4 ? 1 : 2
            motif.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            motif.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            motif.set_style_attribute(:color, Kuix::COLOR_DARK_GREY, :disabled)
            btn.append(motif)

          btn = Kuix::Button.new
          btn.layout = Kuix::StaticLayout.new
          btn.min_size.set!(@unit * 8, @unit * 8)
          btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
          btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
          scroll_btns.append(btn)
          @materials_btns_panel.bind_scroll_down_btn(btn)

            motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L1,0L0.5,1L0,0Z'))
            motif.padding.set_all!(@unit * 2)
            motif.min_size.set_all!(@unit * 6)
            motif.line_width = @unit <= 4 ? 1 : 2
            motif.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            motif.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            motif.set_style_attribute(:color, Kuix::COLOR_DARK_GREY, :disabled)
            btn.append(motif)

      # Materials Filters panel

      @materials_filters_panel = Kuix::Panel.new
      @materials_filters_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      @materials_filters_panel.layout = Kuix::BorderLayout.new
      @materials_filters_panel.padding.set_all!(@unit * 2)
      @materials_filters_panel.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
      @materials_filters_panel.visible = false
      @materials_panel.append(@materials_filters_panel)

        lbl = Kuix::Label.new
        lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
        lbl.padding.set!(0, @unit * 3, 0, @unit * 3)
        lbl.text = PLUGIN.get_i18n_string('tool.smart_paint.filters').upcase
        lbl.text_size = @unit * 3 * get_text_unit_factor
        lbl.text_bold = true
        @materials_filters_panel.append(lbl)

        panel = Kuix::Panel.new
        panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
        panel.layout = Kuix::GridLayout.new(COLOR_MATERIAL_TYPES.length,1, @unit, @unit)
        @materials_filters_panel.append(panel)

        @materials_filters_btns = []
        COLOR_MATERIAL_TYPES.each do |type, color|

          btn = Kuix::Button.new
          btn.min_size.set_all!(@unit * 6)
          btn.border.set_all!(@unit / 2)
          btn.set_style_attribute(:background_color, Kuix::COLOR_LIGHT_GREY)
          btn.set_style_attribute(:background_color, color, :active)
          btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE, :selected)
          btn.set_style_attribute(:background_color, color.blend(Kuix::COLOR_WHITE, 0.2), :hover)
          btn.set_style_attribute(:background_color, Kuix::COLOR_DARK_GREY.blend(Kuix::COLOR_WHITE, 0.1), :disabled)
          btn.set_style_attribute(:border_color, color, :selected)
          btn.selected = @@filters[type]
          btn.data = type
          lbl = btn.append_static_label(PLUGIN.get_i18n_string("tool.smart_paint.filter_#{type}"), @unit * 3 * get_text_unit_factor)
          lbl.set_style_attribute(:color, Kuix::COLOR_DARK_GREY, :disabled)
          btn.on(:click) { |button|

            unless get_enabled_filters_by_action(fetch_action).index(button.data).nil?

              toggle_filter_by_type(button.data)
              update_filters_ratio

              store_action_filters(fetch_action, @@filters.clone)

              # Re populate material defs & setup corresponding buttons
              _populate_material_defs(view.model)
              _setup_material_buttons

            end

          }
          btn.on(:doubleclick) { |button|

            unless get_enabled_filters_by_action(fetch_action).index(button.data).nil?

              set_filters(false)
              set_filter_by_type(button.data, true)
              update_filters_ratio

              store_action_filters(fetch_action, @@filters.clone)

              # Re populate material defs & setup corresponding buttons
              _populate_material_defs(view.model)
              _setup_material_buttons

            end

          }
          panel.append(btn)

          @materials_filters_btns.push(btn)

        end

    end

    # -- Show --

    def show_material_infos(material, material_attributes)
      return if material.nil? || material_attributes.nil?

      text_1 = material.display_name.strip
      text_2 = material_attributes.type > MaterialAttributes::TYPE_UNKNOWN ? "(#{PLUGIN.get_i18n_string("tab.materials.type_#{material_attributes.type}")})" : ''

      return unless @material_infos_panel && text_1.is_a?(String) && text_2.is_a?(String)
      @material_infos_lbl_1.text = text_1
      @material_infos_lbl_1.visible = !text_1.empty?
      @material_infos_lbl_2.text = text_2
      @material_infos_lbl_2.visible = !text_2.empty?
      @material_infos_panel.visible = @material_infos_lbl_1.visible? || @material_infos_lbl_2.visible?
    end

    def hide_material_infos
      @material_infos_panel.visible = false
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_PAINT_PARTS
        return SmartCursorManager.cursor_paint_part
      when ACTION_PAINT_EDGES
        if fetch_action_option_boolean(ACTION_PAINT_EDGES, ACTION_OPTION_EDGES, ACTION_OPTION_EDGES_4)
          return SmartCursorManager.cursor_paint_edge_4
        elsif fetch_action_option_boolean(ACTION_PAINT_EDGES, ACTION_OPTION_EDGES, ACTION_OPTION_EDGES_2)
          return SmartCursorManager.cursor_paint_edge_2
        else
          return SmartCursorManager.cursor_paint_edge_1
        end
      when ACTION_PAINT_FACES
        if fetch_action_option_boolean(ACTION_PAINT_FACES, ACTION_OPTION_FACES, ACTION_OPTION_FACES_2)
          return SmartCursorManager.cursor_paint_face_2
        else
          return SmartCursorManager.cursor_paint_face_1
        end
      when ACTION_PICK
        return SmartCursorManager.cursor_picker
      when ACTION_PAINT_CLEAN
        return SmartCursorManager.cursor_paint_clean
      end

      SmartCursorManager.cursor_paint_error
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_INSTANCES, ACTION_OPTION_EDGES, ACTION_OPTION_FACES
        return true
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group
      when ACTION_OPTION_INSTANCES
        case option
        when ACTION_OPTION_INSTANCES_1
          return Kuix::Label.new('1')
        when ACTION_OPTION_INSTANCES_ALL
          return Kuix::Label.new('∞')
        end
      when ACTION_OPTION_EDGES
        case option
        when ACTION_OPTION_EDGES_1
          return Kuix::Label.new('1')
        when ACTION_OPTION_EDGES_2
          return Kuix::Label.new('2')
        when ACTION_OPTION_EDGES_4
          return Kuix::Label.new('4')
        end
      when ACTION_OPTION_FACES
        case option
        when ACTION_OPTION_FACES_1
          return Kuix::Label.new('1')
        when ACTION_OPTION_FACES_2
          return Kuix::Label.new('2')
        end
      end

      super
    end

    def store_action_material(action, material)
      @@action_materials[action] = material
    end

    def fetch_action_material(action)
      @@action_materials[action]
    end

    def store_action_filters(action, filters)
      @@action_filters[action] = filters
    end

    def fetch_action_filters(action)
      @@action_filters[action]
    end

    def get_startup_action
      return super if @startup_material.nil?

      case MaterialAttributes.new(@startup_material).type
      when MaterialAttributes::TYPE_EDGE
        startup_action = ACTION_PAINT_EDGES
      when MaterialAttributes::TYPE_VENEER
        startup_action = ACTION_PAINT_FACES
      else
        startup_action = ACTION_PAINT_PARTS
      end
      store_action_material(startup_action, @startup_material)
      startup_action

    end

    def is_action_part?
      is_action_paint_parts? || is_action_paint_edges? || is_action_paint_faces? || is_action_paint_clean?
    end

    def is_action_paint_parts?
      fetch_action == ACTION_PAINT_PARTS
    end

    def is_action_paint_edges?
      fetch_action == ACTION_PAINT_EDGES
    end

    def is_action_paint_faces?
      fetch_action == ACTION_PAINT_FACES
    end

    def is_action_pick?
      fetch_action == ACTION_PICK
    end

    def is_action_paint_clean?
      fetch_action == ACTION_PAINT_CLEAN
    end

    # -- Filters --

    def get_enabled_filters_by_action(action)

      case action
      when ACTION_PAINT_PARTS
        [
          MaterialAttributes::TYPE_UNKNOWN,
          MaterialAttributes::TYPE_SOLID_WOOD,
          MaterialAttributes::TYPE_SHEET_GOOD,
          MaterialAttributes::TYPE_DIMENSIONAL,
          MaterialAttributes::TYPE_HARDWARE,
        ]
      when ACTION_PAINT_EDGES
        [
          MaterialAttributes::TYPE_EDGE
        ]
      when ACTION_PAINT_FACES
        [
          MaterialAttributes::TYPE_VENEER
        ]
      else
        [
          MaterialAttributes::TYPE_UNKNOWN,
          MaterialAttributes::TYPE_SOLID_WOOD,
          MaterialAttributes::TYPE_SHEET_GOOD,
          MaterialAttributes::TYPE_DIMENSIONAL,
          MaterialAttributes::TYPE_HARDWARE,
          MaterialAttributes::TYPE_EDGE,
          MaterialAttributes::TYPE_VENEER
        ]
      end

    end

    def set_filters(value = true, property = :selected)

      @@filters.keys.each do |type|
        set_filter_by_type(type, value, property)
      end

    end

    def set_filter_by_type(type, value, property = :selected)

      @@filters[type] = value if property == :selected

      if @materials_filters_btns
        @materials_filters_btns.each { |button|
          if button.data == type
            case property
            when :selected
              button.selected = value
            when :disabled
              button.disabled = value
            end
          end
        }
      end

    end

    def toggle_filter_by_type(type, property = :selected)
      set_filter_by_type(type, !@@filters[type], property)
    end

    def update_filters_ratio

      enabled_filters = get_enabled_filters_by_action(fetch_action)
      selected_filter_count = 0
      enabled_filters.each do |type|
        selected_filter_count += 1 if @@filters[type]
      end

      @materials_filters_btn_lbl.text = "#{selected_filter_count}/#{enabled_filters.length}"
      @materials_filters_btn_lbl.visible = selected_filter_count < enabled_filters.length

    end

    def set_current_material(material, update_buttons = false, update_action = false)

      # Switch action according to material type
      if update_action
        case MaterialAttributes.new(material).type
        when MaterialAttributes::TYPE_EDGE
          set_root_action(ACTION_PAINT_EDGES)
        when MaterialAttributes::TYPE_VENEER
          set_root_action(ACTION_PAINT_FACES)
        else
          set_root_action(ACTION_PAINT_PARTS)
        end
      end

      # Save material as current
      store_action_material(fetch_action, material)

      # Update buttons
      if update_buttons
        @material_buttons.each { |button|
          button.selected = button.data == material
        }
      end

      # Update the action preview
      @action_handler.onToolCurrentMaterialChanged(self) if !@action_handler.nil? && @action_handler.respond_to?(:onToolCurrentMaterialChanged)

    end

    def get_current_material
      material = fetch_action_material(fetch_action)
      return material if material
      nil
    end

    # -- Events --

    def onActivate(view)

      # Force action materials to be valid, before the startup action handler uses them
      @@action_materials.each do |action, material|
        next unless material
        begin
          @@action_materials[action] = nil unless material.model == view.model
        rescue => e # Reference to deleted Entity
          @@action_materials[action] = nil
        end
      end

      super

      # Clear current selection
      view.model.selection.clear

      # Observe materials events
      view.model.materials.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing materials events
      view.model.materials.remove_observer(self)

    end

    def onActionChanged(action)

      if is_action_pick? || is_action_paint_clean?

        @materials_panel.visible = false

      else

        @materials_panel.visible = true

        # Auto filter
        action_filters = fetch_action_filters(action)
        enabled_filters = get_enabled_filters_by_action(action)
        set_filters(false, :selected)
        set_filters(true, :disabled)
        enabled_filters.each do |type|
          set_filter_by_type(type, action_filters.nil? || action_filters[type].nil? ? true : action_filters[type], :selected)
          set_filter_by_type(type, false, :disabled)
        end
        update_filters_ratio

        # Re populate material defs & setup corresponding buttons
        _populate_material_defs(Sketchup.active_model)
        _setup_material_buttons

      end

      case action
      when ACTION_PAINT_PARTS
        set_action_handler(SmartPaintPartsActionHandler.new(self, fetch_action_handler))
      when ACTION_PAINT_EDGES
        set_action_handler(SmartPaintEdgesActionHandler.new(self, fetch_action_handler))
      when ACTION_PAINT_FACES
        set_action_handler(SmartPaintFacesActionHandler.new(self, fetch_action_handler))
      when ACTION_PICK
        set_action_handler(SmartPaintPickActionHandler.new(self, fetch_action_handler))
      when ACTION_PAINT_CLEAN
        set_action_handler(SmartPaintCleanActionHandler.new(self, fetch_action_handler))
      end

      super
    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      if key == VK_LEFT
        button = _get_selected_material_button
        if button && (prev_sibling = button.prev_sibling).is_a?(Kuix::Button)
          prev_sibling.fire(:click, flags)
          return true
        end
      elsif key == VK_RIGHT
        button = _get_selected_material_button
        if button && (next_sibling = button.next_sibling).is_a?(Kuix::Button)
          next_sibling.fire(:click, flags)
          return true
        end
      elsif is_key_alt_or_command?(key)
        push_action(ACTION_PICK) unless is_action_pick?
        return true
      elsif repeat == 1
        if key == Kuix::VK_ADD && is_action_part?
          @materials_add_btn.fire(:click, flags) if @materials_add_btn
          return true
        end
      end
      false
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if is_key_alt_or_command?(key)
        pop_action if is_action_pick?
        return true
      end
      false
    end

    def onMaterialAdd(materials, material)
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
      set_current_material(material, true, true)
    end

    def onMaterialRemove(materials, material)
      begin
        if material == get_current_material
          store_action_material(fetch_action, nil)
        end
      rescue => e # Reference to deleted Entity
        store_action_material(fetch_action, nil)
      end
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
    end

    def onMaterialChange(materials, material)
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
    end

    def onActionOptionStored(action, option_group, option)
      super
      set_root_cursor(get_action_cursor(fetch_action))
    end

    # -----

    private

    def _populate_material_defs(model)

      # Build the material defs
      @material_defs = []
      current_material_exists = false
      model.materials.each do |material|
        material_attributes = MaterialAttributes.new(material)
        if @@filters[material_attributes.type]
          @material_defs.push({
                                :material => material,
                                :material_attributes => material_attributes
                              })
        end
        current_material_exists = current_material_exists || get_current_material.object_id == material.object_id
      end

      # Sort material defs (type > name)
      @material_defs.sort_by! { |material_def| [ MaterialAttributes::type_order(material_def[:material_attributes].type), material_def[:material].display_name ] }

      # Select the default current material if necessary
      if model.materials.length == 0 || fetch_action_material(fetch_action) == false
        set_current_material(false)
      elsif !@material_defs.empty? && (!current_material_exists || fetch_action_material(fetch_action).nil?)
        set_current_material(@material_defs.first[:material])
      end

    end

    def _setup_material_buttons

      @materials_btns_panel.clear

      @material_buttons = []

      btn = NoneButton.new
      btn.layout = Kuix::StaticLayout.new
      btn.min_size.set!(@unit * 20, @unit * 8)
      btn.border.set_all!(@unit)
      btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
      btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE.blend(Kuix::COLOR_BLACK, 0.7), :active)
      btn.set_style_attribute(:border_color, Kuix::COLOR_WHITE)
      btn.set_style_attribute(:border_color, Kuix::COLOR_WHITE.blend(Kuix::COLOR_BLACK, 0.8), :hover)
      btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
      btn.append_static_label(PLUGIN.get_i18n_string('tool.smart_paint.default_material'), @unit * 3 * get_text_unit_factor)
      btn.data = false  # = No material
      btn.selected = get_current_material.nil?
      btn.on(:click) { |button|

        # Set material as current
        set_current_material(false, true)

      }
      @materials_btns_panel.append(btn)
      @material_buttons.push(btn)

      if @material_defs.empty?

        lbl = Kuix::Label.new
        lbl.layout_data = Kuix::GridLayoutData.new(3)
        lbl.text_size = @unit * 3 * get_text_unit_factor
        if is_action_paint_parts?
          lbl.text = PLUGIN.get_i18n_string('tool.smart_paint.warning.no_material')
        elsif is_action_paint_edges?
          lbl.text = PLUGIN.get_i18n_string('tool.smart_paint.warning.no_material_type', { :type => PLUGIN.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_EDGE}") })
        elsif is_action_paint_faces?
          lbl.text = PLUGIN.get_i18n_string('tool.smart_paint.warning.no_material_type', { :type => PLUGIN.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_VENEER}") })
        end
        lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
        @materials_btns_panel.append(lbl)

      end

      @material_defs.each do |material_def|

        material = material_def[:material]
        material_attributes = material_def[:material_attributes]
        material_color = material.color
        material_color.alpha = 255
        material_color_is_dark = ColorUtils::color_is_dark?(material_color)

        btn = Kuix::Button.new
        btn.layout = Kuix::StaticLayout.new
        btn.min_size.set!(@unit * 20, @unit * 8)
        btn.border.set_all!(@unit)
        btn.set_style_attribute(:background_color, material_color)
        btn.set_style_attribute(:background_color, material_color.blend(material_color_is_dark ? Kuix::COLOR_WHITE : Kuix::COLOR_BLACK, 0.7), :active)
        btn.set_style_attribute(:border_color, material_color)
        btn.set_style_attribute(:border_color, material_color.blend(material_color_is_dark ? Kuix::COLOR_WHITE : Kuix::COLOR_BLACK, 0.7), :hover)
        btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
        btn.append_static_label(material.display_name.strip, @unit * 3 * get_text_unit_factor, material_color_is_dark ? Kuix::COLOR_WHITE : nil)
        btn.data = material
        btn.selected = material == get_current_material
        btn.on(:click) { |button|

          # Set material as current
          set_current_material(material, true)

        }
        btn.on(:doubleclick) { |button|

          # Edit material
          PLUGIN.execute_tabs_dialog_command_on_tab('materials', 'edit_material', "{ materialId: #{material.entityID} }")

        }
        btn.on(:enter) { |button|
          show_material_infos(material, material_attributes)
        }
        btn.on(:leave) { |button|
          hide_material_infos
        }
        @materials_btns_panel.append(btn)
        @material_buttons.push(btn)

        if material_attributes.type > MaterialAttributes::TYPE_UNKNOWN

          btn_overlay = Kuix::Panel.new
          btn_overlay.layout_data = Kuix::StaticLayoutData.new(1.0, 0, @unit * 2, @unit * 2, Kuix::Anchor.new(Kuix::Anchor::TOP_RIGHT))
          btn_overlay.set_style_attribute(:background_color, COLOR_MATERIAL_TYPES[material_attributes.type])
          btn_overlay.set_style_attribute(:border_color, Kuix::COLOR_WHITE)
          btn_overlay.border.set_all!(@unit / 4)
          btn_overlay.hittable = false
          btn.append(btn_overlay)

        end

      end

      @materials_btns_panel.set_viewport([[@material_defs.length + 1, 5 ].max, 10 ].min, [((@material_defs.length + 1) / 10.0).ceil, 4 ].min)

    end

    def _get_selected_material_button
      @material_buttons.each { |button|
        return button if button.selected?
      }
      nil
    end

  end

  # -----

  class SmartPaintActionHandler < SmartSelectActionHandler

    STATE_SELECT_FILTER = 8

    LAYER_3D_ACTION_PREVIEW = 3

    # The parts of a rectangle selection sharing a material : their paths,
    # painted or not as the filter dropup ticks them.
    SelectionMaterialEntry = Struct.new(:material_name, :display_name, :color, :type, :paths, :selected)

    # The GroupDef and MaterialAttributes properties GroupDef.group_order
    # reads, to sort the entries as the cut list groups
    SelectionMaterialAttributes = Struct.new(:type)
    SelectionMaterialGroupDef = Struct.new(:material_attributes, :material_name, :std_width, :std_thickness)

    def initialize(action, tool, previous_action_handler = nil)
      super

      @selection_material_entries = nil
      @hovered_selection_material_entry = nil

      # Create 3D layers
      tool.create_3d(LAYER_3D_PART_PREVIEW)
      tool.create_3d(LAYER_3D_ACTION_PREVIEW)

    end

    # -----

    def stop
      @tool.clear_all_3d
      @tool.hide_message
      @tool.remove_tooltip
      super
    end

    # -- STATE --

    def get_state_cursor(state)

      case state

      when STATE_SELECT
        return @tool.get_action_cursor(@action)

      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SELECT_FILTER
        return PLUGIN.get_i18n_string('tool.smart_paint.state_8_status') + '.'

      end

      super
    end

    # -----

    def onToolLButtonDown(tool, flags, x, y, view)
      return true if @state == STATE_SELECT_FILTER  # Handled on button up
      consumed = super
      @mouse_down_point_2d = nil unless _allows_rect_selection?  # No rectangle selection on drag
      _preview_action(true)
      consumed
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      if @state == STATE_SELECT_FILTER
        # A click on a part to paint validates, anywhere else cancels
        if _picked_selection_filter_part?(view, x, y)
          _validate_selection_filter
        else
          _restart
        end
        return true
      end
      UI.beep if @state == STATE_SELECT && !has_active_part?
      super
    end

    def onToolCancel(tool, reason, view)
      if @state == STATE_SELECT_FILTER
        _restart
        return true
      end
      super
    end

    def onToolValidate(tool, view)
      _validate_selection_filter if @state == STATE_SELECT_FILTER
    end

    def onToolReturn(tool, view)
      _validate_selection_filter if @state == STATE_SELECT_FILTER
    end

    def onToolActionOptionStored(tool, action, option_group, option)
      return _preview_selection_filter if @state == STATE_SELECT_FILTER
      _preview_action
    end

    def onToolCurrentMaterialChanged(tool)
      return _preview_selection_filter if @state == STATE_SELECT_FILTER
      _preview_action
    end

    def onStateChanged(old_state, new_state)
      super

      if old_state == STATE_SELECT_FILTER
        @tool.clear_2d(LAYER_2D_FLOATING_TOOLS) # Close the dropup
        @selection_filter_validate_btn = nil
      end

      if new_state == STATE_SELECT_FILTER
        @tool.clear_all_2d
        @tool.clear_all_3d
        _show_selection_filter_dropup
        _preview_selection_filter
      end

    end

    def onToolTransactionUndo(tool, model)
      _restart  # The active part is outdated
    end

    def onToolTransactionRedo(tool, model)
      _restart  # The active part is outdated
    end

    def onPickerChanged(picker, view)
      @previewed = false
      super
      _preview_action unless @previewed  # Already done if the active part changed
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)
      super
      _preview_action(highlighted)
    end

    def onSelected
      if has_active_part?
        _do_action
      elsif has_active_selection? && _allows_rect_selection?
        @selection_material_entries = _get_selection_material_entries
        if @selection_material_entries.empty?
          UI.beep
        elsif @selection_material_entries.size > 1 || @selection_material_entries.any? { |entry| !entry.selected }
          # Several materials, or one not painted by default : let the user choose
          set_state(STATE_SELECT_FILTER)
          return
        else
          _do_selection_action(*_get_selection_part_instances_and_containers)
        end
      end
      _restart
    end

    # -----

    protected

    def _start_with_previous_selection?
      false
    end

    def _start_with_model_selection?
      false
    end

    def _can_activate_locked?
      false
    end

    def _preview_part_mesh?
      false # The action preview draws it
    end

    def _get_part_error_cursor
      SmartCursorManager.cursor_paint_error
    end

    def _pick_part(picker, view)
      if picker.picked_face_path.is_a?(Array)
        if (picked_part_entity_path = _get_part_entity_path_from_path(picker.picked_face_path)).is_a?(Array)
          if (picked_part = _generate_part_from_path(picked_part_entity_path)).is_a?(Part)
            can_activate, error_key, error_vars = _can_activate_part?(picked_part_entity_path, picked_part)
            if can_activate
              _set_active_part(picked_part_entity_path, picked_part)
            else
              _reset_active_part
              @tool.show_tooltip(PLUGIN.get_i18n_string(error_key, error_vars), SmartTool::MESSAGE_TYPE_ERROR) if error_key.is_a?(String)
              @tool.push_cursor(_get_part_error_cursor)
            end
            return
          end
        end
        _reset_active_part
        @tool.show_tooltip("⚠ #{PLUGIN.get_i18n_string('tool.smart_paint.error.not_part')}", SmartTool::MESSAGE_TYPE_ERROR)
        @tool.push_cursor(_get_part_error_cursor)
        return
      end
      _reset_active_part
    end

    # -----

    def _preview_action(highlighted = false)
      @previewed = true
      @tool.clear_3d(LAYER_3D_ACTION_PREVIEW)
      return @tool.hide_message unless has_active_part?
      @tool.pop_to_root_cursor
      _preview_action_draw(highlighted)
    end

    def _preview_action_draw(highlighted)
    end

    def _preview_instances(instances, highlighted, filtered_faces: nil)
      model = Sketchup.active_model

      instance_paths = []
      _instances_to_paths(instances.to_set, instance_paths, model.active_entities, model.active_path.to_a)

      triangles_by_definition = {}

      material = _get_preview_material
      instance_paths.each do |path|

        triangles = triangles_by_definition[path.last.definition] ||= _compute_children_faces_triangles(path.last.definition.entities, filtered_faces: filtered_faces)

        color = material ? material.color : MaterialUtils::get_color_from_path(_get_preview_color_path(path))
        color.alpha = highlighted ? 255 : 200

        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(triangles)
        k_mesh.background_color = color
        k_mesh.transformation = PathUtils::get_transformation(path)
        @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

      end
    end

    def _get_preview_material
      @tool.get_current_material
    end

    # The path the color of an instance path without material comes from
    def _get_preview_color_path(path)
      path[0...-1]
    end

    def _show_shared_definition_warning(definition)
      if definition && definition.count_used_instances > 1
        @tool.show_message("⚠ #{PLUGIN.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.hide_message
      end
    end

    # -----

    # Paints the active part
    def _do_action
    end

    # Paints the parts of the rectangle selection, given their instances and
    # the instances between the selected ones and them
    def _do_selection_action(part_instances, containers)
    end

    def _allows_rect_selection?
      false
    end

    # The instances of the ticked parts of the rectangle selection, and the
    # instances between the selected ones and these parts - the selected ones
    # included.
    def _get_selection_part_instances_and_containers
      selection_path = get_active_selection_path
      part_paths = @selection_material_entries.select(&:selected).map(&:paths).flatten(1).uniq
      [
        part_paths.map(&:last).uniq,
        part_paths.map { |path| path[selection_path.length...-1] }.flatten.uniq
      ]
    end

    # The parts of the rectangle selection, by material, in the cut list
    # groups order. The parts are the cut list ones : a selected group or
    # component can hold several. Only the parts without material and the
    # materials of the applied material type are ticked, or all but the
    # hardware if none is applied.
    def _get_selection_material_entries
      selection_path = get_active_selection_path
      target_material = _get_preview_material
      target_type = target_material ? MaterialAttributes.new(target_material).type : nil
      fn_selected = lambda { |group| group.material_name.empty? || (target_type.nil? ? group.material_type != MaterialAttributes::TYPE_HARDWARE : group.material_type == target_type) }
      cutlist_options = PLUGIN.get_model_preset('cutlist_options')
      entries = {}
      _get_selected_instances.each do |instance|
        worker = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(cutlist_options).merge({ active_entity: instance, active_path: selection_path, part_folding: false }))
        cutlist = worker.run
        cutlist.groups.each do |group|
          entry = entries[group.material_name] ||= SelectionMaterialEntry.new(
            group.material_name,
            group.material_name.empty? ? PLUGIN.get_i18n_string('tab.cutlist.material_undefined') : group.material_display_name,
            group.material_color.nil? ? nil : Sketchup::Color.new(group.material_color),
            group.material_type,
            [],
            fn_selected.call(group)
          )
          group.parts.each { |part| entry.paths.concat(part.def.instance_infos.values.map(&:path)) }
        end
      end
      entries.values.each { |entry| entry.paths.uniq! }

      # Sorted as the cut list groups : each selected instance has its own cut
      # list. An entry is a material, its groups' std dimensions don't apply.
      group_order_strategy = cutlist_options['group_order_strategy']
      fn_group_def = lambda { |entry| SelectionMaterialGroupDef.new(SelectionMaterialAttributes.new(entry.type), entry.material_name) }
      entries.values.sort { |entry_a, entry_b| GroupDef.group_order(fn_group_def.call(entry_a), fn_group_def.call(entry_b), group_order_strategy) }
    end

    # -- Filter --

    def _show_selection_filter_dropup

      k_dropup = SmartDropup.new(
        @tool,
        @selection_material_entries.map { |entry|

          text_defs = [
            SmartDropup::SmartDropupTextDef.new(entry.display_name, Kuix::COLOR_BLACK, true),
            SmartDropup::SmartDropupTextDef.new("(#{entry.paths.size})", Kuix::COLOR_DARK_GREY)
          ]

          on_click = lambda { |k_btn|
            if (k_tick_btn = k_btn.children.find { |child| child.is_a?(Kuix::Button) })
              k_tick_btn.fire(:click)
            end
          }
          on_tick_click = lambda { |k_tick_btn|
            k_tick_btn.selected = entry.selected = !entry.selected
            _preview_selection_filter
          }
          on_enter = lambda { |k_btn|
            @hovered_selection_material_entry = entry
            _preview_selection_filter
          }
          on_leave = lambda { |k_btn|
            @hovered_selection_material_entry = nil
            _preview_selection_filter
          }

          SmartDropup::SmartDropupBtnDef.new(
            text_defs,
            on_click,
            on_enter,
            on_leave,
            0,
            false,
            SmartDropup::SmartDropupTickDef.new(
              entry.selected,
              on_tick_click
            ),
            entry.color.nil? ? Kuix::COLOR_WHITE : entry.color
          )
        },
        nil,
        anchor: @select_rect_points_2d.nil? ? Kuix::Anchor::BOTTOM_RIGHT : SmartDropup.anchor_inside_drag(*@select_rect_points_2d),
        title: PLUGIN.get_i18n_string('tool.smart_paint.select_filter_title'),
        footer_btn_defs: [
          SmartDropup::SmartDropupFooterBtnDef.new(nil, lambda { |k_btn| _restart }, SmartTool::MESSAGE_TYPE_ERROR, false, SmartDropup::MOTIF_CANCEL_PATH),
          SmartDropup::SmartDropupFooterBtnDef.new(nil, lambda { |k_btn| _validate_selection_filter }, SmartTool::MESSAGE_TYPE_SUCCESS, false, SmartDropup::MOTIF_VALIDATE_PATH)
        ]
      )
      @selection_filter_validate_btn = k_dropup.footer_btns.last
      @tool.append_2d(k_dropup, LAYER_2D_FLOATING_TOOLS)

    end

    # Draws the ticked parts as painted - the hovered entry ones opaque.
    def _preview_selection_filter
      @tool.clear_3d(LAYER_3D_ACTION_PREVIEW)
      return if @selection_material_entries.nil?

      material = _get_preview_material
      triangles_by_definition = {}

      @selection_material_entries.select(&:selected).each do |entry|
        hovered = entry == @hovered_selection_material_entry
        entry.paths.each do |path|

          triangles = triangles_by_definition[path.last.definition] ||= _compute_children_faces_triangles(path.last.definition.entities)

          color = material ? material.color : MaterialUtils::get_color_from_path(_get_preview_color_path(path))
          color.alpha = hovered ? 255 : 200

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(triangles)
          k_mesh.background_color = color
          k_mesh.transformation = PathUtils::get_transformation(path)
          @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

        end
      end

      # Nothing to validate without a ticked material
      @selection_filter_validate_btn[:button].disabled = @selection_material_entries.none?(&:selected) unless @selection_filter_validate_btn.nil?

    end

    # Is a ticked part under the given screen point ?
    def _picked_selection_filter_part?(view, x, y)
      instances = @selection_material_entries.select(&:selected).map { |entry| entry.paths.map(&:last) }.flatten.to_set
      ph = view.pick_helper
      ph.do_pick(x, y)
      (0...ph.count).any? { |i| (ph.path_at(i) || []).any? { |entity| instances.include?(entity) } }
    end

    def _validate_selection_filter
      part_instances, containers = _get_selection_part_instances_and_containers
      if part_instances.empty?
        UI.beep
        return
      end
      _do_selection_action(part_instances, containers)
      _restart
    end

    def _paint(operation_name)
      model = Sketchup.active_model
      model.start_operation(operation_name, true, false, false)
      begin

        yield

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

      # Fire event
      PLUGIN.app_observer.model_observer.onDrawingChange

    end

    def _get_selected_instances
      (get_active_selection_instances || []).select { |entity| entity.respond_to?(:definition) }
    end

  end

  class SmartPaintPartsActionHandler < SmartPaintActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartPaintTool::ACTION_PAINT_PARTS, tool, previous_action_handler)
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ↑↓ + ' + PLUGIN.get_i18n_string('tool.default.transparency') + ' = ' + PLUGIN.get_i18n_string('tool.default.toggle_depth') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_1') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_3') + '.'
      end

      super
    end

    protected

    def _preview_action_draw(highlighted)

      part = get_active_part
      material = @tool.get_current_material

      # Show part infos
      @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name ], material && material.name == part.material_name ? SmartTool::MESSAGE_TYPE_SUCCESS : SmartTool::MESSAGE_TYPE_DEFAULT)

      _preview_instances(_get_instances, highlighted)

      if _fetch_option_instances_all
        _show_shared_definition_warning(get_active_part_entity_path.last.definition)
      else
        @tool.hide_message
      end

    end

    def _do_action
      _paint_instances(_get_instances)
    end

    def _do_selection_action(part_instances, containers)
      part_instances = part_instances.map { |instance| instance.definition.instances }.flatten.uniq if _fetch_option_instances_all
      _paint_instances(part_instances)
    end

    def _allows_rect_selection?
      true
    end

    def _paint_instances(instances)
      material = @tool.get_current_material
      _paint('OCL Paint Parts') do
        instances.each { |instance| instance.material = material }
      end
    end

    def _get_instances
      active_instance = get_active_part_entity_path.last
      _fetch_option_instances_all ? active_instance.definition.instances : [ active_instance ]
    end

    # -----

    def _fetch_option_instances_all
      @tool.fetch_action_option_boolean(@action, SmartPaintTool::ACTION_OPTION_INSTANCES, SmartPaintTool::ACTION_OPTION_INSTANCES_ALL)
    end

  end

  # Edges or faces of a sheet good part : its sides
  class SmartPaintSidesActionHandler < SmartPaintActionHandler

    # -----

    protected

    def _can_activate_part?(part_entity_path, part)
      if part.is_a?(Part) && part.group.material_type != MaterialAttributes::TYPE_SHEET_GOOD
        return [ false, 'tool.default.error.wrong_material_type', { :type => PLUGIN.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_SHEET_GOOD}") } ]
      end
      super
    end

    def _can_pick_deeper?
      false
    end

    def _get_preview_color_path(path)
      path
    end

    def _preview_action_draw(highlighted)

      sides, faces = _get_sides_and_faces

      if faces.empty?
        @tool.show_tooltip("⚠ #{PLUGIN.get_i18n_string(_get_no_side_error_key)}", SmartTool::MESSAGE_TYPE_ERROR)
        @tool.push_cursor(SmartCursorManager.cursor_paint_error)
        @tool.hide_message
        return
      end

      material = @tool.get_current_material

      # Show sides infos
      @tool.show_tooltip([
                           "##{_get_active_part_name}",
                           '-',
                           _get_sides_text(sides)
                         ], faces.find { |face| face.material != material }.nil? ? SmartTool::MESSAGE_TYPE_SUCCESS : SmartTool::MESSAGE_TYPE_DEFAULT)

      definition = get_active_part_entity_path.last.definition
      _preview_instances(definition.instances, highlighted, filtered_faces: faces)
      _show_shared_definition_warning(definition)

    end

    def _do_action
      _, faces = _get_sides_and_faces
      return UI.beep if faces.empty?
      material = @tool.get_current_material
      _paint(_get_operation_name) do
        faces.each { |face| face.material = material }
      end
    end

    # -----

    def _get_sides_and_faces
      model = Sketchup.active_model

      side_faces = {}
      _get_side_entity_ids(get_active_part).each { |side, ids| side_faces[side] = model.find_entity_by_id(ids).compact if ids.is_a?(Array) && !ids.empty? }

      sides = _get_sides(side_faces)
      [ sides, sides.map { |side| side_faces[side] }.flatten ]
    end

    def _get_picked_side(side_faces)
      return nil if @picker.nil? || (picked_face = @picker.picked_face).nil?
      side_faces.each { |side, faces| return side if faces.include?(picked_face) }
      nil
    end

    def _get_side_entity_ids(part)  # { side => Array<entity_id> }
      {}
    end

    def _get_sides(side_faces)
      []
    end

    def _get_sides_text(sides)
      ''
    end

    def _get_no_side_error_key
      ''
    end

    def _get_operation_name
      ''
    end

  end

  class SmartPaintEdgesActionHandler < SmartPaintSidesActionHandler

    OPPOSITE_SIDES = { :ymin => :ymax, :ymax => :ymin, :xmin => :xmax, :xmax => :xmin }.freeze

    def initialize(tool, previous_action_handler = nil)
      super(SmartPaintTool::ACTION_PAINT_EDGES, tool, previous_action_handler)
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_2') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_3') + '.'
      end

      super
    end

    protected

    def _get_side_entity_ids(part)
      part.def.edge_entity_ids
    end

    def _get_sides(side_faces)
      sides = []
      if @tool.fetch_action_option_boolean(@action, SmartPaintTool::ACTION_OPTION_EDGES, SmartPaintTool::ACTION_OPTION_EDGES_4)
        [ :ymin, :ymax, :xmin, :xmax ].each { |side| sides << side unless side_faces[side].nil? }
      elsif (picked_side = _get_picked_side(side_faces))
        sides << picked_side
        if @tool.fetch_action_option_boolean(@action, SmartPaintTool::ACTION_OPTION_EDGES, SmartPaintTool::ACTION_OPTION_EDGES_2)
          opposite_side = OPPOSITE_SIDES[picked_side]
          sides << opposite_side unless side_faces[opposite_side].nil?
        end
      end
      sides
    end

    def _get_sides_text(sides)
      PLUGIN.get_i18n_string('tool.smart_paint.edges', { :count => sides.length }) + (sides.length < 4 ? " → #{sides.map { |side| PLUGIN.get_i18n_string("tool.smart_paint.edge_#{side}") }.join(' + ')}" : '')
    end

    def _get_no_side_error_key
      'tool.smart_paint.error.not_edge'
    end

    def _get_operation_name
      'OCL Paint Edges'
    end

  end

  class SmartPaintFacesActionHandler < SmartPaintSidesActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartPaintTool::ACTION_PAINT_FACES, tool, previous_action_handler)
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_3') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_3') + '.'
      end

      super
    end

    protected

    def _get_side_entity_ids(part)
      part.def.face_entity_ids
    end

    def _get_sides(side_faces)
      sides = []
      if @tool.fetch_action_option_boolean(@action, SmartPaintTool::ACTION_OPTION_FACES, SmartPaintTool::ACTION_OPTION_FACES_2)
        [ :zmax, :zmin ].each { |side| sides << side unless side_faces[side].nil? }
      elsif (picked_side = _get_picked_side(side_faces))
        sides << picked_side
      end
      sides
    end

    def _get_sides_text(sides)
      "#{PLUGIN.get_i18n_string('tool.smart_paint.faces', { :count => sides.length })} → #{sides.map { |side| PLUGIN.get_i18n_string("tool.smart_paint.face_#{side}") }.join(' + ')}"
    end

    def _get_no_side_error_key
      'tool.smart_paint.error.not_face'
    end

    def _get_operation_name
      'OCL Paint Faces'
    end

  end

  class SmartPaintPickActionHandler < SmartActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartPaintTool::ACTION_PICK, tool, previous_action_handler)
    end

    # -----

    def stop
      @tool.remove_tooltip
      super
    end

    # -- STATE --

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, lockable: false)
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_4') + '.'
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)
      if @picker.nil? || @picker.picked_face.nil?
        UI.beep # Feedback for "no material"
        return true
      end

      # Set picked material as current
      material = MaterialUtils::get_material_from_path(@picker.picked_face_path)
      @tool.set_current_material(material.nil? ? false : material, true, true)

      true
    end

    def onPickerChanged(picker, view)

      if picker.picked_face

        # Display material infos
        material = MaterialUtils::get_material_from_path(picker.picked_face_path)
        if material
          @tool.show_tooltip("##{material.name} (#{PLUGIN.get_i18n_string("tab.materials.type_#{MaterialAttributes.new(material).type}")})")
        else
          @tool.show_tooltip("##{PLUGIN.get_i18n_string('tool.smart_paint.default_material')}")
        end

      else
        @tool.remove_tooltip
      end

      super
    end

  end

  class SmartPaintCleanActionHandler < SmartPaintActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartPaintTool::ACTION_PAINT_CLEAN, tool, previous_action_handler)
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ↑↓ + ' + PLUGIN.get_i18n_string('tool.default.transparency') + ' = ' + PLUGIN.get_i18n_string('tool.default.toggle_depth') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_0') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_paint.action_3') + '.'
      end

      super
    end

    protected

    def _preview_action_draw(highlighted)

      # Show part infos
      @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name ])

      definition = get_active_part_entity_path.last.definition
      _preview_instances(definition.instances, highlighted)
      _show_shared_definition_warning(definition)

    end

    def _get_preview_material
      nil
    end

    def _do_action
      _clean_definitions([ get_active_part_entity_path.last.definition ])
    end

    def _do_selection_action(part_instances, containers)
      _clean_definitions(part_instances.map(&:definition).uniq, containers)
    end

    def _allows_rect_selection?
      true
    end

    def _clean_definitions(definitions, containers = [])
      _paint('OCL Paint Clean') do

        # Clean the containers : the parts would inherit their material
        containers.each { |container| container.material = nil }

        definitions.each do |definition|

          # Clean definition
          _propagate_material(definition.entities, nil)

          # Clean instances
          definition.instances.each { |instance| instance.material = nil }

        end
      end
    end

    def _propagate_material(entities, material = nil)
      entities.each do |entity|
        next if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        if entity.is_a?(Sketchup::Drawingelement)
          entity.material = material
          entity.back_material = material if entity.respond_to?(:back_material)
          if material.nil? && entity.respond_to?(:clear_texture_position)
            entity.clear_texture_position(true) # Clear texture position is possible (entity is a Face and SU 2022+)
          end
        end
        if entity.is_a?(Sketchup::Group)
          _propagate_material(entity.entities, material)
        end
        if entity.is_a?(Sketchup::ComponentInstance)
          _propagate_material(entity.definition.entities, material)
        end
      end
    end

  end

  class NoneButton < Kuix::Button

    def paint_background(graphics)
      super

      width = @bounds.width - @margin.left - @border.left - @margin.right - @border.right
      height = @bounds.height - @margin.top - @border.top - @margin.bottom - @border.bottom

      graphics.draw_triangle(
        x1: 0,
        y1: 0,
        x2: 0,
        y2: height,
        x3: width,
        y3: height,
        fill_color: @background_color.blend(Sketchup::Color.new(0, 0, 0), 0.9)
      )
    end

  end

end
