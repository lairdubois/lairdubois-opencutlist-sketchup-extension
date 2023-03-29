module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/kuix'
  require_relative '../utils/path_utils'
  require_relative '../utils/color_utils'
  require_relative '../utils/material_utils'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../model/attributes/material_attributes'
  require_relative '../worker/cutlist/cutlist_generate_worker'

  class SmartPaintTool < SmartTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper

    ACTION_PAINT_FACE = 0
    ACTION_PAINT_PART = 1
    ACTION_UNPAINT_FACE = 2
    ACTION_UNPAINT_PART = 3
    ACTION_PICK = 4
    ACTION_PAINT_EDGE = 5
    ACTION_PAINT_VENEER = 6

    ACTION_MODIFIER_0 = 0
    ACTION_MODIFIER_1 = 1
    ACTION_MODIFIER_2 = 2
    ACTION_MODIFIER_4 = 3

    ACTIONS = [
      { :action => ACTION_PAINT_PART },
      { :action => ACTION_PAINT_EDGE, :modifiers => [ ACTION_MODIFIER_1, ACTION_MODIFIER_2, ACTION_MODIFIER_4 ] },
      { :action => ACTION_PAINT_VENEER, :modifiers => [ ACTION_MODIFIER_1, ACTION_MODIFIER_2 ] },
      # { :action => ACTION_PAINT_FACE },
      # { :action => ACTION_UNPAINT_FACE },
      # { :action => ACTION_UNPAINT_PART },
      # { :action => ACTION_PICK }
    ].freeze

    COLOR_MATERIAL_TYPES = {
      MaterialAttributes::TYPE_UNKNOWN => Sketchup::Color.new(128, 128, 128).freeze,
      MaterialAttributes::TYPE_SOLID_WOOD => Sketchup::Color.new(76, 175, 80).freeze,
      MaterialAttributes::TYPE_SHEET_GOOD => Sketchup::Color.new(237, 162, 0).freeze,
      MaterialAttributes::TYPE_DIMENSIONAL => Sketchup::Color.new(245, 89, 172).freeze,
      MaterialAttributes::TYPE_EDGE => Sketchup::Color.new(102, 142, 238).freeze,
      MaterialAttributes::TYPE_VENEER => Sketchup::Color.new(131, 56, 236).freeze,
      MaterialAttributes::TYPE_HARDWARE => Sketchup::Color.new(0, 0, 0).freeze
    }

    @@action = nil
    @@action_modifiers = {} # { action => MODIFIER }

    @@action_materials = {} # { action => Sketchup::Material }
    @@action_filters = {}   # { action => MaterialAttributes:TYPE }

    @@filters = nil

    def initialize(material = nil)
      super(true, false)

      # Keep the given material
      @startup_material = material

      # Setup default filter if not set
      if @@filters.nil?
        @@filters = {}
        for type in 0..COLOR_MATERIAL_TYPES.length - 1
          @@filters[type] = type != MaterialAttributes::TYPE_UNKNOWN
        end
      end

      @paint_down_color = nil
      @paint_hover_color = nil
      @unpaint_color = nil

      # Create cursors
      @cursor_paint_face_id = create_cursor('paint-face', 7, 25)
      @cursor_paint_part_id = create_cursor('paint-part', 7, 25)
      @cursor_unpaint_id = create_cursor('unpaint', 7, 25)
      @cursor_picker_id = create_cursor('picker', 7, 25)
      @cursor_nopaint_id = create_cursor('nopaint', 7, 25)

    end

    def get_stripped_name
      'paint'
    end

    def setup_entities(view)
      super

      panel_south = Kuix::Panel.new
      panel_south.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      panel_south.layout = Kuix::BorderLayout.new
      @canvas.append(panel_south)

      # Status panel

      @status = Kuix::Panel.new
      @status.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
      @status.layout = Kuix::InlineLayout.new(true, @unit, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      @status.padding.set_all!(@unit * 2)
      @status.visible = false
      @status.set_style_attribute(:background_color, Sketchup::Color.new(255, 255, 255, 128))
      panel_south.append(@status)

      @status_lbl_1 = Kuix::Label.new
      @status_lbl_1.text_size = @unit * 3
      @status_lbl_1.text_bold = true
      @status.append(@status_lbl_1)

      @status_lbl_2 = Kuix::Label.new
      @status_lbl_2.text_size = @unit * 3
      @status.append(@status_lbl_2)

      # Settings panel

      @settings = Kuix::Panel.new
      @settings.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      @settings.layout = Kuix::GridLayout.new
      @settings.padding.set_all!(@unit * 2)
      @settings.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      @settings.visible = false
      panel_south.append(@settings)

      filters = Kuix::Panel.new
      filters.layout = Kuix::GridLayout.new(COLOR_MATERIAL_TYPES.length + 1,1, @unit, @unit)
      @settings.append(filters)

      filters_lbl = Kuix::Label.new
      filters_lbl.text = Plugin.instance.get_i18n_string('tool.smart_paint.filters').upcase
      filters_lbl.text_size = @unit * 3
      filters_lbl.text_bold = true
      filters.append(filters_lbl)

      @filter_buttons = []
      COLOR_MATERIAL_TYPES.each do |type, color|

        filters_btn = Kuix::Button.new
        filters_btn.min_size.set_all!(@unit * 8)
        filters_btn.border.set_all!(@unit / 2)
        filters_btn.set_style_attribute(:background_color, Sketchup::Color.new(220, 220, 220))
        filters_btn.set_style_attribute(:background_color, color, :active)
        filters_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'), :selected)
        filters_btn.set_style_attribute(:background_color, color.blend(Sketchup::Color.new('white'), 0.2), :hover)
        filters_btn.set_style_attribute(:border_color, color, :selected)
        filters_btn.selected = @@filters[type]
        filters_btn.data = type
        filters_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_paint.filter_#{type}"), @unit * 3)
        filters_btn.on(:click) { |button|

          unless get_enabled_filters_by_action(fetch_action).index(button.data).nil?

            toggle_filter_by_type(button.data)

            # Re populate material defs & setup corresponding buttons
            _populate_material_defs(view.model)
            _setup_material_buttons

          end

        }
        filters_btn.on(:doubleclick) { |button|

          unless get_enabled_filters_by_action(fetch_action).index(button.data).nil?

            set_filters(false)
            set_filter_by_type(button.data, true)

            # Re populate material defs & setup corresponding buttons
            _populate_material_defs(view.model)
            _setup_material_buttons

          end

        }
        filters.append(filters_btn)

        @filter_buttons.push(filters_btn)

      end

      west = Kuix::Panel.new
      west.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
      west.layout = Kuix::GridLayout.new
      west.padding.set!(0, @unit / 2, 0, 0)
      west.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
      panel_south.append(west)

      west_btn = Kuix::Button.new
      west_btn.layout = Kuix::GridLayout.new
      west_btn.min_size.set_all!(@unit * 10)
      west_btn.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
      west_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205), :hover)
      west_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205), :active)
      lbl = west_btn.append_static_label('⬆', @unit * 5)
      lbl.set_style_attribute(:color, Sketchup::Color.new(214, 212, 205))
      lbl.set_style_attribute(:color, Sketchup::Color.new(62, 59, 51), :hover)
      lbl.set_style_attribute(:color, Sketchup::Color.new(255, 255, 255), :selected)
      west_btn.on(:click) { |button|
        @settings.visible = !@settings.visible?
        west_btn.child.text = @settings.visible? ? '⬇' : '⬆'
      }
      west.append(west_btn)
      @open_btn = west_btn

      east = Kuix::Panel.new
      east.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
      east.layout = Kuix::GridLayout.new
      east.padding.set!(0, 0, 0, @unit / 2)
      east.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
      panel_south.append(east)

      east_btn = Kuix::Button.new
      east_btn.layout = Kuix::GridLayout.new
      east_btn.min_size.set_all!(@unit * 10)
      east_btn.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
      east_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205), :hover)
      east_btn.set_style_attribute(:background_color, Sketchup::Color.new(214, 212, 205), :active)
      lbl = east_btn.append_static_label('+', @unit * 5)
      lbl.set_style_attribute(:color, Sketchup::Color.new(214, 212, 205))
      lbl.set_style_attribute(:color, Sketchup::Color.new(62, 59, 51), :hover)
      lbl.set_style_attribute(:color, Sketchup::Color.new(255, 255, 255), :selected)
      east_btn.on(:click) { |button|
        Plugin.instance.execute_dialog_command_on_tab('materials', 'new_material')
      }
      east.append(east_btn)
      @add_btn = east_btn

      # Buttons panel

      @btns = Kuix::Panel.new
      @btns.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      @btns.padding.set!(@unit, 0, @unit, 0)
      @btns.set_style_attribute(:background_color, Sketchup::Color.new(62, 59, 51))
      panel_south.append(@btns)

      # _setup_material_buttons

    end

    # -- Setters --

    def set_status(text_1, text_2 = '')
      return unless @status && text_1.is_a?(String) && text_2.is_a?(String)
      @status_lbl_1.text = text_1
      @status_lbl_1.visible = !text_1.empty?
      @status_lbl_2.text = text_2
      @status_lbl_2.visible = !text_2.empty?
      @status.visible = @status_lbl_1.visible? || @status_lbl_2.visible?
    end

    def set_status_material(material, material_attributes)
      set_status(material.display_name, material_attributes.type > 0 ? "(#{Plugin.instance.get_i18n_string("tab.materials.type_#{material_attributes.type}")})" : '')
    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      ACTIONS
    end

    def store_action(action)
      @@action = action
    end

    def fetch_action
      @@action
    end

    def store_action_modifier(action, modifier)
      @@action_modifiers[action] = modifier
    end

    def fetch_action_modifier(action)
      @@action_modifiers[action]
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
      if @startup_material.nil?
        super
      else
        case MaterialAttributes.new(@startup_material).type
        when MaterialAttributes::TYPE_EDGE
          startup_action = ACTION_PAINT_EDGE
        when MaterialAttributes::TYPE_VENEER
          startup_action = ACTION_PAINT_VENEER
        else
          startup_action = ACTION_PAINT_PART
        end
        store_action_material(startup_action, @startup_material)
        startup_action
      end
    end

    def is_action_face?
      fetch_action == ACTION_PAINT_FACE || fetch_action == ACTION_UNPAINT_FACE
    end

    def is_action_part?
      fetch_action == ACTION_PAINT_PART || fetch_action == ACTION_PAINT_EDGE || fetch_action == ACTION_PAINT_VENEER || fetch_action == ACTION_UNPAINT_PART
    end

    def is_action_paint?
      fetch_action == ACTION_PAINT_FACE || fetch_action == ACTION_PAINT_PART || fetch_action == ACTION_PAINT_EDGE || fetch_action == ACTION_PAINT_VENEER
    end

    def is_action_paint_edge?
      fetch_action == ACTION_PAINT_EDGE
    end

    def is_action_paint_veneer?
      fetch_action == ACTION_PAINT_VENEER
    end

    def is_action_unpaint?
      fetch_action == ACTION_UNPAINT_FACE || fetch_action == ACTION_UNPAINT_PART
    end

    def is_action_pick?
      fetch_action == ACTION_PICK
    end

    def is_action_modifier_1?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_1
    end

    def is_action_modifier_2?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_2
    end

    def is_action_modifier_4?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_4
    end

    # -- Filters --

    def get_enabled_filters_by_action(action)

      case action
      when ACTION_PAINT_PART
        [
          MaterialAttributes::TYPE_SOLID_WOOD,
          MaterialAttributes::TYPE_SHEET_GOOD,
          MaterialAttributes::TYPE_DIMENSIONAL,
          MaterialAttributes::TYPE_HARDWARE,
        ]
      when ACTION_PAINT_EDGE
        [
          MaterialAttributes::TYPE_EDGE
        ]
      when ACTION_PAINT_VENEER
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

    def set_filters(value = true)

      @@filters.keys.each do |type|
        set_filter_by_type(type, value)
      end

    end

    def set_filter_by_type(type, value)

      @@filters[type] = value

      if @filter_buttons
        @filter_buttons.each { |button|
          if button.data == type
            button.selected = value
          end
        }
      end

    end

    def toggle_filter_by_type(type)
      set_filter_by_type(type, !@@filters[type])
    end

    def set_current_material(material, update_buttons = false)

      # Save material as current
      store_action_material(fetch_action, material)

      # Update the paint color
      @paint_down_color = material ? material.color.blend(Sketchup::Color.new(ColorUtils::color_is_dark?(material.color) ? 'white' : 'black'), 0.85) : nil
      @paint_hover_color = material ? material.color : nil

      # Update buttons
      if update_buttons
        @material_buttons.each { |button|
          button.selected = button.data == material
        }
      end

    end

    def get_current_material
      fetch_action_material(fetch_action)
    end

    # -- Tool stuff --

    def draw(view)

      if is_action_paint?
        color = @is_down ? @paint_down_color : @paint_hover_color
      elsif is_action_unpaint?
        color = @unpaint_color
      else
        color = nil
      end
      if color && @triangles
        view.drawing_color = color
        view.draw(GL_TRIANGLES, @triangles)
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super

      # Force global current material to be valid
      unless get_current_material.nil?
        begin
          get_current_material.model == model
        rescue => e # Reference to deleted Entity
          store_action_material(fetch_action, nil)
        end
      end

      # Observe materials events
      view.model.materials.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing materials events
      view.model.materials.remove_observer(self)

    end

    def onActionChange(action, modifier)

      # Auto filter

      enabled_filters = get_enabled_filters_by_action(action)
      set_filters(false)
      enabled_filters.each { |type| set_filter_by_type(type, true) }

      # Re populate material defs & setup corresponding buttons
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons

      # Update status text and root cursor
      case action
      when ACTION_PAINT_FACE
        Sketchup.set_status_text(
          Plugin.instance.get_i18n_string('tool.smart_paint.status_paint_face') +
            ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.status_unpaint_face') +
            ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.status_pick'),
          SB_PROMPT)
        set_root_cursor(@cursor_paint_face_id)
      when ACTION_PAINT_PART
        Sketchup.set_status_text(
          Plugin.instance.get_i18n_string('tool.smart_paint.status_paint_part') +
            ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.status_unpaint_part') +
            ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_paint.status_pick'),
          SB_PROMPT)
        set_root_cursor(@cursor_paint_part_id)
      when ACTION_PAINT_EDGE
        set_root_cursor(@cursor_paint_part_id)
      when ACTION_PAINT_VENEER
        set_root_cursor(@cursor_paint_part_id)
      when ACTION_UNPAINT_FACE
        Sketchup.set_status_text(Plugin.instance.get_i18n_string('tool.smart_paint.status_unpaint_face'), SB_PROMPT)
        set_root_cursor(@cursor_unpaint_id)
      when ACTION_UNPAINT_PART
        Sketchup.set_status_text(Plugin.instance.get_i18n_string('tool.smart_paint.status_unpaint_part'), SB_PROMPT)
        set_root_cursor(@cursor_unpaint_id)
      when ACTION_PICK
        Sketchup.set_status_text(Plugin.instance.get_i18n_string('tool.smart_paint.status_pick'), SB_PROMPT)
        set_root_cursor(@cursor_picker_id)
      else
        Sketchup.set_status_text('', SB_PROMPT)
        set_root_cursor(@cursor_nopaint_id)
      end

    end

    def onKeyDown(key, repeat, flags, view)
      return if super
      if key == COPY_MODIFIER_KEY
        set_action(is_action_face? ? ACTION_UNPAINT_FACE : ACTION_UNPAINT_PART)
        view.invalidate
      elsif key == ALT_MODIFIER_KEY
        @picked_path = nil
        set_action(ACTION_PICK)
        view.invalidate
      elsif key == VK_LEFT
        button = _get_selected_material_button
        if button && button.previous
          button.previous.fire(:click, flags)
        end
      elsif key == VK_RIGHT
        button = _get_selected_material_button
        if button && button.next
          button.next.fire(:click, flags)
        end
      elsif key == VK_UP
        @open_btn.fire(:click, flags) if @open_btn
      elsif key == VK_DOWN
        @open_btn.fire(:click, flags) if @open_btn
      end
    end

    def onKeyUp(key, repeat, flags, view)
      return if super
      if key == COPY_MODIFIER_KEY || key == ALT_MODIFIER_KEY
        set_current_material(get_current_material)
        view.invalidate
      end
    end

    def onLButtonDown(flags, x, y, view)
      return if super
      unless is_action_none?
        @is_down = true
        _handle_mouse_event(x, y, view, :l_button_down)
      end
    end

    def onLButtonUp(flags, x, y, view)
      return if super
      unless is_action_none?
        @is_down = false
        _handle_mouse_event(x, y, view, :l_button_up)
      end
    end

    def onMouseMove(flags, x, y, view)
      return if super
      unless is_action_none?
        _handle_mouse_event(x, y, view, :move)
      end
    end

    def onMouseLeave(view)
      return if super
      _reset(view)
    end

    def onMaterialAdd(materials, material)
      _populate_material_defs(Sketchup.active_model)
      _setup_material_buttons
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
          if get_current_material.nil? && material == model.materials.current
            store_action_material(fetch_action, material)
          end
        end
        current_material_exists = current_material_exists || get_current_material == material
      end

      # Sort material defs (type > name)
      @material_defs.sort_by! { |material_def| [ MaterialAttributes::type_order(material_def[:material_attributes].type), material_def[:material].display_name ] }

      # Select default current material if necessary
      if model.materials.length == 0 || get_current_material.nil?
        set_current_material(nil)
      elsif !@material_defs.empty? && (get_current_material && !current_material_exists)
        set_current_material(@material_defs.first[:material])
      else
        set_current_material(get_current_material)  # Reapply current material to setup the paint color
      end

    end

    def _setup_material_buttons

      @btns.remove_all
      @btns.layout = Kuix::GridLayout.new([ [ @material_defs.length + 1, 5 ].max, 10 ].min, ((@material_defs.length + 1) / 10.0).ceil)

      @material_buttons = []

      btn = Kuix::Button.new
      btn.layout = Kuix::StaticLayout.new
      btn.min_size.set!(@unit * 20, @unit * 8)
      btn.border.set_all!(@unit)
      btn.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      btn.set_style_attribute(:background_color, Sketchup::Color.new('white').blend(Sketchup::Color.new('black'), 0.7), :active)
      btn.set_style_attribute(:border_color, Sketchup::Color.new('white').blend(Sketchup::Color.new('black'), 0.8), :hover)
      btn.set_style_attribute(:border_color, Sketchup::Color.new(220, 220, 220), :selected)
      btn.append_static_label('NONE', @unit * 3)
      btn.data = nil
      btn.selected = get_current_material.nil?
      btn.on(:click) { |button|

        # Set material as current
        set_current_material(nil, true)

      }
      @btns.append(btn)
      @material_buttons.push(btn)

      @material_defs.each do |material_def|

        material = material_def[:material]
        material_attributes = material_def[:material_attributes]
        material_color_is_dark = ColorUtils::color_is_dark?(material.color)

        btn = Kuix::Button.new
        btn.layout = Kuix::StaticLayout.new
        btn.min_size.set!(@unit * 20, @unit * 8)
        btn.border.set_all!(@unit)
        btn.set_style_attribute(:background_color, material.color)
        btn.set_style_attribute(:background_color, material.color.blend(Sketchup::Color.new(material_color_is_dark ? 'white' : 'black'), 0.7), :active)
        btn.set_style_attribute(:border_color, material.color.blend(Sketchup::Color.new(material_color_is_dark ? 'white' : 'black'), 0.8), :hover)
        btn.set_style_attribute(:border_color, Sketchup::Color.new('white'), :selected)
        btn.append_static_label(material.display_name, @unit * 3, material_color_is_dark ? Sketchup::Color.new('white') : nil)
        btn.data = material
        btn.selected = material == get_current_material
        btn.on(:click) { |button|

          # Set material as current
          set_current_material(material, true)

        }
        btn.on(:enter) { |button|
          set_status_material(material, material_attributes)
        }
        btn.on(:leave) { |button|
          set_status('')
        }
        @btns.append(btn)
        @material_buttons.push(btn)

        if material_attributes.type > MaterialAttributes::TYPE_UNKNOWN

          btn_overlay = Kuix::Panel.new
          btn_overlay.layout_data = Kuix::StaticLayoutData.new(1.0, 0, @unit * 2, @unit * 2, Kuix::Anchor.new(Kuix::Anchor::TOP_RIGHT))
          btn_overlay.set_style_attribute(:background_color, COLOR_MATERIAL_TYPES[material_attributes.type])
          btn_overlay.set_style_attribute(:border_color, Sketchup::Color.new('white'))
          btn_overlay.border.set!(0, 0, @unit / 2, @unit / 2)
          btn_overlay.hittable = false
          btn.append(btn_overlay)

        end

      end

    end

    def _get_selected_material_button
      @material_buttons.each { |button|
        return button if button.selected?
      }
      nil
    end

    def _reset(view)
      super
      if @picked_path
        set_status('')
        @is_down = false
        @picked_path = nil
        @triangles = nil
        @space.remove_all
        view.invalidate
      end
    end

    def _handle_mouse_event(x, y, view, event = nil)
      if @pick_helper.do_pick(x, y) > 0
        @pick_helper.count.times { |pick_path_index|

          picked_path = @pick_helper.path_at(pick_path_index)
          # if picked_path == @picked_path && event == :move
          #   return  # Previously detected path, stop process to optimize.
          # end
          if picked_path && picked_path.last.is_a?(Sketchup::Face)

            @picked_path = picked_path.clone

            if is_action_face?

              picked_face = picked_path.last

              @unpaint_color = MaterialUtils::get_color_from_path(picked_path[0...-1]) # [0...-1] returns array without last element
              @triangles = _compute_face_triangles(picked_face, PathUtils::get_transformation(picked_path))

              if event == :l_button_up
                if is_action_paint?
                  picked_face.material = get_current_material
                elsif is_action_unpaint?
                  picked_face.material = nil
                end
              end

              view.invalidate
              return

            elsif is_action_part?

              picked_entity_path = _get_part_entity_path_from_path(picked_path)
              if picked_entity_path.length > 0

                part = _compute_part_from_path(picked_entity_path)
                if part

                  set_message(part.name)

                  @space.remove_all

                  if is_action_paint_edge?

                    if part.group.material_type != MaterialAttributes::TYPE_SHEET_GOOD
                      _reset(view)
                      set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.wrong_material_type', { :type => Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_SHEET_GOOD}") })}", MESSAGE_TYPE_ERROR)
                    else

                      model = Sketchup.active_model
                      edge_faces = {}
                      part.def.edge_entity_ids.each { |k, v| edge_faces[k] = model.find_entity_by_id(v) if v.is_a?(Array) && !v.empty? }

                      entities = []
                      if is_action_modifier_1? || is_action_modifier_2?

                        picked_face = @pick_helper.picked_face

                        side = nil
                        edge_faces.each { |k, v|
                          v.each { |face|
                            if face == picked_face
                              side = k
                              break
                            end
                          }
                          break unless side.nil?
                        }

                        if side
                          entities << edge_faces[side]
                          if is_action_modifier_2?
                            entities << edge_faces[:xmin] if side == :xmax
                            entities << edge_faces[:xmax] if side == :xmin
                            entities << edge_faces[:ymin] if side == :ymax
                            entities << edge_faces[:ymax] if side == :ymin
                          end
                        end

                      elsif is_action_modifier_4?
                        entities << edge_faces[:xmin]
                        entities << edge_faces[:xmax]
                        entities << edge_faces[:ymin]
                        entities << edge_faces[:ymax]
                      end
                      entities = entities.compact.flatten

                      if entities.empty?
                        set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_edge')}", MESSAGE_TYPE_ERROR)
                      else

                        current_material = get_current_material
                        color = current_material ? current_material.color : MaterialUtils::get_color_from_path(picked_entity_path)
                        color.alpha = 180

                        mesh = Kuix::Mesh.new
                        mesh.add_trangles(_compute_children_faces_triangles(entities))
                        mesh.background_color = color
                        mesh.transformation = PathUtils::get_transformation(picked_entity_path)
                        @space.append(mesh)

                        definition = Sketchup.active_model.definitions[part.def.definition_id]
                        if definition && definition.count_used_instances > 1
                          set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
                        else
                          set_message('')
                        end

                        if event == :l_button_up
                          entities.each { |face| face.material = get_current_material }
                        end

                      end

                    end

                  elsif is_action_paint_veneer?

                    if part.group.material_type != MaterialAttributes::TYPE_SHEET_GOOD
                      _reset(view)
                      set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.wrong_material_type', { :type => Plugin.instance.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_SHEET_GOOD}") })}", MESSAGE_TYPE_ERROR)
                    else

                      model = Sketchup.active_model
                      veneer_faces = {}
                      part.def.veneer_entity_ids.each { |k, v| veneer_faces[k] = model.find_entity_by_id(v) if v.is_a?(Array) && !v.empty? }

                      entities = []
                      if is_action_modifier_1?

                        picked_face = @pick_helper.picked_face

                        side = nil
                        veneer_faces.each { |k, v|
                          v.each { |face|
                            if face == picked_face
                              side = k
                              break
                            end
                          }
                          break unless side.nil?
                        }

                        if side
                          entities << veneer_faces[side]
                        end

                      elsif is_action_modifier_2?
                        entities << veneer_faces[:zmin]
                        entities << veneer_faces[:zmax]
                      end
                      entities = entities.compact.flatten

                      if entities.empty?
                        set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_veneer')}", MESSAGE_TYPE_ERROR)
                      else

                        current_material = get_current_material
                        color = current_material ? current_material.color : MaterialUtils::get_color_from_path(picked_entity_path)
                        color.alpha = 180

                        mesh = Kuix::Mesh.new
                        mesh.add_trangles(_compute_children_faces_triangles(entities))
                        mesh.background_color = color
                        mesh.transformation = PathUtils::get_transformation(picked_entity_path)
                        @space.append(mesh)

                        definition = Sketchup.active_model.definitions[part.def.definition_id]
                        if definition && definition.count_used_instances > 1
                          set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
                        else
                          set_message('')
                        end

                        if event == :l_button_up
                          entities.each { |face| face.material = get_current_material }
                        end

                      end

                    end

                  else

                    current_material = get_current_material
                    color = current_material ? current_material.color : MaterialUtils::get_color_from_path(picked_entity_path[0...-1]) # [0...-1] returns array without last element
                    color.alpha = 180

                    mesh = Kuix::Mesh.new
                    mesh.add_trangles(_compute_children_faces_triangles(picked_entity_path.last.definition.entities))
                    mesh.background_color = color
                    mesh.transformation = PathUtils::get_transformation(picked_entity_path)
                    @space.append(mesh)

                    if event == :l_button_up
                      picked_entity_path.last.material = get_current_material
                    end

                  end

                else
                  _reset(view)
                  set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", MESSAGE_TYPE_ERROR)
                end
                return

              elsif picked_entity_path
                _reset(view)
                set_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", MESSAGE_TYPE_ERROR)
                return
              end

            elsif is_action_pick?

              material = MaterialUtils::get_material_from_path(picked_path)
              if material
                if event == :move

                  # Display material infos
                  set_status_material(material, MaterialAttributes.new(material))

                elsif event == :l_button_up

                  # Set picked material as current (and switch to paint action)
                  set_current_material(material, true)

                  return
                end
              else
                if event == :move

                  # Reset status
                  set_status('')

                elsif event == :l_button_up

                  UI.beep # Feedback for "no material"

                end
              end

              @unpaint_color = nil
              @triangles = nil
              return

            end

          end

        }
      end
      _reset(view)
      UI.beep if event == :l_button_up
    end

    def _get_part_path_from_path(path)
      part_path = path.to_a
      path.reverse_each { |entity|
        return part_path if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        part_path.pop
      }
    end

  end

end
