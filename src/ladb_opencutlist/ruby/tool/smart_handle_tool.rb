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

  class SmartHandleTool < SmartTool

    ACTION_SELECT = 0
    ACTION_COPY_LINE = 1
    ACTION_COPY_GRID = 2
    ACTION_MOVE_LINE = 3
    ACTION_DISTRIBUTE = 4

    ACTION_OPTION_COPY_MEASURE_TYPE = 'copy_measure_type'
    ACTION_OPTION_MOVE_MEASURE_TYPE = 'move_measure_type'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE = 'outside'
    ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE = 'inside'

    ACTION_OPTION_MOVE_MEASURE_TYPE_OUTSIDE = 'outside'
    ACTION_OPTION_MOVE_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_MOVE_MEASURE_TYPE_INSIDE = 'inside'

    ACTION_OPTION_AXES_ACTIVE = 'active'
    ACTION_OPTION_AXES_CONTEXT = 'context'
    ACTION_OPTION_AXES_ENTITY = 'entity'

    ACTION_OPTION_OPTIONS_MIRROR = 'mirror'

    ACTIONS = [
      {
        :action => ACTION_SELECT,
      },
      {
        :action => ACTION_COPY_LINE,
        :options => {
          ACTION_OPTION_COPY_MEASURE_TYPE => [ ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED, ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MIRROR ]
        }
      },
      {
        :action => ACTION_COPY_GRID,
        :options => {
          ACTION_OPTION_COPY_MEASURE_TYPE => [ ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED, ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MIRROR ]
        }
      },
      {
        :action => ACTION_MOVE_LINE,
        :options => {
          ACTION_OPTION_MOVE_MEASURE_TYPE => [ ACTION_OPTION_MOVE_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_MOVE_MEASURE_TYPE_CENTERED, ACTION_OPTION_MOVE_MEASURE_TYPE_INSIDE ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ]
        }
      },
      {
        :action => ACTION_DISTRIBUTE,
        :options => {
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ]
        }
      }
    ].freeze

    # -----

    attr_reader :callback_action_handler,
                :cursor_select, :cursor_select_part, :cursor_select_part_plus, :cursor_select_rect, :cursor_select_copy_line, :cursor_select_copy_grid, :cursor_select_move_line, :cursor_select_distribute, :cursor_move, :cursor_move_copy, :cursor_pin_1, :cursor_pin_2

    def initialize(current_action: nil, callback_action_handler: nil)
      super(current_action: current_action)

      @callback_action_handler = callback_action_handler

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
      @cursor_select_part = create_cursor('select-part', 0, 0)
      @cursor_select_part_plus = create_cursor('select-part-plus', 0, 0)
      @cursor_select_rect = create_cursor('select-rect', 0, 0)
      @cursor_select_copy_line = create_cursor('select-copy-line', 0, 0)
      @cursor_select_copy_grid = create_cursor('select-copy-grid', 0, 0)
      @cursor_select_move_line = create_cursor('select-move-line', 0, 0)
      @cursor_select_distribute = create_cursor('select-distribute', 0, 0)
      @cursor_move = create_cursor('move', 16, 16)
      @cursor_move_copy = create_cursor('move-copy', 16, 16)
      @cursor_pin_1 = create_cursor('pin-1', 11, 31)
      @cursor_pin_2 = create_cursor('pin-2', 11, 31)

    end

    def get_stripped_name
      'handle'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_COPY_LINE, ACTION_COPY_GRID, ACTION_MOVE_LINE, ACTION_DISTRIBUTE
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

      when ACTION_OPTION_COPY_MEASURE_TYPE
        return true

      when ACTION_OPTION_MOVE_MEASURE_TYPE
        return true

      when ACTION_OPTION_AXES
        return true

      end

      false
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_COPY_MEASURE_TYPE
        case option
        when ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.333,0.583L0.333,0.917L0,0.917M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917 M0,0.25L1,0.25 M0,0.083L0,0.417 M1,0.083L1,0.417'))
        when ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.333,0.583L0.333,0.917L0,0.917 M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917 M0.167,0.25L0.822,0.25 M0.167,0.083L0.167,0.417 M0.822,0.083L0.822,0.417'))
        when ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.333,0.583L0.333,0.917L0,0.917M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917 M0.333,0.25L0.667,0.25 M0.333,0.083L0.333,0.417 M0.667,0.083L0.667,0.417'))
        end
      when ACTION_OPTION_MOVE_MEASURE_TYPE
        case option
        when ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.333,0.833L0.333,0.917L0.25,0.917M0.083,0.917L0,0.917L0,0.833M0.667,0.917L0.667,0.583L1.001,0.583L1.001,0.917L0.667,0.917M0,0.667L0,0.583L0.083,0.583M0.25,0.583L0.333,0.583L0.334,0.667 M0,0.25L1,0.25M0,0.083L0,0.417M1,0.083L1,0.417'))
        when ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.333,0.833L0.333,0.917L0.25,0.917M0.083,0.917L0,0.917L0,0.833M0.667,0.917L0.667,0.583L1.001,0.583L1.001,0.917L0.667,0.917M0,0.667L0,0.583L0.083,0.583M0.25,0.583L0.333,0.583L0.334,0.667 M0,0.25L0.833,0.25M0,0.083L0,0.417M0.833,0.083L0.833,0.417'))
        when ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.333,0.833L0.333,0.917L0.25,0.917M0.083,0.917L0,0.917L0,0.833M0.667,0.917L0.667,0.583L1.001,0.583L1.001,0.917L0.667,0.917M0,0.667L0,0.583L0.083,0.583M0.25,0.583L0.333,0.583L0.334,0.667 M0,0.25L0.667,0.25M0,0.083L0,0.417M0.667,0.083L0.667,0.417'))
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
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MIRROR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2'))
        end
      end

      super
    end

    # -- Events --

    def onActionChanged(action)

      remove_all_2d
      remove_all_3d

      case action
      when ACTION_SELECT
        set_action_handler(SmartHandleSelectActionHandler.new(self, fetch_action_handler))
      when ACTION_COPY_LINE
        set_action_handler(SmartHandleCopyLineActionHandler.new(self, fetch_action_handler))
      when ACTION_COPY_GRID
        set_action_handler(SmartHandleCopyGridActionHandler.new(self, fetch_action_handler))
      when ACTION_MOVE_LINE
        set_action_handler(SmartHandleMoveLineActionHandler.new(self, fetch_action_handler))
      when ACTION_DISTRIBUTE
        set_action_handler(SmartHandleDistributeActionHandler.new(self, fetch_action_handler))
      end

      super

      refresh

    end

    def onViewChanged(view)
      super
      refresh
    end

    def onTransactionUndo(model)
      super
      refresh
    end

    def onTransactionCommit(model)
      refresh
    end

  end

  # -----

  class SmartHandleActionHandler < SmartSelectActionHandler

    include UserTextHelper
    include SmartActionHandlerPartHelper

    STATE_HANDLE_START = 1
    STATE_HANDLE = 2
    STATE_HANDLE_COPIES = 3

    LAYER_3D_HANDLE_PREVIEW = 10
    LAYER_3D_AXES_PREVIEW = 20

    attr_reader :picked_handle_start_point,
                :picked_handle_end_point

    def initialize(action, tool, previous_action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(tool)

      @mouse_snap_point = nil

      @picked_handle_start_point = nil
      @picked_handle_end_point = nil

      @cpy_instances = []
      @src_transformations = {}
      _reset_drawing_def

    end

    # -----

    def stop
      Sketchup.active_model.selection.clear
      super
    end

    # -- STATE --

    def get_state_cursor(state)
      super
    end

    def get_state_picker(state)
      super
    end

    def get_state_status(state)
      super
    end

    def get_state_vcb_label(state)
      super
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      if @tool.callback_action_handler.nil?

        case @state

        when STATE_HANDLE_START, STATE_HANDLE
          @picked_shape_start_point = nil
          _unhide_instances
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
      return true if super

      case @state

      when STATE_HANDLE_START

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d([ LAYER_3D_HANDLE_PREVIEW, LAYER_3D_AXES_PREVIEW ])

        _snap_handle_start(flags, x, y, view)
        _preview_handle_start(view)

      when STATE_HANDLE

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d([ LAYER_3D_HANDLE_PREVIEW, LAYER_3D_AXES_PREVIEW ])

        _snap_handle(flags, x, y, view)
        _preview_handle(view)

      end

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

      false
    end

    def onToolMouseLeave(tool, view)
      return true if super
      @tool.remove_all_2d
      @tool.remove_3d([ LAYER_3D_HANDLE_PREVIEW, LAYER_3D_AXES_PREVIEW ])
      @mouse_ip.clear
      view.tooltip = ''
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      return true if super

      case @state

      when STATE_HANDLE_START
        @picked_handle_start_point = @mouse_snap_point
        set_state(STATE_HANDLE)
        _refresh

      when STATE_HANDLE
        @picked_handle_end_point = @mouse_snap_point
        _handle_entity
        set_state(STATE_HANDLE_COPIES)
        _restart

      end

    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super

      if tool.is_key_alt_or_command?(key)
        return true # Block default behavior for the ALT key on Windows
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      if tool.is_key_alt_or_command?(key) && is_quick
        @tool.store_action_option_value(@action, SmartHandleTool::ACTION_OPTION_OPTIONS, SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR, !_fetch_option_mirror, true)
        _refresh
        return true
      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      case @state

      when STATE_HANDLE
        if _read_handle_copies(tool, text, view)
          _refresh
          return true
        end
        if _read_handle(tool, text, view)
          set_state(STATE_HANDLE_COPIES)
          _restart
          return true
        end

      when STATE_HANDLE_COPIES
        return true if _read_handle_copies(tool, text, view)
        return true if _read_handle(tool, text, view)

      end

      false
    end

    def onStateChanged(old_state, new_state)
      super

      case old_state

      when STATE_HANDLE, STATE_HANDLE_START
        Sketchup.active_model.selection.clear

      end

      case new_state

      when STATE_HANDLE, STATE_HANDLE_START
        unless has_active_part?
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(get_active_selection_instances)
        end
        @tool.remove_all_2d

      end

    end

    def onPartSelected
      return true if super

      if (sibling_instances = _get_sibling_instances).is_a?(Array)
        @cpy_instances.concat(sibling_instances)
      end

      @src_transformations = get_active_selection_instances.map { |instance| [ instance, Geom::Transformation.new(instance.transformation) ] }.to_h

      _reset_transformations
      _reset_drawing_def

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(_get_drawing_def, et)

      @picked_handle_start_point = eb.center.transform(et)

    end

    def onToolActionOptionStored(tool, action, option_group, option)

      if option_group == SmartHandleTool::ACTION_OPTION_AXES && !@active_part.nil?

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(_get_drawing_def, et)

        @picked_handle_start_point = eb.center.transform(et)

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
      @picked_handle_start_point = nil
      @picked_handle_end_point = nil
      @src_transformations.clear
      @cpy_instances.clear
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

    def _start_with_previous_selection?
      !@previous_action_handler.is_a?(self.class)
    end

    def _allows_multiple_selections?
      true
    end

    # -----

    def _locked_x?
      false
    end

    def _locked_y?
      false
    end

    def _locked_z?
      false
    end

    # -----

    def _preview_part(part_entity_path, part, layer = 0, highlighted = false)
      super
      if part && fetch_state == STATE_SELECT

        # Show part infos
        @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

        @tool.remove_3d(LAYER_3D_AXES_PREVIEW)
        _preview_edit_axes(true)

      else

        @tool.remove_tooltip
        @tool.remove_3d(LAYER_3D_AXES_PREVIEW)

      end
    end

    def _preview_edit_axes(with_box = true, with_x = true, with_y = true, with_z = true, translucent = false)
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        unit = @tool.get_unit

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)
        center = eb.center

        px_offset = Sketchup.active_model.active_view.pixels_to_model(50, center.transform(et))

        fn = lambda do |axis, dim, locked, color|

          dim = dim * 0.5 + px_offset

          k_edge = Kuix::EdgeMotif3d.new
          k_edge.start.copy!(center.offset(axis.reverse, dim))
          k_edge.end.copy!(center.offset(axis, dim))
          k_edge.start_arrow = true
          k_edge.end_arrow = true
          k_edge.arrow_size = unit * 1.5
          k_edge.line_width = locked ? 3 : 1.5
          k_edge.line_stipple = Kuix::LINE_STIPPLE_SOLID
          k_edge.color = color
          k_edge.transformation = et
          @tool.append_3d(k_edge, LAYER_3D_AXES_PREVIEW)

        end

        fn.call(X_AXIS, eb.width, _locked_x?, translucent ? ColorUtils.color_translucent(Kuix::COLOR_X, 64) : Kuix::COLOR_X) if with_x
        fn.call(Y_AXIS, eb.height, _locked_y?, translucent ? ColorUtils.color_translucent(Kuix::COLOR_Y, 64) : Kuix::COLOR_Y) if with_y
        fn.call(Z_AXIS, eb.depth, _locked_z?, translucent ? ColorUtils.color_translucent(Kuix::COLOR_Z, 64) : Kuix::COLOR_Z) if with_z

        if with_box

          k_box = Kuix::BoxMotif3d.new
          k_box.bounds.copy!(eb)
          k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_box.color = Kuix::COLOR_BLACK
          k_box.transformation = et
          @tool.append_3d(k_box, LAYER_3D_AXES_PREVIEW)

        end

      end
    end

    # -----

    def _snap_handle_start(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _snap_handle(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_handle_start(view)
    end

    def _preview_handle(view)
      _preview_edit_axes(false)
    end

    def _read_handle(tool, text, view)
      false
    end

    def _read_handle_copies(tool, text, view)
      false
    end

    # -----

    def _fetch_option_copy_measure_type
      @tool.fetch_action_option_value(@action, SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE)
    end

    def _fetch_option_move_measure_type
      @tool.fetch_action_option_value(@action, SmartHandleTool::ACTION_OPTION_MOVE_MEASURE_TYPE)
    end

    def _fetch_option_axes
      @tool.fetch_action_option_value(@action, SmartHandleTool::ACTION_OPTION_AXES)
    end

    def _fetch_option_mirror
      @tool.fetch_action_option_boolean(@action, SmartHandleTool::ACTION_OPTION_OPTIONS, SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR)
    end

    # -----

    def _handle_entity
    end

    # -----

    def _get_edit_transformation
      case _fetch_option_axes

      when SmartHandleTool::ACTION_OPTION_AXES_CONTEXT
        t = _get_global_context_transformation(nil)
        return t unless t.nil?

      when SmartHandleTool::ACTION_OPTION_AXES_ENTITY
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
        ignore_clines: false,
        container_validator: has_active_part? ? CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART : CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL
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

    def _copy_instance_metas(src_instance, dst_instance)
      dst_instance.material = src_instance.material
      dst_instance.name = src_instance.name
      dst_instance.layer = src_instance.layer
      dst_instance.casts_shadows = src_instance.casts_shadows?
      dst_instance.receives_shadows = src_instance.receives_shadows?
      dst_instance.glued_to = src_instance.glued_to unless src_instance.glued_to.nil?
      unless src_instance.attribute_dictionaries.nil?
        src_instance.attribute_dictionaries.each do |attribute_dictionary|
          attribute_dictionary.each do |key, value|
            dst_instance.set_attribute(attribute_dictionary.name, key, value)
          end
        end
      end
    end

    def _points_to_segments(points, closed = true, flatten = true)
      segments = points.each_cons(2).to_a
      segments << [ points.last, points.first ] if closed && !points.empty?
      segments.flatten!(1) if flatten
      segments
    end

  end

  class SmartHandleOneStepActionHandler < SmartHandleActionHandler

    def onPartSelected
      super

      set_state(STATE_HANDLE)
      _refresh

    end

    # -----

    def _clear_selection_on_start
      true
    end

  end

  class SmartHandleTwoStepActionHandler < SmartHandleActionHandler

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_HANDLE_START
        return @tool.cursor_pin_1
      when STATE_HANDLE
        return @tool.cursor_pin_2
      end

      super
    end

    # -----

    def onToolCancel(tool, reason, view)

      case @state

      when STATE_HANDLE
        set_state(STATE_HANDLE_START)
        _refresh
        return true

      end

      super
    end

    def onPartSelected
      super

      set_state(STATE_HANDLE_START)
      _refresh

    end

  end

  class SmartHandleSelectActionHandler < SmartHandleActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_SELECT, tool, previous_action_handler)
    end

    # -----

    def onPartSelected

      Sketchup.active_model.selection.clear
      Sketchup.active_model.selection.add(get_active_selection_instances)
      if (sibling_instances = _get_sibling_instances).is_a?(Array)
        Sketchup.active_model.selection.add(sibling_instances)
      end

      _reset_active_part
      _reset_active_selection

      set_state(STATE_SELECT)
      _refresh

    end

    # -----

    protected

    def _pick_part_siblings?
      true
    end

    # -----

    def _preview_edit_axes(with_box)
      # Does nothing
    end

  end

  class SmartHandleCopyLineActionHandler < SmartHandleOneStepActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_COPY_LINE, tool, previous_action_handler)

      @locked_axis = nil

      @operator = '/'
      @number = 1

    end

    # -----

    def stop
      _unhide_sibling_instances
      super
    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_HANDLE
        return @tool.cursor_select_copy_line
      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SELECT, STATE_HANDLE_START, STATE_HANDLE
        return super +
             ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_handle.action_option_options_mirror_status') + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_HANDLE
        return PLUGIN.get_i18n_string('tool.default.vcb_distance')

      end

      super
    end

    # -----

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super
      return if @state != STATE_HANDLE

      if tool.is_key_shift_down?
        if key == Kuix::VK_ADD
          _warn_if_mirrored(@number + 1) if @number == 1
          @number += 1
          _refresh
          return true
        end
        if key == Kuix::VK_SUBTRACT
          @number = [ @number - 1, 1 ].max
          _refresh
          return true
        end
      end

      if key == VK_RIGHT
        x_axis = _get_active_x_axis
        if @locked_axis == x_axis
          @locked_axis = nil
        else
          @locked_axis = x_axis
        end
        _refresh
        return true
      end
      if key == VK_LEFT
        y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
        if @locked_axis == y_axis
          @locked_axis = nil
        else
          @locked_axis = y_axis
        end
        _refresh
        return true
      end
      if key == VK_UP
        z_axis = _get_active_z_axis
        if @locked_axis == z_axis
          @locked_axis = nil
        else
          @locked_axis = z_axis
        end
        _refresh
        return true
      end
      if key == VK_DOWN
        UI.beep
      end

      false
    end

    def onStateChanged(old_state, new_state)
      super

      @locked_axis = nil

      unless _get_instance.nil?
        if new_state == STATE_HANDLE
          @tool.set_3d_visibility(false, [ LAYER_3D_PART_SIBLING_PREVIEW ]) # Hide part preview
          _hide_sibling_instances
        else
          @tool.set_3d_visibility(true, [ LAYER_3D_PART_SIBLING_PREVIEW ]) # Unhide part preview
          _unhide_sibling_instances
        end
      end

    end

    def onToolActionOptionStored(tool, action, option_group, option)
      super

      if option_group == SmartHandleTool::ACTION_OPTION_AXES
         @locked_axis = nil unless @active_part.nil?
      end

      if option == SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR
        _warn_if_mirrored(@number)
      end

    end

    def onPartSelected
      super
      @operator = '/'
      @number = [ @cpy_instances.size, 1 ].max
      _refresh
    end

    # -----

    protected

    def _reset
      @number = 1
      super
    end

    # -----

    def _pick_part_siblings?
      true
    end

    # -----

    def _locked_x?
      return false if @locked_axis.nil?
      _get_active_x_axis.parallel?(@locked_axis)
    end

    def _locked_y?
      return false if @locked_axis.nil?
      _get_active_y_axis.parallel?(@locked_axis)
    end

    def _locked_z?
      return false if @locked_axis.nil?
      _get_active_z_axis.parallel?(@locked_axis)
    end

    # -----

    def _snap_handle(flags, x, y, view)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from 2D projection

          ps = view.screen_coords(@picked_handle_start_point)
          pe = Geom::Point3d.new(x, y, 0)

          move_axis = [ _get_active_x_axis, _get_active_y_axis, _get_active_z_axis ].map! { |axis| { d: pe.distance_to_line([ ps, ps.vector_to(view.screen_coords(@picked_handle_start_point.offset(axis))) ]), axis: axis } }.min { |a, b| a[:d] <=> b[:d] }[:axis]

        end

        picked_point, _ = Geom::closest_points([ @picked_handle_start_point, move_axis ], view.pickray(x, y))
        @mouse_snap_point = picked_point

      else

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from the 3D position

          ps = @picked_handle_start_point
          pe = @mouse_ip.position
          move_axis = _get_active_x_axis

          et = _get_edit_transformation
          eti = et.inverse

          v = ps.transform(eti).vector_to(pe.transform(eti))
          if v.valid?

            eb = _get_drawing_def_edit_bounds(_get_drawing_def, et)

            line = [ eb.center, v ]

            plane_btm = [ eb.corner(0), Z_AXIS ]
            ibtm = Geom.intersect_line_plane(line, plane_btm)
            if !ibtm.nil? && eb.contains?(ibtm)
              move_axis = _get_active_z_axis
            else
              plane_lft = [ eb.corner(0), X_AXIS ]
              ilft = Geom.intersect_line_plane(line, plane_lft)
              if !ilft.nil? && eb.contains?(ilft)
                move_axis = _get_active_x_axis
              else
                plane_frt = [ eb.corner(0), Y_AXIS ]
                ifrt = Geom.intersect_line_plane(line, plane_frt)
                if !ifrt.nil? && eb.contains?(ifrt)
                  move_axis = _get_active_y_axis
                end
              end
            end

          end

        end

        @mouse_snap_point = @mouse_ip.position.project_to_line([[ @picked_handle_start_point, move_axis ]])

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_handle(view)
      return super if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_copy_measure_type)).nil?

      drawing_def, et, eb, ve, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :et, :eb, :ve, :mps, :mpe, :dps, :dpe)
      drawing_def_segments = _get_drawing_def_segments(drawing_def)

      return super unless (mv = mps.vector_to(mpe)).valid?
      color = _get_vector_color(mv)

      _preview_edit_axes(false, !mv.parallel?(_get_active_x_axis), !mv.parallel?(_get_active_y_axis), !mv.parallel?(_get_active_z_axis))

      # Preview

      if @operator == '/'
        ux = mv.x / @number
        uy = mv.y / @number
        uz = mv.z / @number
      else
        ux = mv.x
        uy = mv.y
        uz = mv.z
      end

      (1..@number).each do |i|

        mvu = Geom::Vector3d.new(ux * i, uy * i, uz * i)

        mt = Geom::Transformation.translation(mvu)
        if _fetch_option_mirror && i == @number && @number == 1
          mt = Geom::Transformation.scaling(mpe, *mvu.normalize.to_a.map { |f| (f.abs * -1) > 0 ? 1 : -1 })
          mt *= Geom::Transformation.rotation(mpe, mvu, Geometrix::ONE_PI)
          mt *= Geom::Transformation.translation(mvu)
        end

        k_segments = Kuix::Segments.new
        k_segments.add_segments(drawing_def_segments)
        k_segments.line_width = 1.5
        k_segments.color = Kuix::COLOR_BLACK
        k_segments.transformation = mt * drawing_def.transformation
        @tool.append_3d(k_segments, LAYER_3D_HANDLE_PREVIEW)

        # Preview bounds

        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(eb)
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.color = color
        k_box.transformation = et
        @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(eb)
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.color = color
        k_box.transformation = mt * et
        @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

      end

      # Preview line

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(dps)
      k_edge.end.copy!(dpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = ColorUtils.color_translucent(color, 60)
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(dps)
      k_edge.end.copy!(dpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = color
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ mps, mpe ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_DARK_GREY), LAYER_3D_HANDLE_PREVIEW)
      @tool.append_3d(_create_floating_points(points: [ dps, dpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_HANDLE_PREVIEW)

      # Preview mirror

      if _fetch_option_mirror && @number == 1

        unit = @tool.get_unit(view)

        k_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2'))
        k_motif.layout_data = Kuix::StaticLayoutDataWithSnap.new(mpe.offset(mps.vector_to(mpe), ve.length + view.pixels_to_model(40, mpe)), unit * 5, unit * 5, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        k_motif.padding.set_all!(unit)
        k_motif.set_style_attribute(:color, Kuix::COLOR_WHITE)
        k_motif.set_style_attribute(:background_color, color)
        @tool.append_2d(k_motif)

      end

      # Preview distance

      distance = dps.vector_to(dpe).length

      Sketchup.set_status_text(distance, SB_VCB_VALUE)

      if distance > 0

        k_label = _create_floating_label(
          snap_point: dps.offset(dps.vector_to(dpe), distance / 2),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(tool, text, view)
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_copy_measure_type)).nil?

      dps, dpe, dmin = move_def.values_at(:dps, :dpe, :dmin)
      v = dps.vector_to(dpe)

      distance = _read_user_text_length(tool, text, v.length)
      return false if distance.nil?

      # Error if min distance
      if distance < dmin
        tool.notify_errors([ [ "tool.default.error.lt_min_distance", { :value1 => distance.to_l, :value2 => dmin.to_l } ] ])
        return false
      end

      @picked_handle_end_point = dps.offset(v, [ distance.abs, dmin ].max)

      _handle_entity
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    def _read_handle_copies(tool, text, view)
      return true if super
      return if _get_instances.empty?

      v, _ = _split_user_text(text)

      match = v.nil? ? nil : v.match(/^([x*\/])(\d+)$/)

      if match

        operator, value = match[1, 2]

        number = value.to_i

        if number == 0
          UI.beep
          tool.notify_errors([ [ "tool.default.error.invalid_#{operator == '/' ? 'divider' : 'multiplicator'}", { :value => value } ] ])
          return true
        end

        _warn_if_mirrored(number)

        case @state

        when STATE_HANDLE
          @operator = operator
          @number = number

        when STATE_HANDLE_COPIES
          _copy_line_entity(operator, number)

        end

        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    # -----

    def _handle_entity
      _copy_line_entity(@operator, @number)
    end

    def _copy_line_entity(operator = '*', number = 1)
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, _fetch_option_copy_measure_type)).nil?

      mps, mpe = move_def.values_at(:mps, :mpe)

      ct = _get_global_context_transformation
      cti = ct.inverse

      mps = mps.transform(cti)
      mpe = mpe.transform(cti)
      mv = mps.vector_to(mpe)

      _unhide_sibling_instances

      model = Sketchup.active_model
      model.start_operation('OCL Copy Part', true, false, !active?)

        if operator == '/'
          ux = mv.x / number
          uy = mv.y / number
          uz = mv.z / number
        else
          ux = mv.x
          uy = mv.y
          uz = mv.z
        end

        src_instances = get_active_selection_instances

        if get_active_selection_path.empty?
          entities = model.active_entities
        else
          entities = get_active_selection_path.last.definition.entities
        end

        entities.erase_entities(@cpy_instances) if @cpy_instances.any?
        @cpy_instances.clear

        src_instances.each do |src_instance|

          definition = src_instance.definition

          (1..number).each do |i|

            mvu = Geom::Vector3d.new(ux * i, uy * i, uz * i)

            mt = Geom::Transformation.translation(mvu)
            if _fetch_option_mirror && i == number && number == 1
              mt = Geom::Transformation.scaling(mpe, *mvu.normalize.to_a.map { |f| (f.abs * -1) > 0 ? 1 : -1 })
              mt *= Geom::Transformation.rotation(mpe, mvu, Geometrix::ONE_PI)
              mt *= Geom::Transformation.translation(mvu)
            end
            mt *= @src_transformations[src_instance]

            dst_instance = entities.add_instance(definition, mt)

            @cpy_instances << dst_instance

            _copy_instance_metas(src_instance, dst_instance)

          end
        end

        @operator = operator
        @number = number

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe, type = 0)
      return unless pe.is_a?(Geom::Point3d)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eti = et.inverse

      return unless (eb = _get_drawing_def_edit_bounds(drawing_def, et)).valid?

      # Compute in 'Edit' space

      ecenter = eb.center

      elps = ecenter
      elpe = pe.transform(eti)

      ev = elps.vector_to(elpe)

      unless ev.valid?
        elpe = elps.offset(X_AXIS)
        ev = Geom::Vector3d.new(X_AXIS)
      end

      eline = [ elps, ev ]

      plane_btm = [ eb.corner(0), Z_AXIS ]
      ibtm = Geom.intersect_line_plane(eline, plane_btm)
      if !ibtm.nil? && eb.contains?(ibtm)
        evs = ibtm.vector_to(ecenter)
        evs.reverse! if evs.valid? && evs.samedirection?(ev)
      else
        plane_lft = [ eb.corner(0), X_AXIS ]
        ilft = Geom.intersect_line_plane(eline, plane_lft)
        if !ilft.nil? && eb.contains?(ilft)
          evs = ilft.vector_to(ecenter)
          evs.reverse! if evs.valid? && evs.samedirection?(ev)
        else
          plane_frt = [ eb.corner(0), Y_AXIS ]
          ifrt = Geom.intersect_line_plane(eline, plane_frt)
          if !ifrt.nil? && eb.contains?(ifrt)
            evs = ifrt.vector_to(ecenter)
            evs.reverse! if evs.valid? && evs.samedirection?(ev)
          else
            evs = Geom::Vector3d.new
          end
        end
      end

      eve = evs.reverse

      f = @operator == '/' ? @number : 1

      case type
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE
        dlmin = eve.length * (2 * f + 1)
        dmin = eve.length * (2 * f + 2)
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED
        dlmin = eve.length * 2 * f
        dmin = eve.length * 2 * f
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE
        dlmin = eve.length * (2 * f - 1)
        dmin = eve.length * (2 * f - 2)
      else
        return
      end
      ev.length = dlmin if elps.distance(elpe) < dlmin
      elpe = elps.offset(ev)

      # Restore to 'Global' space

      vs = evs.transform(et)
      ve = eve.transform(et)

      lps = elps.transform(et)
      lpe = elpe.transform(et)

      mps = lps
      dpe = lpe
      case type
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE
        mpe = lpe.offset(vs)
        dps = lps.offset(vs)
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED
        mpe = lpe
        dps = lps
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE
        mpe = lpe.offset(ve)
        dps = lps.offset(ve)
      else
        return
      end

      return unless mps.vector_to(mpe).valid? # No move

      {
        drawing_def: drawing_def,
        et: et,
        eb: eb,   # Expressed in 'Edit' space
        vs: vs,
        ve: ve,
        mps: mps,
        mpe: mpe,
        dps: dps,
        dpe: dpe,
        dmin: dmin
      }
    end

    # -----

    def _warn_if_mirrored(number)
      # Warn if the mirror option enabled
      @tool.notify_warnings([ [ "tool.smart_handle.warning.copies_disable_mirror" ] ]) if _fetch_option_mirror && number != 1
    end

  end

  class SmartHandleCopyGridActionHandler < SmartHandleOneStepActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_COPY_GRID, tool, previous_action_handler)

      @normal = nil

      @locked_normal = nil

      @operator_x = '*'
      @number_x = 1
      @operator_y = '*'
      @number_y = 1

    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_HANDLE
        return @tool.cursor_select_copy_grid
      end

      super
    end


    def get_state_status(state)

      case state

      when STATE_SELECT, STATE_HANDLE_START, STATE_HANDLE
        return super +
           ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_handle.action_option_options_mirror_status') + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_HANDLE
        return PLUGIN.get_i18n_string('tool.default.vcb_size')

      end

      super
    end

    # -----

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super
      return if @state != STATE_HANDLE

      if tool.is_key_shift_down?
        if key == Kuix::VK_ADD
          _warn_if_mirrored(@number_x + 1, @number_y + 1) if @number_x == 1 && @number_y == 1
          @number_x += 1
          @number_y += 1
          _refresh
          return true
        end
        if key == Kuix::VK_SUBTRACT
          @number_x = [ @number_x - 1, 1 ].max
          @number_y = [ @number_y - 1, 1 ].max
          _refresh
          return true
        end
      end

      if key == VK_RIGHT
        x_axis = _get_active_x_axis
        if @locked_normal == x_axis
          @locked_normal = nil
        else
          @locked_normal = x_axis
        end
        _refresh
        return true
      end
      if key == VK_LEFT
        y_axis = _get_active_y_axis
        if @locked_normal == y_axis
          @locked_normal = nil
        else
          @locked_normal = y_axis
        end
        _refresh
        return true
      end
      if key == VK_UP
        z_axis = _get_active_z_axis
        if @locked_normal == z_axis
          @locked_normal = nil
        else
          @locked_normal = z_axis
        end
        _refresh
        return true
      end
      if key == VK_DOWN
        UI.beep
      end

      false
    end

    def onStateChanged(old_state, new_state)
      super

      @locked_normal = nil

    end

    def onToolActionOptionStored(tool, action, option_group, option)
      super

      if option_group == SmartHandleTool::ACTION_OPTION_AXES
        @locked_normal = nil unless @active_part.nil?
      end

      if option == SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR
        _warn_if_mirrored(@number_x, @number_y)
      end

    end

    # -----

    protected

    def _reset
      @number_x = 1
      @number_y = 1
      super
    end

    # -----

    def _locked_x?
      return false if @locked_normal.nil?
      _get_active_x_axis.parallel?(@locked_normal)
    end

    def _locked_y?
      return false if @locked_normal.nil?
      _get_active_y_axis.parallel?(@locked_normal)
    end

    def _locked_z?
      return false if @locked_normal.nil?
      _get_active_z_axis.parallel?(@locked_normal)
    end

    # -----

    def _snap_handle(flags, x, y, view)

      if @locked_normal

        @normal = @locked_normal

      else

        @normal = _get_active_z_axis

      end

      plane = [ @picked_handle_start_point, @normal ]

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        picked_point = Geom::intersect_line_plane(view.pickray(x, y), plane)
        @mouse_snap_point = picked_point

      else

        @mouse_snap_point = @mouse_ip.position.project_to_plane(plane)

      end

    end

    def _preview_handle(view)
      super
      return if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_copy_measure_type)).nil?

      drawing_def, et, eb, ve, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :et, :eb, :ve, :mps, :mpe, :dps, :dpe)
      drawing_def_segments = _get_drawing_def_segments(drawing_def)

      ht = _get_handle_transformation
      hti = ht.inverse

      color = _get_vector_color(@normal)

      mps_2d = mps.transform(hti)
      mpe_2d = mpe.transform(hti)
      mv_2d = mps_2d.vector_to(mpe_2d)

      dps_2d = dps.transform(hti)
      dpe_2d = dpe.transform(hti)
      dv_2d = dps_2d.vector_to(dpe_2d)

      db_2d = Geom::BoundingBox.new
      db_2d.add(dps_2d, dpe_2d)

      # Preview rectangle

      k_rectangle = Kuix::RectangleMotif3d.new
      k_rectangle.bounds.copy!(db_2d)
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_rectangle.line_width = 1.5 unless @locked_normal.nil?
      k_rectangle.color = ColorUtils.color_translucent(color, 60)
      k_rectangle.on_top = true
      k_rectangle.transformation = ht
      @tool.append_3d(k_rectangle, LAYER_3D_HANDLE_PREVIEW)

      k_rectangle = Kuix::RectangleMotif3d.new
      k_rectangle.bounds.copy!(db_2d)
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_rectangle.line_width = 1.5 unless @locked_normal.nil?
      k_rectangle.color = color
      k_rectangle.transformation = ht
      @tool.append_3d(k_rectangle, LAYER_3D_HANDLE_PREVIEW)

      # Preview

      if @operator_x == '/'
        ux = mv_2d.x / @number_x
        border_x = @number_x
      else
        ux = mv_2d.x
        border_x = 1
      end
      if @operator_y == '/'
        uy = mv_2d.y / @number_y
        border_y = @number_y
      else
        uy = mv_2d.y
        border_y = 1
      end

      (0..@number_x).each do |x|
        (0..@number_y).each do |y|

          mvu = Geom::Vector3d.new(ux * x, uy * y).transform(ht)

          mp = mps.offset(mvu)

          mt = Geom::Transformation.translation(mvu)

          unless x == 0 && y == 0

            if _fetch_option_mirror && @number_x == 1 && @number_y == 1

              if x == @number_x && y == @number_y
                mt *= Geom::Transformation.rotation(mp, Z_AXIS.transform(ht), Geometrix::ONE_PI)
                mt *= Geom::Transformation.translation(mvu + mvu)
              elsif x == @number_x || y == @number_y
                mt = Geom::Transformation.scaling(mp, *mvu.normalize.to_a.map { |f| (f.abs * -1) > 0 ? 1 : -1 })
                mt *= Geom::Transformation.rotation(mp, x == 1 ? X_AXIS.transform(ht) : Y_AXIS.transform(ht), Geometrix::ONE_PI)
                mt *= Geom::Transformation.translation(mvu)
              end

            end

            k_segments = Kuix::Segments.new
            k_segments.add_segments(drawing_def_segments)
            k_segments.line_width = 1.5
            k_segments.color = Kuix::COLOR_BLACK
            k_segments.transformation = mt * drawing_def.transformation
            @tool.append_3d(k_segments, LAYER_3D_HANDLE_PREVIEW)

          end

          next unless x == 0 && y == 0 || x == 0 && y == border_y || y == 0 && x == border_x || x == border_x && y == border_y

          dvu = Geom::Vector3d.new(dv_2d.x * [ x, 1 ].min, dv_2d.y * [ y, 1 ].min).transform(ht)
          dp = dps.offset(dvu)

          k_box = Kuix::BoxMotif3d.new
          k_box.bounds.copy!(eb)
          k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_box.color = color
          k_box.transformation = mt * et
          @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

          @tool.append_3d(_create_floating_points(points: [ mp ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_MEDIUM_GREY), LAYER_3D_HANDLE_PREVIEW)
          @tool.append_3d(_create_floating_points(points: [ dp ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_HANDLE_PREVIEW)

        end
      end

      # Preview mirror

      if _fetch_option_mirror && @number_x == 1 && @number_y == 1

        unit = @tool.get_unit(view)

        k_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2'))
        k_motif.layout_data = Kuix::StaticLayoutDataWithSnap.new(mpe.offset(ve, ve.length + view.pixels_to_model(40, mpe)), unit * 5, unit * 5, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        k_motif.padding.set_all!(unit)
        k_motif.set_style_attribute(:color, Kuix::COLOR_WHITE)
        k_motif.set_style_attribute(:background_color, Kuix::COLOR_BLACK)
        @tool.append_2d(k_motif)

      end

      # Preview distance

      distance_x = db_2d.width
      distance_y = db_2d.height

      Sketchup.set_status_text("#{distance_x}#{Sketchup::RegionalSettings.list_separator} #{distance_y}", SB_VCB_VALUE)

      if distance_x > 0

        k_label = _create_floating_label(
          snap_point: db_2d.min.offset(X_AXIS, distance_x / 2).transform(ht),
          text: distance_x,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end
      if distance_y > 0

        k_label = _create_floating_label(
          snap_point: db_2d.min.offset(Y_AXIS, distance_y / 2).transform(ht),
          text: distance_y,
          text_color: Kuix::COLOR_Y,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(tool, text, view)
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_copy_measure_type)).nil?

      ht = _get_handle_transformation
      hti = ht.inverse

      dps, dpe, dminx, dminy = move_def.values_at(:dps, :dpe, :dminx, :dminy)
      dv = dps.transform(hti).vector_to(dpe.transform(hti))

      d1, d2 = _split_user_text(text)

      if d1 || d2

        distance_x = _read_user_text_length(tool, d1, dv.x.abs)
        return false if distance_x.nil?

        # Error if min distance
        if distance_x < dminx
          tool.notify_errors([ [ "tool.default.error.lt_min_distance", { :value1 => distance_x.to_l, :value2 => dminx.to_l } ] ])
          return false
        end

        distance_y = _read_user_text_length(tool, d2, dv.y.abs)
        return false if distance_y.nil?

        # Error if min distance
        if distance_y < dminy
          tool.notify_errors([ [ "tool.default.error.lt_min_distance", { :value1 => distance_y.to_l, :value2 => dminy.to_l } ] ])
          return false
        end

        @picked_handle_end_point = dps.offset(Geom::Vector3d.new(
          [ distance_x.abs, dminx ].max * (dv.x < 0 ? -1 : 1),
          [ distance_y.abs, dminy ].max * (dv.y < 0 ? -1 : 1)
        ).transform(ht))

        _handle_entity
        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    def _read_handle_copies(tool, text, view)
      return true if super
      return if _get_instances.empty?

      v1, v2 = _split_user_text(text)

      match_1 = v1.nil? ? nil : v1.match(/^([x*\/])(\d+)$/)
      match_2 = v2.nil? ? nil : v2.match(/^([x*\/])(\d+)$/)

      if match_1 || match_2

        operator_1, value_1 = match_1 ? match_1[1, 2] : [ '*', 1 ]
        operator_2, value_2 = match_2 ? match_2[1, 2] : [ '*', 1 ]

        number_1 = value_1.to_i
        number_2 = value_2.to_i

        if number_1 == 0
          UI.beep
          tool.notify_errors([ [ "tool.default.error.invalid_#{operator_1 == '/' ? 'divider' : 'multiplicator'}", { :value => value_1 } ] ])
          return true
        end
        if number_2 == 0
          UI.beep
          tool.notify_errors([ [ "tool.default.error.invalid_#{operator_2 == '/' ? 'divider' : 'multiplicator'}", { :value => value_2 } ] ])
          return true
        end

        _warn_if_mirrored(number_1, number_2)

        case @state

        when STATE_HANDLE
          @operator_x = operator_1
          @number_x = number_1
          @operator_y = operator_2
          @number_y = number_2

        when STATE_HANDLE_COPIES
          _copy_grid_entity(operator_1, number_1, operator_2, number_2)

        end

        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    # -----

    def _handle_entity
      _copy_grid_entity(@operator_x, @number_x, @operator_y, @number_y)
    end

    def _copy_grid_entity(operator_x = '*', number_x = 1, operator_y = '*', number_y = 1)
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, _fetch_option_copy_measure_type)).nil?

      mps, mpe = move_def.values_at(:mps, :mpe)

      ht = _get_handle_transformation
      hti = ht.inverse

      mps_2d = mps.transform(hti)
      mpe_2d = mpe.transform(hti)
      mv_2d = mps_2d.vector_to(mpe_2d)

      model = Sketchup.active_model
      model.start_operation('OCL Copy Part', true, false, !active?)

        if operator_x == '/'
          ux = mv_2d.x / number_x
        else
          ux = mv_2d.x
        end
        if operator_y == '/'
          uy = mv_2d.y / number_y
        else
          uy = mv_2d.y
        end

        src_instances = get_active_selection_instances

        if get_active_selection_path.empty?
          entities = model.active_entities
        else
          entities = get_active_selection_path.last.definition.entities
        end

        entities.erase_entities(@cpy_instances) if @cpy_instances.any?
        @cpy_instances.clear

        src_instances.each do |src_instance|

          definition = src_instance.definition

          ct = _get_global_context_transformation
          cti = ct.inverse

          (0..number_x).each do |x|
            (0..number_y).each do |y|

              next if x == 0 && y == 0  # Ignore src instance

              mvu = Geom::Vector3d.new(ux * x, uy * y).transform(ht)

              mt = Geom::Transformation.translation(mvu.transform(cti))
              if _fetch_option_mirror && number_x == 1 && number_y == 1

                mp = mps.offset(mvu)

                mvux = Geom::Vector3d.new(ux * x, 0).transform(ht)
                mvuy = Geom::Vector3d.new(0, uy * y).transform(ht)

                if x == number_x && y == number_y
                  mt *= Geom::Transformation.rotation(mp.transform(cti), (mvux * mvuy).transform(cti), Geometrix::ONE_PI)
                  mt *= Geom::Transformation.translation((mvu + mvu).transform(cti))
                elsif x == number_x || y == number_y
                  mt = Geom::Transformation.scaling(mp.transform(cti), *mvu.transform(cti).normalize.to_a.map { |f| (f.abs * -1) > 0 ? 1 : -1 })
                  mt *= Geom::Transformation.rotation(mp.transform(cti), x == number_x ? mvux.transform(cti) : mvuy.transform(cti), Geometrix::ONE_PI)
                  mt *= Geom::Transformation.translation(mvu.transform(cti))
                end

              end
              mt *= @src_transformations[src_instance]

              dst_instance = entities.add_instance(definition, mt)
              @cpy_instances << dst_instance

              _copy_instance_metas(src_instance, dst_instance)

            end
          end

        end

        @operator_x = operator_x
        @number_x = number_x
        @operator_y = operator_y
        @number_y = number_y

      model.commit_operation

    end

    # -----

    def _get_handle_axes

      active_x_axis = _get_active_x_axis
      active_x_axis = _get_active_y_axis if active_x_axis.parallel?(@normal)

      z_axis = @normal
      x_axis = ORIGIN.vector_to(ORIGIN.offset(active_x_axis).project_to_plane([ ORIGIN, z_axis ]))
      y_axis = z_axis * x_axis

      [ x_axis.normalize, y_axis.normalize, z_axis.normalize ]
    end

    def _get_handle_transformation(origin = ORIGIN)
      Geom::Transformation.axes(origin, *_get_handle_axes)
    end

    def _get_move_def(ps, pe, type = 0)
      return unless pe.is_a?(Geom::Point3d)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      ht = _get_handle_transformation
      hti = ht.inverse

      return unless (eb = _get_drawing_def_edit_bounds(drawing_def, ht)).valid?

      # Compute in 'Edit/Handle' space

      ecenter = eb.center
      plane = [ ecenter, Z_AXIS ]
      line_x = [ ecenter, X_AXIS ]
      line_y = [ ecenter, Y_AXIS ]

      elps = ecenter
      elpe = pe.transform(hti).project_to_plane(plane)
      elpex = elpe.project_to_line(line_x)
      elpey = elpe.project_to_line(line_y)

      evx = elps.vector_to(elpex)
      evy = elps.vector_to(elpey)

      # Avoid zero length vector for evx or evy
      unless evx.valid?
        elpex = elps.offset(X_AXIS)
        evx = Geom::Vector3d.new(X_AXIS)
      end
      unless evy.valid?
        elpey = elps.offset(Y_AXIS)
        evy = Geom::Vector3d.new(Y_AXIS)
      end

      fn_compute = lambda { |line, v|

        plane_btm = [ eb.corner(0), Z_AXIS ]
        ibtm = Geom.intersect_line_plane(line, plane_btm)
        if !ibtm.nil? && eb.contains?(ibtm)
          evs = ibtm.vector_to(ecenter)
          evs.reverse! if v.valid? && evs.valid? && evs.samedirection?(v)
        else
          plane_lft = [ eb.corner(0), X_AXIS ]
          ilft = Geom.intersect_line_plane(line, plane_lft)
          if !ilft.nil? && eb.contains?(ilft)
            evs = ilft.vector_to(ecenter)
            evs.reverse! if v.valid? && evs.valid? && evs.samedirection?(v)
          else
            plane_frt = [ eb.corner(0), Y_AXIS ]
            ifrt = Geom.intersect_line_plane(line, plane_frt)
            if !ifrt.nil? && eb.contains?(ifrt)
              evs = ifrt.vector_to(ecenter)
              evs.reverse! if v.valid? && evs.valid? && evs.samedirection?(v)
            else
              evs = Geom::Vector3d.new
            end
          end
        end

        eve = evs.reverse

        [ evs, eve ]
      }

      evsx, evex = fn_compute.call(line_x, evx)
      evsy, evey = fn_compute.call(line_y, evy)

      evs = evsx + evsy
      eve = evex + evey

      f_x = @operator_x == '/' ? @number_x : 1
      f_y = @operator_y == '/' ? @number_y : 1

      case type
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE
        dlminx = evex.length * (2 * f_x + 1)
        dlminy = evey.length * (2 * f_y + 1)
        dminx = evex.length * (2 * f_x + 2)
        dminy = evey.length * (2 * f_y + 2)
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED
        dlminx = evex.length * 2 * f_x
        dlminy = evey.length * 2 * f_y
        dminx = evex.length * 2 * f_x
        dminy = evey.length * 2 * f_y
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE
        dlminx = evex.length * (2 * f_x - 1)
        dlminy = evey.length * (2 * f_y - 1)
        dminx = evex.length * (2 * f_x - 2)
        dminy = evey.length * (2 * f_y - 2)
      else
        return
      end
      evx.length = dlminx if elps.distance(elpex) < dlminx
      evy.length = dlminy if elps.distance(elpey) < dlminy
      elpe = elps.offset(evx + evy)

      # Restore to 'Global' space

      vs = evs.transform(ht)
      ve = eve.transform(ht)

      lps = elps.transform(ht)
      lpe = elpe.transform(ht)

      mps = lps
      dpe = lpe
      case type
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_OUTSIDE
        mpe = lpe.offset(vs)
        dps = lps.offset(vs)
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_CENTERED
        mpe = lpe
        dps = lps
      when SmartHandleTool::ACTION_OPTION_COPY_MEASURE_TYPE_INSIDE
        mpe = lpe.offset(ve)
        dps = lps.offset(ve)
      else
        return
      end

      return unless mps.vector_to(mpe).valid? # No move

      {
        drawing_def: drawing_def,
        et: ht,
        eb: eb,
        lps: lps,
        lpe: lpe,
        vs: vs,
        ve: ve,
        mps: mps,
        mpe: mpe,
        dps: dps,
        dpe: dpe,
        dminx: dminx,
        dminy: dminy
      }
    end

    # -----

    def _warn_if_mirrored(number_x, number_y)
      # Warn if the mirror option enabled
      @tool.notify_warnings([ [ "tool.smart_handle.warning.copies_disable_mirror" ] ]) if _fetch_option_mirror && (number_x != 1 || number_y != 1)
    end

  end

  class SmartHandleMoveLineActionHandler < SmartHandleOneStepActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_MOVE_LINE, tool, previous_action_handler)

      @locked_axis = nil

    end

    # -----

    def stop
      _unhide_instances
      super
    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_HANDLE
        return @tool.cursor_select_move_line
      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_HANDLE
        return PLUGIN.get_i18n_string('tool.default.vcb_distance')

      end

      super
    end

    # -----

    def onToolSuspend(tool, view)
      super
      _unhide_instances if @state == STATE_HANDLE
    end

    def onToolResume(tool, view)
      super
      _hide_instances if @state == STATE_HANDLE
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super
      return if @state != STATE_HANDLE

      if key == VK_RIGHT
        x_axis = _get_active_x_axis
        if @locked_axis == x_axis
          @locked_axis = nil
        else
          @locked_axis = x_axis
        end
        _refresh
        return true
      end
      if key == VK_LEFT
        y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
        if @locked_axis == y_axis
          @locked_axis = nil
        else
          @locked_axis = y_axis
        end
        _refresh
        return true
      end
      if key == VK_UP
        z_axis = _get_active_z_axis
        if @locked_axis == z_axis
          @locked_axis = nil
        else
          @locked_axis = z_axis
        end
        _refresh
        return true
      end
      if key == VK_DOWN
        UI.beep
      end

      false
    end

    def onStateChanged(old_state, new_state)
      super

      @locked_axis = nil

      if has_active_selection?
        if new_state == STATE_HANDLE
          @tool.remove_3d(LAYER_3D_PART_PREVIEW)  # Remove part preview
          _hide_instances
        else
          _unhide_instances
        end
      end

    end

    def onToolActionOptionStored(tool, action, option_group, option)
      super

      if option_group == SmartHandleTool::ACTION_OPTION_AXES
        @locked_axis = nil unless @active_part.nil?
      end

    end

    # -----

    protected

    # -----

    def _locked_x?
      return false if @locked_axis.nil?
      _get_active_x_axis.parallel?(@locked_axis)
    end

    def _locked_y?
      return false if @locked_axis.nil?
      _get_active_y_axis.parallel?(@locked_axis)
    end

    def _locked_z?
      return false if @locked_axis.nil?
      _get_active_z_axis.parallel?(@locked_axis)
    end

    # -----

    def _snap_handle(flags, x, y, view)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from 2D projection

          ps = view.screen_coords(@picked_handle_start_point)
          pe = Geom::Point3d.new(x, y, 0)

          move_axis = [ _get_active_x_axis, _get_active_y_axis, _get_active_z_axis ].map! { |axis| { d: pe.distance_to_line([ ps, ps.vector_to(view.screen_coords(@picked_handle_start_point.offset(axis))) ]), axis: axis } }.min { |a, b| a[:d] <=> b[:d] }[:axis]

        end

        picked_point, _ = Geom::closest_points([ @picked_handle_start_point, move_axis ], view.pickray(x, y))
        @mouse_snap_point = picked_point

      else

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from 3D position

          ps = @picked_handle_start_point
          pe = @mouse_ip.position
          move_axis = _get_active_x_axis

          et = _get_edit_transformation
          eti = et.inverse

          v = ps.transform(eti).vector_to(pe.transform(eti))
          if v.valid?

            eb = _get_drawing_def_edit_bounds(_get_drawing_def, et)

            line = [ eb.center, v ]

            plane_btm = [ eb.corner(0), Z_AXIS ]
            ibtm = Geom.intersect_line_plane(line, plane_btm)
            if !ibtm.nil? && eb.contains?(ibtm)
              move_axis = _get_active_z_axis
            else
              plane_lft = [ eb.corner(0), X_AXIS ]
              ilft = Geom.intersect_line_plane(line, plane_lft)
              if !ilft.nil? && eb.contains?(ilft)
                move_axis = _get_active_x_axis
              else
                plane_frt = [ eb.corner(0), Y_AXIS ]
                ifrt = Geom.intersect_line_plane(line, plane_frt)
                if !ifrt.nil? && eb.contains?(ifrt)
                  move_axis = _get_active_y_axis
                end
              end
            end

          end

        end

        @mouse_snap_point = @mouse_ip.position.project_to_line([[@picked_handle_start_point, move_axis ]])

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_handle(view)
      return super if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_move_measure_type)).nil?

      drawing_def, drawing_def_segments, et, eb, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :drawing_def_segments, :et, :eb, :mps, :mpe, :dps, :dpe)

      return super unless (mv = mps.vector_to(mpe)).valid?
      color = _get_vector_color(mv)

      _preview_edit_axes(false, !mv.parallel?(_get_active_x_axis), !mv.parallel?(_get_active_y_axis), !mv.parallel?(_get_active_z_axis), true)

      mt = Geom::Transformation.translation(mv)
      if _fetch_option_mirror
        mt = Geom::Transformation.scaling(mpe, *mv.normalize.to_a.map { |f| (f.abs * -1) > 0 ? 1 : -1 })
        mt *= Geom::Transformation.rotation(mpe, mv, Geometrix::ONE_PI)
        mt *= Geom::Transformation.translation(mv)
      end

      # Preview

      k_segments = Kuix::Segments.new
      k_segments.add_segments(drawing_def_segments)
      k_segments.line_width = 1.5
      k_segments.color = Kuix::COLOR_BLACK
      k_segments.transformation = mt * drawing_def.transformation
      @tool.append_3d(k_segments, LAYER_3D_HANDLE_PREVIEW)

      # Preview line

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(dps)
      k_edge.end.copy!(dpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = ColorUtils.color_translucent(color, 60)
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(dps)
      k_edge.end.copy!(dpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = color
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ mps, mpe ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_DARK_GREY), LAYER_3D_HANDLE_PREVIEW)
      @tool.append_3d(_create_floating_points(points: [ dps, dpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_HANDLE_PREVIEW)

      # Preview bounds

      k_box = Kuix::BoxMotif3d.new
      k_box.bounds.copy!(eb)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.color = color
      k_box.transformation = et
      @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

      k_box = Kuix::BoxMotif3d.new
      k_box.bounds.copy!(eb)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.color = color
      k_box.transformation = mt * et
      @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

      distance = dps.vector_to(dpe).length

      Sketchup.set_status_text(distance, SB_VCB_VALUE)

      if distance > 0

        k_label = _create_floating_label(
          snap_point: dps.offset(dps.vector_to(dpe), distance / 2),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(tool, text, view)
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_move_measure_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      dv = dps.vector_to(dpe)

      distance = _read_user_text_length(tool, text, dv.length)
      return true if distance.nil?

      @picked_handle_end_point = dps.offset(dv, distance)

      _handle_entity
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # -----

    def _handle_entity
      _move_line_entity
    end

    def _move_line_entity
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, _fetch_option_move_measure_type)).nil?

      mps, mpe = move_def.values_at(:mps, :mpe)

      ct = _get_global_context_transformation
      cti = ct.inverse

      mps = mps.transform(cti)
      mpe = mpe.transform(cti)
      mv = mps.vector_to(mpe)

      _unhide_instances

      model = Sketchup.active_model
      model.start_operation('OCL Move Part', true, false, !active?)

        src_instances = get_active_selection_instances
        src_instances.each do |src_instance|

          mt = Geom::Transformation.translation(mv)
          mt *= @src_transformations[src_instance]

          src_instance.transformation = mt

        end

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe, type = 0)
      return unless ps.is_a?(Geom::Point3d) && pe.is_a?(Geom::Point3d)
      return unless (v = ps.vector_to(pe)).valid?
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return unless (drawing_def_segments = _get_drawing_def_segments(drawing_def)).is_a?(Array)

      et = _get_edit_transformation
      eti = et.inverse
      eb = _get_drawing_def_edit_bounds(drawing_def, et)

      # Compute in the 'Edit' space

      ev = v.transform(eti)

      ecenter = eb.center
      eline = [ ecenter, ev ]

      plane_btm = [ eb.corner(0), Z_AXIS ]
      ibtm = Geom.intersect_line_plane(eline, plane_btm)
      if !ibtm.nil? && eb.contains?(ibtm)
        evs = ibtm.vector_to(ecenter)
        evs.reverse! if evs.valid? && evs.samedirection?(ev)
      else
        plane_lft = [ eb.corner(0), X_AXIS ]
        ilft = Geom.intersect_line_plane(eline, plane_lft)
        if !ilft.nil? && eb.contains?(ilft)
          evs = ilft.vector_to(ecenter)
          evs.reverse! if evs.valid? && evs.samedirection?(ev)
        else
          plane_frt = [ eb.corner(0), Y_AXIS ]
          ifrt = Geom.intersect_line_plane(eline, plane_frt)
          if !ifrt.nil? && eb.contains?(ifrt)
            evs = ifrt.vector_to(ecenter)
            evs.reverse! if evs.valid? && evs.samedirection?(ev)
          else
            evs = Geom::Vector3d.new
          end
        end
      end

      # Restore to 'Global' space

      center = ecenter.transform(et)
      line = [ center, v ]
      vs = evs.transform(et)
      ve = vs.reverse

      lps = center
      lpe = pe.project_to_line(line)

      mps = lps
      dps = lps.offset(vs)
      dpe = lpe
      case type
      when SmartHandleTool::ACTION_OPTION_MOVE_MEASURE_TYPE_OUTSIDE
        mpe = lpe.offset(vs)
      when SmartHandleTool::ACTION_OPTION_MOVE_MEASURE_TYPE_CENTERED
        mpe = lpe
      when SmartHandleTool::ACTION_OPTION_MOVE_MEASURE_TYPE_INSIDE
        mpe = lpe.offset(ve)
      else
        return
      end

      return unless mps.vector_to(mpe).valid? # No move

      {
        drawing_def: drawing_def,
        drawing_def_segments: drawing_def_segments,
        et: et,
        eb: eb,   # Expressed in the 'Edit' space
        mps: mps,
        mpe: mpe,
        dps: dps,
        dpe: dpe
      }
    end

  end

  class SmartHandleDistributeActionHandler < SmartHandleTwoStepActionHandler

    attr_reader :number

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_DISTRIBUTE, tool, previous_action_handler)

      @locked_axis = nil

      @number = 1

      @raytest_path = nil

    end

    # -----

    def stop
      _unhide_instances
      _unhide_sibling_instances
      super
    end

    # -- STATE --

    def get_state_cursor(state)

      case state

      when STATE_SELECT
        return @tool.cursor_select_distribute

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_HANDLE
        return PLUGIN.get_i18n_string('tool.default.vcb_distance')

      end

      super
    end

    # -----

    def onToolSuspend(tool, view)
      super
      _unhide_instances if @state == STATE_HANDLE
    end

    def onToolResume(tool, view)
      super
      _hide_instances if @state == STATE_HANDLE
    end

    def onToolLButtonDoubleClick(tool, flags, x, y, view)
      if @previous_action_handler.is_a?(self.class)

        unless @previous_action_handler.number.nil? ||
               @previous_action_handler.picked_handle_start_point.nil? ||
               @previous_action_handler.picked_handle_end_point.nil?

          @number = @previous_action_handler.number
          @picked_handle_start_point = @previous_action_handler.picked_handle_start_point
          @picked_handle_end_point = @previous_action_handler.picked_handle_end_point

          _handle_entity
          set_state(STATE_HANDLE_COPIES)
          _restart

        end

      else
        UI.beep
      end
      true
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super
      return if @state != STATE_HANDLE

      if tool.is_key_ctrl_or_option?(key)
        _refresh
        return true
      end

      if tool.is_key_shift_down?
        if key == Kuix::VK_ADD
          @number += 1
          _refresh
          return true
        end
        if key == Kuix::VK_SUBTRACT
          @number = [ @number - 1, 1 ].max
          _refresh
          return true
        end
      end

      if key == VK_RIGHT
        x_axis = _get_active_x_axis
        if @locked_axis == x_axis
          @locked_axis = nil
        else
          @locked_axis = x_axis
        end
        _refresh
        return true
      end
      if key == VK_LEFT
        y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
        if @locked_axis == y_axis
          @locked_axis = nil
        else
          @locked_axis = y_axis
        end
        _refresh
        return true
      end
      if key == VK_UP
        z_axis = _get_active_z_axis
        if @locked_axis == z_axis
          @locked_axis = nil
        else
          @locked_axis = z_axis
        end
        _refresh
        return true
      end
      if key == VK_DOWN
        UI.beep
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      if tool.is_key_ctrl_or_option?(key)
        _refresh
        return true
      end

      false
    end

    def onStateChanged(old_state, new_state)
      super

      @locked_axis = nil

      if has_active_selection?
        if new_state == STATE_HANDLE
          @tool.set_3d_visibility(false, [ LAYER_3D_PART_PREVIEW, LAYER_3D_PART_SIBLING_PREVIEW ]) # Hide part preview
          _hide_instances
          _hide_sibling_instances
        else
          @tool.set_3d_visibility(true, [ LAYER_3D_PART_PREVIEW, LAYER_3D_PART_SIBLING_PREVIEW ]) # Unhide part preview
          _unhide_instances
          _unhide_sibling_instances
        end
      end

    end

    def onToolActionOptionStored(tool, action, option_group, option)
      # Do not call super to keep handle start point

      if option_group == SmartHandleTool::ACTION_OPTION_AXES
        @locked_axis = nil unless @active_part.nil?
      end

    end

    def onPartSelected
      super
      @number = @cpy_instances.size + 1
      _refresh
    end

    # -----

    protected

    def _reset
      @number = 1
      super
    end

    # -----

    def _pick_part_siblings?
      true
    end

    # -----

    def _locked_x?
      return false if @locked_axis.nil?
      _get_active_x_axis.parallel?(@locked_axis)
    end

    def _locked_y?
      return false if @locked_axis.nil?
      _get_active_y_axis.parallel?(@locked_axis)
    end

    def _locked_z?
      return false if @locked_axis.nil?
      _get_active_z_axis.parallel?(@locked_axis)
    end

    # -----

    def _snap_handle(flags, x, y, view)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from 2D projection

          ps = view.screen_coords(@picked_handle_start_point)
          pe = Geom::Point3d.new(x, y, 0)

          move_axis = [ _get_active_x_axis, _get_active_y_axis, _get_active_z_axis ].map! { |axis| { d: pe.distance_to_line([ ps, ps.vector_to(view.screen_coords(@picked_handle_start_point.offset(axis))) ]), axis: axis } }.min { |a, b| a[:d] <=> b[:d] }[:axis]

        end

        picked_point, _ = Geom::closest_points([ @picked_handle_start_point, move_axis ], view.pickray(x, y))
        @mouse_snap_point = picked_point

      else

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from 3D position

          ps = @picked_handle_start_point
          pe = @mouse_ip.position
          move_axis = _get_active_x_axis

          et = _get_edit_transformation
          eti = et.inverse

          v = ps.transform(eti).vector_to(pe.transform(eti))
          if v.valid?

            bounds = Geom::BoundingBox.new
            bounds.add([ -1, -1, -1], [ 1, 1, 1 ])

            line = [ ORIGIN, v ]

            plane_btm = [ bounds.corner(0), Z_AXIS ]
            ibtm = Geom.intersect_line_plane(line, plane_btm)
            if !ibtm.nil? && bounds.contains?(ibtm)
              move_axis = _get_active_z_axis
            else
              plane_lft = [ bounds.corner(0), X_AXIS ]
              ilft = Geom.intersect_line_plane(line, plane_lft)
              if !ilft.nil? && bounds.contains?(ilft)
                move_axis = _get_active_x_axis
              else
                plane_frt = [ bounds.corner(0), Y_AXIS ]
                ifrt = Geom.intersect_line_plane(line, plane_frt)
                if !ifrt.nil? && bounds.contains?(ifrt)
                  move_axis = _get_active_y_axis
                end
              end
            end

          end

        end

        @mouse_snap_point = @mouse_ip.position.project_to_line([[ @picked_handle_start_point, move_axis ]])

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

      if @tool.is_key_ctrl_or_option_down?
        ray = [ @picked_handle_start_point, @picked_handle_start_point.vector_to(@mouse_snap_point) ]
        position, @raytest_path = Sketchup.active_model.raytest(ray)
        @mouse_snap_point = position unless position.nil?
      else
        @raytest_path = nil
      end

    end

    def _preview_handle(view)
      return super if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point)).nil?

      drawing_def, et, eb, center, lps, lpe, mps, mpe = move_def.values_at(:drawing_def, :et, :eb, :center, :lps, :lpe, :mps, :mpe)
      drawing_def_segments = _get_drawing_def_segments(drawing_def)

      return super unless (mv = mps.vector_to(mpe)).valid?
      lv = lps.vector_to(lpe)
      color = _get_vector_color(lv, Kuix::COLOR_DARK_GREY)

      _preview_edit_axes(false, !mv.parallel?(_get_active_x_axis), !mv.parallel?(_get_active_y_axis), !mv.parallel?(_get_active_z_axis), true)

      # Preview

      k_box = Kuix::BoxMotif3d.new
      k_box.bounds.copy!(eb)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.color = Kuix::COLOR_DARK_GREY
      k_box.transformation = et
      @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

      (1..@number).each do |i|

        mt = Geom::Transformation.translation(center.vector_to(mps.offset(mv, mv.length * i / (@number + 1.0))))

        k_segments = Kuix::Segments.new
        k_segments.add_segments(drawing_def_segments)
        k_segments.line_width = 1.5
        k_segments.color = Kuix::COLOR_BLACK
        k_segments.transformation = mt * drawing_def.transformation
        @tool.append_3d(k_segments, LAYER_3D_HANDLE_PREVIEW)

        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(eb)
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.color = color
        k_box.transformation = mt * et
        @tool.append_3d(k_box, LAYER_3D_HANDLE_PREVIEW)

      end

      # Preview line

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(@picked_handle_start_point)
      k_edge.end.copy!(lps)
      k_edge.line_width = 1.5
      k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_edge.color = Kuix::COLOR_DARK_GREY
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(@tool.is_key_ctrl_or_option_down? ? @mouse_snap_point : @mouse_ip.position)
      k_edge.end.copy!(lpe)
      k_edge.line_width = 1.5
      k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_edge.color = Kuix::COLOR_DARK_GREY
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      unless @raytest_path.nil?

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@picked_handle_start_point)
        k_edge.end.copy!(@mouse_snap_point)
        k_edge.line_width = 2.0
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SOLID
        k_edge.color = color
        k_edge.end_arrow = true
        k_edge.arrow_size = @tool.get_unit * 2.0
        @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      end

      @tool.append_3d(_create_floating_points(points: [ @picked_handle_start_point ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_DARK_GREY), LAYER_3D_HANDLE_PREVIEW)
      @tool.append_3d(_create_floating_points(points: [ @picked_handle_start_point ], style: Kuix::POINT_STYLE_CIRCLE, stroke_color: Kuix::COLOR_DARK_GREY), LAYER_3D_HANDLE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ center ], style: Kuix::POINT_STYLE_PLUS), LAYER_3D_HANDLE_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = ColorUtils.color_translucent(color, 60)
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.line_width = 1.5 unless @locked_axis.nil?
      k_edge.color = color
      @tool.append_3d(k_edge, LAYER_3D_HANDLE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ lps, lpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_HANDLE_PREVIEW)

      # Preview distance

      distance = lv.length

      Sketchup.set_status_text(distance, SB_VCB_VALUE)

      if distance > 0

        k_label = _create_floating_label(
          snap_point: lps.offset(lv, distance / 2),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(tool, text, view)

      ps = @picked_handle_start_point
      pe = @mouse_snap_point
      v = ps.vector_to(pe)

      distance = _read_user_text_length(tool, text, v.length)
      return true if distance.nil?

      @picked_handle_end_point = ps.offset(v, distance)

      _handle_entity
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    def _read_handle_copies(tool, text, view)

      if text && (match = text.match(/^([x*\/])(\d+)$/))

        if _fetch_option_mirror
          tool.notify_errors([ [ "tool.smart_handle.error.disabled_by_mirror" ] ])
          return true
        end

        operator, value = match ? match[1, 2] : [ nil, nil ]

        number = value.to_i

        if operator == '/' && number < 2
          UI.beep
          tool.notify_errors([ [ "tool.default.error.invalid_divider", { :value => value } ] ])
          return true
        end
        if number == 0
          UI.beep
          tool.notify_errors([ [ "tool.default.error.invalid_multiplicator", { :value => value } ] ])
          return true
        end

        count = operator == '/' ? number - 1 : number

        case @state

        when STATE_HANDLE
          @number = count

        when STATE_HANDLE_COPIES
          _distribute_entity(count)

        end
        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    # -----

    def _handle_entity
      _distribute_entity(@number)
    end

    def _distribute_entity(number = 1)
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point)).nil?

      center, mps, mpe = move_def.values_at(:center, :mps, :mpe)

      ct = _get_global_context_transformation
      cti = ct.inverse

      center = center.transform(cti)
      mps = mps.transform(cti)
      mpe = mpe.transform(cti)
      mv = mps.vector_to(mpe)

      _unhide_instances
      _unhide_sibling_instances

      model = Sketchup.active_model
      model.start_operation('OCL Distribute Part', true, false, !active?)


        src_instances = get_active_selection_instances

        if get_active_selection_path.empty?
          entities = model.active_entities
        else
          entities = get_active_selection_path.last.definition.entities
        end

        entities.erase_entities(@cpy_instances) if @cpy_instances.any?
        @cpy_instances.clear

        src_instances.each do |src_instance|

          definition = src_instance.definition

          (1..number).each do |i|

            mt = Geom::Transformation.translation(center.vector_to(mps.offset(mv, mv.length * i / (number + 1.0))))
            mt *= @src_transformations[src_instance]

            if i == 1

              src_instance.transformation = mt

            else

              dst_instance = entities.add_instance(definition, mt)

              @cpy_instances << dst_instance

              _copy_instance_metas(src_instance, dst_instance)

            end

          end

        end

        @number = number

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe)
      return unless ps.is_a?(Geom::Point3d) && pe.is_a?(Geom::Point3d)
      return unless (v = ps.vector_to(pe)).valid?
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eti = et.inverse

      return unless (eb = _get_drawing_def_edit_bounds(drawing_def, et)).valid?

      # Compute in 'Edit' space

      ev = v.transform(eti)

      ecenter = eb.center
      eline = [ ecenter, ev ]

      plane_btm = [ eb.corner(0), Z_AXIS ]
      ibtm = Geom.intersect_line_plane(eline, plane_btm)
      if !ibtm.nil? && eb.contains?(ibtm)
        evs = ecenter.vector_to(ibtm)
        evs.reverse! if evs.valid? && evs.samedirection?(ev)
      else
        plane_lft = [ eb.corner(0), X_AXIS ]
        ilft = Geom.intersect_line_plane(eline, plane_lft)
        if !ilft.nil? && eb.contains?(ilft)
          evs = ecenter.vector_to(ilft)
          evs.reverse! if evs.valid? && evs.samedirection?(ev)
        else
          plane_frt = [ eb.corner(0), Y_AXIS ]
          ifrt = Geom.intersect_line_plane(eline, plane_frt)
          if !ifrt.nil? && eb.contains?(ifrt)
            evs = ecenter.vector_to(ifrt)
            evs.reverse! if evs.valid? && evs.samedirection?(ev)
          else
            evs = Geom::Vector3d.new
          end
        end
      end

      # Restore to 'Global' space

      center = ecenter.transform(et)
      line = [ center, v ]
      vs = evs.transform(et)
      ve = vs.reverse

      lps = ps.project_to_line(line)
      lpe = pe.project_to_line(line)

      mps = lps.offset(vs)
      mpe = lpe.offset(ve)

      {
        drawing_def: drawing_def,
        et: et,
        eb: eb,   # Expressed in 'Edit' space
        center: center,
        vs: vs,
        ve: ve,
        lps: lps,
        lpe: lpe,
        mps: mps,
        mpe: mpe
      }
    end

  end

end