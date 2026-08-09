module Ladb::OpenCutList

  require 'digest'
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
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_solid_boolean_apply_worker'
  require_relative '../worker/common/common_solid_rebuild_from_clines_worker'

  class SmartReshapeTool < SmartTool

    ACTION_STRETCH = 0
    ACTION_PANELING = 1
    ACTION_SOLID_UNITE = 2
    ACTION_SOLID_SUBTRACT = 3
    ACTION_SOLID_INTERSECT = 4

    ACTION_OPTION_THICKNESS = 'thickness'
    ACTION_OPTION_STRETCH_MEASURE_TYPE = 'stretch_measure_type'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_PANELING_DIRECTION = 'paneling_direction'
    ACTION_OPTION_PANELING_JOINT_TYPE = 'paneling_joint_type'
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
          return [ ACTION_STRETCH, ACTION_SOLID_UNITE, ACTION_SOLID_SUBTRACT, ACTION_SOLID_INTERSECT ]
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

    def get_action_option_group_titled?(action, option_group)

      case action
      when ACTION_PANELING
        case option_group
        when ACTION_OPTION_PANELING_JOINT_TYPE
          return true
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
      when ACTION_OPTION_PANELING_DIRECTION
        case option
        when ACTION_OPTION_PANELING_DIRECTION_INWARD
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.125,0.125L0.875,0.125L0.875,0.875 M0.625,0.375L0.375,0.625 M0.375,0.375L0.375,0.625L0.625,0.625'))
        when ACTION_OPTION_PANELING_DIRECTION_OUTWARD
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.375L0.625,0.375L0.625,1 M0.75,0.25L1,0 M1,0.25L1,0L0.75,0'))
        end
      when ACTION_OPTION_PANELING_JOINT_TYPE
        case option
        when ACTION_OPTION_PANELING_JOINT_TYPE_FLAT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0L1,1L0.625,1L0.625,0.375 M1,0L0,0L0,0.375L0.625,0.375L0.625,0'))
        when ACTION_OPTION_PANELING_JOINT_TYPE_MITER
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L0,0.375L0.625,0.375L1,0L0,0 M1,0L1,1L0.625,1L0.625,0.375'))
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0.667,1L1,0.667L1,0L0.333,0L0,0.333L0,1 M0,0.333L0.667,0.333L0.667,1 M0.667,0.333L1,0 M0.333,0.5L0.333,0.833 M0.167,0.667L0.5,0.667'))
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0.167L0.167,0.833 M0.417,0.167L0.417,0.833 M0,0.333L0.583,0.333 M0,0.667L0.583,0.667 M0.75,0.333L1,0.167L1,0.833'))
        when ACTION_OPTION_OPTIONS_KEEP_A
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_reshape.action_option_options_keep_a'))
        when ACTION_OPTION_OPTIONS_KEEP_B
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_reshape.action_option_options_keep_b'))
        when ACTION_OPTION_OPTIONS_REMOVE_UNUSED_DEFINITIONS
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.75,0.625L0.25,0.625L0.25,0.75L0.75,0.75L0.75,0.625 M0.5,0.625L0.5,0 M0.25,0.75L0.188,1 M0.75,0.75L0.813,1 M0.375,0.75L0.345,1 M0.5,0.75L0.5,1 M0.625,0.75L0.655,1'))
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.333L0.667,0.333L0.667,1L0,1L0,0.333 M0.333,0.333L0.333,0L1,0L1,0.667L0.667,0.667'))
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION_MIRRORED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2'))
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

    OPERATION_NONE = 0
    OPERATION_MOVE = 1
    OPERATION_SPLIT = 2

    @@last_cutters_data = nil

    @@last_stretch_measures = { :outside => 0, :offset => 0 }

    attr_writer :ignore_next_lbutton_up

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
        return super +
               ' ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1a_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1b_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_0_state_1c_status") + '.'

      when STATE_STRETCH
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string("tool.default.locked_on_last_measure_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_reshape.action_option_options_centered_status") + '.' +
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

          _snap_stretch_start(flags, x, y, view)
          _preview_stretch_start(view)

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

            @picked_stretch_start_point = keb.face_center(@picked_grip_index).to_p.transform(et)
            @picked_stretch_start_opposite_point = keb.face_center(Kuix::Bounds3d.face_opposite(@picked_grip_index)).to_p.transform(et)

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

          @picked_stretch_start_point = keb.face_center(@picked_grip_index).to_p.transform(et)
          @picked_stretch_start_opposite_point = keb.face_center(Kuix::Bounds3d.face_opposite(@picked_grip_index)).to_p.transform(et)
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
        @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

      else

        @tool.remove_tooltip

      end
    end

    # -----

    def _add_part_twin(part_entity_path, part)
      return true if super
      get_active_selection_instances << part_entity_path.last
    end

    # -----

    def _snap_stretch_start(flags, x, y, view)

      @picked_grip_index = nil
      @picked_cutter_index = nil

      return false unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      @locked_axis = nil if @locked_axis && keb.dim_by_axis(@locked_axis) == 0
      @picked_axis = @locked_axis unless @locked_axis.nil?

      ph = view.pick_helper(x, y)

      # Snap to grip?

      [ X_AXIS, Y_AXIS, Z_AXIS ].select { |axis| (@locked_axis.nil? || axis == @locked_axis) && keb.dim_by_axis(axis) > 0 }.each do |axis|
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

        if @mouse_ip.degrees_of_freedom > 2 ||
           @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1 ||
           @mouse_ip.position.on_plane?([@picked_stretch_start_opposite_point, direction ]) ||
           @mouse_ip.face && @mouse_ip.face == @mouse_ip.instance_path.leaf && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(direction) ||
           @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(direction)

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
      if @tool.is_key_shift_down? && (measure = _fetch_last_stretch_measure) != 0
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

        unless @picked_grip_index.nil?

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

        axes = [ X_AXIS, Y_AXIS, Z_AXIS ].delete_if { |axis| axis == @picked_axis || keb.dim_by_axis(axis) == 0 }

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

      split_def, emv, edvs, lps, lpe = stretch_def.values_at(:split_def, :emv,:edvs, :lps, :lpe)
      et, container_defs = split_def.values_at(:et, :container_defs)

      axis_color = _get_vector_color(lps.vector_to(lpe))
      no_scale_color = Kuix::COLOR_DARK_GREY

      fn_preview_container = lambda do |container_def, color|

        color = no_scale_color if LockUtils.locked?(container_def.container) ||
                                  container_def.container.respond_to?(:definition) && container_def.container.definition.behavior.no_scale_mask? == 0b1111111 # 0b1111111 = 127 (all disabld)

        # Render edges

        if container_def.edge_defs.any?
          k_segments = Kuix::Segments.new
          k_segments.add_segments(container_def.edge_defs.flat_map { |edge_def|
            edge = edge_def.edge
            t = edge_def.transformation
            ti = edge_def.transformation_inverse
            [
              edge.start.position.offset(edvs[edge_def.start_section_def].transform(ti)).transform(t).offset(emv),
              edge.end.position.offset(edvs[edge_def.end_section_def].transform(ti)).transform(t).offset(emv)
            ]
          })
          k_segments.color = color
          k_segments.line_width = 1.5
          k_segments.transformation = et
          @tool.append_3d(k_segments, LAYER_3D_STRETCH_PREVIEW)
        end

        # Render clines

        if container_def.cline_defs.any?
          k_segments = Kuix::Segments.new
          k_segments.add_segments(container_def.cline_defs.flat_map { |cline_def|
            cline = cline_def.cline
            t = cline_def.transformation
            ti = cline_def.transformation_inverse
            [
              cline.start.offset(edvs[cline_def.start_section_def].transform(ti)).transform(t).offset(emv),
              cline.end.offset(edvs[cline_def.end_section_def].transform(ti)).transform(t).offset(emv)
            ]
          })
          k_segments.color = color
          k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
          k_segments.transformation = et
          @tool.append_3d(k_segments, LAYER_3D_STRETCH_PREVIEW)
        end

        # Render snaps

        if container_def.snap_defs.any?
          k_points = _create_floating_points(
            points: container_def.snap_defs.map { |snap_def|
              snap = snap_def.snap
              t = snap_def.transformation
              ti = snap_def.transformation_inverse
              snap.position.offset(edvs[snap_def.section_def].transform(ti)).transform(t).offset(emv)
            },
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
      fn_preview_container.call(container_defs.first, axis_color)


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
      k_edge.color = ColorUtils.color_translucent(color, 60)
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_STRETCH_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(lps)
      k_edge.end.copy!(lpe)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_edge.color = color
      @tool.append_3d(k_edge, LAYER_3D_STRETCH_PREVIEW)

      @tool.append_3d(_create_floating_points(points: [ lps, lpe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: Kuix::COLOR_WHITE, stroke_color: color, size: 2), LAYER_3D_STRETCH_PREVIEW)
      @tool.append_3d(_create_floating_points(points: @picked_stretch_start_point, style: Kuix::POINT_STYLE_CIRCLE, stroke_color: nil, fill_color: color, size: 2), LAYER_3D_STRETCH_PREVIEW)

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

    def _read_stretch(tool, text, view)
      return false if (stretch_def = _get_stretch_def(@picked_stretch_start_point, @mouse_snap_point)).nil?

      lps, lpe = stretch_def.values_at(:lps, :lpe)

      distance = _read_user_text_length(tool, text, lps.distance(lpe))
      return true if distance.nil?

      measure_type_outside = _fetch_option_stretch_measure_type_outside?

      # Error if distance < 0 and the measure type is outside
      if measure_type_outside && distance < 0
        tool.notify_errors([ [ "tool.default.error.invalid_length", { :value => distance.to_l } ] ])
        return false
      end

      return false if (measure_def = _get_stretch_measure_def(distance)).nil?
      end_point, pmin, pmax, compression_distance, max_compression_distance = measure_def.values_at(:end_point, :pmin, :pmax, :compression_distance, :max_compression_distance)

      return false if (stretch_def = _get_stretch_def(@picked_stretch_start_point, end_point)).nil?
      split_def, esv = stretch_def.values_at(:split_def, :esv)
      reversed, _ = split_def.values_at(:reversed)

      # Error if max distance exceeded
      compressed = esv.valid? && (reversed ? esv.samedirection?(@picked_axis) : !esv.samedirection?(@picked_axis))
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
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # -----

    # Last measure is stored by measure type because its meaning differs :
    # overall dimension in "outside" mode - always positive, the compression is implied by the
    # comparison with the current dimension - and stretch delta in "offset" mode, where it is
    # signed : positive = expansion, negative = compression.

    def _fetch_last_stretch_measure
      @@last_stretch_measures[_fetch_option_stretch_measure_type_outside? ? :outside : :offset]
    end

    def _store_last_stretch_measure(measure, compressed = false)
      return if measure.nil? || measure == 0  # A null measure doesn't erase the stored one
      if _fetch_option_stretch_measure_type_outside?
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

    def _get_xyz_method
      { X_AXIS => :x, Y_AXIS => :y, Z_AXIS => :z }[@picked_axis]
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
      return nil if (stretch_def = _get_stretch_def(@picked_stretch_start_point, reference_point)).nil?

      split_def, factor, lps, lpe = stretch_def.values_at(:split_def, :factor, :lps, :lpe)
      et, epmin, epmax, max_compression_distance = split_def.values_at(:et, :epmin, :epmax, :max_compression_distance)

      if (v = direction).nil?
        v = lps.vector_to(lpe)
        v = _get_stretch_outward_direction unless v.valid?  # Fallback to the grip outward direction
      end
      return nil if v.nil? || !v.valid?

      pmin = epmin.transform(et)
      pmax = epmax.transform(et)

      if _fetch_option_stretch_measure_type_outside?
        real_distance = (measure - (pmax - pmin).length) / factor
        compression_distance = (real_distance * factor).abs
      else
        real_distance = measure
        compression_distance = real_distance.abs
        max_compression_distance = max_compression_distance / factor
      end

      {
        end_point: @picked_stretch_start_point.offset(v, real_distance),
        pmin: pmin,
        pmax: pmax,
        compression_distance: compression_distance,
        max_compression_distance: max_compression_distance,
      }
    end

    # -----

    # Returns the 0-based index in the active selection path of the first ancestor to make unique
    # when the edited context (the last path element's definition) is also visible through a locked
    # occurrence path, or nil if the context is safe. Occurrence paths that share the context
    # without any lock are left shared: the stretch is expected to propagate to them.
    def _locked_aliased_context_level
      path = get_active_selection_path
      return nil if !path.is_a?(Array) || path.empty?
      return nil unless (context = path.last).respond_to?(:definition)

      _instances_to_paths(context.definition.instances, (occurrence_paths = []), Sketchup.active_model.entities)

      level = nil
      occurrence_paths.each do |occurrence_path|
        next if occurrence_path == path ||
                !LockUtils.locked_path?(occurrence_path)
        divergence = 0
        divergence += 1 while divergence < occurrence_path.size && divergence < path.size && occurrence_path[divergence] == path[divergence]
        level = level.nil? ? divergence : [ level, divergence ].min
      end
      level
    end

    # Make the active selection path unique from 'level' down to its last element so that the
    # stretch edits a context that no locked occurrence can see (SketchUp locks are not enforced
    # by the Ruby API), then remap the active selection and the split_def containers to the
    # copies. make_unique preserves the entity order, so copies are retrieved by index.
    def _isolate_locked_aliased_context(level)
      path = get_active_selection_path
      instances = get_active_selection_instances

      child_positions = path.each_cons(2).map { |parent, child| parent.definition.entities.to_a.index(child) }
      instance_positions = instances.map { |instance| path.last.definition.entities.to_a.index(instance) }

      new_path = path.take(level)
      current = path[level]
      (level...path.size).each do |j|
        current.make_unique if current.definition.count_used_instances > 1
        new_path << current
        current = current.definition.entities[child_positions[j]] if j < path.size - 1
      end

      new_instances = instance_positions.map { |position| new_path.last.definition.entities[position] }

      mapping = instances.zip(new_instances).to_h
      if (split_def = _get_split_def).is_a?(Hash)
        split_def[:container_defs].each do |container_def|
          container_def.container = mapping[container_def.container] if mapping.key?(container_def.container)
        end
      end

      _set_active_selection(new_path, new_instances, true)
    end

    # -----

    def _stretch_entity
      return if (stretch_def = _get_stretch_def(@picked_stretch_start_point, @picked_stretch_end_point)).nil?

      split_def, emv, esv, edvs, lps, lpe = stretch_def.values_at(:split_def, :emv, :esv, :edvs, :lps, :lpe)
      et, eps, evpspe, reversed, section_defs, container_defs = split_def.values_at(:et, :eps, :evpspe, :reversed, :section_defs, :container_defs)

      # Keep the applied measure - and its way - to be able to reuse them on the next stretch
      compressed = esv.valid? && (reversed ? esv.samedirection?(@picked_axis) : !esv.samedirection?(@picked_axis))
      _store_last_stretch_measure(lps.distance(lpe), compressed)

      _unhide_instances

      # Prepare uniqueness data
      container_defs.first.compute_md5(@picked_axis)
      container_defs.first.compute_entity_pos

      # Divide in 2 operations to hide native make_unique group operations
      # The first operation set with "next_transparent = true"

      model = Sketchup.active_model
      model.start_operation('OCL Stretch', true, true, !active?)

        # Isolate context routine
        # -----------------------

        # If the edited context is visible through a locked occurrence path, make the selection
        # path unique first so the stretch cannot alter what the lock protects.
        unless (locked_aliased_level = _locked_aliased_context_level).nil?
          _isolate_locked_aliased_context(locked_aliased_level)
        end

        # Make Unique routine
        # -------------------

        make_unique_o = _fetch_option_options_make_unique?

        container_defs.group_by(&:definition)
                      .sort_by { |definition, container_defs| container_defs.map(&:depth).max }  # Ensure that lowest depth containers are processed first
                      .each do |definition, container_defs|

          next if definition.nil?

          count_stretched_instances = container_defs.size
          count_instances = definition.count_instances
          count_used_instances = definition.count_used_instances

          # Process extern instances
          if !make_unique_o && count_used_instances > count_stretched_instances

            # -- Extern instances exist

            # Extract definition instances
            definition_instances = definition.instances

            # Extract stretched instances
            stretched_instances = container_defs.map(&:container)

            if count_used_instances > count_instances

              active_selection_path = get_active_selection_path
              active_selection_path_size = active_selection_path.size

              # Retrieve all instance paths
              _instances_to_paths(definition_instances, (extern_instance_paths = []), model.entities)

              # Reduce to extern instances only
              extern_instance_paths.delete_if { |path|
                path.take(active_selection_path_size) == active_selection_path &&
                stretched_instances.include?(path[active_selection_path_size])
              }

              # An instance is locked if AT LEAST ONE of its paths is locked: re-pointing it to the
              # stretched definition would also alter its occurrences under locked ancestors.
              locked_extern_instances = extern_instance_paths.select { |path| LockUtils.locked_path?(path) }.map! { |path| path.last }
              unlocked_extern_instances = extern_instance_paths.map { |path| path.last }.uniq - locked_extern_instances

              make_unique_e = locked_extern_instances.any?

            else

              locked_extern_instances, unlocked_extern_instances = LockUtils.partition_locked_extern_instances(definition, stretched_instances)

              # The Ruby API does not enforce locks: without make unique, locked extern instances
              # would be silently deformed and back translated.
              make_unique_e = locked_extern_instances.any?

            end

          else

            # -- No extern instances

            make_unique_e = false

          end

          # Groups with edges must be made unique because SketchUp make them unique when transform entities and this causing troubles with the stretching.
          make_unique_g = definition.group? && (!make_unique_o || container_defs.first.edge_defs.any? && count_stretched_instances > 1)

          container_defs.sort_by { |container_def| -container_def.operation }
                        .group_by(&:md5)
                        .each do |md5, container_defs|

            make_unique_d = make_unique_o && count_stretched_instances < count_used_instances
            make_unique_c = (make_unique_e || make_unique_g || make_unique_d || container_defs.size < count_stretched_instances) && container_defs.any? { |container_def| container_def.operation == OPERATION_SPLIT }

            # puts "  make_unique_e: #{make_unique_e}"
            # puts "  make_unique_d: #{make_unique_d}"
            # puts "  make_unique_c: #{make_unique_c}"
            # puts "  #{md5}: #{container_defs.size} / #{count_stretched_instances} / #{count_used_instances} (op: #{container_defs.map(&:operation)}))"
            # container_defs.each do |container_def|
            #   puts "   ↳ C <#{definition.name}> (#{container_def.container.name}) #{container_def.entity_pos} (edeges: #{container_def.edge_defs.size})"
            #   # container_def.edge_defs.each do |edge_def|
            #   #   puts "     ↳ E #{edge_def.entity_pos}"
            #   # end
            # end

            if make_unique_c

              if definition.group?

                container_defs.each do |container_def|

                  new_container = container_def.container.make_unique
                  new_definition = new_container.definition

                  container_def.container = new_container
                  container_def.edge_defs.each do |edge_def|
                    edge_def.edge = new_definition.entities[edge_def.entity_pos]
                  end
                  container_def.cline_defs.each do |cline_def|
                    cline_def.cline = new_definition.entities[cline_def.entity_pos]
                  end
                  container_def.snap_defs.each do |snap_def|
                    snap_def.snap = new_definition.entities[snap_def.entity_pos]
                  end
                  container_def.children.each do |container_def|
                    container_def.container = new_definition.entities[container_def.entity_pos]
                  end

                end

              else

                container_def0 = container_defs.first

                new_container = container_def0.container.make_unique
                new_definition = new_container.definition

                container_def0.container = new_container

                container_defs.each do |container_def|
                  container_def.container.definition = new_definition
                  container_def.edge_defs.each do |edge_def|
                    edge_def.edge = new_definition.entities[edge_def.entity_pos]
                  end
                  container_def.cline_defs.each do |cline_def|
                    cline_def.cline = new_definition.entities[cline_def.entity_pos]
                  end
                  container_def.snap_defs.each do |snap_def|
                    snap_def.snap = new_definition.entities[snap_def.entity_pos]
                  end
                  container_def.children.each do |container_def|
                    container_def.container = new_definition.entities[container_def.entity_pos]
                  end
                end

                if make_unique_e && defined?(unlocked_extern_instances)
                  unlocked_extern_instances.each do |extern_instance|
                    extern_instance.definition = new_definition
                  end
                end

              end

              count_stretched_instances -= container_defs.size
              count_used_instances -= container_defs.size

            end

          end

        end

      model.commit_operation

      model = Sketchup.active_model
      model.start_operation('OCL Stretch', true, false, !active?)

        # Stretch routine
        # ---------------

        # Keep stretched definitions (and their instances) to avoid stretching the same definition twice
        stretched_definition_defs = {}

        # A sorting order is defined to ensure that the furthest edges are moved first
        sorting_order = (esv.valid? && esv.samedirection?(evpspe)) ? -1 : 1

        # Precompute the inverse of the active selection path transformation (invariant within the loop)
        active_selection_path_t = PathUtils.get_transformation(get_active_selection_path, IDENTITY)
        active_selection_path_ti = active_selection_path_t.inverse

        container_defs.each do |container_def|

          next if container_def.model?

          entities = container_def.entities
          container = container_def.container
          container_edv = edvs[container_def.section_def]

          # Stretch definition edges only once
          unless stretched_definition_defs.has_key?(container_def.definition)

            # Move edges
            # ----------

            container_def.edge_defs
                         .select { |edge_def| edge_def.operation == OPERATION_MOVE }
                         .group_by(&:start_section_def)
                         .sort_by { |section_def, _| section_def.index * sorting_order }.to_h # Sort edges to be sure that farthest points are moved first
                         .each do |section_def, edge_defs|

              edv = edvs[section_def]

              edge_def0 = edge_defs.first
              t = edge_def0.transformation

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == section_def && edv.valid?

              target_position0 = edge_def0.ref_position
              target_position0 = target_position0.offset(edv.transform(t.inverse)) if edv.valid?
              current_position0 = edge_def0.edge.start.position

              v = current_position0.vector_to(target_position0)

              entities.transform_entities(Geom::Transformation.translation(v), edge_defs.map(&:edge)) if v.valid?

            end

            # Move clines
            # -----------

            container_def.cline_defs
                         .each do |cline_def|

              t = cline_def.transformation

              # Compute Start point

              edv = edvs[cline_def.start_section_def]

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == cline_def.start_section_def && edv.valid?

              target_start = cline_def.ref_start_position
              target_start = target_start.offset(edv.transform(t.inverse)) if edv.valid?

              # Compute End point

              edv = edvs[cline_def.end_section_def]

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == cline_def.end_section_def && edv.valid?

              target_end = cline_def.ref_end_position
              target_end = target_end.offset(edv.transform(t.inverse)) if edv.valid?

              # Apply

              cline_def.cline.direction = target_start.vector_to(target_end)
              cline_def.cline.position = cline_def.cline.start = target_start
              cline_def.cline.end = target_end

            end

            # Move snaps
            # ----------

            container_def.snap_defs
                         .select { |snap_def| snap_def.operation == OPERATION_MOVE }
                         .group_by(&:section_def)
                         .each do |section_def, snap_defs|

              edv = edvs[section_def]

              snap_def0 = snap_defs.first
              t = snap_def0.transformation

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == section_def && edv.valid?

              target_position0 = snap_def0.ref_position
              target_position0 = target_position0.offset(edv.transform(t.inverse)) if edv.valid?
              current_position0 = snap_def0.snap.position

              v = current_position0.vector_to(target_position0)

              entities.transform_entities(Geom::Transformation.translation(v), snap_defs.map(&:snap)) if v.valid?

            end

            # Flag definition as stretched + keep edv converted to definition space
            ddv = container_edv
            unless ddv.nil?
              ddv += emv if container_def.depth <= 1 && get_active_selection_instances.include?(container_def.container) # Apply "move" translation (if the centered option is enabled)
              if container_def.depth > 0
                ddv = ddv.transform((container_def.transformation * container_def.container_transformation).inverse)
              else
                # Root container: unlike children, its SplitContainerDef transformation is 'et' (edit -> world),
                # not a local -> edit map. The edit -> definition conversion must be composed from the live
                # path transformations: (path * container).inverse * et. Do NOT use 'det' here: the drawing_def
                # root transformation is orthonormalized by the decomposition worker (mirror stripped), so 'det'
                # carries a stray reflection for mirrored instances, while this composition stays consistent
                # with the edge moves whatever the rotation or mirror of the instance and its path.
                ddv = ddv.transform((active_selection_path_t * container_def.container_transformation).inverse * et)
              end
            end
            stretched_definition_defs[container_def.definition] = StretchedDefinitionDef.new(ddv)

          end

          # Keep stretched container def, if not make unique to be able to back transform extern instances
          stretched_definition_defs[container_def.definition].containers << container_def.container if !make_unique_o && container_def.component? && container_def.operation == OPERATION_SPLIT

          # Move container
          # --------------

          next if container_def.operation == OPERATION_NONE ||
                  container_def.section_def.nil?

          edv = container_edv

          # Subtract parent container move
          unless container_def.parent.nil? || container_def.parent.section_def.nil?
            edv -= edvs[container_def.parent.section_def]
            edv.reverse! if container_def.parent.section_def == container_def.section_def && edv.valid?
          end

          # Apply move translation (if the centered option is enabled)
          edv += emv if container_def.depth <= 1 && get_active_selection_instances.include?(container_def.container)

          target_position = container_def.ref_position
          target_position = target_position.offset(edv.transform(if container_def.depth == 0
                                                                   active_selection_path_ti * container_def.transformation
                                                                 else
                                                                   container_def.transformation.inverse
                                                                 end)) if edv.valid?
          current_position = ORIGIN.transform(container.transformation)

          v = current_position.vector_to(target_position)

          if container.respond_to?(:glued_to) && container.glued_to
            # Deforming the host face of a glued instance makes SketchUp rewrite its
            # transformation in place to strip any mirror (det < 0). Re-impose the full
            # reference transformation at the target position, even when v is zero.
            container.transformation = Geom::Transformation.translation(container_def.ref_position.vector_to(target_position)) * container_def.ref_transformation
          else
            container.transform!(Geom::Transformation.translation(v)) if v.valid?
          end

        end

        # Apply back translation on extern instances if needed
        unless make_unique_o

          stretched_definition_defs.each do |definition, stretched_definition_def|

            if stretched_definition_def.containers.any?
              extern_instances = definition.instances - stretched_definition_def.containers
              if extern_instances.any?

                extern_instances.each do |extern_instance|

                  t = extern_instance.transformation

                  ref_position = @extern_instances_ref_positions[extern_instance] ||= ORIGIN.transform(t)

                  # puts "stretched_definition_def.ddv = #{stretched_definition_def.ddv}"

                  target_position = ref_position
                  target_position = target_position.offset(stretched_definition_def.ddv.transform(t)) if !stretched_definition_def.ddv.nil? && stretched_definition_def.ddv.valid?
                  current_position = ORIGIN.transform(t)

                  # k_edge = Kuix::EdgeMotif3d.new
                  # k_edge.start.copy!(current_position)
                  # k_edge.end.copy!(target_position)
                  # k_edge.color = Kuix::COLOR_CYAN
                  # k_edge.line_width = 2
                  # k_edge.end_arrow = true
                  # k_edge.on_top = true
                  # @tool.append_3d(k_edge, 100)
                  #
                  # k_edge = Kuix::EdgeMotif3d.new
                  # k_edge.start.copy!(current_position)
                  # k_edge.end.copy!(current_position.offset(stretched_definition_def.ddv))
                  # k_edge.color = Kuix::COLOR_MAGENTA
                  # k_edge.line_width = 2
                  # k_edge.end_arrow = true
                  # k_edge.on_top = true
                  # @tool.append_3d(k_edge, 100)

                  v = current_position.vector_to(target_position)

                  extern_instance.transform!(Geom::Transformation.translation(v)) if v.valid?

                end

              end
            end

          end

        end

        # Adjust cutters
        eti = et.inverse
        epo = reversed ? lpe.transform(eti) : eps.offset(emv)
        epomax = reversed ? eps.offset(emv) : lpe.transform(eti)
        distance = epo.distance(epomax)
        el = [ epo, evpspe ]
        sd = section_defs
        sd = sd.reverse if reversed
        @cutters[@picked_axis] = sd
           .select { |section_def| section_def.bounds.valid? } # Exclude empty sections
           .each_cons(2).map { |section_def0, section_def1|
              max0 = section_def0.bounds.max.project_to_line(el).offset!(edvs[section_def0] + emv)
              min1 = section_def1.bounds.min.project_to_line(el).offset!(edvs[section_def1] + emv)
              if (v = max0.vector_to(min1)).valid? && v.samedirection?(@picked_axis)  # Exclude if bounds overlap
                epc = Geom.linear_combination(0.5, max0, 0.5, min1)
                epo.vector_to(epc).length / distance
              end
            }
           .compact
        _store_cutters
        _load_cutters

      model.commit_operation

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

    def _get_split_def
      return @split_def unless @split_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return nil if @picked_grip_index.nil?

      et = _get_edit_transformation
      eb = _get_drawing_def_edit_bounds(drawing_def, et)
      keb = Kuix::Bounds3d.new.copy!(eb)

      det = drawing_def.transformation.inverse * et
      deti = det.inverse

      # Compute a new drawing_def that include all content
      return nil unless (drawing_def = CommonDrawingDecompositionWorker.new(_get_drawing_def_ipaths, **(_get_drawing_def_parameters.merge(
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL,
        ignore_snaps: false,
        flatten: false,
      ))).run).is_a?(DrawingDef)

      # Transform drawing_def to be expressed in the edit space
      drawing_def.transform!(det)

      grip_index_s = Kuix::Bounds3d.face_opposite(@picked_grip_index)
      grip_index_e = @picked_grip_index

      eps = keb.face_center(grip_index_s).to_p
      epe = keb.face_center(grip_index_e).to_p
      evpspe = eps.vector_to(epe)

      reversed = evpspe.valid? && !evpspe.samedirection?(@picked_axis)

      epmin = reversed ? epe : eps
      epmax = reversed ? eps : epe

      container_defs = []

      v_s = {}  # Vertex => DrawingContainerDef => SectionDef

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
        (v_s[vertex] ||= {})[drawing_container_def] = section_def
      }
      fn_fetch_vertex_section_def = lambda { |vertex, drawing_container_def|
        (v_s[vertex] ||= {})[drawing_container_def]
      }

      fn_analyse = lambda do |drawing_container_def, parent_section_def = nil, depth = 0|

        # Extract container
        # -----------------

        # k_box = Kuix::BoxMotif3d.new
        # k_box.bounds.copy!(drawing_container_def.bounds)
        # k_box.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        # k_box.line_width = 2
        # k_box.color = [ Kuix::COLOR_RED, Kuix::COLOR_GREEN, Kuix::COLOR_BLUE, Kuix::COLOR_MAGENTA ][depth % 4]
        # k_box.transformation = et
        # @tool.append_3d(k_box, LAYER_3D_PART_PREVIEW)

        section_def = parent_section_def
        if section_def.nil?

          if drawing_container_def.is_root? && !get_active_selection_instances.one?

            # No section_def if the root container is just the instance holder

            operation = OPERATION_SPLIT

          # Check if the container is locked. Locked containers are never deformed (no SPLIT),
          # but they are translated with the section containing their origin: the lock protects
          # the container's shape, not its position within the stretched assembly.
          elsif LockUtils.locked?(drawing_container_def.container)

            container_origin = ORIGIN.transform(drawing_container_def.transformation * drawing_container_def.container.transformation)
            section_def = section_defs.find { |section_def| section_def.contains_point?(container_origin, xyz_method) }

            # Add the container bounds to the section bounds so the locked container is taken into
            # account by the max compression distance. If it straddles a cutter, the section
            # oversize check rejects the cutter layout instead of silently translating it.
            section_def.bounds.add(drawing_container_def.bounds) if !section_def.nil? && drawing_container_def.bounds.valid?

            operation = OPERATION_MOVE

          # Check if the container is glued or always face camera to search the section according to its origin only
          elsif drawing_container_def.container.respond_to?(:glued_to) && drawing_container_def.container.glued_to ||
                drawing_container_def.container.respond_to?(:definition) && (drawing_container_def.container.definition.behavior.always_face_camera? || drawing_container_def.container.definition.behavior.no_scale_mask? == 0b1111111)   # 0b1111111 = 127 (all disabld)

            container_origin = ORIGIN.transform(drawing_container_def.transformation * drawing_container_def.container.transformation)
            section_def = section_defs.find { |section_def| section_def.contains_point?(container_origin, xyz_method) }

            # Container bounds are not considered in this case

            operation = OPERATION_MOVE

          else

            # Check if container bounds is entirely inside a section
            section_def = section_defs.find { |section_def| section_def.contains_bounds?(drawing_container_def.bounds, xyz_method) }
            if section_def.nil?

              container_origin = ORIGIN.transform(drawing_container_def.is_root? ? deti : drawing_container_def.transformation * drawing_container_def.container.transformation)
              min_max = [ drawing_container_def.bounds.min, drawing_container_def.bounds.max ].min_by { |point| (point.send(xyz_method) - container_origin.send(xyz_method)).abs }

              # Default container section_def is where the bounds extreme is the nearest origin
              section_def = section_defs.find { |section_def| section_def.contains_point?(min_max, xyz_method) }

              operation = OPERATION_SPLIT


              # color = [ Kuix::COLOR_RED, Kuix::COLOR_GREEN, Kuix::COLOR_BLUE, Kuix::COLOR_MAGENTA ][depth % 4]
              #
              # k_box = Kuix::BoxMotif3d.new
              # k_box.bounds.copy!(drawing_container_def.bounds)
              # k_box.color = color
              # k_box.transformation = det
              # @tool.append_3d(k_box, LAYER_3D_PART_PREVIEW)
              #
              # k_points = _create_floating_points(
              #   points: container_origin,
              #   fill_color: color,
              #   size: [ 6, 4, 2, 1 ][depth % 4]
              # )
              # k_points.transformation = det
              # @tool.append_3d(k_points, LAYER_3D_PART_PREVIEW)


            else

              # Add the container bounds to the section bounds
              section_def.bounds.add(drawing_container_def.bounds)

              operation = OPERATION_MOVE

            end

          end

        else
          operation = OPERATION_NONE
        end

        container_def = SplitContainerDef.new(
          drawing_container_def.container,
          drawing_container_def.transformation,
          depth,
          drawing_container_def.container.respond_to?(:transformation) ? drawing_container_def.container.transformation : nil,
          section_def,
          operation
        )
        container_defs << container_def

        # Keep container section as entire parent section
        parent_section_def = section_def unless operation == OPERATION_SPLIT

        # k_box = Kuix::BoxMotif3d.new
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
          section_def ||= fn_fetch_vertex_section_def.call(cm.curve.first_edge.start, drawing_container_def)
          section_def ||= fn_fetch_vertex_section_def.call(cm.curve.last_edge.end, drawing_container_def)
          section_def ||= section_defs.find { |s| s.intersects_bounds?(cm.bounds, xyz_method) }
          unless section_def.nil?
            cm.curve.edges.each do |edge|
              container_def.edge_defs << SplitEdgeDef.new(
                edge,
                cm.transformation,
                edge.start.position,
                section_def,
                section_def,
                if operation == OPERATION_SPLIT
                  OPERATION_MOVE
                else
                  OPERATION_NONE
                end
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
            if operation == OPERATION_SPLIT
              start_section_def == end_section_def ? OPERATION_MOVE : OPERATION_SPLIT
            else
              OPERATION_NONE
            end
          )

          if parent_section_def.nil? &&
             start_section_def == end_section_def &&
             em.edge.start.edges.all? { |edge| edge.curve.nil? } && em.edge.end.edges.all? { |edge| edge.curve.nil? }
            start_section_def.bounds.add(em.points)  # Add to content bbox
          end

        end

        # 3. Iterate on finite clines

        drawing_container_def.cline_manipulators.each do |cm|

          next if cm.infinite?

          if parent_section_def.nil?
            start_section_def = section_defs.find { |s| s.contains_point?(cm.start_point, xyz_method) }
            end_section_def = section_defs.find { |s| s.contains_point?(cm.end_point, xyz_method) }
          else
            start_section_def = end_section_def = parent_section_def
          end

          container_def.cline_defs << SplitClineDef.new(
            cm.cline,
            cm.transformation,
            cm.cline.start,
            cm.cline.end,
            start_section_def,
            end_section_def,
            if operation == OPERATION_SPLIT
              start_section_def == end_section_def ? OPERATION_MOVE : OPERATION_SPLIT
            else
              OPERATION_NONE
            end
          )

          if parent_section_def.nil? &&
             start_section_def == end_section_def
            start_section_def.bounds.add(cm.points)  # Add to content bbox
          end

        end

        # 4. Iterate on snaps

        drawing_container_def.snap_manipulators.each do |sm|

          if parent_section_def.nil?
            section_def = section_defs.find { |s| s.contains_point?(sm.position, xyz_method) }
          else
            section_def = parent_section_def
          end

          next if section_def.nil?  # TODO : this should not occur

          container_def.snap_defs << SplitSnapDef.new(
            sm.snap,
            sm.transformation,
            sm.snap.position,
            section_def,
            if operation == OPERATION_SPLIT
              OPERATION_MOVE
            else
              OPERATION_NONE
            end
          )

          if parent_section_def.nil?
            section_def.bounds.add(sm.position)  # Add to content bbox
          end

        end

        # 5. Iterate over children

        depth += 1
        drawing_container_def.container_defs.each do |child_drawing_container_def|
          child = fn_analyse.call(child_drawing_container_def, parent_section_def, depth)
          child.parent = container_def
          container_def.children << child
        end

        container_def
      end

      fn_analyse.call(drawing_def)

      # Compute max compression distance
      el = [ eps, evpspe ]
      sd = section_defs
      sd = sd.reverse if reversed
      vsd = sd.select { |section_def| section_def.bounds.valid? && !section_def.bounds.empty? }
      if vsd.one?
        # TODO : Improve this case where there's only one section
        drawing_size = drawing_def.bounds.min.project_to_line(el).transform(et).distance(drawing_def.bounds.max.project_to_line(el).transform(et))
        section_size = vsd.first.bounds.min.project_to_line(el).transform(et).distance(vsd.first.bounds.max.project_to_line(el).transform(et))
        min_distance = drawing_size - section_size
      else
        min_distance = vsd
          .each_cons(2).map { |section_def0, section_def1|
            section_def0.bounds.max.project_to_line(el).transform(et).distance(section_def1.bounds.min.project_to_line(el).transform(et))
          }
          .min
        min_distance = 0 if min_distance.nil?
      end
      max_compression_distance = [ (min_distance * (vsd.size - 1)) - 1.mm, 0 ].max # Keep 1mm to avoid geometry merge problems

      @split_def = {
        drawing_def: drawing_def,
        et: et,
        det: det,
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

    def _get_stretch_def(ps, pe)
      return nil unless ps.is_a?(Geom::Point3d) && pe.is_a?(Geom::Point3d)
      return nil unless (split_def = _get_split_def).is_a?(Hash)

      et, eps, max_compression_distance, section_defs, reversed = split_def.values_at(:et, :eps, :max_compression_distance, :section_defs, :reversed)
      eti = et.inverse

      v = ps.vector_to(pe)     # "Move" vector in global space
      ev = v.transform(eti)

      factor = _fetch_option_options_centered? ? 2.0 : 1.0

      # Limit move to max compression distance
      compressed = ev.valid? && (reversed ? ev.samedirection?(@picked_axis) : !ev.samedirection?(@picked_axis))
      if compressed && (v.length * factor > max_compression_distance)
        pe = ps.offset(v, max_compression_distance / factor)
        v = ps.vector_to(pe)
      end

      if factor > 1.0
        mv = v.reverse
        sv = v
        sv.length *= factor if sv.valid?
      else
        mv = Geom::Vector3d.new
        sv = v
      end

      emv = mv.transform(eti)   # "Move" vector in edit space
      esv = sv.transform(eti)   # "Stretch" vector in edit space

      # Compute move vectors for each section
      edvs = section_defs.map { |section_def|
        edv = Geom::Vector3d.new(esv)
        edv.length = edv.length * section_def.index / (section_defs.length - 1) if esv.valid? && section_defs.length > 1
        [ section_def, edv ]
      }.to_h

      lps = _fetch_option_stretch_measure_type_outside? ? eps.transform(et).offset(mv) : ps
      lpe = pe

      {
        split_def: split_def,
        factor: factor,
        emv: emv,
        esv: esv,
        edvs: edvs,
        lps: lps,
        lpe: lpe,
      }
    end

    # -----

    SplitSectionDef = Struct.new(
      :index,
      :min_xyz,
      :max_xyz,
      :bounds
    ) do

      def contains_point?(point, xyz_method)
        min_xyz <= point.send(xyz_method) && max_xyz >= point.send(xyz_method)
      end

      def contains_bounds?(bounds, xyz_method)
        min_xyz <= bounds.min.send(xyz_method) && max_xyz >= bounds.max.send(xyz_method)
      end

      def intersects_bounds?(bounds, xyz_method)
        min_xyz <= bounds.max.send(xyz_method) && max_xyz >= bounds.min.send(xyz_method)
      end

    end

    SplitContainerDef = Struct.new(
      :container,
      :transformation,
      :depth,
      :ref_transformation,
      :section_def,
      :operation,
      :entity_pos,
      :edge_defs,
      :cline_defs,
      :snap_defs,
      :parent,
      :children,
    ) do

      def initialize(
        container,
        transformation,
        depth,
        ref_transformation,
        section_def,
        operation,
        entity_pos = -1,
        edge_defs = [],
        cline_defs = [],
        snap_defs = [],
        parent = nil,
        children = []
      )
        super
        @md5 = nil
      end

      def definition
        return container.definition if container.respond_to?(:definition)
        nil
      end

      def entities
        return container.entities if container.respond_to?(:entities)
        return definition.entities unless definition.nil?
        nil
      end

      def group?
        unless (definition = self.definition).nil?
          return definition.group?
        end
        false
      end

      def component?
        unless (definition = self.definition).nil?
          return !definition.group?
        end
        false
      end

      def model?
        container.is_a?(Sketchup::Model)
      end

      def ref_position
        return nil if ref_transformation.nil?
        ORIGIN.transform(ref_transformation)
      end

      def container_transformation
        return container.transformation if container.respond_to?(:transformation)
        IDENTITY
      end

      def md5
        @md5
      end

      def compute_md5(axis)
        @md5 ||= begin
          data = []
          data << container.definition.persistent_id if container.respond_to?(:definition)

          unless parent.nil?
            if (local_axis = axis.transform((transformation * container.transformation).inverse)).valid?
              data << (local_axis.angle_between(axis) % Math::PI).round(6) # Differentiating rotations but not perfect aligned mirrors
              data << local_axis.length.to_f.round(6) if operation == OPERATION_SPLIT  # Differentiating scaling
            end
          end

          if operation == OPERATION_SPLIT
            data << edge_defs.map { |edge_def|
              [
                edge_def.edge.persistent_id,
                (section_def.index - edge_def.start_section_def.index).abs, # Use "delta" to be able to unify flipped elements
                (section_def.index - edge_def.end_section_def.index).abs
              ]
            } if edge_defs.any?
            data << cline_defs.map { |cline_def|
              [
                cline_def.cline.persistent_id,
                (section_def.index - cline_def.start_section_def.index).abs, # Use "delta" to be able to unify flipped elements
                (section_def.index - cline_def.end_section_def.index).abs
              ]
            } if cline_defs.any?
            data << snap_defs.map { |snap_def|
              [
                snap_def.snap.persistent_id,
                (section_def.index - snap_def.section_def.index).abs, # Use "delta" to be able to unify flipped elements
              ]
            } if snap_defs.any?
          end

          # Children md5 alone carries no positional info. Under a SPLIT container, each child is translated
          # according to its own section, so two instances whose children fall in sections with different
          # "deltas" (relative to the container's anchor section) deform differently and must not share
          # their definition. This can't be caught by the edge deltas above when the container has no
          # direct edges (e.g. a component made only of sub-components).
          data << children.map { |container_def|
            [
              container_def.compute_md5(axis),
              if operation == OPERATION_SPLIT && !section_def.nil? && !container_def.section_def.nil?
                (section_def.index - container_def.section_def.index).abs # Use "delta" to be able to unify flipped elements
              end
            ]
          }

          Digest::MD5.hexdigest(Marshal.dump(data))
        end
      end

      def compute_entity_pos
        return if (entities = self.entities).nil?
        entity_positions = entities.each_with_index.to_h { |entity, index| [ entity, index ] }
        edge_defs.each do |edge_def|
          edge_def.entity_pos = entity_positions[edge_def.edge]
        end
        cline_defs.each do |cline_def|
          cline_def.entity_pos = entity_positions[cline_def.cline]
        end
        snap_defs.each do |snap_def|
          snap_def.entity_pos = entity_positions[snap_def.snap]
        end
        children.each do |container_def|
          container_def.entity_pos = entity_positions[container_def.container]
          container_def.compute_entity_pos
        end
      end

    end

    SplitEdgeDef = Struct.new(
      :edge,
      :transformation,
      :ref_position,
      :start_section_def,
      :end_section_def,
      :operation,
      :entity_pos
    ) do

      def initialize(
        edge,
        transformation,
        ref_position,
        start_section_def,
        end_section_def,
        operation,
        entity_pos = -1
      )
        super
      end

      def transformation_inverse
        @transformation_inverse ||= transformation.inverse
      end

    end

    SplitClineDef = Struct.new(
      :cline,
      :transformation,
      :ref_start_position,
      :ref_end_position,
      :start_section_def,
      :end_section_def,
      :operation,
      :entity_pos
    ) do

      def initialize(
        cline,
        transformation,
        ref_start_position,
        ref_end_position,
        start_section_def,
        end_section_def,
        operation,
        entity_pos = -1
      )
        super
      end

      def transformation_inverse
        @transformation_inverse ||= transformation.inverse
      end

    end

    SplitSnapDef = Struct.new(
      :snap,
      :transformation,
      :ref_position,
      :section_def,
      :operation,
      :entity_pos
    ) do

      def initialize(
        snap,
        transformation,
        ref_position,
        section_def,
        operation,
        entity_pos = -1
      )
        super
      end

      def transformation_inverse
        @transformation_inverse ||= transformation.inverse
      end

    end

    StretchedDefinitionDef = Struct.new(
      :ddv,
      :containers
    ) do

      def initialize(
        ddv,
        containers = []
      )
        super
      end

    end

  end

  class SmartReshapeSolidActionHandler < SmartActionHandler

    include SmartActionHandlerPartHelper

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

    def _get_drawing_def_parameters
      {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: true,
        ignore_soft_edges: true,
        ignore_clines: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS,
        flatten: false
      }
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

        # Apply boolean operations
        result_def = CommonSolidBooleanApplyWorker.new(
          @src_selection.items.map(&:drawing_def),
          @cut_selection.items.map(&:drawing_def),
          operation: operation,
          keep_srcs: _fetch_option_options_keep_a?,
          keep_cuts: _fetch_option_options_keep_b?,
          make_unique: _fetch_option_options_make_unique?,
          wrap_operation: false
        ).run
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
      @tool.remove_tooltip
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
      @tool.show_tooltip(PLUGIN.get_i18n_string(@refused_error[0], @refused_error[1]), SmartTool::MESSAGE_TYPE_ERROR)
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
      Sketchup.set_status_text('', SB_VCB_VALUE)
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