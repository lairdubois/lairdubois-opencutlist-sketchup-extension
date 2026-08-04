module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative 'smart_handle_tool'
  require_relative '../lib/geometrix/finder/circle_finder'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../lib/fiddle/meshy/meshy'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'
  require_relative '../manipulator/cline_manipulator'
  require_relative '../helper/user_text_helper'
  require_relative '../helper/part_helper'
  require_relative '../helper/face_matcher_helper'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/solid/solid_mesh_def'
  require_relative '../model/solid/solid_boolean_result_def'
  require_relative '../utils/path_utils'
  require_relative '../utils/drawingelement_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_solid_find_cavities_worker'

  class SmartDrawTool < SmartTool

    ACTION_DRAW_RECTANGLE = 0
    ACTION_DRAW_CIRCLE = 1
    ACTION_DRAW_POLYGON = 2
    ACTION_DRAW_DIVIDER = 3

    ACTION_OPTION_OFFSET = 'offset'
    ACTION_OPTION_SEGMENTS = 'segments'
    ACTION_OPTION_THICKNESS = 'thickness'
    ACTION_OPTION_MEASURE_TYPE = 'measure_type'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_OFFSET_SHAPE_OFFSET = 'shape_offset'

    ACTION_OPTION_SEGMENTS_SEGMENT_COUNT = 'segment_count'

    ACTION_OPTION_THICKNESS_THICKNESS = 'thickness'

    ACTION_OPTION_MEASURE_TYPE_INSIDE = 'inside'
    ACTION_OPTION_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_MEASURE_TYPE_OUTSIDE = 'outside'

    ACTION_OPTION_AXES_ACTIVE = 'active'
    ACTION_OPTION_AXES_CONTEXT = 'context'

    ACTION_OPTION_OPTIONS_CONSTRUCTION = 'construction'
    ACTION_OPTION_OPTIONS_DRAW_IN = 'draw_in'
    ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED = 'rectangle_centered'
    ACTION_OPTION_OPTIONS_SMOOTHING = 'smoothing'
    ACTION_OPTION_OPTIONS_MEASURE_FROM_VERTEX = 'measure_from_vertex'
    ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER = 'measure_from_diameter'
    ACTION_OPTION_OPTIONS_MEASURE_REVERSED = 'measure_reversed'
    ACTION_OPTION_OPTIONS_PULL_CENTRED = 'pull_centered'
    ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE = 'reduce_envelope'
    ACTION_OPTION_OPTIONS_REUSE_DEFINITION = 'reuse_definition'
    ACTION_OPTION_OPTIONS_ASK_NAME = 'ask_name'

    ACTIONS = [
      {
        :action => ACTION_DRAW_RECTANGLE,
        :options => {
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_DRAW_IN, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, ACTION_OPTION_OPTIONS_PULL_CENTRED, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      },
      {
        :action => ACTION_DRAW_CIRCLE,
        :options => {
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_SEGMENTS => [ ACTION_OPTION_SEGMENTS_SEGMENT_COUNT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_DRAW_IN, ACTION_OPTION_OPTIONS_SMOOTHING, ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER, ACTION_OPTION_OPTIONS_PULL_CENTRED, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      },
      {
        :action => ACTION_DRAW_POLYGON,
        :options => {
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_DRAW_IN, ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_PULL_CENTRED, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      },
      {
        :action => ACTION_DRAW_DIVIDER,
        :options => {
          ACTION_OPTION_MEASURE_TYPE => [ ACTION_OPTION_MEASURE_TYPE_INSIDE, ACTION_OPTION_MEASURE_TYPE_CENTERED, ACTION_OPTION_MEASURE_TYPE_OUTSIDE ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      }
    ]

    # -----

    def initialize(

                   current_action: nil

    )

      super(
        current_action: current_action
      )

    end

    def get_stripped_name
      'draw'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_DRAW_RECTANGLE
          return SmartCursorManager.cursor_pencil_rectangle
      when ACTION_DRAW_CIRCLE
          return SmartCursorManager.cursor_pencil_circle
      when ACTION_DRAW_POLYGON
          return SmartCursorManager.cursor_pencil_polygon
      when ACTION_DRAW_DIVIDER
          return SmartCursorManager.cursor_pencil_divider
      end

      super
    end

    def get_action_options_modal?(action)
      action != ACTION_DRAW_DIVIDER
    end

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET
          return [ ACTION_DRAW_RECTANGLE, ACTION_DRAW_CIRCLE, ACTION_DRAW_POLYGON ]
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_ASK_NAME
          return [ACTION_DRAW_RECTANGLE, ACTION_DRAW_CIRCLE, ACTION_DRAW_POLYGON, ACTION_DRAW_DIVIDER ]
        when ACTION_OPTION_OPTIONS_DRAW_IN
          return [ ACTION_DRAW_RECTANGLE, ACTION_DRAW_CIRCLE, ACTION_DRAW_POLYGON ]
        end
      end

      super
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET
          return false
        end
      when ACTION_OPTION_SEGMENTS
        case option
        when ACTION_OPTION_SEGMENTS_SEGMENT_COUNT
          return false
        end
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
      when ACTION_OPTION_MEASURE_TYPE
        return true
      when ACTION_OPTION_AXES
        return true
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_SEGMENTS
        case option
        when ACTION_OPTION_SEGMENTS_SEGMENT_COUNT
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_THICKNESS
        case option
        when ACTION_OPTION_THICKNESS_THICKNESS
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_MEASURE_TYPE
        case option
        when ACTION_OPTION_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917M0,0.25L1,0.25M0,0.083L0,0.417M1,0.083L1,0.417'))
        when ACTION_OPTION_MEASURE_TYPE_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917M0,0.25L0.833,0.25M0,0.083L0,0.417M0.833,0.083L0.833,0.417'))
        when ACTION_OPTION_MEASURE_TYPE_INSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917M0,0.25L0.667,0.25M0,0.083L0,0.417M0.667,0.083L0.667,0.417'))
        end
      when ACTION_OPTION_AXES
        case option
        when ACTION_OPTION_AXES_ACTIVE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,0.833L1,0.833 M0,0.167L0.167,0L0.333,0.167 M0.833,0.667L1,0.833L0.833,1'))
        when ACTION_OPTION_AXES_CONTEXT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,0.833L1,0.833 M0,0.167L0.167,0L0.333,0.167 M0.833,0.667L1,0.833L0.833,1 M0.5,0.083L0.5,0.5L0.917,0.5L0.917,0.083L0.5,0.083'))
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_CONSTRUCTION
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,1L0,1L0,0.833 M0,0.667L0,0.333 M0,0.167L0,0L0.167,0 M0.333,0L0.667,0 M0.833,0L1,0L1,0.167 M1,0.333L1,0.667 M1,0.833L1,1L0.833,1 M0.333,1L0.667,1'))
        when ACTION_OPTION_OPTIONS_DRAW_IN
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L0.25,0L0,0L0,0.25 M1,0L1,0.25L1,0L0.75,0 M0,1L0.25,1L0,1L0,0.75 M1,1L1,0.75L1,1L0.75,1 M0.583,0.417L0.25,0.417L0.25,0.75L0.583,0.75L0.583,0.417 M0.583,0.583L0.75,0.583L0.75,0.25L0.417,0.25L0.417,0.417'))
        when ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L1,0L1,1L0,1L0,0 M0.5,0.667L0.5,0.333 M0.333,0.5L0.667,0.5'))
        when ACTION_OPTION_OPTIONS_SMOOTHING
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0.719L0.97,0.548L0.883,0.398L0.75,0.286L0.587,0.227L0.413,0.227L0.25,0.286L0.117,0.398L0.03,0.548L0,0.719'))
        when ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0,0.667L1,0.667L1,1L0,1 M0.25,0.667L0.25,0.833 M0.5,0.667L0.5,0.833 M0.75,0.667L0.75,0.833 M0.25,0.5L0.75,0 M0.25,0.25L0.323,0.427L0.5,0.5L0.677,0.427L0.75,0.25L0.677,0.073L0.5,0L0.323,0.073L0.25,0.25'))
        when ACTION_OPTION_OPTIONS_MEASURE_REVERSED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0,0.667L1,0.667L1,1L0,1 M0.25,0.667L0.25,0.833 M0.5,0.667L0.5,0.833 M0.75,0.667L0.75,0.833  M0.861,0.292L0.708,0.139L0.5,0.083L0.292,0.139L0.14,0.292 M0.14,0.083L0.14,0.292L0.333,0.292'))
        when ACTION_OPTION_OPTIONS_PULL_CENTRED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0.667,1L1,0.667L1,0L0.333,0L0,0.333L0,1 M0,0.333L0.667,0.333L0.667,1 M0.667,0.333L1,0 M0.333,0.5L0.333,0.833 M0.167,0.667L0.5,0.667'))
        when ACTION_OPTION_OPTIONS_ASK_NAME
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.25L1,0.25L1,0.75L0,0.75L0,0.25 M0.438,0.313L0.438,0.688 M0.125,0.625L0.125,0.375L0.313,0.625L0.313,0.375'))
        when ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L0,1L1,1L1,0L0,0 M0,0.625L0.625,0.625L0.625,0.375L0,0.375'))
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.333L0.667,0.333L0.667,1L0,1L0,0.333 M0.333,0.333L0.333,0L1,0L1,0.667L0.667,0.667'))
        end
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      view.model.selection.clear

    end

    def onActionChanged(action)

      case action
      when ACTION_DRAW_RECTANGLE
        set_action_handler(SmartDrawRectangleActionHandler.new(self))
      when ACTION_DRAW_CIRCLE
        set_action_handler(SmartDrawCircleActionHandler.new(self))
      when ACTION_DRAW_POLYGON
        set_action_handler(SmartDrawPolygonActionHandler.new(self))
      when ACTION_DRAW_DIVIDER
        set_action_handler(SmartDrawDividerActionHandler.new(self))
      end

      super
    end

    def onViewChanged(view)
      super
      refresh
    end

  end

  # -----

  class SmartDrawActionHandler < SmartActionHandler

    include UserTextHelper

    # -----

    def stop
      @tool.clear_all_3d
      @tool.clear_all_2d
      super
    end

    # -----

    def onToolKeyDown(tool, key, repeat, flags, view)

      if key <= 128
        key_char = key.chr
        if key_char == 'X' && @tool.is_key_shift_down?
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_CONSTRUCTION, !_fetch_option_construction?, fire_event: true)
          _refresh
          return true
        end
      end

      false
    end

    def onToolTransactionUndo(tool, model)
      _refresh
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    def _fetch_option_construction?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_CONSTRUCTION)
    end

    def _fetch_option_draw_in?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_DRAW_IN)
    end

    def _fetch_option_ask_name?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_ASK_NAME)
    end

    # -----

    # Orients the newly built +definition+'s own axes on its own geometry :
    # Z on the normal of its largest face, X on the longest edge lying in
    # that face (perpendicular to the normal) - so the part's axes read as
    # "front/thickness" instead of whatever axes the pick happened to leave
    # it in. Returns a transformation to apply to the definition's content
    # (see callers), or IDENTITY when there is no face to orient on.
    def _get_auto_orient_transformation(definition, transformation = IDENTITY)

      # Sum areas of all faces that are "parallel"
      a_defs = {}
      definition.entities.each do |entity|
        next unless entity.is_a?(Sketchup::Face)
        normal = entity.normal
        key = a_defs.keys.find { |k| k.parallel?(normal) }
        if (a_def = a_defs[key]).nil?
          a_def = { :area => 0, :face => entity }
          a_defs[normal] = a_def
        end
        a_def[:area] += entity.area(transformation)
      end
      max_a_def = a_defs.values.max_by { |a_def| a_def[:area] }
      unless max_a_def.nil?

        face = max_a_def[:face]
        normal = face.normal

        # Sum lengths of all edges that are "parallel"
        l_defs = {}
        definition.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Edge)
          _, direction = entity.line
          next unless direction.valid?
          next unless direction.perpendicular?(normal)
          key = l_defs.keys.find { |k| k.parallel?(direction) }
          if (l_def = l_defs[key]).nil?
            l_def = { :length => 0, :edge => entity }
            l_defs[direction] = l_def
          end
          l_def[:length] += entity.length(transformation)
        end
        max_l_def = l_defs.values.max_by { |l_def| l_def[:length] }
        unless max_l_def.nil?

          edge = max_l_def[:edge]
          _, direction = edge.line

          z_axis = normal.reverse  # Reverse the normal by presuming it points into the solid
          x_axis = direction
          y_axis = z_axis * x_axis

          return Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
        end

      end

      IDENTITY
    end

  end

  class SmartDrawShapeActionHandler < SmartDrawActionHandler

    include SmartActionHandlerPartHelper
    include PartHelper

    STATE_SHAPE_START = 0
    STATE_SHAPE = 1
    STATE_PULL = 2

    LAYER_2D_DIMENSIONS = 10
    LAYER_2D_FLOATING_TOOLS = 20

    LAYER_3D_DRAW_PREVIEW = 10

    @@last_pull_measure = 0

    attr_reader :picked_shape_start_point, :picked_shape_end_point, :picked_pull_end_point, :picked_move_end_point, :normal, :direction

    def initialize(action, tool, previous_action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(tool)

      @mouse_down_point = nil
      @mouse_snap_point = nil

      @nearest_vertex_manipulator = nil
      @nearest_edge_manipulators = nil

      @picked_shape_start_point = nil
      @picked_shape_end_point = nil
      @picked_pull_end_point = nil

      @locked_direction = nil
      @locked_normal = nil
      @locked_axis = nil
      @locked_pull_axis = nil
      @locked_pull_manipulator = nil

      @direction = nil
      @normal = _get_active_z_axis

      @definition = nil

      @active_container_path = nil

      # Create 3D layers
      tool.create_3d(LAYER_3D_DRAW_PREVIEW)
      tool.create_3d(LAYER_3D_PART_PREVIEW)

    end

    # -- STATE --

    def get_startup_state
      STATE_SHAPE_START
    end

    def get_state_cursor(state)

      case state

      when STATE_PULL
        return SmartCursorManager.cursor_pull

      end

      super
    end

    def get_state_picker(state)

      case state
      when STATE_SHAPE_START
        return SmartPicker.new(tool: @tool, observer: self, pick_point: false)
      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SHAPE_START
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' + X = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_construction_status') + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_measure_from_vertex_status') + '.'

      when STATE_SHAPE
        return PLUGIN.get_i18n_string("tool.smart_draw.action_#{@action}_state_#{state}_status") + '.'

      when STATE_PULL
        return PLUGIN.get_i18n_string("tool.smart_draw.action_x_state_#{state}_status") + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_measure_locked_status') + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_pull_centered_status') + '.' +
          ' | ←↑→ = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_pull_locked_status') + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string('tool.default.vcb_radius')

      when STATE_PULL
        return PLUGIN.get_i18n_string('tool.default.vcb_distance')

      end

      super
    end

    # -----

    def onToolResume(tool, view)

      # If resume from SmartHandleTool
      if @previous_action_handler && @previous_action_handler.tool.respond_to?(:callback_action_handler)

        # Remove floating tools
        _remove_floating_tools

        # Copy last mouse position
        @tool.last_mouse_x = @previous_action_handler.tool.last_mouse_x
        @tool.last_mouse_y = @previous_action_handler.tool.last_mouse_y

      end

      super
    end

    def onToolCancel(tool, reason, view)
      super

      case @state

      when STATE_SHAPE_START
        _reset

      when STATE_SHAPE
        @picked_shape_start_point = nil
        set_state(STATE_SHAPE_START)

      when STATE_PULL
        @picked_shape_end_point = nil
        set_state(STATE_SHAPE)

      end
      _refresh

    end

    def onToolMouseMove(tool, flags, x, y, view)

      @mouse_snap_point = nil
      @mouse_snap_centroid = nil
      @mouse_snap_face_manipulator = nil
      @mouse_ip.pick(view, x, y, _get_previous_input_point)

      # SKETCHUP_CONSOLE.clear
      # puts "---"
      # puts "vertex = #{@mouse_ip.vertex}"
      # puts "edge = #{@mouse_ip.edge}"
      # puts "face = #{@mouse_ip.face}"
      # puts "face_transformation.identity? = #{@mouse_ip.face_transformation.identity?}"
      # puts "cline = #{@mouse_ip.cline}"
      # puts "depth = #{@mouse_ip.depth}"
      # puts "instance_path.length = #{@mouse_ip.instance_path.length}"
      # puts "instance_path.leaf = #{@mouse_ip.instance_path.leaf}"
      # puts "transformation.identity? = #{@mouse_ip.transformation.identity?}"
      # puts "degrees_of_freedom = #{@mouse_ip.degrees_of_freedom}"
      # puts "best_picked = #{view.pick_helper(x, y).best_picked}"
      # puts "---"

      @tool.clear_2d(LAYER_2D_DIMENSIONS)
      @tool.clear_3d(LAYER_3D_DRAW_PREVIEW)

      super

      case @state

      when STATE_SHAPE_START
        _snap_shape_start(flags, x, y, view)
        _preview_shape_start(view)
        if !@mouse_down_point.nil? && @mouse_snap_point.distance(@mouse_down_point) > view.pixels_to_model(20, @mouse_snap_point)  # Drag handled only if the distance is > 20px
          @picked_shape_start_point = @mouse_down_point
          @mouse_down_point = nil
          set_state(STATE_SHAPE)
        end

      when STATE_SHAPE
        _snap_shape(flags, x, y, view)
        _preview_shape(view)

      when STATE_PULL
        _snap_pull(flags, x, y, view)
        _preview_pull(view)

      end

      # k_points = _create_floating_points(
      #   points: @mouse_snap_point,
      #   style: Kuix::POINT_STYLE_TRIANGLE,
      #   stroke_color: Kuix::COLOR_YELLOW
      # )
      # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

      # k_axes_helper = Kuix::AxesHelper.new
      # k_axes_helper.transformation = _get_transformation
      # @tool.append_3d(k_axes_helper, LAYER_3D_DRAW_PREVIEW)

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

    end

    def onToolMouseLeave(tool, view)
      @tool.clear_2d(LAYER_2D_DIMENSIONS)
      @tool.clear_all_3d
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onToolLButtonDown(tool, flags, x, y, view)
      @mouse_ip.pick(view, x, y)
      @mouse_down_point = @mouse_ip.position
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SHAPE_START
        @picked_shape_start_point = @mouse_snap_centroid.nil? ? @mouse_down_point : @mouse_snap_centroid
        @mouse_down_point = nil
        set_state(STATE_SHAPE)
        _refresh

      when STATE_SHAPE
        if _valid_shape?
          @picked_shape_end_point = @mouse_snap_point
          set_state(STATE_PULL)
          _refresh
        else
          UI.beep
        end

      when STATE_PULL
        if _valid_solid?
          @picked_pull_end_point = @mouse_snap_point
          _create_entity
          _restart
        else
          UI.beep
        end

      else
        UI.beep

      end

      @mouse_down_point = nil

      view.lock_inference if view.inference_locked?
      @locked_axis = nil unless @locked_axis.nil?

    end

    def onToolLButtonDoubleClick(tool, flags, x, y, view)

      case @state

      when STATE_PULL
        unless @@last_pull_measure == 0

          measure = @@last_pull_measure
          measure /= 2 if _fetch_option_pull_centered?
          @picked_pull_end_point = @picked_shape_end_point.offset(@normal, measure)

          _create_entity
          _restart

          return true
        end

      end

      false
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super

      case @state

      when STATE_SHAPE_START, STATE_SHAPE

        if @state == STATE_SHAPE_START
          if tool.is_key_shift?(key) || tool.is_key_ctrl_or_option?(key) || tool.is_key_alt_or_command?(key)
            _refresh
            return true # Block default behavior for the ALT key on Windows
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
          y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
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
          face_manipulator = @mouse_ip.valid? && @mouse_ip.face ? FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation) : nil
          if !@locked_normal.nil? && (face_manipulator.nil? || !face_manipulator.nil? && @locked_normal.samedirection?(face_manipulator.normal))
            @locked_normal = nil
          elsif !face_manipulator.nil?
            @locked_normal = face_manipulator.normal
          end
          _refresh
          return true
        end

      when STATE_PULL

        if tool.is_key_shift?(key)
          UI.beep if @@last_pull_measure == 0
          _refresh
          return true
        end
        if tool.is_key_ctrl_or_option?(key)
          _refresh
          return true
        end

        if key == VK_RIGHT
          x_axis = _get_active_x_axis
          if @locked_pull_axis == x_axis
            @locked_pull_axis = nil
          else
            @locked_pull_axis = x_axis
          end
          @locked_pull_manipulator = nil
          _refresh
          return true
        end
        if key == VK_LEFT
          y_axis = _get_active_y_axis
          if @locked_pull_axis == y_axis
            @locked_pull_axis = nil
          else
            @locked_pull_axis = y_axis
          end
          @locked_pull_manipulator = nil
          _refresh
          return true
        end
        if key == VK_UP
          z_axis = _get_active_z_axis
          if @locked_pull_axis == z_axis
            @locked_pull_axis = nil
          else
            @locked_pull_axis = z_axis
          end
          @locked_pull_manipulator = nil
          _refresh
          return true
        end
        if key == VK_DOWN
          edge_manipulator = @mouse_ip.valid? && @mouse_ip.edge ? EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation) : nil
          if !@locked_pull_axis.nil? && (edge_manipulator.nil? || !edge_manipulator.nil? && @locked_pull_axis.samedirection?(edge_manipulator.direction))
            @locked_pull_axis = nil
            @locked_pull_manipulator = nil
          elsif !edge_manipulator.nil?
            @locked_pull_axis = edge_manipulator.direction
            @locked_pull_manipulator = edge_manipulator
          end
          _refresh
          return true
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE_START
        if tool.is_key_shift?(key) && is_quick
          if tool.is_key_ctrl_or_option_down?
            unless @mouse_snap_face_manipulator.nil?
              if _set_picked_points_from_face_manipulator(@mouse_snap_face_manipulator, view)
                @mouse_snap_face_manipulator = nil
                set_state(STATE_PULL)
              end
            end
          end
          _refresh
          return true
        end
        if tool.is_key_alt_or_command?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_FROM_VERTEX, !_fetch_option_measure_from_vertex?, fire_event: true)
          Sketchup.set_status_text('', SB_VCB_VALUE)
          @previous_action_handler = nil
          _remove_floating_tools
          _refresh
          return true
        end
        if tool.is_key_ctrl_or_option?(key)
          _refresh
          return true
        end

      when STATE_PULL
        if tool.is_key_shift?(key)
          _refresh
          return true
        end
        if tool.is_key_ctrl_or_option?(key)
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_PULL_CENTRED, !_fetch_option_pull_centered?, fire_event: true) if is_quick
          _refresh
          return true
        end

      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if _read_offset(tool, text, view)

      return true if super

      case @state

      when STATE_SHAPE_START
        return _read_shape_start(tool, text, view)

      when STATE_SHAPE
        return _read_shape(tool, text, view)

      when STATE_PULL
        return _read_pull(tool, text, view)

      end

      false
    end

    def onStateChanged(old_state, new_state)
      super

      if old_state == STATE_PULL
        @locked_pull_axis = nil
        @locked_pull_manipulator = nil
      end

      # Remove floatin tools
      _remove_floating_tools

      # Disable measure from vertex option
      @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_FROM_VERTEX, false, fire_event: true)

    end

    def onPickerChanged(picker, view)

      case @state

      when STATE_SHAPE_START
        _pick_part(picker, view) if _fetch_option_draw_in?

      end

      super
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)

      # Preview part's container
      _preview_part(part_entity_path, part)

      # Reset active container path
      @active_container_path = nil

      if part_entity_path.is_a?(Array) && part_entity_path.length > 1

        container_path = part_entity_path[0...-1]
        return true if container_path == Sketchup.active_model.active_path

        @active_container_path = container_path

      end

    end

    # -----

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    # -----

    protected

    # -----

    def _can_activate_locked?
      false
    end

    # -----

    def _preview_part_mesh?
      false
    end

    def _preview_part_container?
      true
    end

    # -----

    def _get_previous_input_point
      return Sketchup::InputPoint.new(@picked_shape_start_point) if @state == STATE_SHAPE
      return Sketchup::InputPoint.new(@picked_shape_end_point) if @state == STATE_PULL
      nil
    end

    def _get_picked_points
      points = []
      points << @picked_shape_start_point unless @picked_shape_start_point.nil?
      points << @picked_shape_end_point unless @picked_shape_end_point.nil?
      points << @picked_pull_end_point unless @picked_pull_end_point.nil?
      points << @mouse_snap_point unless @mouse_snap_point.nil?
      points
    end

    def _picked_shape_start_point?
      !@picked_shape_start_point.nil?
    end

    def _picked_shape_end_point?
      !@picked_shape_end_point.nil?
    end

    def _set_picked_points_from_face_manipulator(face_manipulator, view)
      false
    end

    # -----

    def _snap_shape_start(flags, x, y, view)

      @nearest_vertex_manipulator = nil
      @nearest_edge_manipulators = nil

      if @locked_normal

        @normal = @locked_normal

      else

        # if @mouse_ip.instance_path.length > 1
        #   part_path = _get_part_entity_path_from_path(@mouse_ip.instance_path.to_a)
        #   if part_path.length > 1
        #     puts "active_container_path = #{part_path[0...-1]}"
        #   end
        # end

        if @mouse_ip.vertex

          # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
          #
          # k_points = Kuix::Points.new
          # k_points.add_points([ vertex_manipulator.point ])
          # k_points.size = 30
          # k_points.stroke_style = Kuix::POINT_STYLE_SQUARE
          # k_points.color = Kuix::COLOR_MAGENTA
          # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)
          #
          # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
          #
          #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          #   @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)
          #
          # end

        elsif @mouse_ip.edge

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(edge_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

          if @mouse_ip.face && @mouse_ip.edge.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

            @normal = face_manipulator.normal

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            # @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)

          end

          @direction = edge_manipulator.direction
          @locked_direction = @direction

          if _fetch_option_measure_from_vertex?

            @nearest_vertex_manipulator = edge_manipulator.nearest_vertex_manipulator_to(@mouse_ip.position)
            @nearest_edge_manipulators = @nearest_vertex_manipulator.edge_manipulators.select { |edge_manipulator| edge_manipulator.edge == @mouse_ip.edge }

          end

        elsif @mouse_ip.cline

          cline_manipulator = ClineManipulator.new(@mouse_ip.cline, @mouse_ip.transformation)

          if @mouse_ip.face

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

            @normal = face_manipulator.normal

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            # @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)

          end

          @direction = cline_manipulator.direction
          @locked_direction = @direction

        elsif @mouse_ip.face #&& @mouse_ip.degrees_of_freedom == 2

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

          @locked_direction = nil
          @normal = face_manipulator.normal

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(face_manipulator.triangles)
          # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
          # @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)

          position = @mouse_ip.position
          degrees_of_freedom = @mouse_ip.degrees_of_freedom
          face = @mouse_ip.face

          if @tool.is_key_ctrl_or_option_down?

            if @tool.is_key_shift_down?
              @mouse_snap_face_manipulator = face_manipulator
            end

            # Compute face centroid
            @mouse_snap_point = @mouse_snap_centroid = face_manipulator.centroid
            unless @mouse_snap_point.nil?
              position = @mouse_snap_point
              @mouse_ip.clear
            end

          end

          if degrees_of_freedom == 2 && _fetch_option_measure_from_vertex?

            # Compute nearest
            @nearest_vertex_manipulator = face_manipulator.outer_loop_manipulator.nearest_vertex_manipulator_to(position, false)
            @nearest_edge_manipulators = @nearest_vertex_manipulator.edge_manipulators.select { |edge_manipulator| edge_manipulator.edge.faces.include?(face) }

          end

        elsif @locked_normal.nil?

          @locked_direction = nil
          @direction = nil
          @normal = _get_active_z_axis

        end

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _snap_shape(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _snap_pull(flags, x, y, view)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1 ||
        @mouse_ip.position.on_plane?([ @picked_shape_end_point, @normal ]) ||
        @mouse_ip.face && @mouse_ip.face == @mouse_ip.instance_path.leaf && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(@normal) ||
        @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(@normal)

        picked_point, _ = Geom::closest_points([ @picked_shape_end_point, @normal ], view.pickray(x, y))
        @mouse_snap_point = picked_point
        @mouse_ip.clear

      else

        # Force picked point to be projected to shape last picked point normal line
        @mouse_snap_point = @mouse_ip.position.project_to_line([ @picked_shape_end_point, @normal ])

      end

      # Lock on the last pull measure
      if @tool.is_key_shift_down? && @@last_pull_measure > 0
        measure = @@last_pull_measure
        measure /= 2 if _fetch_option_pull_centered?
        v = @picked_shape_end_point.vector_to(@mouse_snap_point)
        @mouse_snap_point = @picked_shape_end_point.offset(v, measure) if measure > 0 && v.valid?

      # Raytest
      elsif @tool.is_key_ctrl_or_option_down?
        ray = [ @picked_shape_end_point, @picked_shape_end_point.vector_to(@mouse_snap_point) ]
        position, entity = Sketchup.active_model.raytest(ray)
        @mouse_snap_point = position unless position.nil?
      end

    end

    # -----

    def _preview_shape_start(view)

      unless @mouse_snap_centroid.nil?

        k_points = _create_floating_points(
          points: @mouse_snap_centroid,
          style: Kuix::POINT_STYLE_CIRCLE,
          fill_color: Sketchup::Color.new(17, 98, 160),
          stroke_color: Kuix::COLOR_WHITE
        )
        @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

      end

      unless @nearest_vertex_manipulator.nil? || @nearest_edge_manipulators.nil?

        p0 = @nearest_vertex_manipulator.point
        pm = @mouse_snap_point
        pp = @nearest_edge_manipulators.map { |edge_manipulator| @mouse_snap_point.project_to_line(edge_manipulator.line) }
        if pp.one?
          dd = [ pp.first.distance(p0) ]
        else
          dd = pp.map { |point| point.distance(pm) }
        end

        colors = [ Kuix::COLOR_X, Kuix::COLOR_Y ]
        pp.each_with_index do |p, index|

          if pp.one?

            k_edge = Kuix::EdgeMotif3d.new
            k_edge.start.copy!(p)
            k_edge.end.copy!(p0)
            k_edge.line_width = 1
            k_edge.line_stipple = Kuix::LINE_STIPPLE_SOLID
            k_edge.color = colors[index]
            k_edge.on_top = true
            @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

          else

            k_edge = Kuix::EdgeMotif3d.new
            k_edge.start.copy!(p0)
            k_edge.end.copy!(p)
            k_edge.line_width = 1
            k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
            k_edge.color = Kuix::COLOR_BLACK
            @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

            k_edge = Kuix::EdgeMotif3d.new
            k_edge.start.copy!(p)
            k_edge.end.copy!(pm)
            k_edge.line_width = 1
            k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
            k_edge.color = colors[index]
            @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

          end

          k_points = _create_floating_points(
            points: p,
            style: Kuix::POINT_STYLE_SQUARE,
            stroke_color: colors[index],
            fill_color: nil,
            size: 1.5
          )
          @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

          if view.pixels_to_model(60, p0) < dd[index]

            k_label = _create_floating_label(
              snap_point: Geom.linear_combination(0.5, p, 0.5, pp.one? ? p0 : pm),
              text: dd[index],
              text_color: colors[index],
              border_color: colors[index]
            )
            @tool.append_2d(k_label, LAYER_2D_DIMENSIONS)

          end

        end

        k_points = _create_floating_points(
          points: p0,
          style: Kuix::POINT_STYLE_CIRCLE,
          stroke_color: Kuix::COLOR_BLACK,
          fill_color: Kuix::COLOR_WHITE
        )
        @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

        Sketchup.set_status_text(dd.join("#{Sketchup::RegionalSettings.list_separator} "), SB_VCB_VALUE)

      end

    end

    def _preview_shape(view)
    end

    def _preview_pull(view)
      return if (pull_def = _get_pull_def).nil?

      t, psb, pst, ps, p1, centered, sheared, bt, tt = pull_def.values_at(:t, :psb, :pst, :ps, :p1, :centered, :sheared, :bt, :tt)

      measure = psb.distance(pst)

      color = sheared ? _get_vector_color(@locked_pull_axis, Kuix::COLOR_MAGENTA) : _get_normal_color

      if @locked_pull_manipulator.is_a?(EdgeManipulator)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@locked_pull_manipulator.start_point)
        k_edge.end.copy!(@locked_pull_manipulator.end_point)
        k_edge.color = Kuix::COLOR_MAGENTA
        k_edge.line_width = 2
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

      end

      if _fetch_option_shape_offset != 0

        shape_points = _get_local_shape_points
        bottom_shape_points = shape_points.map { |point| point.transform(bt) }
        top_shape_points = shape_points.map { |point| point.transform(tt) }

        k_segments = Kuix::Segments.new
        k_segments.add_segments(_points_to_segments(bottom_shape_points))
        k_segments.add_segments(_points_to_segments(top_shape_points))
        k_segments.add_segments(bottom_shape_points.zip(top_shape_points).flatten(1))
        k_segments.line_width = 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_bottom_shape_points = o_shape_points.map { |point| point.transform(bt) }
        o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

        k_segments = Kuix::Segments.new
        k_segments.add_segments(_points_to_segments(o_bottom_shape_points))
        k_segments.add_segments(_points_to_segments(o_top_shape_points))
        k_segments.add_segments(o_bottom_shape_points.zip(o_top_shape_points).flatten(1))
        k_segments.line_width = _fetch_option_construction? ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction?
        k_segments.color = color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      if sheared

        # Draw thickness arrow
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(psb)
        k_edge.end.copy!(pst)
        k_edge.line_width = 1.5
        k_edge.color = Kuix::COLOR_Z
        k_edge.start_arrow = true
        k_edge.end_arrow = true
        k_edge.arrow_size = @tool.get_unit * 2.0
        k_edge.on_top = true
        k_edge.transformation = t
        @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

        # Bottom link to thickness arrow
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(psb)
        k_edge.end.copy!(p1)
        k_edge.line_width = 1
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        k_edge.transformation = t
        @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

        # Top link to thickness arrow
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(pst)
        k_edge.end.copy!(ps.transform(tt))
        k_edge.line_width = 1
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        k_edge.transformation = t
        @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

      elsif centered

        # Draw the first picked point
        k_point = _create_floating_points(
          points: @picked_shape_start_point,
          style: Kuix::POINT_STYLE_PLUS
        )
        @tool.append_3d(k_point, LAYER_3D_DRAW_PREVIEW)

        # Draw line from first picked point to snap point
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@picked_shape_start_point)
        k_edge.end.copy!(@mouse_snap_point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

      end

      Sketchup.set_status_text(measure, SB_VCB_VALUE)

      if measure > 0

        k_label = _create_floating_label(
          snap_point: Geom.linear_combination(0.5, psb, 0.5, pst).transform(t),
          text: measure,
          text_color: Kuix::COLOR_Z,
          border_color: color
        )
        @tool.append_2d(k_label, LAYER_2D_DIMENSIONS)

      end

    end

    # -----

    def _read_offset(tool, text, view)

      if (match = /^(.+)x$/i.match(text))

        value = match[1]

        begin
          offset = value.to_l
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_SHAPE_OFFSET, offset.to_s, fire_event: true)
          Sketchup.set_status_text('', SB_VCB_VALUE)
          _refresh
        rescue ArgumentError
          UI.beep
          tool.notify_errors([ [ 'tool.default.error.invalid_offset', { :value => value } ] ])
        end

        return true
      end

      false
    end

    def _read_shape_start(tool, text, view)

      if @nearest_edge_manipulators.is_a?(Array) && @nearest_edge_manipulators.one?

        p0 = @nearest_vertex_manipulator.point
        p1 = @mouse_snap_point.project_to_line(@nearest_edge_manipulators[0].line)
        n1 = p0.vector_to(p1)

        d1 = _read_user_text_length(tool, text, n1.length)
        return true if d1.nil?

        @picked_shape_start_point = p0.offset(n1, d1)

        set_state(STATE_SHAPE)
        _refresh

        return true
      elsif @nearest_vertex_manipulator

        d1, d2 = _split_user_text(text)

        if d1 || d2

          p0 = @nearest_vertex_manipulator.point
          p1, p2 = @nearest_edge_manipulators.map { |edge_manipulator| @mouse_snap_point.project_to_line(edge_manipulator.line) }
          pm = @mouse_snap_point
          n1 = p1.vector_to(pm)
          n2 = p2.vector_to(pm)

          d1 = _read_user_text_length(tool, d1, n1.length)
          d2 = _read_user_text_length(tool, d2, n2.length)

          @picked_shape_start_point = Geom.intersect_line_line([ p0.offset(n1, d1), @nearest_edge_manipulators[0].direction], [ p0.offset(n2, d2), @nearest_edge_manipulators[1].direction])

          set_state(STATE_SHAPE)
          _refresh

          return true
        end

      else

        p = _read_user_text_point(tool, text, @mouse_snap_point)

        if p

          @picked_shape_start_point = p

          set_state(STATE_SHAPE)
          _refresh

          return true
        end

      end

      false
    end

    def _read_shape(tool, text, view)
      if @picked_shape_start_point == @mouse_snap_point
        UI.beep
        tool.notify_errors([ "tool.default.error.no_direction" ])
        return true
      end
      false
    end

    def _read_pull(tool, text, view)
      return if (pull_def = _get_pull_def).nil?

      t, psb, pst, pe = pull_def.values_at(:t, :psb, :pst, :pe)

      base_thickness = pst.z - psb.z
      thickness = _read_user_text_length(tool, text, base_thickness)
      return true if thickness.nil?
      thickness /= 2 if _fetch_option_pull_centered?

      @picked_pull_end_point = Geom::Point3d.new(pe.x, pe.y, thickness).transform(t)

      _create_entity
      _restart

      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # -----

    def _fetch_option_shape_offset
      @tool.fetch_action_option_length(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_SHAPE_OFFSET)
    end

    def _fetch_option_measure_from_vertex?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_FROM_VERTEX)
    end

    def _fetch_option_pull_centered?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_PULL_CENTRED)
    end

    # -----

    def _get_axes

      if @direction.nil? || !@direction.valid? || !@direction.perpendicular?(@normal)

        active_x_axis = _get_active_x_axis
        active_x_axis = _get_active_y_axis if active_x_axis.parallel?(@normal)

        x_axis = ORIGIN.vector_to(ORIGIN.offset(active_x_axis).project_to_plane([ ORIGIN, @normal ]))

      else
        x_axis = @direction
      end
      z_axis = @normal
      y_axis = z_axis * x_axis

      [ x_axis.normalize, y_axis.normalize, z_axis.normalize ]
    end

    def _get_transformation(origin = ORIGIN)
      Geom::Transformation.axes(origin, *_get_axes)
    end

    def _get_normal_color
      color = _get_vector_color(@normal)
      return Kuix::COLOR_MAGENTA if @normal == @locked_normal && color == Kuix::COLOR_BLACK
      color
    end

    def _get_direction_color
      _get_vector_color(@direction)
    end

    # -----

    def _reset
      @mouse_ip.clear
      @mouse_down_point = nil
      @mouse_snap_point = nil
      @mouse_snap_centroid = nil
      @mouse_snap_face_manipulator = nil
      @nearest_vertex_manipulator = nil
      @nearest_edge_manipulators = nil
      @picked_shape_start_point = nil
      @picked_shape_end_point = nil
      @picked_pull_end_point = nil
      @direction = nil
      @normal = _get_active_z_axis
      @locked_direction = nil
      @locked_normal = nil
      @locked_axis = nil
      @locked_pull_axis = nil
      @locked_pull_manipulator = nil
      @active_container_path = nil
      super
      set_state(STATE_SHAPE_START)
    end

    def _restart
      new_action_handler = super

      @locked_direction = nil
      @locked_normal = nil
      @locked_axis = nil

      if @state == STATE_PULL && !(center = _get_instance_bounds_center).nil?
        _append_floating_tools_at(center, new_action_handler)
      end

    end

    # -----

    def _valid_shape?
      _get_local_shapes_points_with_offset.any?
    end

    def _valid_solid?
      true
    end

    # -----

    def _get_local_shape_points
      []
    end

    def _get_local_shapes_points_with_offset(shape_offset = nil)
      []
    end

    # -----

    def _create_faces(definition, t, ps, pe)
      _get_local_shapes_points_with_offset
        .map { |shape_points| definition.entities.add_face(shape_points.map { |p| p.transform(t) }) if shape_points.size >= 3 }
        .compact
    end

    def _create_entity
      return if (pull_def = _get_pull_def).nil?

      t, ps, pe, psb, pst, bt, tt = pull_def.values_at(:t, :ps, :pe, :psb, :pst, :bt, :tt)

      model = Sketchup.active_model
      model.start_operation('OCL Create Part', true, false, !active?)
      begin

        if @active_container_path.is_a?(Array) && @active_container_path.any? &&
           (active_container = @active_container_path.last) && active_container.respond_to?(:definition)
          active_entities = active_container.definition.entities
          active_transformation = PathUtils.get_transformation(@active_container_path, IDENTITY)
        else
          active_entities = model.active_entities
          active_transformation = IDENTITY
        end

        # Remove previously created entity if exists
        if @definition.is_a?(Sketchup::ComponentDefinition)
          model.active_entities.erase_entities(@definition.instances)
          model.definitions.remove(@definition) if Sketchup.version_number >= 1800000000
          @definition = nil
        end

        measure = psb.distance(pst)

        @@last_pull_measure = measure

        if _fetch_option_construction? || measure == 0

        group = active_entities.add_group
        group.transformation = active_transformation.inverse * t

        if _fetch_option_construction?

          # Construction

          _get_local_shapes_points_with_offset.each do |o_shape_points|

            o_bottom_shape_points = o_shape_points.map { |point| point.transform(bt) }

            _points_to_segments(o_bottom_shape_points, true, false).each { |segment| group.entities.add_cline(*segment) }

            if measure > 0

              o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

              _points_to_segments(o_top_shape_points, true, false).each { |segment| group.entities.add_cline(*segment) }
              o_bottom_shape_points.zip(o_top_shape_points).each { |segment| group.entities.add_cline(*segment) }

            end

          end

        else

          # Flat drawing, just add to the group

          faces = _create_faces(group.definition, IDENTITY, ps, pe)
          faces.each do |face|
            face.reverse! unless face.normal.samedirection?(Z_AXIS)
          end

        end

        instance = group

      else

        # Solid drawing creates a component definition + instance

        bti = bt.inverse

        definition = model.definitions.add(PLUGIN.get_i18n_string('default.part_single').capitalize)

        bottom_faces = _create_faces(definition, bt, ps, pe)
        if measure > 0
          top_faces = _create_faces(definition, tt, ps, pe)
        else
          top_faces = []
        end
        bottom_faces.zip(top_faces).each do |bottom_face, top_face|

          if !top_face.nil?

            bottom_face.reverse! if bottom_face.normal.samedirection?(psb.vector_to(pst))
            top_face.reverse! if top_face.normal.samedirection?(pst.vector_to(psb))

            entities = bottom_face.parent.entities
            group = entities.add_group
            smoothed = (curve = bottom_face.outer_loop.edges.first.curve).is_a?(Sketchup::ArcCurve) && !curve.is_polygon?
            bottom_face.vertices.each do |vertex|
              group.entities.add_edges([ vertex.position, vertex.position.transform(bti).transform(tt) ]).each do |edge|
                edge.soft = edge.smooth = smoothed
              end
            end
            group.explode.grep(Sketchup::Edge).each { |edge| edge.find_faces }

          else

            bottom_face.reverse! unless bottom_face.normal.samedirection?(Z_AXIS)

          end

        end

        tao = _get_auto_orient_transformation(definition, t)
        unless tao.identity?

          t = t * tao
          taoi = tao.inverse

          # Transform definition's entities
          entities = definition.entities
          entities.transform_entities(taoi, entities.to_a)

        end

        instance = active_entities.add_instance(definition, active_transformation.inverse * t)

        if active?

          fn_ask_name = lambda {
            unless instance.nil? || instance.definition.nil? || instance.definition.deleted?
              if (data = UI.inputbox([ PLUGIN.get_i18n_string('tab.cutlist.edit_part.name') ], [ instance.definition.name ], PLUGIN.get_i18n_string('default.rename')))
                name = data.first
                if name.empty?
                  UI.beep
                else
                  instance.definition.name = name
                end
              end
            end
          }

          if _fetch_option_ask_name?
            fn_ask_name.call
          else

            # Notify part created and propose renaming
            @tool.notify_success(
              PLUGIN.get_i18n_string("tool.smart_draw.success.part_created", { :name => definition.name }),
              [
                {
                  :label => PLUGIN.get_i18n_string('default.rename'),
                  :block => fn_ask_name,
                }
              ]
            )

          end

        end

      end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

      # Keep definition
      @definition = instance.definition

      # Reset drawing def cache
      @drawing_def = nil

    end

    # --

    def _get_pull_def
      return nil unless @picked_shape_start_point.is_a?(Geom::Point3d) && @picked_shape_end_point.is_a?(Geom::Point3d)

      centered = _fetch_option_pull_centered?

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      points = _get_picked_points
      ps = points[0].transform(ti)  # point start
      pe = points[1].transform(ti)  # point end
      pp = points[2].transform(ti)  # point pull

      v = pe.vector_to(pp)

      psb = centered ? ps.offset(v.reverse) : ps   # point start bottom
      pst = ps.offset(v)                          # point start top

      sheared = false

      unless @locked_pull_axis.nil?
        p3 = Geom.intersect_line_plane([ pe, @locked_pull_axis.transform(ti) ], [ pp, v ])
        unless p3.nil?

          offset = p3.vector_to(pe)
          p1 = centered ? ps.offset(offset) : ps
          p2 = centered ? pe.offset(offset) : pe

          sheared = true

        end
      end

      unless sheared

        p1 = ps
        p2 = pe
        p3 = pp

        if centered
          offset = pp.vector_to(pe)
          p1 = p1.offset(offset)
          p2 = p2.offset(offset)
        end

      end

      bt = Geom::Transformation.translation(pe.vector_to(p2))
      tt = Geom::Transformation.translation(pe.vector_to(p3))

      {
        t: t,
        ti:ti,
        ps: ps,
        pe: pe,
        psb: psb,
        pst: pst,
        p1: p1,
        p2: p2,
        p3: p3,
        centered: centered,
        sheared: sheared,
        bt: bt,
        tt: tt,
      }
    end

    # --

    def _get_instance
      return nil if @definition.nil? || @definition.deleted?
      @definition.instances.first
    end

    # Returns the center of the created instance bounds expressed in model space.
    # Unlike _get_drawing_def, definition bounds take clines and cpoints into account.
    def _get_instance_bounds_center
      return nil if (instance = _get_instance).nil?

      bounds = instance.definition.bounds
      return nil unless bounds.valid?

      instance_path = (@active_container_path.nil? ? Sketchup.active_model.active_path.to_a : @active_container_path) + [ instance ]

      bounds.center.transform(PathUtils.get_transformation(instance_path, IDENTITY))
    end

    def _get_drawing_def
      return nil if @definition.nil?
      return @drawing_def unless @drawing_def.nil?

      model = Sketchup.active_model
      return nil if model.nil?

      instance = _get_instance
      instance_path = (@active_container_path.nil? ? Sketchup.active_model.active_path.to_a : @active_container_path) + [ instance ]

      return nil unless instance_path.is_a?(Array) && instance_path.any?

      @drawing_def = CommonDrawingDecompositionWorker.new(Sketchup::InstancePath.new(instance_path),
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: true,
        ignore_soft_edges: true,
        ignore_clines: true
      ).run
    end

    # --

    def _append_floating_tools_at(position, callback_action_handler)

      unit = @tool.get_unit

      model = Sketchup.active_model
      tools = model.tools
      instance_path = (@active_container_path.is_a?(Array) ? @active_container_path : model.active_path.to_a) + [ _get_instance ]
      selection = SmartSelection.new([ instance_path ])

      tool_defs = [
        {
          tooltip_key: "tool.smart_handle.action_#{SmartHandleTool::ACTION_COPY_LINE}",
          path: 'M0,0.667L0.333,0.667L0.333,1L0,1L0,0.667 M0.667,0L1,0L1,0.333L0.667,0.333L0.667,0 M0.417,0.583L0.583,0.417',
          block: lambda {
            tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_COPY_LINE,
              callback_action_handler: callback_action_handler,
              startup_selection: selection
            ))
          }
        },
        {
          tooltip_key: "tool.smart_handle.action_#{SmartHandleTool::ACTION_COPY_GRID}",
          path: 'M0.333,0.667L0,0.667L0,1L0.333,1L0.333,0.667 M1,0.667L0.667,0.667L0.667,1L1,1L1,0.667 M0.333,0L0,0L0,0.333L0.333,0.333L0.333,0 M1,0L0.667,0L0.667,0.333L1,0.333L1,0 M0.167,0.417L0.167,0.583 M0.417,0.833L0.583,0.833',
          block: lambda {
            tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_COPY_GRID,
              callback_action_handler: callback_action_handler,
              startup_selection: selection
            ))
          }
        },
        {
          tooltip_key: "tool.smart_handle.action_#{SmartHandleTool::ACTION_MOVE_LINE}",
          path: 'M0.666,0L1,0L1,0.334L0.666,0.334L0.666,0M0.083,0.917L0.583,0.417',
          block: lambda {
            tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_MOVE_LINE,
              callback_action_handler: callback_action_handler,
              startup_selection: selection
            ))
          }
        },
        {
          tooltip_key: "tool.smart_handle.action_#{SmartHandleTool::ACTION_DISTRIBUTE}",
          path: 'M0.333,0.333L0.667,0.333L0.667,0.667L0.333,0.667L0.333,0.333 M0.083,0.917L0.25,0.75 M0.75,0.25L0.917,0.083',
          block: lambda {
            tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_DISTRIBUTE,
              callback_action_handler: callback_action_handler,
              startup_selection: selection
            ))
          }
        },
        {
          tooltip_key: "tool.smart_reshape.action_#{SmartReshapeTool::ACTION_PANELING}",
          path: 'M0,0L0,0.375L0.625,0.375L1,0L0,0 M1,0L1,1L0.625,1L0.625,0.375',
          block: lambda {
            tools.push_tool(SmartReshapeTool.new(
              current_action: SmartReshapeTool::ACTION_PANELING,
              callback_action_handler: callback_action_handler,
              startup_selection: selection
            ))
          }
        }
      ]

      k_panel = Kuix::Panel.new
      k_panel.layout_data = Kuix::StaticLayoutDataWithSnap.new(position, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      k_panel.layout = Kuix::GridLayout.new(tool_defs.length, 1, unit * 0.5, unit * 0.5)
      @tool.append_2d(k_panel, LAYER_2D_FLOATING_TOOLS)

      tool_defs.each do |tool_def|

        k_btn = Kuix::Button.new
        k_btn.layout = Kuix::GridLayout.new
        k_btn.border.set_all!(unit * 0.5)
        k_btn.padding.set_all!(unit)
        k_btn.set_style_attribute(:background_color, ColorUtils.color_translucent(Kuix::COLOR_WHITE, 200))
        k_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_LIGHT, :hover)
        k_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND, :active)
        k_btn.set_style_attribute(:border_color, SmartTool::COLOR_BRAND_LIGHT)
        k_btn.set_style_attribute(:border_color, SmartTool::COLOR_BRAND, :hover)
        k_btn.on(:enter) do
          # Sketchup.active_model.selection.clear
          # Sketchup.active_model.selection.add(_get_instance)
          @tool.show_message(PLUGIN.get_i18n_string(tool_def[:tooltip_key]))
        end
        k_btn.on(:leave) do
          # Sketchup.active_model.selection.clear
          @tool.hide_message
        end
        k_btn.on(:click) do
          @tool.hide_message
          tool_def[:block].call
        end
        k_panel.append(k_btn)

          k_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(tool_def[:path]))
          k_motif.line_width = unit * 0.25
          k_motif.min_size.set_all!(unit * 4)
          k_motif.set_style_attribute(:color, Kuix::COLOR_BLACK)
          k_motif.set_style_attribute(:color, Kuix::COLOR_WHITE, :active)
          k_btn.append(k_motif)

      end

    end

    def _remove_floating_tools
      @tool.hide_message
      @tool.clear_2d(LAYER_2D_FLOATING_TOOLS)
    end

    # -- UTILS --

    def _points_to_segments(points, closed = true, flatten = true)
      segments = points.each_cons(2).to_a
      segments << [ points.last, points.first ] if closed && !points.empty?
      segments.flatten!(1) if flatten
      segments
    end

  end

  class SmartDrawRectangleActionHandler < SmartDrawShapeActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_RECTANGLE, tool, previous_action_handler)
    end

    # -- State --

    def get_state_status(state)

      case state

      when STATE_SHAPE
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_rectangle_centered_status') + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string('tool.default.vcb_size')

      end

      super
    end

    # -----

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE
        if tool.is_key_ctrl_or_option?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, !_fetch_option_rectangle_centered?, fire_event: true)
          _refresh
          return true
        end

      end

      super
    end

    protected

    def _get_previous_input_point
      return nil if _picked_shape_start_point? && !_picked_shape_end_point?
      super
    end

    # -----

    def _snap_shape(flags, x, y, view)

      ground_plane = [ @picked_shape_start_point, _get_active_z_axis ]

      if @mouse_ip.vertex

        if @locked_normal

          locked_plane = [ @picked_shape_start_point, @locked_normal ]

          @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
          @normal = @locked_normal

        elsif @mouse_ip.position.on_plane?(ground_plane)

          @normal = _get_active_z_axis

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_x_axis ])

          @normal = _get_active_x_axis

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_y_axis ])

          @normal = _get_active_y_axis

        else

          # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
          #
          # k_points = Kuix::Points.new
          # k_points.add_points([ vertex_manipulator.point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_SQUARE
          # k_points.stroke_color = Kuix::COLOR_MAGENTA
          # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)
          #
          # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
          #
          #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          #   @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)
          #
          # end

        end

      elsif @mouse_ip.edge

        edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

        if @locked_normal

          locked_plane = [ @picked_shape_start_point, @locked_normal ]

          @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
          @normal = @locked_normal

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_z_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_z_axis)

          @normal = _get_active_z_axis

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_x_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_x_axis)

          @normal = _get_active_x_axis

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_y_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_y_axis)

          @normal = _get_active_y_axis

        else

          unless @picked_shape_start_point.on_line?(edge_manipulator.line)

            plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_shape_start_point, edge_manipulator.start_point, edge_manipulator.end_point ]))

            @normal = plane_manipulator.normal

          end

          @direction = edge_manipulator.direction if @locked_direction.nil?

          # k_points = Kuix::Points.new
          # k_points.add_points([ @picked_shape_start_point.position, edge_manipulator.start_point, edge_manipulator.end_point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_TRIANGLE
          # k_points.stroke_color = Kuix::COLOR_BLUE
          # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)
          #
          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(edge_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

        end

      elsif @mouse_ip.cline

        cline_manipulator = ClineManipulator.new(@mouse_ip.cline, @mouse_ip.transformation)

        if @locked_normal

          locked_plane = [ @picked_shape_start_point, @locked_normal ]

          @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
          @normal = @locked_normal

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_z_axis ]) && !cline_manipulator.direction.perpendicular?(_get_active_z_axis)

          @normal = _get_active_z_axis

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_x_axis ]) && !cline_manipulator.direction.perpendicular?(_get_active_x_axis)

          @normal = _get_active_x_axis

        elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_y_axis ]) && !cline_manipulator.direction.perpendicular?(_get_active_y_axis)

          @normal = _get_active_y_axis

        else

          unless cline_manipulator.infinite? || @picked_shape_start_point.on_line?(cline_manipulator.line)

            plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_shape_start_point, cline_manipulator.start_point, cline_manipulator.end_point ]))

            @normal = plane_manipulator.normal

          end

          @direction = cline_manipulator.direction if @locked_direction.nil?

          # k_points = Kuix::Points.new
          # k_points.add_points([ @picked_shape_start_point.position, cline_manipulator.start_point, cline_manipulator.end_point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_TRIANGLE
          # k_points.stroke_color = Kuix::COLOR_BLUE
          # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)
          #
          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(cline_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

        end

      elsif @mouse_ip.face && @mouse_ip.degrees_of_freedom == 2

        if @locked_normal

          locked_plane = [ @picked_shape_start_point, @locked_normal ]

          @mouse_ip.copy!(@mouse_ip.position.project_to_plane(locked_plane))
          @normal = @locked_normal

        else

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

          if @picked_shape_start_point.on_plane?(face_manipulator.plane)

            @normal = face_manipulator.normal

          else

            p1 = @picked_shape_start_point
            p2 = @mouse_ip.position
            p3 = @mouse_ip.position.project_to_plane(ground_plane)

            # k_points = Kuix::Points.new
            # k_points.add_points([ p1, p2, p3 ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_PLUS
            # k_points.stroke_color = Kuix::COLOR_RED
            # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

            plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
            plane_manipulator = PlaneManipulator.new(plane)

            @direction = _get_active_z_axis if @locked_direction.nil?
            @normal = plane_manipulator.normal

            @mouse_snap_point = @mouse_ip.position

          end

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(face_manipulator.triangles)
          # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
          # @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)

        end

      else

        if @locked_normal

          locked_plane = [ @picked_shape_start_point, @locked_normal ]

          if @mouse_ip.degrees_of_freedom > 2
            @mouse_ip.copy!(Geom.intersect_line_plane(view.pickray(x, y), locked_plane))
          else
            @mouse_ip.copy!(@mouse_ip.position.project_to_plane(locked_plane))
          end
          @normal = @locked_normal

        else

          if @mouse_ip.degrees_of_freedom > 2
            picked_point = Geom::intersect_line_plane(view.pickray(x, y), ground_plane)
            @mouse_ip.copy!(picked_point) unless picked_point.nil?
          end

          if !@mouse_ip.position.on_plane?(ground_plane)

            p1 = @picked_shape_start_point
            p2 = @mouse_ip.position
            p3 = @mouse_ip.position.project_to_plane(ground_plane)

            # k_points = Kuix::Points.new
            # k_points.add_points([ p1, p2, p3 ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_CROSS
            # k_points.stroke_color = Kuix::COLOR_RED
            # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

            plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
            plane_manipulator = PlaneManipulator.new(plane)

            @direction = _get_active_z_axis if @locked_direction.nil?
            @normal = plane_manipulator.normal

          else

            @direction = @locked_direction
            @normal = _get_active_z_axis

          end

        end

      end

      # Check square
      if @mouse_snap_point.nil? && @mouse_ip.degrees_of_freedom >= 2

        t = _get_transformation(@picked_shape_start_point)
        ti = t.inverse

        p1 = @picked_shape_start_point.transform(ti)
        p2 = @mouse_ip.position.transform(ti)
        v = p1.vector_to(p2)

        psqr = Geom::Point3d.new(p1.x + v.x, p1.y + v.x.abs * (v.y < 0 ? -1 : 1)).transform(t)

        @mouse_snap_point = psqr if view.pick_helper.test_point(psqr, x, y, 20)

      end

      super
    end

    # -----

    def _preview_shape_start(view)
      super

      width = view.pixels_to_model(40, @mouse_snap_point)
      height = width / 2

      normal_color = _get_normal_color

      shape_offset = _fetch_option_shape_offset
      if shape_offset > 0
        offset = width * 0.1
      elsif shape_offset < 0
        offset = width * -0.1
      else
        offset = 0
      end

      if offset != 0

        k_rectangle = Kuix::RectangleMotif3d.new
        k_rectangle.bounds.size.set!(width, height)
        k_rectangle.line_width = 1
        k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_rectangle.color = normal_color
        k_rectangle.on_top = true
        k_rectangle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
        k_rectangle.transformation *= Geom::Transformation.translation(Geom::Vector3d.new(-width / 2, -height / 2)) if _fetch_option_rectangle_centered?
        @tool.append_3d(k_rectangle, LAYER_3D_DRAW_PREVIEW)

      end

      k_rectangle = Kuix::RectangleMotif3d.new
      k_rectangle.bounds.origin.set!(-offset, -offset)
      k_rectangle.bounds.size.set!(width + 2 * offset, height + 2 * offset)
      k_rectangle.line_width = @locked_normal ? 3 : 1.5
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction?
      k_rectangle.color = normal_color
      k_rectangle.on_top = true
      k_rectangle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
      k_rectangle.transformation *= Geom::Transformation.translation(Geom::Vector3d.new(-width / 2, -height / 2)) if _fetch_option_rectangle_centered?
      @tool.append_3d(k_rectangle, LAYER_3D_DRAW_PREVIEW)

    end

    def _preview_shape(view)

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      normal_color = _get_normal_color

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p2)

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_segments = _points_to_segments(o_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(o_segments)
        k_segments.line_width = @locked_normal ? 3 : _fetch_option_construction? ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction?
        k_segments.color = normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      Sketchup.set_status_text("#{bounds.width}#{Sketchup::RegionalSettings.list_separator} #{bounds.height}", SB_VCB_VALUE)

      if bounds.valid?

        if bounds.width == bounds.height && bounds.width != 0

          k_edge = Kuix::EdgeMotif3d.new
          k_edge.start.copy!(_fetch_option_rectangle_centered? ? @picked_shape_start_point.offset(@mouse_snap_point.vector_to(@picked_shape_start_point)) : @picked_shape_start_point)
          k_edge.end.copy!(@mouse_snap_point)
          k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          k_edge.color = normal_color
          @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

        end

        if _fetch_option_rectangle_centered?

          k_points = _create_floating_points(
            points: @picked_shape_start_point,
            style: Kuix::POINT_STYLE_PLUS
          )
          @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

          if bounds.width != bounds.height

            k_edge = Kuix::EdgeMotif3d.new
            k_edge.start.copy!(@picked_shape_start_point)
            k_edge.end.copy!(@mouse_snap_point)
            k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

          end

        end

        if view.pixels_to_model(30, bounds.min) < bounds.min.distance(bounds.max)

          if bounds.width != 0

            k_label = _create_floating_label(
              snap_point: bounds.min.offset(X_AXIS, bounds.width / 2).transform(t),
              text: bounds.width,
              text_color: Kuix::COLOR_X,
              border_color: normal_color
            )
            @tool.append_2d(k_label, LAYER_2D_DIMENSIONS)

          end

          if bounds.height != 0

            k_label = _create_floating_label(
              snap_point: bounds.min.offset(Y_AXIS, bounds.height / 2).transform(t),
              text: bounds.height,
              text_color: Kuix::COLOR_Y,
              border_color: normal_color
            )
            @tool.append_2d(k_label, LAYER_2D_DIMENSIONS)

          end

        end

      end

    end

    # -----

    def _read_shape(tool, text, view)
      return true if super

      d1, d2, d3 = _split_user_text(text)

      if d1 || d2

        t = _get_transformation(@picked_shape_start_point)
        ti = t.inverse

        p1 = @picked_shape_start_point.transform(ti)
        p2 = @mouse_snap_point.transform(ti)

        rectangle_centered = _fetch_option_rectangle_centered?

        base_length = p2.x - p1.x
        base_length *= 2 if rectangle_centered
        length = _read_user_text_length(tool, d1, base_length)
        return true if length.nil?
        length = length / 2 if rectangle_centered

        base_width = p2.y - p1.y
        base_width *= 2 if rectangle_centered
        width = _read_user_text_length(tool, d2, base_width)
        return true if width.nil?
        width = width / 2 if rectangle_centered

        @picked_shape_end_point = Geom::Point3d.new(p1.x + length, p1.y + width, p1.z).transform(t)

        set_state(STATE_PULL)
        _refresh

      end
      if d3

        t = _get_transformation(@picked_shape_start_point)
        ti = t.inverse

        p2 = @picked_shape_end_point.transform(ti)

        thickness = _read_user_text_length(tool, d3, 0)
        return true if thickness.nil?
        thickness = thickness / 2 if _fetch_option_pull_centered?

        @picked_pull_end_point = Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t)

        _create_entity
        _restart

        return true
      end

      true
    end

    # -----

    def _fetch_option_rectangle_centered?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED)
    end

    # -----

    def _valid_shape?

      points = _get_picked_points
      return false if points.length < 2

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      (p2.x - p1.x).round(6) != 0 && (p2.y - p1.y).round(6) != 0
    end

    def _valid_solid?

      points = _get_picked_points
      return false if points.length < 3

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      p1 = points[0].transform(ti)
      p3 = points[2].transform(ti)

      (p3.x - p1.x).round(6) != 0 && (p3.y - p1.y).round(6) != 0 && (p3.z - p1.z).round(6) != 0
    end

    # -----

    def _get_picked_points
      points = super

      if _fetch_option_rectangle_centered? && _picked_shape_start_point? && points.length > 1
        points[0] = points[0].offset(points[1].vector_to(points[0]))
      end

      points
    end

    # -----

    def _get_local_shape_points

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p2)

      [
        bounds.corner(0),
        bounds.corner(1),
        bounds.corner(3),
        bounds.corner(2)
      ]
    end

    def _get_local_shapes_points_with_offset(shape_offset = nil)
      shape_offset = _fetch_option_shape_offset if shape_offset.nil?

      bounds = Geom::BoundingBox.new
      bounds.add(_get_local_shape_points)

      o_min = bounds.min.offset(X_AXIS, -shape_offset).offset!(Y_AXIS, -shape_offset)
      o_max = bounds.max.offset(X_AXIS, shape_offset).offset!(Y_AXIS, shape_offset)

      o_bounds = Geom::BoundingBox.new
      o_bounds.add(o_min, o_max)

      [[
        o_bounds.corner(0),
        o_bounds.corner(1),
        o_bounds.corner(3),
        o_bounds.corner(2)
      ]]
    end

  end

  class SmartDrawCircleActionHandler < SmartDrawShapeActionHandler

    @@last_radius_measure = 0

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_CIRCLE, tool, previous_action_handler)
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string("tool.smart_draw.action_#{@action}_state_1_#{_fetch_option_measure_from_diameter? ? 'diameter' : 'radius'}_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_measure_locked_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_draw.action_option_options_measure_from_#{_fetch_option_measure_from_diameter? ? 'radius' : 'diameter'}_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string("tool.default.vcb_#{_fetch_option_measure_from_diameter? ? 'diameter' : 'radius'}")

      end

      super
    end

    # -----

    def onToolKeyDown(tool, key, repeat, flags, view)

      case @state

      when STATE_SHAPE
        if tool.is_key_shift?(key)
          _refresh
          return true
        end

      end

      super
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE
        if tool.is_key_shift?(key)
          _refresh
          return true
        end
        if tool.is_key_ctrl_or_option?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER, !_fetch_option_measure_from_diameter?, fire_event: true)
          Sketchup.set_status_text(get_state_status(fetch_state), SB_PROMPT)
          Sketchup.set_status_text(get_state_vcb_label(fetch_state), SB_VCB_LABEL)
          _refresh
          return true
        end

      end

      super
    end

    def onToolUserText(tool, text, view)
      return true if _read_segment_count(tool, text)
      super
    end

    protected

    def _snap_shape_start(flags, x, y, view)
      super

      # Force direction to default
      @locked_direction = nil
      @direction = nil

    end

    def _snap_shape(flags, x, y, view)

      @normal = @locked_normal if @locked_normal

      plane = [ @picked_shape_start_point, @normal ]

      if @mouse_ip.degrees_of_freedom > 2
        @mouse_snap_point = Geom.intersect_line_plane(view.pickray(x, y), plane)
      else
        @mouse_snap_point = @mouse_ip.position.project_to_plane(plane)
      end

      @direction = @picked_shape_start_point.vector_to(@mouse_snap_point.project_to_plane([ @picked_shape_start_point, @normal ])).normalize!

      # Lock on the last radius measure
      if @tool.is_key_shift_down? && @@last_radius_measure > 0
        measure = @@last_radius_measure
        v = @picked_shape_start_point.vector_to(@mouse_snap_point)
        @mouse_snap_point = @picked_shape_start_point.offset(v, measure) if measure > 0 && v.valid?
      end

      super
    end

    # -----

    def _preview_shape_start(view)
      super

      diameter = view.pixels_to_model(40, @mouse_snap_point)

      normal_color = _get_normal_color

      shape_offset = _fetch_option_shape_offset
      if shape_offset > 0
        offset = diameter * 0.2
      elsif shape_offset < 0
        offset = diameter * -0.2
      else
        offset = 0
      end

      if offset != 0

        k_circle = Kuix::CircleMotif3d.new(_fetch_option_segment_count)
        k_circle.bounds.size.set_all!(diameter)
        k_circle.line_width = 1
        k_circle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_circle.color = normal_color
        k_circle.on_top = true
        k_circle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation * Geom::Transformation.translation(Geom::Vector3d.new(-diameter / 2, -diameter / 2))
        @tool.append_3d(k_circle, LAYER_3D_DRAW_PREVIEW)

      end

      k_circle = Kuix::CircleMotif3d.new(_fetch_option_segment_count)
      k_circle.bounds.size.set_all!(diameter + offset)
      k_circle.line_width = @locked_normal ? 3 : 1.5
      k_circle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction?
      k_circle.color = normal_color
      k_circle.on_top = true
      k_circle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation * Geom::Transformation.translation(Geom::Vector3d.new(-(diameter + offset) / 2, -(diameter + offset) / 2))
      @tool.append_3d(k_circle, LAYER_3D_DRAW_PREVIEW)

    end

    def _preview_shape(view)

      measure_start = _fetch_option_measure_from_diameter? ? @picked_shape_start_point.offset(@mouse_snap_point.vector_to(@picked_shape_start_point)) : @picked_shape_start_point
      measure_vector = measure_start.vector_to(@mouse_snap_point)
      measure = measure_vector.length

      normal_color = _get_normal_color

      k_points = _create_floating_points(
        points: @picked_shape_start_point,
        style: Kuix::POINT_STYLE_PLUS
      )
      @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(measure_start)
      k_edge.end.copy!(@mouse_snap_point)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      k_edge.color = _get_direction_color
      @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

      t = _get_transformation(@picked_shape_start_point)

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 1.1
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_segments = _points_to_segments(o_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(o_segments)
        k_segments.line_width = @locked_normal ? 3 : _fetch_option_construction? ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction?
        k_segments.color = normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      Sketchup.set_status_text("#{measure}", SB_VCB_VALUE)

      if measure > 0 && view.pixels_to_model(30, measure_start) < measure

        k_label = _create_floating_label(
          snap_point: measure_start.offset(measure_vector, measure / 2),
          text: measure,
          text_color: Kuix::COLOR_X,
          border_color: _get_direction_color
        )
        @tool.append_2d(k_label, LAYER_2D_DIMENSIONS)

      end

    end

    # -----

    def _read_shape(tool, text, view)
      return true if super

      d1, d2 = _split_user_text(text)

      if d1

        measure_start = _fetch_option_measure_from_diameter? ? @picked_shape_start_point.offset(@mouse_snap_point.vector_to(@picked_shape_start_point)) : @picked_shape_start_point
        measure_vector = measure_start.vector_to(@mouse_snap_point)
        measure = measure_vector.length
        measure = _read_user_text_length(tool, d1, measure)
        return true if measure.nil?

        @picked_shape_end_point = @picked_shape_start_point.offset(measure_vector, _fetch_option_measure_from_diameter? ? measure / 2.0 : measure)

        if d2.nil?
          set_state(STATE_PULL)
          _refresh
        end

      end
      if d2

        t = _get_transformation(@picked_shape_start_point)
        ti = t.inverse

        p2 = @picked_shape_end_point.transform(ti)

        thickness = _read_user_text_length(tool, d2, 0)
        return true if thickness.nil?

        @picked_pull_end_point = Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t)

        _create_entity
        _restart

      end

      true
    end

    def _read_segment_count(tool, text)
      if (match = /^(.+)s$/i.match(text))

        value = match[1]
        segment_count = value.to_i

        if segment_count < 3 || segment_count > 999
          UI.beep
          @tool.notify_errors([ [ 'tool.default.error.invalid_segment_count', { :value => value } ] ])
          return true
        end

        @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_SEGMENTS, SmartDrawTool::ACTION_OPTION_SEGMENTS_SEGMENT_COUNT, segment_count, fire_event: true)
        Sketchup.set_status_text('', SB_VCB_VALUE)
        _refresh

        return true
      end

      false
    end

    # -----

    def _fetch_option_segment_count
      [ 999, [ @tool.fetch_action_option_integer(@action, SmartDrawTool::ACTION_OPTION_SEGMENTS, SmartDrawTool::ACTION_OPTION_SEGMENTS_SEGMENT_COUNT), 3 ].max ].min
    end

    def _fetch_option_smoothed?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_SMOOTHING)
    end

    def _fetch_option_measure_from_diameter?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER)
    end

    # -----

    def _valid_shape?

      points = _get_picked_points
      return false if points.length < 2

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      p1.distance(p2).round(6) > 0
    end

    # -----

    def _get_local_shape_points
      _get_local_shapes_points_with_offset(0).first
    end

    def _get_local_shapes_points_with_offset(shape_offset = nil)
      shape_offset = _fetch_option_shape_offset if shape_offset.nil?

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      segment_count = _fetch_option_segment_count
      unit_angle = Geometrix::TWO_PI / segment_count
      start_angle = X_AXIS.angle_between(Geom::Vector3d.new(p2.x, p2.y, 0))
      start_angle *= -1 if p2.y < 0
      circle_def = Geometrix::CircleDef.new(p1, p1.distance(p2) + shape_offset)

      [ Array.new(segment_count) { |i| Geometrix::CircleFinder.circle_point_at_angle(circle_def, start_angle + i * unit_angle) } ]
    end

    # -----

    def _create_faces(definition, t, ps, pe)
      @@last_radius_measure = ps.distance(pe)
      if _fetch_option_smoothed?
        edge = definition.entities.add_circle(ps.transform(t), Z_AXIS, ps.distance(pe) + _fetch_option_shape_offset, _fetch_option_segment_count).first
      else
        edge = definition.entities.add_ngon(ps.transform(t), Z_AXIS, ps.distance(pe) + _fetch_option_shape_offset, _fetch_option_segment_count).first
      end
      edge.find_faces
      edge.faces
    end

    def _get_auto_orient_transformation(definition, transformation = IDENTITY)

      points = _get_picked_points
      p1 = points[0]
      p2 = points[1]
      p3 = points[2]

      diameter = p1.distance(p2) * 2
      elevation = p2.distance(p3)

      # Set length (X axis) along elevation only if elevation > diameter
      if elevation > diameter
        return Geom::Transformation.axes(ORIGIN, Z_AXIS, Y_AXIS.reverse, X_AXIS)
      end

      IDENTITY
    end

  end

  class SmartDrawPolygonActionHandler < SmartDrawShapeActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_POLYGON, tool, previous_action_handler)

      @picked_points = []         # Geometry ordered
      @picked_points_stack = []   # Pick ordered

    end

    # -----

    def stop
      _erase_clines
      super
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SHAPE
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_draw.action_option_options_measure_reversed_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string('tool.default.vcb_length')

      end

      super
    end

    # -----

    def onToolCancel(tool, reason, view)
      if !_picked_shape_end_point? && @picked_points.any?
        if _remove_last_picked_point(view)
          super
        else
          _refresh
        end
      else
        super
      end
    end

    def onToolMouseMove(tool, flags, x, y, view)

      case @state

      when STATE_SHAPE_START
        super
        _add_picked_point(@picked_shape_start_point, view) if _picked_shape_start_point?
        return true

      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SHAPE_START
        super
        _add_picked_point(@picked_shape_start_point, view) if _picked_shape_start_point?
        return true

      when STATE_SHAPE
        if @picked_points.find { |point| point == @mouse_snap_point }
          if @picked_points.length >= 3
            return super
          else
            return false
          end
        end
        _add_picked_point(@mouse_snap_point, view)
        _refresh
        return true

      end

      super
    end

    def onToolLButtonDoubleClick(tool, flags, x, y, view)

      case @state

      when STATE_SHAPE
        onToolLButtonUp(tool, flags, x, y, view)  # 1. Complete STATE_SHAPE_POINTS
        # TODO : find a way to implement triple click
        return true   # super                              # 2. Process auto pull if possible

      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      case @state

      when STATE_SHAPE
        if key == VK_RIGHT
          x_axis = _get_active_x_axis
          if !x_axis.perpendicular?(@normal) && @picked_points.length >= 3
            UI.beep
            return true
          end
          if @locked_axis == x_axis
            @locked_axis = nil
            view.lock_inference
          else
            @locked_axis = x_axis
            p = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(x_axis)))
          end
          _refresh
          return true
        end
        if key == VK_LEFT
          y_axis = _get_active_y_axis
          if !y_axis.perpendicular?(@normal) && @picked_points.length >= 3
            UI.beep
            return true
          end
          if @locked_axis == y_axis
            @locked_axis = nil
            view.lock_inference
          else
            @locked_axis = y_axis
            p = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(y_axis)))
          end
          _refresh
          return true
        end
        if key == VK_UP
          z_axis = _get_active_z_axis
          if !z_axis.perpendicular?(@normal) && @picked_points.length >= 3
            UI.beep
            return true
          end
          if @locked_axis == z_axis
            @locked_axis = nil
            view.lock_inference
          else
            @locked_axis = z_axis
            p = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(z_axis)))
          end
          _refresh
          return true
        end
        if key == VK_DOWN
          UI.beep
          return true
        end

      end

      super
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE
        if tool.is_key_ctrl_or_option?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED, !_fetch_option_measure_reversed?, fire_event: true)
          Sketchup.set_status_text(get_state_status(fetch_state), SB_PROMPT)
          Sketchup.set_status_text(get_state_vcb_label(fetch_state), SB_VCB_LABEL)
          if view.inference_locked?
            p = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(@locked_axis)))
          end
          _refresh
          return true
        end
        if tool.is_key_shift?(key) && is_quick
          p = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
          _create_cline(p, p.vector_to(@mouse_snap_point))
        end

      end

      super
    end

    def onStateChanged(old_state, new_state)
      super

      _erase_clines if old_state == STATE_SHAPE

    end

    # -----

    protected

    def _set_picked_points_from_face_manipulator(face_manipulator, view)
      points = face_manipulator.outer_loop_manipulator.points
      @picked_shape_start_point = points.first
      @picked_shape_end_point = points.last
      points.each do |point|
        _add_picked_point(point, view)
      end
      true
    end

    def _add_picked_point(point, view)

      if _fetch_option_measure_reversed?
        # Prepend new point
        @picked_points.unshift(point)
      else
        # Push new point
        @picked_points << point
      end
      @picked_points_stack << point

      # Reset inference
      view.lock_inference if view.inference_locked?
      @locked_axis = nil

    end

    def _remove_last_picked_point(view)

      # Pop last picked point
      point = @picked_points_stack.pop
      @picked_points.delete(point)
      @picked_shape_start_point = nil if point == @picked_shape_start_point

      # Reset inference
      @locked_axis = nil
      view.lock_inference if view.inference_locked?

      @picked_points.empty?
    end

    # -----

    def _snap_shape_start(flags, x, y, view)
      super

      # Force direction to default
      @locked_direction = nil
      @direction = nil

    end

    def _snap_shape(flags, x, y, view)

      if @picked_points.length >= 3

        ph = view.pick_helper(x, y, 50)

        # Test previously picked points
        @picked_points.each do |point|

          # Test point themselves
          if ph.test_point(point)

            k_points = _create_floating_points(
              points: point,
              style: Kuix::POINT_STYLE_SQUARE,
              fill_color: Kuix::COLOR_BLACK,
              stroke_color: Kuix::COLOR_WHITE
            )
            @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

            if @locked_axis
              @mouse_snap_point = point.project_to_line([_fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last, @locked_axis ])
            else
              @mouse_snap_point = point
            end
            @mouse_ip.clear

            return
          end

        end

      end

      if @picked_points.length < 2

        ground_plane = [ @picked_shape_start_point, _get_active_z_axis ]

        if @mouse_ip.vertex

          if @locked_normal

            locked_plane = [ @picked_shape_start_point, @locked_normal ]

            @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?(ground_plane)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_x_axis ])

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_y_axis ])

            @normal = _get_active_y_axis

          else

            # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
            #
            # k_points = Kuix::Points.new
            # k_points.add_points([ vertex_manipulator.point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_SQUARE
            # k_points.stroke_color = Kuix::COLOR_MAGENTA
            # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)
            #
            # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
            #
            #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)
            #
            #   k_mesh = Kuix::Mesh.new
            #   k_mesh.add_triangles(face_manipulator.triangles)
            #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            #   @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)
            #
            # end

          end

        elsif @mouse_ip.edge

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          if @locked_normal

            locked_plane = [ @picked_shape_start_point, @locked_normal ]

            @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_z_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_z_axis)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_x_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_x_axis)

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_y_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_y_axis)

            @normal = _get_active_y_axis

          else

            unless @picked_shape_start_point.on_line?(edge_manipulator.line)

              plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_shape_start_point, edge_manipulator.start_point, edge_manipulator.end_point ]))

              @normal = plane_manipulator.normal

            end

            # @direction = cline_manipulator.direction

            # k_points = Kuix::Points.new
            # k_points.add_points([ @picked_shape_start_point.position, edge_manipulator.start_point, edge_manipulator.end_point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_TRIANGLE
            # k_points.stroke_color = Kuix::COLOR_BLUE
            # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(edge_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

          end

        elsif @mouse_ip.cline

          cline_manipulator = ClineManipulator.new(@mouse_ip.cline, @mouse_ip.transformation)

          if @locked_normal

            locked_plane = [ @picked_shape_start_point, @locked_normal ]

            @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_z_axis ]) && !cline_manipulator.direction.perpendicular?(_get_active_z_axis)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_x_axis ]) && !cline_manipulator.direction.perpendicular?(_get_active_x_axis)

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_start_point, _get_active_y_axis ]) && !cline_manipulator.direction.perpendicular?(_get_active_y_axis)

            @normal = _get_active_y_axis

          else

            unless cline_manipulator.infinite? || @picked_shape_start_point.on_line?(cline_manipulator.line)

              plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_shape_start_point, cline_manipulator.start_point, cline_manipulator.end_point ]))

              @normal = plane_manipulator.normal

            end

            # @direction = cline_manipulator.direction

            # k_points = Kuix::Points.new
            # k_points.add_points([ @picked_shape_start_point.position, cline_manipulator.start_point, cline_manipulator.end_point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_TRIANGLE
            # k_points.stroke_color = Kuix::COLOR_BLUE
            # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(cline_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

          end

        elsif @mouse_ip.face && @mouse_ip.degrees_of_freedom == 2

          if @locked_normal

            locked_plane = [ @picked_shape_start_point, @locked_normal ]

            @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
            @normal = @locked_normal

          else

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

            if @picked_shape_start_point.on_plane?(face_manipulator.plane)

              @normal = face_manipulator.normal

            else

              p1 = @picked_shape_start_point
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_PLUS
              # k_points.stroke_color = Kuix::COLOR_RED
              # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

              plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
              plane_manipulator = PlaneManipulator.new(plane)

              @direction = _get_active_z_axis
              @normal = plane_manipulator.normal

            end

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
            # @tool.append_3d(k_mesh, LAYER_3D_DRAW_PREVIEW)

          end

        else

          if @locked_normal

            locked_plane = [ @picked_shape_start_point, @locked_normal ]

            if @mouse_ip.degrees_of_freedom > 2
              @mouse_snap_point = Geom.intersect_line_plane(view.pickray(x, y), locked_plane)
            else
              @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
            end
            @normal = @locked_normal

          else

            if @mouse_ip.degrees_of_freedom > 2
              picked_point = Geom::intersect_line_plane(view.pickray(x, y), ground_plane)
              @mouse_ip.copy!(picked_point) unless picked_point.nil?
            end

            if !@mouse_ip.position.on_plane?(ground_plane)

              p1 = @picked_shape_start_point
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_CROSS
              # k_points.stroke_color = Kuix::COLOR_RED
              # @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

              plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
              plane_manipulator = PlaneManipulator.new(plane)

              @direction = _get_active_z_axis
              @normal = plane_manipulator.normal

            else

              @direction = nil
              @normal = _get_active_z_axis

            end

          end

        end

      elsif @picked_points.length == 2

        if @locked_normal

          locked_plane = [ @picked_shape_start_point, @locked_normal ]

          if @mouse_ip.degrees_of_freedom > 2
            @mouse_snap_point = Geom.intersect_line_plane(view.pickray(x, y), locked_plane)
          else
            @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
          end
          @normal = @locked_normal

        else

          p1 = @picked_points[0]
          p2 = @picked_points[1]
          p3 = @mouse_ip.position

          plane = Geom::fit_plane_to_points(p1, p2, p3)
          plane_manipulator = PlaneManipulator.new(plane)

          @normal = plane_manipulator.normal

        end

      else

        plane = [ @picked_shape_start_point, @normal ]

        if !@mouse_snap_point.nil?
          @mouse_snap_point = @mouse_snap_point.project_to_plane(plane)
          @mouse_ip.clear
        elsif @mouse_ip.degrees_of_freedom > 2
          @mouse_snap_point = Geom.intersect_line_plane(view.pickray(x, y), plane)
        else
          @mouse_snap_point = @mouse_ip.position.project_to_plane(plane)
        end

      end

      super

      if @picked_points.length >= 2 && @mouse_ip.degrees_of_freedom > 1

        po = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
        if (v = po.vector_to(@mouse_snap_point)).valid?

          line = [ po, v ]

          ph = view.pick_helper(x, y, 30)

          # Test previously picked points
          @picked_points.each do |point|

            pp = point.project_to_line(line)

            # Test point themselves
            if ph.test_point(pp)

              k_points = _create_floating_points(
                points: point,
                style: Kuix::POINT_STYLE_CIRCLE,
                fill_color: Kuix::COLOR_BLACK,
                stroke_color: Kuix::COLOR_WHITE
              )
              @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

              k_edge = Kuix::EdgeMotif3d.new
              k_edge.start.copy!(point)
              k_edge.end.copy!(pp)
              k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
              k_edge.color = Kuix::COLOR_MAGENTA
              @tool.append_3d(k_edge, LAYER_3D_DRAW_PREVIEW)

              @mouse_snap_point = pp
              @mouse_ip.clear

              return
            end

          end

        end

      end

    end

    # -----

    def _preview_shape_start(view)
      super

      width = view.pixels_to_model(40, @mouse_snap_point)
      height = width / 2

      normal_color = _get_normal_color

      shape_offset = _fetch_option_shape_offset
      if shape_offset > 0
        offset = width * 0.1
      elsif shape_offset < 0
        offset = width * -0.1
      else
        offset = 0
      end

      if offset != 0

        k_motif = Kuix::Motif3d.new([[

                                       [ 0, 0, 0 ],
                                       [ 1, 0, 0 ],
                                       [ 0.5, 1, 0 ],
                                       [ 0, 1, 0 ],
                                       [ 0, 0, 0 ]

                                     ]])
        k_motif.bounds.size.set!(width, height)
        k_motif.line_width = 1
        k_motif.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_motif.color = normal_color
        k_motif.on_top = true
        k_motif.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
        @tool.append_3d(k_motif, LAYER_3D_DRAW_PREVIEW)

      end

      k_motif = Kuix::Motif3d.new([[

                                     [ 0, 0, 0 ],
                                     [ shape_offset > 0 ? 1.1 : shape_offset < 0 ? 0.9 : 1, 0, 0 ],
                                     [ 0.5, 1, 0 ],
                                     [ 0, 1, 0 ],
                                     [ 0, 0, 0 ]

                                   ]])
      k_motif.bounds.origin.set!(-offset, -offset)
      k_motif.bounds.size.set!(width + 2 * offset, height + 2 * offset)
      k_motif.line_width = @locked_normal ? 3 : 1.5
      k_motif.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction?
      k_motif.color = normal_color
      k_motif.on_top = true
      k_motif.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
      @tool.append_3d(k_motif, LAYER_3D_DRAW_PREVIEW)

    end

    def _preview_shape(view)

      t = _get_transformation(@picked_shape_start_point)

      normal_color = _get_normal_color

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_segments = _points_to_segments(o_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(o_segments)
        k_segments.line_width = @locked_normal ? 3 : _fetch_option_construction? ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction?
        k_segments.color = normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

      end

      if @picked_points.length >= 1

        measure_start = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last
        measure_vector = measure_start.vector_to(@mouse_snap_point)
        measure = measure_vector.length

        Sketchup.set_status_text("#{measure}", SB_VCB_VALUE)

        k_points = _create_floating_points(
          points: measure_start,
          style: Kuix::POINT_STYLE_PLUS
        )
        @tool.append_3d(k_points, LAYER_3D_DRAW_PREVIEW)

        if measure_vector.valid?

          k_line = Kuix::Line.new
          k_line.position = measure_start
          k_line.direction = measure_vector
          k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
          k_line.color = _get_vector_color(measure_vector, Kuix::COLOR_DARK_GREY)
          @tool.append_3d(k_line, LAYER_3D_DRAW_PREVIEW)

          k_segments = Kuix::Segments.new
          k_segments.add_segments([ measure_start, @mouse_snap_point ])
          k_segments.line_width = @locked_axis ? 3 : _fetch_option_construction? ? 1 : 1.5
          k_segments.line_stipple = _fetch_option_shape_offset != 0 ? Kuix::LINE_STIPPLE_DOTTED : (_fetch_option_construction? ? Kuix::LINE_STIPPLE_LONG_DASHES : Kuix::LINE_STIPPLE_SOLID)
          k_segments.color = _get_vector_color(@locked_axis, normal_color)
          k_segments.on_top = true
          @tool.append_3d(k_segments, LAYER_3D_DRAW_PREVIEW)

          if view.pixels_to_model(60, measure_start) < measure

            k_label = _create_floating_label(
              snap_point: measure_start.offset(measure_vector, measure / 2),
              text: measure,
              border_color: normal_color
            )
            @tool.append_2d(k_label, LAYER_2D_DIMENSIONS)

          end

        end

      end

    end

    # -----

    def _read_shape_start(tool, text, view)
      if super && !@picked_shape_start_point.nil?
        _add_picked_point(@picked_shape_start_point, view)
        _refresh
      end
    end

    def _read_shape(tool, text, view)
      return true if super

      measure_start = _fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last

      # Check if input is a point with <> and [] notation
      p = _read_user_text_point(tool, text, @mouse_snap_point, measure_start)
      if p

        if @locked_normal || @picked_points.length >= 3
          # Project the input point if picked points already form a plan
          plane = [ @picked_shape_start_point, @normal ]
          p = p.project_to_plane(plane)
        elsif @picked_points.length >= 2
          # Update normal
          plane = Geom.fit_plane_to_points(@picked_points + [ p ])
          @normal = PlaneManipulator.new(plane).normal
        end

      else

        # Read a simple length
        measure_vector = measure_start.vector_to(@mouse_snap_point)
        measure = measure_vector.length
        measure = _read_user_text_length(tool, text, measure)
        return true if measure.nil?

        p = measure_start.offset(measure_vector, measure)
      end

      _add_picked_point(p, view)
      _refresh

      true
    end

    # -----

    def _fetch_option_measure_reversed?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED)
    end

    # -----

    def _reset
      super
      @picked_points.clear
    end

    # -----

    def _get_previous_input_point
      return super if _picked_shape_end_point?
      Sketchup::InputPoint.new(_fetch_option_measure_reversed? ? @picked_points.first : @picked_points.last)
    end

    # -----

    def _get_local_shape_points
      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse
      if _picked_shape_end_point?
        points = @picked_points.map { |point| point.transform(ti) }

        if _fetch_option_pull_centered?
          picked_points = _get_picked_points
          p1 = picked_points[0].transform(ti)
          points.each { |point| point.z = p1.z }
        end

      else
        points = (@picked_points + [ @mouse_snap_point ]).map { |point| point.transform(ti) }
      end

      points
    end

    def _get_local_shapes_points_with_offset(shape_offset = nil)
      shape_offset = _fetch_option_shape_offset if shape_offset.nil?
      points = _get_local_shape_points
      return [ points ] if shape_offset == 0 || points.length < 3
      paths, _ = Fiddle::Clippy.execute_union( closed_subjects: [ Fiddle::Clippy.points_to_rpath(points) ] )
      Fiddle::Clippy.inflate_paths(
        paths: paths,
        delta: shape_offset,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      ).map { |o_path| Fiddle::Clippy.rpath_to_points(o_path, points[0].z) }
       .delete_if { |o_points| o_points.size < 3 }  # Remove flat polygons
    end

    # -----

    def _create_cline(position, direction)
      (@clines ||= []) << Sketchup.active_model.active_entities.add_cline(position, direction)
    end

    def _erase_clines
      return unless @clines.is_a?(Array)
      Sketchup.active_model.active_entities.erase_entities(@clines)
      @clines.clear
    end

  end

  class SmartDrawDividerActionHandler < SmartDrawActionHandler

    include SmartActionHandlerPartHelper
    include FaceMatcherHelper

    STATE_PLACE = 0
    STATE_DISTRIBUTE = 1

    LAYER_3D_CAVITY_PREVIEW = 100
    LAYER_3D_DIVIDER_PREVIEW = 200

    LAYER_2D_DISTANCE = 100

    # Keeps the slab sides well clear of the target cavity bounds, so only
    # the cavity's own boundary (real panels, or the hull cap when the
    # cavity is open) ever clips the intersection - never the slab itself.
    DIVIDER_SLAB_MARGIN = 1.0

    # A body of the slab ∩ cavity intersection weighing less than this share
    # of the biggest one is a boolean sliver, not a compartment : each body
    # becomes a part of the model, so they are dropped rather than drawn.
    DIVIDER_FRAGMENT_MIN_VOLUME_SHARE = 1.0e-3

    # Below this dot-product gap, two candidates are considered equally
    # (im)perpendicular to the cavity's opening : the opening criterion does
    # not discriminate between them (e.g. the picked face's normal already
    # equals the opening normal, so both in-plane candidates are exactly
    # perpendicular to it), and the screen-based tie-break takes over.
    DIVIDER_NORMAL_OPENING_DOT_EPSILON = 1.0e-6

    attr_reader :locked_normal, :number, :spacings

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_DIVIDER, tool, previous_action_handler)

      @locked_normal = previous_action_handler.is_a?(self.class) ? previous_action_handler.locked_normal : nil
      @number = previous_action_handler.is_a?(self.class) ? previous_action_handler.number : 0
      @spacings = previous_action_handler.is_a?(self.class) ? previous_action_handler.spacings : []

      @picked_point = nil

    end

    # -----

    def get_state_picker(state)

      case state
      when STATE_PLACE
        return SmartPicker.new(tool: @tool, observer: self, pick_point: true, lockable: true)
      when STATE_DISTRIBUTE
        return SmartPicker.new(tool: @tool, observer: self, pick_point: true, lockable: false)
      end

      super
    end

    def get_state_status(state)

      case state
      when STATE_PLACE, STATE_DISTRIBUTE
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' + X = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_construction_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_measure_reversed_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_reduce_envelope_status') + '.'
      end

      super
    end

    def get_state_vcb_label(state)

      case state
      when STATE_PLACE
        return PLUGIN.get_i18n_string("tool.default.vcb_distance")
      when STATE_DISTRIBUTE
        return PLUGIN.get_i18n_string("tool.default.vcb_spacings")
      end

      super
    end

    # -----

    def onToolCancel(tool, reason, view)

      if @state == STATE_DISTRIBUTE
        if @spacings.any?
          _set_distribution(@number, [], tool, view)
        else
          _set_distribution(0, [], tool, view)
        end
        return true
      end

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      super

      case @state
      when STATE_PLACE, STATE_DISTRIBUTE
        if _create_entity(@picked_point, view)
          # The just-created divider is now real geometry in the model :
          # the cached cavities (and the fragment it was clipped to) are
          # stale, whatever the next divider picks must see it.
          @cavities_def = nil
          _refresh
        else
          UI.beep
        end
      end

      true
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super

      case @state

      when STATE_PLACE, STATE_DISTRIBUTE

        if tool.is_key_shift_down?
          if key == Kuix::VK_ADD
            _set_distribution(@number + 1, @spacings, tool, view)
            return true
          end
          if key == Kuix::VK_SUBTRACT
            _set_distribution(@number - 1, @spacings, tool, view)
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
          @locked_normal = nil
          _refresh
          return true
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_PLACE, STATE_DISTRIBUTE
        if tool.is_key_shift?(key)
          _refresh
          return true
        end
        if tool.is_key_ctrl_or_option?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED, !_fetch_option_measure_reversed?, fire_event: true)
          _refresh
          return true
        end
        if tool.is_key_alt_or_command?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, !_fetch_option_reduce_envelope?, fire_event: true)
          @cavities_def = nil
          @locked_normal = nil
          _refresh
          return true
        end

      end

    end

    def onToolUserText(tool, text, view)

      return true if _read_number(tool, text, view)
      return true if _read_spacings(tool, text, view)
      return true if _read_thickness(tool, text, view)
      return true if @state == STATE_PLACE && _read_distance(tool, text, view)

      false
    end

    def onPickerChanged(picker, view)
      case @state

      when STATE_PLACE, STATE_DISTRIBUTE
        _pick_part(picker, view)
        if has_active_part?
          if _snap_point(picker)
            @tool.remove_tooltip
            @tool.pop_cursor(SmartCursorManager.cursor_select_error)
          else
            @tool.show_tooltip(PLUGIN.get_i18n_string('tool.smart_draw.error.invalid_divider_cavity'), SmartTool::MESSAGE_TYPE_ERROR)
            @tool.push_cursor(SmartCursorManager.cursor_select_error)
          end
        end
        _preview_divider(view)
        _preview_cavity
      end

      super
    end

    def onToolActionOptionStored(tool, action, option_group, option)

      case option_group
      when SmartDrawTool::ACTION_OPTION_MEASURE_TYPE
        _refresh
      when SmartDrawTool::ACTION_OPTION_AXES
        @locked_normal = nil
        _refresh
      end

    end

    def onToolTransactionUndo(tool, model)
      @cavities_def = nil
      super
    end

    # -----

    protected

    # -----

    def _reset
      @cavities_def = nil
      @picked_point = nil
      @locked_normal = nil
      @number = 0
      @spacings = []
      super
    end

    def _refresh
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      return [ false, 'tool.smart_draw.error.invalid_divider_seed' ] unless (!part.is_a?(Part) || part.group.material_type != MaterialAttributes::TYPE_HARDWARE)
      return [ false, 'tool.smart_draw.error.invalid_divider_container' ] if !part_entity_path.nil? && part_entity_path.one?

      # The inherited tests first : no point paying for a cavity detection on a part that will be refused anyway.
      can_activate, _ = super_result = super
      return super_result unless can_activate

      return [ false, 'tool.smart_draw.error.no_divider_cavity' ] if (cavities_def = _get_cavities_def(part_entity_path, part)).is_a?(CavitiesDef) && cavities_def.valid? && cavities_def.fragment_defs.empty?

      super_result
    end

    def _preview_part_mesh?
      false
    end

    def _preview_part_container?
      true
    end

    def _preview_part_container_axes?
      _fetch_option_axes_context?
    end

    # -----

    def _snap_point(picker)
      if has_active_part? && (picked_plane_manipulator = picker.picked_plane_manipulator).is_a?(PlaneManipulator)
        @picked_point = picker.picked_point.project_to_plane(picked_plane_manipulator.plane)
        return (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid? &&
               !cavities_def.fragment_defs.empty? &&
               _get_cavity_fragment_def(cavities_def, @picked_point, picked_plane_manipulator).is_a?(SolidCavityFragmentDef)
      else
        @picked_point = nil
        return false
      end
    end

    # -----

    def _preview_cavity

      @tool.clear_3d(LAYER_3D_CAVITY_PREVIEW)

      return unless @picked_point.is_a?(Geom::Point3d)
      return unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      color = Kuix::COLOR_BLUE

      active_fragment_defs = cavities_def.fragment_defs_for_point(@picked_point)
      active_fragment_defs.each do |fragment_def|

        segments = fragment_def.unique_boundary_segments

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.color = color
        k_segments.line_width = 1
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_CAVITY_PREVIEW)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.color = color
        k_segments.line_width = 1.5
        @tool.append_3d(k_segments, LAYER_3D_CAVITY_PREVIEW)

        fragment_def.each_triangle_batch do |_, triangles|

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(triangles.flatten)
          k_mesh.cull_face = Kuix::CULL_FACE_BACK # The fragment is a closed volume : without culling its near and far walls would blend on the same pixels and the tint would darken where they overlap
          k_mesh.background_color = ColorUtils.color_translucent(color, 0.05)
          @tool.append_3d(k_mesh, LAYER_3D_CAVITY_PREVIEW)

        end

      end

    end

    def _preview_divider(view)

      @tool.clear_3d(LAYER_3D_DIVIDER_PREVIEW)
      @tool.clear_2d(LAYER_2D_DISTANCE)

      return unless (divider_defs = _compute_dividers(@picked_point, view)).is_a?(Array)

      color = _get_vector_color(@locked_normal, Kuix::COLOR_MAGENTA)

      divider_defs.each do |divider_def|
        divider_def.fragments.each do |fragment|

          # face_info_defs is irrelevant here : the preview only needs the geometry (boundary_segments doesn't dereference it).
          divider_fragment_def = SolidFragmentDef.new(fragment['vertices'], fragment['face_indices'], fragment['face_ids'], [])
          next if divider_fragment_def.empty?

          segments = divider_fragment_def.unique_boundary_segments

          k_segments = Kuix::Segments.new
          k_segments.add_segments(segments)
          k_segments.color = color
          k_segments.line_width = 1
          k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
          k_segments.on_top = true
          @tool.append_3d(k_segments, LAYER_3D_DIVIDER_PREVIEW)

          unless _fetch_option_construction?

            k_segments = Kuix::Segments.new
            k_segments.add_segments(segments)
            k_segments.color = color
            k_segments.line_width = @locked_normal ? 2.5 : 1.5
            @tool.append_3d(k_segments, LAYER_3D_DIVIDER_PREVIEW)

          end

        end
      end

      fn_preview_measure = lambda { |ps, pe, distance|

        # Preview line

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(ps)
        k_edge.end.copy!(pe)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.color = ColorUtils.color_translucent(color, 60)
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_DIVIDER_PREVIEW)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(ps)
        k_edge.end.copy!(pe)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.color = color
        @tool.append_3d(k_edge, LAYER_3D_DIVIDER_PREVIEW)

        case @state
        when STATE_PLACE
          fill_color = Kuix::COLOR_WHITE
          stroke_color = color
          size = 2
        when STATE_DISTRIBUTE
          fill_color = color
          stroke_color = nil
          size = 1
        end
        @tool.append_3d(_create_floating_points(points: [ ps, pe ], style: Kuix::POINT_STYLE_CIRCLE, fill_color: fill_color, stroke_color: stroke_color, size: size), LAYER_3D_DIVIDER_PREVIEW)

        # Preview distance

        k_label = _create_floating_label(
          snap_point: Geom.linear_combination(0.5, ps, 0.5, pe),
          text: distance.to_l.to_s,
          text_color: color,
          border_color: color
        )
        @tool.append_2d(k_label, LAYER_2D_DISTANCE)

      }

      # One measure per compartment : in free mode the single gap between the
      # pick and the cavity's wall, in distributed mode the clear opening
      # BEFORE each divider - plus the one the LAST divider closes on the
      # cavity itself, which belongs to no divider's own measure.
      divider_defs.each_with_index do |divider_def, index|

        distance = divider_def.distance
        if distance > 0
          fn_preview_measure.call(divider_def.wall_point, divider_def.point, distance)
          Sketchup.set_status_text(distance, SB_VCB_VALUE) if index == 0 && @state == STATE_PLACE
        end

        trailing_distance = divider_def.trailing_distance
        if !trailing_distance.nil? && trailing_distance > 0
          fn_preview_measure.call(divider_def.trailing_point, divider_def.trailing_wall_point, trailing_distance)
        end

      end

    end

    # -----

    def _read_number(tool, text, view)
      return false unless text.is_a?(String) && (match = text.match(/^([x*\/])(\d+)$/))

      operator, value = match[1, 2]

      number = value.to_i

      if operator == '/' && number < 2
        UI.beep
        tool.notify_errors([ [ 'tool.default.error.invalid_divider', { :value => value } ] ])
        return true
      end

      _set_distribution(operator == '/' ? number - 1 : number, @spacings, tool, view)
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # A list of lengths - "100;200", regional list divider, "100=" repeating
    # a value (see #_split_user_text) - PINS the clear openings of the current
    # distribution instead of leaving them all equal. Same VCB grammar and
    # same reading as the Smart Handle "distribute" action : the leading run
    # pins from the near end of the cavity, the trailing run from the far end,
    # an invalid or empty entry marking where the free middle begins - "100;"
    # pins only the first opening, ";100" only the last. See
    # #_get_divider_slab_intervals.
    def _read_spacings(tool, text, view)

      list = _split_user_text(text)
      return false unless list.is_a?(Array) && list.size > 1

      # An entry that is not a length at all is not an error here : it is how
      # the user says "leave this one free"
      spacings = list.map { |spacing|
        length = _read_user_text_length(tool, spacing, -1)
        length.nil? || length == -1 ? -1 : length.abs.to_l
      }

      number = [ @number, spacings.select { |spacing| spacing > 0 }.size ].max

      _set_distribution(number, spacings, tool, view)
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    def _read_distance(tool, text, view)
      # A typed distance places THE divider against the cavity's wall : in
      # distributed mode the positions are computed, there is nothing to place.
      return false unless @number == 0
      return false unless (divider_def = _compute_dividers(@picked_point, view).to_a.first).is_a?(DividerDef)

      distance = _read_user_text_length(tool, text, divider_def.distance)
      return true if distance.nil?

      if distance < 0
        tool.notify_errors([[ 'tool.default.error.invalid_length', { :value => distance } ]])
        return true
      end

      if _create_entity(divider_def.wall_point.offset(divider_def.normal, distance), view)
        Sketchup.set_status_text('', SB_VCB_VALUE)
        _restart
        return true
      end

      false
    end

    def _read_thickness(tool, text, view)

      # Keep it "compatible" with the way to enter offset in Smart Draw Tool.
      if (match = /^(.+)x$/i.match(text))
        text = match[1]
      else
        return false
      end

      thickness = _read_user_text_length(tool, text)
      return true if thickness.nil?

      if thickness < 0
        tool.notify_errors([[ 'tool.default.error.invalid_thickness', { :value => thickness } ]])
        return true
      end

      @tool.store_action_option_value(@action, SmartReshapeTool::ACTION_OPTION_THICKNESS, SmartReshapeTool::ACTION_OPTION_THICKNESS_THICKNESS, thickness.to_s, fire_event: true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _fetch_option_thickness
      @tool.fetch_action_option_length(@action, SmartReshapeTool::ACTION_OPTION_THICKNESS, SmartReshapeTool::ACTION_OPTION_THICKNESS_THICKNESS)
    end

    def _fetch_option_measure_reversed?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED)
    end

    def _fetch_option_reduce_envelope?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE)
    end

    def _fetch_option_reuse_definition?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
    end

    def _fetch_option_measure_type_inside?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE_INSIDE)
    end

    def _fetch_option_measure_type_outside?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE_OUTSIDE)
    end

    def _fetch_option_axes_context?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_AXES, SmartDrawTool::ACTION_OPTION_AXES_CONTEXT)
    end

    # -----

    # Rebuilds the divider fragments as real geometry inside the model,
    # names and selects the resulting part - the same tail conventions
    # (ask_name option / success notification) as the other draw handlers'
    # _create_entity. When the construction option is on, only the outline
    # is drawn (as clines, in a plain group) instead of a real solid part -
    # same "construction, not a part" contract as the other draw handlers,
    # so no naming / success notification happens in that case either.
    # Returns true on success, false when there is nothing valid to build
    # (no pick, no cavity, degenerate intersection).
    def _create_entity(point, view)
      return false unless (divider_defs = _compute_dividers(point, view)).is_a?(Array) && !divider_defs.empty?

      container_path = divider_defs.first.container_path
      if container_path.is_a?(Array) && container_path.any? && (container = container_path.last) && container.respond_to?(:definition)
        active_entities = container.definition.entities
        active_transformation = PathUtils.get_transformation(container_path, IDENTITY)
      else
        active_entities = Sketchup.active_model.entities
        active_transformation = IDENTITY
        container_path = []
      end

      model = Sketchup.active_model
      model.start_operation('OCL Create Separator', true, false, !active?)
      begin

        # Definitions this batch actually BUILT - what the naming applies to
        # (one when the parts share it, as many as parts when the reuse
        # option is off), and the last one a part turned out to be one more
        # occurrence of.
        created_definitions = []
        reused_definition = nil

        # Entities the batch actually added to the model : a divider whose
        # slab was clipped into several disjoint bodies builds one part per
        # body (see below), so this is NOT the divider count.
        created_entity_count = 0

        # The parts of one batch, as candidates for the next ones :
        # #_find_reusable_definition only knows the parts that were already
        # there when the cavities were computed, so without this the second
        # divider of a distribution would never recognize the first - the
        # very part it is a repetition of. Same shape, same neighbourhood
        # criteria as any other candidate : a cavity that is not prismatic
        # along the normal clips them differently, and they stay distinct
        # parts.
        sibling_part_defs = []

        divider_defs.each do |divider_def|

          normal_3f = divider_def.normal_3f
          u, v = _get_divider_plane_uv_3f(normal_3f)

          # One part per disjoint body the divider's slab was clipped into :
          # a "U" cavity divided across both its branches leaves two boards,
          # not one board in two pieces (see #_compute_dividers).
          divider_def.fragments.each do |fragment|

            # Local frame for the new part : Z = thickness axis (the chosen
            # divider normal), X/Y = the slab's own in-plane basis, origin on
            # the slab's reference plane at this body's own corner. u, v,
            # normal is right-handed by construction
            # (_get_divider_plane_basis), so this transformation is a pure
            # rotation - never a mirror.
            world_transformation = Geom::Transformation.axes(_get_divider_fragment_origin(divider_def, fragment, u, v), Geom::Vector3d.new(u), Geom::Vector3d.new(v), Geom::Vector3d.new(normal_3f))

            if _fetch_option_construction?

              group = active_entities.add_group
              group.transformation = active_transformation.inverse * world_transformation

              created_faces = _build_divider_faces(group.entities, [ fragment ], world_transformation)
              if created_faces.empty?
                group.erase!
                next
              end

              edges = created_faces.flat_map(&:edges).uniq
              edges.each { |edge| group.entities.add_cline(edge.start.position, edge.end.position) }
              group.entities.erase_entities(created_faces + edges)

              created_entity_count += 1

              next
            end

            definition = model.definitions.add(PLUGIN.get_i18n_string('default.part_single').capitalize)

            # A body the boolean left unbuildable is skipped rather than
            # fatal : the other bodies - and the other dividers - of the
            # batch are legitimate, and must not fall with it.
            created_faces = _build_divider_faces(definition.entities, [ fragment ], world_transformation)
            if created_faces.empty?
              model.definitions.remove(definition) if model.definitions.respond_to?(:remove)
              next
            end

            candidate_definition, candidate_world_transformation = _find_reusable_definition(fragment, created_faces, world_transformation, sibling_part_defs)

            if candidate_definition.nil?

              tao = _get_auto_orient_transformation(definition, world_transformation)
              unless tao.identity?

                world_transformation = world_transformation * tao
                taoi = tao.inverse

                # Transform definition's entities
                entities = definition.entities
                entities.transform_entities(taoi, entities.to_a)

              end

              instance = active_entities.add_instance(definition, active_transformation.inverse * world_transformation)

              # Force UUID to be generated in the creation operation
              DefinitionAttributes.new(definition).uuid

              created_definitions << definition

            else

              # The part is one more occurrence of a part that is already
              # there : the freshly built geometry is thrown away and the
              # existing definition is instanced instead - see
              # #_find_reusable_definition
              model.definitions.remove(definition) if model.definitions.respond_to?(:remove)
              definition = candidate_definition
              world_transformation = candidate_world_transformation
              instance = active_entities.add_instance(definition, active_transformation.inverse * world_transformation)

              reused_definition = definition

            end

            sibling_part_defs << _get_divider_part_def(container_path, instance, world_transformation) if _fetch_option_reuse_definition?

            created_entity_count += 1

          end

        end

        if created_entity_count == 0
          model.abort_operation
          return false
        end

        if active? && !_fetch_option_construction?

          new_definition = created_definitions.first
          count = created_entity_count

          fn_ask_name = lambda {
            unless new_definition.nil? || new_definition.deleted?
              if (data = UI.inputbox([ PLUGIN.get_i18n_string('tab.cutlist.edit_part.name') ], [ new_definition.name ], PLUGIN.get_i18n_string('default.rename')))
                name = data.first
                if name.empty?
                  UI.beep
                else
                  # One name for the whole batch : with the reuse option off,
                  # a distribution builds as many definitions as dividers,
                  # and they are all the part the user just named
                  created_definitions.each { |created_definition| created_definition.name = name unless created_definition.deleted? }
                end
              end
            end
          }

          if new_definition.nil?
            # Renaming here would rename the part they were reused from too : only the plain notification makes sense
            @tool.notify_success(PLUGIN.get_i18n_string("tool.smart_draw.success.part_reused", { :name => reused_definition.nil? ? '' : reused_definition.name, :count => count }))
          elsif _fetch_option_ask_name?
            fn_ask_name.call
          else
            @tool.notify_success(
              PLUGIN.get_i18n_string("tool.smart_draw.success.part_created", { :name => new_definition.name, :count => count }),
              [
                {
                  :label => PLUGIN.get_i18n_string('default.rename'),
                  :block => fn_ask_name,
                }
              ]
            )
          end

        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
        return false
      end

      true
    end

    # Turns the raw Meshy fragments (world coordinates) into real, coplanar-
    # merged Sketchup::Face geometry inside +entities+, expressed in the
    # given transformation's local space. Deliberately simpler than
    # CommonSolidBooleanApplyWorker#_solid_fragments_to_geometry : the whole
    # definition is fresh (never touches pre-existing geometry) and carries
    # a single new part, so there is no per-face material/layer/curve
    # provenance to restore - any two coplanar adjacent faces merge
    # unconditionally.
    def _build_divider_faces(entities, fragments, world_transformation)
      ti = world_transformation.inverse
      flipped = TransformationUtils.flipped?(world_transformation)

      fragments.each do |fragment|
        vertices = fragment['vertices']
        face_indices = fragment['face_indices']

        points = vertices.each_slice(3).map { |x, y, z| Geom::Point3d.new(x, y, z).transform(ti) }

        mesh = Geom::PolygonMesh.new(points.length, face_indices.length / 3)
        face_indices.each_slice(3) do |a, b, c|
          triangle = [ points[a], points[b], points[c] ]
          triangle.reverse! if flipped
          mesh.add_polygon(triangle)
        end

        entities.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE)
      end

      faces = entities.grep(Sketchup::Face)
      return [] if faces.empty?

      # Merge coplanar adjacent faces (native solid tools do the same) :
      # erase only when SketchUp will actually merge the two faces (same
      # oriented normal, truly coplanar within tolerance), otherwise erasing
      # the edge would erase both faces and leave a hole.
      edges_to_erase = []
      entities.grep(Sketchup::Edge).each do |edge|
        edge_faces = edge.faces
        next unless edge_faces.length == 2
        face_0, face_1 = edge_faces
        next unless face_0.normal.samedirection?(face_1.normal) && face_1.outer_loop.vertices.all? { |vertex| vertex.position.on_plane?(face_0.plane) }
        edges_to_erase << edge
      end
      entities.erase_entities(edges_to_erase) if edges_to_erase.any?

      # Degenerate remnants : Manifold may emit a sliver triangle thinner
      # than the SketchUp merge tolerance ; a face with less than 3 edges is
      # never a legitimate piece of the shell.
      degenerate_faces = faces.select { |face| !face.deleted? && face.edges.length < 3 }
      unless degenerate_faces.empty?
        degenerate_entities = []
        degenerate_faces.each do |face|
          degenerate_entities.concat(face.edges.select { |edge| edge.faces.all? { |edge_face| degenerate_faces.include?(edge_face) } })
          degenerate_entities << face
        end
        entities.erase_entities(degenerate_entities)
      end

      faces.reject(&:deleted?)
    end

    # -----

    # Applies a new distribution - how many dividers, and which openings are
    # pinned - then previews it, reporting the one thing the user cannot see
    # coming : a layout whose dividers no longer fit in the cavity they were
    # asked for. It is still stored in that case - the pick may well land in a
    # roomier cavity next.
    def _set_distribution(number, spacings, tool, view)

      @number = [ number, 0 ].max
      @spacings = spacings

      if @number > 0 && !(context = _compute_divider_context(@picked_point, view)).nil?
        _cavities_def, fragment_def, normal_3f = context
        n0, n1 = _get_divider_mesh_extent(fragment_def.vertices, normal_3f)
        if _get_divider_slab_intervals(n0, n1, _fetch_option_thickness, @number, @spacings).nil?
          UI.beep
          tool.notify_errors([ [ 'tool.smart_draw.error.divider_number_overflow', { :number => @number } ] ])
        end
      end

      if @number > 0
        set_state(STATE_DISTRIBUTE) unless @state == STATE_DISTRIBUTE
      else
        set_state(STATE_PLACE) unless @state == STATE_PLACE
      end
      _refresh
    end

    # -----

    def _get_edit_transformation
      return PathUtils.get_transformation(get_active_part_entity_path[0...-1], IDENTITY) if _fetch_option_axes_context?
      super
    end

    # -----

    # The cavities of the given part's container - by default the ACTIVE
    # part's. The explicit parameters exist for #_can_activate_part?, which
    # runs BEFORE the part it examines is activated and so cannot rely on the
    # active one.
    def _get_cavities_def(part_entity_path = get_active_part_entity_path, part = get_active_part)
      return nil unless part_entity_path.is_a?(Array) && part_entity_path.length > 1

      container_path = part_entity_path[0...-1]
      return nil if container_path.empty?

      container = container_path.last
      return nil if container.nil?

      # Cavities belong to the CONTAINER, not to the picked part : sliding the
      # pick from one panel to another of the same box must reuse the boolean
      # pass rather than pay for it again. Comparing the paths compares the
      # entities themselves, so a #_make_unique_groups_in_path that replaced
      # them invalidates the cache - which is exactly what it should do.
      return @cavities_def if @cavities_def.is_a?(CavitiesDef) && @cavities_def.container_path == container_path

      return nil if !part.is_a?(Part) || part.group.material_is_virtual || part.group.material_type == MaterialAttributes::TYPE_HARDWARE

      cutlist = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_options'))
                                                     .merge({ active_entity: container, active_path: container_path[0...-1] })
      ).run

      parts = cutlist.groups
                     .reject { |group| group.material_is_virtual || group.material_type == MaterialAttributes::TYPE_HARDWARE}
                     .flat_map { |group| group.get_parts }
      drawing_defs = parts.flat_map { |container_part|
        container_part.def.instance_infos.values.map { |instance_info|
          CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(instance_info.path) ],
                                               ignore_surfaces: true,
                                               ignore_edges: true,
                                               container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS_AND_CUTS_OPENING
          ).run
        }
      }

      result_def = CommonSolidFindCavitiesWorker.new(drawing_defs,
                                                     max_opening_planes: 4,
                                                     reduce_envelope: _fetch_option_reduce_envelope?
      ).run

      @cavities_def = CavitiesDef.new(container_path, result_def, drawing_defs)

      unless result_def.success?
        @tool.notify_errors(result_def.errors)
      end

      @cavities_def
    end

    # -----

    # A freshly created divider, in the shape #_find_reusable_definition's
    # candidate pool expects : [ occurrence path, instance, WORLD face
    # manipulators, face planes ]. Read off the definition AFTER the auto
    # orientation has moved its entities, so the manipulators land where the
    # part really is.
    def _get_divider_part_def(container_path, instance, world_transformation)
      face_manipulators = instance.definition.entities.grep(Sketchup::Face).map { |face| FaceManipulator.new(face, world_transformation) }
      [ container_path + [ instance ], instance, face_manipulators, _get_face_planes(face_manipulators) ]
    end

    # WORLD origin of the local frame a fragment's part is built in : on the
    # slab's own reference plane (+divider_def+'s point), but at the
    # fragment's own low corner in the slab plane. All the bodies of one slab
    # would otherwise share the pick's lateral position, leaving the axes of
    # the part built from the far branch of a "U" cavity well outside its own
    # material.
    def _get_divider_fragment_origin(divider_def, fragment, u, v)
      normal_3f = divider_def.normal_3f
      vertices = fragment['vertices']

      du = _get_divider_mesh_extent(vertices, u).first
      dv = _get_divider_mesh_extent(vertices, v).first

      # Point3d coordinates are Lengths : to_f keeps the recomposition in plain Float
      point_3f = divider_def.point.to_a.map { |coord| coord.to_f }
      dn = normal_3f[0] * point_3f[0] + normal_3f[1] * point_3f[1] + normal_3f[2] * point_3f[2]

      # (u, v, normal) is orthonormal, so recomposing from the three
      # coordinates is exact.
      Geom::Point3d.new(
        u[0] * du + v[0] * dv + normal_3f[0] * dn,
        u[1] * du + v[1] * dv + normal_3f[1] * dn,
        u[2] * du + v[2] * dv + normal_3f[2] * dn
      )
    end

    # [ definition, WORLD transformation ] of an existing part the one just
    # built is one more occurrence of, or nil : the caller then throws
    # its freshly built geometry away and instances that definition instead,
    # so the two are ONE part in the cutlist rather than two identical ones.
    # nil unless the reuse option is on.
    #
    # Two criteria, cheapest first :
    #
    # - the SHAPE. One of the candidate's faces must be congruent to the
    #   divider's own main face - matched by FaceMatcherHelper's quantized
    #   signature (hashable, so the whole pass is O(n)) then verified
    #   geometrically - and superposable by a PROPER motion, never a mirrored
    #   one, which would place a flipped instance. The transformation that
    #   superposes them must then land the candidate's whole bounds on the
    #   divider's own : that settles the thickness, and which way the
    #   material goes from the matched face (aligning a part's top face onto
    #   the divider's bottom one superposes the faces but not the solids).
    #
    # - the NEIGHBOURHOOD. The candidate must touch exactly the same part
    #   instances the divider touches (see #_get_touching_part_ids). Same
    #   shape in the same place is what makes it the SAME part repeated - a
    #   second shelf between the very sides the first one already spans. Same
    #   shape elsewhere is a coincidence (a divider cut like a shelf, an
    #   identical shelf in a different compartment), and sharing a definition
    #   there would silently link two parts the user means to keep apart :
    #   editing one would edit the other.
    #
    # +sibling_part_defs+ carries the parts the SAME batch has already created
    # (see #_get_divider_part_def) : the cavities - hence the candidate pool
    # below - were computed before any of them existed, so a distribution
    # would otherwise never see its own parts as candidates for one another.
    # They are examined last, so an eligible part that was already in the
    # model still wins.
    def _find_reusable_definition(fragment, created_faces, world_transformation, sibling_part_defs = [])
      return nil unless _fetch_option_reuse_definition?
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)

      drawing_defs = cavities_def.drawing_defs
      return nil unless drawing_defs.is_a?(Array) && !drawing_defs.empty?

      bounds = _get_divider_fragment_bounds(fragment)
      return nil if bounds.nil? || bounds.empty?

      divider_manipulators = created_faces.map { |face| FaceManipulator.new(face, world_transformation) }
      reference_manipulator = divider_manipulators.max_by { |face_manipulator| face_manipulator.face.area(face_manipulator.transformation) }
      return nil if reference_manipulator.nil?

      # [ occurrence path, instance, WORLD face manipulators, face planes ] of
      # every part of the container, computed once : the neighbourhood of each
      # candidate is read against the same set the divider's own is
      part_defs = drawing_defs.map { |drawing_def|
        path = drawing_def.container_path
        next nil unless path.is_a?(Array) && !path.empty?
        instance = path.last
        next nil unless instance.respond_to?(:definition) && !instance.deleted?
        face_manipulators = drawing_def.face_manipulators.map { |face_manipulator|
          FaceManipulator.new(face_manipulator.face, drawing_def.transformation * face_manipulator.transformation)
        }
        [ path, instance, face_manipulators, _get_face_planes(face_manipulators) ]
      }.compact
      part_defs += sibling_part_defs

      # A divider touching nothing has no neighbourhood to compare : no reuse
      touching_part_ids = _get_touching_part_ids(_get_face_planes(divider_manipulators), part_defs)
      return nil if touching_part_ids.empty?

      part_defs.each do |path, instance, face_manipulators, face_planes|

        instance_transformation = PathUtils.get_transformation(path, IDENTITY)

        candidate_transformation = nil
        face_manipulators.each do |face_manipulator|
          transformation = _face_manipulators_alignment_transformation(reference_manipulator, face_manipulator, mirror: false)
          next if transformation.nil?
          transformation = transformation * instance_transformation
          next unless _bounds_superpose?(_get_definition_bounds(instance.definition, transformation), bounds)
          candidate_transformation = transformation
          break
        end
        next if candidate_transformation.nil?

        next unless _get_touching_part_ids(face_planes, part_defs, exclude_path: path) == touching_part_ids

        return [ instance.definition, candidate_transformation ]
      end

      nil
    end

    # Identifiers of the parts the given faces are in CONTACT with : one of
    # their faces must lie on the same plane as one of the part's, facing it,
    # and the two must overlap there on a real area - the way one board meets
    # another. Sorted, so two neighbourhoods compare with a plain ==.
    #
    # Faces rather than bounds : a bounding box test would be far cheaper, but
    # it is only sound on an axis aligned assembly. Everything here is in
    # WORLD coordinates, so a cabinet drawn at an angle - or merely nested in
    # a rotated container - would see every box inflate around its part and
    # invent neighbours, differently for each part, quietly turning the reuse
    # off. A plane match is invariant by rotation.
    def _get_touching_part_ids(face_planes, part_defs, exclude_path: nil)
      part_defs.map { |path, _instance, _face_manipulators, other_face_planes|
        next nil if path == exclude_path
        next nil unless face_planes.any? { |face_plane|
          other_face_planes.any? { |other_face_plane| _face_planes_touch?(face_plane, other_face_plane) }
        }
        path.map { |entity| entity.entityID }
      }.compact.sort
    end

    # [ normal, offset, outer loop points ] per face, in WORLD coordinates -
    # what #_face_planes_touch? needs, extracted once per part.
    def _get_face_planes(face_manipulators)
      face_manipulators.map { |face_manipulator|
        points = face_manipulator.outer_loop_manipulator.points
        next nil if points.length < 3
        normal_3f = face_manipulator.normal.to_a
        origin_3f = points.first.to_a
        [ normal_3f, normal_3f[0] * origin_3f[0] + normal_3f[1] * origin_3f[1] + normal_3f[2] * origin_3f[2], points ]
      }.compact
    end

    # True when the two faces are in contact : they must FACE each other
    # (opposite outward normals - two boards in contact each expose the face
    # the other pushes against), lie on the same plane within the mesh
    # tolerance, and overlap there on both axes of that plane. The overlap is
    # measured on the outer loops' extents in the plane's own basis, so it
    # follows the assembly's orientation ; it may read as a contact where two
    # notched outlines only interleave, which merely gives up a reuse.
    def _face_planes_touch?(face_plane_a, face_plane_b)
      normal_3f_a, offset_3f_a, points_a = face_plane_a
      normal_3f_b, offset_3f_b, points_b = face_plane_b

      return false if normal_3f_a[0] * normal_3f_b[0] + normal_3f_a[1] * normal_3f_b[1] + normal_3f_a[2] * normal_3f_b[2] > -0.9999
      return false if (offset_3f_a + offset_3f_b).abs > SolidMeshDef::TOLERANCE

      u, v = _get_divider_plane_uv_3f(normal_3f_a)
      [ u, v ].all? do |axis|
        min_a = max_a = nil
        points_a.each do |point|
          projection = axis[0] * point.x.to_f + axis[1] * point.y.to_f + axis[2] * point.z.to_f
          min_a = projection if min_a.nil? || projection < min_a
          max_a = projection if max_a.nil? || projection > max_a
        end
        min_b = max_b = nil
        points_b.each do |point|
          projection = axis[0] * point.x.to_f + axis[1] * point.y.to_f + axis[2] * point.z.to_f
          min_b = projection if min_b.nil? || projection < min_b
          max_b = projection if max_b.nil? || projection > max_b
        end
        [ max_a, max_b ].min - [ min_a, min_b ].max > SolidMeshDef::TOLERANCE
      end
    end

    # WORLD bounds of the given definition, placed by the given WORLD
    # transformation. The transformed corners of a box are the corners of the
    # transformed box, so this stays exact whatever the rotation.
    def _get_definition_bounds(definition, transformation)
      bounds = Geom::BoundingBox.new
      definition_bounds = definition.bounds
      8.times { |index| bounds.add(definition_bounds.corner(index).transform(transformation)) }
      bounds
    end

    # WORLD bounds of the solid a part is about to be built from - one
    # fragment, never the whole divider : on a "U" cavity the bounds of both
    # branches together would span the notch between them, and match no
    # existing part at all.
    def _get_divider_fragment_bounds(fragment)
      bounds = Geom::BoundingBox.new
      vertices = fragment['vertices']
      vertices.each_slice(3) { |x, y, z| bounds.add(Geom::Point3d.new(x, y, z)) } if vertices.is_a?(Array)
      bounds
    end

    def _bounds_superpose?(bounds, other_bounds)
      return false if bounds.empty? || other_bounds.empty?
      tolerance = SolidMeshDef::TOLERANCE
      min = bounds.min.to_a ; max = bounds.max.to_a
      other_min = other_bounds.min.to_a ; other_max = other_bounds.max.to_a
      (0..2).all? { |axis| (min[axis] - other_min[axis]).abs <= tolerance && (max[axis] - other_max[axis]).abs <= tolerance }
    end

    # -----

    # The cavity fragment a pick designates, or nil when the point sits in no
    # cavity at all.
    #
    # The lookup point is nudged to the cavity side of the picked face : a
    # point picked exactly on a boundary face is ambiguous between the
    # cavities it separates (fragment_defs_for_point would return both).
    def _get_cavity_fragment_def(cavities_def, point, picked_face_manipulator)
      inward_point = point.offset(picked_face_manipulator.normal.reverse, SolidMeshDef::TOLERANCE * 10)
      cavities_def.fragment_defs_for_point(inward_point).first || cavities_def.fragment_defs_for_point(point).first
    end

    # What the pick resolves to, before any slab is built :
    # [ cavities_def, fragment_def, normal_3f ], or nil when the pick is not
    # on a usable cavity. Split out of #_compute_dividers so the count can
    # be validated (see #_set_distribution) without paying for the booleans.
    def _compute_divider_context(point, view)
      return nil unless point.is_a?(Geom::Point3d)
      return nil unless (picked_face_manipulator = @picker.picked_plane_manipulator).is_a?(PlaneManipulator)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      fragment_def = _get_cavity_fragment_def(cavities_def, point, picked_face_manipulator)
      return nil if fragment_def.nil?

      normal_3f = _get_divider_normal_3f(picked_face_manipulator, fragment_def, view)
      return nil if normal_3f.nil?

      [ cavities_def, fragment_def, normal_3f ]
    end

    # [ [ d0, d1 ], ... ] the +number+ distributed dividers span along the
    # normal, ordered, inside the cavity's own [ +n0+, +n1+ ] extent.
    #
    # What is shared equally is the CLEAR OPENINGS, never the axis spacings -
    # those would leave the openings unequal by one thickness as soon as the
    # panels are not infinitely thin.
    #
    # +spacings+ PINS openings, from the ends inward : its leading run of
    # valid lengths fixes the openings before the first dividers, its
    # trailing run - whatever follows an invalid or empty entry, so "100;"
    # pins the first opening and ";100" the last - fixes the openings after
    # the last ones. Only the dividers LEFT IN THE MIDDLE share what
    # remains, which is the whole cavity when the list is empty. Pins beyond
    # the count are dropped : they have no divider to place.
    #
    # nil when the layout does not fit : a middle share with no room left, or
    # pinned dividers that overrun each other.
    def _get_divider_slab_intervals(n0, n1, thickness, number, spacings)
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

      # Pinned from the near end, in order
      start_d = n0
      start_intervals = start_spacings.map { |spacing|
        d0 = start_d + spacing
        start_d = d0 + thickness
        [ d0, start_d ]
      }

      # Pinned from the far end : +end_spacings+ reads outermost first, so
      # these come out in reverse
      end_d = n1
      end_intervals = end_spacings.map { |spacing|
        d1 = end_d - spacing
        end_d = d1 - thickness
        [ end_d, d1 ]
      }.reverse

      middle_size = number - start_intervals.size - end_intervals.size
      if middle_size > 0

        opening = ((end_d - start_d) - middle_size * thickness) / (middle_size + 1.0)
        return nil if opening <= SolidMeshDef::TOLERANCE

        middle_intervals = (1..middle_size).map { |index|
          d0 = start_d + index * (opening + thickness) - thickness
          [ d0, d0 + thickness ]
        }

      else

        # Nothing to share, but the two pinned runs must still not have walked
        # past each other
        return nil if end_d - start_d < -SolidMeshDef::TOLERANCE

        middle_intervals = []

      end

      start_intervals + middle_intervals + end_intervals
    end

    # Computes the divider solids at the current pick : the intersection of
    # a thick slab (normal to one of the picked face's transformation axes,
    # perpendicular to the reference face) with the cavity fragment touched by
    # the picked point. The slab is oversized in its own plane on purpose (see
    # DIVIDER_SLAB_MARGIN) : only the CAVITY boundary ever clips the result,
    # so an open cavity (hull mode) clips flush with its cap, not with the
    # slab's own edges.
    #
    # ONE slab through the picked point when the count is 0 - the free mode,
    # where the pick is the position. Otherwise that many slabs distributed
    # over the cavity's own extent along the normal - see
    # #_get_divider_slab_intervals for how the openings are shared and
    # pinned.
    #
    # Returns an Array of DividerDef - in the normal's own order, so the
    # first is the one nearest the cavity's low end - or nil (no pick, no
    # cavity, distribution that does not fit, degenerate intersection). Shared
    # by the 3D preview and the actual creation, so what gets built is exactly
    # what was last shown.
    def _compute_dividers(point, view)
      return nil unless (context = _compute_divider_context(point, view)).is_a?(Array)
      cavities_def, fragment_def, normal_3f = context

      thickness = _fetch_option_thickness
      n0, n1 = _get_divider_mesh_extent(fragment_def.vertices, normal_3f)
      d = normal_3f[0] * point.x + normal_3f[1] * point.y + normal_3f[2] * point.z

      # [ d0, d1, reference offset, distance to measure ] per slab, all
      # expressed as offsets along the normal.
      if @number > 0

        intervals = _get_divider_slab_intervals(n0, n1, thickness, @number, @spacings)
        return nil if intervals.nil?

        # The measured distance is the clear opening BEFORE each divider,
        # so the reference offset is its near face : the preview then draws
        # exactly the compartment the distribution just created - the pinned
        # value where there is one, the computed share elsewhere.
        previous_d = n0
        slabs = intervals.map { |d0, d1|
          opening = d0 - previous_d
          previous_d = d1
          [ d0, d1, d0, opening ]
        }

      else

        d0, d1 = _get_divider_slab_interval(d, thickness, n0, n1)

        # Gap between the picked point and the cavity boundary "behind" it
        # (n0, the low end of the cavity's own extent along the normal - never
        # n1, so it's always >= 0, measured the same way +normal points).
        slabs = [ [ d0, d1, d, d - n0 ] ]

      end

      normal = Geom::Vector3d.new(normal_3f)
      u, v = _get_divider_plane_uv_3f(normal_3f)
      cavity_mesh = {
        :vertices => fragment_def.vertices,
        :face_indices => fragment_def.face_indices,
        :face_ids => fragment_def.face_ids,
        :tolerance => SolidMeshDef::TOLERANCE
      }

      divider_defs = []
      slabs.each do |d0, d1, reference_d, distance|

        output = Fiddle::Meshy.operate(
          :operation => Fiddle::Meshy::OPERATION_INTERSECTION,
          :validate => false, # Both operands are already valid (slab, and a fragment born of a validated computation)
          :tolerance => SolidMeshDef::TOLERANCE,
          :src_meshes => [ _get_divider_slab_mesh(normal_3f, d0, d1, fragment_def) ],
          :cut_meshes => [ cavity_mesh ]
        )
        return nil unless output.is_a?(Hash) && output['fragments'].is_a?(Array)

        fragments = output['fragments'].select { |fragment| fragment['vertices'].is_a?(Array) && fragment['face_indices'].is_a?(Array) }
        fragments = _normalize_divider_fragments(fragments, u, v)
        return nil if fragments.empty?

        # The picked point, slid along the normal onto this slab's own
        # reference plane : the pick itself only lies in the slab of the free
        # mode. The slide stays inside the picked face (the divider normal
        # is one of that face's own in-plane axes), so it keeps pointing at
        # the compartment the user is aiming at.
        reference_point = reference_d == d ? point : point.offset(normal, reference_d - d)

        # The slab ∩ cavity intersection can split into several disjoint
        # bodies (a non-convex cavity - a "U" - clipping the oversized slab in
        # more than one place).
        #
        # In FREE mode the pick designates one precise compartment : the body
        # it lands in is the divider the user meant to draw, and the others
        # would be extra, unwanted geometry.
        #
        # In DISTRIBUTED mode nothing is designated - the pick only names the
        # cavity, the ask is "divide it in n" - so every body is kept, and
        # each one goes on to build a part of its own (see #_create_entity) :
        # two disjoint bodies are two boards, never one board in two pieces.
        if @number == 0 && fragments.length > 1
          touched_fragment = fragments.find do |fragment|
            SolidFragmentDef.new(fragment['vertices'], fragment['face_indices'], fragment['face_ids'], []).contains_point?(reference_point)
          end
          fragments = [ touched_fragment ] unless touched_fragment.nil?
        end

        divider_defs << DividerDef.new(cavities_def, reference_point, normal_3f, fragments, fragment_def, distance.to_l)

      end

      # A distribution of n dividers makes n + 1 compartments, and each
      # DividerDef only carries the one BEFORE it : the last one closes on
      # the cavity itself, and would otherwise be the only compartment with
      # no measure of its own.
      if @number > 0 && !divider_defs.empty?
        last_d1 = slabs.last[1]
        divider_defs.last.trailing_point = last_d1 == d ? point : point.offset(normal, last_d1 - d)
        divider_defs.last.trailing_distance = (n1 - last_d1).to_l
      end

      divider_defs
    end

    # The two local axes of the picked face's container transformation lying
    # in the face's plane - the axis most aligned with the face normal
    # (perpendicular to the face, not usable as the divider's own normal)
    # is excluded. Order is deterministic (transformation's x, y, z order),
    # independent of the camera.
    def _get_divider_normal_candidates(picked_face_manipulator)
      t = picked_face_manipulator.transformation
      candidates = [ t.xaxis, t.yaxis, t.zaxis ].map(&:normalize)

      face_normal = picked_face_manipulator.normal
      excluded_index = candidates.each_index.max_by { |index| (candidates[index] % face_normal).abs }
      candidates.delete_at(excluded_index)

      candidates
    end

    # Which of the two candidate axes to use as the divider's normal.
    #
    # First criterion, the cavity's opening : the candidate the LEAST aligned
    # with the opening axis is the one whose slab meets the open side by a
    # chant instead of a main face. The epsilon widens the minimum into a
    # tie band, so a candidate is only accepted when it is alone in it -
    # two axes equally (im)perpendicular to the opening (typically a
    # cavity open along the third, excluded axis) tell nothing and fall
    # through. A hermetic cavity, a non-cavity fragment or a degenerate one
    # yields no opening normal at all and falls through too.
    #
    # Fallback, the camera : the candidate reading the most horizontal on
    # screen, i.e. the most aligned with the screen-right vector - the
    # natural "shelf" reading of what the user currently sees. Degenerate
    # camera (direction parallel to up) : first candidate, deterministic.
    def _get_divider_normal_candidate_index(candidates, fragment_def, view)
      if (opening_normal_3f = _get_cavity_opening_normal_3f(fragment_def)).is_a?(Array)
        opening_normal = Geom::Vector3d.new(opening_normal_3f)
        dots = candidates.map { |axis| (axis % opening_normal).abs }
        min_dot = dots.min
        perpendicular_indices = candidates.each_index.select { |index| dots[index] <= min_dot + DIVIDER_NORMAL_OPENING_DOT_EPSILON }
        return perpendicular_indices.first if perpendicular_indices.length == 1
      end

      camera = view.camera
      screen_right = camera.direction.cross(camera.up)
      return 0 unless screen_right.valid?

      candidates.each_index.max_by { |index| (candidates[index] % screen_right).abs } || 0
    end

    # The divider's normal : the candidate that keeps a CHANT (thin edge),
    # not a whole main face, against the cavity's open side - a face landing
    # flush in the opening reads as a false front/back, not a shelf or
    # partition. Falls back to whichever candidate reads more horizontal in
    # the current view when the opening criterion doesn't discriminate
    # (hermetic cavity, or both candidates equally (im)perpendicular to it).
    # The "normal reversed" option swaps this natural pick for its complement.
    def _get_divider_normal_3f(picked_face_manipulator, fragment_def, view)

      # A locked axis (arrow keys) overrides the opening / camera heuristic
      # entirely : the slab is built along that exact axis regardless of the
      # picked face's own plane (the intersection math doesn't care where the
      # normal comes from). The "normal reversed" option still flips it, for
      # the same "which side is front" purpose it serves in the unlocked case.
      if @locked_normal
        normal = _fetch_option_measure_reversed? ? @locked_normal.reverse : @locked_normal
        return normal.to_a
      end

      candidates = _get_divider_normal_candidates(picked_face_manipulator)
      return nil if candidates.length < 2

      index = _get_divider_normal_candidate_index(candidates, fragment_def, view)

      candidate = candidates[index]
      candidate = Geom::Vector3d.new(candidate).reverse! if _fetch_option_measure_reversed?

      candidate.to_a
    end

    # Area-weighted dominant normal ([ x, y, z ] unit Float array) of the
    # given cavity fragment's OPEN side - its cap triangles (reserved face id
    # 0, the envelope ; see CommonSolidFindCavitiesWorker) rather than a real
    # panel face. nil for a hermetic cavity (no cap at all) or a degenerate
    # fragment. Folded up to sign (same trick as
    # CommonSolidFindCavitiesWorker#_panel_dominant_normals) : only the AXIS
    # matters here, and a through-cavity's two opposite caps must accumulate
    # under the same key rather than canceling each other out.
    def _get_cavity_opening_normal_3f(fragment_def)
      return nil unless fragment_def.is_a?(SolidCavityFragmentDef) && !fragment_def.closed?

      vertices = fragment_def.vertices
      face_ids = fragment_def.face_ids
      return nil if face_ids.nil?

      area_by_direction = Hash.new(0.0)
      fragment_def.face_indices.each_slice(3).with_index do |(a, b, c), triangle_index|
        next unless face_ids[triangle_index] == 0

        ax, ay, az = vertices[a * 3], vertices[a * 3 + 1], vertices[a * 3 + 2]
        bx, by, bz = vertices[b * 3], vertices[b * 3 + 1], vertices[b * 3 + 2]
        cx, cy, cz = vertices[c * 3], vertices[c * 3 + 1], vertices[c * 3 + 2]
        ux = bx - ax ; uy = by - ay ; uz = bz - az
        vx = cx - ax ; vy = cy - ay ; vz = cz - az
        nx = uy * vz - uz * vy
        ny = uz * vx - ux * vz
        nz = ux * vy - uy * vx
        length = Math.sqrt(nx * nx + ny * ny + nz * nz)
        next if length == 0

        nx /= length ; ny /= length ; nz /= length
        if nx < 0 || (nx == 0 && (ny < 0 || (ny == 0 && nz < 0)))
          nx = -nx ; ny = -ny ; nz = -nz
        end
        key = [ (nx * 1000).round, (ny * 1000).round, (nz * 1000).round ]
        area_by_direction[key] += length

      end

      max_entry = area_by_direction.max_by { |_, area| area }
      key = max_entry.nil? ? nil : max_entry.first
      key.nil? ? nil : key.map { |v| v / 1000.0 }
    end

    # Orthonormal basis [ u, v ] completing the given unit normal ([ x, y, z ]
    # Float array), seeded on the axis the normal is least aligned with. Pure
    # Float arithmetic (no Geom:: classes) to match the fragment/mesh data,
    # already extracted as flat Float arrays - see the "Length JSON gotcha"
    # in SolidMeshDef.
    def _get_divider_plane_uv_3f(normal)
      seed = [ [ 1.0, 0.0, 0.0 ], [ 0.0, 1.0, 0.0 ], [ 0.0, 0.0, 1.0 ] ][normal.map(&:abs).each_with_index.min.last]
      u = [
        normal[1] * seed[2] - normal[2] * seed[1],
        normal[2] * seed[0] - normal[0] * seed[2],
        normal[0] * seed[1] - normal[1] * seed[0]
      ]
      length = Math.sqrt(u[0] * u[0] + u[1] * u[1] + u[2] * u[2])
      u = u.map { |v| v / length }
      v = [
        normal[1] * u[2] - normal[2] * u[1],
        normal[2] * u[0] - normal[0] * u[2],
        normal[0] * u[1] - normal[1] * u[0]
      ]
      [ u, v ]
    end

    # [ min, max ] of the given flat Float vertices array projected on the
    # given axis.
    def _get_divider_mesh_extent(vertices, axis)
      min = Float::INFINITY
      max = -Float::INFINITY
      vertices.each_slice(3) do |x, y, z|
        p = axis[0] * x + axis[1] * y + axis[2] * z
        min = p if p < min
        max = p if p > max
      end
      [ min, max ]
    end

    # The bodies of a slab ∩ cavity intersection worth building, in a stable
    # order.
    #
    # Manifold outputs its disjoint bodies in no guaranteed order, and that
    # order now decides which part the batch is named after (see
    # #_create_entity) : they are sorted by their own position in the slab's
    # plane, so the same pick always names the same one.
    #
    # A body negligible next to the biggest one is dropped : every survivor
    # becomes a part of the model, and a boolean sliver left along the cavity
    # boundary is not a compartment the user asked for.
    def _normalize_divider_fragments(fragments, u, v)
      return fragments if fragments.length < 2

      fragment_defs = fragments.map { |fragment| SolidFragmentDef.new(fragment['vertices'], fragment['face_indices'], fragment['face_ids'], []) }
      min_volume = fragment_defs.map { |fragment_def| fragment_def.volume }.max * DIVIDER_FRAGMENT_MIN_VOLUME_SHARE

      fragments.each_index.reject { |index|
        fragment_defs[index].empty? || fragment_defs[index].volume < min_volume
      }.sort_by { |index|
        vertices = fragments[index]['vertices']
        [ _get_divider_mesh_extent(vertices, u).first, _get_divider_mesh_extent(vertices, v).first ]
      }.map { |index| fragments[index] }
    end

    # [ d0, d1 ] the slab of a FREELY placed divider spans along the normal :
    # +d+ (the picked point's own offset) being its inside face, its outside
    # face, or its center, per the "measure_type" option, then clamped to the
    # cavity's own [ n0, n1 ] extent.
    #
    # Unlike u/v, the normal axis gets no margin : it's the cavity's own
    # extent that must contain the full slab, not the other way around. An
    # interval landing past the cavity's bound on this axis would otherwise
    # hand the boolean intersection a wish it can only grant by silently
    # thinning the part below the requested thickness. Shifting [d0, d1]
    # here - without resizing it - keeps the full thickness whenever the
    # cavity is deep enough for it ; when it isn't, centering on the
    # cavity's own extent is the best that can be done (the intersection
    # will still thin the result to fit).
    #
    # A distributed divider needs none of this : its interval is derived
    # from [ n0, n1 ] to begin with (see #_compute_dividers), so it is
    # inside the cavity by construction.
    def _get_divider_slab_interval(d, thickness, n0, n1)

      if _fetch_option_measure_type_inside?
        d0 = d
        d1 = d + thickness
      elsif _fetch_option_measure_type_outside?
        d0 = d - thickness
        d1 = d
      else
        d0 = d - thickness / 2.0
        d1 = d + thickness / 2.0
      end

      if n1 - n0 >= thickness
        shift = 0.0
        shift = n0 - d0 if d0 < n0
        shift = n1 - d1 if d1 > n1
        d0 += shift
        d1 += shift
      else
        mid = (n0 + n1) / 2.0
        d0 = mid - thickness / 2.0
        d1 = mid + thickness / 2.0
      end

      [ d0, d1 ]
    end

    # Box spanning [ +d0+, +d1+ ] along +normal+, and oversized in its own
    # plane well beyond +fragment_def+'s bounds (DIVIDER_SLAB_MARGIN) so
    # that intersecting it with the cavity fragment clips exclusively on the
    # cavity's own boundary - real panel faces, or the hull cap when the
    # cavity is open. Serialized to the mesh format expected by
    # Fiddle::Meshy.operate ; every triangle carries face id 0 (same reserved-
    # id convention as CommonSolidFindCavitiesWorker's envelope - irrelevant
    # here since only the geometry is used for the preview).
    def _get_divider_slab_mesh(normal_3f, d0, d1, fragment_def)
      u, v = _get_divider_plane_uv_3f(normal_3f)

      u0, u1 = _get_divider_mesh_extent(fragment_def.vertices, u)
      v0, v1 = _get_divider_mesh_extent(fragment_def.vertices, v)
      u0 -= DIVIDER_SLAB_MARGIN ; u1 += DIVIDER_SLAB_MARGIN
      v0 -= DIVIDER_SLAB_MARGIN ; v1 += DIVIDER_SLAB_MARGIN

      vertices = []
      [ [ u0, v0, d0 ], [ u1, v0, d0 ], [ u1, v1, d0 ], [ u0, v1, d0 ],
        [ u0, v0, d1 ], [ u1, v0, d1 ], [ u1, v1, d1 ], [ u0, v1, d1 ] ].each do |pu, pv, pn|
        vertices << u[0] * pu + v[0] * pv + normal_3f[0] * pn
        vertices << u[1] * pu + v[1] * pv + normal_3f[1] * pn
        vertices << u[2] * pu + v[2] * pv + normal_3f[2] * pn
      end

      face_indices = [
        0, 2, 1, 0, 3, 2,
        4, 5, 6, 4, 6, 7,
        0, 1, 5, 0, 5, 4,
        2, 3, 7, 2, 7, 6,
        1, 2, 6, 1, 6, 5,
        3, 0, 4, 3, 4, 7
      ]

      {
        :vertices => vertices,
        :face_indices => face_indices,
        :face_ids => Array.new(face_indices.length / 3, 0),
        :num_vertices => vertices.length / 3,
        :num_faces => face_indices.length / 3,
        :tolerance => SolidMeshDef::TOLERANCE
      }
    end

    # -----

    CavitiesDef = Struct.new(:container_path, :result_def, :drawing_defs) do
      def valid?
        result_def.is_a?(SolidBooleanResultDef) && result_def.success?
      end
      def fragment_defs
        result_def.fragment_defs
      end
      def fragment_defs_for_point(point)
        result_def.fragment_defs_for_point(point)
      end
    end

    # One divider - i.e. one slab of the distribution, carrying the 1..N
    # disjoint bodies the cavity clipped that slab into, hence 1..N parts
    # (see #_compute_dividers and #_create_entity). The measures below belong
    # to the slab as a whole, not to any one of its bodies.
    #
    # +distance+ is the clear opening BEFORE the divider, measured from
    # +point+ (its near face) back to +wall_point+. +trailing_distance+ is the
    # one AFTER it, measured from +trailing_point+ (its far face) on to
    # +trailing_wall_point+ : only the LAST divider of a distribution
    # carries it, since every other closing opening is the next divider's
    # own +distance+.
    DividerDef = Struct.new(:cavity_def, :point, :normal_3f, :fragments, :fragment_def, :distance, :trailing_point, :trailing_distance) do
      def container_path
        cavity_def.container_path
      end
      def normal
        @normal ||= Geom::Vector3d.new(normal_3f)
      end
      def wall_point
        @wall_point ||= point.offset(normal, -distance)
      end
      def trailing_wall_point
        return nil if trailing_point.nil? || trailing_distance.nil?
        @trailing_wall_point ||= trailing_point.offset(normal, trailing_distance)
      end
    end

  end

end