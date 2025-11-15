module Ladb::OpenCutList

  require 'digest'
  require_relative 'smart_tool'
  require_relative '../lib/geometrix/finder/circle_finder'
  require_relative '../lib/kuix/geom/bounds3d'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'
  require_relative '../manipulator/cline_manipulator'
  require_relative '../helper/entities_helper'
  require_relative '../helper/user_text_helper'
  require_relative '../worker/common/common_drawing_decomposition_worker'

  class SmartReshapeTool < SmartTool

    ACTION_STRETCH = 0

    ACTION_OPTION_STRETCH_MEASURE_TYPE = 'stretch_measure_type'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE = 'outside'
    ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET = 'offset'

    ACTION_OPTION_AXES_ACTIVE = 'active'
    ACTION_OPTION_AXES_CONTEXT = 'context'
    ACTION_OPTION_AXES_ENTITY = 'entity'

    ACTIONS = [
      {
        :action => ACTION_STRETCH,
        :options => {
          ACTION_OPTION_STRETCH_MEASURE_TYPE => [ ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ]
        }
      }
    ].freeze

    # -----

    attr_reader :callback_action_handler,
                :cursor_select, :cursor_select_part

    def initialize(current_action: nil, callback_action_handler: nil)
      super(current_action: current_action)

      @callback_action_handler = callback_action_handler

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
      @cursor_select_part = create_cursor('select-part', 0, 0)

    end

    def get_stripped_name
      'reshape'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_STRETCH
        return @cursor_select
      end

      super
    end

    def get_action_options_modal?(action)
      false
    end

    def get_action_option_toggle?(action, option_group, option)
      true
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group

      when ACTION_OPTION_STRETCH_MEASURE_TYPE
        return true

      when ACTION_OPTION_AXES
        return true

      end

      false
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_STRETCH_MEASURE_TYPE
        case option
        when ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L1,0.583L1,0.917L0,0.917M0,0.25L1,0.25M0,0.083L0,0.417M1,0.083L1,0.417'))
        when ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.5,0.583L0.5,0.917L0,0.917M0.5,0.25L1,0.25M0.5,0.083L0.5,0.417M1,0.083L1,0.417 M0.75,0.583L1,0.583L1,0.917L0.75,0.917'))
        end
      when ACTION_OPTION_AXES
        case option
        when ACTION_OPTION_AXES_ACTIVE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,0.833L1,0.833 M0,0.167L0.167,0L0.333,0.167 M0.833,0.667L1,0.833L0.833,1'))
        when ACTION_OPTION_AXES_CONTEXT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,0.833L1,0.833 M0,0.167L0.167,0L0.333,0.167 M0.833,0.667L1,0.833L0.833,1 M0.5,0.083L0.5,0.5L0.917,0.5L0.917,0.083L0.5,0.083'))
        when ACTION_OPTION_AXES_ENTITY
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.25,0L0.25,0.75L1,0.75 M0.083,0.167L0.25,0L0.417,0.167 M0.833,0.583L1,0.75L0.833,0.917 M0.042,0.5L0.042,0.958L0.5,0.958L0.5,0.5L0.042,0.5'))
        end
      end

      super
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

    def onActionChanged(action)

      remove_all_2d
      remove_all_3d

      case action
      when ACTION_STRETCH
        set_action_handler(SmartReshapeStretchActionHandler.new(self, fetch_action_handler))
      end

      super

      refresh

    end

    def onViewChanged(view)
      super
      refresh
    end

    def onTransactionUndo(model)
      refresh
    end

    def onTransactionCommit(model)
      refresh
    end

  end

  # -----

  class SmartReshapeActionHandler < SmartActionHandler

    include UserTextHelper
    include SmartActionHandlerPartHelper

    STATE_SELECT = 0
    STATE_SELECT_RECT = 5
    STATE_SELECT_SIBLINGS = 4
    STATE_RESHAPE_START = 1
    STATE_RESHAPE = 2

    LAYER_3D_RESHAPE_PREVIEW = 10

    attr_reader :picked_handle_start_point,
                :picked_handle_end_point

    def initialize(action, tool, previous_action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(tool)

      @mouse_down_point = nil
      @mouse_snap_point = nil

      @picked_reshape_start_point = nil
      @picked_reshape_end_point = nil

      @startup_state = STATE_SELECT

    end

    # ------

    def start
      super

      return if (model = Sketchup.active_model).nil?
      selection = model.selection

      # Try to copy the previous action handler selection
      if @previous_action_handler

        if (part_entity_path = @previous_action_handler.get_active_part_entity_path) &&
           (part = @previous_action_handler.get_active_part)

          _set_active_part(part_entity_path, part)

          if _pick_part_siblings?

            if (part_sibling_entity_paths = @previous_action_handler.get_active_part_sibling_entity_paths) &&
               (part_siblings = @previous_action_handler.get_active_part_siblings)

              part_sibling_entity_paths.zip(part_siblings).each do |part_sibling_entity_path, part_sibling|
                _add_part_sibling(part_sibling_entity_path, part_sibling)
              end

            end

          end

          onPartSelected

        elsif (selection_path = @previous_action_handler.get_active_selection_path) &&
              (instances = @previous_action_handler.get_active_selection_instances)

          _reset_active_part
          _set_active_selection(selection_path, instances)

          onPartSelected

        end

      else

        if (entities = selection.select { |entity| entity.respond_to?(:transformation) }).any?

          active_path = model.active_path.is_a?(Array) ? model.active_path : []

          if entities.one?
            path = active_path + [ entities.first ]
            part_entity_path = _get_part_entity_path_from_path(path)
            unless (part = _generate_part_from_path(part_entity_path)).nil?
              _set_active_part(part_entity_path, part)
            end
          end

          unless has_active_part?
            _set_active_selection(active_path, entities)
          end

          onPartSelected

        end

      end

      # Clear current selection
      selection.clear if _clear_selection_on_start

    end

    # -- STATE --

    def get_startup_state
      @startup_state
    end

    def get_state_cursor(state)

      case state
      when STATE_SELECT
        return @tool.cursor_select_part
      end

      super
    end

    def get_state_picker(state)

      case state
      when STATE_SELECT, STATE_SELECT_SIBLINGS
        return SmartPicker.new(tool: @tool, observer: self, pick_point: false)
      end

      super
    end

    def get_state_status(state)
      PLUGIN.get_i18n_string("tool.smart_reshape.action_#{@action}_state_#{state}_status") + '.'
    end

    def get_state_vcb_label(state)
      super
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      if @tool.callback_action_handler.nil?

        case @state

        when STATE_RESHAPE
          set_state(STATE_RESHAPE_START)
          _refresh
          return true

        when STATE_RESHAPE_START
          @picked_shape_start_point = nil
          _unhide_instance
          _unhide_sibling_instances
        end

        _reset
        _refresh

      else
        stop
        Sketchup.active_model.tools.pop_tool
      end

      true
    end

    def onToolMouseMove(tool, flags, x, y, view)
      super

      return true if x < 0 || y < 0

      case @state

      when STATE_SELECT

        if @mouse_down_point_2d && @mouse_down_point_2d.distance(Geom::Point3d.new(x, y, 0)) > 20  # Drag handled only if the distance is > 10px
          set_state(STATE_SELECT_RECT)
        end

      when STATE_SELECT_RECT

        @tool.remove_all_2d

        unless @mouse_down_point_2d.nil?
          @mouse_move_point_2d = Geom::Point2d.new(x, y)
          _preview_reshape_select_rect(view)
        end

      when STATE_RESHAPE_START

        @mouse_snap_point = nil

        @tool.remove_all_2d
        @tool.remove_3d([LAYER_3D_RESHAPE_PREVIEW ])

        _snap_reshape_start(flags, x, y, view)
        _preview_reshape_start(view)

      when STATE_RESHAPE

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d([LAYER_3D_RESHAPE_PREVIEW ])

        _snap_reshape(flags, x, y, view)
        _preview_reshape(view)

      end

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

      false
    end

    def onToolMouseLeave(tool, view)
      @tool.remove_all_2d
      @tool.remove_3d([ LAYER_3D_RESHAPE_PREVIEW ])
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onToolLButtonDown(tool, flags, x, y, view)

      case @state

      when STATE_SELECT
        if has_active_part? && _pick_part_siblings?
          set_state(STATE_SELECT_SIBLINGS)
          return true
        else
          @mouse_down_point_2d = Geom::Point3d.new(x, y)
          return true
        end

      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      @mouse_down_point = nil

      case @state

      when STATE_SELECT, STATE_SELECT_SIBLINGS
        @mouse_down_point_2d = nil
        @mouse_move_point_2d = nil
        unless has_active_part?
          UI.beep
          return true
        end
        onPartSelected

      when STATE_SELECT_RECT
        if @mouse_down_point_2d.nil?
          set_state(STATE_SELECT)
          return true
        else

          ph = view.pick_helper(x, y)
          ph.window_pick(@mouse_down_point_2d, Geom::Point3d.new(x, y), Sketchup::PickHelper::PICK_INSIDE)

          @tool.remove_all_2d
          @mouse_down_point_2d = nil
          @mouse_move_point_2d = nil

          if ph.count > 0

            model = Sketchup.active_model
            active_path = model.active_path.is_a?(Array) ? model.active_path : []

            instances = (0...ph.count)
                          .map { |i| ph.element_at(i) }
                          .uniq
                          .select { |entity| entity.respond_to?(:transformation) }
            if instances.any?

              _reset_active_part
              _set_active_selection(active_path, instances)

              onPartSelected

              return true
            end

          end
          UI.beep
          set_state(STATE_SELECT)
        end

      when STATE_RESHAPE_START
        @picked_reshape_start_point = @mouse_snap_point
        set_state(STATE_RESHAPE)
        _refresh

      when STATE_RESHAPE
        @picked_reshape_end_point = @mouse_snap_point
        _reshape_entity
        _restart

      end

    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      case @state

      when STATE_RESHAPE
        if _read_reshape(tool, text, view)
          _restart
          return true
        end

      end

      false
    end

    def onPickerChanged(picker, view)

      case @state

      when STATE_SELECT
        _pick_part(picker, view)

      when STATE_SELECT_SIBLINGS
        _pick_part_sibling(picker, view)

      end

      super
    end

    def onStateChanged(state)
      super

      @tool.remove_tooltip

    end

    def onPartSelected
    end

    # -----

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    def enableVCB?
      true
    end

    # -----

    protected

    def _reset
      @mouse_ip.clear
      @mouse_snap_point = nil
      @picked_reshape_start_point = nil
      @picked_reshape_end_point = nil
      super
      set_state(STATE_SELECT)
    end

    def _restart
      if @tool.callback_action_handler.nil?
        super
      else
        @tool.callback_action_handler.previous_action_handler = self
        Sketchup.active_model.tools.pop_tool if active?
      end
    end

    # -----

    def _clear_selection_on_start
      true
    end

    # -----

    def _preview_part(part_entity_path, part, layer = 0, highlighted = false)
      super
      if part

        # Show part infos
        @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

      else

        @tool.remove_tooltip

      end
    end

    # -----

    def _snap_reshape_start(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _snap_reshape(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_reshape_select_rect(view)

      k_rect = _create_floating_rect(
        start_point_2d: @mouse_down_point_2d,
        end_point_2d: @mouse_move_point_2d,
      )
      @tool.append_2d(k_rect)

    end

    def _preview_reshape_start(view)
    end

    def _preview_reshape(view)
    end

    def _read_reshape(tool, text, view)
      false
    end

    # -----

    def _fetch_option_stretch_measure_type
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE)
    end

    def _fetch_option_stretch_measure_type_outside
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE)
    end

    def _fetch_option_stretch_measure_type_offset
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET)
    end

    def _fetch_option_axes
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_AXES)
    end

    # -----

    def _reshape_entity
    end

    # -----

    def _get_edit_transformation
      case _fetch_option_axes

      when SmartReshapeTool::ACTION_OPTION_AXES_CONTEXT
        t = _get_global_context_transformation(nil)
        return t unless t.nil?

      when SmartReshapeTool::ACTION_OPTION_AXES_ENTITY
        t = _get_global_instance_transformation(nil)
        return t unless t.nil?

      end
      super
    end

    def _get_drawing_def_parameters
      {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: false,
        ignore_soft_edges: false,
        ignore_clines: true,
      }
    end

    def _get_drawing_def_segments(drawing_def)
      segments = []
      if drawing_def.is_a?(DrawingDef)
        segments += drawing_def.cline_manipulators.flat_map { |manipulator| manipulator.segment }
        segments += drawing_def.edge_manipulators.flat_map { |manipulator| manipulator.segment }
        segments += drawing_def.curve_manipulators.flat_map { |manipulator| manipulator.segments }
      end
      segments
    end

    # -- UTILS --

    def _points_to_segments(points, closed = true, flatten = true)
      segments = points.each_cons(2).to_a
      segments << [ points.last, points.first ] if closed && !points.empty?
      segments.flatten!(1) if flatten
      segments
    end

  end

  class SmartReshapeStretchActionHandler < SmartReshapeActionHandler

    STATE_RESHAPE_CUTTER_MOVE = 10
    STATE_RESHAPE_CUTTER_ADD = 11
    STATE_RESHAPE_CUTTER_REMOVE = 12

    LAYER_3D_GRIPS_PREVIEW = 100
    LAYER_3D_CUTTERS_PREVIEW = 200

    PX_INFLATE_VALUE = 50

    @@last_cutters_data = nil

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_STRETCH, tool, previous_action_handler)

      @picked_axis = nil
      @picked_grip_index = -1

      @cutters = nil

      @picked_cutter_index = nil
      @picked_cutter_start_point = nil

      @locked_axis = nil

    end

    # -----

    def start
      super

      if @previous_action_handler &&
         @previous_action_handler.is_a?(SmartReshapeStretchActionHandler)

        # After a "restart" we want to catch VCB input so we change the "startup state"
        @startup_state = @state

      end

    end

    def stop
      _unhide_instance
      super
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_RESHAPE_START
        return super +
               "#{(' ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1a_status") + '.') unless @picked_axis.nil?}" +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1b_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1c_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_RESHAPE
        return PLUGIN.get_i18n_string("tool.default.vcb_distance")

      end

      super    end

    # -----

    def onToolSuspend(tool, view)
      _unhide_instance if @state == STATE_RESHAPE
    end

    def onToolResume(tool, view)
      super
      _hide_instance if @state == STATE_RESHAPE
    end

    def onToolLButtonDown(tool, flags, x, y, view)

      case @state

      when STATE_RESHAPE_START
        if @picked_cutter_index

          drawing_def = _get_drawing_def
          et = _get_edit_transformation
          eb = _get_drawing_def_edit_bounds(drawing_def, et)

          direction = @picked_axis.transform(et)
          min = eb.min.transform(et)
          max = eb.max.transform(et)
          max_plane = [ max, direction ]
          vmax = min.vector_to(min.project_to_plane(max_plane))

          plane = [min.offset(vmax, vmax.length * @cutters[@picked_axis][@picked_cutter_index]), direction ]

          @picked_cutter_start_point = Geom.intersect_line_plane(view.pickray(x, y), plane)

          set_state(STATE_RESHAPE_CUTTER_MOVE)
          _refresh
          return true
        end

        if @picked_grip_index

          @mouse_down_point = Geom::Point3d.new(x, y,)

          return true
        end

        return true

      when STATE_RESHAPE_CUTTER_ADD, STATE_RESHAPE_CUTTER_REMOVE
        return true

      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_RESHAPE_START
        if @picked_grip_index

          drawing_def = _get_drawing_def
          et = _get_edit_transformation
          eb = _get_drawing_def_edit_bounds(drawing_def, et)
          keb = Kuix::Bounds3d.new.copy!(eb)

          @picked_reshape_start_point = keb.face_center(@picked_grip_index).to_p.transform(et)
          @mouse_down_point = nil

          set_state(STATE_RESHAPE) if _assert_valid_cutters
          _refresh
          return true
        end
        unless @picked_cutter_index
          _reset
          _refresh
          return true
        end

      when STATE_RESHAPE_CUTTER_MOVE
        if @picked_cutter_index
          _store_cutters
          _load_cutters # Reload to sanitize
          set_state(STATE_RESHAPE_START)
          _refresh
          return true
        end

      when STATE_RESHAPE_CUTTER_ADD
        if @snap_ratio
          @cutters[@picked_axis] << @snap_ratio
          @snap_ratio = nil
          _store_cutters
          _load_cutters # Reload to sanitize
          _refresh
        end
        return true

      when STATE_RESHAPE_CUTTER_REMOVE
        if @picked_cutter_index
          @cutters[@picked_axis].delete_at(@picked_cutter_index)
          @picked_cutter_index = nil
          _store_cutters
          _load_cutters # Reload to sanitize
          _refresh
        end
        return true

      end

      super
    end

    def onToolMouseMove(tool, flags, x, y, view)
      check_super = true
      case @state

      when STATE_RESHAPE_START
        @tool.remove_3d([LAYER_3D_PART_PREVIEW, LAYER_3D_CUTTERS_PREVIEW, LAYER_3D_GRIPS_PREVIEW ])
        check_super = @mouse_down_point.nil?

      end

      return true if check_super && super

      case @state

      when STATE_RESHAPE_START
        unless @mouse_down_point.nil? || @picked_grip_index.nil?
          if Geom::Point3d.new(x, y).distance(@mouse_down_point) > 20  # Drag handled only if the distance is > 20px

            drawing_def = _get_drawing_def
            et = _get_edit_transformation
            eb = _get_drawing_def_edit_bounds(drawing_def, et)
            keb = Kuix::Bounds3d.new.copy!(eb)

            @picked_reshape_start_point = keb.face_center(@picked_grip_index).to_p.transform(et)

            @mouse_down_point = nil
            set_state(STATE_RESHAPE) if _assert_valid_cutters
          end
        end

      when STATE_RESHAPE_CUTTER_MOVE

        @mouse_snap_point = nil

        @tool.remove_all_2d
        @tool.remove_3d([LAYER_3D_CUTTERS_PREVIEW ])

        _snap_reshape_cutter_move(flags, x, y, view)
        _preview_reshape_cutter_move(view)

      when STATE_RESHAPE_CUTTER_ADD

        @mouse_snap_point = nil

        @tool.remove_all_2d
        @tool.remove_3d([LAYER_3D_CUTTERS_PREVIEW ])

        _snap_reshape_cutter_add(flags, x, y, view)
        _preview_reshape_cutter_add(view)

      when STATE_RESHAPE_CUTTER_REMOVE

        @mouse_snap_point = nil

        @tool.remove_all_2d
        @tool.remove_3d([LAYER_3D_CUTTERS_PREVIEW ])

        _snap_reshape_cutter_remove(flags, x, y, view)
        _preview_reshape_cutter_remove(view)

      end

      false
    end

    def onToolMouseLeave(tool, view)
      @tool.remove_3d([ LAYER_3D_PART_PREVIEW, LAYER_3D_GRIPS_PREVIEW, LAYER_3D_CUTTERS_PREVIEW ])
      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      case @state

      when STATE_RESHAPE_START
        if key == VK_RIGHT
          if @locked_axis == X_AXIS
            @locked_axis = nil
          else
            @locked_axis = X_AXIS
          end
          _refresh
          return true
        elsif key == VK_LEFT
          if @locked_axis == Y_AXIS
            @locked_axis = nil
          else
            @locked_axis = Y_AXIS
          end
          _refresh
          return true
        elsif key == VK_UP
          if @locked_axis == Z_AXIS
            @locked_axis = nil
          else
            @locked_axis = Z_AXIS
          end
          _refresh
          return true
        elsif key == VK_DOWN
          @locked_axis = nil
          _refresh
          return true
        end
        unless @picked_axis.nil?
          if tool.is_key_ctrl_or_option?(key)
            set_state(STATE_RESHAPE_CUTTER_ADD)
            _refresh
            return true
          end
          if tool.is_key_alt_or_command?(key)
            set_state(STATE_RESHAPE_CUTTER_REMOVE)
            _refresh
            return true
          end
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      case @state

      when STATE_RESHAPE_CUTTER_ADD, STATE_RESHAPE_CUTTER_REMOVE
        if tool.is_key_ctrl_or_option?(key)
          @snap_ratio = nil
          set_state(STATE_RESHAPE_START)
          _refresh
          return true
        end
        if tool.is_key_alt_or_command?(key)
          set_state(STATE_RESHAPE_START)
          _refresh
          return true
        end

      end

      false
    end

    def onToolActionOptionStored(tool, action, option_group, option)

      if option_group == SmartReshapeTool::ACTION_OPTION_AXES && @state > STATE_RESHAPE_START
        set_state(STATE_RESHAPE_START)
        _refresh
      end

    end

    def onStateChanged(state)
      super

      unless _get_instances.nil?

        case state

        when STATE_SELECT
          _unhide_instances

        when STATE_RESHAPE_START
          @tool.remove_3d(LAYER_3D_PART_PREVIEW)  # Remove part preview
          _unhide_instances

        when STATE_RESHAPE_CUTTER_MOVE
          @tool.remove_3d(LAYER_3D_GRIPS_PREVIEW)
          _unhide_instances

        when STATE_RESHAPE_CUTTER_ADD, STATE_RESHAPE_CUTTER_REMOVE
          @tool.remove_3d(LAYER_3D_GRIPS_PREVIEW)
          _unhide_instances

        when STATE_RESHAPE
          @tool.remove_3d([LAYER_3D_GRIPS_PREVIEW, LAYER_3D_CUTTERS_PREVIEW ])
          _get_split_def    # Compute a new split_def
          _hide_instances

        end

      end

    end

    def onPartSelected

      _reset_drawing_def

      _load_cutters

      set_state(STATE_RESHAPE_START)
      _refresh

    end

    # -----

    protected

    def _reset
      @split_def = nil
      @picked_axis = nil
      @picked_grip_index = nil
      @picked_cutter_index = nil
      super
    end

    # -----

    def _snap_reshape_start(flags, x, y, view)

      @picked_grip_index = nil
      @picked_cutter_index = nil

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      @picked_axis = @locked_axis unless @locked_axis.nil?

      # Snap to grip?

      pk = view.pick_helper(x, y, 40)
      [ X_AXIS, Y_AXIS, Z_AXIS ].select { |axis| @locked_axis.nil? || axis == @locked_axis }.each do |axis|
        grip_indices = Kuix::Bounds3d.faces_by_axis(axis)
        grip_indices.each do |grip_index|
          p = keb.face_center(grip_index).to_p.transform(et)
          if pk.test_point(p)
            @picked_axis = axis
            @picked_grip_index = grip_index
            @split_def = nil
            @mouse_snap_point = p
            return true
          end
        end
      end

      unless @cutters.nil? || @picked_axis.nil?

        # Snap to a cutter?

        direction = @picked_axis.transform(et)
        min = eb.min.transform(et)
        max = eb.max.transform(et)
        min_plane = [ min, direction ]
        max_plane = [ max, direction ]
        vmax = min.vector_to(min.project_to_plane(max_plane))

        inch_inflate_value = view.pixels_to_model(PX_INFLATE_VALUE, eb.center.transform(et))

        quad_index, _ = Kuix::Bounds3d.faces_by_axis(@picked_axis)
        quad_ref = keb.inflate_all!(inch_inflate_value).get_quad(quad_index).map { |point| point.transform(et).project_to_plane(min_plane)}

        p2d = Geom::Point3d.new(x, y)
        @cutters[@picked_axis].each_with_index do |ratio, index|

          v = Geom::Vector3d.new(vmax)
          v.length = vmax.length * ratio
          t = Geom::Transformation.translation(v)

          polygon = quad_ref.map { |point| view.screen_coords(point.transform(t)) }
          if Geom.point_in_polygon_2D(p2d, polygon, true)
            @picked_cutter_index = index
            return true
          end

        end

      end

      super
    end

    def _snap_reshape_cutter_move(flags, x, y, view)

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)

      direction = @picked_axis.transform(et)

      picked_point, _ = Geom::closest_points([@picked_cutter_start_point, direction ], view.pickray(x, y))
      @mouse_snap_point = picked_point
      @mouse_ip.clear

      min = eb.min.transform(et)
      max = eb.max.transform(et)

      min_plane = [ min, direction ]
      max_plane = [ max, direction ]

      pmin = @mouse_snap_point.project_to_plane(min_plane)
      pmax = @mouse_snap_point.project_to_plane(max_plane)

      v = pmin.vector_to(@mouse_snap_point)
      vmax = pmin.vector_to(pmax)

      if v.valid? && vmax.valid?
        ratio = v.length / vmax.length
        ratio *= -1 unless v.samedirection?(vmax)
        ratio = [ [ 0, ratio ].max, 1 ].min
      else
        ratio = 0
      end

      @cutters[@picked_axis][@picked_cutter_index] = ratio

    end

    def _snap_reshape_cutter_add(flags, x, y, view)

      @snap_ratio = nil
      @picked_cutter_index = nil

      unless @picked_axis.nil?

        drawing_def = _get_drawing_def
        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)
        ked = Kuix::Bounds3d.new.copy!(eb)
        center = eb.center.transform(et)
        direction = @picked_axis.transform(et)

        case @picked_axis
        when X_AXIS
          plane = [ center, eb.height > eb.depth ? _get_active_z_axis : _get_active_y_axis ]
        when Y_AXIS
          plane = [ center, eb.width > eb.depth ? _get_active_z_axis : _get_active_x_axis ]
        when Z_AXIS
          plane = [ center, eb.height > eb.width ? _get_active_x_axis : _get_active_y_axis ]
        else
          plane = nil
        end
        unless plane.nil?

          hit = Geom.intersect_line_plane(view.pickray(x, y), plane)
          unless hit.nil?

            @mouse_snap_point = hit.project_to_line([ center, direction ])

            min, max = Kuix::Bounds3d.faces_by_axis(@picked_axis).map { |index| ked.face_center(index).to_p.transform(et) }

            v = min.vector_to(@mouse_snap_point)
            vmax = min.vector_to(max)

            if v.valid? && vmax.valid?
              ratio = v.length / vmax.length
              ratio *= -1 unless v.samedirection?(vmax)
              @snap_ratio = [ [ 0, ratio ].max, 1 ].min
            end

          end

        end

      end

    end

    def _snap_reshape_cutter_remove(flags, x, y, view)

      @picked_cutter_index = nil

      unless @cutters.nil? || @picked_axis.nil?

        drawing_def = _get_drawing_def
        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)
        keb = Kuix::Bounds3d.new.copy!(eb)
        direction = @picked_axis.transform(et)

        min = eb.min.transform(et)
        max = eb.max.transform(et)
        min_plane = [ min, direction ]
        max_plane = [ max, direction ]
        vmax = min.vector_to(min.project_to_plane(max_plane))

        if @picked_axis == X_AXIS
          quad_index = Kuix::Bounds3d::LEFT
        elsif @picked_axis == Y_AXIS
          quad_index = Kuix::Bounds3d::FRONT
        elsif @picked_axis == Z_AXIS
          quad_index = Kuix::Bounds3d::BOTTOM
        end

        inch_inflate_value = view.pixels_to_model(PX_INFLATE_VALUE, eb.center.transform(et))

        quad_ref = keb.inflate_all!(inch_inflate_value).get_quad(quad_index).map { |point| point.transform(et).project_to_plane(min_plane)}

        p2d = Geom::Point3d.new(x, y)
        @cutters[@picked_axis].each_with_index do |ratio, index|

          v = Geom::Vector3d.new(vmax)
          v.length = vmax.length * ratio
          t = Geom::Transformation.translation(v)

          polygon = quad_ref.map { |point| view.screen_coords(point.transform(t)) }
          if Geom.point_in_polygon_2D(p2d, polygon, true)
            @picked_cutter_index = index
            return true
          end

        end

      end

    end

    def _snap_reshape(flags, x, y, view)

      pk = view.pick_helper(x, y, 40)
      if pk.test_point(@picked_reshape_start_point)

        @mouse_snap_point = @picked_reshape_start_point
        @mouse_ip.clear

      else

        et = _get_edit_transformation
        direction = @picked_axis.transform(et)

        if @mouse_ip.degrees_of_freedom > 2 ||
           @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1 ||
           @mouse_ip.face && @mouse_ip.face == @mouse_ip.instance_path.leaf && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(direction) ||
           @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(direction)

          picked_point, _ = Geom::closest_points([ @picked_reshape_start_point, direction ], view.pickray(x, y))
          @mouse_snap_point = picked_point
          @mouse_ip.clear

        else

          # Force picked point to be projected to shape the last picked point normal line
          @mouse_snap_point = @mouse_ip.position.project_to_line([ @picked_reshape_start_point, direction ])

        end

      end

    end

    def _preview_active_cutters(view)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)
      inch_inflate_value = view.pixels_to_model(PX_INFLATE_VALUE, eb.center.transform(et))

      if @picked_axis

        color = _get_vector_color(@picked_axis.transform(et))

        case @picked_axis
        when X_AXIS
          section_ref = keb.x_section_min.inflate!(0, inch_inflate_value, inch_inflate_value)
          patterns_transformation = Geom::Transformation.axes(ORIGIN, Z_AXIS, Y_AXIS, X_AXIS)
        when Y_AXIS
          section_ref = keb.y_section_min.inflate!(inch_inflate_value, 0, inch_inflate_value)
          patterns_transformation = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS, Y_AXIS)
        when Z_AXIS
          section_ref = keb.z_section_min.inflate!(inch_inflate_value, inch_inflate_value, 0)
          patterns_transformation = IDENTITY
        end

        ratios = @cutters[@picked_axis]
        ratios = ratios.dup.push(@snap_ratio) if @snap_ratio
        ratios.each_with_index do |ratio, index|

          section = Kuix::Bounds3d.new.copy!(section_ref)
          section.origin.x += ratio * keb.width if @picked_axis == X_AXIS
          section.origin.y += ratio * keb.height if @picked_axis == Y_AXIS
          section.origin.z += ratio * keb.depth if @picked_axis == Z_AXIS

          is_picked_section = @picked_cutter_index == index
          is_add = @state == STATE_RESHAPE_CUTTER_ADD && @snap_ratio && index == ratios.length - 1
          is_remove = ratio == 0 || ratio == 1 || @state == STATE_RESHAPE_CUTTER_REMOVE && is_picked_section
          is_highligted = is_picked_section && !is_remove

          section_color = color
          section_color = Kuix::COLOR_DARK_GREY if is_remove

          k_rectangle = Kuix::RectangleMotif.new
          k_rectangle.bounds.copy!(section)
          k_rectangle.line_width = if is_highligted
                               3
                             else
                               is_remove || is_add ? 2 : 1
                             end
          k_rectangle.line_stipple = is_remove || is_add ? Kuix::LINE_STIPPLE_SHORT_DASHES : Kuix::LINE_STIPPLE_SOLID
          k_rectangle.color = section_color
          k_rectangle.transformation = et
          k_rectangle.patterns_transformation = patterns_transformation
          @tool.append_3d(k_rectangle, LAYER_3D_CUTTERS_PREVIEW)

          k_mesh = Kuix::Mesh.new
          k_mesh.add_quads(section.get_quads)
          k_mesh.background_color = ColorUtils.color_translucent(section_color, is_highligted ? 0.6 : 0.3)
          k_mesh.transformation = et
          @tool.append_3d(k_mesh, LAYER_3D_CUTTERS_PREVIEW)

        end

      end
    end

    def _preview_active_axis
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      if @picked_axis

        color = _get_vector_color(@picked_axis.transform(et))

        p1, p2 = Kuix::Bounds3d.faces_by_axis(@picked_axis).map { |face| keb.face_center(face).to_p }

        k_edge = Kuix::EdgeMotif.new
        k_edge.start.copy!(p1)
        k_edge.end.copy!(p2)
        k_edge.line_width = @picked_axis == @locked_axis ? 2 : 1.5
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_edge.color = color
        k_edge.on_top = true
        k_edge.transformation = et
        @tool.append_3d(k_edge, LAYER_3D_RESHAPE_PREVIEW)

        k_points = _create_floating_points(
          points: [ p1, p2 ],
          style: Kuix::POINT_STYLE_CIRCLE,
          stroke_color: color,
          fill_color: Kuix::COLOR_WHITE
        )
        k_points.transformation = et
        @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)

        if @picked_grip_index

          k_points = _create_floating_points(
            points: keb.face_center(@picked_grip_index).to_p,
            style: Kuix::POINT_STYLE_CIRCLE,
            stroke_color: nil,
            fill_color: color
          )
          k_points.transformation = et
          @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)

        end

      end
    end

    def _preview_reshape_start(view)
      super

      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      # Box

      k_box = Kuix::BoxMotif.new
      k_box.bounds.copy!(eb)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.transformation = et
      @tool.append_3d(k_box, LAYER_3D_PART_PREVIEW)

      # Grips + lines

      if @locked_axis.nil?

        axes = [ X_AXIS, Y_AXIS, Z_AXIS ].delete_if { |axis| axis == @picked_axis }

        axes.map { |axis| Kuix::Bounds3d.faces_by_axis(axis).map { |face| keb.face_center(face).to_p } }.each do |p0, p1|

          k_edge = Kuix::EdgeMotif.new
          k_edge.start.copy!(p0)
          k_edge.end.copy!(p1)
          k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          k_edge.color = Kuix::COLOR_MEDIUM_GREY
          k_edge.on_top = true
          k_edge.transformation = et
          @tool.append_3d(k_edge, LAYER_3D_GRIPS_PREVIEW)

        end

        k_points = _create_floating_points(
          points: axes.flat_map { |axis| Kuix::Bounds3d.faces_by_axis(axis).map { |face| keb.face_center(face).to_p } },
          style: Kuix::POINT_STYLE_CIRCLE,
          stroke_color: Kuix::COLOR_DARK_GREY,
          fill_color: Kuix::COLOR_WHITE
        )
        k_points.transformation = et
        @tool.append_3d(k_points, LAYER_3D_GRIPS_PREVIEW)

      end

      _preview_active_cutters(view)
      _preview_active_axis

    end

    def _preview_reshape_cutter_move(view)
      _preview_active_cutters(view)
    end

    def _preview_reshape_cutter_add(view)
      _preview_active_cutters(view)
    end

    def _preview_reshape_cutter_remove(view)
      _preview_active_cutters(view)
    end

    def _preview_reshape(view)
      return super if (stretch_def = _get_stretch_def(@picked_reshape_start_point, @mouse_snap_point)).nil?

      split_def, edvs, lps, lpe = stretch_def.values_at(:split_def, :edvs, :lps, :lpe)
      et, container_defs = split_def.values_at(:et, :container_defs)

      color = _get_vector_color(lps.vector_to(lpe))

      container_defs.each do |container_def|

        k_segments = Kuix::Segments.new
        k_segments.add_segments(container_def.edge_defs.flat_map { |edge_def|
          edge = edge_def.edge
          t = edge_def.transformation
          ti = t.inverse
          [
            edge.start.position.offset(edvs[edge_def.start_section_def].transform(ti)).transform(t),
            edge.end.position.offset(edvs[edge_def.end_section_def].transform(ti)).transform(t)
          ]
        })
        k_segments.color = color
        k_segments.line_width = 1.5
        k_segments.transformation = et
        @tool.append_3d(k_segments, LAYER_3D_RESHAPE_PREVIEW)

      end

      # eti = et.inverse
      # epmin, eps, epe, evpspe, reversed, section_defs = split_def.values_at(:epmin, :eps, :epe, :evpspe, :reversed, :section_defs)
      # l = [ epmin, evpspe ]
      # epo = reversed ? lpe.transform(eti) : eps
      # epomax = reversed ? eps : lpe.transform(eti)
      # sd = section_defs
      # sd = sd.reverse if reversed
      # rs = sd
      #        .select { |section_def| section_def.bounds.valid? }
      #        .each_cons(2).map { |section_def0, section_def1|
      #   [
      #     section_def0.bounds.max.project_to_line(l).offset!(edvs[section_def0]),
      #     section_def1.bounds.min.project_to_line(l).offset!(edvs[section_def1]),
      #     Geom.linear_combination(0.5, section_def0.bounds.max.project_to_line(l).offset!(edvs[section_def0]),
      #                             0.5, section_def1.bounds.min.project_to_line(l).offset!(edvs[section_def1]))
      #   ]
      # }
      #
      # rs.each do |pmin, pmax, pl|
      #   k_points = _create_floating_points(points: [pmin, pmax], stroke_color: Kuix::COLOR_BLACK)
      #   k_points.transformation = et
      #   @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)
      #   k_points = _create_floating_points(points: pl, stroke_color: Kuix::COLOR_YELLOW)
      #   k_points.transformation = et
      #   @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)
      # end
      # k_points = _create_floating_points(points: epo, fill_color: Kuix::COLOR_YELLOW)
      # k_points.transformation = et
      # @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)
      # k_points = _create_floating_points(points: epomax, fill_color: Kuix::COLOR_MAGENTA)
      # k_points.transformation = et
      # @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)


      # colors = [ Kuix::COLOR_CYAN, Kuix::COLOR_MAGENTA, Kuix::COLOR_YELLOW ]
      #
      # section_defs, _ = split_def.values_at(:section_defs)
      # section_defs.each do |section_def|
      #
      #   dv = edvs[section_def]
      #
      #   # if section_def.bounds.valid?
      #   #   k_box = Kuix::BoxMotif.new
      #   #   k_box.bounds.copy!(section_def.bounds)
      #   #   k_box.bounds.translate!(*dv.to_a) if dv.valid?
      #   #   k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      #   #   k_box.line_wi dth = 2
      #   #   k_box.color = colors[section_def.index % colors.length]
      #   #   k_box.transformation = et
      #   #   @tool.append_3d(k_box, LAYER_3D_RESHAPE_PREVIEW)
      #   # end
      #
      #   if section_def.bounds.valid?
      #     k_box = Kuix::BoxMotif.new
      #     k_box.bounds.copy!(section_def.bounds)
      #     k_box.bounds.translate!(*dv.to_a)
      #     k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      #     k_box.line_width = 2
      #     k_box.color = colors[section_def.index % colors.length]
      #     k_box.transformation = et
      #     @tool.append_3d(k_box, LAYER_3D_RESHAPE_PREVIEW)
      #   end
      #
      # end

      # Preview line

      color = _get_vector_color(@picked_axis.transform(et), Kuix::COLOR_DARK_GREY)

      k_edge = Kuix::EdgeMotif.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.color = ColorUtils.color_translucent(color, 60)
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_RESHAPE_PREVIEW)

      k_edge = Kuix::EdgeMotif.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.color = color
      @tool.append_3d(k_edge, LAYER_3D_RESHAPE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ lps, lpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_RESHAPE_PREVIEW)
      @tool.append_3d(_create_floating_points(points: @picked_reshape_start_point, style: Kuix::POINT_STYLE_CIRCLE, stroke_color: nil, fill_color: color, size: 2), LAYER_3D_RESHAPE_PREVIEW)

      # Preview distance

      distance = lps.distance(lpe)

      Sketchup.set_status_text(distance, SB_VCB_VALUE)

      if distance > 0

        k_label = _create_floating_label(
          snap_point: Geom.linear_combination(0.5, lps, 0.5, lpe),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_reshape(tool, text, view)
      return super if (stretch_def = _get_stretch_def(@picked_reshape_start_point, @mouse_snap_point)).nil?

      emv, lps, lpe, split_def = stretch_def.values_at(:emv, :lps, :lpe, :split_def)
      max_compression_distance, reversed = split_def.values_at(:max_compression_distance, :reversed)
      v = lps.vector_to(lpe)

      distance = _read_user_text_length(tool, text, v.length)
      return true if distance.nil?

      # Error if distance < 0 and the measure type is outside
      if _fetch_option_stretch_measure_type_outside && distance < 0
        tool.notify_errors([ [ "tool.default.error.invalid_length", { :value => distance.to_l } ] ])
        return false
      end

      # Error if max distance exceeded
      compressed = emv.valid? && (reversed ? emv.samedirection?(@picked_axis) : !emv.samedirection?(@picked_axis))
      compressed = !compressed if distance < 0
      if compressed && @picked_reshape_start_point.distance(lps.offset(v, distance)) > max_compression_distance
        tool.notify_errors([ [ "tool.default.error.gt_max_distance", { :value1 => distance.abs.to_l, :value2 => max_compression_distance.abs.to_l } ] ])
        return false
      end

      @picked_reshape_end_point = lps.offset(v, distance)

      _reshape_entity
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # -----

    def _get_drawing_def_parameters
      {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: false,
        ignore_soft_edges: false,
        ignore_clines: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
      }
    end

    # -----

    def _get_xyz_method
      { X_AXIS => :x, Y_AXIS => :y, Z_AXIS => :z }[@picked_axis]
    end

    def _assert_valid_cutters
      return false if !@cutters.is_a?(Hash) ||
                      @picked_axis.nil? ||
                      !(ratios = @cutters[@picked_axis]).is_a?(Array) || ratios.empty? ||
                      (section_defs, _ = _get_split_def.values_at(:section_defs)).nil?

      xyz_method = _get_xyz_method

      # Check section pt_boxes oversize
      unless section_defs.all? { |section_def| !section_def.bounds.valid? || section_def.min_xyz <= section_def.bounds.min.send(xyz_method) && section_def.max_xyz >= section_def.bounds.max.send(xyz_method) }
        UI.beep
        @tool.notify_errors([ "tool.smart_reshape.error.curve_intersect" ])
        return false
      end

      true
    end

    # -----

    def _reshape_entity
      _stretch_entity
    end

    def _stretch_entity
      return if (stretch_def = _get_stretch_def(@picked_reshape_start_point, @picked_reshape_end_point, true)).nil?

      split_def, emv, edvs, lpe = stretch_def.values_at(:split_def, :emv, :edvs, :lpe)
      et, eps, evpspe, reversed, section_defs, container_defs = split_def.values_at(:et, :eps, :evpspe, :reversed, :section_defs, :container_defs)

      _unhide_instances

      model = Sketchup.active_model
      model.start_operation('OCL Stretch Part', true, false, !active?)

        sorting_order = (emv.valid? && emv.samedirection?(evpspe)) ? -1 : 1

        container_defs
          .group_by { |container_def| container_def.section_def }
          .each do |section_def, container_defs|

          edv = edvs[section_def]

          container_defs.each do |container_def|

            drawing_container_def = container_def.drawing_container_def
            container = drawing_container_def.container
            entities = container.respond_to?(:entities) ? container.entities : container.definition.entities

            # Move edges
            # ----------

            container_def.edge_defs
                          .select { |edge_def| edge_def.operation == SplitEdgeDef::OPERATION_MOVE }
                          .group_by { |edge_def| edge_def.start_section_def }
                          .sort_by { |edge_section_def, _| edge_section_def.index * sorting_order }.to_h
                          .each do |edge_section_def, edge_defs|

              edge_edv = edvs[edge_section_def]

              edge_def0 = edge_defs.first
              t = edge_def0.transformation

              target_position0 = edge_def0.ref_position
              target_position0 = target_position0.offset(edge_edv.transform(t.inverse)) if edge_edv.valid?
              current_position0 = edge_def0.edge.start.position

              v = current_position0.vector_to(target_position0)

              entities.transform_entities(Geom::Transformation.translation(v), edge_defs.map { |edge_def| edge_def.edge }) if v.valid?

            end

            # Move container
            # --------------

            next if container_def.operation != SplitContainerDef::OPERATION_MOVE || section_def.nil?

            t = drawing_container_def.transformation

            target_position = container_def.ref_position
            target_position = target_position.offset(edv.transform(t.inverse)) if edv.valid?
            current_position = ORIGIN.transform(container.transformation)

            v = current_position.vector_to(target_position)

            container.transform!(Geom::Transformation.translation(v)) if v.valid?

          end

        end

        # Adjust cutters
        eti = et.inverse
        epo = reversed ? lpe.transform(eti) : eps
        epomax = reversed ? eps : lpe.transform(eti)
        distance = epo.distance(epomax)
        el = [ epo, evpspe ]
        sd = section_defs
        sd = sd.reverse if reversed
        @cutters[@picked_axis] = sd
           .select { |section_def| section_def.bounds.valid? } # Exclude empty sections
           .each_cons(2).map { |section_def0, section_def1|
              max0 = section_def0.bounds.max.project_to_line(el).offset!(edvs[section_def0])
              min1 = section_def1.bounds.min.project_to_line(el).offset!(edvs[section_def1])
              if (v = max0.vector_to(min1)).valid? && v.samedirection?(@picked_axis)  # Exclude if bounds overlap
                epc = Geom.linear_combination(0.5, max0, 0.5, min1)
                epo.vector_to(epc).length / distance
              end
            }
           .compact
        _store_cutters
        _load_cutters

      model.commit_operation

    end

    # -----

    def _get_cutters_holder
      if (instances = _get_instances).is_a?(Array) && instances.one? &&
         (instance = instances.first).respond_to?(:definition)
        return instance.definition
      end
      nil
    end

    def _store_cutters
      if @cutters
        data = {
          'x' => @cutters[X_AXIS],
          'y' => @cutters[Y_AXIS],
          'z' => @cutters[Z_AXIS],
        }
        if (holder = _get_cutters_holder)
          PLUGIN.set_attribute(holder, "stretch_cutters", data)
        else
          @@last_cutters_data = data
        end
      end
    end

    def _load_cutters
      if (holder = _get_cutters_holder)
        data = PLUGIN.get_attribute(holder, "stretch_cutters")
      else
        data = @@last_cutters_data
      end
      fn_valid_cutters = lambda { |cutters, xyz|
        if cutters.is_a?(Hash) &&
           cutters[xyz].is_a?(Array) &&
           (valid_cutters = cutters[xyz].map { |v| v.to_f }.select { |v| v > 0 && v < 1.0 }).any?
          valid_cutters
        else
          [ 0.5 ]
        end
      }
      @cutters = {
        X_AXIS => fn_valid_cutters.call(data, 'x'),
        Y_AXIS => fn_valid_cutters.call(data, 'y'),
        Z_AXIS => fn_valid_cutters.call(data, 'z'),
      }
    end

    # -----

    def _get_split_def
      return @split_def unless @split_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return nil if @picked_grip_index.nil?

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      det = drawing_def.transformation.inverse * et

      # Compute a new drawing_def that include subparts
      return nil unless (drawing_def = CommonDrawingDecompositionWorker.new(_get_drawing_def_ipaths, **(_get_drawing_def_parameters.merge(
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL,
        flatten: false,
      ))).run).is_a?(DrawingDef)

      # Transform drawing_def to be expressed in the edit space
      drawing_def.transform!(det)

      grip_index_s = Kuix::Bounds3d.face_opposite(@picked_grip_index)
      grip_index_e = @picked_grip_index

      eps = keb.face_center(grip_index_s).to_p
      epe = keb.face_center(grip_index_e).to_p
      evpspe = eps.vector_to(epe)

      reversed = !evpspe.samedirection?(@picked_axis)

      epmin = reversed ? epe : eps
      epmax = reversed ? eps : epe

      container_defs = []

      v_s = {}  # Vertex => DrawingContainerDef => SectionDef

      reversed = evpspe.valid? && !evpspe.samedirection?(@picked_axis)
      xyz_method = _get_xyz_method

      ratios = @cutters[@picked_axis].sort
      ratios.uniq!
      ratios.reverse!.map! { |ratio| 1 - ratio } if reversed

      section_defs = ([ Float::INFINITY * (reversed ? 1 : -1) ] + ratios.map { |ratio| eps.send(xyz_method) + ratio * evpspe.length * (reversed ? -1 : 1) } + [ Float::INFINITY * (reversed ? -1 : 1) ]).each_cons(2).map.with_index { |min_max, index|
        SplitSectionDef.new(
          index,
          min_max.min,
          min_max.max,
          Geom::BoundingBox.new
        )
      }

      fn_store_vertex_section_def = lambda { |vertex, drawing_container_def, section_def|
        v_s[vertex] ||= {}
        v_s[vertex][drawing_container_def] = section_def
      }
      fn_fetch_vertex_section_def = lambda { |vertex, drawing_container_def|
        v_s[vertex] ||= {}
        v_s[vertex][drawing_container_def]
      }

      fn_analyse = lambda do |drawing_container_def, parent_section_def = nil, depth = 0|

        # Extract container
        # -----------------

        # k_box = Kuix::BoxMotif.new
        # k_box.bounds.copy!(drawing_container_def.bounds)
        # k_box.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        # k_box.line_width = 2
        # k_box.color = [ Kuix::COLOR_RED, Kuix::COLOR_GREEN, Kuix::COLOR_BLUE, Kuix::COLOR_MAGENTA ][depth % 4]
        # k_box.transformation = et
        # @tool.append_3d(k_box, LAYER_3D_PART_PREVIEW)

        section_def = parent_section_def
        if section_def.nil?

          # Check if the container is glued or always face camera to search the section according to its origin only
          if drawing_container_def.container.respond_to?(:glued_to) && drawing_container_def.container.glued_to ||
             drawing_container_def.container.respond_to?(:definition) && (drawing_container_def.container.definition.behavior.always_face_camera? || drawing_container_def.container.definition.behavior.no_scale_mask? == 127)

            container_origin = ORIGIN.transform(drawing_container_def.transformation * drawing_container_def.container.transformation)
            section_def = section_defs.find { |section_def| section_def.contains_point?(container_origin, xyz_method) }

            operation = SplitContainerDef::OPERATION_MOVE

          else

            # Check if container bounds is entirely inside a section
            section_def = section_defs.find { |section_def| section_def.contains_bounds?(drawing_container_def.bounds, xyz_method) }
            if section_def.nil?

              # Default container section_def is where its bounds min is
              # section_def = section_defs.find { |section_def| section_def.contains_point?(drawing_container_def.bounds.min, xyz_method) } if section_def.nil?

              operation = SplitContainerDef::OPERATION_SPLIT

            else

              # Add to section bounds
              section_def.bounds.add(drawing_container_def.bounds)

              operation = SplitContainerDef::OPERATION_MOVE

            end

          end

        else
          operation = SplitContainerDef::OPERATION_NONE
        end

        container_def = SplitContainerDef.new(
          drawing_container_def,
          depth,
          drawing_container_def.container.respond_to?(:transformation) ? ORIGIN.transform(drawing_container_def.container.transformation) : nil,
          section_def,
          [],
          [],
          operation
        )
        container_defs << container_def

        # Keep container section as entire parent section
        parent_section_def = section_def

        # k_box = Kuix::BoxMotif.new
        # k_box.bounds.copy!(drawing_container_def.bounds)
        # k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        # k_box.line_width = 2
        # k_box.color = [ Kuix::COLOR_YELLOW, Kuix::COLOR_CYAN, Kuix::COLOR_MAGENTA ][(section_def.index % 3) - 1]
        # k_box.transformation = et
        # @tool.append_3d(k_box, LAYER_3D_PART_PREVIEW)

        # Extract edges
        # -------------

        # 1. Iterate on curves

        drawing_container_def.curve_manipulators.each do |cm|

          # Treat curves as a whole undeformable entity

          section_def = parent_section_def
          section_def = fn_fetch_vertex_section_def.call(cm.curve.first_edge.start, drawing_container_def) if section_def.nil?
          section_def = fn_fetch_vertex_section_def.call(cm.curve.last_edge.end, drawing_container_def) if section_def.nil?
          section_def = section_defs.find { |s| s.intersects_bounds?(cm.bounds, xyz_method) } if section_def.nil?
          unless section_def.nil?
            cm.curve.edges.each do |edge|
              container_def.edge_defs << SplitEdgeDef.new(
                edge,
                cm.transformation,
                edge.start.position,
                section_def,
                section_def,
                operation == SplitContainerDef::OPERATION_NONE ? SplitEdgeDef::OPERATION_NONE : SplitEdgeDef::OPERATION_MOVE
              )
              fn_store_vertex_section_def.call(edge.start, drawing_container_def, section_def)
              fn_store_vertex_section_def.call(edge.end, drawing_container_def, section_def)
            end
            section_def.bounds.add(cm.points)  # Add to section bounds
          end

        end

        # 2. Iterate on edges

        drawing_container_def.edge_manipulators.each do |em|

          next if !parent_section_def.nil? && em.edge.soft? # Minor optimization - skip soft edges if container grabbed

          if parent_section_def.nil?
            start_section_def = fn_fetch_vertex_section_def.call(em.edge.start, drawing_container_def)
            if start_section_def.nil?
              start_section_def = section_defs.find { |s| s.contains_point?(em.start_point, xyz_method) }
              fn_store_vertex_section_def.call(em.edge.start, drawing_container_def, start_section_def)
            end
            end_section_def = fn_fetch_vertex_section_def.call(em.edge.end, drawing_container_def)
            if end_section_def.nil?
              end_section_def = section_defs.find { |s| s.contains_point?(em.end_point, xyz_method) }
              fn_store_vertex_section_def.call(em.edge.end, drawing_container_def, end_section_def)
            end
          else
            start_section_def = end_section_def = parent_section_def
          end

          next if start_section_def.nil? || end_section_def.nil?  # TODO : this should not occur

          container_def.edge_defs << SplitEdgeDef.new(
            em.edge,
            em.transformation,
            em.edge.start.position,
            start_section_def,
            end_section_def,
            if operation == SplitContainerDef::OPERATION_SPLIT
              start_section_def == end_section_def ? SplitEdgeDef::OPERATION_MOVE : SplitEdgeDef::OPERATION_SPLIT
            else
              SplitEdgeDef::OPERATION_NONE
            end
          )

          if parent_section_def.nil? &&
             start_section_def == end_section_def &&
             em.edge.start.edges.all? { |edge| edge.curve.nil? } && em.edge.end.edges.all? { |edge| edge.curve.nil? }
            start_section_def.bounds.add(em.points)  # Add to content bbox
          end

        end

        # 3. Iterate over children

        depth += 1
        drawing_container_def.container_defs.each do |child_drawing_container_def|
          container_def.children << fn_analyse.call(child_drawing_container_def, parent_section_def, depth)
        end

        container_def
      end

      fn_analyse.call(drawing_def)

      puts "----"
      container_defs.each do |container_def|
        puts "#{"".rjust(container_def.depth)}#{container_def.drawing_container_def.container.name} (op: #{container_def.operation}) -> #{container_def.md5(@picked_axis)} "
      end
      puts "----"



      # Compute max compression distance
      el = [ eps, evpspe ]
      sd = section_defs
      sd = sd.reverse if reversed
      min_distance = sd
        .select { |section_def| section_def.bounds.valid? }
        .each_cons(2).map { |section_def0, section_def1|
          section_def0.bounds.max.project_to_line(el).transform(et).distance(section_def1.bounds.min.project_to_line(el).transform(et))
        }
        .min
      min_distance = 0 if min_distance.nil?
      max_compression_distance = [ (min_distance * (section_defs.size - 1)) - 1.mm, 0 ].max # Keep 1mm to avoid geometry merge problems

      @split_def = {
        drawing_def: drawing_def,
        et: et,
        eb: eb,   # Expressed in 'Edit' space
        epmin: epmin,
        epmax: epmax,
        eps: eps,
        epe: epe,
        evpspe: evpspe,
        reversed: reversed,
        max_compression_distance: max_compression_distance,
        section_defs: section_defs,
        container_defs: container_defs,
      }
    end

    def _get_unique_split_def
      return nil unless (split_def = _get_split_def).is_a?(Hash)

      container_defs, _ = split_def.values_at(:container_defs)

      split_def
    end

    def _get_stretch_def(ps, pe, make_unique = false)
      return nil unless (split_def = (make_unique ? _get_unique_split_def : _get_split_def)).is_a?(Hash)

      et, eps, max_compression_distance, section_defs, reversed = split_def.values_at(:et, :eps, :max_compression_distance, :section_defs, :reversed)
      eti = et.inverse

      mv = ps.vector_to(pe)     # Move vector in global space
      emv = mv.transform(eti)   # Move vector in edit space

      # Limit move to max compression distance
      compressed = emv.valid? && (reversed ? emv.samedirection?(@picked_axis) : !emv.samedirection?(@picked_axis))
      if compressed && mv.length > max_compression_distance
        pe = ps.offset(mv, max_compression_distance)
        mv = ps.vector_to(pe)
        emv = mv.transform(eti)
      end

      # Compute move vectors for each section
      edvs = section_defs.map { |section_def|
        edv = Geom::Vector3d.new(emv)
        edv.length = edv.length * section_def.index / (section_defs.length - 1) if emv.valid?
        [ section_def, edv ]
      }.to_h

      lps = _fetch_option_stretch_measure_type_outside ? eps.transform(et) : ps
      lpe = pe

      {
        split_def: split_def,
        emv: emv,
        edvs: edvs,
        lps: lps,
        lpe: lpe,
      }
    end

    # -----

    SplitSectionDef = Struct.new(:index, :min_xyz, :max_xyz, :bounds) {
      def contains_point?(point, xyz_method)
        min_xyz <= point.send(xyz_method) && max_xyz >= point.send(xyz_method)
      end
      def contains_bounds?(bounds, xyz_method)
        min_xyz <= bounds.min.send(xyz_method) && max_xyz >= bounds.max.send(xyz_method)
      end
      def intersects_bounds?(bounds, xyz_method)
        min_xyz <= bounds.max.send(xyz_method) && max_xyz >= bounds.min.send(xyz_method)
      end
    }

    SplitContainerDef = Struct.new(:drawing_container_def, :depth, :ref_position, :section_def, :edge_defs, :children, :operation) {
      def md5(axis)
        if @md5.nil?
          data = []
          data = [ drawing_container_def.container.definition.object_id ] if drawing_container_def.container.respond_to?(:definition)
          if operation == SplitContainerDef::OPERATION_SPLIT

            unless drawing_container_def.is_root?
              local_axis = axis.transform((drawing_container_def.transformation * drawing_container_def.container.transformation).inverse)
              data << (local_axis.parallel?(axis) || local_axis.perpendicular?(axis)) if local_axis.valid?
              data << local_axis.length if local_axis.valid?
            end

            data << edge_defs.map { |edge_def| edge_def.md5 }.join
            data << children.map { |container_def| container_def.md5(axis) }.join

          end
          @md5 = Digest::MD5.hexdigest(data.to_json)
        end
        @md5
      end
    }
    SplitContainerDef::OPERATION_NONE = 0
    SplitContainerDef::OPERATION_MOVE = 1
    SplitContainerDef::OPERATION_SPLIT = 2

    SplitEdgeDef = Struct.new(:edge, :transformation, :ref_position, :start_section_def, :end_section_def, :operation) {
      def md5
        data = [
          edge.object_id,
          start_section_def.index,
          end_section_def.index
        ]
        Digest::MD5.hexdigest(data.to_json)
      end
    }
    SplitEdgeDef::OPERATION_NONE = 0
    SplitEdgeDef::OPERATION_MOVE = 1
    SplitEdgeDef::OPERATION_SPLIT = 2

  end

end