module Ladb::OpenCutList

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

      @definition = nil
      @instances = []
      @drawing_def = nil

    end

    # ------

    def start
      super

      return if (model = Sketchup.active_model).nil?
      selection = model.selection

      # Try to copy the previous action handler selection
      if @previous_action_handler &&
         (part_entity_path = @previous_action_handler.get_active_part_entity_path) &&
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

      else

        # Try to select part from the current selection
        entity = selection.min { |a, b| a.entityID <=> b.entityID } # Smaller entityId == Older entity
        if entity.is_a?(Sketchup::ComponentInstance)
          active_path = model.active_path.is_a?(Array) ? model.active_path : []
          path = active_path + [ entity ]
          part_entity_path = _get_part_entity_path_from_path(path)
          _make_unique_groups_in_path(part_entity_path)
          unless (part = _generate_part_from_path(part_entity_path)).nil?

            _set_active_part(part_entity_path, part)

            if _pick_part_siblings?

              part_entity = part_entity_path.last
              part_definition = part_entity.definition

              entities = selection.select { |e| e != part_entity && e.is_a?(Sketchup::ComponentInstance) && e.definition == part_definition }
              entities.each do |entity|

                sibling_path = active_path + [ entity ]
                part_sibling_entity_path = _get_part_entity_path_from_path(sibling_path)
                unless (part_sibling = _generate_part_from_path(part_sibling_entity_path)).nil?
                  _add_part_sibling(part_sibling_entity_path, part_sibling)
                end

              end

            end

            onPartSelected

          end
        end

      end

      # Clear current selection
      selection.clear if _clear_selection_on_start

    end

    # -- STATE --

    def get_startup_state
      STATE_SELECT
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

      case state

      when STATE_SELECT, STATE_SELECT_SIBLINGS, STATE_RESHAPE_START, STATE_RESHAPE
        return PLUGIN.get_i18n_string("tool.smart_handle.action_#{@action}_state_#{state}_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)
      super
    end

    # -----

    def onToolCancel(tool, reason, view)

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

      when STATE_RESHAPE_START

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

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
      @tool.remove_3d([LAYER_3D_RESHAPE_PREVIEW ])
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onToolLButtonDown(tool, flags, x, y, view)

      case @state

      when STATE_SELECT
        if @active_part_entity_path.is_a?(Array) && _pick_part_siblings?
          set_state(STATE_SELECT_SIBLINGS)
          return true
        end

      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      @mouse_down_point = nil

      case @state

      when STATE_SELECT, STATE_SELECT_SIBLINGS
        if @active_part_entity_path.nil?
          UI.beep
          return true
        end
        onPartSelected

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
      return if (instance = _get_instance).nil?

      sibling_instances = _get_sibling_instances

      @instances << instance
      @instances.concat(sibling_instances) if sibling_instances.is_a?(Array)
      @definition = instance.definition

      @src_transformation = Geom::Transformation.new(instance.transformation)

      @global_context_transformation = nil
      @global_instance_transformation = nil
      @drawing_def = nil

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(_get_drawing_def, et)

      @picked_reshape_start_point = eb.center.transform(et)

    end

    def onToolActionOptionStored(tool, action, option_group, option)

      if option_group == SmartReshapeTool::ACTION_OPTION_AXES && !@active_part.nil?

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(_get_drawing_def, et)

        @picked_reshape_start_point = eb.center.transform(et)

      end

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
      @definition = nil
      @instances.clear
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
        ignore_clines: false
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

    def _get_drawing_def_edit_bounds(drawing_def, et)
      eb = Geom::BoundingBox.new
      if drawing_def.is_a?(DrawingDef)

        points = drawing_def.face_manipulators.flat_map { |manipulator| manipulator.outer_loop_manipulator.points }
        eti = et.inverse

        eb.add(points.map { |point| point.transform(eti * drawing_def.transformation) })

      end
      eb
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

    STATE_RESHAPE_SECTION_MOVE = 10
    STATE_RESHAPE_SECTION_ADD = 11
    STATE_RESHAPE_SECTION_REMOVE = 12

    LAYER_3D_GRIPS_PREVIEW = 100
    LAYER_3D_SECTIONS_PREVIEW = 200

    INFLATE_VALUE = 10

    CENTER_INDICES = [
      Kuix::Bounds3d::TOP,
      Kuix::Bounds3d::BOTTOM,
      Kuix::Bounds3d::LEFT,
      Kuix::Bounds3d::RIGHT,
      Kuix::Bounds3d::FRONT,
      Kuix::Bounds3d::BACK,
    ]

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_STRETCH, tool, previous_action_handler)

      @snap_axis = nil
      @picked_grip_index = -1

      @sections = nil

      @picked_section_index = nil
      @picked_section_start_point = nil

    end

    # -----

    def start
      super
    end

    def stop
      _unhide_instance
      super
    end

    # -----

    def onToolSuspend(tool, view)
      _unhide_instance if @state != STATE_SELECT
    end

    def onToolResume(tool, view)
      super
      # _hide_instance if @state != STATE_SELECT
    end

    def onToolLButtonDown(tool, flags, x, y, view)

      case @state

      when STATE_RESHAPE_START
        if @picked_section_index

          drawing_def = _get_drawing_def
          et = _get_edit_transformation
          eb = _get_drawing_def_edit_bounds(drawing_def, et)

          direction = @snap_axis.transform(et)
          min = eb.min.transform(et)
          max = eb.max.transform(et)
          max_plane = [ max, direction ]
          vmax = min.vector_to(min.project_to_plane(max_plane))

          plane = [min.offset(vmax, vmax.length * @sections[@snap_axis][@picked_section_index]), direction ]

          @picked_section_start_point = Geom.intersect_line_plane(view.pickray(x, y), plane)

          set_state(STATE_RESHAPE_SECTION_MOVE)
          _refresh
          return true
        end

        if @picked_grip_index

          drawing_def = _get_drawing_def
          et = _get_edit_transformation
          eb = _get_drawing_def_edit_bounds(drawing_def, et)
          b = Kuix::Bounds3d.new.copy!(eb)

          @mouse_down_point = b.face_center(@picked_grip_index).to_p.transform(et)

          return true
        end

        return true

      when STATE_RESHAPE_SECTION_ADD, STATE_RESHAPE_SECTION_REMOVE
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
          b = Kuix::Bounds3d.new.copy!(eb)

          @picked_reshape_start_point = b.face_center(@picked_grip_index).to_p.transform(et)

          set_state(STATE_RESHAPE)
          _refresh
          return true
        end
        unless @picked_section_index
          return true
        end

      when STATE_RESHAPE_SECTION_MOVE
        if @picked_section_index
          set_state(STATE_RESHAPE_START)
          _refresh
          return true
        end

      when STATE_RESHAPE_SECTION_ADD
        if @snap_ratio
          @sections[@snap_axis] << @snap_ratio
          @snap_ratio = nil
          _refresh
        end
        return true

      when STATE_RESHAPE_SECTION_REMOVE
        if @picked_section_index
          @sections[@snap_axis].delete_at(@picked_section_index)
          @picked_section_index = nil
          _refresh
        end
        return true

      # when STATE_RESHAPE
      #   if @picked_grip_index
      #     _reshape_entity
      #     @drawing_def = nil
      #     set_state(STATE_RESHAPE_START)
      #     _refresh
      #     return true
      #   end

      end

      super
    end

    def onToolMouseMove(tool, flags, x, y, view)
      case @state

      when STATE_RESHAPE_START
        @tool.remove_3d([ LAYER_3D_SECTIONS_PREVIEW, LAYER_3D_GRIPS_PREVIEW  ])

      end

      return true if super

      case @state

      when STATE_RESHAPE_START
        unless @mouse_down_point.nil? || @picked_grip_index.nil?
          @picked_reshape_start_point = @mouse_down_point
          @mouse_down_point = nil
          set_state(STATE_RESHAPE)
        end

      when STATE_RESHAPE_SECTION_MOVE

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d([ LAYER_3D_SECTIONS_PREVIEW ])

        _snap_handle_section_move(flags, x, y, view)
        _preview_reshape_section_move(view)

      when STATE_RESHAPE_SECTION_ADD

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d([ LAYER_3D_SECTIONS_PREVIEW ])

        _snap_reshape_section_add(flags, x, y, view)
        _preview_reshape_section_add(view)

      when STATE_RESHAPE_SECTION_REMOVE

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d([ LAYER_3D_SECTIONS_PREVIEW ])

        _snap_reshape_section_remove(flags, x, y, view)
        _preview_reshape_section_remove(view)

      end

      false
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      case @state

      when STATE_RESHAPE_START
        if tool.is_key_ctrl_or_option?(key)
          set_state(STATE_RESHAPE_SECTION_ADD)
          _refresh
          return true
        end
        if tool.is_key_alt_or_command?(key)
          set_state(STATE_RESHAPE_SECTION_REMOVE)
          _refresh
          return true
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      case @state

      when STATE_RESHAPE_SECTION_ADD, STATE_RESHAPE_SECTION_REMOVE
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

    def onStateChanged(state)
      super

      unless _get_instance.nil?

        case state

        when STATE_SELECT
          _unhide_instance

        when STATE_RESHAPE_START
          @tool.remove_3d(LAYER_3D_PART_PREVIEW)  # Remove part preview
          _unhide_instance

        when STATE_RESHAPE_SECTION_MOVE
          @tool.remove_3d(LAYER_3D_GRIPS_PREVIEW)
          _unhide_instance

        when STATE_RESHAPE_SECTION_ADD, STATE_RESHAPE_SECTION_REMOVE
          @tool.remove_3d(LAYER_3D_GRIPS_PREVIEW)
          _unhide_instance

        when STATE_RESHAPE
          @tool.remove_3d([ LAYER_3D_GRIPS_PREVIEW, LAYER_3D_SECTIONS_PREVIEW ])
          _hide_instance

        end

      end

    end

    def onPartSelected

      instance = _get_instance

      @instances << instance
      @definition = instance.definition
      @drawing_def = nil

      @src_transformation = Geom::Transformation.new(instance.transformation)

      @sections = {
        X_AXIS => [ 0.5 ],
        Y_AXIS => [ 0.5 ],
        Z_AXIS => [ 0.5 ],
      }

      set_state(STATE_RESHAPE_START)
      _refresh

    end

    # -----

    protected

    def _reset
      @snap_axis = nil
      @picked_grip_index = -1
      @picked_section_index = nil
      super
    end

    # -----

    def _snap_reshape_start(flags, x, y, view)

      @mouse_ip.clear

      @picked_grip_index = nil
      @picked_section_index = nil

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      b = Kuix::Bounds3d.new.copy!(eb)

      pk = view.pick_helper(x, y, 40)
      CENTER_INDICES.each do |i|
        p = b.face_center(i).to_p.transform(et)
        if pk.test_point(p)
          if i == Kuix::Bounds3d::TOP || i == Kuix::Bounds3d::BOTTOM
            @snap_axis = Z_AXIS
          elsif i == Kuix::Bounds3d::LEFT || i == Kuix::Bounds3d::RIGHT
            @snap_axis = X_AXIS
          else
            @snap_axis = Y_AXIS
          end
          @picked_grip_index = i
          @mouse_snap_point = p
          return true
        end
      end

      unless @sections.nil? || @snap_axis.nil?

        direction = @snap_axis.transform(et)
        min = eb.min.transform(et)
        max = eb.max.transform(et)
        min_plane = [ min, direction ]
        max_plane = [ max, direction ]
        vmax = min.vector_to(min.project_to_plane(max_plane))

        if @snap_axis == X_AXIS
          quad_index = Kuix::Bounds3d::LEFT
        elsif @snap_axis == Y_AXIS
          quad_index = Kuix::Bounds3d::FRONT
        elsif @snap_axis == Z_AXIS
          quad_index = Kuix::Bounds3d::BOTTOM
        end

        quad_ref = b.inflate_all!(INFLATE_VALUE).get_quad(quad_index).map { |point| point.transform(et).project_to_plane(min_plane)}

        p2d = Geom::Point3d.new(x, y)
        @sections[@snap_axis].each_with_index do |ratio, index|

          v = Geom::Vector3d.new(vmax)
          v.length = vmax.length * ratio
          t = Geom::Transformation.translation(v)

          polygon = quad_ref.map { |point| view.screen_coords(point.transform(t)) }
          if Geom.point_in_polygon_2D(p2d, polygon, true)
            @picked_section_index = index
            return true
          end

        end

      end

      super
    end

    def _snap_handle_section_move(flags, x, y, view)

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)

      direction = @snap_axis.transform(et)

      # if @mouse_ip.degrees_of_freedom > 2 ||
      #    @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

      picked_point, _ = Geom::closest_points([ @picked_section_start_point, direction ], view.pickray(x, y))
      @mouse_snap_point = picked_point
      @mouse_ip.clear

      # else
      #
      #   # Force picked point to be projected to shape last picked point normal line
      #   @mouse_snap_point = @mouse_ip.position.project_to_line([ @picked_section_start_point, direction ])
      #
      # end

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

      @sections[@snap_axis][@picked_section_index] = ratio

    end

    def _snap_reshape_section_add(flags, x, y, view)

      @mouse_ip.clear

      @snap_ratio = nil
      @picked_section_index = nil

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      direction = @snap_axis.transform(et)

      picked_point, _ = Geom::closest_points([ eb.min, direction ], view.pickray(x, y))
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
        @snap_ratio = [ [ 0, ratio ].max, 1 ].min
      end

    end

    def _snap_reshape_section_remove(flags, x, y, view)

      @mouse_ip.clear

      @picked_section_index = nil

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      b = Kuix::Bounds3d.new.copy!(eb)
      direction = @snap_axis.transform(et)

      unless @sections.nil? || @snap_axis.nil?

        min = eb.min.transform(et)
        max = eb.max.transform(et)
        min_plane = [ min, direction ]
        max_plane = [ max, direction ]
        vmax = min.vector_to(min.project_to_plane(max_plane))

        if @snap_axis == X_AXIS
          quad_index = Kuix::Bounds3d::LEFT
        elsif @snap_axis == Y_AXIS
          quad_index = Kuix::Bounds3d::FRONT
        elsif @snap_axis == Z_AXIS
          quad_index = Kuix::Bounds3d::BOTTOM
        end

        quad_ref = b.inflate_all!(INFLATE_VALUE).get_quad(quad_index).map { |point| point.transform(et).project_to_plane(min_plane)}

        p2d = Geom::Point3d.new(x, y)
        @sections[@snap_axis].each_with_index do |ratio, index|

          v = Geom::Vector3d.new(vmax)
          v.length = vmax.length * ratio
          t = Geom::Transformation.translation(v)

          polygon = quad_ref.map { |point| view.screen_coords(point.transform(t)) }
          if Geom.point_in_polygon_2D(p2d, polygon, true)
            @picked_section_index = index
            return true
          end

        end

      end

    end

    def _snap_reshape(flags, x, y, view)

      et = _get_edit_transformation
      direction = @snap_axis.transform(et)

      if @mouse_ip.degrees_of_freedom > 2 ||
         @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        picked_point, _ = Geom::closest_points([ @picked_reshape_start_point, direction ], view.pickray(x, y))
        @mouse_snap_point = picked_point
        @mouse_ip.clear

      else

        # Force picked point to be projected to shape the last picked point normal line
        @mouse_snap_point = @mouse_ip.position.project_to_line([ @picked_reshape_start_point, direction ])

      end

    end

    def _preview_active_sections
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      b = Kuix::Bounds3d.new.copy!(eb)

      if @snap_axis

        color = _get_vector_color(@snap_axis.transform(et))

        case @snap_axis
        when X_AXIS
          section_ref = b.x_section_min.inflate!(0, INFLATE_VALUE, INFLATE_VALUE)
        when Y_AXIS
          section_ref = b.y_section_min.inflate!(INFLATE_VALUE, 0, INFLATE_VALUE)
        when Z_AXIS
          section_ref = b.z_section_min.inflate!(INFLATE_VALUE, INFLATE_VALUE, 0)
        end

        ratios = @sections[@snap_axis]
        ratios = ratios.dup.push(@snap_ratio) if @snap_ratio
        ratios.each_with_index do |ratio, index|

          section = Kuix::Bounds3d.new.copy!(section_ref)
          section.origin.x += ratio * b.width if @snap_axis == X_AXIS
          section.origin.y += ratio * b.height if @snap_axis == Y_AXIS
          section.origin.z += ratio * b.depth if @snap_axis == Z_AXIS

          is_picked_section = @picked_section_index == index
          is_remove = @state == STATE_RESHAPE_SECTION_REMOVE && is_picked_section
          is_add = @state == STATE_RESHAPE_SECTION_ADD && @snap_ratio && index == ratios.length - 1
          is_highligted = is_picked_section && !is_remove

          section_color = color
          section_color = Kuix::COLOR_DARK_GREY if is_remove

          k_box = Kuix::BoxMotif.new
          k_box.bounds.copy!(section)
          k_box.line_width = is_highligted ? 3 : (is_remove || is_add ? 2 : 1)
          k_box.line_stipple = is_remove || is_add ? Kuix::LINE_STIPPLE_SHORT_DASHES : Kuix::LINE_STIPPLE_SOLID
          k_box.color = section_color
          k_box.transformation = et
          @tool.append_3d(k_box, LAYER_3D_SECTIONS_PREVIEW)

          k_mesh = Kuix::Mesh.new
          k_mesh.add_quads(section.get_quads)
          k_mesh.background_color = ColorUtils.color_translucent(section_color, is_highligted ? 0.6 : 0.3)
          k_mesh.transformation = et
          @tool.append_3d(k_mesh, LAYER_3D_SECTIONS_PREVIEW)

        end

      end
    end

    def _preview_active_axis
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      b = Kuix::Bounds3d.new.copy!(eb)

      if @snap_axis

        color = _get_vector_color(@snap_axis.transform(et))

        case @snap_axis
        when X_AXIS
          p1 = b.face_center(Kuix::Bounds3d::LEFT).to_p
          p2 = b.face_center(Kuix::Bounds3d::RIGHT).to_p
        when Y_AXIS
          p1 = b.face_center(Kuix::Bounds3d::FRONT).to_p
          p2 = b.face_center(Kuix::Bounds3d::BACK).to_p
        when Z_AXIS
          p1 = b.face_center(Kuix::Bounds3d::BOTTOM).to_p
          p2 = b.face_center(Kuix::Bounds3d::TOP).to_p
        end

        k_edge = Kuix::EdgeMotif.new
        k_edge.start.copy!(p1)
        k_edge.end.copy!(p2)
        k_edge.line_width = 1.5
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
            points: b.face_center(@picked_grip_index).to_p,
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
      # return unless (drawing_def_segments = _get_drawing_def_segments(drawing_def)).is_a?(Array)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)

      # Grips

      b = Kuix::Bounds3d.new.copy!(eb)
      k_points = _create_floating_points(
        points: CENTER_INDICES.map { |center| b.face_center(center).to_p },
        style: Kuix::POINT_STYLE_CIRCLE,
        stroke_color: Kuix::COLOR_DARK_GREY,
        fill_color: Kuix::COLOR_WHITE
      )
      k_points.transformation = et
      @tool.append_3d(k_points, LAYER_3D_GRIPS_PREVIEW)

      _preview_active_sections
      _preview_active_axis

    end

    def _preview_reshape_section_move(view)
      _preview_active_sections
    end

    def _preview_reshape_section_add(view)
      _preview_active_sections
    end

    def _preview_reshape_section_remove(view)
      _preview_active_sections
    end

    def _preview_reshape(view)
      return super if (stretch_def = _get_stretch_def(@picked_reshape_start_point, @mouse_snap_point)).nil?

      et, v, lps, lpe, b_defs = stretch_def.values_at(:et, :v, :lps, :lpe, :b_defs)

      colors = [ Kuix::COLOR_CYAN, Kuix::COLOR_MAGENTA, Kuix::COLOR_YELLOW ]

      b_defs.each do |b_def|

        if v.valid?
          dv = Geom::Vector3d.new(v)
          dv.length = dv.length * b_def[:index] / (b_defs.length - 1)
        end

        if b_def[:pt_bbox].valid?
          k_box = Kuix::BoxMotif.new
          k_box.bounds.copy!(b_def[:pt_bbox])
          k_box.bounds.translate!(*dv.to_a) if v.valid?
          k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          k_box.line_width = 2
          k_box.color = colors[b_def[:index] % colors.length]
          k_box.transformation = et
          @tool.append_3d(k_box, LAYER_3D_RESHAPE_PREVIEW)
        end

        unless b_def[:vertices].empty?
          k_points = _create_floating_points(
            points: b_def[:vertices].map { |vertex| v.valid? ? vertex.position.offset(dv) : vertex.position },
            style: Kuix::POINT_STYLE_SQUARE,
            stroke_color: colors[b_def[:index] % colors.length],
            )
          k_points.transformation = et
          @tool.append_3d(k_points, LAYER_3D_RESHAPE_PREVIEW)
        end

      end

      # Preview line

      color = _get_vector_color(v, Kuix::COLOR_DARK_GREY)

      k_edge = Kuix::EdgeMotif.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = ColorUtils.color_translucent(color, 60)
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_RESHAPE_PREVIEW)

      k_edge = Kuix::EdgeMotif.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = color
      @tool.append_3d(k_edge, LAYER_3D_RESHAPE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ lps, lpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_RESHAPE_PREVIEW)

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

      lps, lpe = stretch_def.values_at(:lps, :lpe)
      v = lps.vector_to(lpe)

      distance = _read_user_text_length(tool, text, v.length)
      return true if distance.nil?

      @picked_reshape_end_point = lps.offset(v, distance)

      _reshape_entity
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # -----

    def _reshape_entity
      _stretch_entity
    end

    def _stretch_entity
      return if (stretch_def = _get_stretch_def(@picked_reshape_start_point, @picked_reshape_end_point)).nil?

      v, b_defs = stretch_def.values_at(:v, :b_defs)

      if v.valid?

        instance = _get_instance
        entities = instance.definition.entities

        _unhide_instance

        model = Sketchup.active_model
        model.start_operation('OCL Stretch Part', true, false, !active?)

        b_defs.each do |b_def|
          next if b_def[:vertices].empty?

          dv = Geom::Vector3d.new(v)
          dv.length = dv.length * b_def[:index] / (b_defs.length - 1)

          entities.transform_entities(Geom::Transformation.translation(dv), b_def[:vertices])

        end

        model.commit_operation

      end

    end

    # -----

    def _get_stretch_def(ps, pe)
      return nil if (drawing_def = _get_drawing_def).nil?

      et = _get_edit_transformation
      eti = et.inverse
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      b = Kuix::Bounds3d.new.copy!(eb)

      v = ps.vector_to(pe).transform(eti)

      grip_index_0 = Kuix::Bounds3d.face_opposite(@picked_grip_index)
      grip_index_1 = @picked_grip_index

      p0 = b.face_center(grip_index_0).to_p
      p1 = b.face_center(grip_index_1).to_p
      vmax = p0.vector_to(p1)

      ref_quads = b.get_quad(grip_index_0).map { |point| point }
      quads = ref_quads.dup

      b_defs = []

      ratios = @sections[@snap_axis].sort
      ratios.reverse!.map! { |ratio| 1 - ratio } unless vmax.samedirection?(@snap_axis)
      ratios << 1.0 unless ratios.last == 1.0
      ratios.each_with_index do |ratio, index|

        bbox = Geom::BoundingBox.new
        bbox.add(quads)
        bbox.add(p0.offset(vmax, ratio * vmax.length))

        quads = ref_quads.map { |point| point.offset(vmax, ratio * vmax.length) }

        b_defs << {
          index: index,
          bbox: bbox,
          pt_bbox: Geom::BoundingBox.new,
          vertices: []
        }

      end

      drawing_def.edge_manipulators.each do |em|

        b_defs.each do |b|
          em.edge.vertices.each do |vertex|
            b[:vertices] << vertex if b[:bbox].contains?(vertex.position)
          end
        end

      end

      b_defs.each do |b|
        b[:vertices].uniq!
        b[:pt_bbox].add(b[:vertices].map { |vertex| vertex.position }) unless b[:vertices].empty?
      end

      b_defs.reverse! if v.valid? && v.samedirection?(vmax)

      {
        drawing_def: drawing_def,
        et: et,
        eb: eb,   # Expressed in 'Edit' space
        v: v,
        vmax: vmax,
        lps: _fetch_option_stretch_measure_type == SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE ? p0.transform(et) : ps,
        lpe: pe,
        b_defs: b_defs
      }
    end

  end

end