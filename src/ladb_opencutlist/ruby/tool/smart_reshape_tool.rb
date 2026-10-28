module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/geom/bounds3d'
  require_relative '../lib/geometrix/geometrix'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'
  require_relative '../manipulator/cline_manipulator'
  require_relative '../helper/user_text_helper'
  require_relative '../helper/face_matcher_helper'
  require_relative '../utils/lock_utils'
  require_relative '../utils/component_utils'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_solid_boolean_apply_worker'
  require_relative '../worker/common/common_solid_rebuild_from_clines_worker'
  require_relative '../worker/common/common_stretch_split_worker'
  require_relative '../worker/common/common_stretch_apply_worker'

  class SmartReshapeTool < SmartTool

    ACTION_STRETCH = 0
    ACTION_PANELING = 1
    ACTION_SOLID_UNITE = 2
    ACTION_SOLID_SUBTRACT = 3
    ACTION_SOLID_INTERSECT = 4
    ACTION_SLICE = 5

    ACTION_OPTION_THICKNESS = 'thickness'
    ACTION_OPTION_STRETCH_MEASURE_TYPE = 'stretch_measure_type'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_PANELING_DIRECTION = 'paneling_direction'
    ACTION_OPTION_PANELING_JOINT_TYPE = 'paneling_joint_type'
    ACTION_OPTION_SLICE_MODE = 'slice_mode'
    ACTION_OPTION_SLICE_REFERENCE = 'slice_reference'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_THICKNESS_THICKNESS = 'thickness'

    ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE = 'outside'
    ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET = 'offset'

    ACTION_OPTION_AXES_ACTIVE = 'active'
    ACTION_OPTION_AXES_CONTEXT = 'context'
    ACTION_OPTION_AXES_ENTITY = 'entity'

    ACTION_OPTION_PANELING_DIRECTION_INWARD = 'inward'
    ACTION_OPTION_PANELING_DIRECTION_OUTWARD = 'outward'

    ACTION_OPTION_PANELING_JOINT_TYPE_FLAT = 'flat'
    ACTION_OPTION_PANELING_JOINT_TYPE_MITER = 'miter'

    ACTION_OPTION_SLICE_MODE_SLICE = 'slice'
    ACTION_OPTION_SLICE_MODE_CUT = 'cut'

    ACTION_OPTION_SLICE_REFERENCE_FACE = 'face'
    ACTION_OPTION_SLICE_REFERENCE_POINTS = 'points'

    ACTION_OPTION_OPTIONS_CENTERED = 'centered'
    ACTION_OPTION_OPTIONS_MAKE_UNIQUE = 'make_unique'
    ACTION_OPTION_OPTIONS_KEEP_A = 'keep_a'
    ACTION_OPTION_OPTIONS_KEEP_B = 'keep_b'
    ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS = 'remove_unused_definitions'
    ACTION_OPTION_OPTIONS_REUSE_DEFINITION = 'reuse_definition'
    ACTION_OPTION_OPTIONS_REUSE_DEFINITION_MIRRORED = 'reuse_definition_mirrored'

    ACTIONS = [
      {
        :action => ACTION_STRETCH,
        :options => {
          ACTION_OPTION_STRETCH_MEASURE_TYPE => [ ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CENTERED, ACTION_OPTION_OPTIONS_MAKE_UNIQUE ]
        }
      },
      {
        :action => ACTION_SOLID_UNITE,
        :options => {
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_KEEP_A, ACTION_OPTION_OPTIONS_KEEP_B, ACTION_OPTION_OPTIONS_MAKE_UNIQUE, ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS ]
        }
      },
      {
        :action => ACTION_SOLID_SUBTRACT,
        :options => {
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_KEEP_A, ACTION_OPTION_OPTIONS_KEEP_B, ACTION_OPTION_OPTIONS_MAKE_UNIQUE, ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS ]
        }
      },
      {
        :action => ACTION_SOLID_INTERSECT,
        :options => {
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_KEEP_A, ACTION_OPTION_OPTIONS_KEEP_B, ACTION_OPTION_OPTIONS_MAKE_UNIQUE, ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS ]
        }
      },
      {
        :action => ACTION_SLICE,
        :options => {
          ACTION_OPTION_SLICE_MODE => [ ACTION_OPTION_SLICE_MODE_SLICE, ACTION_OPTION_SLICE_MODE_CUT ],
          ACTION_OPTION_SLICE_REFERENCE => [ ACTION_OPTION_SLICE_REFERENCE_FACE, ACTION_OPTION_SLICE_REFERENCE_POINTS ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT, ACTION_OPTION_AXES_ENTITY ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MAKE_UNIQUE ]
        }
      },
      {
        :action => ACTION_PANELING,
        :options => {
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_PANELING_DIRECTION => [ ACTION_OPTION_PANELING_DIRECTION_INWARD, ACTION_OPTION_PANELING_DIRECTION_OUTWARD ],
          ACTION_OPTION_PANELING_JOINT_TYPE => [ ACTION_OPTION_PANELING_JOINT_TYPE_FLAT, ACTION_OPTION_PANELING_JOINT_TYPE_MITER ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_REUSE_DEFINITION_MIRRORED ]
        }
      }
    ].freeze

    # -----

    attr_reader :callback_action_handler
    attr_accessor :startup_selection

    def initialize(current_action: nil, callback_action_handler: nil, startup_selection: nil)
      super(current_action: current_action)

      @callback_action_handler = callback_action_handler
      @startup_selection = startup_selection

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
        return SmartCursorManager.cursor_select
      when ACTION_PANELING
        return SmartCursorManager.cursor_select
      when ACTION_SOLID_UNITE
        return SmartCursorManager.cursor_select
      when ACTION_SOLID_SUBTRACT
        return SmartCursorManager.cursor_select
      when ACTION_SOLID_INTERSECT
        return SmartCursorManager.cursor_select
      when ACTION_SLICE
        return SmartCursorManager.cursor_select
      end

      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_PANELING
        return false
      end

      false
    end

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_KEEP_A, ACTION_OPTION_OPTIONS_KEEP_B, ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS
          return [ ACTION_SOLID_UNITE, ACTION_SOLID_SUBTRACT, ACTION_SOLID_INTERSECT ]
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return [ ACTION_STRETCH, ACTION_SOLID_UNITE, ACTION_SOLID_SUBTRACT, ACTION_SOLID_INTERSECT, ACTION_SLICE ]
        end
      end

      super
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_THICKNESS
        case option
        when ACTION_OPTION_THICKNESS_THICKNESS
          return false
        end
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group

      when ACTION_OPTION_STRETCH_MEASURE_TYPE
        return true

      when ACTION_OPTION_AXES
        return true

      when ACTION_OPTION_PANELING_DIRECTION
        return true

      when ACTION_OPTION_PANELING_JOINT_TYPE
        return true

      when ACTION_OPTION_SLICE_MODE
        return true

      when ACTION_OPTION_SLICE_REFERENCE
        return true

      end

      false
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_THICKNESS
        case option
        when ACTION_OPTION_THICKNESS_THICKNESS
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
          end
      when ACTION_OPTION_STRETCH_MEASURE_TYPE
        case option
        when ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.917V.583H1V.917ZM0,.25H1M0,.083V.417M1,.083V.417'))
        when ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.917V.583H.5V.917ZM.5,.25H1M.5,.083V.417M1,.083V.417M.75,.583H1V.917H.75'))
        end
      when ACTION_OPTION_AXES
        case option
        when ACTION_OPTION_AXES_ACTIVE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,0V.833H1M0,.167L.167,0L.333,.167M.833,.667L1,.833L.833,1'))
        when ACTION_OPTION_AXES_CONTEXT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,0V.833H1M0,.167L.167,0L.333,.167M.833,.667L1,.833L.833,1M.5,.083V.5H.917V.083Z'))
        when ACTION_OPTION_AXES_ENTITY
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.25,0V.75H1M.083,.167L.25,0L.417,.167M.833,.583L1,.75L.833,.917M.042,.5V.958H.5V.5Z'))
        end
      when ACTION_OPTION_PANELING_DIRECTION
        case option
        when ACTION_OPTION_PANELING_DIRECTION_INWARD
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.125,.125H.875V.875M.625,.375L.375,.625M.375,.375V.625H.625'))
        when ACTION_OPTION_PANELING_DIRECTION_OUTWARD
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.375H.625V1M.75,.25L1,0M1,.25V0H.75'))
        end
      when ACTION_OPTION_PANELING_JOINT_TYPE
        case option
        when ACTION_OPTION_PANELING_JOINT_TYPE_FLAT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0V1H.625V.375M1,0H0V.375H.625V0'))
        when ACTION_OPTION_PANELING_JOINT_TYPE_MITER
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0V.375H.625L1,0ZM1,0V1H.625V.375'))
        end
      when ACTION_OPTION_SLICE_MODE
        case option
        when ACTION_OPTION_SLICE_MODE_SLICE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.25H.375V.75H0ZM.625,.25H1V.75H.625ZM.5,0V.25M.5,.375V.625M.5,.75V1'))
        when ACTION_OPTION_SLICE_MODE_CUT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.25H.375V.75H0ZM.75,.25H.625V.375M.875,.25H1V.375M.75,.75H.625V.625M.875,.75H1V.625M.5,0V.25M.5,.375V.625M.5,.75V1'))
        end
      when ACTION_OPTION_SLICE_REFERENCE
        case option
        when ACTION_OPTION_SLICE_REFERENCE_FACE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.5,0L0,.5L.5,1L1,.5Z'))
        when ACTION_OPTION_SLICE_REFERENCE_POINTS
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,.833L.5,.167L.833,.833ZM.083,.75V.917H.25V.75ZM.417,.083V.25H.583V.083ZM.75,.75V.917H.917V.75Z'))
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1H.667L1,.667V0H.333L0,.333ZM0,.333H.667V1M.667,.333L1,0M.333,.5V.833M.167,.667H.5'))
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,.167V.833M.417,.167V.833M0,.333H.583M0,.667H.583M.75,.333L1,.167V.833'))
        when ACTION_OPTION_OPTIONS_KEEP_A
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_reshape.action_option_options_keep_a'))
        when ACTION_OPTION_OPTIONS_KEEP_B
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_reshape.action_option_options_keep_b'))
        when ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.75,.625H.25V.75H.75ZM.5,.625V0M.25,.75L.188,1M.75,.75L.813,1M.375,.75L.345,1M.5,.75V1M.625,.75L.655,1'))
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.333H.667V1H0ZM.333,.333V0H1V.667H.667'))
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION_MIRRORED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.5,0V.2M.5,.4V.6M.5,.8V1M0,.2L.3,.5L0,.8ZM1,.2L.7,.5L1,.8Z'))
        end
      end

      super
    end

    def get_action_option_btn_disabled?(action, option_group, option)

      case option_group

      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION_MIRRORED
          return !fetch_action_option_boolean(action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
        end
      end

      super
    end

    # -- Events --

    def onActionChanged(action)

      clear_all_2d
      clear_all_3d

      case action
      when ACTION_STRETCH
        set_action_handler(SmartReshapeStretchActionHandler.new(self, fetch_action_handler))
      when ACTION_PANELING
        set_action_handler(SmartReshapePanelingActionHandler.new(self, fetch_action_handler))
      when ACTION_SOLID_UNITE
        set_action_handler(SmartReshapeSolidUniteActionHandler.new(self, fetch_action_handler))
      when ACTION_SOLID_SUBTRACT
        set_action_handler(SmartReshapeSolidSubtractActionHandler.new(self, fetch_action_handler))
      when ACTION_SOLID_INTERSECT
        set_action_handler(SmartReshapeSolidIntersectActionHandler.new(self, fetch_action_handler))
      when ACTION_SLICE
        set_action_handler(SmartReshapeSliceActionHandler.new(self, fetch_action_handler))
      end

      super
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

  class SmartReshapeStretchActionHandler < SmartSelectActionHandler

    include UserTextHelper

    STATE_STRETCH_START = 1
    STATE_STRETCH = 2
    STATE_STRETCH_CUTTER_MOVE = 10
    STATE_STRETCH_CUTTER_ADD = 11
    STATE_STRETCH_CUTTER_REMOVE = 12

    LAYER_3D_STRETCH_PREVIEW = 10
    LAYER_3D_GRIPS_PREVIEW = 100
    LAYER_3D_CUTTERS_PREVIEW = 200

    PX_INFLATE_VALUE = 50

    @@last_cutters_data = nil

    @@last_stretch_measures = { :outside => 0, :offset => 0 }

    attr_writer :ignore_next_lbutton_up
    attr_reader :picked_axis, :picked_interior_handle

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_STRETCH, tool, previous_action_handler)

      @mouse_ip = SmartInputPoint.new(tool)

      @mouse_down_point = nil
      @mouse_snap_point = nil

      @ignore_next_lbutton_up = false

      @picked_stretch_start_point = nil
      @picked_stretch_end_point = nil

      @picked_axis = nil
      @picked_grip_index = nil
      @picked_interior_handle = nil

      # While SHIFT is held over an interior handle, the handle stays picked and its stretch start
      # point can be taken anywhere, projected on the handle axis.
      @interior_handle_locked = false

      # SHIFT still held when the stretch starts must not trigger the last measure lock
      @stretch_shift_ignored = false

      # An end grip stretch leaves the mouse right on the grip it moved, so the next mouse move
      # picks its axis again by itself. An interior one leaves it on its handle, which is only
      # pickable once an axis is active : carry the axis over so the stretch can be chained.
      if previous_action_handler.is_a?(SmartReshapeStretchActionHandler) &&
         !previous_action_handler.picked_interior_handle.nil?
        @picked_axis = previous_action_handler.picked_axis
      end

      @cutters = nil

      @picked_cutter_index = nil
      @picked_cutter_start_point = nil

      @locked_axis = nil

      @extern_instances_ref_positions = {}

      # Create 3D layers
      tool.create_3d(LAYER_3D_STRETCH_PREVIEW)
      tool.create_3d(LAYER_3D_PART_TWINS_PREVIEW)
      tool.create_3d(LAYER_3D_PART_PREVIEW)

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
      _unhide_instances
      super
    end

    # -----

    def close_doors_on_start?
      true
    end

    # -----

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_STRETCH_START, STATE_STRETCH
        return SmartCursorManager.cursor_select_stretch
      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_option_options_make_unique_status") + '.'

      when STATE_STRETCH_START
        return super if @picked_axis.nil?
        # An interior handle stretches too, but at constant overall dimension
        status = if @picked_interior_handle.nil?
                   super + ' ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1a_status") + '.'
                 else
                   PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1d_status") + '.'
                 end
        return status +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1b_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1c_status") + '.'

      when STATE_STRETCH
        status = super +
                 ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string("tool.default.locked_on_last_measure_status") + '.'
        # The "centered" option has no meaning for an interior stretch : the overall dimension is preserved
        status += ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_option_options_centered_status") + '.' if @picked_interior_handle.nil?
        return status +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_option_options_make_unique_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_STRETCH
        return PLUGIN.get_i18n_string("tool.default.vcb_distance")

      end

      super
    end

    # -----

    def onToolSuspend(tool, view)
      super
      _unhide_instances if @state == STATE_STRETCH
    end

    def onToolResume(tool, view)
      super
      _hide_instances if @state == STATE_STRETCH
    end

    def onToolCancel(tool, reason, view)
      super

      if @tool.callback_action_handler.nil?

        case @state

        when STATE_STRETCH
          set_state(STATE_STRETCH_START)
          _refresh
          return true

        when STATE_STRETCH_START
          @picked_shape_start_point = nil
          _unhide_instance
          _unhide_twin_instances
        end

        _reset
        _refresh

      else
        # stop
        Sketchup.active_model.tools.pop_tool
      end

      true
    end

    def onToolMouseMove(tool, flags, x, y, view)
      check_super = true
      case @state

      when STATE_STRETCH_START
        @tool.clear_3d([ LAYER_3D_PART_PREVIEW, LAYER_3D_CUTTERS_PREVIEW, LAYER_3D_GRIPS_PREVIEW ])
        check_super = @mouse_down_point.nil?

      end

      if check_super
        super

        return true if x < 0 || y < 0

        case @state

        when STATE_STRETCH_START

          @mouse_snap_point = nil

          @tool.clear_all_2d
          @tool.clear_3d([LAYER_3D_STRETCH_PREVIEW ])

          previous_interior_handle = @picked_interior_handle

          _snap_stretch_start(flags, x, y, view)
          _preview_stretch_start(view)

          # The status differs when an interior handle is hovered
          if previous_interior_handle.nil? != @picked_interior_handle.nil?
            @tool.set_status_prompt(get_state_status(@state))
          end

        when STATE_STRETCH

          @mouse_snap_point = nil
          @mouse_ip.pick(view, x, y)

          @tool.clear_all_2d
          @tool.clear_3d(LAYER_3D_STRETCH_PREVIEW)

          _snap_stretch(flags, x, y, view)
          _preview_stretch(view)

        end

        view.tooltip = @mouse_ip.tooltip
        view.invalidate

      end

      case @state

      when STATE_STRETCH_START
        unless @mouse_down_point.nil? || @picked_grip_index.nil?
          if Geom::Point3d.new(x, y).distance(@mouse_down_point) > 20  # Drag handled only if the distance is > 20px

            drawing_def = _get_drawing_def
            et = _get_edit_transformation
            eb = _get_drawing_def_edit_bounds(drawing_def, et)
            keb = Kuix::Bounds3d.new.copy!(eb)

            _pick_stretch_start_points(keb, et)

            @mouse_down_point = nil
            set_state(STATE_STRETCH) if _assert_valid_cutters
          end
        end

      when STATE_STRETCH_CUTTER_MOVE

        @mouse_snap_point = nil

        @tool.clear_all_2d
        @tool.clear_3d([LAYER_3D_CUTTERS_PREVIEW ])

        _snap_stretch_cutter_move(flags, x, y, view)
        _preview_stretch_cutter_move(view)

      when STATE_STRETCH_CUTTER_ADD

        @mouse_snap_point = nil

        @tool.clear_all_2d
        @tool.clear_3d(LAYER_3D_CUTTERS_PREVIEW)

        _snap_stretch_cutter_add(flags, x, y, view)
        _preview_stretch_cutter_add(view)

      when STATE_STRETCH_CUTTER_REMOVE

        @mouse_snap_point = nil

        @tool.clear_all_2d
        @tool.clear_3d(LAYER_3D_CUTTERS_PREVIEW)

        _snap_stretch_cutter_remove(flags, x, y, view)
        _preview_stretch_cutter_remove(view)

      end

      false
    end

    def onToolMouseLeave(tool, view)
      return true if super
      @tool.clear_all_2d
      @mouse_ip.clear
      view.tooltip = ''
    end

    def onToolLButtonDown(tool, flags, x, y, view)

      @ignore_next_lbutton_up = false  # A "down" always pairs with the following "up"

      case @state

      when STATE_STRETCH_START
        unless @picked_cutter_index.nil?

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
          if @picked_cutter_start_point.nil?
            # Ray is certainly parallel to the direction, so we use the intersection between direction and plan
            @picked_cutter_start_point = Geom.intersect_line_plane([min, direction], plane)
          end

          set_state(STATE_STRETCH_CUTTER_MOVE)
          _refresh
          return true
        end

        unless @picked_grip_index.nil?

          @mouse_down_point = Geom::Point3d.new(x, y,)

          return true
        end

        return true

      when STATE_STRETCH_CUTTER_ADD, STATE_STRETCH_CUTTER_REMOVE
        return true

      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      # Ignore the "up" event that trails a double click : it isn't paired with a "down" and it is
      # dispatched to the handler recreated by the '_restart' triggered by the double click.
      if @ignore_next_lbutton_up
        @ignore_next_lbutton_up = false
        return true
      end

      case @state

      when STATE_STRETCH_START
        unless @picked_grip_index.nil?

          drawing_def = _get_drawing_def
          et = _get_edit_transformation
          eb = _get_drawing_def_edit_bounds(drawing_def, et)
          keb = Kuix::Bounds3d.new.copy!(eb)

          _pick_stretch_start_points(keb, et)
          @mouse_down_point = nil

          set_state(STATE_STRETCH) if _assert_valid_cutters
          _refresh
          return true
        end
        if @picked_cutter_index.nil?
          _reset
          _refresh
          return true
        end

      when STATE_STRETCH_CUTTER_MOVE
        unless @picked_cutter_index.nil?
          _store_cutters
          _load_cutters # Reload to sanitize
          set_state(STATE_STRETCH_START)
          _refresh
          return true
        end

      when STATE_STRETCH_CUTTER_ADD
        if @snap_ratio
          @cutters[@picked_axis] << @snap_ratio
          @snap_ratio = nil
          _store_cutters
          _load_cutters # Reload to sanitize
          _refresh
        end
        return true

      when STATE_STRETCH_CUTTER_REMOVE
        unless @picked_cutter_index.nil?
          @cutters[@picked_axis].delete_at(@picked_cutter_index)
          @picked_cutter_index = nil
          _store_cutters
          _load_cutters # Reload to sanitize
          _refresh
        end
        return true

      end

      @mouse_down_point = nil

      case @state

      when STATE_STRETCH_START
        @picked_stretch_start_point = @mouse_snap_point
        set_state(STATE_STRETCH)
        _refresh

      when STATE_STRETCH
        @picked_stretch_end_point = @mouse_snap_point
        _stretch_entity
        _restart

      end

      super
    end

    def onToolLButtonDoubleClick(tool, flags, x, y, view)

      case @state

      when STATE_STRETCH

        # Reuse the last measure AND its way : the direction is the grip outward one, the sign of
        # the measure tells if the shape was expanded or compressed.
        measure = _fetch_last_stretch_measure
        unless measure == 0 || (measure_def = _get_stretch_measure_def(measure, @mouse_snap_point, _get_stretch_outward_direction)).nil?

          @picked_stretch_end_point = measure_def[:end_point]

          _stretch_entity  # Silently clamped to the max compression distance by '_get_stretch_def'

          new_action_handler = _restart
          new_action_handler.ignore_next_lbutton_up = true if new_action_handler.is_a?(SmartReshapeStretchActionHandler)

          return true
        end

        UI.beep

      end

      false
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super

      if tool.is_key_alt_or_command?(key) && (@state == STATE_SELECT || @state == STATE_STRETCH)
        return true # Block default behavior for the ALT key on Windows
      end

      case @state

      when STATE_STRETCH_START
        if key == VK_RIGHT
          if @locked_axis == X_AXIS
            @locked_axis = nil
          else
            @locked_axis = X_AXIS
          end
          _refresh
          return true
        end
        if key == VK_LEFT
          if @locked_axis == Y_AXIS
            @locked_axis = nil
          else
            @locked_axis = Y_AXIS
          end
          _refresh
          return true
        end
        if key == VK_UP
          if @locked_axis == Z_AXIS
            @locked_axis = nil
          else
            @locked_axis = Z_AXIS
          end
          _refresh
          return true
        end
        if key == VK_DOWN
          @locked_axis = nil
          _refresh
          return true
        end
        if tool.is_key_shift?(key)
          unless @picked_interior_handle.nil? || @interior_handle_locked
            @interior_handle_locked = true
            _refresh
          end
          return true
        end
        unless @picked_axis.nil?
          if tool.is_key_ctrl_or_option?(key)
            set_state(STATE_STRETCH_CUTTER_ADD)
            _refresh
            return true
          end
          if tool.is_key_alt_or_command?(key)
            set_state(STATE_STRETCH_CUTTER_REMOVE)
            _refresh
            return true
          end
        end

      when STATE_STRETCH

        if tool.is_key_shift?(key)
          return true if @stretch_shift_ignored
          UI.beep if _fetch_last_stretch_measure == 0
          _refresh
          return true
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      if tool.is_key_alt_or_command?(key) && is_quick && (@state == STATE_SELECT || @state == STATE_STRETCH)
        @tool.store_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE, !_fetch_option_options_make_unique?, fire_event: true)
        _refresh
        return true
      end

      case @state

      when STATE_STRETCH_START
        if tool.is_key_shift?(key)
          if @interior_handle_locked
            @interior_handle_locked = false
            _refresh
          end
          return true
        end

      when STATE_STRETCH_CUTTER_ADD, STATE_STRETCH_CUTTER_REMOVE
        if tool.is_key_ctrl_or_option?(key)
          @snap_ratio = nil
          set_state(STATE_STRETCH_START)
          _refresh
          return true
        end
        if tool.is_key_alt_or_command?(key)
          set_state(STATE_STRETCH_START)
          _refresh
          return true
        end

      when STATE_STRETCH
        if tool.is_key_ctrl_or_option?(key) && is_quick
          @tool.store_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_CENTERED, !_fetch_option_options_centered?, fire_event: true)
          _refresh
          return true
        end
        if tool.is_key_shift?(key)
          @stretch_shift_ignored = false
          _refresh  # Release the measure lock
          return true
        end

      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      case @state

      when STATE_STRETCH
        if _read_stretch(tool, text, view)
          _restart
          return true
        end

      end

      false
    end

    def onToolActionOptionStored(tool, action, option_group, option)

      if option_group == SmartReshapeTool::ACTION_OPTION_AXES && @state > STATE_STRETCH_START
        set_state(STATE_STRETCH_START)
        _refresh
      end

    end

    def onStateChanged(old_state, new_state)
      super

      @interior_handle_locked = false
      @stretch_shift_ignored = new_state == STATE_STRETCH && @tool.is_key_shift_down?

      case old_state

      when STATE_STRETCH, STATE_STRETCH_START
        Sketchup.active_model.selection.clear

      end

      case new_state

      when STATE_STRETCH, STATE_STRETCH_START
        unless has_active_part?
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(get_active_selection_instances)
        end
        @tool.clear_all_2d

      end

      if has_active_selection?

        case new_state

        when STATE_STRETCH_START
          @tool.clear_all_2d
          @tool.clear_3d([LAYER_3D_PART_PREVIEW, LAYER_3D_PART_TWINS_PREVIEW ])  # Remove part preview
          _unhide_instances

        when STATE_STRETCH_CUTTER_MOVE
          @tool.clear_3d(LAYER_3D_GRIPS_PREVIEW)
          _unhide_instances

        when STATE_STRETCH_CUTTER_ADD, STATE_STRETCH_CUTTER_REMOVE
          @tool.clear_3d(LAYER_3D_GRIPS_PREVIEW)
          _unhide_instances

        when STATE_STRETCH
          @tool.clear_3d([LAYER_3D_GRIPS_PREVIEW, LAYER_3D_CUTTERS_PREVIEW ])
          _get_split_def    # Compute a new split_def
          _hide_instances

        end

      end

    end

    def onSelected
      return true if super

      _reset_drawing_def
      _load_cutters

      set_state(STATE_STRETCH_START)

      _refresh

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
      @picked_stretch_start_point = nil
      @picked_stretch_end_point = nil
      @picked_stretch_start_opposite_point = nil
      @split_def = nil
      @picked_axis = nil
      @picked_grip_index = nil
      @picked_interior_handle = nil
      @interior_handle_locked = false
      @picked_cutter_index = nil
      @extern_instances_ref_positions = {}
      super
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

    def _pick_part_twins?
      true
    end

    def _start_with_previous_selection?
      true
    end

    def _allows_multiple_selections?
      true
    end

    def _allows_tree_selection?
      true
    end

    def _clear_selection_on_start?
      true
    end

    # -----

    def _can_activate_locked?
      false
    end

    # -----

    def _preview_all_instances?
      !_fetch_option_options_make_unique?
    end

    def _preview_part_box?
      true
    end

    def _get_path_part_preview_color(path, part, highlighted = false)
      # Occurrences reachable through a locked path won't follow the stretch
      # (isolate context + make unique routines): preview them grey.
      if path != @active_part_entity_path && LockUtils.locked_path?(path)
        return highlighted ? COLOR_LOCKED_INSTANCE_HIGHLIGHTED : COLOR_LOCKED_INSTANCE
      end
      super
    end

    def _preview_part(part_entity_path, part, layer = 0, highlighted: false, clear_before: true)
      super
      if part && fetch_state == STATE_SELECT

        # Show part infos
        @tool.set_root_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

      else

        @tool.remove_root_tooltip

      end
    end

    # -----

    def _add_part_twin(part_entity_path, part)
      return true if super
      get_active_selection_instances << part_entity_path.last
    end

    # -----

    # Set the stretch start point - and the opposite one, used as the "outward" reference by the
    # last measure reuse - from the picked handle : a bbox face center for an end grip, the handle
    # point itself for an interior one, whose outward way is the axis.
    def _pick_stretch_start_points(keb, et)
      if @picked_interior_handle.nil?
        @picked_stretch_start_point = keb.face_center(@picked_grip_index).to_p.transform(et)
        @picked_stretch_start_opposite_point = keb.face_center(Kuix::Bounds3d.face_opposite(@picked_grip_index)).to_p.transform(et)
      else
        @picked_stretch_start_point = @picked_interior_handle[:point]
        @picked_stretch_start_opposite_point = @picked_stretch_start_point.offset(@picked_axis.transform(et).reverse)
      end
    end

    # True when the mouse inference point tells a stable position along 'direction' : an exact point,
    # an edge perpendicular to it, or a face facing it. Anywhere else the point slides freely along
    # the direction, so it says nothing about it and the raw mouse ray is a better source.
    def _stretch_ip_stable_along?(direction)
      return false unless @mouse_ip.valid?
      !(@mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1 ||
        @mouse_ip.face && @mouse_ip.face == @mouse_ip.instance_path.leaf && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(direction) ||
        @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(direction))
    end

    # The point of the given segment closest to the given point, ends included.
    def _get_segment_clamped_point(points, point)
      p0 = points.first
      p1 = points.last
      v = p0.vector_to(p1)
      return p0 unless v.valid?
      ratio = p0.vector_to(point).dot(v) / v.dot(v)
      return p0 if ratio <= 0
      return p1 if ratio >= 1
      p0.offset(v, v.length * ratio)
    end

    # The point of the given segment closest to the given line, ends included.
    def _get_segment_closest_point(points, line)
      p0 = points.first
      v = p0.vector_to(points.last)
      return p0 unless v.valid?
      point, _ = Geom.closest_points([ p0, v ], line)
      return p0 if point.nil?
      _get_segment_clamped_point(points, point)
    end

    # The point of the given segment a stretch starts from, and whether it is magnetized : the mouse
    # inference point projected on the segment when it tells a known position along it - a vertex,
    # an edge across it, a face facing it - so the move can start from a precise origin, else the
    # point closest to the mouse ray. The inference point is only a source here : it is released
    # right away so the grab point drawn on the segment stays the only feedback.
    def _get_segment_grab_point(points, view, x, y)
      if (v = points.first.vector_to(points.last)).valid?
        @mouse_ip.pick(view, x, y)
        point = _stretch_ip_stable_along?(v) ? _get_segment_clamped_point(points, @mouse_ip.position) : nil
        @mouse_ip.clear
        return [ point, true ] unless point.nil?
      end
      [ _get_segment_closest_point(points, view.pickray(x, y)), false ]
    end

    def _snap_stretch_start(flags, x, y, view)

      if @interior_handle_locked && !@picked_interior_handle.nil?
        _snap_stretch_start_locked_interior_handle(view, x, y)
        return true
      end

      @picked_grip_index = nil
      @picked_interior_handle = nil
      @picked_cutter_index = nil

      @mouse_ip.clear   # This state never displays an inference : a section handle only reads it

      return false unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      stretchable_axes = _get_stretchable_axes(keb, et)

      @locked_axis = nil if @locked_axis && !stretchable_axes.include?(@locked_axis)
      @picked_axis = @locked_axis unless @locked_axis.nil?
      @picked_axis = nil if @picked_axis && !stretchable_axes.include?(@picked_axis)   # A carried over axis may be forbidden here

      ph = view.pick_helper(x, y)

      # Snap to grip?

      stretchable_axes.select { |axis| @locked_axis.nil? || axis == @locked_axis }.each do |axis|
        grip_indices = Kuix::Bounds3d.faces_by_axis(axis)
        grip_indices.each do |grip_index|
          p = keb.face_center(grip_index).to_p.transform(et)
          if ph.test_point(p, x, y, @picked_axis.nil? || axis == @picked_axis ? 30 : 10)
            @picked_axis = axis
            @picked_grip_index = grip_index
            @split_def = nil
            @mouse_snap_point = p
            return true
          end
        end
      end

      unless @cutters.nil? || @picked_axis.nil?

        # Snap to an interior handle?

        _get_interior_handle_defs(keb, et).each do |handle_def|

          # A section handle is grabbable all along its slab segment, magnetized to the geometry
          next unless ph.pick_segment(handle_def[:points], x, y, 20)
          handle_def[:point], handle_def[:magnetized] = _get_segment_grab_point(handle_def[:points], view, x, y)

          @picked_interior_handle = handle_def
          # An interior handle isn't attached to a bbox face. The split def only needs the axis
          # orientation, so synthesize the "max" grip to get a canonical - never reversed -
          # section order.
          @picked_grip_index = Kuix::Bounds3d.faces_by_axis(@picked_axis).last
          @split_def = nil
          @mouse_snap_point = handle_def[:point]
          return true
        end

        # Snap to a cutter?

        direction = @picked_axis.transform(et)
        min = eb.min.transform(et)
        max = eb.max.transform(et)
        min_plane = [ min, direction ]
        max_plane = [ max, direction ]
        vmax = min.vector_to(min.project_to_plane(max_plane))

        if vmax.valid?

          inch_inflate_value = view.pixels_to_model(PX_INFLATE_VALUE, eb.center.transform(et))

          quad_index, _ = Kuix::Bounds3d.faces_by_axis(@picked_axis)
          quad_ref = keb.inflate_all!(inch_inflate_value).get_quad(quad_index).map { |point| point.transform(et).project_to_plane(min_plane)}

          p2d = Geom::Point3d.new(x, y)
          @cutters[@picked_axis].each_with_index do |ratio, index|

            v = Geom::Vector3d.new(vmax)
            v.length = vmax.length * ratio
            t = Geom::Transformation.translation(v)

            polygon_3d = quad_ref.map { |point| point.transform(t) }
            polygon_2d = polygon_3d.map { |point| view.screen_coords(point) }
            if Geom.point_in_polygon_2D(p2d, polygon_2d, true)
              @picked_cutter_index = index
              return true
            end
            polygon_3d.each_cons(2) { |segment|
              if ph.pick_segment(segment, x, y, 20)
                @picked_cutter_index = index
                return true
              end
            }

          end

        end

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    # The locked interior handle keeps its axis and grip : only its grab point follows the mouse,
    # free to be taken anywhere and projected on the - unbounded - handle axis. The inference it is
    # taken from stays displayed.
    def _snap_stretch_start_locked_interior_handle(view, x, y)
      handle_def = @picked_interior_handle
      line = [ handle_def[:points].first, handle_def[:points].first.vector_to(handle_def[:points].last) ]
      return unless line[1].valid?

      @mouse_ip.pick(view, x, y)
      if _stretch_ip_stable_along?(line[1])
        handle_def[:target] = @mouse_ip.position
        handle_def[:point] = @mouse_ip.position.project_to_line(line)
        handle_def[:magnetized] = true
      else
        handle_def[:target] = nil
        handle_def[:point], _ = Geom.closest_points(line, view.pickray(x, y))
        handle_def[:magnetized] = false
        @mouse_ip.clear   # An unused inference isn't displayed
      end

      @mouse_snap_point = handle_def[:point]
    end

    def _snap_stretch_cutter_move(flags, x, y, view)

      drawing_def = _get_drawing_def
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)

      direction = @picked_axis.transform(et)
      ray = view.pickray(x, y)

      picked_point, _ = Geom::closest_points([ @picked_cutter_start_point, direction ], ray)
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

    def _snap_stretch_cutter_add(flags, x, y, view)

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

          ray = view.pickray(x, y)
          ray_origin, _ = ray

          hit = Geom.intersect_line_plane(ray, plane)
          if hit.nil?
            # Projection is certainly parallel to the direction
            @mouse_snap_point = ray_origin.project_to_line([ center, direction ])
          else
            @mouse_snap_point = hit.project_to_line([ center, direction ])
          end

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

    def _snap_stretch_cutter_remove(flags, x, y, view)

      @picked_cutter_index = nil

      unless @cutters.nil? || @picked_axis.nil?

        ph = view.pick_helper(x, y, 20)

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

          polygon_3d = quad_ref.map { |point| point.transform(t) }
          polygon_2d = polygon_3d.map { |point| view.screen_coords(point) }
          if Geom.point_in_polygon_2D(p2d, polygon_2d, true)
            @picked_cutter_index = index
            return true
          end
          polygon_3d.each_cons(2) { |segment|
            if ph.pick_segment(segment, x, y, 20)
              @picked_cutter_index = index
              return true
            end
          }

        end

      end

    end

    def _snap_stretch(flags, x, y, view)

      ph = view.pick_helper(x, y, 40)
      if ph.test_point(@picked_stretch_start_point)

        @mouse_snap_point = @picked_stretch_start_point
        @mouse_ip.clear

      else

        et = _get_edit_transformation
        direction = @picked_axis.transform(et)

        # The opposite point is a real bbox face for an end grip - snapping the end of the stretch
        # there would flatten the shape - but only a way marker for an interior handle
        if !_stretch_ip_stable_along?(direction) ||
           @picked_interior_handle.nil? && @mouse_ip.position.on_plane?([@picked_stretch_start_opposite_point, direction ])

          picked_point, _ = Geom::closest_points([@picked_stretch_start_point, direction ], view.pickray(x, y))
          @mouse_snap_point = picked_point
          @mouse_ip.clear

        else

          # Force picked point to be projected to shape the last picked point normal line
          @mouse_snap_point = @mouse_ip.position.project_to_line([@picked_stretch_start_point, direction ])

        end

      end

      # Lock on the last stretch measure. Only its magnitude is locked : the way stays driven by
      # the mouse, like the SmartDraw pull lock.
      if !@stretch_shift_ignored && @tool.is_key_shift_down? && (measure = _fetch_last_stretch_measure) != 0
        measure_def = _get_stretch_measure_def(measure.abs)
        unless measure_def.nil?
          @mouse_snap_point = measure_def[:end_point]
          @mouse_ip.clear
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
          is_add = @state == STATE_STRETCH_CUTTER_ADD && @snap_ratio && index == ratios.length - 1
          is_remove = ratio == 0 || ratio == 1 || @state == STATE_STRETCH_CUTTER_REMOVE && is_picked_section
          is_highligted = is_picked_section && !is_remove

          section_color = color
          section_color = Kuix::COLOR_DARK_GREY if is_remove

          k_rectangle = Kuix::RectangleMotif3d.new
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

          k_rectangle_fill = Kuix::RectangleFillMotif3d.new
          k_rectangle_fill.bounds.copy!(section)
          k_rectangle_fill.color = ColorUtils.color_translucent(section_color, is_highligted ? 0.6 : 0.3)
          k_rectangle_fill.transformation = et
          k_rectangle_fill.patterns_transformation = patterns_transformation
          @tool.append_3d(k_rectangle_fill, LAYER_3D_CUTTERS_PREVIEW)

          k_point = _create_floating_points(
            points: [ section.center.to_p ],
            style: Kuix::POINT_STYLE_CIRCLE,
            fill_color: section_color,
            stroke_color: nil,
            size: 1
          )
          k_point.transformation = et
          @tool.append_3d(k_point, LAYER_3D_CUTTERS_PREVIEW)

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

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(p1)
        k_edge.end.copy!(p2)
        k_edge.line_width = @picked_axis == @locked_axis ? 2 : 1.5
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_edge.color = color
        k_edge.on_top = true
        k_edge.transformation = et
        @tool.append_3d(k_edge, LAYER_3D_STRETCH_PREVIEW)

        k_points = _create_floating_points(
          points: [ p1, p2 ],
          style: Kuix::POINT_STYLE_CIRCLE,
          stroke_color: color,
          fill_color: Kuix::COLOR_WHITE,
          size: 2
        )
        k_points.transformation = et
        @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)

        # An interior handle is highlighted where its own family is drawn : the grip index is
        # synthesized for it and points at a bbox face that has nothing to do with it
        if @picked_interior_handle.nil? && !@picked_grip_index.nil?

          k_points = _create_floating_points(
            points: keb.face_center(@picked_grip_index).to_p,
            style: Kuix::POINT_STYLE_CIRCLE,
            stroke_color: nil,
            fill_color: color,
            size: 2
          )
          k_points.transformation = et
          @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)

        end

      end
    end

    def _preview_stretch_start(view)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      # Box

      k_box = Kuix::BoxMotif3d.new
      k_box.bounds.copy!(eb)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.transformation = et
      @tool.append_3d(k_box, LAYER_3D_PART_PREVIEW)

      # Grips + lines

      if @locked_axis.nil?

        axes = _get_stretchable_axes(keb, et).delete_if { |axis| axis == @picked_axis }

        axes.map { |axis| Kuix::Bounds3d.faces_by_axis(axis).map { |face| keb.face_center(face).to_p } }.each do |p0, p1|

          k_edge = Kuix::EdgeMotif3d.new
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
          fill_color: Kuix::COLOR_WHITE,
          size: 2.5
        )
        k_points.transformation = et
        @tool.append_3d(k_points, LAYER_3D_GRIPS_PREVIEW)

      end

      _preview_active_cutters(view)
      _preview_active_axis

      # The picked interior handle : its section slab is grabbable all along, so its segment is
      # drawn solid over the dashed axis

      unless @picked_interior_handle.nil?

        color = _get_vector_color(@picked_axis.transform(et))

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@picked_interior_handle[:points].first)   # Already expressed in the global space
        k_edge.end.copy!(@picked_interior_handle[:points].last)
        k_edge.line_width = 2.5
        k_edge.start_arrow = k_edge.end_arrow = true
        k_edge.arrow_size = 10
        k_edge.color = color
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_GRIPS_PREVIEW)

        # Show where the segment is grabbed, the diamond telling the grab point is magnetized to
        # the geometry and not just the closest point to the mouse ray
        if @picked_interior_handle[:magnetized]
          style = Kuix::POINT_STYLE_DIAMOND
          size = 3
        else
          style = Kuix::POINT_STYLE_CIRCLE
          size = 2
        end
        k_points = _create_floating_points(
          points: @picked_interior_handle[:point],
          style: style,
          stroke_color: Kuix::COLOR_WHITE,
          fill_color: color,
          size: size
        )
        @tool.append_3d(k_points, LAYER_3D_GRIPS_PREVIEW)

        # A grab point taken away from the handle axis : link it to its projection
        target = @picked_interior_handle[:target]
        if @interior_handle_locked && !target.nil? && target != @picked_interior_handle[:point]
          k_edge = Kuix::EdgeMotif3d.new
          k_edge.start.copy!(target)
          k_edge.end.copy!(@picked_interior_handle[:point])
          k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          k_edge.color = color
          k_edge.on_top = true
          @tool.append_3d(k_edge, LAYER_3D_GRIPS_PREVIEW)
        end
      end

    end

    def _preview_stretch_cutter_move(view)
      _preview_active_cutters(view)
    end

    def _preview_stretch_cutter_add(view)
      _preview_active_cutters(view)
    end

    def _preview_stretch_cutter_remove(view)
      _preview_active_cutters(view)
    end

    def _preview_stretch(view)
      return false if (stretch_def = _get_stretch_def(@picked_stretch_start_point, @mouse_snap_point)).nil?

      lps, lpe = stretch_def.lps, stretch_def.lpe
      et = stretch_def.split_def.et

      axis_color = _get_vector_color(lps.vector_to(lpe))
      no_scale_color = Kuix::COLOR_DARK_GREY

      fn_preview_container = lambda do |container_def, color|

        color = no_scale_color if LockUtils.locked?(container_def.container) ||
                                  container_def.container.respond_to?(:definition) && container_def.container.definition.behavior.no_scale_mask? == 0b1111111 # 0b1111111 = 127 (all disabld)

        # Render edges

        if container_def.edge_defs.any?
          k_segments = Kuix::Segments.new
          k_segments.add_segments(stretch_def.preview_edge_segments(container_def))
          k_segments.color = color
          k_segments.line_width = 1.5
          k_segments.transformation = et
          @tool.append_3d(k_segments, LAYER_3D_STRETCH_PREVIEW)
        end

        # Render clines

        if container_def.cline_defs.any?
          k_segments = Kuix::Segments.new
          k_segments.add_segments(stretch_def.preview_cline_segments(container_def))
          k_segments.color = color
          k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
          k_segments.transformation = et
          @tool.append_3d(k_segments, LAYER_3D_STRETCH_PREVIEW)
        end

        # Render snaps

        if container_def.snap_defs.any?
          k_points = _create_floating_points(
            points: stretch_def.preview_snap_points(container_def),
            style: Kuix::POINT_STYLE_CIRCLE,
            fill_color: Kuix::COLOR_SNAP_FILL,
            stroke_color: Kuix::COLOR_SNAP_STROKE,
            size: 2
          )
          k_points.transformation = et
          @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)
        end

        container_def.children.each { |container_def| fn_preview_container.call(container_def, color) }

      end
      fn_preview_container.call(stretch_def.split_def.root_container_def, axis_color)


      # _unhide_instances
      # rt = PathUtils.get_transformation(get_active_selection_path, IDENTITY)
      # get_active_selection_instances.each do |instance|
      #
      #   it = instance.transformation
      #   iti = it.inverse
      #
      #   p0 = ORIGIN
      #   p1 = ORIGIN + emv.transform(iti)
      #
      #   k_edge = Kuix::EdgeMotif3d.new
      #   k_edge.start.copy!(p0)
      #   k_edge.end.copy!(p1)
      #   k_edge.arrow_size = 2 * @tool.get_unit
      #   k_edge.end_arrow = true
      #   k_edge.color = Kuix::COLOR_CYAN
      #   k_edge.line_width = 2
      #   k_edge.on_top = true
      #   k_edge.transformation = rt * it
      #   @tool.append_3d(k_edge, LAYER_3D_STRETCH_PREVIEW)
      #
      # end
      # _hide_instances

      # eti = et.inverse
      # epmin, eps, evpspe, reversed, section_defs = split_def.values_at(:epmin, :eps, :evpspe, :reversed, :section_defs)
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
      #   @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)
      #   k_points = _create_floating_points(points: pl, stroke_color: Kuix::COLOR_YELLOW)
      #   k_points.transformation = et
      #   @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)
      # end
      # k_points = _create_floating_points(points: epo, fill_color: Kuix::COLOR_YELLOW)
      # k_points.transformation = et
      # @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)
      # k_points = _create_floating_points(points: epomax, fill_color: Kuix::COLOR_MAGENTA)
      # k_points.transformation = et
      # @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)
      # k_points = _create_floating_points(points: ORIGIN, style: Kuix::POINT_STYLE_DIAMOND, fill_color: Kuix::COLOR_CYAN, stroke_color: Kuix::COLOR_BLACK)
      # k_points.transformation = et
      # @tool.append_3d(k_points, LAYER_3D_STRETCH_PREVIEW)


      # colors = [ Kuix::COLOR_CYAN, Kuix::COLOR_MAGENTA, Kuix::COLOR_YELLOW ]
      #
      # section_defs, _ = split_def.values_at(:section_defs)
      # section_defs.each do |section_def|
      #
      #   dv = edvs[section_def]
      #
      #   # if section_def.bounds.valid?
      #   #   k_box = Kuix::BoxMotif3d.new
      #   #   k_box.bounds.copy!(section_def.bounds)
      #   #   k_box.bounds.translate!(*dv.to_a) if dv.valid?
      #   #   k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      #   #   k_box.line_width = 2
      #   #   k_box.color = colors[section_def.index % colors.length]
      #   #   k_box.transformation = et
      #   #   @tool.append_3d(k_box, LAYER_3D_STRETCH_PREVIEW)
      #   # end
      #
      #   if section_def.bounds.valid?
      #     k_box = Kuix::BoxMotif3d.new
      #     k_box.bounds.copy!(section_def.bounds)
      #     k_box.bounds.translate!(*dv.to_a)
      #     k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      #     k_box.line_width = 2
      #     k_box.color = colors[section_def.index % colors.length]
      #     k_box.transformation = et
      #     @tool.append_3d(k_box, LAYER_3D_STRETCH_PREVIEW)
      #   end
      #
      # end

      # Preview line

      color = _get_vector_color(@picked_axis.transform(et), Kuix::COLOR_DARK_GREY)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.color = color
      k_edge.show_hidden_lines = true
      k_edge.hidden_line_width = k_edge.line_width
      k_edge.hidden_line_color = ColorUtils.color_translucent(color, 60)
      @tool.append_3d(k_edge, LAYER_3D_STRETCH_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ lps, lpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_STRETCH_PREVIEW)
      @tool.append_3d(_create_floating_points(points: @picked_stretch_start_point, style: Kuix::POINT_STYLE_CIRCLE, stroke_color: nil, fill_color: color, size: 2), LAYER_3D_STRETCH_PREVIEW)

      # Preview distance

      distance = lps.distance(lpe)

      @tool.set_status_vcb_value(distance, true)

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

    def _read_stretch(tool, text, view)
      return false if (stretch_def = _get_stretch_def(@picked_stretch_start_point, @mouse_snap_point)).nil?

      lps, lpe = stretch_def.lps, stretch_def.lpe

      distance = _read_user_text_length(tool, text, lps.distance(lpe))
      return true if distance.nil?

      measure_type_outside = _stretch_measure_type_outside?

      # Error if distance < 0 and the measure type is outside
      if measure_type_outside && distance < 0
        tool.notify_errors([ [ "tool.default.error.invalid_length", { :value => distance.to_l } ] ])
        return false
      end

      return false if (measure_def = _get_stretch_measure_def(distance)).nil?
      end_point, pmin, pmax, compression_distance, max_compression_distance = measure_def.values_at(:end_point, :pmin, :pmax, :compression_distance, :max_compression_distance)

      return false if (stretch_def = _get_stretch_def(@picked_stretch_start_point, end_point)).nil?

      # Error if max distance exceeded
      compressed = stretch_def.compressed?
      compressed = true unless @picked_interior_handle.nil?  # An interior stretch compresses gaps both ways
      if compressed && compression_distance > max_compression_distance
        if measure_type_outside
          tool.notify_errors([ [ "tool.default.error.lt_min_distance", { :value1 => distance.abs.to_l, :value2 => (pmin.distance(pmax) - max_compression_distance).abs.to_l } ] ])
        else
          tool.notify_errors([ [ "tool.default.error.gt_max_distance", { :value1 => distance.abs.to_l, :value2 => max_compression_distance.abs.to_l } ] ])
        end
        return false
      end

      @picked_stretch_end_point = end_point

      _stretch_entity
      @tool.set_status_vcb_value('')

      true
    end

    # -----

    # Last measure is stored by measure type because its meaning differs :
    # overall dimension in "outside" mode - always positive, the compression is implied by the
    # comparison with the current dimension - and stretch delta in "offset" mode, where it is
    # signed : positive = expansion, negative = compression.

    def _fetch_last_stretch_measure
      @@last_stretch_measures[_stretch_measure_type_outside? ? :outside : :offset]
    end

    def _store_last_stretch_measure(measure, compressed = false)
      return if measure.nil? || measure == 0  # A null measure doesn't erase the stored one
      if _stretch_measure_type_outside?
        @@last_stretch_measures[:outside] = measure
      else
        @@last_stretch_measures[:offset] = compressed ? -measure : measure
      end
    end

    # -----

    def _fetch_option_stretch_measure_type
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE)
    end

    def _fetch_option_stretch_measure_type_outside?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE_OUTSIDE)
    end

    def _fetch_option_stretch_measure_type_offset?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE, SmartReshapeTool::ACTION_OPTION_STRETCH_MEASURE_TYPE_OFFSET)
    end

    # The "outside" measure means the overall dimension. An interior stretch preserves it, so its
    # measure is always the handle offset, whatever the option says.
    def _stretch_measure_type_outside?
      @picked_interior_handle.nil? && _fetch_option_stretch_measure_type_outside?
    end

    def _fetch_option_axes
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_AXES)
    end

    def _fetch_option_options_centered?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_CENTERED)
    end

    def _fetch_option_options_make_unique?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE)
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
        ignore_clines: false,
        container_validator: has_active_part? && !has_active_part_twins? ? CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART : CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL
      }
    end

    # -----

    # The grip outward direction : offsetting the grip along it expands the shape, offsetting it
    # backward compresses the shape.
    def _get_stretch_outward_direction
      return nil if @picked_stretch_start_opposite_point.nil? || @picked_stretch_start_point.nil?
      @picked_stretch_start_opposite_point.vector_to(@picked_stretch_start_point)
    end

    # Convert a "measure" - as displayed in the VCB : overall dimension if the measure type is
    # "outside", stretch delta if it is "offset" - to the matching stretch end point.
    # 'direction' defaults to the mouse driven one : pass an explicit one to let the sign of the
    # measure drive the way.
    def _get_stretch_measure_def(measure, reference_point = @mouse_snap_point, direction = nil)
      return nil unless (split_def = _get_split_def).is_a?(StretchSplitDef)
      split_def.measure_def(@picked_stretch_start_point, measure, reference_point,
                            direction: direction,
                            fallback_direction: _get_stretch_outward_direction,
                            centered: _fetch_option_options_centered?,
                            measure_outside: _stretch_measure_type_outside?,
                            interior_index: _get_picked_interior_index)
    end

    # -----

    def _stretch_entity
      return if (stretch_def = _get_stretch_def(@picked_stretch_start_point, @picked_stretch_end_point)).nil?

      # Keep the applied measure - and its way - to be able to reuse them on the next stretch
      _store_last_stretch_measure(stretch_def.measure, stretch_def.compressed?)

      _unhide_instances

      result_def = CommonStretchApplyWorker.new(
        stretch_def,
        selection_path: get_active_selection_path,
        selection_instances: get_active_selection_instances,
        make_unique: _fetch_option_options_make_unique?,
        extern_instances_ref_positions: @extern_instances_ref_positions,
        transparent: !active?
      ).run

      # The selection may have been remapped to made unique copies
      if result_def.selection_path != get_active_selection_path || result_def.selection_instances != get_active_selection_instances
        _set_active_selection(result_def.selection_path, result_def.selection_instances, true)
      end

      unless result_def.success?
        @tool.notify_errors(result_def.errors)
        return
      end

      # Adjust cutters
      @cutters[@picked_axis] = stretch_def.cutter_ratios
      _store_cutters
      _load_cutters

      # Fire event
      PLUGIN.app_observer.model_observer.onDrawingChange

    end

    # -----

    def _get_cutters_holder
      if (instances = get_active_selection_instances).is_a?(Array) && instances.one? &&
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
           (valid_cutters = cutters[xyz].map(&:to_f).select { |v| v > 0 && v < 1.0 }).any?
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

    def _assert_valid_cutters
      return false if !@cutters.is_a?(Hash) ||
                      @picked_axis.nil? ||
                      !(ratios = @cutters[@picked_axis]).is_a?(Array) || ratios.empty? ||
                      !(split_def = _get_split_def).is_a?(StretchSplitDef)

      # Check section pt_boxes oversize
      unless split_def.sections_valid?
        UI.beep
        @tool.notify_errors([ "tool.smart_reshape.error.curve_intersect" ])
        return false
      end

      true
    end

    # -----

    def _get_split_def
      return @split_def unless @split_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return nil if @picked_grip_index.nil?

      et = _get_edit_transformation

      @split_def = CommonStretchSplitWorker.new(
        _get_drawing_def_ipaths,
        et: et,
        axis: @picked_axis,
        grip_index: @picked_grip_index,
        ratios: @cutters[@picked_axis],
        eb: _get_drawing_def_edit_bounds(drawing_def, et),
        root_split: !get_active_selection_instances.one?
      ).run
    end

    # The edit axes that can be stretched : the bounds have a thickness along them, and no selected
    # instance's definition forbids to scale along them ('no_scale_mask' bits 0, 1 and 2 : red, green
    # and blue local axes). Stretching along an edit axis scales every local axis not perpendicular
    # to it, so an oblique edit axis is forbidden as soon as it leans on a forbidden local axis.
    def _get_stretchable_axes(keb, et)
      axes = [ X_AXIS, Y_AXIS, Z_AXIS ].select { |axis| keb.dim_by_axis(axis) > 0 }
      return axes if @active_selection_path.nil? || !(instances = get_active_selection_instances).is_a?(Array)

      forbidden_local_axes = instances.flat_map { |instance|
        next [] unless instance.respond_to?(:definition) && (mask = instance.definition.behavior.no_scale_mask?) & 0b111 != 0
        t = PathUtils.get_transformation(@active_selection_path + [ instance ], IDENTITY)
        [ t.xaxis, t.yaxis, t.zaxis ].select.with_index { |_, bit| mask & (1 << bit) != 0 }
      }
      return axes if forbidden_local_axes.empty?

      axes.select { |axis|
        direction = axis.transform(et)
        forbidden_local_axes.all? { |local_axis| !local_axis.valid? || direction.perpendicular?(local_axis) }
      }
    end

    # The interior handle candidates for the picked axis, expressed in the global space : a point on
    # each cutting plane, and the whole slab segment of each interior section - a section handle is
    # grabbable anywhere between its two planes, ':point' being only its default grab point. The
    # sections at both ends are anchors - they never move - so they get no handle.
    def _get_interior_handle_defs(keb, et)
      return [] if @cutters.nil? || @picked_axis.nil?
      return [] unless (ratios = @cutters[@picked_axis]).is_a?(Array)

      ratios = ratios.sort
      ratios.uniq!   # Same normalization as '_get_split_def'
      return [] if ratios.empty?

      grip_index_min, grip_index_max = Kuix::Bounds3d.faces_by_axis(@picked_axis)
      pmin = keb.face_center(grip_index_min).to_p
      v = pmin.vector_to(keb.face_center(grip_index_max).to_p)
      return [] unless v.valid?

      # One handle spanning each interior section's slab, from plane to plane. The grab point along
      # that segment is only known at pick time.
      ratios.each_cons(2).each_with_index.map { |min_max, index|
        {
          :index => index + 1,
          :points => min_max.map { |ratio| pmin.offset(v, v.length * ratio).transform(et) }
        }
      }
    end

    def _get_stretch_def(ps, pe)
      return nil unless (split_def = _get_split_def).is_a?(StretchSplitDef)
      split_def.stretch_def(ps, pe,
                            centered: _fetch_option_options_centered?,
                            measure_outside: _stretch_measure_type_outside?,
                            interior_index: _get_picked_interior_index)
    end

    def _get_picked_interior_index
      @picked_interior_handle.nil? ? nil : @picked_interior_handle[:index]
    end

  end

  class SmartReshapeSolidActionHandler < SmartActionHandler

    include SmartActionHandlerPartHelper
    include SmartActionHandlerSolidBooleanHelper

    STATE_SELECT_SRC = 0
    STATE_SELECT_CUT = 1

    LAYER_3D_SRC_PREVIEW = 10
    LAYER_3D_CUT_PREVIEW = 20

    def initialize(action, tool, previous_action_handler = nil)
      super

      @src_selection = Selection.new(LAYER_3D_SRC_PREVIEW)
      @cut_selection = Selection.new(LAYER_3D_CUT_PREVIEW)

    end

    # -----

    def close_doors_on_start?
      true
    end

    # -----

    def get_state_cursor(state)

      case state
      when STATE_SELECT_SRC
        return SmartCursorManager.cursor_select_a
      when STATE_SELECT_CUT
        return SmartCursorManager.cursor_select_b
      end

      super
    end

    def get_state_picker(state)

      case state
      when STATE_SELECT_SRC, STATE_SELECT_CUT
        return SmartPicker.new(tool: @tool, observer: self, pick_point: false, lockable: false)
      end

      super
    end

    def get_state_status(state)
      return super +
             (_allows_multiple_selections? ? ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string("tool.smart_select.state_0_to_7_status") + '.' : '')
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      if @tool.callback_action_handler.nil?

        case @state

        when STATE_SELECT_SRC
          if @src_selection.items.any?
            @src_selection.clear
            tool.hide_validation
            tool.clear_3d(LAYER_3D_SRC_PREVIEW)
          else
            _reset
          end

        when STATE_SELECT_CUT
          if @cut_selection.items.any?
            @cut_selection.clear
            tool.hide_validation
            tool.clear_3d(LAYER_3D_CUT_PREVIEW)
          else
            set_state(STATE_SELECT_SRC)
          end

        end
        _refresh

      else
        _reset
        stop
        Sketchup.active_model.tools.pop_tool
      end

    end


    def onToolValidate(tool, view)

      case @state

      when STATE_SELECT_SRC
        set_state(STATE_SELECT_CUT)

      when STATE_SELECT_CUT
        _operate

      end

    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_SRC
        unless _toggle_selection(tool, @src_selection) { set_state(STATE_SELECT_CUT) }
          UI.beep
        end
        return true

      when STATE_SELECT_CUT
        unless _toggle_selection(tool, @cut_selection) { _operate }
          UI.beep
        end
        return true

      end

    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_alt_or_command?(key)
        return true # Block default behavior for the ALT key on Windows
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key) && _allows_multiple_selections?
        if @state == STATE_SELECT_SRC && @src_selection.items.any?
          tool.notify(PLUGIN.get_i18n_string('tool.smart_reshape.notify.validate_a'))
          return true
        elsif @state == STATE_SELECT_CUT && @cut_selection.items.any?
          tool.notify(PLUGIN.get_i18n_string('tool.smart_reshape.notify.validate_b'))
          return true
        end
      end

      if tool.is_key_alt_or_command?(key) && is_quick
        @tool.store_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE, !_fetch_option_options_make_unique?, fire_event: true)
        _refresh
        return true
      end

      false
    end

    def onStateChanged(old_state, new_state)

      case new_state

      when STATE_SELECT_SRC
        @tool.hide_validation
        @src_selection.clear
        @tool.clear_3d([ LAYER_3D_SRC_PREVIEW, LAYER_3D_CUT_PREVIEW ])
        @tool.clear_notifications

      when STATE_SELECT_CUT
        @tool.hide_validation
        @cut_selection.clear
        @tool.clear_3d([ LAYER_3D_CUT_PREVIEW ])
        @tool.clear_notifications
        _refresh

      end

      super
    end

    def onPickerChanged(picker, view)
      _pick_part(picker, view)
      super
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)

      case @state

      when STATE_SELECT_SRC
        _preview_part(part_entity_path, part)

      when STATE_SELECT_CUT
        _preview_part(part_entity_path, part)

      end

    end

    # -----

    protected

    def _reset
      @src_selection.clear
      @cut_selection.clear
      super
      set_state(STATE_SELECT_SRC)
    end

    def _refresh
      _reset_active_part
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    def _get_solid_operation
      # Implemented in subclass
    end

    def _allows_multiple_selections?
      true
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      return false if @state == STATE_SELECT_CUT && @src_selection.items.find { |item| item.part_entity_path == part_entity_path }
      super
    end

    # -----

    def _get_active_part_preview_color(part, highlighted = false)
      case @state
      when STATE_SELECT_CUT
        ColorUtils.color_translucent(COLOR_PART, 0.3)
      else
        super
      end
    end

    def _get_instance_part_preview_color(part, highlighted = false)
      _get_active_part_preview_color(part, highlighted)
    end

    # -----

    # The operands are read the way every solid boolean in the tools reads
    # them - see SmartActionHandlerSolidBooleanHelper.
    def _get_drawing_def_parameters
      SOLID_BOOLEAN_DRAWING_DEF_PARAMETERS
    end

    # -----

    def _fetch_option_options_keep_a?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_KEEP_A)
    end

    def _fetch_option_options_keep_b?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_KEEP_B)
    end

    def _fetch_option_options_make_unique?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE)
    end

    def _fetch_option_options_remove_unused_definitions?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS)
    end

    # -----

    def _toggle_selection(tool, selection)
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)
        selection.toggle(get_active_part_entity_path, get_active_part, drawing_def)
        _preview_selection(selection)
        if _allows_multiple_selections? && (tool.is_key_shift_down? || selection.need_validation?)
          if selection.items.empty?
            tool.hide_validation
          else
            tool.show_validation
          end
          return true
        end
        yield
        return true
      end
      false
    end

    def _preview_selection(selection)
      @tool.clear_3d(selection.layer)
      selection.items.each { |item| _preview_part(item.part_entity_path, item.part, selection.layer, clear_before: false) }
    end

    # -----

    def _operate(operation = nil)

      errors = nil

      model = Sketchup.active_model
      model.start_operation('OCL Solid Operation', true)
      begin

        # Keep track of active definitions
        if _fetch_option_options_remove_unused_definitions? && Sketchup.version_number >= 1800000000
          selected_definitions = @src_selection.items.map { |item| item.part_entity_path.last.definition } + @cut_selection.items.map { |item| item.part_entity_path.last.definition }
          selected_definitions.uniq!
        end

        # Apply boolean operations, inside the operation opened above
        result_def = _apply_solid_boolean(
          @src_selection.items.map(&:drawing_def),
          @cut_selection.items.map(&:drawing_def),
          operation: operation,
          keep_srcs: _fetch_option_options_keep_a?,
          keep_cuts: _fetch_option_options_keep_b?,
          make_unique: _fetch_option_options_make_unique?
        )
        if result_def.success?

          # Clean up unused definitions if possible
          if defined?(selected_definitions) && selected_definitions.is_a?(Array)
            definitions = Sketchup.active_model.definitions
            selected_definitions.each do |definition|
              definitions.remove(definition) if definition.count_used_instances.zero?
            end
          end

          model.commit_operation

        else
          errors = result_def.errors
          model.abort_operation
        end

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

      if errors.is_a?(Array) && errors.any?
        _reset
        @tool.notify_errors(errors)
      else
        _restart
      end
    end

    # -----

    Selection = Struct.new(:layer) do

      def initialize(layer)
        super
        @items = []
        @need_validation = false
      end

      def toggle(part_entity_path, part, drawing_def)
        if (item = @items.find { |item| item.part_entity_path == part_entity_path })
          @items.delete(item)
        else
          @items.push(SelectionItem.new(part_entity_path, part, drawing_def))
          @need_validation = true if @items.size > 1
        end
      end

      def clear
        @items.clear
        @need_validation = false
      end

      def items
        @items
      end

      def need_validation?
        @need_validation
      end

    end
    SelectionItem = Struct.new(:part_entity_path, :part, :drawing_def)

  end

  class SmartReshapeSolidUniteActionHandler < SmartReshapeSolidActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_SOLID_UNITE, tool, previous_action_handler)
    end

    # -----

    def get_state_cursor(state)

      case state
      when STATE_SELECT_SRC
        return SmartCursorManager.cursor_select_unite_a
      when STATE_SELECT_CUT
        return SmartCursorManager.cursor_select_unite_b
      end

      super
    end

    protected

    # -----

    def _allows_multiple_selections?
      @state == STATE_SELECT_CUT
    end

    # -----

    def _operate(operation = nil)
      super(Fiddle::Meshy::OPERATION_UNION)
    end

  end

  class SmartReshapeSolidSubtractActionHandler < SmartReshapeSolidActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_SOLID_SUBTRACT, tool, previous_action_handler)
    end

    # -----

    def get_state_cursor(state)

      case state
      when STATE_SELECT_SRC
        return SmartCursorManager.cursor_select_subtract_a
      when STATE_SELECT_CUT
        return SmartCursorManager.cursor_select_subtract_b
      end

      super
    end

    protected

    # -----

    def _get_active_part_preview_color(part, highlighted = false)
      case @state
      when STATE_SELECT_CUT
        ColorUtils.color_translucent(Kuix::COLOR_RED, 0.3)
      else
        super
      end
    end

    def _get_active_part_preview_offset(part, highlighted = false)
      case @state
      when STATE_SELECT_CUT
        0.5
      else
        super
      end
    end

    # -----

    def _operate(operation = nil)
      super(Fiddle::Meshy::OPERATION_SUBTRACTION)
    end

  end

  class SmartReshapeSolidIntersectActionHandler < SmartReshapeSolidActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_SOLID_INTERSECT, tool, previous_action_handler)
    end

    # -----

    def get_state_cursor(state)

      case state
      when STATE_SELECT_SRC
        return SmartCursorManager.cursor_select_intersect_a
      when STATE_SELECT_CUT
        return SmartCursorManager.cursor_select_intersect_b
      end

      super
    end

    protected

    # -----

    def _allows_multiple_selections?
      @state == STATE_SELECT_CUT
    end

    # -----

    def _operate(operation = nil)
      super(Fiddle::Meshy::OPERATION_INTERSECTION)
    end

  end

  # Slices the selected parts by a plane : into two pieces each - every piece
  # its own definition, named after the part - or, in "cut" mode, keeping one
  # side only.
  #
  # The plane is parallel to a reference face, picked anywhere in the model,
  # at a distance from it ; or - an arrow key pressed (→ X, ← Y, ↑ Z, ↓ back
  # to the face) - perpendicular to that axis, at a distance from the end of
  # the selection closest to the mouse. Parts it does not cross are left
  # untouched, assemblies are traversed down to their parts.
  #
  # Each piece is the part INTERSECTED with a box on its side of the plane (see
  # SmartActionHandlerSolidBooleanHelper) : one boolean per side, the second
  # side working on clones laid before anything is cut. In make_unique: false
  # mode the definition is rebuilt in place, so every instance of a sliced
  # definition is sliced too : the clones are laid beside each of them -
  # except the selected parts the plane does not cross, which keep theirs.
  class SmartReshapeSliceActionHandler < SmartSelectActionHandler

    include UserTextHelper
    include SmartActionHandlerSolidBooleanHelper

    STATE_SLICE_REFERENCE = 1
    STATE_SLICE = 2
    STATE_SLICE_SIDE = 3
    STATE_SLICE_DISTRIBUTE = 4

    LAYER_3D_SLICE_PREVIEW = 10
    LAYER_3D_SLICE_SELECTION_PREVIEW = 11

    PX_INFLATE_VALUE = 50

    COLOR_FACE_REFERENCE = Kuix::COLOR_MAGENTA
    COLOR_REMOVED_PART = Sketchup::Color.new(120, 120, 120, 200).freeze
    COLOR_SLICED_EDGE = Kuix::COLOR_BLACK

    SlicePartDef = Struct.new(:path, :points, :triangles, :edges)  # WORLD coordinates, edges lazily read

    attr_reader :number, :spacings

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_SLICE, tool, previous_action_handler)

      @mouse_ip = SmartInputPoint.new(tool)

      @reference_axis = nil   # The edit axis the plane is perpendicular to, nil when it is parallel to a face

      @reference_plane = nil  # [ point, normal ] WORLD : the reference face, or the selection end the distance is measured from
      @slice_plane = nil      # [ point, normal ] WORLD : the reference normal, so the distance reads along it
      @slice_side = nil       # 1 keeps the slice plane normal side, -1 the other one (cut mode)
      @reference_face_manipulator = nil
      @reference_points = []  # WORLD : the 3 points reference, the plane they define
      @reference_ip = SmartInputPoint.new(tool)  # The last reference point, the inferences start from it
      @locked_axis = nil      # The axis the next reference point is locked on
      @reference_snap_point = nil  # WORLD : the next reference point, the mouse projected on the locked axis
      @picked_reference = nil # [ plane, face_manipulator ] : the last plane picked at step 1, ↓ goes back to it from an axis

      @slice_part_defs = nil
      @sliced_previews = nil                    # side => [ edge segments, section segments ] WORLD

      # xn / /n : the planes shared over the selection, pinned by @spacings - kept from the previous slice
      @number = previous_action_handler.is_a?(self.class) ? previous_action_handler.number : 0
      @spacings = previous_action_handler.is_a?(self.class) ? previous_action_handler.spacings : []
      @unhide_slice_instances_transformations = nil

      # Create 3D layers
      tool.create_3d(LAYER_3D_SLICE_PREVIEW)
      tool.create_3d(LAYER_3D_SLICE_SELECTION_PREVIEW)
      tool.create_3d(LAYER_3D_PART_TWINS_PREVIEW)
      tool.create_3d(LAYER_3D_PART_PREVIEW)

    end

    # -----

    def close_doors_on_start?
      true
    end

    # -----

    def stop
      _unhide_slice_instances
      super
    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SLICE_REFERENCE
        return SmartCursorManager.cursor_pin_2 if _fetch_option_slice_reference_points? && @reference_points.any?
        return SmartCursorManager.cursor_pin_1
      when STATE_SLICE, STATE_SLICE_SIDE, STATE_SLICE_DISTRIBUTE
        return SmartCursorManager.cursor_select_scissors
      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_option_options_make_unique_status") + '.'

      when STATE_SLICE_REFERENCE
        if _fetch_option_slice_reference_points?
          return PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_1c_status") + '.' if @reference_points.length >= 3
          status = PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_1b_status", { :index => @reference_points.length + 1 }) + '.'
          status += ' | ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_1b_arrows_status") + '.' if @reference_points.any?
          return status
        end
        return super +
               ' | ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_1_arrows_status") + '.'

      when STATE_SLICE
        if _fetch_option_slice_mode_cut?
          status = PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_2a_status") + '.'
        else
          status = PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_2_status") + '.'
        end
        return status +
               ' | ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_2_arrows_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_option_options_make_unique_status") + '.'

      when STATE_SLICE_DISTRIBUTE
        return PLUGIN.get_i18n_string("tool.smart_reshape.action_5_state_4_status", { :number => @number + 1 }) + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_SLICE
        return PLUGIN.get_i18n_string("tool.default.vcb_distance")

      when STATE_SLICE_DISTRIBUTE
        return PLUGIN.get_i18n_string("tool.default.vcb_spacings")

      end

      super
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      if @tool.callback_action_handler.nil?

        case @state

        when STATE_SLICE_SIDE
          set_state(STATE_SLICE)
          _refresh
          return true

        when STATE_SLICE_DISTRIBUTE
          if @spacings.any?
            _set_distribution(@number, [])
          else
            _set_distribution(0, [])
          end
          return true

        when STATE_SLICE
          # The remembered plane is forgotten : back to step 1 from scratch
          @reference_axis = nil
          @picked_reference = nil
          @reference_face_manipulator = nil
          @reference_points = []
          @reference_ip.clear
          set_state(STATE_SLICE_REFERENCE)
          _refresh
          return true

        when STATE_SLICE_REFERENCE
          if @reference_points.any?
            _remove_last_reference_point
            _refresh
            return true
          end

        end

        _reset
        _refresh

      else
        Sketchup.active_model.tools.pop_tool
      end

      true
    end

    def onToolSuspend(tool, view)
      super
      _unhide_slice_instances if @state == STATE_SLICE_SIDE
    end

    def onToolResume(tool, view)
      super
      _hide_slice_instances if @state == STATE_SLICE_SIDE
    end

    def onToolMouseMove(tool, flags, x, y, view)
      super

      return true if x < 0 || y < 0

      case @state

      when STATE_SLICE_REFERENCE, STATE_SLICE, STATE_SLICE_SIDE, STATE_SLICE_DISTRIBUTE

        if @state == STATE_SLICE_REFERENCE && @reference_points.any?
          @mouse_ip.pick(view, x, y, @reference_ip)  # Inferences from the last point
        else
          @mouse_ip.pick(view, x, y)
        end

        @tool.clear_all_2d
        @tool.clear_3d(LAYER_3D_SLICE_PREVIEW)

        case @state
        when STATE_SLICE_REFERENCE
          _snap_slice_reference(flags, x, y, view)
          _preview_slice_reference(view)
        when STATE_SLICE
          _snap_slice(flags, x, y, view)
          _preview_slice(view)
        when STATE_SLICE_SIDE
          _snap_slice_side(flags, x, y, view)
          _preview_slice_side(view)
        when STATE_SLICE_DISTRIBUTE
          _preview_slice_distribute(view)
        end

        view.invalidate

      end

      false
    end

    def onToolMouseLeave(tool, view)
      return true if super
      @tool.clear_all_2d
      @tool.clear_3d(LAYER_3D_SLICE_PREVIEW)
      @mouse_ip.clear
      view.tooltip = ''
    end

    def onToolLButtonDown(tool, flags, x, y, view)

      case @state

      when STATE_SLICE_REFERENCE, STATE_SLICE, STATE_SLICE_SIDE, STATE_SLICE_DISTRIBUTE
        return true  # The part picked by the selection must not be highlighted anymore

      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SLICE_REFERENCE
        if _fetch_option_slice_reference_points?
          if @reference_points.length < 3
            _snap_reference_point(x, y, view)
            _add_reference_point(view)
          end
          return true if @reference_points.length < 3
          _snap_slice_reference(flags, x, y, view)  # The plane of the 3 points, the mouse not involved
        end
        if @reference_plane.nil?
          UI.beep
        else
          @picked_reference = [ @reference_plane, @reference_face_manipulator ]
          _set_distribution(@number, @spacings)
        end
        return true

      when STATE_SLICE
        _validate_slice_plane
        return true

      when STATE_SLICE_SIDE
        if @slice_side.nil?
          UI.beep
        else
          _slice_entities([ @slice_plane ], @slice_side)
        end
        return true

      when STATE_SLICE_DISTRIBUTE
        _validate_slice_distribution  # The planes do not follow the mouse : the click applies them
        return true

      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super

      if tool.is_key_alt_or_command?(key) && (@state == STATE_SELECT || @state == STATE_SLICE)
        return true # Block default behavior for the ALT key on Windows
      end

      # SHIFT + / - : one plane more or less
      if (@state == STATE_SLICE || @state == STATE_SLICE_DISTRIBUTE) && !_fetch_option_slice_mode_cut? &&
         tool.is_key_shift_down? && !tool.is_vcb_typing? && (key == Kuix::VK_ADD || key == Kuix::VK_SUBTRACT)
        _set_distribution(@number + (key == Kuix::VK_ADD ? 1 : -1), @spacings)
        return true
      end

      # 3 points reference : → X, ← Y, ↑ Z lock the next point on that axis, ↓ unlocks
      if @state == STATE_SLICE_REFERENCE && _fetch_option_slice_reference_points?
        axis = { VK_RIGHT => X_AXIS, VK_LEFT => Y_AXIS, VK_UP => Z_AXIS }[key]
        if axis
          if @reference_points.empty? || @reference_points.length >= 3
            UI.beep
          else
            _lock_reference_axis(axis.transform(_get_edit_transformation))
            _refresh
          end
          return true
        end
        if key == VK_DOWN
          _lock_reference_axis(nil)
          _refresh
          return true
        end
        return false
      end

      # → X, ← Y, ↑ Z : the plane perpendicular to that axis ; ↓ : back to the picked plane, then to its step
      if @state == STATE_SLICE_REFERENCE || @state == STATE_SLICE || @state == STATE_SLICE_DISTRIBUTE
        axis = { VK_RIGHT => X_AXIS, VK_LEFT => Y_AXIS, VK_UP => Z_AXIS }[key]
        if axis
          @reference_axis = axis
          _snap_slice_axis_reference(flags, tool.last_mouse_x, tool.last_mouse_y, view)  # Read now : the distributed planes do not follow the mouse
          if @state == STATE_SLICE
            @tool.set_status_prompt(get_state_status(@state))
            _refresh
          else
            _set_distribution(@number, @spacings)
          end
          return true
        end
        if key == VK_DOWN
          if !@reference_axis.nil? && !@picked_reference.nil? && @state != STATE_SLICE_REFERENCE
            # From an axis : back to the last picked plane
            @reference_axis = nil
            @reference_plane, @reference_face_manipulator = @picked_reference
            if @state == STATE_SLICE
              @tool.set_status_prompt(get_state_status(@state))
              _refresh
            else
              _set_distribution(@number, @spacings)
            end
          else
            # From the plane : back to its step, the 3 points kept
            @reference_axis = nil
            set_state(STATE_SLICE_REFERENCE) unless @state == STATE_SLICE_REFERENCE
            _refresh
          end
          return true
        end
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      if tool.is_key_alt_or_command?(key) && is_quick && (@state == STATE_SELECT || @state == STATE_SLICE)
        @tool.store_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE, !_fetch_option_options_make_unique?, fire_event: true)
        _refresh
        return true
      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      case @state

      when STATE_SLICE
        return true if _read_slice_number(tool, text, view)
        return true if _read_slice_spacings(tool, text, view)
        return true if _read_slice(tool, text, view)

      when STATE_SLICE_DISTRIBUTE
        return true if _read_slice_number(tool, text, view)
        return true if _read_slice_spacings(tool, text, view)

      end

      false
    end

    def onToolValidate(tool, view)

      case @state

      when STATE_SLICE_DISTRIBUTE
        _validate_slice_distribution

      end

      false
    end

    def onToolReturn(tool, view)
      onToolValidate(tool, view)
    end

    def onToolActionOptionStored(tool, action, option_group, option)

      if option_group == SmartReshapeTool::ACTION_OPTION_SLICE_MODE
        # The distribution kept from the previous slice is not the other mode's
        @number = 0
        @spacings = []
      end

      if option_group == SmartReshapeTool::ACTION_OPTION_SLICE_REFERENCE
        # The other kind of reference : drawn again
        _lock_reference_axis(nil)
        @reference_points = []
        @reference_ip.clear
        @picked_reference = nil
        @reference_face_manipulator = nil
      end

      return unless @state > STATE_SELECT && @state <= STATE_SLICE_DISTRIBUTE

      case option_group

      when SmartReshapeTool::ACTION_OPTION_SLICE_REFERENCE
        @reference_axis = nil
        if @state == STATE_SLICE_REFERENCE
          @reference_plane = nil
          @tool.set_root_cursor(get_state_cursor(@state))
        else
          set_state(STATE_SLICE_REFERENCE)
        end

      when SmartReshapeTool::ACTION_OPTION_SLICE_MODE
        # The reference is kept : only the steps the other mode does not have are left
        set_state(STATE_SLICE) if @state == STATE_SLICE_SIDE || @state == STATE_SLICE_DISTRIBUTE

      when SmartReshapeTool::ACTION_OPTION_AXES
        # An axis reference follows the new axes - read again on mouse move, but not by the fixed distributed planes
        _snap_slice_axis_reference(0, tool.last_mouse_x, tool.last_mouse_y, Sketchup.active_model.active_view) if @state == STATE_SLICE_DISTRIBUTE && !@reference_axis.nil?

      else
        return

      end

      @tool.set_status_prompt(get_state_status(@state))
      _refresh
    end

    def onStateChanged(old_state, new_state)
      super

      case new_state

      when STATE_SLICE_REFERENCE
        @reference_plane = nil
        @slice_plane = nil
        @slice_side = nil

      when STATE_SLICE
        @reference_plane = nil unless @reference_axis.nil?
        @slice_plane = nil
        @slice_side = nil

      when STATE_SLICE_DISTRIBUTE
        @slice_plane = nil

      when STATE_SLICE_SIDE
        @slice_side = nil
        @sliced_previews = nil

      end

      case old_state

      when STATE_SLICE_REFERENCE, STATE_SLICE, STATE_SLICE_SIDE, STATE_SLICE_DISTRIBUTE
        @tool.clear_3d(LAYER_3D_SLICE_SELECTION_PREVIEW)
        _unhide_slice_instances if old_state == STATE_SLICE_SIDE
        _lock_reference_axis(nil) if old_state == STATE_SLICE_REFERENCE

      end

      case new_state

      when STATE_SLICE_REFERENCE, STATE_SLICE, STATE_SLICE_SIDE, STATE_SLICE_DISTRIBUTE
        Sketchup.active_model.selection.clear
        @tool.clear_all_2d
        @tool.clear_3d([ LAYER_3D_PART_PREVIEW, LAYER_3D_PART_TWINS_PREVIEW ])  # Remove part preview
        _preview_slice_selection  # Before hiding : the instances are framed where they stand
        _hide_slice_instances if new_state == STATE_SLICE_SIDE

      end

    end

    def onSelected
      return true if super

      _reset_drawing_def
      @slice_part_defs = nil

      if _get_slice_part_defs.empty?
        UI.beep
        _reset
        return
      end

      set_state(STATE_SLICE_REFERENCE)

      _refresh

    end

    # -----

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid? && (@locked_axis.nil? || @state != STATE_SLICE_REFERENCE)  # Locked : the projected point is the one shown
    end

    def enableVCB?
      true
    end

    # -----

    protected

    def _reset
      @mouse_ip.clear
      @reference_axis = nil
      @reference_plane = nil
      @reference_face_manipulator = nil
      @reference_points = []
      @reference_ip.clear
      @locked_axis = nil
      @reference_snap_point = nil
      @picked_reference = nil
      @slice_plane = nil
      @slice_side = nil
      @slice_part_defs = nil
      @sliced_previews = nil
      @number = 0
      @spacings = []
      super
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

    # The pieces are not the selection anymore : a restart starts from scratch
    def _start_with_previous_selection?
      false
    end

    def _allows_multiple_selections?
      true
    end

    def _allows_tree_selection?
      true
    end

    def _clear_selection_on_start?
      true
    end

    # -----

    def _can_activate_locked?
      false
    end

    # -----

    def _preview_part_box?
      true
    end

    def _preview_part(part_entity_path, part, layer = 0, highlighted: false, clear_before: true)
      super
      if part && fetch_state == STATE_SELECT

        # Show part infos
        @tool.set_root_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

      else

        @tool.remove_root_tooltip

      end
    end

    # -----

    def _fetch_option_slice_mode_cut?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_SLICE_MODE, SmartReshapeTool::ACTION_OPTION_SLICE_MODE_CUT)
    end

    def _fetch_option_slice_reference_points?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_SLICE_REFERENCE, SmartReshapeTool::ACTION_OPTION_SLICE_REFERENCE_POINTS)
    end

    def _fetch_option_axes
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_AXES)
    end

    def _fetch_option_options_make_unique?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE)
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

    # -----

    # The parts of the selection, the selected instances being parts or
    # assemblies : the cut list ones, hardware excluded. A part nested in
    # another one follows it.
    def _get_slice_part_defs
      return @slice_part_defs unless @slice_part_defs.nil?
      @slice_part_defs = []
      return @slice_part_defs unless has_active_selection?

      selection_path = get_active_selection_path
      paths = get_active_selection_instances.map { |instance|
        worker = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_options')).merge({ active_entity: instance, active_path: selection_path, part_folding: false }))
        cutlist = worker.run
        cutlist.groups
               .reject { |group| group.material_type == MaterialAttributes::TYPE_HARDWARE }
               .map { |group| group.parts.map { |part| part.def.instance_infos.values.map(&:path) } }
      }.flatten(3).uniq
      paths = paths.select { |path| path.last.is_a?(Sketchup::ComponentInstance) }
      paths = paths.reject { |path| paths.any? { |other| other.length < path.length && path[0, other.length] == other } }

      paths.each do |path|
        drawing_def = _decompose_for_solid_boolean([ Sketchup::InstancePath.new(path) ]).first
        next unless drawing_def.is_a?(DrawingDef)
        mesh_def = SolidMeshDef.from_drawing_def(drawing_def)
        next if mesh_def.nil? || mesh_def.empty?
        points = mesh_def.vertices.each_slice(3).map { |x, y, z| Geom::Point3d.new(x, y, z) }
        triangles = mesh_def.face_indices.map { |index| points[index] }
        @slice_part_defs << SlicePartDef.new(path, points, triangles)
      end

      @slice_part_defs
    end

    # The parts the given plane really crosses : some of their geometry on
    # either side of it.
    def _get_crossed_part_defs(plane)
      point, normal = plane
      _get_slice_part_defs.select do |part_def|
        below = false
        above = false
        part_def.points.each do |p|
          d = point.vector_to(p).dot(normal)
          below = true if d < -SolidMeshDef::TOLERANCE
          above = true if d > SolidMeshDef::TOLERANCE
          break if below && above
        end
        below && above
      end
    end

    # The parts lying wholly on the side of the given plane opposite to +side+
    # (1 = the plane normal side) - touching the plane at most : what a cut
    # keeping +side+ erases.
    def _get_removed_part_defs(plane, side)
      point, normal = plane
      _get_slice_part_defs.select do |part_def|
        part_def.points.all? { |p| point.vector_to(p).dot(normal) * side < SolidMeshDef::TOLERANCE } &&
          part_def.points.any? { |p| point.vector_to(p).dot(normal) * side < -SolidMeshDef::TOLERANCE }
      end
    end

    # A frame on the given plane : its origin and normal (z), the x axis laid
    # on the edit axis the most perpendicular to the normal, so a plane
    # perpendicular to an axis displays square.
    def _get_plane_frame(plane)
      point, normal = plane
      et = _get_edit_transformation
      axis = [ X_AXIS, Y_AXIS, Z_AXIS ].map { |a| a.transform(et).normalize }.min_by { |a| a.dot(normal).abs }
      u = normal.cross(axis).cross(normal).normalize
      v = normal.cross(u).normalize
      Geom::Transformation.axes(point, u, v, normal)
    end

    # The bounds of the given part defs, in the given frame.
    def _get_part_defs_extents(part_defs, frame)
      fti = frame.inverse
      extents = Geom::BoundingBox.new
      part_defs.each { |part_def| extents.add(part_def.points.map { |p| p.transform(fti) }) }
      extents
    end

    # The part edges, read on demand, as segments.
    def _get_slice_part_def_edges(part_def)
      part_def.edges ||= begin
        drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(part_def.path) ],
          ignore_faces: true,
          ignore_edges: false,
          ignore_soft_edges: true,
          container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS
        ).run
        if drawing_def.is_a?(DrawingDef)
          t = drawing_def.transformation
          segments = drawing_def.edge_manipulators.flat_map(&:segment)
          segments += drawing_def.curve_manipulators.flat_map(&:segments)
          segments.map { |p| p.transform(t) }
        else
          []
        end
      end
    end

    # -- Reference points --

    # True when the reference plane is the 3 points one.
    def _reference_points_plane?
      @reference_axis.nil? && @reference_face_manipulator.nil? && @reference_points.length == 3
    end

    # The plane through the 3 reference points, nil until they are placed.
    def _get_reference_points_plane
      return nil unless @reference_points.length == 3
      p0, p1, p2 = @reference_points
      normal = p0.vector_to(p1).cross(p0.vector_to(p2))
      return nil unless normal.valid?
      [ p0, normal.normalize ]
    end

    # The mouse position, projected on the locked axis line from the last
    # point - by hand : view.lock_inference ignores a direction that is not a
    # model axis (~/DevProjects/sketchup-api-quirks/quirks/lock-inference-model-axes-only.md).
    def _snap_reference_point(x, y, view)
      @reference_snap_point = nil
      return if @reference_points.length >= 3
      if @locked_axis.nil? || @reference_points.empty?
        @reference_snap_point = @mouse_ip.position if @mouse_ip.valid?
      else
        line = [ @reference_points.last, @locked_axis ]
        if _mouse_ip_on_geometry?
          @reference_snap_point = @mouse_ip.position.project_to_line(line)
        else
          @reference_snap_point, _ = Geom.closest_points(line, view.pickray(x, y))
        end
      end
    end

    def _add_reference_point(view)
      return UI.beep if (point = @reference_snap_point).nil?
      return UI.beep if @reference_points.any? { |p| p == point }
      return UI.beep if @reference_points.length == 2 && @reference_points[0].vector_to(@reference_points[1]).parallel?(@reference_points[0].vector_to(point))  # Collinear
      @reference_points << point
      if @locked_axis.nil?
        @reference_ip.copy!(@mouse_ip)
      else
        @reference_ip.copy!(point)  # Off the picked geometry
      end
      _lock_reference_axis(nil)
      @tool.set_root_cursor(get_state_cursor(@state))
      @tool.set_status_prompt(get_state_status(@state))
      _refresh
    end

    def _remove_last_reference_point
      @reference_points.pop
      @reference_plane = nil
      if @reference_points.empty?
        @reference_ip.clear
      else
        @reference_ip.copy!(@reference_points.last)
      end
      _lock_reference_axis(nil)
      @tool.set_root_cursor(get_state_cursor(@state))
      @tool.set_status_prompt(get_state_status(@state))
    end

    # Locks the next reference point on +axis+ from the last one, or unlocks
    # when +axis+ is nil or the locked one.
    def _lock_reference_axis(axis)
      @locked_axis = axis.nil? || @locked_axis == axis ? nil : axis
    end

    # -- Distribution --

    # The /n planes : @number of them shared over the selection, from its end
    # the closest to the reference to the other one, @spacings pinning the
    # pieces from both ends. nil when they do not fit.
    def _get_distributed_planes
      return nil if @reference_plane.nil? || @number < 1
      point, normal = @reference_plane
      frame = _get_plane_frame(@reference_plane)
      extents = _get_part_defs_extents(_get_slice_part_defs, frame)
      return nil if extents.empty?
      if extents.min.z.abs <= extents.max.z.abs
        z0, direction = extents.min.z, 1
      else
        z0, direction = extents.max.z, -1
      end
      return nil if (offsets = _get_distribution_offsets(extents.depth, @number, @spacings)).nil?
      offsets.map { |offset| [ Geom::Point3d.new(0, 0, z0 + direction * offset).transform(frame), normal ] }
    end

    # The +number+ plane offsets along a +length+, read as the Smart Build
    # Divider reads its spacings - with no thickness : the leading run of
    # valid +spacings+ pins the first pieces, the run after an invalid or
    # empty entry the last ones, the planes left in the middle share what
    # remains. nil when they do not fit.
    def _get_distribution_offsets(length, number, spacings)
      return nil unless number > 0

      fn_valid_spacing = lambda { |spacing| spacing.is_a?(Length) && spacing >= 0 }
      start_spacings = spacings.take_while(&fn_valid_spacing)
      end_spacings = start_spacings.size == spacings.size ? [] : spacings.reverse.take_while(&fn_valid_spacing)

      if start_spacings.size > number
        start_spacings = start_spacings.take(number)
        end_spacings = []
      elsif start_spacings.size + end_spacings.size > number
        end_spacings = end_spacings.take(number - start_spacings.size)
      end

      start_d = 0.0
      start_offsets = start_spacings.map { |spacing| start_d += spacing }

      end_d = length.to_f
      end_offsets = end_spacings.map { |spacing| end_d -= spacing }.reverse

      middle_size = number - start_offsets.size - end_offsets.size
      if middle_size > 0
        segment = (end_d - start_d) / (middle_size + 1.0)
        return nil if segment <= SolidMeshDef::TOLERANCE
        middle_offsets = (1..middle_size).map { |index| start_d + index * segment }
      else
        middle_offsets = []
      end

      offsets = start_offsets + middle_offsets + end_offsets
      bounds = [ 0.0 ] + offsets + [ length.to_f ]
      return nil if bounds.each_cons(2).any? { |a, b| b - a <= SolidMeshDef::TOLERANCE }

      offsets
    end

    def _set_distribution(number, spacings)
      @number = [ number, 0 ].max
      @spacings = spacings

      if @number > 0 && _get_distributed_planes.nil?
        UI.beep
        @tool.notify_errors([ [ 'tool.smart_reshape.error.slice_number_overflow', { :number => @number + 1 } ] ])
      end

      if @number > 0
        if @state == STATE_SLICE_DISTRIBUTE
          @tool.set_status_prompt(get_state_status(@state))
        else
          set_state(STATE_SLICE_DISTRIBUTE)
        end
      else
        set_state(STATE_SLICE) unless @state == STATE_SLICE
      end
      _refresh
    end

    # -- Hide --

    # The parts are hidden as the stretch hides its instances : scaled to
    # nothing by move!, out of the undo stack. An instance is hidden only when
    # all its occurrences are parts of the selection, the preview standing for
    # them all.
    def _hide_slice_instances
      return if @unhide_slice_instances_transformations.is_a?(Hash)
      occurrences = Hash.new(0)
      _get_slice_part_defs.each do |part_def|
        _get_slice_part_def_edges(part_def)  # Read while the instance still stands
        occurrences[part_def.path.last] += 1
      end
      @unhide_slice_instances_transformations = {}
      occurrences.each do |instance, count|
        next if instance.deleted?
        parent = instance.parent
        next if parent.is_a?(Sketchup::ComponentDefinition) && parent.count_used_instances > count
        @unhide_slice_instances_transformations[instance] = Geom::Transformation.new(instance.transformation)
      end
      @unhide_slice_instances_transformations.each_key { |instance| instance.move!(Geom::Transformation.scaling(0)) }
    end

    def _unhide_slice_instances
      return unless @unhide_slice_instances_transformations.is_a?(Hash)
      @unhide_slice_instances_transformations.each { |instance, transformation| instance.move!(transformation) unless instance.deleted? }
      @unhide_slice_instances_transformations = nil
    end

    def _slice_instance_hidden?(part_def)
      @unhide_slice_instances_transformations.is_a?(Hash) && @unhide_slice_instances_transformations.key?(part_def.path.last)
    end

    # -- Snap --

    def _mouse_ip_on_geometry?
      return false unless @mouse_ip.valid?  # Not picked yet : an axis key pressed before any mouse move
      !(@mouse_ip.degrees_of_freedom > 2 || @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1)
    end

    def _snap_slice_reference(flags, x, y, view)
      @reference_plane = nil
      @reference_face_manipulator = nil
      if _fetch_option_slice_reference_points?
        _snap_reference_point(x, y, view)
        return @reference_plane = _get_reference_points_plane
      end
      return if (face = @mouse_ip.face).nil?

      face_manipulator = FaceManipulator.new(face, @mouse_ip.face_transformation)
      normal = face_manipulator.normal.normalize
      @reference_plane = [ @mouse_ip.position.project_to_plane(face_manipulator.plane), normal ]
      @reference_face_manipulator = face_manipulator
    end

    def _snap_slice(flags, x, y, view)
      _snap_slice_axis_reference(flags, x, y, view) unless @reference_axis.nil?
      return @slice_plane = nil if @reference_plane.nil?

      point, normal = @reference_plane
      line = [ point, normal ]
      if _mouse_ip_on_geometry?
        p = @mouse_ip.position.project_to_line(line)
      else
        p, _ = Geom.closest_points(line, view.pickray(x, y))
      end
      if _reference_points_plane? && point.vector_to(p).dot(normal) < -SolidMeshDef::TOLERANCE
        # A 3 points plane has no side of its own : its normal follows the mouse
        normal = normal.reverse
        @reference_plane = [ point, normal ]
      end
      @slice_plane = [ p, normal ]
    end

    # The axis reference, read on the bounds of the selected parts : the
    # selection end the mouse is closest to, along the reference axis.
    def _snap_slice_axis_reference(flags, x, y, view)
      @reference_plane = nil

      et = _get_edit_transformation
      eti = et.inverse
      eb = Geom::BoundingBox.new
      _get_slice_part_defs.each { |part_def| eb.add(part_def.points.map { |p| p.transform(eti) }) }
      return if eb.empty?
      ecenter = eb.center
      center = ecenter.transform(et)
      half_dims = { X_AXIS => eb.width / 2, Y_AXIS => eb.height / 2, Z_AXIS => eb.depth / 2 }

      axis = @reference_axis
      direction = axis.transform(et).normalize
      line = [ center, direction ]
      if _mouse_ip_on_geometry?
        p = @mouse_ip.position.project_to_line(line)
      else
        p, _ = Geom.closest_points(line, view.pickray(x, y))
      end

      sign = center.vector_to(p).dot(direction) >= 0 ? 1 : -1
      reference_point = ecenter.offset(axis, sign * half_dims[axis]).transform(et)
      @reference_plane = [ reference_point, sign > 0 ? direction.reverse : direction ]
    end

    def _snap_slice_side(flags, x, y, view)
      @slice_side = nil
      return if @slice_plane.nil?

      point, normal = @slice_plane
      if _mouse_ip_on_geometry?
        p = @mouse_ip.position
      else
        p, _ = Geom.closest_points([ point, normal ], view.pickray(x, y))
      end
      d = point.vector_to(p).dot(normal)
      @slice_side = d >= 0 ? 1 : -1 if d.abs > SolidMeshDef::TOLERANCE
    end

    # -- Preview --

    # The selected instances framed as SmartBuild frames its picked instance,
    # instead of the native selection.
    def _preview_slice_selection
      @tool.clear_3d(LAYER_3D_SLICE_SELECTION_PREVIEW)
      return unless has_active_selection?

      selection_path = get_active_selection_path
      get_active_selection_instances.each do |instance|
        next if instance.deleted?

        kb = Kuix::Bounds3d.new.copy!(instance.definition.bounds).inflate_all!(1)
        t = PathUtils.get_transformation(selection_path + [ instance ], IDENTITY)

        k_box = Kuix::BoxCornersMotif3d.new
        k_box.bounds.copy!(kb)
        k_box.corner_size = 20
        k_box.color = Kuix::COLOR_BLUE
        k_box.line_width = 2.0
        k_box.line_stipple = Kuix::LINE_STIPPLE_SOLID
        k_box.transformation = t
        @tool.append_3d(k_box, LAYER_3D_SLICE_SELECTION_PREVIEW)

        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(kb)
        k_box.color = Kuix::COLOR_BLUE
        k_box.line_width = 1.5
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.transformation = t
        @tool.append_3d(k_box, LAYER_3D_SLICE_SELECTION_PREVIEW)

      end
    end

    def _preview_slice_reference(view)
      return _preview_reference_points(view) if _fetch_option_slice_reference_points?
      return if @reference_plane.nil?
      _preview_reference_face(3)
    end

    # The points placed, the segment to the mouse, and the triangle once the
    # 3 are known.
    def _preview_reference_points(view)
      points = @reference_points.dup
      mouse_point = @reference_snap_point if @reference_points.length < 3
      points << mouse_point unless mouse_point.nil?
      return if points.empty?

      # The sides but the one being drawn, left to the edge below : drawn twice, they flicker
      if mouse_point.nil?
        outline_points = points
      else
        outline_points = @reference_points.length == 2 ? [ mouse_point ] + @reference_points : []
      end
      if outline_points.length > 1
        k_polyline = Kuix::Polyline.new
        k_polyline.add_points(outline_points)
        k_polyline.closed = mouse_point.nil? && outline_points.length == 3
        k_polyline.line_width = 2
        k_polyline.show_hidden_lines = true
        k_polyline.depth_offset = 2  # Over the edges the points snap to
        k_polyline.color = COLOR_FACE_REFERENCE
        @tool.append_3d(k_polyline, LAYER_3D_SLICE_PREVIEW)
      end

      unless mouse_point.nil? || @reference_points.empty?
        # The segment being drawn, in the color of the axis it follows
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@reference_points.last)
        k_edge.end.copy!(mouse_point)
        k_edge.line_width = @locked_axis.nil? ? 2 : 3
        k_edge.show_hidden_lines = true
        k_edge.color = _get_vector_color(@reference_points.last.vector_to(mouse_point), COLOR_FACE_REFERENCE)
        k_edge.on_top = false
        @tool.append_3d(k_edge, LAYER_3D_SLICE_PREVIEW)

        # Locked : the mouse linked to its projection on the axis
        if !@locked_axis.nil? && @mouse_ip.valid? && @mouse_ip.position != mouse_point
          k_edge = Kuix::EdgeMotif3d.new
          k_edge.start.copy!(@mouse_ip.position)
          k_edge.end.copy!(mouse_point)
          k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_edge.color = _get_vector_color(@locked_axis, COLOR_FACE_REFERENCE)
          k_edge.on_top = true
          @tool.append_3d(k_edge, LAYER_3D_SLICE_PREVIEW)
        end
      end

      if points.length == 3
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(points)
        k_mesh.background_color = ColorUtils.color_translucent(COLOR_FACE_REFERENCE, 0.1)
        @tool.append_3d(k_mesh, LAYER_3D_SLICE_PREVIEW)
      end

      @tool.append_3d(_create_floating_points(points: @reference_points, style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: COLOR_FACE_REFERENCE, size: 2), LAYER_3D_SLICE_PREVIEW) if @reference_points.any?

    end

    def _preview_slice(view)
      return if @slice_plane.nil?

      color = _get_slice_plane_color
      crossed_part_defs = _get_crossed_part_defs(@slice_plane)

      _preview_crossed_parts(crossed_part_defs)
      _preview_slice_plane(view, @slice_plane, color, crossed_part_defs.any?)

      # The distance to the reference

      point, normal = @reference_plane
      distance = point.vector_to(@slice_plane[0]).dot(normal)

      if @reference_axis.nil?
        _preview_reference_face
      else
        _preview_slice_plane(view, @reference_plane, color, false, true)
      end

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(point)
      k_edge.end.copy!(@slice_plane[0])
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.color = color
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_SLICE_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ point, @slice_plane[0] ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_SLICE_PREVIEW)

      @tool.set_status_vcb_value(distance.abs.to_l, true)

      unless distance.abs < SolidMeshDef::TOLERANCE

        k_label = _create_floating_label(
          snap_point: Geom.linear_combination(0.5, point, 0.5, @slice_plane[0]),
          text: distance.abs.to_l,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _preview_slice_distribute(view)
      return if @reference_plane.nil?

      color = _get_slice_plane_color

      if @reference_axis.nil?
        _preview_reference_face
      else
        _preview_slice_plane(view, @reference_plane, color, false, true)
      end

      return if (planes = _get_distributed_planes).nil?

      _preview_crossed_parts(planes.flat_map { |plane| _get_crossed_part_defs(plane) }.uniq)
      planes.each { |plane| _preview_slice_plane(view, plane, color, _get_crossed_part_defs(plane).any?) }

      # The piece lengths, along the selection center

      frame = _get_plane_frame(@reference_plane)
      extents = _get_part_defs_extents(_get_slice_part_defs, frame)
      fti = frame.inverse
      zs = [ extents.min.z, extents.max.z ] + planes.map { |plane| plane[0].transform(fti).z }
      zs.sort.each_cons(2) do |z0, z1|

        k_label = _create_floating_label(
          snap_point: Geom::Point3d.new(extents.center.x, extents.center.y, (z0 + z1) / 2.0).transform(frame),
          text: (z1 - z0).to_l,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _preview_slice_side(view)
      return if @slice_plane.nil?

      color = _get_slice_plane_color
      crossed_part_defs = _get_crossed_part_defs(@slice_plane)

      _preview_sliced_parts(@slice_plane, @slice_side, color)
      _preview_slice_plane(view, @slice_plane, color, true)

      return if @slice_side.nil? || crossed_part_defs.empty?

      removed_part_defs = _get_removed_part_defs(@slice_plane, @slice_side)
      _preview_removed_parts(removed_part_defs.reject { |part_def| _slice_instance_hidden?(part_def) })

      frame = _get_plane_frame(@slice_plane)
      extents = _get_part_defs_extents(crossed_part_defs + removed_part_defs, frame)

      # The kept side

      center = Geom::Point3d.new(extents.center.x, extents.center.y, 0).transform(frame)
      normal = @slice_plane[1]

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(center)
      k_edge.end.copy!(center.offset(@slice_side > 0 ? normal : normal.reverse, view.pixels_to_model(PX_INFLATE_VALUE * 1.5, center)))
      k_edge.end_arrow = true
      k_edge.arrow_size = @tool.get_unit * 2.0
      k_edge.line_width = 2
      k_edge.color = color
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_SLICE_PREVIEW)

    end

    def _preview_crossed_parts(part_defs)
      part_defs.each do |part_def|

        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(part_def.triangles)
        k_mesh.background_color = COLOR_PART
        @tool.append_3d(k_mesh, LAYER_3D_SLICE_PREVIEW)

      end
    end

    # The parts as the cut leaves them, in wireframe : their edges clipped to
    # the kept +side+ (all of them while it is unknown) and the section contour.
    # Computed once per side, the plane being fixed.
    def _preview_sliced_parts(plane, side, color)
      @sliced_previews ||= {}
      edge_segments, section_segments = (@sliced_previews[side] ||= _compute_sliced_preview(plane, side))

      unless edge_segments.empty?
        k_segments = Kuix::Segments.new
        k_segments.add_segments(edge_segments)
        k_segments.line_width = 1.5
        k_segments.color = COLOR_SLICED_EDGE
        @tool.append_3d(k_segments, LAYER_3D_SLICE_PREVIEW)
      end

      unless section_segments.empty?
        k_segments = Kuix::Segments.new
        k_segments.add_segments(section_segments)
        k_segments.line_width = 2
        k_segments.color = color
        @tool.append_3d(k_segments, LAYER_3D_SLICE_PREVIEW)
      end

    end

    def _compute_sliced_preview(plane, side)
      point, normal = plane
      fn_distance = lambda { |p| point.vector_to(p).dot(normal) }

      crossed_part_defs = _get_crossed_part_defs(plane)
      removed_part_defs = side.nil? ? [] : _get_removed_part_defs(plane, side)

      edge_segments = []
      (_get_slice_part_defs - removed_part_defs).each do |part_def|
        _get_slice_part_def_edges(part_def).each_slice(2) do |p0, p1|
          unless side.nil?
            d0 = fn_distance.call(p0) * side
            d1 = fn_distance.call(p1) * side
            next if d0 < SolidMeshDef::TOLERANCE && d1 < SolidMeshDef::TOLERANCE && (d0 < -SolidMeshDef::TOLERANCE || d1 < -SolidMeshDef::TOLERANCE)
            if d0 < -SolidMeshDef::TOLERANCE
              p0 = Geom.linear_combination(d1 / (d1 - d0), p0, -d0 / (d1 - d0), p1)
            elsif d1 < -SolidMeshDef::TOLERANCE
              p1 = Geom.linear_combination(d1 / (d1 - d0), p0, -d0 / (d1 - d0), p1)
            end
          end
          edge_segments << p0 << p1
        end
      end

      # Each triangle crossing the plane gives a segment of the contour
      section_segments = []
      crossed_part_defs.each do |part_def|
        part_def.triangles.each_slice(3) do |triangle|
          ds = triangle.map { |p| fn_distance.call(p) }
          ss = ds.map { |d| d > SolidMeshDef::TOLERANCE ? 1 : (d < -SolidMeshDef::TOLERANCE ? -1 : 0) }
          next if ss.all?(&:zero?)
          ps = []
          3.times do |i|
            j = (i + 1) % 3
            ps << triangle[i] if ss[i] == 0
            ps << Geom.linear_combination(ds[j] / (ds[j] - ds[i]), triangle[i], -ds[i] / (ds[j] - ds[i]), triangle[j]) if ss[i] * ss[j] < 0
          end
          section_segments << ps[0] << ps[1] if ps.length == 2 && ps[0] != ps[1]
        end
      end

      [ edge_segments, section_segments ]
    end

    def _preview_removed_parts(part_defs)
      part_defs.each do |part_def|

        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(part_def.triangles)
        k_mesh.background_color = COLOR_REMOVED_PART
        @tool.append_3d(k_mesh, LAYER_3D_SLICE_PREVIEW)

      end
    end

    def _preview_reference_face(line_width = 2)
      if @reference_face_manipulator.nil?
        return unless _reference_points_plane?
        points = @reference_points  # The 3 points triangle
      else
        points = @reference_face_manipulator.outer_loop_manipulator.points
      end

      k_polyline = Kuix::Polyline.new
      k_polyline.add_points(points)
      k_polyline.closed = true
      k_polyline.line_width = line_width
      k_polyline.color = COLOR_FACE_REFERENCE
      k_polyline.show_hidden_lines = true
      k_polyline.depth_offset = 2  # Over the face edges it lies on
      @tool.append_3d(k_polyline, LAYER_3D_SLICE_PREVIEW)

    end

    # The plane displayed over the whole selection, inflated by a few pixels.
    def _preview_slice_plane(view, plane, color, highlighted, reference = false)

      frame = _get_plane_frame(plane)
      extents = _get_part_defs_extents(_get_slice_part_defs, frame)
      return if extents.empty?

      inflate = view.pixels_to_model(PX_INFLATE_VALUE, plane[0])

      k_rectangle = Kuix::RectangleMotif3d.new
      k_rectangle.bounds.set!(extents.min.x - inflate, extents.min.y - inflate, 0, extents.width + inflate * 2, extents.height + inflate * 2, 0)
      k_rectangle.line_width = highlighted ? 2 : 1
      k_rectangle.line_stipple = reference || !highlighted ? Kuix::LINE_STIPPLE_SHORT_DASHES : Kuix::LINE_STIPPLE_SOLID
      k_rectangle.color = color
      k_rectangle.transformation = frame
      @tool.append_3d(k_rectangle, LAYER_3D_SLICE_PREVIEW)

      return if reference

      k_rectangle_fill = Kuix::RectangleFillMotif3d.new
      k_rectangle_fill.bounds.copy!(k_rectangle.bounds)
      k_rectangle_fill.color = ColorUtils.color_translucent(color, highlighted ? 0.3 : 0.1)
      k_rectangle_fill.transformation = frame
      @tool.append_3d(k_rectangle_fill, LAYER_3D_SLICE_PREVIEW)

    end

    def _get_slice_plane_color
      return COLOR_FACE_REFERENCE if @reference_plane.nil? || @reference_axis.nil?
      _get_vector_color(@reference_plane[1], COLOR_FACE_REFERENCE)
    end

    # -- Read --

    def _read_slice(tool, text, view)
      return false if @reference_plane.nil?

      point, normal = @reference_plane
      distance = @slice_plane.nil? ? 0 : point.vector_to(@slice_plane[0]).dot(normal)

      distance = _read_user_text_length(tool, text, distance)
      return true if distance.nil?

      @slice_plane = [ point.offset(distance < 0 ? normal.reverse : normal, distance.abs), normal ]
      @tool.set_status_vcb_value('')
      _validate_slice_plane

      true
    end

    # xn : n planes, /n : n pieces (n - 1 planes), shared over the selection
    # as the Smart Build Divider reads them. Slice mode only.
    def _read_slice_number(tool, text, view)
      return false if _fetch_option_slice_mode_cut?
      return false unless text.is_a?(String) && (match = text.match(/^([x*\/])(\d+)$/))

      operator, value = match[1, 2]
      number = value.to_i

      if operator == '/' && number < 2
        UI.beep
        tool.notify_errors([ [ 'tool.default.error.invalid_divider', { :value => value } ] ])
        return true
      end

      _set_distribution(operator == '/' ? number - 1 : number, @spacings)
      @tool.set_status_vcb_value('')

      true
    end

    # A list of lengths - "600;300", "600;" pins the first piece, ";300" the
    # last one - read as the Smart Build Divider spacings. Slice mode only.
    def _read_slice_spacings(tool, text, view)
      return false if _fetch_option_slice_mode_cut?

      list = _split_user_text(text)
      return false unless list.is_a?(Array) && list.size > 1

      # An entry that is not a length at all marks the free middle
      spacings = list.map { |spacing|
        length = _read_user_text_length(tool, spacing, -1)
        length.nil? || length == -1 ? -1 : length.abs.to_l
      }

      _set_distribution([ @number, spacings.select { |spacing| spacing > 0 }.size ].max, spacings)
      @tool.set_status_vcb_value('')

      true
    end

    # -----

    def _validate_slice_plane
      return UI.beep if @slice_plane.nil?
      if _fetch_option_slice_mode_cut?
        return UI.beep if _get_crossed_part_defs(@slice_plane).empty?
        set_state(STATE_SLICE_SIDE)
        _refresh
      else
        return UI.beep if _get_crossed_part_defs(@slice_plane).empty?
        _slice_entities([ @slice_plane ])
      end
    end

    def _validate_slice_distribution
      return UI.beep if (planes = _get_distributed_planes).nil?
      _slice_entities(planes)
    end

    # -- Apply --

    # Slices the crossed parts by the given parallel planes : keeps all the
    # pieces, or, with a single plane, only the +side+ one (1 = the plane
    # normal side) when given.
    def _slice_entities(planes, side = nil)
      _unhide_slice_instances
      planes = planes.select { |plane| _get_crossed_part_defs(plane).any? }
      part_defs = planes.flat_map { |plane| _get_crossed_part_defs(plane) }.uniq
      if part_defs.empty?
        UI.beep
        return
      end
      plane = planes.first

      frame = _get_plane_frame(plane)
      fti = frame.inverse
      extents = _get_part_defs_extents(part_defs, frame)
      margin = [ 1.0, extents.diagonal * 0.1 ].max
      zmin = extents.min.z - margin
      zmax = extents.max.z + margin
      slabs = if side.nil?
                zs = planes.map { |p| p[0].transform(fti).z.to_f }.sort
                zs = zs.each_with_object([]) { |z, uniq_zs| uniq_zs << z if uniq_zs.empty? || z - uniq_zs.last > SolidMeshDef::TOLERANCE }
                ([ zmin ] + zs + [ zmax ]).each_cons(2).to_a
              else
                [ side > 0 ? [ 0, zmax ] : [ zmin, 0 ] ]
              end
      removed_paths = side.nil? ? [] : _get_removed_part_defs(plane, side).map(&:path)
      kept_paths = (_get_slice_part_defs - part_defs).map(&:path) - removed_paths

      # The slabs each part really has material in
      path_slabs = part_defs.map { |part_def|
        zmin_part, zmax_part = part_def.points.map { |p| p.transform(fti).z.to_f }.minmax
        (0...slabs.length).select { |index| [ zmax_part, slabs[index][1] ].min - [ zmin_part, slabs[index][0] ].max > SolidMeshDef::TOLERANCE }
      }

      errors = []

      model = Sketchup.active_model
      model.start_operation('OCL Slice Parts', true)
      begin

        errors = _slice_parts(part_defs.map(&:path), plane, frame, extents, margin, slabs, path_slabs, _fetch_option_options_make_unique?, removed_paths, kept_paths)
        if errors.empty?
          model.commit_operation
        else
          model.abort_operation
        end

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
        errors = [ [ 'core.error.exception', { :error => e.message } ] ]
      end

      Sketchup.active_model.selection.clear
      if errors.any?
        _reset
        @tool.notify_errors(errors)
      else
        _restart
      end
    end

    # Runs inside the caller's operation, answers the errors - nothing to undo
    # by the caller but its own operation. Each of the +slabs+ ([ zmin, zmax ]
    # in +frame+) a part has material in - its +path_slabs+ indices - yields
    # one piece of it.
    #
    # The parts sharing a definition and sliced at the same place in it form a
    # twin group : their pieces share a definition too. In make_unique: false
    # mode, the definition being rebuilt in place, a definition can't be
    # sliced at two different places.
    #
    # The +removed_paths+ parts, wholly beyond the plane, are erased - their
    # instance only : in make_unique: false mode, every occurrence of the
    # assembly holding them.
    #
    # The +kept_paths+ parts, selected but not crossed, keep their shape : in
    # make_unique: false mode, a twin group whose definition one of them uses
    # moves - with the unselected instances - to a definition of its own.
    def _slice_parts(paths, plane, frame, extents, margin, slabs, path_slabs, make_unique, removed_paths = [], kept_paths = [])
      model = Sketchup.active_model

      # Separate the assemblies holding the parts, so the pieces are laid in
      # (and the removed parts erased from) this occurrence only
      if make_unique
        all_paths = _make_unique_ancestors(paths + removed_paths)
        paths = all_paths[0...paths.length]
        removed_paths = all_paths[paths.length..-1]
      end

      twin_groups = []
      group_slabs = []
      paths.each_with_index do |path, path_index|
        definition = path.last.definition
        if (twin_group = twin_groups.find { |group| group.first.last.definition == definition && _same_local_plane?(group.first, path, plane) })
          twin_group << path
        elsif !make_unique && twin_groups.any? { |group| group.first.last.definition == definition }
          return [ [ 'tool.smart_reshape.error.slice_shared_definition', { :name => definition.name } ] ]
        else
          twin_groups << [ path ]
          group_slabs << path_slabs[path_index]
        end
      end

      base_names = twin_groups.map { |twin_paths| twin_paths.map { |path| path.last.definition.name } }.flatten

      # Keep the shape of the selected parts the plane does not cross
      unless make_unique
        kept_instances = kept_paths.map(&:last)
        twin_groups.each do |twin_paths|
          instances = twin_paths.map(&:last)
          definition = instances.first.definition
          next unless kept_instances.any? { |instance| instance.definition == definition }
          followers = definition.instances - instances - kept_instances
          instances.first.make_unique
          (instances[1..-1] + followers).each { |instance| instance.definition = instances.first.definition }
        end
      end

      # The pieces beyond the first one are cut from clones laid BEFORE any
      # boolean : a boolean rebuilds the definition it cuts
      piece_paths = twin_groups.map { |twin_paths| twin_paths.map { |path| [ path ] } }
      twin_groups.each_with_index do |twin_paths, group_index|
        (1...group_slabs[group_index].length).each do
          _clone_twin_parts(twin_paths, make_unique).each_with_index { |clone_path, index| piece_paths[group_index][index] << clone_path }
        end
      end
      piece_slabs = twin_groups.each_with_index.map { |twin_paths, group_index| twin_paths.map { group_slabs[group_index] } }.flatten(1)
      piece_paths = piece_paths.flatten(1)

      slabs.each_with_index do |(zmin, zmax), slab_index|

        # The piece each part has in this slab
        slab_piece_paths = piece_paths.each_with_index.map { |pieces, index| (piece_index = piece_slabs[index].index(slab_index)).nil? ? nil : pieces[piece_index] }.compact
        next if slab_piece_paths.empty?

        box = _add_slab_box(frame, extents, margin, zmin, zmax)

        src_drawing_defs = _decompose_for_solid_boolean(slab_piece_paths.map { |piece_path| Sketchup::InstancePath.new(piece_path) })
        cut_drawing_defs = _decompose_for_solid_boolean([ Sketchup::InstancePath.new([ box ]) ])
        return [ [ 'default.error' ] ] unless (src_drawing_defs + cut_drawing_defs).all? { |drawing_def| drawing_def.is_a?(DrawingDef) }

        result_def = _apply_solid_boolean(
          src_drawing_defs,
          cut_drawing_defs,
          operation: CommonSolidBooleanWorker::OPERATION_INTERSECTION,
          make_unique: make_unique
        )
        return result_def.errors unless result_def.success?

        slab_piece_paths.each { |piece_path| _erase_out_of_slab_machinings(piece_path, frame, zmin, zmax) }

      end

      removed_paths.map(&:last).select(&:valid?).group_by(&:parent).each { |parent, instances| parent.entities.erase_entities(instances) }

      # Each piece named after its part
      if slabs.length > 1
        renamed = {}
        piece_paths.each_with_index do |pieces, index|
          next if pieces.length < 2
          definitions = pieces.map { |piece_path| piece_path.last.valid? ? piece_path.last.definition : nil }.compact.uniq
          next if definitions.empty? || definitions.any? { |definition| renamed[definition] }
          definitions.each { |definition| renamed[definition] = true }
          _name_pieces(base_names[index], definitions)
        end
      end

      []
    end

    # Names the given piece definitions "Name #1", "Name #2"... numbered from
    # the first number free for all of them - a part sliced again continues
    # its numbering instead of piling suffixes up.
    #
    # SketchUp re-uniquifies any name it holds taken - the definition's own
    # current one included, and ones only undone definitions bore - into one
    # of its own making ("Name ", "Name #k", possibly a duplicate). So the
    # pieces first get temporary names, out of each other's way, then each
    # final name is read back, the numbering moving on until all hold.
    def _name_pieces(base_name, definitions)
      base_name = base_name.sub(/ #\d+\z/, '')
      model_definitions = Sketchup.active_model.definitions
      fn_free = lambda { |name| (definition = model_definitions[name]).nil? || definitions.include?(definition) }
      start = 1
      100.times do
        names = (0...definitions.length).map { |offset| "#{base_name} ##{start + offset}" }
        if names.all? { |name| fn_free.call(name) }
          return if definitions.zip(names).all? { |definition, name| definition.name == name }
          definitions.each { |definition| definition.name = "ocl-slice-#{definition.entityID}" }
          definitions.zip(names).each { |definition, name| definition.name = name }
          return if definitions.zip(names).all? { |definition, name| definition.name == name }
        end
        start += 1
      end
    end

    # Makes unique every assembly holding the given parts that is displayed
    # elsewhere - the active context excepted : editing it is editing all its
    # occurrences. The parts are found again by POSITION, which is what
    # survives a make_unique.
    def _make_unique_ancestors(paths)
      active_path = Sketchup.active_model.active_path.to_a
      paths.map { |path| _get_index_path(path) }.map do |index_path|
        path = _resolve_index_path(index_path)
        (0...path.length - 1).each do |depth|
          entity = path[depth]
          next if active_path.include?(entity)
          next if entity.definition.instances.length < 2
          entity.make_unique
          path = _resolve_index_path(index_path)
        end
        path
      end
    end

    def _get_index_path(path)
      entities = Sketchup.active_model.entities
      path.map do |entity|
        index = entities.to_a.index(entity)
        entities = entity.definition.entities
        index
      end
    end

    def _resolve_index_path(index_path)
      entities = Sketchup.active_model.entities
      index_path.map do |index|
        entity = entities.to_a[index]
        entities = entity.definition.entities
        entity
      end
    end

    # Is the plane at the same place in both parts' definition ?
    def _same_local_plane?(path_a, path_b, plane)
      point_a, normal_a = _get_local_plane(path_a, plane)
      point_b, normal_b = _get_local_plane(path_b, plane)
      normal_a.samedirection?(normal_b) && point_b.on_plane?([ point_a, normal_a ])
    end

    def _get_local_plane(path, plane)
      ti = PathUtils.get_transformation(path, IDENTITY).inverse
      point, normal = plane
      [ point.transform(ti), normal.transform(ti).normalize ]
    end

    # A clone of each of the given twin parts, all sharing one new definition
    # - the piece to come. When the part definition is rebuilt in place, the
    # clone definition is laid beside every other instance of it too.
    def _clone_twin_parts(twin_paths, make_unique)
      instances = twin_paths.map(&:last)
      definition = instances.first.definition

      clone = _add_instance_beside(instances.first, definition)
      clone.make_unique
      clone_definition = clone.definition

      clones = [ clone ] + instances[1..-1].map { |instance| _add_instance_beside(instance, clone_definition) }
      unless make_unique
        (definition.instances - instances).each { |other_instance| _add_instance_beside(other_instance, clone_definition) }
      end

      twin_paths.zip(clones).map { |path, clone_instance| path[0...-1] + [ clone_instance ] }
    end

    def _add_instance_beside(src_instance, definition)
      dst_instance = src_instance.parent.entities.add_instance(definition, src_instance.transformation)
      dst_instance.material = src_instance.material
      dst_instance.name = src_instance.name
      dst_instance.layer = src_instance.layer
      dst_instance.casts_shadows = src_instance.casts_shadows?
      dst_instance.receives_shadows = src_instance.receives_shadows?
      ComponentUtils.copy_attributes(src_instance, dst_instance)
      dst_instance
    end

    # A closed box at the model root : the selection extents (+margin) in the
    # frame plane, from +zmin+ to +zmax+ along its normal.
    def _add_slab_box(frame, extents, margin, zmin, zmax)
      xmin = extents.min.x - margin
      xmax = extents.max.x + margin
      ymin = extents.min.y - margin
      ymax = extents.max.y + margin
      corners = [
        [ xmin, ymin, zmin ], [ xmax, ymin, zmin ], [ xmax, ymax, zmin ], [ xmin, ymax, zmin ],
        [ xmin, ymin, zmax ], [ xmax, ymin, zmax ], [ xmax, ymax, zmax ], [ xmin, ymax, zmax ]
      ].map { |coordinates| Geom::Point3d.new(coordinates).transform(frame) }

      group = Sketchup.active_model.entities.add_group
      [ [ 0, 3, 2, 1 ], [ 4, 5, 6, 7 ], [ 0, 1, 5, 4 ], [ 1, 2, 6, 5 ], [ 2, 3, 7, 6 ], [ 3, 0, 4, 7 ] ].each do |indices|
        group.entities.add_face(indices.map { |index| corners[index] })
      end
      group
    end

    # The machinings and hardware a boolean leaves out of its operands stay
    # in every piece : erase those lying beyond the piece slab. One the plane
    # crosses stays in both pieces.
    def _erase_out_of_slab_machinings(piece_path, frame, zmin, zmax)
      instance = piece_path.last
      return unless instance.valid?

      _erase_out_of_slab_machinings_in(instance.definition.entities, frame.inverse * PathUtils.get_transformation(piece_path, IDENTITY), zmin, zmax)
    end

    # Searches the untyped groups too - the part's own sub groups, the group
    # SmartJoin lays hardware articles in - and erases those it empties.
    # Answers whether +entities+ was emptied.
    #
    # A group shared with another piece is made unique BEFORE being searched :
    # an edit through the entities of a shared group lands on its sibling.
    def _erase_out_of_slab_machinings_in(entities, t, zmin, zmax)
      erasables = entities.select { |entity|
        next false unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        type = _get_material_attributes(entity.material).type
        if entity.definition.behavior.cuts_opening? || type == MaterialAttributes::TYPE_MACHINING || type == MaterialAttributes::TYPE_HARDWARE
          z = entity.bounds.center.transform(t).z
          z < zmin || z > zmax
        elsif entity.is_a?(Sketchup::Group) && type == MaterialAttributes::TYPE_UNKNOWN
          entity.make_unique if entity.definition.instances.length > 1
          _erase_out_of_slab_machinings_in(entity.entities, t * entity.transformation, zmin, zmax)
        else
          false
        end
      }
      return false if erasables.empty?
      entities.erase_entities(erasables)
      entities.length == 0
    end

  end

  class SmartReshapePanelingActionHandler < SmartActionHandler

    include UserTextHelper
    include FaceMatcherHelper

    STATE_SELECT = 0
    STATE_PANELING = 1

    LAYER_3D_PANELING_PREVIEW = 10

    # Any fixed reflection does. #_find_reusable_panel_def composes it with the
    # proper alignments FaceMatcherHelper answers to reach the mirrored
    # placements ; which plane it reflects about is irrelevant, the alignment
    # that follows puts the panel back where it belongs.
    PANEL_REFLECTION = Geom::Transformation.scaling(-1, 1, 1)

    def initialize(tool, previous_action_handler = nil)
      super(SmartReshapeTool::ACTION_PANELING, tool, previous_action_handler)

      @drawing_def = nil

      # The shell the pick landed on when it is NOT a closed manifold solid,
      # and the i18n tuple saying why : kept only to SHOW the user what was
      # refused and what is wrong with it — see #_snap_select. Never becomes
      # @drawing_def, nothing is ever panelled from it.
      @refused_drawing_def = nil
      @refused_error = nil

      # A CONSTRUCTION drawing waiting to become one : the container of the
      # CLines (InstancePath) and the manipulators the STATE_SELECT preview
      # draws it with. The solid itself is only rebuilt when STATE_PANELING
      # opens its operation — see #_rebuild_drawing_def_from_clines.
      @cline_source_ipath = nil
      @cline_source_manipulators = []

      @hover_face_manipulators = Set.new
      @hover_edge_manipulators = Set.new

      @selected_face_manipulators = Set.new

      @edge_joint_types = {}

    end

    # -----

    def start
      super

      return if (model = Sketchup.active_model).nil?
      selection = model.selection

      container_path = nil
      container = nil

      if @tool.startup_selection.is_a?(SmartSelection)

        container_path = @tool.startup_selection.path
        container = @tool.startup_selection.instances.first

      elsif selection.any?

        if (container = selection.first).is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
          container_path = model.active_path.to_a
        end

        selection.clear

      end

      unless container_path.nil? || container.nil?

        ipath = Sketchup::InstancePath.new(container_path + [ container ])

        @drawing_def = CommonDrawingDecompositionWorker.new([ipath],
          ignore_faces: false,
          ignore_edges: false
        ).run

        # No face to panel : the container may still be a CONSTRUCTION
        # drawing, whose CLines the decomposition leaves out (ignore_clines
        # defaults to true, and there would be nothing to hide or extrude
        # anyway). The solid is rebuilt from them when STATE_PANELING opens
        # its operation — see #_rebuild_drawing_def_from_clines.
        if @drawing_def.is_a?(DrawingDef) && @drawing_def.face_manipulators.empty?
          _reset_drawing_def
          _set_cline_source(ipath)
        elsif @drawing_def.is_a?(DrawingDef) && !(error = _get_shell_error(@drawing_def.face_manipulators)).nil?

          # Panelling only knows how to work from a closed manifold solid — see
          # #_get_shell_error. A selection made BEFORE the action started has no
          # hover to carry a tooltip, so the refusal is notified out loud.
          @tool.notify_errors([ error ])
          _reset_drawing_def

        end

        # A DrawingDef with no face and no CLine to rebuild one from is not a
        # paneling source : entering STATE_PANELING with it used to leave the
        # tool in a state with nothing to click on and no way to tell why.
        if @drawing_def.is_a?(DrawingDef) || !@cline_source_ipath.nil?
          set_state(STATE_PANELING)
          _abandon_paneling if @drawing_def.nil?
        end

      end

    end

    def stop
      if @selected_face_manipulators.any?

        # Hide tool validation
        @tool.hide_validation

        # Remove faces and edges FIRST : purging goes through
        # DefinitionList#remove, and whatever it does to the open operation must
        # not cost the reference drawing its erasure. Reuse made this matter -
        # without it every definition holds an instance and nothing is ever
        # removed here.
        _erase_drawings

        _purge_definitions
        _clear_definitions_factory

        # Commit operation (apply entity changes)
        Sketchup.active_model.commit_operation

      else

        _purge_definitions
        _clear_definitions_factory

        # Abord operation (restore entities)
        Sketchup.active_model.abort_operation

      end
      _clear_selected
      _clear_edge_joint_types
      _reset_refused_drawing_def
      super
    end

    # -----

    def close_doors_on_start?
      true
    end

    # -----

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_PANELING
        return SmartCursorManager.cursor_select_paneling
      end

      super
    end

    def get_state_picker(state)

      case state
      when STATE_SELECT
        return SmartPicker.new(tool: @tool, observer: self, pick_point: false, pick_clines: true, pick_context_by_cline: true)
      end

      super
    end

    def get_state_status(state)

      case state
      when STATE_PANELING
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' + ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_1_rollover_face_status") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_1_select_similar_status") + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' + ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_1_rollover_face_status") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_1_select_all_edges_status") + '.'
      end

      super
    end

    def get_state_vcb_label(state)
      PLUGIN.get_i18n_string("tool.default.vcb_thickness")
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      if @tool.callback_action_handler.nil?

        case @state

        when STATE_SELECT
          _reset

        when STATE_PANELING
          _clear_edge_joint_types
          _clear_selected
          _clear_computed
          _reset

        end
        _refresh

      else
        _reset
        stop
        Sketchup.active_model.tools.pop_tool
      end

    end

    def onToolValidate(tool, view)
      _restart
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if (tool.is_key_shift?(key) || tool.is_key_ctrl_or_option_down?(key)) && @hover_face_manipulators.any?
        _refresh
      end

    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if (tool.is_key_shift?(key) || tool.is_key_ctrl_or_option_down?(key)) && @hover_face_manipulators.any?
        _refresh
      end

    end

    def onToolMouseMove(tool, flags, x, y, view)
      return true if super

      case @state

      when STATE_PANELING
        _snap_paneling(flags, x, y, view)
        _preview_paneling(view)
        return true

      end

      false
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT
        if @drawing_def.nil? && @cline_source_ipath.nil?
          UI.beep
        else
          set_state(STATE_PANELING)
          _abandon_paneling if @drawing_def.nil?  # The CLine rebuild failed
          return true
        end

      when STATE_PANELING
        if @hover_edge_manipulators.any?
          @hover_edge_manipulators.each do |em|
            _toggle_edge_joint_type(em.edge)
          end
          _compute
          _refresh
          return true
        end
        if @hover_face_manipulators.any?
          @hover_face_manipulators.each do |fm|
            _toggle_selected(fm)
          end
          _compute
          _refresh
          return true
        end

      end

    end

    def onToolLButtonDoubleClick(tool, flags, x, y, view)
      onToolLButtonUp(tool, flags, x, y, view)
    end

    def onToolUserText(tool, text, view)
      return true if super

      return true if _read_thickness(tool, text, view)

      false
    end

    def onStateChanged(old_state, new_state)

      case old_state

      when STATE_PANELING

        @tool.hide_validation

        _purge_definitions
        _clear_definitions_factory

        # Abort operation (restore entities state)
        Sketchup.active_model.abort_operation

      end

      case new_state

      when STATE_SELECT
        _reset_drawing_def
        _reset_refused_drawing_def
        _reset_cline_source
        @tool.clear_3d([ LAYER_3D_PANELING_PREVIEW ])

      when STATE_PANELING

        # Start operation (allows manipulating entities without altering the undo stack)
        Sketchup.active_model.start_operation(PLUGIN.get_i18n_string('tool.smart_reshape.action_1'), true)

        # A CONSTRUCTION drawing becomes a solid here, INSIDE the operation
        # just opened : leaving this state aborts it and the rebuilt geometry
        # never existed, committing erases it through _erase_drawings like any
        # other reference geometry. On failure @drawing_def stays nil and the
        # caller backs out — see #_abandon_paneling.
        _rebuild_drawing_def_from_clines unless @cline_source_ipath.nil?

        _clear_selected
        _clear_edge_joint_types
        _hide_drawings
        _preview_paneling(Sketchup.active_model.active_view)

      end

      super
    end

    def onPickerChanged(picker, view)

      case @state

      when STATE_SELECT
        _reset_drawing_def
        _reset_refused_drawing_def
        _reset_cline_source
        _snap_select(picker, view)
        _feedback_select
        _preview_select

      end

      super
    end

    def onToolActionOptionStored(tool, action, option_group, option)
      if option_group == SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE
        _clear_edge_joint_types
        _compute
      elsif option_group == SmartReshapeTool::ACTION_OPTION_PANELING_DIRECTION
        _compute
      elsif option_group == SmartReshapeTool::ACTION_OPTION_OPTIONS
        _compute
      end
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    protected

    def _reset
      # Same order as #stop : the reference drawing is put back BEFORE the
      # purge goes through DefinitionList#remove
      _unhide_drawings
      _purge_definitions
      _reset_drawing_def
      _reset_refused_drawing_def
      _reset_cline_source
      @hover_face_manipulators.clear
      @hover_edge_manipulators.clear
      @selected_face_manipulators.clear
      @edge_joint_types.clear
      super
      set_state(STATE_SELECT)
    end

    def _reset_drawing_def
      @drawing_def = nil
    end

    # Drops the refused shell AND the feedback it put on screen : the tooltip and
    # the error cursor outlive the pick that raised them, and would otherwise
    # follow the user out of the state, or out of the tool.
    def _reset_refused_drawing_def
      @refused_drawing_def = nil
      @refused_error = nil
      @tool.remove_root_tooltip
      @tool.pop_cursor(SmartCursorManager.cursor_select_error)
    end

    def _reset_cline_source
      @cline_source_ipath = nil
      @cline_source_manipulators = []
    end

    def _restart
      if @tool.callback_action_handler.nil?
        super
      else
        @tool.callback_action_handler.previous_action_handler = self
        Sketchup.active_model.tools.pop_tool if active?
      end
    end

    # Backs out of a STATE_PANELING that has nothing to panel — the CLine
    # rebuild failed, and its errors are already notified.
    #
    # Called by whoever asked for the state change, once set_state has
    # RETURNED : set_state is onStateChanged(@state, @state = state), so
    # switching back from inside onStateChanged would nest the abort inside the
    # operation being opened. From here the abort lands where it belongs.
    def _abandon_paneling
      set_state(STATE_SELECT)
      UI.beep
    end

    # ----- Check

    # The i18n error tuple saying why the shell these face manipulators describe
    # is not a closed manifold solid, nil when it is one. Paneling accepts
    # nothing else : a panel is bounded by the planes its neighbours provide, and
    # on a naked edge there is no neighbour — hence no miter, and no thickness to
    # stop against.
    #
    # An edge is read through the DRAWING and not through the model : what counts
    # is how many of its faces the drawing holds, so a face left outside — in
    # another context, on a hidden layer — closes nothing the paneling could rely
    # on. The edges are walked from the FACES rather than from the drawing's own
    # edge manipulators : the decomposition files curved edges under
    # curve_manipulators (see CommonDrawingDecompositionWorker), and a cylinder
    # would sail through unchecked. Edges bounding no face at all — stray
    # geometry the connectivity walk dragged along — are none of the shell's
    # business.
    #
    # Entities are keyed by #entityID and not by object : the same entity can
    # reach Ruby as more than one wrapper, which a Set of objects would count
    # twice.
    def _get_shell_error(face_manipulators)
      return [ 'core.solid.error.empty' ] if face_manipulators.empty?

      face_ids = Set.new(face_manipulators.map { |face_manipulator| face_manipulator.face.entityID })

      naked_edge_count = 0
      non_manifold_edge_count = 0

      edge_ids = Set.new
      face_manipulators.each do |face_manipulator|
        face_manipulator.face.edges.each do |edge|
          next unless edge_ids.add?(edge.entityID)
          count = edge.faces.count { |face| face_ids.include?(face.entityID) }
          naked_edge_count += 1 if count == 1
          non_manifold_edge_count += 1 if count > 2
        end
      end

      return [ 'core.solid.error.non_manifold_edges', { :count => non_manifold_edge_count } ] if non_manifold_edge_count > 0
      return [ 'core.solid.error.open_edges', { :count => naked_edge_count } ] if naked_edge_count > 0

      nil
    end

    # ----- Snap

    def _snap_select(picker, view)

      if (picked_face = picker.picked_face).is_a?(Sketchup::Face) && (picked_face_path = picker.picked_face_path).is_a?(Array)

        container = picked_face_path[-2]
        container_transformation = PathUtils.get_transformation(picked_face_path[0..-2], IDENTITY)

        all_connected = picked_face.all_connected

        drawing_def = DrawingDef.new(container, container_transformation)
        drawing_def.face_manipulators.concat(all_connected
                                                .grep(Sketchup::Face)
                                                .map { |face| FaceManipulator.new(face) })
        drawing_def.edge_manipulators.concat(all_connected
                                                .grep(Sketchup::Edge)
                                                .map { |edge| EdgeManipulator.new(edge) })

        # Everything connected to the picked face is a shell, but only a CLOSED
        # MANIFOLD one is a solid to panel — see #_get_shell_error. What it
        # refuses is retained apart : shown, explained, and never panelled.
        if (error = _get_shell_error(drawing_def.face_manipulators)).nil?
          @drawing_def = drawing_def
        else
          @refused_drawing_def = drawing_def
          @refused_error = error
        end

      end

      if picker.picked_cline.is_a?(Sketchup::ConstructionLine) && (picked_cline_path = picker.picked_cline_path).is_a?(Array)

        active_path = view.model.active_path.to_a
        _set_cline_source(Sketchup::InstancePath.new(active_path + picked_cline_path[0...-1]))

      end

      # A pick can land on a face AND on a CLine — one drawn over the other. The
      # CLine source wins : STATE_PANELING rebuilds from it and overwrites
      # whatever the face gave. So a shell refused next to one is refused for
      # nothing, and saying so would deny a click that does work.
      _reset_refused_drawing_def unless @cline_source_ipath.nil?

    end

    def _snap_paneling(flags, x, y, view)

      return unless @drawing_def.is_a?(DrawingDef)

      ph = view.pick_helper(x, y, 30)

      @hover_face_manipulators.clear
      @hover_edge_manipulators.clear

      @drawing_def.face_manipulators.each do |fm|
        if ph.test_point(fm.centroid.transform(@drawing_def.transformation))
          @hover_face_manipulators << fm

          if @tool.is_key_ctrl_or_option_down?

            matching_face_manipulators = _find_matching_face_manipulators(fm, @drawing_def.face_manipulators, mirror: true)
            matching_face_manipulators.each do |mfm|
              @hover_face_manipulators << mfm
            end

          end

          break
        end
      end

      if @hover_face_manipulators.any? && @tool.is_key_shift_down?

        @drawing_def.edge_manipulators.each do |em|
          if em.edge.faces.any? { |face| @hover_face_manipulators.any? { |fm| fm.face == face} } &&
             em.edge.faces.all? { |face| @selected_face_manipulators.any? { |fm| fm.face == face } }
            @hover_edge_manipulators << em
          end
        end

      elsif @hover_face_manipulators.empty? && @selected_face_manipulators.any?

        @drawing_def.edge_manipulators.each do |em|
          if ph.pick_segment(em.points.map { |point| point.transform(@drawing_def.transformation) }) &&
             em.edge.faces.all? { |face| @selected_face_manipulators.any? { |fm| fm.face == face } }
            @hover_edge_manipulators << em
            break
          end
        end

      end

    end

    # ----- Preview

    def _preview_select

      @tool.clear_3d([ LAYER_3D_PANELING_PREVIEW ])

      unless @cline_source_ipath.nil?

        segments = @cline_source_manipulators.flat_map { |manipulator| manipulator.points }
        transformation = @cline_source_ipath.transformation

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 4
        k_segments.line_stipple = Kuix::LINE_STIPPLE_SOLID
        k_segments.color = ColorUtils.color_lighten(Kuix::COLOR_BLUE, 0.8)
        k_segments.transformation = transformation
        @tool.append_3d(k_segments, LAYER_3D_PANELING_PREVIEW)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 2
        k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_segments.color = Kuix::COLOR_BLUE
        k_segments.transformation = transformation
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_PANELING_PREVIEW)

        bounds = Geom::BoundingBox.new
        @cline_source_manipulators.each { |manipulator| bounds.add(manipulator.points) }

        # k_box = Kuix::BoxMotif3d.new
        # k_box.bounds.copy!(Kuix::Bounds3d.new.copy!(bounds).inflate_all!(1))
        # k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        # k_box.color = Kuix::COLOR_DARK_GREY
        # k_box.transformation = transformation
        # @tool.append_3d(k_box, LAYER_3D_PANELING_PREVIEW)

      end

      # A refused shell is previewed too, in red : the user has to see WHICH
      # geometry the tooltip is talking about — see #_feedback_select.
      drawing_def = @drawing_def.is_a?(DrawingDef) ? @drawing_def : @refused_drawing_def
      return unless drawing_def.is_a?(DrawingDef)

      k_mesh = Kuix::Mesh.new
      k_mesh.add_triangles(drawing_def.face_manipulators.flat_map(&:triangles))
      k_mesh.background_color = ColorUtils.color_lighten(Kuix::COLOR_BLUE, 0.5) #ColorUtils.color_translucent(@drawing_def.nil? ? Kuix::COLOR_RED : Kuix::COLOR_BLUE, 0.3)
      k_mesh.transformation = drawing_def.transformation
      @tool.append_3d(k_mesh, LAYER_3D_PANELING_PREVIEW)

      kb = Kuix::Bounds3d.new.copy!(drawing_def.bounds).inflate_all!(1)

      # k_box = Kuix::BoxMotif3d.new
      # k_box.bounds.copy!(kb)
      # k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      # k_box.color = Kuix::COLOR_DARK_GREY
      # k_box.transformation = drawing_def.transformation
      # @tool.append_3d(k_box, LAYER_3D_PANELING_PREVIEW)

    end

    def _preview_paneling(view)

      @tool.clear_3d([ LAYER_3D_PANELING_PREVIEW ])

      return unless @drawing_def.is_a?(DrawingDef)

      size = view.pixels_to_model(25, @drawing_def.bounds.center.transform(@drawing_def.transformation))

      @drawing_def.face_manipulators.each do |fm|

        hover_face = @hover_face_manipulators.include?(fm)
        selected = @selected_face_manipulators.include?(fm)

        if hover_face && @hover_edge_manipulators.none?

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(fm.triangles)
          k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_MAGENTA, 0.3)
          k_mesh.transformation = @drawing_def.transformation
          @tool.append_3d(k_mesh, LAYER_3D_PANELING_PREVIEW)

        end

        color = ColorUtils.color_translucent(selected ? Kuix::COLOR_MAGENTA : Kuix::COLOR_DARK_GREY, 0.8)
        color = ColorUtils.color_darken(color, 0.4) if hover_face

        x_axis = fm.centroid.vector_to(fm.outer_loop_manipulator.points.first).normalize
        z_axis = fm.normal
        y_axis = x_axis.cross(z_axis).normalize!

        ct = @drawing_def.transformation * Geom::Transformation.axes(fm.centroid, x_axis, y_axis, z_axis)

        k_circle_bg = Kuix::CircleFillMotif3d.new(12)
        k_circle_bg.bounds.origin.set!(-(size * 0.5), -(size * 0.5), 0)
        k_circle_bg.bounds.size.set!(size, size, 0)
        k_circle_bg.color = Kuix::COLOR_WHITE
        k_circle_bg.transformation = ct
        k_circle_bg.on_top = true
        @tool.append_3d(k_circle_bg, LAYER_3D_PANELING_PREVIEW)

        k_circle_stroke = Kuix::CircleMotif3d.new(12)
        k_circle_stroke.bounds.copy!(k_circle_bg.bounds)
        k_circle_stroke.line_width = 2
        k_circle_stroke.color = color
        k_circle_stroke.transformation = ct
        k_circle_stroke.on_top = true
        @tool.append_3d(k_circle_stroke, LAYER_3D_PANELING_PREVIEW)

        k_circle_fg = Kuix::CircleFillMotif3d.new(12)
        k_circle_fg.bounds.origin.set!(-(size * 0.35), -(size * 0.35), 0)
        k_circle_fg.bounds.size.set!(size * 0.7, size * 0.7, 0)
        k_circle_fg.color = color
        k_circle_fg.transformation = ct
        k_circle_fg.on_top = true
        @tool.append_3d(k_circle_fg, LAYER_3D_PANELING_PREVIEW)

      end

      if @hover_edge_manipulators.any?

        k_segments = Kuix::Segments.new
        k_segments.add_segments(@hover_edge_manipulators.flat_map { |em| em.points })
        k_segments.line_width = 2
        k_segments.color = Kuix::COLOR_MAGENTA
        k_segments.on_top = true
        k_segments.transformation = @drawing_def.transformation
        @tool.append_3d(k_segments, LAYER_3D_PANELING_PREVIEW)

      end

    end

    # ----- Feedback

    # Says, on the spot, why the shell under the cursor cannot be panelled : the
    # error cursor that the click will lead nowhere, the tooltip what is wrong
    # with the geometry. Same idiom as
    # SmartActionHandlerPartHelper#_set_active_part.
    #
    # Only ever puts feedback UP : taking it down belongs to
    # #_reset_refused_drawing_def, which every pick — and every way out of the
    # state — goes through first.
    def _feedback_select
      return if @refused_error.nil?
      @tool.set_root_tooltip(PLUGIN.get_i18n_string(@refused_error[0], @refused_error[1]), SmartTool::MESSAGE_TYPE_ERROR)
      @tool.push_cursor(SmartCursorManager.cursor_select_error)
    end

    # ----- Read

    def _read_thickness(tool, text, view)

      # Keep it "compatible" with the way to enter offset in Smart Draw Tool.
      if (match = /^(.+)x$/i.match(text))
        text = match[1]
      end

      thickness = _read_user_text_length(tool, text)
      return true if thickness.nil?

      if thickness < 0
        tool.notify_errors([[ 'tool.default.error.invalid_thickness', { :value => thickness } ]])
        return true
      end

      @tool.store_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_THICKNESS, SmartReshapeTool::ACTION_OPTION_THICKNESS_THICKNESS, thickness.to_s, fire_event: true)
      @tool.set_status_vcb_value('')
      _compute
      _refresh

      false
    end

    # -----

    def _fetch_option_thickness
      @tool.fetch_action_option_length(@action, SmartReshapeTool::ACTION_OPTION_THICKNESS, SmartReshapeTool::ACTION_OPTION_THICKNESS_THICKNESS)
    end

    def _fetch_option_paneling_direction
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_PANELING_DIRECTION)
    end

    def _fetch_option_paneling_direction_inward?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_PANELING_DIRECTION, SmartReshapeTool::ACTION_OPTION_PANELING_DIRECTION_INWARD)
    end

    def _fetch_option_paneling_direction_outward?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_PANELING_DIRECTION, SmartReshapeTool::ACTION_OPTION_PANELING_DIRECTION_OUTWARD)
    end

    def _fetch_option_paneling_join_type
      @tool.fetch_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE)
    end

    def _fetch_option_paneling_join_type_flat?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE, SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_FLAT)
    end

    def _fetch_option_paneling_join_type_miter?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE, SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_MITER)
    end

    def _fetch_option_reuse_definition?
      @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
    end

    def _fetch_option_reuse_definition_mirrored?
      _fetch_option_reuse_definition? &&
        @tool.fetch_action_option_boolean(@action, SmartReshapeTool::ACTION_OPTION_OPTIONS, SmartReshapeTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION_MIRRORED)
    end

    # -----

    def _hide_drawings
      if @drawing_def.is_a?(DrawingDef)
        @drawing_def.face_manipulators.each { |fm| fm.face.visible = false }
      end
    end

    def _unhide_drawings
      if @drawing_def.is_a?(DrawingDef)
        @drawing_def.face_manipulators.each { |fm| fm.face.visible = true }
      end
    end

    def _erase_drawings
      if @drawing_def.is_a?(DrawingDef)
        edges = @drawing_def.edge_manipulators.map(&:edge).reject { |edge| !edge.is_a?(Sketchup::Edge) || edge.deleted? }
        edges += @drawing_def.curve_manipulators.flat_map { |cm| cm.curve.edges }.reject { |edge| !edge.is_a?(Sketchup::Edge) || edge.deleted? }
        _get_active_entities.erase_entities(edges) unless edges.empty?
        _reset_drawing_def
      end
    end

    # ----- CLine stuff

    # Retains the given container (InstancePath) as the CONSTRUCTION drawing to
    # rebuild, and collects the manipulators the STATE_SELECT preview draws it
    # with. Returns false — and retains nothing — when it holds no usable CLine,
    # or when the model locks forbid writing into it : the rebuild puts the
    # solid, and later the panels, inside that very container.
    #
    # Infinite CLines are left out of the PREVIEW only (ClineManipulator#points
    # would dereference a nil endpoint) ; the rebuild clips them against the
    # rest of the drawing on its own.
    def _set_cline_source(ipath)
      return false if ipath.nil?

      container = _cline_source_container(ipath)
      return false unless container.respond_to?(:definition)

      manipulators = container.definition.entities
                              .grep(Sketchup::ConstructionLine)
                              .map { |cline| ClineManipulator.new(cline) }
                              .reject { |manipulator| manipulator.infinite? }
      return false if manipulators.empty?

      if LockUtils.locked_path?(ipath.to_a)
        @tool.notify_errors([ [ 'tool.default.error.selection_contains_locked_entities' ] ])
        return false
      end

      @cline_source_ipath = ipath
      @cline_source_manipulators = manipulators
      true
    end

    # The container an InstancePath ends on. Read off #to_a and NOT off #leaf :
    # a path whose last element is an INSTANCE — which is exactly what a
    # container path is — makes Sketchup::InstancePath#leaf return nil, as it
    # only ever yields a terminal drawing element.
    def _cline_source_container(ipath)
      ipath.to_a.last
    end

    # Turns the retained CONSTRUCTION drawing into the reference solid, in the
    # operation STATE_PANELING has just opened (hence wrap_operation: false).
    # The CLines are kept : they are the drawing the user works from, they
    # survive _erase_drawings at commit — which only erases edges — and the
    # panels are built alongside them, in the same container.
    #
    # The manipulators are left untransformed and the container transformation
    # carried by the DrawingDef, which is the convention #_snap_select follows —
    # NOT the one CommonDrawingDecompositionWorker produces.
    def _rebuild_drawing_def_from_clines

      container = _cline_source_container(@cline_source_ipath)
      container_transformation = @cline_source_ipath.transformation

      result_def = CommonSolidRebuildFromClinesWorker.new(container,
                                                          # The CLines are read through the container's own placement, and the
                                                          # rebuilt geometry written back into it : both sides of the worker
                                                          # speak the same space, whatever the container is nested in.
                                                          source_transformation: PathUtils.get_transformation(@cline_source_ipath.to_a[0...-1], IDENTITY),
                                                          target_entities: container.definition.entities,
                                                          target_transformation: container_transformation,
                                                          keep_inner_faces: false,
                                                          orient_faces: true,
                                                          erase_sources: false,
                                                          wrap_operation: false
      ).run

      unless result_def.success?
        @tool.notify_errors(result_def.errors)
        return false
      end

      # The rebuild succeeds as soon as it makes ONE face, but paneling asks for
      # a closed manifold solid like anywhere else — see #_get_shell_error. The
      # drawing gets the same verdict as a picked shell, only later : what the
      # CLines enclose is only known once they have been turned into geometry.
      # Sending back false leaves the caller to abandon the state, whose abort
      # takes that geometry with it.
      unless result_def.closed?
        if result_def.face_count == 0
          @tool.notify_errors([ [ 'core.solid.error.empty' ] ])
        elsif result_def.non_manifold_edge_count > 0
          @tool.notify_errors([ [ 'core.solid.error.non_manifold_edges', { :count => result_def.non_manifold_edge_count } ] ])
        else
          @tool.notify_errors([ [ 'core.solid.error.open_edges', { :count => result_def.naked_edge_count } ] ])
        end
        return false
      end

      @drawing_def = DrawingDef.new(container, container_transformation)
      @drawing_def.face_manipulators.concat(result_def.faces.map { |face| FaceManipulator.new(face) })
      @drawing_def.edge_manipulators.concat(result_def.edges.map { |edge| EdgeManipulator.new(edge) })

      true
    end

    # -----

    def _toggle_selected(face_manipulator)
      if @selected_face_manipulators.include?(face_manipulator)
        @selected_face_manipulators.delete(face_manipulator)
        face_manipulator.face.edges
                        .select { |edge| @selected_face_manipulators.none? { |fm| fm.face.edges.include?(edge) } }
                        .each { |edge| _delete_edge_joint_type(edge) }
      else
        @selected_face_manipulators << face_manipulator
      end
    end

    def _clear_selected
      @selected_face_manipulators.clear
    end

    # -----

    def _get_joint_type(edge)
      @edge_joint_types[edge] ||= _fetch_option_paneling_join_type
    end

    def _get_joint_type_miter?(edge)
      _get_joint_type(edge) == SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_MITER
    end

    def _get_faces_joint_type_miter?(face_manipulator_1, face_manipulator_2)
      return false unless face_manipulator_1 == face_manipulator_2 || @selected_face_manipulators.include?(face_manipulator_1) && @selected_face_manipulators.include?(face_manipulator_2)
      shared_edge = (face_manipulator_1.face.edges & face_manipulator_2.face.edges).first
      return _get_joint_type_miter?(shared_edge) unless shared_edge.nil?  # Faces shared one edge
      shared_vertex = (face_manipulator_1.face.vertices & face_manipulator_2.face.vertices).first
      return _get_joint_type_miter?(shared_vertex.edges.first) unless shared_vertex.nil?  # Faces shared one vertex: use joint type of the first vertex edge
      false  # Faces shared nothing
    end

    def _toggle_edge_joint_type(edge)
      case _get_joint_type(edge)
      when SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_FLAT
        @edge_joint_types[edge] = SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_MITER
      when SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_MITER
        @edge_joint_types[edge] = SmartReshapeTool::ACTION_OPTION_PANELING_JOINT_TYPE_FLAT
      else
        @edge_joint_types[edge] = _fetch_option_paneling_join_type
      end
    end

    def _delete_edge_joint_type(edge)
      @edge_joint_types.delete(edge)
    end

    def _clear_edge_joint_types
      @edge_joint_types.clear
    end

    # -----

    def _get_active_entities
      return @drawing_def.container.definition.entities if @drawing_def && @drawing_def.container.respond_to?(:definition)
      Sketchup.active_model.active_entities
    end

    def _get_definitions_factory
      @definitions_factory ||= {}
    end

    def _clear_definitions_factory
      @definitions_factory.clear if @definitions_factory.is_a?(Hash)
    end

    def _create_definition(face, name = 'Part')
      definitions_factory = _get_definitions_factory
      if (definition = definitions_factory[face]).nil?
        definition = definitions_factory[face] = Sketchup.active_model.definitions.add(name)
      else
        definition.entities.clear!
      end
      definition
    end

    # An already created panel whose definition the panel being computed could
    # share, or nil. Returns [ definition, transformation ] : the definition to
    # instantiate, and where to place that new instance.
    #
    # Congruence is read on the PANEL, never on the source face : a corner
    # point is the intersection of three planes, and whether a neighbour
    # contributes its own plane or its plane offset by the thickness depends on
    # the edge's joint type AND on the extrusion order (see #_compute). Two
    # congruent source faces routinely produce two different panels.
    #
    # +points+ is the panel's whole point cloud - gd points and up points
    # together - so the check below covers the solid, not just an outline.
    def _find_reusable_panel_def(entities, points, signature, front_centroid, panel_defs)
      return nil unless _fetch_option_reuse_definition?
      return nil if panel_defs.empty?

      # The panel is still expressed in the container's space at this stage -
      # its axes are only adapted once it is known not to be reusable
      reference_manipulator = entities.grep(Sketchup::Face)
                                      .map { |face| FaceManipulator.new(face) }
                                      .max_by { |face_manipulator| face_manipulator.face.area }
      return nil if reference_manipulator.nil?

      mirrored = _fetch_option_reuse_definition_mirrored?

      best = nil # [ definition, instance transformation, score ]

      panel_defs.each do |definition, transformation, face_manipulators, candidate_points, candidate_signature, candidate_front_centroid|
        next unless _panel_points_signatures_match?(signature, candidate_signature)

        # #_face_manipulators_alignment_transformations only ever answers
        # PROPER motions - see FaceMatcherHelper. The mirrored placements are
        # reached by reflecting the candidate first : the proper V it then
        # returns composes into V * REFLECTION, of negative determinant.
        variants = [ [ face_manipulators, nil ] ]
        if mirrored
          variants << [
            face_manipulators.map { |face_manipulator| FaceManipulator.new(face_manipulator.face, PANEL_REFLECTION * transformation) },
            PANEL_REFLECTION
          ]
        end

        variants.each do |variant_manipulators, reflection|

          variant_manipulators.each do |face_manipulator|

            # Every alignment, not just the first : a symmetric face superposes
            # several ways - a rectangle four ways - and only some of them may
            # also superpose the solid
            _face_manipulators_alignment_transformations(reference_manipulator, face_manipulator).each do |alignment|

              t = reflection.nil? ? alignment : alignment * reflection

              next unless _points_sets_superpose?(points, candidate_points, t)

              score = _panel_placement_score(t, candidate_front_centroid, front_centroid)
              next unless best.nil? || (score <=> best.last) > 0

              best = [ definition, t * transformation, score ]

            end

          end

        end

      end

      best.nil? ? nil : [ best[0], best[1] ]
    end

    # How good a placement is, highest wins. Every placement scored here
    # already superposes the solid - they only differ in how the reused panel
    # is turned.
    #
    # 1. front face outside, the convention #_compute sets its part axes on.
    #    Beats everything else : the alternative is a panel that reads
    #    inside out.
    # 2. then, the linear part closest to the identity - maximizing its trace
    #    minimizes ||L - I||, so the reused instance keeps the owner's axes as
    #    much as the placement allows.
    #
    # On two facing panels of a caisson these two criteria cannot both be fully
    # met by a proper motion : keeping the front face outside forces a 180°
    # turn that reverses either the "up" axis or the "front" axis. Only a
    # reflection preserves all three, which is what criterion 2 elects as soon
    # as the mirrored variants are enumerated (trace 1, against -1 for both
    # proper turns).
    def _panel_placement_score(t, candidate_front_centroid, front_centroid)
      [
        candidate_front_centroid.transform(t) == front_centroid ? 1 : 0,
        _transformation_trace(t)
      ]
    end

    def _transformation_trace(transformation)
      a = transformation.to_a
      w = a[15]
      w = 1.0 if w.nil? || w == 0
      (a[0] + a[5] + a[10]) / w
    end

    # Fingerprint invariant by rotation AND translation : the sorted distances
    # from the point cloud's centroid. Cheap pre-filter that spares the
    # alignment search on all but the genuinely congruent candidates.
    #
    # Kept as raw lengths and compared with a tolerance rather than quantized
    # into a hashable key : two congruent panels are computed independently,
    # each through its own plane intersections, so they carry their own
    # floating point noise - and any quantization boundary they happened to
    # straddle would silently cost the reuse.
    def _panel_points_signature(points)
      centroid = Geometrix::PointFinder.find_centroid(points)
      points.map { |point| centroid.distance(point).to_f }.sort
    end

    def _panel_points_signatures_match?(signature, other_signature)
      return false unless signature.length == other_signature.length
      signature.each_with_index.all? { |distance, index| (distance - other_signature[index]).abs <= SolidMeshDef::TOLERANCE }
    end

    # True when +other_points+, once transformed, is exactly +points+ - each
    # point matched one to one, within SketchUp's tolerance.
    def _points_sets_superpose?(points, other_points, t)
      return false unless points.length == other_points.length
      remaining = points.dup
      other_points.all? { |point|
        transformed_point = point.transform(t)
        index = remaining.index { |other_point| other_point == transformed_point }
        next false if index.nil?
        remaining.delete_at(index)
        true
      }
    end

    def _purge_definitions
      _get_definitions_factory.each_value do |definition|
        next if definition.deleted? || definition.count_used_instances > 0
        Sketchup.active_model.definitions.remove(definition) if Sketchup.active_model.definitions.respond_to?(:remove)  # SketchUp 2018+
      end
    end

    def _clear_computed
      _get_active_entities.erase_entities(
        _get_definitions_factory.values
                                .select { |definition| !definition.deleted? }
                                .flat_map { |definition| definition.instances }
      )
    end

    def _intersect_planes(planes, ref_plane, ref_centroid)
      return [] unless planes.is_a?(Array) && planes.size >= 3

      points = []

      # Calculate all intersection lines of plane pairs
      lines = planes.combination(2).map { |plane1, plane2| Geom.intersect_plane_plane(plane1, plane2) }.compact

      # Calculate all unique intersection points of the lines
      lines.combination(3).each { |line1, line2, line3|
        p1 = Geom.intersect_line_line(line1, line2)
        next if p1.nil? || points.include?(p1)
        p2 = Geom.intersect_line_line(line2, line3)
        points << p1 if p1 == p2
      }

      # Filter points
      points.select! { |point|
        point.on_plane?(ref_plane) &&
          planes.all? { |plane|
            !(v = point.vector_to(point.project_to_plane(plane))).valid? ||
              v.samedirection?(plane[1])
          }
      }

      if points.size > 1

        _, plane_normal = ref_plane
        x_axis = ref_centroid.vector_to(points.first).normalize!
        y_axis = plane_normal.cross(x_axis).normalize!

        # Sort points in clockwise order
        points.sort_by! { |point|
          v = ref_centroid.vector_to(point)
          x = v.dot(x_axis)
          y = v.dot(y_axis)
          Math.atan2(y, x)
        }

      end

      points
    end

    # A corner point is the intersection of three planes, and the drawing is
    # guaranteed a closed manifold solid — see #_get_shell_error — so every
    # vertex has its three faces to provide them. The `gd_points.size < 3` guard
    # below only ever catches degenerate geometry.
    def _compute

      _clear_computed

      return unless @drawing_def.is_a?(DrawingDef)

      outward = _fetch_option_paneling_direction_outward?
      thickness = _fetch_option_thickness.abs
      thickness *= -1 unless outward
      active_entities = _get_active_entities
      extruded_face_manipulators = Set.new

      # [ definition, transformation, CONTAINER space face manipulators, points, signature, front centroid ]
      # of every panel created by this pass, the pool #_find_reusable_panel_def
      # picks a definition to share from
      panel_defs = []

      @selected_face_manipulators.each do |sfm|

        gd_centroid = sfm.centroid
        up_centroid = sfm.centroid.offset(sfm.normal, thickness)

        gd_plane = sfm.plane
        up_plane = [ up_centroid, sfm.normal ]

        # 1. Extract points from face outer vertices

        gd_points = []
        up_points = []

        vertex_gd_points = {}
        vertex_th_points = {}

        sfm.outer_loop_manipulator.vertex_manipulators.each do |vm|

          # Ground points

          planes = vm.vertex.faces
                     .map { |face| @drawing_def.face_manipulators.find { |fm| fm.face == face } }
                     .compact
                     .map { |fm|
                       if fm == sfm || (miter = _get_faces_joint_type_miter?(fm, sfm)) || !miter && !extruded_face_manipulators.include?(fm)
                         fm.plane
                       else
                         [ fm.position.offset(fm.normal, thickness), fm.normal ]
                       end
                     }

          if (points = _intersect_planes(planes, gd_plane, gd_centroid)).any?
            vertex_gd_points[vm.vertex] = points
            gd_points.concat(points)
          end

          unless thickness.zero?

            # Up points

            planes = vm.vertex.faces
                       .map { |face| @drawing_def.face_manipulators.find { |fm| fm.face == face } }
                       .compact
                       .map { |fm|
                         if fm == sfm || !(miter = _get_faces_joint_type_miter?(fm, sfm)) && extruded_face_manipulators.include?(fm) || miter && @selected_face_manipulators.include?(fm)
                           [ fm.position.offset(fm.normal, thickness), fm.normal ]
                         else
                           fm.plane
                         end
                       }

            if (points = _intersect_planes(planes, up_plane, up_centroid)).any?
              vertex_th_points[vm.vertex] = points
              up_points.concat(points)
            end

          end

        end

        gd_points.uniq! { |point| point.to_a }
        up_points.uniq! { |point| point.to_a }

        next if gd_points.size < 3 || up_points.size < 3

        # 2. Create part definition + instance

        definition = _create_definition(sfm.face, PLUGIN.get_i18n_string('default.part_single').capitalize)
        entities = definition.entities

        # 3. Draw main faces

        gd_face = entities.add_face(gd_points)
        gd_face.reverse! unless gd_face.normal.samedirection?(sfm.normal)
        gd_face.reverse! if outward

        unless thickness.zero?
          up_face = entities.add_face(up_points)
          up_face.reverse! unless outward
        end

        # 4. Connect faces

        unless thickness.zero?

          edges = []
          sfm.outer_loop_manipulator.vertex_manipulators.each do |vm|
            a1 = vertex_gd_points[vm.vertex]
            a2 = vertex_th_points[vm.vertex]
            next if a1.nil? || a1.empty? || a2.nil? || a2.empty?
            a1 = a1.cycle.take(a2.size) if a2.size > a1.size
            a2 = a2.cycle.take(a1.size) if a1.size > a2.size
            a1.zip(a2).each { |p1, p2| edges.concat(entities.add_edges(p1, p2)) }
          end

          # 4. Find all other faces

          edges.each(&:find_faces)

        end

        # 5. Reuse the definition of an identical panel, or keep this one

        points = gd_points + up_points
        signature = _panel_points_signature(points)
        front_centroid = Geometrix::PointFinder.find_centroid(outward ? up_points : gd_points)

        if (panel_def = _find_reusable_panel_def(entities, points, signature, front_centroid, panel_defs)).nil?

          # 6. Adapt part axes

          z_axis = sfm.normal # Front face is always outside
          x_axis = EdgeManipulator.new(sfm.longest_outer_edge, sfm.transformation).direction
          y_axis = z_axis.cross(x_axis).normalize!

          t = Geom::Transformation.axes(sfm.centroid, x_axis, y_axis, z_axis)

          definition.entities.transform_entities(t.inverse, definition.entities.to_a) # Inverted both lines failed on old version of SketchUp
          active_entities.add_instance(definition, t)

          # Offer this panel to the following ones. Its face manipulators are
          # built AFTER the entities moved to the definition's own space, and
          # carry t so they read back in the container's space - building them
          # before would leave them caching points the transform then moves.
          panel_defs << [
            definition,
            t,
            definition.entities.grep(Sketchup::Face).map { |face| FaceManipulator.new(face, t) },
            points,
            signature,
            front_centroid
          ]

        else

          # Give the temporary definition back - #_purge_definitions removes it
          # from the model when the operation ends
          entities.clear!
          active_entities.add_instance(panel_def[0], panel_def[1])

        end

        # Flag face as extruded
        extruded_face_manipulators << sfm

      end

      # Update tool validation display
      if @selected_face_manipulators.any?
        @tool.show_validation
      else
        @tool.hide_validation
      end

    end

  end

end