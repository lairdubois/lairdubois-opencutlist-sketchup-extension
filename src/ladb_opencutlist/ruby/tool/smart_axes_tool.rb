module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../helper/boundingbox_helper'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/geom/size3d'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'

  class SmartAxesTool < SmartTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include BoundingBoxHelper
    include CutlistObserverHelper

    ACTION_MIRROR = 0
    ACTION_SWAP_LENGTH_WIDTH = 1
    ACTION_SWAP_FRONT_BACK = 2
    ACTION_SWAP_AUTO = 3

    ACTION_MODIFIER_CLOCKWISE = 0
    ACTION_MODIFIER_ANTICLOCKWIZE = 1
    ACTION_MODIFIER_LENGTH = 2
    ACTION_MODIFIER_WIDTH = 3
    ACTION_MODIFIER_THICKNESS = 4

    ACTIONS = [
      { :action => ACTION_MIRROR, :modifiers => [ ACTION_MODIFIER_THICKNESS, ACTION_MODIFIER_LENGTH, ACTION_MODIFIER_WIDTH ] },
      { :action => ACTION_SWAP_LENGTH_WIDTH, :modifiers => [ ACTION_MODIFIER_CLOCKWISE, ACTION_MODIFIER_ANTICLOCKWIZE ] },
      { :action => ACTION_SWAP_FRONT_BACK },
      { :action => ACTION_SWAP_AUTO }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(200, 200, 0, 100).freeze
    COLOR_ARROW = COLOR_WHITE
    COLOR_ARROW_AUTO_ORIENTED = Sketchup::Color.new(123, 213, 239, 255).freeze
    COLOR_BOX = COLOR_BLUE

    @@action = nil
    @@action_modifiers = {}

    def initialize
      super(true, false)

      # Create cursors
      @cursor_swap_length_width_clockwise = create_cursor('swap-length-width-clockwise', 4, 4)
      @cursor_swap_length_width_anticlockwise = create_cursor('swap-length-width-anticlockwise', 4, 4)
      @cursor_swap_front_back = create_cursor('swap-front-back', 4, 4)
      @cursor_swap_auto = create_cursor('swap-auto', 4, 4)
      @cursor_mirror = create_cursor('mirror', 4, 4)
      @cursor_select_error = create_cursor('select-error', 4, 4)

    end

    def get_stripped_name
      'axes'
    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      ACTIONS
    end

    def get_action_status(action)

      case action
      when ACTION_SWAP_LENGTH_WIDTH
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_1') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + '* = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_2') + '.'
      when ACTION_SWAP_FRONT_BACK
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_2') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.alt_key_#{Plugin.instance.platform_name}") + '* = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_2') + '.'
      when ACTION_SWAP_AUTO
        return super +
          ' | ' + Plugin.instance.get_i18n_string("default.tab_key") + ' + ' + Plugin.instance.get_i18n_string('tool.default.transparency') + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.toggle_depth') + '.' +
          ' | ' + Plugin.instance.get_i18n_string("default.copy_key_#{Plugin.instance.platform_name}") + ' = ' + Plugin.instance.get_i18n_string('tool.smart_axes.action_0') + '.'
      end

      super
    end

    def get_action_cursor(action, modifier)

      case action
      when ACTION_SWAP_LENGTH_WIDTH
        return is_action_modifier_anticlockwise? ? @cursor_swap_length_width_anticlockwise : @cursor_swap_length_width_clockwise
      when ACTION_SWAP_FRONT_BACK
        return @cursor_swap_front_back
      when ACTION_MIRROR
        return @cursor_mirror
      when ACTION_SWAP_AUTO
        return @cursor_swap_auto
      end

      super
    end

    def get_action_modifier_btn_child(action, modifier)

      case action
      when ACTION_SWAP_LENGTH_WIDTH
        case modifier
        when ACTION_MODIFIER_CLOCKWISE
          shape = Kuix::Lines2d.new(Kuix::Lines2d.pattern_from_svg_path('M0,1L0,0.8333L0.1667,0.5L0.5,0.3333L0.8333,0.3333L0.6667,0L1,0.3333L0.6667,0.6667L0.8333,0.3333'))
          shape.line_width = @unit <= 4 ? 0.5 : 1
          return shape
        when ACTION_MODIFIER_ANTICLOCKWIZE
          shape = Kuix::Lines2d.new(Kuix::Lines2d.pattern_from_svg_path('M0,1L0,0.8333L0.1667,0.5L0.5,0.3333L0.8333,0.3333L0.6667,0L1,0.3333L0.6667,0.6667L0.8333,0.3333'))
          shape.pattern_transformation = Geom::Transformation.translation(Geom::Vector3d.new(1, 0, 0)) * Geom::Transformation.scaling(-1, 1, 1)
          shape.line_width = @unit <= 4 ? 0.5 : 1
          return shape
        end
      when ACTION_MIRROR
        case modifier
        when ACTION_MODIFIER_LENGTH
          lbl = Kuix::Label.new
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action_modifier_length')
          return lbl
        when ACTION_MODIFIER_WIDTH
          lbl = Kuix::Label.new
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action_modifier_width')
          return lbl
        when ACTION_MODIFIER_THICKNESS
          lbl = Kuix::Label.new
          lbl.text = Plugin.instance.get_i18n_string('tool.smart_axes.action_modifier_thickness')
          return lbl
        end
      end

      super
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

    def is_action_swap_length_width?
      fetch_action == ACTION_SWAP_LENGTH_WIDTH
    end

    def is_action_swap_front_back?
      fetch_action == ACTION_SWAP_FRONT_BACK
    end

    def is_action_mirror?
      fetch_action == ACTION_MIRROR
    end

    def is_action_swap_auto?
      fetch_action == ACTION_SWAP_AUTO
    end

    def is_action_modifier_clockwise?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_CLOCKWISE
    end

    def is_action_modifier_anticlockwise?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_ANTICLOCKWIZE
    end

    def is_action_modifier_length?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_LENGTH
    end

    def is_action_modifier_width?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_WIDTH
    end

    def is_action_modifier_thickness?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_THICKNESS
    end

    # -- Menu --

    def getMenu(menu, flags, x, y, view)
      # _pick_hover_part(x, y, view) unless view.nil?
      build_menu(menu, view)
    end

    def build_menu(menu, view = nil)
      if @active_part
        active_part_id = @active_part.id
        active_part_material_type = @active_part.group.material_type
        item = menu.add_item(@active_part.name) {}
        menu.set_validation_proc(item) { MF_GRAYED }
        menu.add_separator
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'general', dontGenerate: false }")
        }
        menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_axes_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'axes', dontGenerate: false }")
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_size_increase_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'size_increase', dontGenerate: false }")
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
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'edges', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
            MF_ENABLED
          else
            MF_GRAYED
          end
        }
        item = menu.add_item(Plugin.instance.get_i18n_string('core.menu.item.edit_part_faces_properties')) {
          Plugin.instance.execute_dialog_command_on_tab('cutlist', 'edit_part', "{ part_id: '#{active_part_id}', tab: 'faces', dontGenerate: false }")
        }
        menu.set_validation_proc(item) {
          if active_part_material_type == MaterialAttributes::TYPE_SHEET_GOOD
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

    def onActivate(view)
      super

      # Observe model events
      view.model.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing model events
      view.model.remove_observer(self)

    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      if key == ALT_MODIFIER_KEY
        unless is_action_swap_auto?
          push_action(ACTION_SWAP_AUTO)
        end
        return true
      elsif key == COPY_MODIFIER_KEY
        if is_action_mirror?
          set_root_action(ACTION_SWAP_AUTO)
          return true
        elsif is_action_swap_length_width?
          set_root_action(ACTION_SWAP_FRONT_BACK)
          return true
        elsif is_action_swap_front_back?
          set_root_action(ACTION_MIRROR)
          return true
        elsif is_action_swap_auto?
          set_root_action(ACTION_SWAP_LENGTH_WIDTH)
          return true
        end
      elsif repeat == 1
        if key == VK_NUMPAD1 && is_action_swap_length_width?
          push_action_modifier(ACTION_MODIFIER_CLOCKWISE)
          return true
        elsif key == VK_NUMPAD2 && is_action_swap_length_width?
          push_action_modifier(ACTION_MODIFIER_ANTICLOCKWIZE)
          return true
        end
      end
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if key == VK_TAB  # TAB key doesn't generate "onKeyDown" event
        if @active_part_entity_path

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

          active_index = picked_part_entity_paths.map { |path| path.last }.index(@active_part_entity_path.last)
          new_index = (active_index + 1) % picked_part_entity_paths.length

          part = _compute_part_from_path(picked_part_entity_paths[new_index])
          _set_active(picked_part_entity_paths[new_index], part)

          @picked_path = picked_paths[new_index]

        end
        return true
      elsif after_down
        if key == ALT_MODIFIER_KEY
          if is_action_swap_auto?
            if is_quick
              set_root_action(ACTION_SWAP_AUTO)
            else
              pop_action
            end
            return true
          end
        elsif key == VK_NUMPAD1 && is_action_modifier_clockwise? && is_action_swap_length_width?
          if is_quick
            set_root_action(ACTION_SWAP_LENGTH_WIDTH, ACTION_MODIFIER_CLOCKWISE)
          else
            pop_action_modifier
          end
          return true
        elsif key == VK_NUMPAD2 && is_action_modifier_anticlockwise? && is_action_swap_length_width?
          if is_quick
            set_root_action(ACTION_SWAP_LENGTH_WIDTH, ACTION_MODIFIER_ANTICLOCKWIZE)
          else
            pop_action_modifier
          end
          return true
        end
      end
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      _handle_mouse_event(x, y, view, :l_button_down)
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      _handle_mouse_event(x, y, view, :l_button_up)
    end

    def onLButtonDoubleClick(flags, x, y, view)
      return true if super
      _handle_mouse_event(x, y, view, :l_button_dblclick)
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(x, y, view, :move)
      end
    end

    def onMouseLeave(view)
      return true if super
      _reset(view)
    end

    def onTransactionUndo(model)
      _refresh_active
    end

    def onActionChange(action, modifier)
      _refresh_active
    end

    private

    def _refresh_active
      _set_active(@active_part_entity_path, _compute_part_from_path(@active_part_entity_path))
    end

    def _set_active(part_entity_path, part)

      @active_part_entity_path = part_entity_path
      @active_part = part

      if part

        # Show part infos

        infos = [ "#{part.length} x #{part.width} x #{part.thickness}" ]
        infos << "#{part.material_name} (#{Plugin.instance.get_i18n_string("tab.materials.type_#{part.group.material_type}")})" unless part.material_name.empty?
        infos << ">|<" if part.flipped

        notify_infos(part.name, infos)

        # Create drawing helpers

        instance_info = part.def.instance_infos.values.first

        clear_space

        arrow_color = part.auto_oriented ? COLOR_ARROW_AUTO_ORIENTED : COLOR_ARROW
        arrow_line_width = 2
        arrow_offset = Sketchup.active_model.active_view.pixels_to_model(1, Sketchup.active_model.active_view.guess_target)

        part_helper = Kuix::Group.new
        part_helper.transformation = instance_info.transformation
        @space.append(part_helper)

        if part.group.material_type != MaterialAttributes::TYPE_HARDWARE

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

          if part.not_aligned_on_axes ||
            part.length_increased || part.width_increased || part.thickness_increased ||
            part.group.material_type == MaterialAttributes::TYPE_UNKNOWN

            increases = [ 0, 0, 0 ]
            part.def.size.axes.each_with_index do |axis, index|
              case index
              when 0
                increases[axis == X_AXIS ? 0 : (axis == Y_AXIS ? 1 : 2)] = part.def.length_increase.to_f if part.length_increased
              when 1
                increases[axis == X_AXIS ? 0 : (axis == Y_AXIS ? 1 : 2)] = part.def.width_increase.to_f if part.width_increased
              when 2
                increases[axis == X_AXIS ? 0 : (axis == Y_AXIS ? 1 : 2)] = part.def.thickness_increase.to_f if part.thickness_increased
              end
            end

            # Bounding box helper
            box_helper = Kuix::BoxHelper.new
            box_helper.bounds.origin.copy!(instance_info.definition_bounds.min)
            box_helper.bounds.size.copy!(instance_info.definition_bounds)
            box_helper.bounds.size.width += increases[0] / part.def.scale.x
            box_helper.bounds.size.height += increases[1] / part.def.scale.y
            box_helper.bounds.size.depth += increases[2] / part.def.scale.z
            box_helper.color = COLOR_BOX
            box_helper.line_width = 2
            box_helper.line_stipple = '-'
            part_helper.append(box_helper)

          end

        end

        # Axes helper
        axes_helper = Kuix::AxesHelper.new
        axes_helper.transformation = Geom::Transformation.scaling(1 / part.def.scale.x, 1 / part.def.scale.y, 1 / part.def.scale.z)
        part_helper.append(axes_helper)

        # All instances

        unless part_entity_path.nil?

          active_instance = part_entity_path.last
          instances = is_action_mirror? ? [ active_instance ] : active_instance.definition.instances
          instance_paths = []
          _instances_to_paths(instances, instance_paths, Sketchup.active_model.active_entities, Sketchup.active_model.active_path ? Sketchup.active_model.active_path : [])

          instance_paths.each do |path|

            mesh = Kuix::Mesh.new
            mesh.add_trangles(_compute_children_faces_triangles(path.last.definition.entities))
            mesh.background_color = COLOR_MESH
            mesh.transformation = PathUtils::get_transformation(path)
            @space.append(mesh)

          end

        end

        # Status

        if part.group.material_type == MaterialAttributes::TYPE_HARDWARE
          notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_orientable')}", MESSAGE_TYPE_ERROR)
          return
        end

        if is_action_swap_auto? && !part.auto_oriented && part.def.size.length >= part.def.size.width && part.def.size.width >= part.def.size.thickness
          notify_message("✔ #{Plugin.instance.get_i18n_string('tool.smart_axes.success.part_oriented')}", MESSAGE_TYPE_SUCCESS)
          return
        end

        unless is_action_mirror?
          definition = Sketchup.active_model.definitions[part.def.definition_id]
          if definition && definition.count_used_instances > 1
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", MESSAGE_TYPE_WARNING)
          else
            hide_message
          end
        else
          hide_message
        end

      else
        hide_infos
        clear_space
      end

    end

    def _reset(view)
      super
      if @picked_path
        @picked_path = nil
        _set_active(nil, nil)
      end
    end

    def _handle_mouse_event(x, y, view, event = nil)
      if event == :move

        if @pick_helper.do_pick(x, y) > 0
          @pick_helper.count.times { |pick_path_index|

            picked_path = @pick_helper.path_at(pick_path_index)
            if picked_path == @picked_path
              return
            # TODO : This code doesn't support nested components
            # elsif @active_part_entity_path
            #   contains_previous = false
            #   @pick_helper.count.times do |pick_path_index|
            #     contains_previous = @pick_helper.path_at(pick_path_index).take(@active_part_entity_path.length) == @active_part_entity_path
            #     return if contains_previous
            #   end
            #   return if contains_previous # Previously detected path, stop process to optimize.
            end
            if picked_path && picked_path.last.is_a?(Sketchup::Face)

              @picked_path = picked_path

              picked_entity_path = _get_part_entity_path_from_path(picked_path)
              if picked_entity_path.length > 0

                part = _compute_part_from_path(picked_entity_path)
                if part
                  _set_active(picked_entity_path, part)
                else
                  _reset(view)
                  notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", MESSAGE_TYPE_ERROR)
                end
                return

              elsif picked_entity_path
                _reset(view)
                notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_axes.error.not_part')}", MESSAGE_TYPE_ERROR)
                return
              end

            end

          }
        end
        _reset(view)

      elsif event == :l_button_up || event == :l_button_dblclick

        if @active_part && @active_part.group.material_type != MaterialAttributes::TYPE_HARDWARE

          definition = view.model.definitions[@active_part.def.definition_id]
          unless definition.nil?

            size = @active_part.def.size

            ti = nil
            if is_action_swap_length_width?

              if is_action_modifier_anticlockwise?
                ti = Geom::Transformation.axes(
                  ORIGIN,
                  size.axes[1],
                  AxisUtils.flipped?(size.axes[1], size.axes[0], size.axes[2]) ? size.axes[0].reverse : size.axes[0],
                  size.axes[2]
                )
              else
                ti = Geom::Transformation.axes(
                  ORIGIN,
                  AxisUtils.flipped?(size.axes[1], size.axes[0], size.axes[2]) ? size.axes[1].reverse : size.axes[1],
                  size.axes[0],
                  size.axes[2]
                )
              end

            elsif is_action_swap_front_back?

              ti = Geom::Transformation.axes(
                ORIGIN,
                size.axes[0],
                AxisUtils.flipped?(size.axes[0], size.axes[1], size.axes[2].reverse) ? size.axes[1].reverse : size.axes[1],
                size.axes[2].reverse
              )

            elsif is_action_mirror?

              entity = @active_part_entity_path.last
              bounds = _compute_faces_bounds(entity.definition)

              scaling = {
                X_AXIS => 1,
                Y_AXIS => 1,
                Z_AXIS => 1,
              }
              if is_action_modifier_length?
                scaling[@active_part.def.size.oriented_axis(X_AXIS)] = -1
              elsif is_action_modifier_width?
                scaling[@active_part.def.size.oriented_axis(Y_AXIS)] = -1
              elsif is_action_modifier_thickness?
                scaling[@active_part.def.size.oriented_axis(Z_AXIS)] = -1
              end

              t = Geom::Transformation.scaling(bounds.center, scaling[X_AXIS], scaling[Y_AXIS], scaling[Z_AXIS])
              entity.transformation *= t

              part = _compute_part_from_path(@active_part_entity_path)
              _set_active(@active_part_entity_path, part)

            elsif is_action_swap_auto?

              instance_info = @active_part.def.instance_infos.values.first
              oriented_size = Size3d.create_from_bounds(instance_info.definition_bounds, @active_part.def.scale, true)

              ti = Geom::Transformation.axes(
                ORIGIN,
                oriented_size.axes[0],
                AxisUtils.flipped?(oriented_size.axes[0], oriented_size.axes[1], oriented_size.axes[2]) ? oriented_size.axes[1].reverse : oriented_size.axes[1],
                oriented_size.axes[2]
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

              if Plugin.instance.get_model_preset('cutlist_options').fetch('auto_orient')
                definition_attributes = DefinitionAttributes.new(definition)
                definition_attributes.orientation_locked_on_axis = true
                definition_attributes.write_to_attributes
              end

              # Commit model modification operation
              view.model.commit_operation

              part = _compute_part_from_path(@active_part_entity_path)
              _set_active(@active_part_entity_path, part)

            end

          end

        else
          UI.beep
        end

      end
    end

  end

end
