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

    ACTION_MODIFIER_1 = 0
    ACTION_MODIFIER_2 = 1
    ACTION_MODIFIER_4 = 2

    ACTIONS = [
      { :action => ACTION_PAINT_PART },
      # { :action => ACTION_PAINT_EDGE, :modifiers => [ ACTION_MODIFIER_1, ACTION_MODIFIER_2, ACTION_MODIFIER_4 ] },
      # { :action => ACTION_PAINT_VENEER, :modifiers => [ ACTION_MODIFIER_1, ACTION_MODIFIER_2 ] },
      { :action => ACTION_PAINT_FACE },
      { :action => ACTION_UNPAINT_FACE },
      { :action => ACTION_UNPAINT_PART },
      { :action => ACTION_PICK }
    ].freeze

    COLOR_MATERIAL_TYPES = {
      MaterialAttributes::TYPE_UNKNOWN => Sketchup::Color.new(128, 128, 128, 255).freeze,
      MaterialAttributes::TYPE_SOLID_WOOD => Sketchup::Color.new(76, 175, 80, 255).freeze,
      MaterialAttributes::TYPE_SHEET_GOOD => Sketchup::Color.new(237, 162, 0, 255).freeze,
      MaterialAttributes::TYPE_DIMENSIONAL => Sketchup::Color.new(245, 89, 172, 255).freeze,
      MaterialAttributes::TYPE_EDGE => Sketchup::Color.new(102, 142, 238, 255).freeze,
      MaterialAttributes::TYPE_VENEER => Sketchup::Color.new(131, 56, 236, 255).freeze,
      MaterialAttributes::TYPE_HARDWARE => Sketchup::Color.new(0, 0, 0, 255).freeze
    }

    @@current_material = nil
    @@filters = nil
    @@action = nil

    def initialize(material = nil)
      super(true, false)

      model = Sketchup.active_model
      if model

        # Try to use given material
        @@current_material = material if material

        # Force global current material to be valid
        unless @@current_material.nil?
          begin
            @@current_material.model == model
          rescue => e # Reference to deleted Entity
            @@current_material = nil
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
      @status.append(@status_lbl_1)

      @status_lbl_2 = Kuix::Label.new
      @status_lbl_2.text_size = @unit * 2
      @status.append(@status_lbl_2)

      # Settings panel

      @settings = Kuix::Panel.new
      @settings.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::SOUTH)
      @settings.layout = Kuix::GridLayout.new
      @settings.border.set!(@unit / 2)
      @settings.padding.set_all!(@unit * 2)
      @settings.set_style_attribute(:background_color, Sketchup::Color.new('white'))
      @settings.set_style_attribute(:border_color, Sketchup::Color.new(200, 200, 200, 255))
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
        filters_btn.set_style_attribute(:background_color, Sketchup::Color.new('white'))
        filters_btn.set_style_attribute(:background_color, color, :active)
        filters_btn.set_style_attribute(:background_color, color.blend(Sketchup::Color.new('white'), 0.2), :hover)
        filters_btn.set_style_attribute(:border_color, color, :selected)
        filters_btn.selected = @@filters[type]
        filters_btn.data = type
        filters_btn.append_static_label(Plugin.instance.get_i18n_string("tool.smart_paint.filter_#{type}"), @unit * 3)
        filters_btn.on(:click) { |button|

          toggle_filter_by_type(button.data)

          # Re populate material defs & setup corresponding buttons
          _populate_material_defs(view.model)
          _setup_material_buttons

        }
        filters_btn.on(:doubleclick) { |button|

          set_filters(false)
          set_filter_by_type(button.data, true)

          # Re populate material defs & setup corresponding buttons
          _populate_material_defs(view.model)
          _setup_material_buttons

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

      _setup_material_buttons

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

    def set_action(action, modifier = nil)
      super

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

    def is_action_face?
      @@action == ACTION_PAINT_FACE || @@action == ACTION_UNPAINT_FACE
    end

    def is_action_part?
      @@action == ACTION_PAINT_PART || @@action == ACTION_PAINT_EDGE || @@action == ACTION_PAINT_VENEER || @@action == ACTION_UNPAINT_PART
    end

    def is_action_paint?
      @@action == ACTION_PAINT_FACE || @@action == ACTION_PAINT_PART || @@action == ACTION_PAINT_EDGE || @@action == ACTION_PAINT_VENEER
    end

    def is_action_unpaint?
      @@action == ACTION_UNPAINT_FACE || @@action == ACTION_UNPAINT_PART
    end

    def is_action_pick?
      @@action == ACTION_PICK
    end

    # -- Filters --

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

    def set_current_material(material, material_attributes, update_buttons = false)

      # Save material as current
      @@current_material = material

      # Update the paint color
      @paint_down_color = material ? material.color.blend(Sketchup::Color.new(ColorUtils::color_is_dark?(material.color) ? 'white' : 'black'), 0.85) : nil
      @paint_hover_color = material ? material.color : nil

      # Select the pick strategy
      if material_attributes

        # Set action according to material type
        case material_attributes.type
        when MaterialAttributes::TYPE_EDGE, MaterialAttributes::TYPE_VENEER
          set_action(ACTION_PAINT_FACE)
        else
          set_action(ACTION_PAINT_PART)
        end

      else
        set_action(nil)
      end

      # Update buttons
      if update_buttons
        @material_buttons.each { |button|
          button.selected = button.data == material
        }
      end

    end

    def get_current_material
      @@current_material
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

      # Populate material defs
      _populate_material_defs(view.model)

      super

      # Observe materials events
      view.model.materials.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing materials events
      view.model.materials.remove_observer(self)

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
        set_current_material(@@current_material, MaterialAttributes.new(@@current_material))
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
      if super
        _reset(view)
        return
      end
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
        if material == @@current_material
          @@current_material = nil
        end
      rescue => e # Reference to deleted Entity
        @@current_material = nil
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

      # Setup default filter if not set
      if @@filters.nil?
        @@filters = {}
        for type in 0..COLOR_MATERIAL_TYPES.length - 1
          @@filters[type] = true
        end
      end

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
          if @@current_material.nil? && material == model.materials.current
            @@current_material = material
          end
        end
        current_material_exists = current_material_exists || @@current_material == material
      end

      # Sort material defs (type > name)
      @material_defs.sort_by! { |material_def| [ MaterialAttributes::type_order(material_def[:material_attributes].type), material_def[:material].display_name ] }

      # Select default current material if necessary
      if model.materials.length == 0
        set_current_material(nil, nil)
      elsif !@material_defs.empty? && (@@current_material && !current_material_exists || @@current_material.nil?)
        set_current_material(@material_defs.first[:material], @material_defs.first[:material_attributes])
      else
        set_current_material(@@current_material, @@current_material ? MaterialAttributes.new(@@current_material) : nil)  # Reapply current material to setup the paint color
      end

    end

    def _setup_material_buttons

      @btns.remove_all
      @btns.layout = Kuix::GridLayout.new([ @material_defs.length, 10 ].min, (@material_defs.length / 10.0).ceil)

      if @material_defs.empty?

        warning_lbl = Kuix::Label.new
        warning_lbl.margin.set_all!(@unit * 2)
        warning_lbl.text = Plugin.instance.get_i18n_string("tool.smart_paint.warning.#{Sketchup.active_model.materials.length == 0 ? 'no_material' : 'all_filtered'}")
        warning_lbl.text_size = @unit * 4
        warning_lbl.set_style_attribute(:color, Sketchup::Color.new(214, 212, 205))
        @btns.append(warning_lbl)

        if Sketchup.active_model.materials.length > 0
          @settings.visible = true
        end

      end

      @material_buttons = []
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
        btn.set_style_attribute(:border_color, Sketchup::Color.new(247, 127, 0), :selected)
        btn.append_static_label(material.display_name, @unit * 3, material_color_is_dark ? Sketchup::Color.new('white') : nil)
        btn.data = material
        btn.selected = material == get_current_material
        btn.on(:click) { |button|

          # Set material as current
          set_current_material(material, material_attributes, true)

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

              picked_part_path = _get_part_path_from_path(picked_path)
              picked_part = picked_path.last
              if picked_part

                @unpaint_color = MaterialUtils::get_color_from_path(picked_part_path[0...-1]) # [0...-1] returns array without last element
                @triangles = _compute_children_faces_triangles(picked_part.definition.entities, PathUtils::get_transformation(picked_part_path))

                if event == :l_button_up
                  if is_action_paint?
                    picked_part.material = get_current_material
                  elsif is_action_unpaint?
                    picked_part.material = nil
                  end
                end

                # worker = CutlistGenerateWorker.new({}, picked_part, picked_part_path)
                # cutlist = worker.run
                #
                # puts cutlist.groups.first&.parts.first&.def

                # Reset status
                set_status('')

                view.invalidate
                return

              elsif picked_part_path
                set_message("⚠️️ #{Plugin.instance.get_i18n_string("tool.smart_paint.warning.not_part")}", MESSAGE_TYPE_ERROR)
              end

              @unpaint_color = nil
              @triangles = nil
              return

            elsif is_action_pick?

              material = MaterialUtils::get_material_from_path(picked_path)
              if material
                if event == :move

                  # Display material infos
                  set_status_material(material, MaterialAttributes.new(material))

                elsif event == :l_button_up

                  # Set picked material as current (and switch to paint action)
                  set_current_material(material, MaterialAttributes.new(material), true)

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
