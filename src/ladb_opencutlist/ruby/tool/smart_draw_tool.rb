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
  require_relative '../model/attributes/layer_attributes'
  require_relative '../model/solid/solid_mesh_def'
  require_relative '../model/solid/solid_boolean_result_def'
  require_relative '../utils/path_utils'
  require_relative '../utils/drawingelement_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_solid_find_cavities_worker'
  require_relative '../worker/common/common_solid_boolean_apply_worker'

  class SmartDrawTool < SmartTool

    ACTION_DRAW_RECTANGLE = 0
    ACTION_DRAW_CIRCLE = 1
    ACTION_DRAW_POLYGON = 2
    ACTION_DRAW_DIVIDER = 3
    ACTION_DRAW_FRONT_PANEL = 4
    ACTION_DRAW_BACK_PANEL = 5

    ACTION_OPTION_THICKNESS = 'thickness'
    ACTION_OPTION_OFFSET = 'offset'
    ACTION_OPTION_SEGMENTS = 'segments'
    ACTION_OPTION_MEASURE_TYPE = 'measure_type'
    ACTION_OPTION_OVERLAY = 'overlay'
    ACTION_OPTION_MACHINING = 'machining'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_THICKNESS_THICKNESS = 'thickness'

    ACTION_OPTION_OFFSET_SHAPE_OFFSET = 'shape_offset'
    ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET = 'front_panel_offset'
    ACTION_OPTION_OFFSET_BACK_PANEL_DEPTH = 'back_panel_depth'
    ACTION_OPTION_OFFSET_BACK_PANEL_SETBACK = 'back_panel_setback'

    ACTION_OPTION_SEGMENTS_SEGMENT_COUNT = 'segment_count'

    ACTION_OPTION_MEASURE_TYPE_INSIDE = 'inside'
    ACTION_OPTION_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_MEASURE_TYPE_OUTSIDE = 'outside'

    ACTION_OPTION_OVERLAY_INSET = 'inset'
    ACTION_OPTION_OVERLAY_FULL_OVERLAY = 'full_overlay'

    # What a panel does to the parts it cuts into. VOLUME stands the removed
    # material up as a group of its own, marked with a machining material -
    # non destructive, and what the projection reads as a pocket (see
    # CommonDrawingProjectionWorker). A real boolean subtraction is the
    # variant to come ; the option is a group of its own from the start so
    # that adding it is one value, not a migration.
    ACTION_OPTION_MACHINING_NONE = 'none'
    ACTION_OPTION_MACHINING_VOLUME = 'volume'

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
    ACTION_OPTION_OPTIONS_MIRROR = 'mirror'
    ACTION_OPTION_OPTIONS_ASK_NAME = 'ask_name'
    ACTION_OPTION_OPTIONS_LAYER_NAME = 'layer_name'
    ACTION_OPTION_OPTIONS_MACHINING_MATERIAL_NAME = 'machining_material_name'
    ACTION_OPTION_OPTIONS_MACHINING_LAYER_NAME = 'machining_layer_name'

    # What a machining volume is drawn as when the handler has to create one -
    # the same blue the BXF import and the Smart Join tool give theirs, so that
    # machinings of every provenance read alike in a model.
    COLOR_DEFAULT_MACHINING_MATERIAL = Sketchup::Color.new('#0068ff')

    # The mirror motif - a dashed axis, a triangle on each side pointing at it
    # (the same as SmartHandleTool's) - and the same turned a quarter : the
    # axis then runs across, for front panels mirrored on top of one another.
    MIRROR_MOTIF_VERTICAL_PATH = 'M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2'
    MIRROR_MOTIF_HORIZONTAL_PATH = 'M0,0.5L0.2,0.5 M0.4,0.5L0.6,0.5 M0.8,0.5L1,0.5 M0.2,0L0.5,0.3L0.8,0L0.2,0 M0.2,1L0.5,0.7L0.8,1L0.2,1'

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
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_MEASURE_TYPE => [ ACTION_OPTION_MEASURE_TYPE_INSIDE, ACTION_OPTION_MEASURE_TYPE_CENTERED, ACTION_OPTION_MEASURE_TYPE_OUTSIDE ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      },
    ]

    if Sketchup.debug_mode?
      ACTIONS << {
        :action => ACTION_DRAW_FRONT_PANEL,
        :options => {
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET ],
          ACTION_OPTION_OVERLAY => [ ACTION_OPTION_OVERLAY_INSET, ACTION_OPTION_OVERLAY_FULL_OVERLAY ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_MIRROR, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      }
      # The back panel shares the whole of the front panel's pipeline (see
      # SmartDrawMouthPanelActionHandler), so it is gated with it : releasing
      # one without the other would make no sense.
      ACTIONS << {
        :action => ACTION_DRAW_BACK_PANEL,
        :options => {
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_BACK_PANEL_DEPTH, ACTION_OPTION_OFFSET_BACK_PANEL_SETBACK ],
          ACTION_OPTION_OVERLAY => [ ACTION_OPTION_OVERLAY_INSET, ACTION_OPTION_OVERLAY_FULL_OVERLAY ],
          ACTION_OPTION_MACHINING => [ ACTION_OPTION_MACHINING_NONE, ACTION_OPTION_MACHINING_VOLUME ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      }
    end

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
      when ACTION_DRAW_FRONT_PANEL, ACTION_DRAW_BACK_PANEL
          # The same pencil for both : what a mouth panel is FOR is not
          # something a cursor can show, and a dedicated icon is an asset to
          # draw, not a line to write.
          return SmartCursorManager.cursor_pencil_front_panel
      end

      super
    end

    def get_action_options_modal?(action)
      action != ACTION_DRAW_DIVIDER
    end

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_THICKNESS
        case option
        when ACTION_OPTION_THICKNESS_THICKNESS
          return [ ACTION_DRAW_DIVIDER, ACTION_DRAW_FRONT_PANEL ]
        end
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET
          return [ ACTION_DRAW_RECTANGLE, ACTION_DRAW_CIRCLE, ACTION_DRAW_POLYGON ]
        end
      when ACTION_OPTION_AXES
        return [ ACTION_DRAW_DIVIDER, ACTION_DRAW_FRONT_PANEL, ACTION_DRAW_BACK_PANEL ]
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_ASK_NAME
          return [ ACTION_DRAW_RECTANGLE, ACTION_DRAW_CIRCLE, ACTION_DRAW_POLYGON, ACTION_DRAW_DIVIDER, ACTION_DRAW_FRONT_PANEL, ACTION_DRAW_BACK_PANEL ]
        when ACTION_OPTION_OPTIONS_DRAW_IN, ACTION_OPTION_OPTIONS_PULL_CENTRED
          return [ ACTION_DRAW_RECTANGLE, ACTION_DRAW_CIRCLE, ACTION_DRAW_POLYGON ]
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
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET
          return false
        when ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET
          return false
        when ACTION_OPTION_OFFSET_BACK_PANEL_DEPTH, ACTION_OPTION_OFFSET_BACK_PANEL_SETBACK
          return false
        end
      when ACTION_OPTION_SEGMENTS
        case option
        when ACTION_OPTION_SEGMENTS_SEGMENT_COUNT
          return false
        end
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_OVERLAY
        return true
      when ACTION_OPTION_MACHINING
        return true
      when ACTION_OPTION_MEASURE_TYPE
        return true
      when ACTION_OPTION_AXES
        return true
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_THICKNESS
        case option
        when ACTION_OPTION_THICKNESS_THICKNESS
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET, ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET,
             ACTION_OPTION_OFFSET_BACK_PANEL_DEPTH, ACTION_OPTION_OFFSET_BACK_PANEL_SETBACK
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_SEGMENTS
        case option
        when ACTION_OPTION_SEGMENTS_SEGMENT_COUNT
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
      when ACTION_OPTION_OVERLAY
        case option
        when ACTION_OPTION_OVERLAY_INSET
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.125,0.125L0.688,0.125L0.688,0L0.125,0L0.125,0.125 M0.125,1L0.688,1L0.688,0.875L0.125,0.875L0.125,1 M0.688,0.25L0.5,0.25L0.5,0.75L0.688,0.75L0.688,0.25'))
        when ACTION_OPTION_OVERLAY_FULL_OVERLAY
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.125,0.125L0.688,0.125L0.688,0L0.125,0L0.125,0.125 M0.125,1L0.688,1L0.688,0.875L0.125,0.875L0.125,1 M1,0L0.813,0L0.813,1L1,1L1,0'))
        end
      when ACTION_OPTION_MACHINING
        # Two stiles and a panel between them - bare, then let into a groove
        # cut in each of them.
        case option
        when ACTION_OPTION_MACHINING_NONE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L0.188,0L0.188,1L0,1L0,0 M0.813,0L1,0L1,1L0.813,1L0.813,0 M0.313,0.375L0.688,0.375L0.688,0.625L0.313,0.625L0.313,0.375'))
        when ACTION_OPTION_MACHINING_VOLUME
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L0.188,0L0.188,0.375L0.063,0.375L0.063,0.625L0.188,0.625L0.188,1L0,1L0,0 M1,0L0.813,0L0.813,0.375L0.938,0.375L0.938,0.625L0.813,0.625L0.813,1L1,1L1,0 M0.063,0.375L0.938,0.375L0.938,0.625L0.063,0.625L0.063,0.375'))
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
        when ACTION_OPTION_OPTIONS_MIRROR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(MIRROR_MOTIF_VERTICAL_PATH))
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
      when ACTION_DRAW_FRONT_PANEL
        set_action_handler(SmartDrawFrontPanelActionHandler.new(self))
      when ACTION_DRAW_BACK_PANEL
        set_action_handler(SmartDrawBackPanelActionHandler.new(self))
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

    # Weights of the axis signs in #_get_auto_orient_axes_transformation's
    # score. Offsets are normalized in [ -1, 1 ], and 4 > 2 + 1, 2 > 1, so
    # these make the score a STRICT priority order Z > X > Y : the offset
    # magnitudes only break ties, when an axis is ambiguous (offset ~ 0).
    AUTO_ORIENT_Z_WEIGHT = 4.0
    AUTO_ORIENT_X_WEIGHT = 2.0
    AUTO_ORIENT_Y_WEIGHT = 1.0

    # Orients the newly built +definition+'s own axes on its own geometry :
    # Z on the normal of its largest face, X on the longest edge lying in
    # that face (perpendicular to the normal) - so the part's axes read as
    # "front/thickness" instead of whatever axes the pick happened to leave
    # it in. Axis SIGNS are then decided by the geometry itself, see
    # #_get_auto_orient_axes_transformation. Returns a transformation to
    # apply to the definition's content (see callers), or IDENTITY when
    # there is no face to orient on.
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

          # Both candidates are directions, not oriented axes : the face is
          # the FIRST one of its parallel group (a panel's two large faces
          # are antiparallel, so they share a group) and the edge direction
          # follows its start/end order. Both signs are therefore arbitrary,
          # and the helper decides them from the geometry.
          return _get_auto_orient_axes_transformation(definition, direction, normal)
        end

      end

      IDENTITY
    end

    # Signs +x_axis+ and +z_axis+ - given as unsigned DIRECTIONS - so that
    # they point toward +definition+'s geometry, and returns the resulting
    # transformation (IDENTITY when the corrected basis is the canonical
    # one, both callers rely on that).
    #
    # The transformation is a pure rotation around the definition's own
    # ORIGIN and Y = Z * X, so the three signs can NOT be chosen freely :
    # once X and Z are set, Y follows - picking it too would mirror the part
    # (negative determinant). Only the 4 (sx, sz) combinations are valid, and
    # they are ranked by a woodworking priority : Z (thickness) first, then
    # X (length), Y last (see AUTO_ORIENT_*_WEIGHT).
    def _get_auto_orient_axes_transformation(definition, x_axis, z_axis)

      y_axis = z_axis * x_axis

      points = definition.entities.grep(Sketchup::Edge).flat_map { |edge| [ edge.start.position, edge.end.position ] }
      return Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis) if points.empty?

      ox = _get_auto_orient_offset(points, x_axis)
      oy = _get_auto_orient_offset(points, y_axis)
      oz = _get_auto_orient_offset(points, z_axis)

      # (1, 1) is evaluated first and only a strictly better score replaces
      # it : a symmetric geometry - where every offset is 0 - keeps the
      # incoming basis instead of flipping on numerical noise.
      best_sx = 1
      best_sz = 1
      best_score = nil
      [ 1, -1 ].each do |sx|
        [ 1, -1 ].each do |sz|
          score = AUTO_ORIENT_Z_WEIGHT * sz * oz + AUTO_ORIENT_X_WEIGHT * sx * ox + AUTO_ORIENT_Y_WEIGHT * sx * sz * oy
          if best_score.nil? || score > best_score + 1e-9
            best_score = score
            best_sx = sx
            best_sz = sz
          end
        end
      end

      x_axis = x_axis.reverse if best_sx < 0
      z_axis = z_axis.reverse if best_sz < 0
      y_axis = z_axis * x_axis  # Recomputed : keeps the basis right handed, never a mirror

      Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
    end

    # Where +points+ sit along +axis+, relative to the definition's origin,
    # as a ratio in [ -1, 1 ] : 1 = entirely on the positive side, 0 =
    # centered on the origin (ambiguous : a disc, a cylinder), -1 = entirely
    # on the negative side.
    def _get_auto_orient_offset(points, axis)
      min = nil
      max = nil
      points.each do |point|
        # Point3d coordinates are Lengths, whose comparisons are tolerant :
        # to_f keeps the extent computation in plain Float
        d = point.x.to_f * axis.x + point.y.to_f * axis.y + point.z.to_f * axis.z
        min = d if min.nil? || d < min
        max = d if max.nil? || d > max
      end
      return 0.0 if min.nil? || (max - min).abs < 1e-9
      (min + max) / (max - min)
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
          ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string('tool.default.locked_on_last_measure_status') + '.' +
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
               ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string('tool.default.locked_on_last_measure_status') + '.' +
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

      # Set length (X axis) along elevation only if elevation > diameter.
      # The signs are left to the helper : a cylinder pulled downward must
      # not end up with its axes pointing away from its own material.
      if elevation > diameter
        return _get_auto_orient_axes_transformation(definition, Z_AXIS, X_AXIS)
      end

      _get_auto_orient_axes_transformation(definition, X_AXIS, Z_AXIS)
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

  # Base of the action handlers that draw a panel INSIDE an existing
  # enclosure - a divider fitted to a compartment, a front panel fitted to its
  # opening. What they share is the CAVITIES of the container the pick lands
  # in : one boolean pass, cached on that container, that all of them read.
  class SmartDrawPanelActionHandler < SmartDrawActionHandler

    include SmartActionHandlerPartHelper

    LAYER_3D_CAVITY_PREVIEW = 100

    def initialize(action, tool, previous_action_handler = nil)
      super
    end

    # -----

    protected

    def _reset
      _reset_cavities_def
      super
    end

    def _reset_cavities_def
      @cavities_def = nil
      _reset_picked_cavity
    end

    # What a pick resolved to in the cavities, for the handlers that read it
    # there (see SmartDrawDividerActionHandler#_snap_point) : dropped with the
    # cavities it points into, which the next pick recomputes.
    def _reset_picked_cavity
      @picked_fragment_def = nil
      @picked_plane_manipulator = nil
    end

    # -----

    def _preview_part_container_axes?
      _fetch_option_axes_context?
    end

    # -----

    # The frame the axis locks (arrow keys) are read in : the CONTAINER's own,
    # when the axes option asks for it - a canted carcass then locks on its
    # own axes rather than on the model's. Falls back to the active frame
    # while no part is picked yet, there being no container to read.
    def _get_edit_transformation
      if _fetch_option_axes_context? && (part_entity_path = get_active_part_entity_path).is_a?(Array) && part_entity_path.length > 1
        return PathUtils.get_transformation(part_entity_path[0...-1], IDENTITY)
      end
      super
    end

    # -----

    def _fetch_option_axes_context?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_AXES, SmartDrawTool::ACTION_OPTION_AXES_CONTEXT)
    end

    # -----

    # Whether the cavity envelope must be REDUCED to what the panels really
    # enclose (see CommonSolidFindCavitiesWorker, ENVELOPE REDUCTION). Off
    # here : the reduction pulls the envelope back to a recessed chant, and
    # with it the CAPS that stand for the openings - which is precisely where
    # a front panel sits. A handler that fits a panel INTO a compartment may turn
    # it on ; one that fits a panel ONTO an opening must not.
    def _cavities_reduce_envelope?
      false
    end

    # Whether the OVERALL cavity is wanted alongside the compartments : the
    # interior as if the enclosure were empty, bounded by its contour panels
    # only (see CommonSolidFindCavitiesWorker, OVERALL CAVITY). That is what
    # a full height front panel spans, across the compartments its internal panels
    # carve out.
    def _cavities_overall?
      false
    end

    # Whether the panels merely LAID ON the assembly are to be left out of
    # the enclosure (see CommonSolidFindCavitiesWorker, DETACHED PARTS). Off
    # here : a panel of the container is part of it until proven otherwise.
    # A handler that DRAWS such panels has to turn it on, or the ones it has
    # already drawn would be read as part of the carcass and inflate the
    # envelope over the openings that are left.
    def _cavities_ignore_applied_panels?
      false
    end

    # Whether the FRONT PANELS already drawn make the openings they fill recede
    # (see CommonSolidFindCavitiesWorker, INSET FRONT PANELS). Off here : a
    # handler that fits a panel ONTO an opening has to read that opening as
    # the carcass leaves it, or it would lay its front panel against the back of
    # the one already there. A handler that fits a panel INTO a compartment
    # must turn it on, on pain of telescoping into an inset front panel.
    def _cavities_recess_front_panels?
      false
    end

    # -----

    # The point a pick designates on the wall of a cavity, kept in
    # @picked_point ; true when it really lands in one.
    #
    # The point is projected on the picked face's own plane : a pick reads a
    # bit off the surface, and a point floating in front of the wall belongs
    # to no cavity at all.
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

    # Draws the cavities the pick lands in - their contours, and their volume
    # as a translucent shell.
    def _preview_cavity

      @tool.clear_3d(LAYER_3D_CAVITY_PREVIEW)

      return unless @picked_point.is_a?(Geom::Point3d)
      return unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      color = Kuix::COLOR_BLUE

      active_fragment_defs = _get_preview_cavity_fragment_defs(cavities_def)
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

    # The cavities #_preview_cavity draws : the ones the pick lands in. A
    # handler whose pick gathers SEVERAL of them has more than that to show.
    def _get_preview_cavity_fragment_defs(cavities_def)
      cavities_def.fragment_defs_for_point(@picked_point)
    end

    # -----

    # The paths of every APPLIED PANEL the given container holds - a front
    # panel or a back, see LayerAttributes::TYPES_PANEL - at any depth and
    # WHATEVER its visibility.
    #
    # The cutlist #_get_cavities_def runs cannot hand them over : like the rest
    # of the extension it reads what the model SHOWS, and hiding the panels -
    # their tag, or the instances themselves - to work inside the carcass is
    # precisely how a box is drawn. The panel a part would telescope into
    # would then be the one nobody has in front of them.
    #
    # Only the RECESS reads this list. A hidden PANEL stays out of the cavities
    # exactly as it stays out of the cutlist : what it does there is WIDEN a
    # cavity, which errs the way the model reads, where a panel gone missing
    # puts a part through another.
    def _fetch_applied_panel_entity_paths(container, container_path, applied_panel_entity_paths = [])
      return applied_panel_entity_paths unless container.respond_to?(:definition)
      container.definition.entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        next if entity.definition.behavior.always_face_camera?
        entity_path = container_path + [ entity ]
        if LayerAttributes.panel_type?(LayerAttributes.type_of(entity))
          applied_panel_entity_paths << entity_path   # An applied panel is read WHOLE : what it holds is its own business, and a panel inside a panel is none
        else
          _fetch_applied_panel_entity_paths(entity, entity_path, applied_panel_entity_paths)
        end
      end
      applied_panel_entity_paths
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
      # The glued cuts-opening machinings stay IN : SketchUp punches their
      # opening in the host face tessellation, so a drilled panel without them
      # is an open shell (one open edge loop per mortise) that no boolean can
      # take. They are what closes it back — SolidMeshDef marks them virtual,
      # and CommonSolidFindCavitiesWorker drops the voids they enclose. Hence
      # flatten: false, without which they land in the drawing def's own faces
      # and lose that provenance.
      fn_decompose = lambda { |entity_path, ignore_visibility|
        CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(entity_path) ],
                                             ignore_surfaces: true,
                                             ignore_edges: true,
                                             container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS,
                                             ignore_visibility: ignore_visibility,
                                             flatten: false
        ).run
      }

      # The APPLIED PANELS - a front panel or a back, see
      # LayerAttributes::TYPES_PANEL - are held apart from the panels of the
      # carcass : one is laid ON the carcass, and read as a panel of it, it
      # pushes the envelope forward over the part of itself it covers - the
      # openings that are left then read on a slanted, oversized cap, and the
      # next panel is fitted to a mouth that does not exist. Nothing in their
      # geometry says what they are (see CommonSolidFindCavitiesWorker, APPLIED
      # PANELS) : their LAYER does. BOTH kinds, and for the same reason - a back
      # laid on the rear of a carcass closes its rear opening exactly as a front
      # closes the front one.
      #
      # They are not necessarily out of the picture, though : a panel fitted
      # INTO its mouth occupies that end of the compartment it closes, and a
      # handler that fits a panel in there has to stop at its back. Handed to
      # the worker aside, that is exactly what they do - they recede the
      # openings they fill, and nothing else (see
      # CommonSolidFindCavitiesWorker, INSET FRONT PANELS). Aside also means read
      # aside : #_fetch_applied_panel_entity_paths goes and gets them from the
      # container itself, where the ones the model hides are still there.
      panel_instance_infos = parts.flat_map { |container_part|
        container_part.def.instance_infos.values
      }.reject { |instance_info|
        LayerAttributes.panel_type?(LayerAttributes.type_of(instance_info.entity))
      }

      drawing_defs = panel_instance_infos.map { |instance_info| fn_decompose.call(instance_info.path, false) }
      # An applied panel is read whole and blind to what the model shows : the tag it
      # is marked with is the tag its own faces are likely to carry, and hidden
      # once it is the mesh that would come back empty.
      front_panel_drawing_defs = _cavities_recess_front_panels? ? _fetch_applied_panel_entity_paths(container, container_path).map { |entity_path| fn_decompose.call(entity_path, true) } : []

      result_def = CommonSolidFindCavitiesWorker.new(drawing_defs,
                                                     max_opening_planes: 4,
                                                     reduce_envelope: _cavities_reduce_envelope?,
                                                     overall_cavity: _cavities_overall?,
                                                     ignore_applied_panels: _cavities_ignore_applied_panels?,
                                                     front_panel_drawing_defs: front_panel_drawing_defs
      ).run

      @cavities_def = CavitiesDef.new(container_path, result_def, drawing_defs)

      unless result_def.success?
        @tool.notify_errors(result_def.errors)
      end

      @cavities_def
    end

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

      # What a RAY designates in these cavities : [ fragment_def, point,
      # plane_manipulator ] - the compartment it enters, where it first meets
      # a wall of it, and that wall read as the picker would have read the
      # face behind it. nil when it designates none.
      #
      # Picking the cavities rather than the model is what lets a part be
      # fitted in a compartment something else stands in front of - a front panel,
      # a drawer front, anything laid over the opening - without hiding it :
      # the mouths are the cavity's own geometry, and what fills them is not.
      #
      # The ray must ENTER by a mouth, i.e. its first crossing of the
      # compartment must be one of the CAPS the openings stand for (face id
      # 0). That is what keeps a pick READING INTO an opening : aiming at the
      # outside of a carcass crosses no mouth at all - the first thing met is
      # the far side of the panel aimed at - and designates nothing, exactly
      # as it does today.
      def pick_ray(origin, direction)

        picked = nil
        fragment_defs.each do |fragment_def|

          hits = fragment_def.ray_hits(origin, direction)
          next if hits.empty?
          next unless fragment_def.triangle_face_id(hits.first[2]) == 0 || _origin_inside?(fragment_def, origin)   # Entered by something else than a mouth

          # The first WALL met after the mouth - the face the cursor is on, as
          # the picker would have given it if nothing stood in front. One that
          # no panel can be read behind (a cap, or geometry with no
          # provenance) is passed over rather than fatal : the next one along
          # the ray is just as much in the compartment.
          point = nil
          plane_manipulator = nil
          hits.each do |_distance, hit_point, triangle_index|
            next if fragment_def.triangle_face_id(triangle_index).to_i == 0
            plane_manipulator = _wall_plane_manipulator(fragment_def, triangle_index, hit_point)
            next if plane_manipulator.nil?
            point = hit_point
            break
          end
          next if point.nil?   # A cavity crossed through its mouths only : nothing to lean the pick on

          # Compared on the MOUTH, not on the wall : which compartment the
          # user is looking into is settled at its opening, and a shallow one
          # in front of a deep one is the one they see.
          next unless picked.nil? || hits.first[0] < picked[0]
          picked = [ hits.first[0], fragment_def, point, plane_manipulator ]

        end
        return nil if picked.nil?

        _distance, fragment_def, point, plane_manipulator = picked

        [ fragment_def, point, plane_manipulator ]
      end

      private

      # Whether the ray STARTS inside the given cavity - the camera standing in
      # the compartment it looks at, where there is no mouth left to cross on
      # the way to its walls. Bounds first : the eye is outside every
      # compartment on the vast majority of picks, and that answers those for
      # the price of a box test.
      def _origin_inside?(fragment_def, origin)
        point = origin.is_a?(Geom::Point3d) ? origin : Geom::Point3d.new(origin)
        return false unless fragment_def.bounds.contains?(point)
        fragment_def.contains_point?(point)
      end

      # The wall a ray hit, as the PlaneManipulator a picker would have handed
      # back for the source face behind it : the plane read off the triangle
      # itself - exact, and free of the source face's own extent - carried by
      # the TRANSFORMATION of the panel it comes from, which is what the
      # handlers read the part's own axes on (see
      # #_get_divider_normal_candidates).
      #
      # The panel is found through the triangle's face id : it indexes the
      # operation's face info registry, whose container_def is the panel's own
      # DrawingDef (only a root one bounds a cavity - see
      # SolidBooleanResultDef#fragment_defs_for_face). nil for a wall no panel
      # stands behind, an opening cap included.
      def _wall_plane_manipulator(fragment_def, triangle_index, point)
        face_id = fragment_def.triangle_face_id(triangle_index)
        return nil if face_id.nil? || face_id == 0
        face_info_def = fragment_def.face_info_defs[face_id]
        return nil if face_info_def.nil?
        drawing_def = face_info_def.container_def
        return nil unless drawing_def.is_a?(DrawingDef)
        transformation = drawing_def.transformation
        return nil unless transformation.is_a?(Geom::Transformation)
        normal = fragment_def.triangle_normal(triangle_index)
        return nil if normal.nil?

        # Expressed in the panel's own space, since PlaneManipulator brings its
        # plane back to the world through the transformation it is given.
        ti = transformation.inverse
        PlaneManipulator.new([ point.transform(ti), normal.transform(ti) ], transformation)
      end

    end

  end

  class SmartDrawDividerActionHandler < SmartDrawPanelActionHandler

    include FaceMatcherHelper

    STATE_PLACE = 0
    STATE_DISTRIBUTE = 1

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
          _reset_cavities_def
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
          return true
        end
        if tool.is_key_alt_or_command?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, !_fetch_option_reduce_envelope?, fire_event: true)
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
      when SmartDrawTool::ACTION_OPTION_OPTIONS
        case option
        when SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED
          _refresh
        when SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE
          _reset_cavities_def
          _refresh
        end
      end

    end

    def onToolTransactionUndo(tool, model)
      _reset_cavities_def
      super
    end

    # -----

    protected

    # -----

    def _reset
      @picked_point = nil
      @picked_fragment_def = nil
      @picked_plane_manipulator = nil
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

    # -----

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

    # The reduction is the divider's own option : a divider is fitted BETWEEN
    # the panels it lands on, so pulling the envelope back to a recessed
    # chant is a legitimate reading of the compartment - see
    # SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE.
    def _cavities_reduce_envelope?
      _fetch_option_reduce_envelope?
    end

    # A divider is fitted INTO the compartment it divides : a front panel already
    # standing in its mouth is in the way, and the compartment stops at its
    # back - see CommonSolidFindCavitiesWorker, INSET FRONT PANELS. A front panel laid
    # in applique is no obstacle and recedes nothing, which the worker reads
    # off the cavities themselves : there is nothing to tell it here.
    def _cavities_recess_front_panels?
      true
    end

    # -----

    # The pick, read on the CAVITIES themselves rather than on the model : the
    # ray under the cursor is cast at the compartments, and the compartment it
    # enters through a mouth, the point where it first meets a wall of it, and
    # that wall are what the placement then works on (see
    # CavitiesDef#pick_ray).
    #
    # A divider is fitted INSIDE a compartment, and what closes that
    # compartment stands between the cursor and it : a front panel, a drawer front,
    # a plinth, the neighbouring carcass. Reading the pick off the model makes
    # every one of them opaque - the picker hands back the face in FRONT, a
    # point that lies in no cavity - and the only way through is to hide them.
    # The cavities, themselves, are not hidden by what fills their mouth : the
    # mouths are their own geometry.
    #
    # What the inherited pick does and this one does not : SketchUp's
    # inference (endpoints, midpoints, edges) no longer takes part, the point
    # being read off the cavity wall alone. A divider is placed at a distance
    # or by distribution, not on a vertex, so there is nothing there to lose.
    def _snap_point(picker)

      @picked_point = nil
      @picked_fragment_def = nil
      @picked_plane_manipulator = nil

      return false unless has_active_part?
      return false unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?
      return false unless picker.is_a?(SmartPicker) && (view = picker.view).is_a?(Sketchup::View)

      ray = view.pickray(picker.pick_position.x, picker.pick_position.y)
      return false unless ray.is_a?(Array) && ray.length == 2

      picked = cavities_def.pick_ray(ray[0], ray[1])
      return false if picked.nil?

      @picked_fragment_def, @picked_point, @picked_plane_manipulator = picked

      true
    end

    # The pick designates ONE compartment, and #_snap_point already knows
    # which : looking it up again from the point would hand back every cavity
    # that point touches, and it lies exactly on a wall two of them may share.
    def _get_preview_cavity_fragment_defs(cavities_def)
      @picked_fragment_def.is_a?(SolidCavityFragmentDef) ? [ @picked_fragment_def ] : []
    end

    # -----

    def _fetch_option_reuse_definition?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
    end

    def _fetch_option_measure_type_inside?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE_INSIDE)
    end

    def _fetch_option_measure_type_outside?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE, SmartDrawTool::ACTION_OPTION_MEASURE_TYPE_OUTSIDE)
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

    # What the pick resolves to, before any slab is built :
    # [ cavities_def, fragment_def, normal_3f ], or nil when the pick is not
    # on a usable cavity. Split out of #_compute_dividers so the count can
    # be validated (see #_set_distribution) without paying for the booleans.
    def _compute_divider_context(point, view)
      return nil unless point.is_a?(Geom::Point3d)
      return nil unless (picked_face_manipulator = @picked_plane_manipulator).is_a?(PlaneManipulator)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      # The compartment comes from the pick itself (#_snap_point) : the ray
      # entered ONE of them, and there is nothing to look up - nor any point
      # sitting on a boundary to disambiguate.
      fragment_def = @picked_fragment_def
      return nil unless fragment_def.is_a?(SolidCavityFragmentDef)

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

  # Draws a PANEL fitted to an opening of a cavity - the shared pipeline of
  # every panel laid on a mouth. Abstract : see
  # SmartDrawFrontPanelActionHandler and SmartDrawBackPanelActionHandler for
  # the two of them, and the "WHAT KIND OF PANEL THIS IS" section below for
  # everything that tells them apart.
  #
  # The cavity detector already knows what an opening is : the envelope CAPS
  # (face id 0) close the cavity flush with the panel edges where no panel
  # does, and SolidCavityFragmentDef#opening_defs reads their net contour -
  # one closed loop per opening, exact whatever the tessellation or the slope
  # of the panel. That contour IS the panel, so the handler only has to
  # choose WHICH opening the pick means, and give it a thickness.
  #
  # Two POSES : INSET, where the panel fills the mouth with its outer face
  # flush with the plane the caps stand on, and OVERLAY, where it is laid in
  # front of the mouth and covers the frame around it - which the cavity
  # cannot tell on its own, and is read off the container's silhouette instead
  # (see #_get_overlay_points). #_get_panel_nominal_points is the single place
  # the two branch.
  #
  # One mouth may take SEVERAL panels : the nominal contour is then shared
  # into equal bands before the clearance applies, and the direction they
  # succeed one another along is read off the panel under the cursor - the
  # cuts run parallel to it (see #_get_split_direction).
  #
  # The OVERALL cavity is deliberately not asked for either
  # (#_cavities_overall? stays false, see SmartDrawPanelActionHandler) : it is
  # what a FULL HEIGHT panel spans, but a pick would then land in two cavities
  # at once - its compartment and the overall one - and which of them the user
  # means is a rule of its own, not something to settle by fragment order.
  class SmartDrawMouthPanelActionHandler < SmartDrawPanelActionHandler

    STATE_PLACE = 0

    LAYER_3D_PANEL_PREVIEW = 200

    LAYER_2D_WIDTH = 100

    # Minimum dot between an opening's outward normal and the direction the
    # camera looks FROM, for that opening to be a candidate : an opening seen
    # edge-on, or from behind, is not the one the user is pointing at. A
    # panel may still be as flat as 6° from edge-on and take a panel - only
    # the ones actually turned away are ruled out.
    OPENING_FACING_MIN_DOT = 0.1

    # Below this dot deviation two opening normals are the same direction,
    # and below this projected area (square inches) a triangle stands edge-on
    # to the opening plane : it projects to a segment and brings nothing to
    # the container's silhouette.
    OPENING_PLANE_MIN_DOT = 1.0 - 1e-6
    FOOTPRINT_MIN_TRIANGLE_AREA = 1e-9

    # How far the silhouette is grown and shrunk back to shake the union's
    # degeneracies out of it - see #_compute_footprint_paths. A tenth of the
    # model tolerance : wide enough that no contact survives it as a mere
    # touch, narrow enough that nothing a carcass is actually made of is
    # thinner.
    FOOTPRINT_CLEANUP_DELTA = SolidMeshDef::TOLERANCE / 10.0

    # How far off the straight line its two neighbours draw a vertex of a
    # panel outline may sit and still be no corner at all - see
    # #_flatten_outline. Same order as the silhouette cleanup, and for the
    # same reason : a tenth of the model tolerance is under anything drawn on
    # purpose and over everything left behind by an assembly meant to be
    # flush.
    OUTLINE_FLAT_TOLERANCE = SolidMeshDef::TOLERANCE / 10.0

    # How far a cavity's share of the panel is grown to see whether it
    # TOUCHES another - see #_merge_adjacent?. The contact between two shares
    # is exact, they are cut apart by the very same bisector, so all this has
    # to tell apart is a contact by an EDGE from one by a mere CORNER : grown
    # by delta, a share overlaps an edge neighbour over delta times the
    # length of their common border, and a diagonal one over delta squared.
    MERGE_ADJACENCY_DELTA = SolidMeshDef::TOLERANCE

    # The shortest common border two shares may be merged on. A tenth of an
    # inch of contact is a corner, not a shared panel - and it stands four
    # orders of magnitude over what a corner actually scores.
    MERGE_MIN_SHARED_BORDER = 0.1

    # Below this norm the picked face's normal, projected on the opening
    # plane, is no direction at all : the face is nearly PARALLEL to the
    # opening and says nothing about where the panels should meet. Both
    # normals being unit, that norm IS the sine of the angle between the two
    # planes - so this is a 10 degree threshold.
    SPLIT_DIRECTION_MIN_NORM = 0.17

    # Below this the way a direction reads on an axis is no reading at all,
    # and the next criterion of #_orient_split_direction takes over.
    SPLIT_DIRECTION_WAY_EPSILON = 1e-6

    # The narrowest a panel may be, anywhere - see #_clean_pieces.
    # Whatever the sharing and the clearance leave narrower than this is no
    # panel anyone would cut : the 1 mm bridge a clearance leaves between the
    # two legs of a U, a sliver a band catches off the tip of a leg, a lip a
    # carcass leaves on its silhouette.
    PANEL_MIN_WIDTH = 5.mm

    attr_reader :locked_direction, :number, :widths

    def initialize(action, tool, previous_action_handler = nil)
      super

      # Compared on the CONCRETE class : a front panel and a back are shared
      # and locked on their own terms, and switching from one action to the
      # other is not the same gesture going on.
      @locked_direction = previous_action_handler.is_a?(self.class) ? previous_action_handler.locked_direction : nil
      @number = previous_action_handler.is_a?(self.class) ? previous_action_handler.number : 1
      @widths = previous_action_handler.is_a?(self.class) ? previous_action_handler.widths : []

      @picked_point = nil

      @merge_context = nil
      @merge_fragment_defs = []
      @merge_paths = []
      @merge_mouth_paths = []
      @merge_cancelled = false

    end

    # -----

    def get_state_picker(state)

      case state
      when STATE_PLACE
        return SmartPicker.new(tool: @tool, observer: self, pick_point: true)
      end

      super
    end

    def get_state_status(state)

      case state
      when STATE_PLACE
        return super +
               (_merge_allowed? ? ' | ' + PLUGIN.get_i18n_string("tool.smart_#{@tool.get_stripped_name}.action_#{@action}_state_#{state}_merge_status") + '.' : '') +
               ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' + X = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_construction_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_measure_reversed_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_reduce_envelope_status') + '.'
      end

      super
    end

    def get_state_vcb_label(state)

      case state
      when STATE_PLACE
        return PLUGIN.get_i18n_string("tool.default.vcb_thickness")
      end

      super
    end

    # -----

    # A pick that stays DOWN opens a MERGE : the panel then spans every cavity
    # the cursor visits before the button comes back up - one leaf over
    # several compartments, the way a panel is often built.
    #
    # What the pick resolves to is frozen here, once : the opening, the frame
    # it is read in, the direction the panels would be shared along. The drag
    # only ever adds cavities to it. That is what lets the cursor cross a
    # chant, a hinge, the outside of the case - anything that resolves to no
    # cavity at all - without the panel losing the shape it has.
    #
    # Only where the pose allows it at all - see #_merge_allowed?. The gesture
    # then simply is the click it always was.
    #
    # What is kept of the picked cavity is its SHARE and its MOUTH, not the
    # contour the context carries : that one has already been through the pose's
    # own growth (see #_get_panel_nominal_points), and feeding a grown contour
    # back into the growth at the next cavity would grow it twice. The contour
    # is rebuilt from these two, whole, at every cavity that comes in.
    def onToolLButtonDown(tool, flags, x, y, view)
      super

      case @state
      when STATE_PLACE
        @merge_cancelled = false
        if _merge_allowed? && (context = _compute_panel_context(@picked_point, view)).is_a?(MouthPanelContext)
          ti = context.transformation.inverse
          share_points = _get_cavity_share_points(context.fragment_def, context.opening_def, ti)
          mouth_points = _get_cavity_mouth_points(context.fragment_def, context.opening_def, ti)
          unless share_points.nil? || mouth_points.nil?
            @merge_context = context
            @merge_fragment_defs = [ context.fragment_def ]
            @merge_paths = [ Fiddle::Clippy.points_to_rpath(share_points) ]
            @merge_mouth_paths = [ Fiddle::Clippy.points_to_rpath(mouth_points) ]
          end
        end
      end

      true
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      super

      case @state
      when STATE_PLACE
        if @merge_cancelled
          # The drag was called off while the button was still down : this is
          # the release of a gesture that no longer stands for anything.
          @merge_cancelled = false
        else
          merging = _merging?
          if _create_entity(@picked_point, view)
            _reset_merge
            # The cavities are NOT re-read : laying a panel on the carcass does
            # not change the compartments it has, and the next panel is to be
            # fitted to the same bare openings as this one. The detection would
            # come to the same answer anyway - the panel goes on a layer marked
            # as such, which #_get_cavities_def leaves out of the enclosure -
            # this only spares paying for it again at every panel.
            _refresh
          else
            # The merged panel is gone with the drag that carried it : the
            # preview has to stop showing it.
            _reset_merge
            _refresh if merging
            UI.beep
          end
        end
      end

      true
    end

    # The distribution is the only thing a pick cannot undo by itself, and it
    # survives from one panel to the next on purpose : it is unwound here, the
    # pinned widths first, then the count.
    def onToolCancel(tool, reason, view)

      # The button is still down when a drag is called off : the release that
      # follows must not build the panel it was about.
      if _merging?
        _reset_merge
        @merge_cancelled = true
        _refresh
        return true
      end

      if @widths.any?
        _set_distribution(@number, [], tool, view)
        return true
      end
      if @number > 1
        _set_distribution(1, [], tool, view)
        return true
      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)
      return true if super

      case @state

      when STATE_PLACE

        if tool.is_key_shift_down?
          if key == Kuix::VK_ADD
            _set_distribution(@number + 1, @widths, tool, view)
            return true
          end
          if key == Kuix::VK_SUBTRACT
            _set_distribution(@number - 1, @widths, tool, view)
            return true
          end
        end

        # The arrow keys pin the direction the panels succeed one another
        # along, the way they pin the divider's normal - the same axis, the
        # same frame (see the axes option). It only has anything to say once
        # the opening is SHARED : a lone panel takes the whole mouth
        # whichever way it would have been cut.
        if key == VK_RIGHT
          _toggle_locked_direction(_get_active_x_axis)
          return true
        end
        if key == VK_LEFT
          _toggle_locked_direction(_get_active_y_axis)
          return true
        end
        if key == VK_UP
          _toggle_locked_direction(_get_active_z_axis)
          return true
        end
        if key == VK_DOWN
          _toggle_locked_direction(nil)
          return true
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_PLACE
        if tool.is_key_ctrl_or_option?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED, !_fetch_option_measure_reversed?, fire_event: true)
          return true
        end
        if tool.is_key_alt_or_command?(key) && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, !_fetch_option_reduce_envelope?, fire_event: true)
          return true
        end

      end

    end

    def onToolUserText(tool, text, view)

      return true if _read_number(tool, text, view)
      return true if _read_widths(tool, text, view)
      return true if _read_panel_lengths(tool, text, view)
      return true if _read_thickness(tool, text, view)

      false
    end

    def onPickerChanged(picker, view)
      case @state

      when STATE_PLACE
        if _merging?
          _merge_pick(picker, view)
        else
          _pick_part(picker, view)
          if has_active_part?
            if _snap_point(picker)
              @tool.remove_tooltip
              @tool.pop_cursor(SmartCursorManager.cursor_select_error)
            else
              @tool.show_tooltip(PLUGIN.get_i18n_string("tool.smart_draw.error.invalid_#{_panel_i18n_key_suffix}_cavity"), SmartTool::MESSAGE_TYPE_ERROR)
              @tool.push_cursor(SmartCursorManager.cursor_select_error)
            end
          end
        end
        _preview_panel(view)
        _preview_cavity
      end

      super
    end

    def onToolActionOptionStored(tool, action, option_group, option)
      # The lock holds an axis of the frame the option just changed : it no
      # longer stands for the one the user pointed at.
      @locked_direction = nil if option_group == SmartDrawTool::ACTION_OPTION_AXES
      # OVERLAY is folded into #_cavities_reduce_envelope? itself (an applied
      # panel never wants a receded mouth - see there), so flipping it can
      # change what the cavities compute to just as much as the option does.
      if option_group == SmartDrawTool::ACTION_OPTION_OVERLAY ||
         (option_group == SmartDrawTool::ACTION_OPTION_OPTIONS && option == SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE)
        _reset_cavities_def
      end
      _refresh
    end

    def onToolTransactionUndo(tool, model)
      _reset_cavities_def
      super
    end

    # -----

    protected

    # -----

    def _reset
      @picked_point = nil
      @locked_direction = nil
      @number = 1
      @widths = []
      @merge_cancelled = false
      _reset_merge
      super
    end

    def _reset_cavities_def
      @footprint_container_path = nil
      @footprint_paths_cache = nil
      @silhouette_paths_cache = nil
      @panel_footprint_container_path = nil
      @panel_footprint_paths_cache = nil
      @share_container_path = nil
      @share_points_cache = nil
      super
    end

    def _refresh
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    # Locks the split direction on +direction+, or unlocks it - pressing the
    # axis it is already on being how the lock is called off, exactly as on
    # the divider.
    def _toggle_locked_direction(direction)
      @locked_direction = @locked_direction == direction ? nil : direction
      _refresh
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      return [ false, "tool.smart_draw.error.invalid_#{_panel_i18n_key_suffix}_seed" ] unless (!part.is_a?(Part) || part.group.material_type != MaterialAttributes::TYPE_HARDWARE)
      return [ false, "tool.smart_draw.error.invalid_#{_panel_i18n_key_suffix}_container" ] if !part_entity_path.nil? && part_entity_path.one?

      # The inherited tests first : no point paying for a cavity detection on a part that will be refused anyway.
      can_activate, _ = super_result = super
      return super_result unless can_activate

      return [ false, "tool.smart_draw.error.no_#{_panel_i18n_key_suffix}_cavity" ] if (cavities_def = _get_cavities_def(part_entity_path, part)).is_a?(CavitiesDef) && cavities_def.valid? && cavities_def.fragment_defs.empty?

      super_result
    end

    def _preview_part_mesh?
      false
    end

    def _preview_part_container?
      true
    end

    # -----
    # Every cavity the panel spans while a merge is on, not just the one under
    # the cursor : the whole point of the drag is to see the set grow.
    def _get_preview_cavity_fragment_defs(cavities_def)
      return @merge_fragment_defs if _merging?
      super
    end

    # -----

    # "x3", "*3" or "/3" - how many panels share the opening. The two forms
    # mean the same layout here, unlike the divider's : a panel takes no
    # thickness out of the opening, so "3 of them" and "divide it in 3"
    # describe the very same three panels.
    def _read_number(tool, text, view)
      return false unless text.is_a?(String) && (match = text.match(/^([x*\/])(\d+)$/))

      value = match[2]
      number = value.to_i

      if number < 1
        UI.beep
        tool.notify_errors([ [ 'tool.default.error.invalid_divider', { :value => value } ] ])
        return true
      end

      _set_distribution(number, @widths, tool, view)
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # A list of lengths - "400;500", regional list divider, "400=" repeating
    # a value (see #_split_user_text) - PINS the widths of the current
    # distribution instead of leaving them all equal. Same VCB grammar and
    # same reading as the Smart Draw Divider's spacings : the leading run
    # pins from the near end of the opening, the trailing run from the far
    # end, an invalid or empty entry marking where the free middle begins -
    # "400;" pins only the first panel, ";400" only the last. Which end is
    # near is settled by #_orient_split_direction, never by where the cursor
    # happened to be. See #_get_panel_band_intervals.
    def _read_widths(tool, text, view)

      list = _split_user_text(text)
      return false unless list.is_a?(Array) && list.size > 1

      # An entry that is not a length at all is not an error here : it is how
      # the user says "leave this one free"
      widths = list.map { |width|
        length = _read_user_text_length(tool, width, -1)
        length.nil? || length == -1 ? -1 : length.abs.to_l
      }

      number = [ @number, widths.select { |width| width > 0 }.size ].max

      _set_distribution(number, widths, tool, view)
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    def _read_thickness(tool, text, view)

      thickness = _read_user_text_length(tool, text)
      return true if thickness.nil?

      if thickness < 0
        tool.notify_errors([[ 'tool.default.error.invalid_thickness', { :value => thickness } ]])
        return true
      end

      @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_THICKNESS, SmartDrawTool::ACTION_OPTION_THICKNESS_THICKNESS, thickness.to_s, fire_event: true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # The SUFFIXED lengths of the VCB, which a bare length cannot stand for
    # here - it is already the thickness. None by default : what a panel has
    # besides its thickness is its own business (see
    # SmartDrawFrontPanelActionHandler#_read_panel_lengths for the clearance,
    # and SmartDrawBackPanelActionHandler for the groove depth and the
    # setback). Answers true once one of them was read, the way every other
    # #_read_* does.
    def _read_panel_lengths(tool, text, view)
      false
    end

    # Reads +text+ as the length +suffix+ marks - "3x" for a suffix of "x" -
    # and stores it in +option+ of the OFFSET group. nil when the text is not
    # suffixed that way at all, so the caller can try the next grammar ; true
    # once the text was ABOUT that length, whether or not it turned out to be
    # a usable one.
    def _read_suffixed_offset(tool, text, suffix, option)
      return nil unless text.is_a?(String) && (match = /^(.+)#{suffix}$/i.match(text))

      length = _read_user_text_length(tool, match[1])
      return true if length.nil?

      if length < 0
        tool.notify_errors([[ 'tool.default.error.invalid_offset', { :value => length } ]])
        return true
      end

      @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OFFSET, option, length.to_s, fire_event: true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _fetch_option_thickness
      @tool.fetch_action_option_length(@action, SmartDrawTool::ACTION_OPTION_THICKNESS, SmartDrawTool::ACTION_OPTION_THICKNESS_THICKNESS)
    end

    def _fetch_option_overlay_full_overlay?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OVERLAY, SmartDrawTool::ACTION_OPTION_OVERLAY_FULL_OVERLAY)
    end

    def _fetch_option_reuse_definition?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
    end

    def _fetch_option_measure_reversed?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED)
    end

    def _fetch_option_reduce_envelope?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE)
    end

    # Not exposed in the action's options panel : the layer panels are put on
    # is a technical setting, not a drawing option - only the modal (see
    # modal-smart-draw-tool-action-4.twig and -5) gives access to it.
    def _fetch_option_layer_name
      @tool.fetch_action_option_string(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_LAYER_NAME)
    end

    # -- WHAT KIND OF PANEL THIS IS --
    #
    # Everything that tells one panel of a mouth from another, and nothing
    # else. The pipeline above and below is deliberately blind to it : a front
    # panel and a back are cut from the same mouth, shared the same way, built
    # and reused by the same code, and only these few answers differ.

    # The word the action's own i18n keys are built on - the errors it raises
    # about the part it is offered, the cavity it finds, the count it cannot
    # fit. Abstract : there is no such thing as a panel in general to name.
    def _panel_i18n_key_suffix
      raise NotImplementedError
    end

    # The LAYER type the panels are marked with, which is the only thing that
    # says what a panel is FOR - see LayerAttributes. Read both ways : it
    # marks what this handler builds, and it recognises what it must not build
    # on top of (see #_picked_on_existing_panel?). Abstract, and for the very
    # reason the marking exists : geometry cannot answer it.
    def _panel_layer_type
      raise NotImplementedError
    end

    # The name of the model operation the batch is built in - what the user
    # reads in the undo stack. Abstract.
    def _panel_operation_name
      raise NotImplementedError
    end

    # Off by default, like the base class : reduction pulls a cavity's own
    # mouth back to a recessed chant, which is the LAST place a panel
    # spanning the whole opening wants it. Turned on, though, it is what lets
    # a recessed divider (or shelf) split the opening into one cavity per
    # compartment in the first place - with nothing left to select, there
    # would be no per-compartment panel to place.
    #
    # OVERLAY is the exception, whatever the option says : an applied panel
    # is read off the RECEDED mouth just the same (#_get_panel_nominal_points
    # starts from opening_def.outer_loop before growing it), and everything
    # #_get_overlay_points then builds - the frame the growth happens in, and
    # the plane the panel is finally cut and placed on - inherits that same
    # setback. The growth itself lands right, since #_compute_footprint_paths
    # reads the UNREDUCED panels, but at the wrong depth : the panel ends up
    # spanning the container's true outer silhouette - the untouched contour
    # stiles included - while sitting flush with the recessed divider's edge,
    # deep enough behind the case's own front to bury itself in the stiles'
    # own material. INSET has no such trap : its panel IS the mouth, at
    # whatever depth that mouth sits.
    def _cavities_reduce_envelope?
      _fetch_option_reduce_envelope? && !_fetch_option_overlay_full_overlay?
    end

    # -----

    # Whether the given pick lands on a panel already built there, rather
    # than on the bare cavity behind it.
    #
    # Nothing downstream can tell the two apart on its own : an INSET panel's
    # outward face sits exactly on the mouth it fills, so nudged inward (see
    # #_get_cavity_fragment_def) it lands in the very same compartment a bare
    # opening would - offering to build a second panel where one already
    # stands. #_get_panel_opening_def cannot catch it either : it only reads
    # what the pick resolved TO, never what actually stopped the ray. Only the
    # pick itself still knows that, off the face it hit - marked, like every
    # panel, by its LAYER alone (see LayerAttributes).
    #
    # Its OWN kind of panel, never every kind : a back panel already drawn is
    # the most natural thing in the world to hover when a front panel is being
    # drawn - it is the back wall of the very cavity being faced, see
    # #_get_split_direction - and refusing that pick would refuse the tool's
    # commonest gesture.
    def _picked_on_existing_panel?(picker)
      (picked_face_path = picker.picked_face_path).is_a?(Array) &&
        picked_face_path.any? { |entity| LayerAttributes.type_of(entity) == _panel_layer_type }
    end

    # A pick on an existing panel snaps to nothing : see
    # #_picked_on_existing_panel?. Nothing at all - the point the
    # previous pick left is dropped too, or #_preview_cavity would go on
    # drawing the cavity that pick landed in.
    def _snap_point(picker)
      if _picked_on_existing_panel?(picker)
        @picked_point = nil
        return false
      end
      super
    end

    # -----

    # What the pick resolves to, before any outline is cut : the MouthPanelContext,
    # or nil when the pick is not on a cavity that has an opening facing the
    # viewer.
    #
    # Split out of #_compute_panel_defs so that a count can be validated (see
    # #_set_distribution) against the very contour the preview is cut from.
    def _compute_panel_context(point, view)
      # A merge in progress IS the answer : it was resolved when the drag
      # opened, and has been fed cavities ever since (see #_merge_add).
      return @merge_context if _merging?

      return nil unless point.is_a?(Geom::Point3d)
      return nil if _picked_on_existing_panel?(@picker)
      return nil unless (picked_face_manipulator = @picker.picked_plane_manipulator).is_a?(PlaneManipulator)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      fragment_def = _get_cavity_fragment_def(cavities_def, point, picked_face_manipulator)
      return nil unless fragment_def.is_a?(SolidCavityFragmentDef)

      opening_def = _get_panel_opening_def(fragment_def, view)
      return nil if opening_def.nil?

      t = _get_opening_transformation(opening_def)
      ti = t.inverse

      points = _get_panel_nominal_points(fragment_def, opening_def, ti)
      return nil if points.nil? || points.length < 3

      MouthPanelContext.new(cavities_def, fragment_def, opening_def, t, points, _get_split_direction(picked_face_manipulator, opening_def, ti, view))
    end

    # The opening's OWN frame, where the mouth lies flat on z = 0 and
    # everything below is computed.
    #
    # CANONICAL for the PLANE - its origin is the world origin projected on it,
    # its axes come from the normal alone - so two cavities sharing a panel read
    # their neighbours and the container's silhouette in the very same
    # coordinates, the silhouette can be computed once for them all, and anyone
    # holding nothing but an opening_def (see
    # SmartDrawBackPanelActionHandler#_prepare_panels!) reads the same frame the
    # contours were cut in.
    def _get_opening_transformation(opening_def)
      x_axis, y_axis, z_axis = opening_def.normal.axes
      Geom::Transformation.axes(Geom::Point3d.new(0, 0, 0).project_to_plane(opening_def.plane), x_axis, y_axis, z_axis)
    end

    # The panels the pick resolves to, in the split direction's own order -
    # band after band, and across it within a band the contour cuts in
    # several pieces - so the same pick always yields them in the same order,
    # and the batch is always named after the same one. nil when the pick is
    # not on a usable opening, or when the count does not fit on it.
    def _compute_panel_defs(point, view)
      return nil unless (context = _compute_panel_context(point, view)).is_a?(MouthPanelContext)

      thickness = _fetch_option_thickness
      return nil if thickness.nil? || thickness <= 0

      bands = _get_panel_outlines(context)
      return nil if bands.nil?

      overlay = _fetch_option_overlay_full_overlay?
      direction = context.world_direction
      bands.each_with_index.flat_map { |outlines, band|
        outlines.map { |plane_outline, outline| MouthPanelDef.new(context.container_path, context.fragment_def, context.opening_def, outline, thickness, overlay, direction, band, plane_outline) }
      }
    end

    # Applies a new distribution - how many panels, and which widths are
    # pinned - then previews it, reporting the one thing the user cannot see
    # coming : a layout the opening under the cursor has no room for. It is
    # still stored in that case, the pick may well land on a roomier opening
    # next.
    def _set_distribution(number, widths, tool, view)

      @number = [ number, 1 ].max
      @widths = widths

      if _shared? && (context = _compute_panel_context(@picked_point, view)).is_a?(MouthPanelContext) && _get_panel_outlines(context).nil?
        UI.beep
        tool.notify_errors([ [ "tool.smart_draw.error.#{_panel_i18n_key_suffix}_number_overflow", { :number => @number } ] ])
      end

      _refresh
    end

    # Whether the opening is SHARED at all - several panels, or a single one
    # the user pinned the width of. A lone panel taking the whole contour
    # short circuits the whole sharing pass.
    def _shared?
      @number > 1 || @widths.any?
    end

    # The opening a panel is meant for : among the ones the cavity has, the one
    # turned most squarely the way #_panel_opening_facing_vector asks for.
    #
    # Nothing in the cavity says which of its mouths is which - a through tube
    # has two, congruent ones. What says it is the VIEWER, and which way round
    # depends on what is being drawn : a front panel goes on the mouth the
    # camera faces, a back panel on the one at the far end of the same look
    # (see the hook). An opening turned the other way, or seen edge-on
    # (OPENING_FACING_MIN_DOT), is not a candidate at all.
    #
    # FACING first, area only to break a tie between two openings the camera
    # is square to alike. Reading the area first looks reasonable - the main
    # panel is usually the biggest mouth - and is wrong as soon as the case
    # is seen from three quarters : a compartment open on its side offers a
    # mouth several times the panel's, and the panel lands on the flank the
    # user is not even looking at. What the user points at is what they FACE.
    def _get_panel_opening_def(fragment_def, view)
      facing = _panel_opening_facing_vector(view)

      best = nil
      best_score = nil
      fragment_def.opening_defs.each do |opening_def|
        normal = opening_def.normal
        dot = normal.x * facing[0] + normal.y * facing[1] + normal.z * facing[2]
        next if dot < OPENING_FACING_MIN_DOT
        score = [ dot, opening_def.area ]
        next unless best_score.nil? || (score <=> best_score) > 0
        best = opening_def
        best_score = score
      end

      best
    end

    # The direction an opening's outward normal has to point along to be the
    # one this pick means, as [ x, y, z ].
    #
    # Towards the CAMERA here : a panel is drawn on the opening the user is
    # looking into, which is the mouth of the compartment facing them.
    # A handler whose panel closes the FAR end of that look reverses it - see
    # SmartDrawBackPanelActionHandler.
    def _panel_opening_facing_vector(view)
      direction = view.camera.direction
      [ -direction.x, -direction.y, -direction.z ]
    end

    # The NOMINAL contour the panels are cut out of, in the opening's frame -
    # before the count shares it and before the clearance pulls it back.
    #
    # Two POSES, and what separates them is entirely here :
    #
    #   INSET   : the mouth itself, the opening's outer contour.
    #   OVERLAY : the share of the container's front this cavity is entitled
    #             to - see #_get_overlay_points.
    def _get_panel_nominal_points(fragment_def, opening_def, ti)

      mouth = opening_def.outer_loop
      return nil if mouth.nil? || mouth.length < 3

      mouth_points = mouth.map { |point| point.transform(ti) }

      points = _fetch_option_overlay_full_overlay? ? _get_overlay_points(fragment_def, opening_def, mouth_points, ti) : mouth_points
      return nil if points.nil? || points.length < 3

      _grow_nominal_points(points, opening_def, ti)
    end

    # The nominal contour GROWN to what the panel is really cut to, still in
    # the opening's frame. Unchanged here : a panel of a mouth is the mouth,
    # or the share of the front it is entitled to, and nothing more.
    #
    # A panel that sits in a GROOVE is wider than its mouth by the depth it
    # runs into the parts around it (see SmartDrawBackPanelActionHandler), and
    # this is where it says so - BEFORE the count shares the contour, unlike
    # the clearance, which applies after : two panels cut out of one contour
    # BUTT on their seam, they do not each grow into it.
    def _grow_nominal_points(points, opening_def, ti)
      points
    end

    # How far the panels stand back from the opening plane, along its INWARD
    # normal - the plane they are really laid on. Zero here : both poses lay
    # the panel against the mouth, on one side of it or the other.
    #
    # A groove takes the panel deeper than that (see
    # SmartDrawBackPanelActionHandler) and the whole of the rest of the
    # pipeline is blind to it : an outline is carried by its own frame, whose
    # origin is a point OF that outline, so moving every point of it along the
    # normal moves the part and nothing else - the preview, the reuse test and
    # the mirror test all read it the same.
    def _panel_outline_offset(opening_def)
      0
    end

    # The outlines the panels are cut to - one list per band, ordered along
    # the split direction, each holding [ the outline in the OPENING's frame,
    # the same outline in WORLD coordinates ] of every panel that band comes
    # out as (see #_split_points). The frame one is what a handler cutting
    # into the parts around the panel reads its ring off (see
    # SmartDrawBackPanelActionHandler) ; the world one is what gets built.
    #
    # The nominal contour is shared FIRST, and only then does the CLEARANCE
    # apply, to each panel on every one of its own edges. That order is the
    # whole point : it is how a set of panels is specified - a 2 mm clearance
    # takes 4 mm off the pair's width, 4 off its height, and leaves 4 mm
    # between the two leaves. A PINNED width is therefore the width of the
    # share, not of the finished leaf, exactly as a pinned opening is for the
    # divider.
    #
    # The clearance may in turn cut a piece in several, and so may
    # PANEL_MIN_WIDTH : a neck left narrower than that simply vanishes,
    # and what it joined becomes as many panels (see
    # #_apply_panel_clearance). The pieces of a band are therefore ordered
    # only once all of them are known - see #_sort_pieces_across.
    #
    # nil when the layout leaves nothing buildable : a count the contour is
    # too narrow for, or a band the clearance leaves nothing of. Building
    # fewer panels than asked is not the answer - a band losing SOME of
    # its pieces is : a sliver thinner than PANEL_MIN_WIDTH never was a
    # panel to begin with.
    def _get_panel_outlines(context)

      if _shared?
        bands = _split_points(context.points, context.direction, @number, @widths)
        return nil if bands.nil?
      else
        bands = [ [ context.points ] ]
      end

      # The panels stand back along the opening's INWARD normal, so the offset
      # is taken the other way round.
      offset = _panel_outline_offset(context.opening_def)
      normal = context.opening_def.normal

      bands.map { |pieces|
        outlines = pieces.flat_map { |piece| _apply_panel_clearance(piece) }
        return nil if outlines.empty?
        _sort_pieces_across(outlines, context.direction).map { |points|
          plane_outline = _flatten_outline(points)
          world_outline = plane_outline.map { |point| point.transform(context.transformation) }
          world_outline = world_outline.map { |point| point.offset(normal, -offset) } unless offset == 0
          [ plane_outline, world_outline ]
        }
      }
    end

    # +pieces+ - the panels one band comes out as, in the opening's
    # frame - ordered ACROSS the split +direction+, so that the same pick
    # always yields them in the same order, whatever order Clipper hands them
    # over in. The opening's frame has its x to the right as seen from
    # outside, so turning the direction CLOCKWISE reads them in reading
    # order : left to right across stacked bands, top to bottom across bands
    # side by side. A lone panel may have no direction at all, and is
    # then read as stacked.
    def _sort_pieces_across(pieces, direction)
      return pieces if pieces.length < 2
      dx, dy = direction.nil? ? [ 0.0, 1.0 ] : direction
      pieces.sort_by { |piece| piece.map { |point| point.x.to_f * dy - point.y.to_f * dx }.min }
    end

    # Drops the vertices that draw no corner : the ones sitting, within
    # OUTLINE_FLAT_TOLERANCE, on the straight line their two neighbours draw.
    #
    # A carcass is full of faces MEANT to be flush - the end of a panel cut
    # to the very plane of the face of the next one at a mitre - and modelled
    # a micron off. The silhouette then carries a 179.999 degree vertex that
    # Clipper, rightly, has no reason to drop, and the panel built on it comes
    # out with a superfluous edge splitting one of its sides into two coplanar
    # faces. The mouth of a cavity, read off a triangle soup, can hand over
    # such a vertex just as well - so the panel outline is flattened whatever
    # the overlay setting that drew it.
    #
    # Read as a DISTANCE to the chord rather than as an angle : it is the
    # sagitta that says whether the corner would ever be seen, where an angle
    # reads wide on a very short edge that deviates by nothing at all.
    #
    # One vertex at a time, and over again : dropping one puts its neighbours
    # face to face and may well flatten them in turn.
    def _flatten_outline(points)

      outline = points
      while outline.length > 3

        index = (0...outline.length).find { |i|
          _chord_deviation(outline[i], outline[i - 1], outline[(i + 1) % outline.length]) <= OUTLINE_FLAT_TOLERANCE
        }
        break if index.nil?

        outline = outline.dup if outline.equal?(points)
        outline.delete_at(index)

      end
      outline
    end

    # Distance from +point+ to the straight line through its two neighbours,
    # zero when the three are aligned. Neighbours that coincide draw no line
    # at all : the point is then the tip of a spur, and reads as flat, which
    # is exactly what it is.
    def _chord_deviation(point, previous_point, following_point)
      dx = (following_point.x - previous_point.x).to_f
      dy = (following_point.y - previous_point.y).to_f
      length = Math.sqrt(dx * dx + dy * dy)
      return 0.0 if length <= 0
      ((point.x - previous_point.x).to_f * dy - (point.y - previous_point.y).to_f * dx).abs / length
    end

    # The direction, in the opening's own frame ([ x, y ] unit Floats), the
    # panels succeed one another along - so the cuts between them run
    # PERPENDICULAR to it, that is, PARALLEL to the panel under the cursor.
    #
    # That panel is the whole rule : its normal, projected on the opening
    # plane. Hovering a side gives panels side by side, hovering a shelf gives
    # them stacked, and an oblique panel gives a cut parallel to it - nothing
    # is snapped to the container's axes, so a canted carcass reads as
    # exactly as an orthogonal one.
    #
    # A panel PARALLEL to the opening says nothing : the projection vanishes
    # (SPLIT_DIRECTION_MIN_NORM), and that panel is the BACK of the very
    # cavity being faced - the most natural thing to hover on a case seen
    # from the front. The fallback is then the horizontal of the opening
    # plane, hence vertical cuts and panels side by side, which is what a pair
    # of panels usually is. It is read off the world's own up rather than off
    # the camera so that orbiting does not swing it around ; on a HORIZONTAL
    # opening, where there is no horizontal of the plane to speak of, the
    # screen's own right takes over.
    #
    # A LOCKED axis (arrow keys) overrides the panel rule entirely : the
    # panels then succeed one another along that axis, whatever the cursor
    # rests on - which is the whole point, the pick being free to wander over
    # the cavity while the layout holds.
    #
    # The "measure reversed" option flips the WAY only, after it is settled -
    # the same complement it applies to a pinned measure anywhere else in the
    # tool - so the pinned widths count from the opposite end.
    def _get_split_direction(picked_face_manipulator, opening_def, ti, view)
      normal = opening_def.normal

      direction = _get_locked_split_direction(normal)

      if direction.nil?

        direction = _vector_rejection(picked_face_manipulator.normal, normal)

        if direction.length.to_f < SPLIT_DIRECTION_MIN_NORM
          direction = normal.cross(Z_AXIS)
          unless direction.valid?
            camera = view.camera
            direction = _vector_rejection(camera.direction.cross(camera.up), normal)
            return nil unless direction.valid?
          end
        end

      end

      direction = _orient_split_direction(direction.normalize, normal)
      direction = direction.reverse if _fetch_option_measure_reversed?
      direction = direction.transform(ti)

      [ direction.x, direction.y ]
    end

    # What the locked axis amounts to on the opening the panels are cut from :
    # its share of that plane. nil when no axis is locked, and nil too when
    # the locked one stands too close to the opening's OWN normal to say
    # anything about a direction in it - the very threshold the panel under
    # the cursor is held to. The lock is then simply inert on this opening,
    # rather than cutting the panels on a direction that reads as nothing :
    # a case is faced from several sides, and an axis that means "side by
    # side" on its front means nothing on its flank.
    def _get_locked_split_direction(normal)
      return nil unless @locked_direction.is_a?(Geom::Vector3d) && @locked_direction.valid?

      direction = _vector_rejection(@locked_direction, normal)
      direction.length.to_f < SPLIT_DIRECTION_MIN_NORM ? nil : direction
    end

    # Which WAY that direction points - hence which end the pinned widths are
    # counted from, and which panel the batch is named after.
    #
    # The panel under the cursor gives an AXIS, not a way : the left side of
    # a case and its right side have opposite normals, and "400;" would pin
    # one panel or the other depending on where the cursor happened to be. So
    # the way is settled off the WORLD alone - never off the pick, never off
    # the camera :
    #
    #   - a direction with a vertical component points UP : stacked panels are
    #     pinned from the bottom one.
    #   - a horizontal one points to the RIGHT of the panel as seen from
    #     OUTSIDE it, that is, the one whose turn from the outward normal
    #     goes the same way as the world's up.
    #   - on a HORIZONTAL opening neither reading means anything : +X then
    #     +Y, for the sake of answering the same thing twice.
    def _orient_split_direction(direction, normal)

      z = direction.z
      return direction.reverse if z < -SPLIT_DIRECTION_WAY_EPSILON
      return direction if z > SPLIT_DIRECTION_WAY_EPSILON

      right = normal.cross(direction) % Z_AXIS
      return direction.reverse if right < -SPLIT_DIRECTION_WAY_EPSILON
      return direction if right > SPLIT_DIRECTION_WAY_EPSILON

      return direction.reverse if direction.x < -SPLIT_DIRECTION_WAY_EPSILON
      return direction if direction.x > SPLIT_DIRECTION_WAY_EPSILON

      direction.y < 0 ? direction.reverse : direction
    end

    # +vector+ stripped of its component along +normal+ (a UNIT vector) :
    # what is left of it in the plane +normal+ stands on. Not normalized -
    # its norm is what tells how much of the vector was in the plane to begin
    # with.
    def _vector_rejection(vector, normal)
      dot = vector % normal
      Geom::Vector3d.new(
        vector.x - dot * normal.x,
        vector.y - dot * normal.y,
        vector.z - dot * normal.z
      )
    end

    # +points+ - a closed contour of the opening's frame - shared into
    # +number+ bands along +direction+, ordered from the low end : equal
    # ones, or the ones +widths+ pins (see #_get_panel_band_intervals).
    #
    # Each band is CLIPPED to the contour rather than assumed rectangular :
    # the contour may be canted, notched, or - in applique - the share of a
    # silhouette a neighbour's bisector has already cut into. So a band may
    # well come out in several PIECES - the two legs of a U, cut across - and
    # every one of them is a panel of its own : a panel is one
    # panel, and keeping only one of them would leave the others' part of
    # the opening bare. Each band is therefore a LIST of pieces, handed over
    # raw and in no particular order : #_get_panel_outlines cleans them
    # (see #_clean_pieces) and orders them once the clearance has had its say.
    #
    # nil when the direction is unusable, when the contour is degenerate
    # along it, when the layout does not fit, or when a band comes out empty.
    def _split_points(points, direction, number, widths)
      return nil unless number > 0
      return nil if direction.nil?

      dx, dy = direction

      d0 = d1 = nil
      points.each do |point|
        d = point.x.to_f * dx + point.y.to_f * dy
        d0 = d if d0.nil? || d < d0
        d1 = d if d1.nil? || d > d1
      end
      return nil if d0.nil? || d1 - d0 <= SolidMeshDef::TOLERANCE

      intervals = _get_panel_band_intervals(d0, d1, number, widths)
      return nil if intervals.nil?

      # Through a union, so that the contour is wound the way Clipper expects
      # its subjects whichever way the opening handed it over.
      subject_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(points) ])
      return nil if subject_paths.empty?

      reach = _paths_reach(subject_paths)

      bands = []
      intervals.each do |b0, b1|

        band_paths, _ = Fiddle::Clippy.execute_intersection(
          closed_subjects: subject_paths,
          clips: [ _band_path(dx, dy, b0, b1, reach) ]
        )

        pieces = band_paths.select { |path| path.length >= 6 }.map { |path| Fiddle::Clippy.rpath_to_points(path) }
        return nil if pieces.empty?

        bands << pieces

      end

      bands
    end

    # What of the given paths - a panel's contour, once shared and
    # pulled back by the clearance - can actually be cut : each resulting
    # path is a panel.
    #
    # Straight out of Clipper, not everything is. A band edge landing ON an
    # edge of the contour - a pinned width equal to the depth of a notch,
    # and a notch modelled a micron off that - leaves a hairline that is
    # either DUST of its own, or a BRIDGE a micron thick welding two legs
    # into one ring. And a clearance just short of half a neck leaves a
    # bridge that is real, but no thicker than a veneer : the two legs of a
    # U over a 3 mm band, pulled back by 1 mm on each side, hang together by
    # a 1 mm strip as long as the notch is wide.
    #
    # Shrunk by half of PANEL_MIN_WIDTH and grown straight back, the
    # paths lose all of that : what is narrower than PANEL_MIN_WIDTH -
    # a whole sliver, or the neck between two legs - does not survive the
    # shrinking, and all the rest comes back to the micron, as in
    # #_cleanup_footprint_paths the other way round. The miter joins are what
    # make that round trip exact : every corner is rebuilt sharp, where a
    # rounded join would leave it bevelled.
    def _clean_pieces(paths)
      return [] if paths.empty?

      delta = PANEL_MIN_WIDTH.to_f / 2.0
      shrunk_paths = Fiddle::Clippy.inflate_paths(
        paths: paths,
        delta: -delta,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      return [] if shrunk_paths.empty?

      Fiddle::Clippy.inflate_paths(
        paths: shrunk_paths,
        delta: delta,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      ).select { |path| path.length >= 6 }
    end

    # [ [ b0, b1 ], ... ] the +number+ panels span along the split direction,
    # ordered, inside the contour's own [ +w0+, +w1+ ] extent.
    #
    # What is shared is the whole extent : a panel takes no thickness out of
    # the opening the way a divider does, so with no pin at all the cuts are
    # plain divisions and the bands tile the contour edge to edge.
    #
    # +widths+ PINS bands, from the ends inward : its leading run of valid
    # lengths fixes the first panels, its trailing run - whatever follows an
    # invalid or empty entry, so "400;" pins the first and ";400" the last -
    # fixes the last ones. Only the panels LEFT IN THE MIDDLE share what
    # remains. Pins beyond the count are dropped : they have no panel to size.
    #
    # Pinned runs that do not fill the extent leave the middle of the panel
    # BARE rather than stretching anything : the widths are what the user
    # asked for, and that is the only honest reading of them.
    #
    # nil when the layout does not fit : a middle share with no room left, or
    # pinned runs that overrun each other.
    def _get_panel_band_intervals(w0, w1, number, widths)
      return nil unless number > 0

      fn_valid_width = lambda { |width| width.is_a?(Length) && width > 0 }
      start_widths = widths.take_while(&fn_valid_width)
      end_widths = start_widths.size == widths.size ? [] : widths.reverse.take_while(&fn_valid_width)

      if start_widths.size > number
        start_widths = start_widths.take(number)
        end_widths = []
      elsif start_widths.size + end_widths.size > number
        end_widths = end_widths.take(number - start_widths.size)
      end

      # Pinned from the near end, in order
      start_d = w0
      start_intervals = start_widths.map { |width|
        b0 = start_d
        start_d = b0 + width
        [ b0, start_d ]
      }

      # Pinned from the far end : +end_widths+ reads outermost first, so
      # these come out in reverse
      end_d = w1
      end_intervals = end_widths.map { |width|
        b1 = end_d
        end_d = b1 - width
        [ end_d, b1 ]
      }.reverse

      middle_size = number - start_intervals.size - end_intervals.size
      if middle_size > 0

        width = (end_d - start_d) / middle_size.to_f
        return nil if width <= SolidMeshDef::TOLERANCE

        middle_intervals = (0...middle_size).map { |index|
          b0 = start_d + index * width
          [ b0, b0 + width ]
        }

      else

        # Nothing to share, but the two pinned runs must still not have
        # walked past each other
        return nil if end_d - start_d < -SolidMeshDef::TOLERANCE

        middle_intervals = []

      end

      start_intervals + middle_intervals + end_intervals
    end

    # The band { p | +d0+ <= p . direction <= +d1+ }, as a closed path long
    # enough across to behave like an unbounded strip - wound counter
    # clockwise, the way the NON ZERO fill of the intersection expects it.
    def _band_path(direction_x, direction_y, d0, d1, reach)
      side_x = -direction_y
      side_y = direction_x
      [
        direction_x * d0 - side_x * reach, direction_y * d0 - side_y * reach,
        direction_x * d1 - side_x * reach, direction_y * d1 - side_y * reach,
        direction_x * d1 + side_x * reach, direction_y * d1 + side_y * reach,
        direction_x * d0 + side_x * reach, direction_y * d0 + side_y * reach
      ]
    end

    # One piece of a shared contour, in the opening's frame, as the LIST of
    # panels it really comes out as - normalized, cleaned, and pulled back by
    # whatever CLEARANCE the panel is cut with.
    #
    # No clearance here : a panel takes one only where something has to pass
    # beside it, which is a property of the panel, not of the mouth (see
    # SmartDrawFrontPanelActionHandler, where a pair of leaves has to open).
    # The normalizing union and #_clean_pieces are wanted either way, though -
    # the winding Clipper hands a mouth over with is not a given, and a sliver
    # narrower than PANEL_MIN_WIDTH is no panel whatever cut it.
    #
    # Empty when nothing is left at all : no wider than a sliver to begin
    # with, or too narrow for the clearance everywhere.
    def _apply_panel_clearance(points)

      # The union normalizes the winding, and the winding is what decides
      # which side a negative delta offsets towards.
      paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(points) ])

      _clean_pieces(paths).map { |path| Fiddle::Clippy.rpath_to_points(path) }
    end

    # OVERLAY : the share of the container's front that belongs to this
    # cavity, in the opening's frame.
    #
    # A panel in applique covers the frame around its mouth, and how far is
    # not a number the user should have to give : it is written in the
    # carcass. It runs to the OUTER EDGE of the container where nothing else
    # claims the material, and stops HALF WAY through a panel it shares with
    # a neighbouring compartment, so that the two panels meet on the middle of
    # that panel. Front to front, the pair of them covers the whole panel.
    #
    # Read as a partition of the container's silhouette. Each sibling mouth
    # of the same plane contributes ONE CUT : the perpendicular bisector of
    # the shortest segment between the two mouths, which is the mid plane of
    # the panel they share, and everything past it is taken away. A bisector
    # is a half plane, unbounded - that is the whole point. A collar grown
    # around the neighbour would not do : it stops a few millimetres past its
    # own mouth, and the two shares simply flow into each other around it,
    # along the top and bottom borders of the panel.
    #
    # Nothing is cut out of our own side, so the outer border, claimed by no
    # one else, stays whole. A sibling sitting diagonally cuts on the
    # diagonal, and on a grid of compartments that bisector passes exactly
    # through the corner where the four of them meet : it takes nothing the
    # straight neighbours had not already taken.
    #
    # What is left may well be in several pieces ; ours is the one the mouth
    # falls in. Only its OUTER contour is kept : a hole in the container's
    # front is not the panel's business.
    def _get_overlay_points(fragment_def, opening_def, mouth_points, ti)

      footprint_paths = _get_footprint_paths(opening_def, ti)
      return nil if footprint_paths.nil? || footprint_paths.empty?

      reach = _paths_reach(footprint_paths)

      clips = []
      _get_sibling_mouth_points(fragment_def, opening_def, ti).each do |sibling_points|
        near_point, far_point = _loops_closest_points(mouth_points, sibling_points)
        next if near_point.nil?
        dx = (far_point.x - near_point.x).to_f
        dy = (far_point.y - near_point.y).to_f
        gap = Math.sqrt(dx * dx + dy * dy)
        # Mouths that touch share no panel : there is nothing between them to
        # halve, and no direction to cut along either.
        next if gap <= SolidMeshDef::TOLERANCE
        clips << _half_plane_path((near_point.x + far_point.x).to_f / 2.0, (near_point.y + far_point.y).to_f / 2.0, dx / gap, dy / gap, reach)
      end

      polytree = Fiddle::Clippy.execute_polytree(
        clip_type: clips.empty? ? Fiddle::Clippy::CLIP_TYPE_UNION : Fiddle::Clippy::CLIP_TYPE_DIFFERENCE,
        closed_subjects: footprint_paths,
        clips: clips
      )

      # Through a union, so that the mouth is wound the way Clipper expects
      # whichever way the opening handed it over.
      mouth_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(mouth_points) ])

      best_path = _best_overlapping_path(Fiddle::Clippy.polytree_to_polyshapes(polytree).map { |polyshape| polyshape.paths.first }, mouth_paths)
      return nil if best_path.nil?

      Fiddle::Clippy.rpath_to_points(best_path)
    end

    # The one of +paths+ that covers most of +reference_paths+, or nil when
    # none of them covers any of it.
    #
    # What every reading that comes back in SEVERAL pieces settles on : ours is
    # the piece the mouth falls in. A piece that merely touches the mouth
    # scores nothing, an area being what is compared, so a contour cut in two
    # right along a mouth edge cannot pick the wrong half.
    def _best_overlapping_path(paths, reference_paths)
      best_path = nil
      best_area = 0.0
      paths.each do |path|
        next if path.nil? || path.length < 6
        overlap_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: [ path ], clips: reference_paths)
        area = overlap_paths.inject(0.0) { |sum, overlap_path| sum + Fiddle::Clippy.get_rpath_area(overlap_path) }
        next unless area > best_area
        best_path = path
        best_area = area
      end
      best_path
    end

    # The container's SILHOUETTE on the opening plane : every panel of the
    # container projected on it and unioned - the outline a panel in applique
    # may cover, and no further.
    #
    # A triangle standing edge-on to the plane projects to a segment and is
    # dropped : it adds nothing, and the faces that do face the plane already
    # carry that part of the outline. On a plain carcass that leaves only the
    # front and back faces of each panel, a handful of triangles.
    #
    # Cached per PLANE for the container the cavities were read on : the
    # preview recomputes the panel on every mouse move, the carcass does not
    # change under it.
    def _get_footprint_paths(opening_def, ti)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)

      unless @footprint_paths_cache.is_a?(Hash) && @footprint_container_path == cavities_def.container_path
        @footprint_container_path = cavities_def.container_path
        @footprint_paths_cache = {}
      end

      key = _opening_plane_key(opening_def)
      return @footprint_paths_cache[key] if @footprint_paths_cache.has_key?(key)

      @footprint_paths_cache[key] = _compute_footprint_paths(cavities_def.drawing_defs, ti)
    end

    # The container's SILHOUETTE on the opening plane, OUTER contours only -
    # the limit no panel of that mouth may cross.
    #
    # #_get_footprint_paths is the union of the panels, and a union has HOLES :
    # the mouths themselves, and every window a carcass leaves between its
    # panels. A hole is not a limit - a panel spans it, that is what a panel is
    # for - so only the outer ring of each piece of the silhouette is kept.
    #
    # Cached beside the footprint it is read from, and dropped with it.
    def _get_silhouette_paths(opening_def, ti)
      footprint_paths = _get_footprint_paths(opening_def, ti)
      return nil if footprint_paths.nil? || footprint_paths.empty?

      @silhouette_paths_cache = {} unless @silhouette_paths_cache.is_a?(Hash)

      key = _opening_plane_key(opening_def)
      return @silhouette_paths_cache[key] if @silhouette_paths_cache.has_key?(key)

      polytree = Fiddle::Clippy.execute_polytree(clip_type: Fiddle::Clippy::CLIP_TYPE_UNION, closed_subjects: footprint_paths)
      @silhouette_paths_cache[key] = Fiddle::Clippy.polytree_to_polyshapes(polytree).map { |polyshape| polyshape.paths.first }.compact
    end

    # The footprint of ONE panel of the container on the opening plane, the way
    # #_get_footprint_paths reads them all together - what tells, of a contour
    # drawn on that plane, the part of it that stands over THAT panel.
    #
    # #_compute_footprint_paths already takes a list, so reading one panel is
    # reading a list of one ; only the cache is its own, keyed by the panel as
    # well as by the plane.
    def _get_panel_footprint_paths(drawing_def, opening_def, ti)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)

      unless @panel_footprint_paths_cache.is_a?(Hash) && @panel_footprint_container_path == cavities_def.container_path
        @panel_footprint_container_path = cavities_def.container_path
        @panel_footprint_paths_cache = {}
      end

      key = [ drawing_def.object_id, _opening_plane_key(opening_def) ]
      return @panel_footprint_paths_cache[key] if @panel_footprint_paths_cache.has_key?(key)

      @panel_footprint_paths_cache[key] = _compute_footprint_paths([ drawing_def ], ti)
    end

    # What identifies the PLANE an opening lies on, as a hash key : its
    # normal, and how far from the world origin it stands along it. Both read
    # coarsely enough that two mouths of the same panel answer the same
    # thing - which is the whole point, they share everything that is read
    # per plane.
    def _opening_plane_key(opening_def)
      normal = opening_def.normal
      origin = opening_def.origin
      [
        (normal.x * 1e6).round, (normal.y * 1e6).round, (normal.z * 1e6).round,
        ((origin.x * normal.x + origin.y * normal.y + origin.z * normal.z) / SolidMeshDef::TOLERANCE).round
      ]
    end

    def _compute_footprint_paths(drawing_defs, ti)

      paths = []
      drawing_defs.each do |drawing_def|

        mesh_def = SolidMeshDef.from_drawing_def(drawing_def)
        vertices = mesh_def.vertices
        face_indices = mesh_def.face_indices

        index = 0
        while index < face_indices.length

          points = (0..2).map { |offset|
            base = face_indices[index + offset] * 3
            Geom::Point3d.new(vertices[base], vertices[base + 1], vertices[base + 2]).transform(ti)
          }
          index += 3

          # Twice the signed projected area, and its sign is the winding :
          # the union runs on NON ZERO, so every path is turned the same way
          # before it goes in.
          area = ((points[1].x - points[0].x) * (points[2].y - points[0].y) -
                  (points[1].y - points[0].y) * (points[2].x - points[0].x)).to_f
          next if area.abs < FOOTPRINT_MIN_TRIANGLE_AREA
          points.reverse! if area < 0

          paths << Fiddle::Clippy.points_to_rpath(points)

        end

      end
      return [] if paths.empty?

      footprint_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: paths)
      _cleanup_footprint_paths(footprint_paths)
    end

    # Grows the silhouette by a hair and shrinks it straight back.
    #
    # A no-op on the SHAPE, and not one on the way it is written down. Two
    # panels of a carcass never overlap - they butt - and a MITRE makes that
    # contact degenerate : the end face of one lands exactly on the face of
    # the other, coplanar, so in projection the two outlines share a whole
    # edge and meet on it at a single point. Clipper hands such a union back
    # as ONE self touching path : the outer contour, a zero width slit run
    # down to the mouth and back, then the mouth traversed as if it were part
    # of the outline. Taken for the outer contour it is (see
    # #_get_overlay_points), it cuts the panel to the shape of the carcass
    # frame itself - the panels, mouth left out - instead of the panel.
    #
    # The round trip breaks the tie : grown, the panels genuinely OVERLAP and
    # the union is a plain region ; shrunk back, it comes out as an outer
    # contour and its holes, each on its own path, to the micron. What it
    # also drops on the way is collinear vertices, which is no loss.
    def _cleanup_footprint_paths(footprint_paths)
      return footprint_paths if footprint_paths.empty?

      grown = Fiddle::Clippy.inflate_paths(
        paths: footprint_paths,
        delta: FOOTPRINT_CLEANUP_DELTA,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      return footprint_paths if grown.empty?

      cleaned = Fiddle::Clippy.inflate_paths(
        paths: grown,
        delta: -FOOTPRINT_CLEANUP_DELTA,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      cleaned.empty? ? footprint_paths : cleaned
    end

    # The mouths of the OTHER cavities that open on the very same plane, in
    # the opening's frame - the neighbours a panel in applique has to share
    # the frame with.
    #
    # Same plane AND same side : a cavity opening the other way sits behind
    # the panel and is no neighbour of this panel.
    #
    # A neighbour CLOSED on this very plane - a real panel standing where an
    # opening could have been, e.g. the fitted back of one compartment while
    # the one next to it is bare - has no #opening_defs there at all, and is
    # silently left out of the partition without the fallback below : nothing
    # then cuts the picked cavity's share off from its territory, and the
    # overlay balloons through the shared panel into whatever the neighbour
    # was walling off. #wall_loops_on_plane reads that wall's own inner loop
    # instead, which is flush with the very same panel edges a mouth would
    # have drawn there - so it slots into the same list unchanged. See
    # SolidCavityFragmentDef#wall_loops_on_plane.
    def _get_sibling_mouth_points(fragment_def, opening_def, ti)
      return [] unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)

      mouths = []
      cavities_def.fragment_defs.each do |other_fragment_def|
        next if other_fragment_def.equal?(fragment_def)

        opening_defs_on_plane = _get_opening_defs_on_plane(other_fragment_def, opening_def)
        loops = if opening_defs_on_plane.empty?
          other_fragment_def.wall_loops_on_plane(opening_def.normal, opening_def.origin)
        else
          opening_defs_on_plane.map(&:outer_loop)
        end

        loops.each do |loop_points|
          next if loop_points.nil? || loop_points.length < 3
          mouths << loop_points.map { |point| point.transform(ti) }
        end
      end
      mouths
    end

    # The openings of +fragment_def+ that lie on the SAME plane as the given
    # one - same outward direction, same offset along it. A cavity has at
    # most one on a given panel in all but the twisted cases, but nothing
    # says so : an L shaped compartment may well show two separate mouths on
    # the same front.
    def _get_opening_defs_on_plane(fragment_def, opening_def)
      normal = opening_def.normal
      origin = opening_def.origin
      fragment_def.opening_defs.select { |other_opening_def|
        other_opening_def.normal.dot(normal) >= OPENING_PLANE_MIN_DOT &&
        (other_opening_def.origin - origin).dot(normal).abs <= SolidMeshDef::TOLERANCE
      }
    end

    # The closest pair of points of two closed contours of the plane, the
    # first on the FIRST contour - read on every vertex against every edge of
    # the other, both ways round. Two mouths never overlap, so their contours
    # never cross : the closest pair always has one of its ends on a vertex,
    # and that reading is exact.
    def _loops_closest_points(loop_points, other_loop_points)
      best = nil
      best_distance = nil
      [ [ loop_points, other_loop_points, false ], [ other_loop_points, loop_points, true ] ].each do |points, edge_points, swapped|
        points.each do |point|
          edge_points.each_with_index do |start_point, index|
            foot, distance = _point_segment_foot(point, start_point, edge_points[(index + 1) % edge_points.length])
            next unless best_distance.nil? || distance < best_distance
            best_distance = distance
            best = swapped ? [ foot, point ] : [ point, foot ]
          end
        end
      end
      return [ nil, nil ] if best.nil?
      best
    end

    # [ the point of the segment closest to +point+, its distance ].
    def _point_segment_foot(point, start_point, end_point)
      dx = (end_point.x - start_point.x).to_f
      dy = (end_point.y - start_point.y).to_f
      px = (point.x - start_point.x).to_f
      py = (point.y - start_point.y).to_f
      length2 = dx * dx + dy * dy
      if length2 <= 0
        ratio = 0.0
      else
        ratio = (px * dx + py * dy) / length2
        ratio = 0.0 if ratio < 0.0
        ratio = 1.0 if ratio > 1.0
      end
      foot = Geom::Point3d.new(start_point.x.to_f + ratio * dx, start_point.y.to_f + ratio * dy, 0.0)
      [ foot, Math.sqrt((px - ratio * dx) ** 2 + (py - ratio * dy) ** 2) ]
    end

    # How far a half plane has to run to be, as far as the footprint is
    # concerned, unbounded.
    def _paths_reach(paths)
      reach = 0.0
      paths.each { |path| path.each { |coordinate| value = coordinate.to_f.abs ; reach = value if value > reach } }
      reach * 4.0 + 1.0
    end

    # The half plane { p | (p - origin) . direction >= 0 }, as a closed path
    # big enough to behave like one - wound counter clockwise, the way the
    # NON ZERO fill of the difference expects its clips.
    def _half_plane_path(origin_x, origin_y, direction_x, direction_y, reach)
      side_x = -direction_y
      side_y = direction_x
      [
        origin_x - side_x * reach,                          origin_y - side_y * reach,
        origin_x + (direction_x - side_x) * reach,          origin_y + (direction_y - side_y) * reach,
        origin_x + (direction_x + side_x) * reach,          origin_y + (direction_y + side_y) * reach,
        origin_x + side_x * reach,                          origin_y + side_y * reach
      ]
    end

    # -----

    # Whether a MERGE is on : a pick held down, gathering the cavities one
    # single panel is to span.
    def _merging?
      @merge_context.is_a?(MouthPanelContext)
    end

    def _reset_merge
      @merge_context = nil
      @merge_fragment_defs = []
      @merge_paths = []
      @merge_mouth_paths = []
    end

    # Whether the drag may gather cavities at all, for the pose in force.
    #
    # In applique ONLY here : an inset panel merged over two compartments would
    # have to be notched around the panel that separates them, and that is no
    # door. A panel that stands BACK from its mouth is not bound by that - it
    # runs straight past such a panel, which is then shortened instead. See
    # SmartDrawBackPanelActionHandler.
    def _merge_allowed?
      _fetch_option_overlay_full_overlay?
    end

    # The MOUTHS of the cavities the merge has gathered, in the frame the merge
    # is read in - what a pose that grows out of its mouth measures from, at the
    # merged panel just as at a lone one. Empty when no merge is on.
    def _merge_mouth_paths
      _merging? ? @merge_mouth_paths : []
    end

    # The SHARES of the cavities the merge has gathered - the cells of the
    # container's front they are each entitled to. What tells where the merge
    # STOPS, which is not something its mouths can say. Empty when no merge is on.
    def _merge_share_paths
      _merging? ? @merge_paths : []
    end

    # Feeds the merge the cavity under the cursor.
    #
    # Anything else leaves the panel exactly as it is : the cursor off the
    # carcass, on the chant between two compartments, on a cavity already
    # taken, on one that meets the panel by a corner alone. A drag crosses all
    # of that on its way, and would be unusable if the panel came undone every
    # time it did.
    #
    # The active part is deliberately NOT picked again : the cavities are the
    # ones the drag started in, and reading them on another container would
    # cost a whole boolean pass and drop the panel being drawn. #_snap_point
    # reads the pick against the ACTIVE part's cavities, so leaving that part
    # alone is exactly what keeps it answering for the right container.
    def _merge_pick(picker, view)

      picked_point = @picked_point
      unless _snap_point(picker)
        @picked_point = picked_point    # A pick on nothing is not a pick : the cavity preview keeps the point it had
        return
      end

      fragment_def = _get_cavity_fragment_def(@merge_context.cavities_def, @picked_point, picker.picked_plane_manipulator)
      return unless fragment_def.is_a?(SolidCavityFragmentDef)

      _merge_add(fragment_def)
    end

    # Adds one cavity to the merge - its own share of the panel unioned into
    # the panel's contour. Answers whether it took.
    #
    # Each cavity's share is a CELL of a partition of the container's front
    # (see #_get_overlay_points), and two neighbouring cells are jointive to
    # the micron, having been cut apart by the very same bisector. So the
    # panel over several cavities is quite simply the UNION of their cells :
    # nothing has to be derived anew, and every cell stays cut by the
    # neighbours that were left out of the merge - which is exactly what a
    # panel in applique still owes them.
    #
    # Cutting the shares first and unioning them after is also what makes an
    # L shaped merge come out right. Merging the cavities first, by leaving
    # them out of one another's neighbours, looks equivalent and is not : a
    # bisector is an unbounded half plane, so the cut called for by a cavity
    # standing above the left leg of the L would run on and rob the right
    # leg too, which it stands nowhere near.
    #
    # The SHARES are what adjacency is read on, whatever the pose : they are cut
    # apart by one bisector and are jointive to the micron, where two MOUTHS of
    # neighbouring compartments stand a whole panel apart. So both are kept - the
    # shares to tell a neighbour from a stranger, the mouths for the pose that
    # measures from them.
    def _merge_add(fragment_def)
      return false if @merge_fragment_defs.any? { |other_fragment_def| other_fragment_def.equal?(fragment_def) }

      ti = @merge_context.transformation.inverse

      points = _get_cavity_share_points(fragment_def, @merge_context.opening_def, ti)
      return false if points.nil? || points.length < 3

      mouth_points = _get_cavity_mouth_points(fragment_def, @merge_context.opening_def, ti)
      return false if mouth_points.nil? || mouth_points.length < 3

      path = Fiddle::Clippy.points_to_rpath(points)
      return false unless _merge_adjacent?(path)

      paths = @merge_paths + [ path ]
      mouth_paths = @merge_mouth_paths + [ Fiddle::Clippy.points_to_rpath(mouth_points) ]
      merged_points = _merge_nominal_points(paths, mouth_paths, @merge_context.opening_def, ti)
      return false if merged_points.nil?

      @merge_fragment_defs << fragment_def
      @merge_paths = paths
      @merge_mouth_paths = mouth_paths
      @merge_context.points = merged_points

      true
    end

    # The NOMINAL contour the gathered cavities draw, in the opening's frame -
    # nil when they draw no panel at all.
    #
    # The SHARES, here : a panel in applique is the share of the front each
    # compartment is entitled to, and several of them is their union, nothing
    # more (see #_merge_add). The mouths are of no use to it. A pose that grows
    # out of its mouth reads them instead - see
    # SmartDrawBackPanelActionHandler.
    def _merge_nominal_points(share_paths, mouth_paths, opening_def, ti)
      _merge_points(share_paths)
    end

    # The contour the merged shares draw, in the opening's frame - nil when
    # they draw anything but ONE plain ring.
    #
    # The union of two jointive cells is the very degeneracy
    # #_cleanup_footprint_paths exists for : they share a whole edge and
    # touch nowhere else, and Clipper hands that back as a single self
    # touching path unless the pair is grown apart and shrunk back first. The
    # collinear vertices the seam leaves along the way are dropped later,
    # together with the ones the carcass itself leaves behind (see
    # #_flatten_outline).
    #
    # More than one ring means the shares enclose something they do not
    # cover - a compartment left out in the middle of the ones taken. That is
    # a frame, not a panel.
    def _merge_points(paths)
      merged_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: paths)
      merged_paths = _cleanup_footprint_paths(merged_paths)
      return nil unless merged_paths.length == 1

      points = Fiddle::Clippy.rpath_to_points(merged_paths.first)
      points.length < 3 ? nil : points
    end

    # Whether the given share touches what the panel already covers by an
    # EDGE - by a shared panel, that is - and not by a single corner.
    #
    # The four cells of a grid meet at one point : taking two of them
    # DIAGONALLY would draw a bow tie, which is no panel. Grown by
    # MERGE_ADJACENCY_DELTA, a share overlaps an edge neighbour over that
    # delta times the length of their common border, and a diagonal one over
    # the delta squared - orders of magnitude apart, so the reading needs no
    # finesse at all.
    def _merge_adjacent?(path)
      return true if @merge_paths.empty?

      grown_paths = Fiddle::Clippy.inflate_paths(
        paths: [ path ],
        delta: MERGE_ADJACENCY_DELTA,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      return false if grown_paths.empty?

      overlap_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: @merge_paths, clips: grown_paths)
      area = overlap_paths.inject(0.0) { |sum, overlap_path| sum + Fiddle::Clippy.get_rpath_area(overlap_path).abs }

      area > MERGE_ADJACENCY_DELTA * MERGE_MIN_SHARED_BORDER
    end

    # The share of the panel one cavity is entitled to, in the frame the
    # merge is read in : what #_get_panel_nominal_points computes for the
    # picked cavity, for any other cavity of the same panel.
    #
    # The REFERENCE opening is what is handed over to #_get_overlay_points,
    # never the cavity's own : both lie on the same plane, and everything
    # that is read per plane - the container's silhouette above all - is then
    # read once for them all. Only the MOUTH has to be the cavity's own, it
    # is what tells which piece of the partition is its.
    #
    # Cached, and rightly so : a drag walks in and out of the same cavities,
    # and without it a share that was refused would be computed again at
    # every mouse move. Held per container, like the silhouette, so that the
    # fragments the keys name are still the ones the cache was filled on.
    def _get_cavity_share_points(fragment_def, opening_def, ti)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)

      unless @share_points_cache.is_a?(Hash) && @share_container_path == cavities_def.container_path
        @share_container_path = cavities_def.container_path
        @share_points_cache = {}
      end

      key = [ fragment_def.object_id, _opening_plane_key(opening_def) ]
      return @share_points_cache[key] if @share_points_cache.has_key?(key)

      mouth_points = _get_cavity_mouth_points(fragment_def, opening_def, ti)
      points = mouth_points.nil? ? nil : _get_overlay_points(fragment_def, opening_def, mouth_points, ti)

      @share_points_cache[key] = points
    end

    # The MOUTH one cavity shows on the reference opening's plane, in that
    # opening's frame - what tells which piece of the partition is its share,
    # and what a panel let into a groove is cut from directly.
    #
    # The LARGEST when a cavity shows several there : an L shaped compartment
    # may well open twice on one front, and the panel is drawn on the mouth the
    # pick is about, not on a corner of the same compartment. nil when the cavity
    # does not open on that plane at all.
    def _get_cavity_mouth_points(fragment_def, opening_def, ti)
      own_opening_def = _get_opening_defs_on_plane(fragment_def, opening_def).max_by { |other_opening_def| other_opening_def.area }
      return nil if own_opening_def.nil?

      mouth = own_opening_def.outer_loop
      return nil if mouth.nil? || mouth.length < 3

      mouth.map { |point| point.transform(ti) }
    end

    # -----

    def _preview_panel(view)

      @tool.clear_3d(LAYER_3D_PANEL_PREVIEW)
      @tool.clear_2d(_preview_2d_layers)

      return unless (panel_defs = _compute_panel_defs(@picked_point, view)).is_a?(Array) && !panel_defs.empty?

      # The AXIS colour says the arrow keys are the ones deciding where the
      # panels meet - and only when they really are : a lock the opening
      # makes nothing of (see #_get_locked_split_direction), or an opening no
      # count shares at all, is no lock to report.
      locked = _shared? && !_get_locked_split_direction(panel_defs.first.opening_def.normal).nil?
      color = locked ? _get_vector_color(@locked_direction, Kuix::COLOR_MAGENTA) : Kuix::COLOR_MAGENTA

      panel_defs.each do |panel_def|

        # face_info_defs is irrelevant here : the preview only needs the
        # geometry (boundary_segments doesn't dereference it).
        vertices, face_indices, face_ids = panel_def.mesh_3f
        panel_fragment_def = SolidFragmentDef.new(vertices, face_indices, face_ids, [])
        segments = panel_fragment_def.unique_boundary_segments

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.color = color
        k_segments.line_width = 1
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_PANEL_PREVIEW)

        unless _fetch_option_construction?

          k_segments = Kuix::Segments.new
          k_segments.add_segments(segments)
          k_segments.color = color
          k_segments.line_width = locked ? 2.5 : 1.5
          @tool.append_3d(k_segments, LAYER_3D_PANEL_PREVIEW)

        end

        # Each panel's own width, once the opening is shared : what the count
        # and the pins did to the panel is exactly what the user cannot read
        # off the outlines alone. A lone panel filling its whole mouth needs
        # none of it - the VCB already carries its thickness.
        if _shared?
          k_label = _create_floating_label(
            snap_point: panel_def.center,
            text: panel_def.width.to_l.to_s,
            text_color: color,
            border_color: color
          )
          @tool.append_2d(k_label, LAYER_2D_WIDTH)
        end

      end

      _preview_panel_decorations(panel_defs, view, color)

      Sketchup.set_status_text(panel_defs.first.thickness.to_l, SB_VCB_VALUE)

    end

    # The 2D layers #_preview_panel draws on, and clears before it does. The
    # widths are the only ones every panel has ; a handler that draws more of
    # its own (see #_preview_panel_decorations) has to declare them here too,
    # or what it drew on the previous move stays on screen.
    def _preview_2d_layers
      [ LAYER_2D_WIDTH ]
    end

    # Whatever the panel shows BESIDES its own outline and width. Nothing by
    # default : the outlines say everything about a plain panel.
    def _preview_panel_decorations(panel_defs, view, color)
    end

    # -----

    # Rebuilds the panels the pick resolves to as real geometry inside the
    # model, and names the batch - the same tail conventions (ask_name option
    # / success notification) as the other draw handlers' _create_entity.
    # When the construction option is on, only the outlines are drawn (as
    # clines, in a plain group each) instead of real parts, so no naming /
    # success notification happens in that case either.
    #
    # A panel the boolean or SketchUp left unbuildable is skipped rather than
    # fatal : the other panels of the batch are legitimate and must not fall
    # with it. Returns true as soon as one of them was built.
    def _create_entity(point, view)
      return false unless (panel_defs = _compute_panel_defs(point, view)).is_a?(Array) && !panel_defs.empty?

      model = Sketchup.active_model
      model.start_operation(_panel_operation_name, true, false, !active?)
      begin

        # Whatever the batch has to do to the EXISTING model comes first, and
        # hands back the container path to build in : a handler that has to cut
        # into the parts around its panel (see
        # SmartDrawBackPanelActionHandler) may have to make an ancestor unique
        # to do so, which replaces the very container the panel is about to go
        # in. Read after, the path would point at a definition nobody sees any
        # more.
        container_path = _prepare_panels!(panel_defs)

        if container_path.is_a?(Array) && container_path.any? && (container = container_path.last) && container.respond_to?(:definition)
          active_entities = container.definition.entities
          active_transformation = PathUtils.get_transformation(container_path, IDENTITY)
        else
          active_entities = Sketchup.active_model.entities
          active_transformation = IDENTITY
          container_path = []
        end

        # Definitions this batch actually BUILT - what the naming applies to,
        # one per distinct panel - and how many entities it added to the
        # model. With the reuse option on the two no longer match : a mouth
        # shared between three equal panels builds ONE definition and three
        # instances of it.
        created_definitions = []
        created_entity_count = 0

        # The panels this batch has already built - [ outline, definition,
        # WORLD transformation ] - as candidates for the ones that follow.
        # See #_find_reusable_panel.
        sibling_panel_defs = []

        # [ definition, WORLD transformation ] of each panel of the batch
        # once it stands in the model, by its index - nil for the ones
        # skipped. What the mirror option instances its even panels
        # from, see #_get_panel_mirror_transformations.
        instance_defs = []
        mirror_transformations = _get_panel_mirror_transformations(panel_defs)

        panel_defs.each_with_index do |panel_def, index|

          # Local frame for the new part : Z = the opening's outward normal,
          # X/Y its own in-plane basis, origin on the opening plane. The panel
          # is then built on one side of z = 0 or the other, according to the
          # POSE - inset INTO the cavity, in applique in FRONT of it - so that
          # in both cases one of its faces lands exactly on the mouth plane.
          x_axis, y_axis, z_axis = panel_def.axes
          world_transformation = Geom::Transformation.axes(panel_def.origin, x_axis, y_axis, z_axis)

          if _fetch_option_construction?

            group = active_entities.add_group
            group.transformation = active_transformation.inverse * world_transformation

            created_faces = _build_panel_faces(group.entities, panel_def, world_transformation)
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

          # A panel the mirror option lays in mirror is its
          # neighbour's definition, reflected - whatever the reuse option says,
          # and before any translated occurrence it might also be.
          mirror_transformation, mirrored_index = mirror_transformations[index]
          mirrored_instance_def = mirrored_index.nil? ? nil : instance_defs[mirrored_index]
          if !mirror_transformation.nil? && !mirrored_instance_def.nil?
            candidate_definition = mirrored_instance_def[0]
            candidate_world_transformation = mirror_transformation * mirrored_instance_def[1]
          else
            candidate_definition, candidate_world_transformation = _find_reusable_panel(panel_def, sibling_panel_defs)
          end

          if candidate_definition.nil?

            definition = model.definitions.add(PLUGIN.get_i18n_string('default.part_single').capitalize)

            created_faces = _build_panel_faces(definition.entities, panel_def, world_transformation)
            if created_faces.empty?
              model.definitions.remove(definition) if model.definitions.respond_to?(:remove)
              next
            end

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

            # The outline is kept as it was CUT, in world coordinates - the
            # auto orientation moved the definition's entities and its
            # transformation together, so what the next panel has to be
            # compared to is unchanged by it.
            sibling_panel_defs << [ panel_def.outline, definition, world_transformation ] if _fetch_option_reuse_definition?

            instance_defs[index] = [ definition, world_transformation ]

          else

            # The panel is one more occurrence of a panel this batch has
            # already built : nothing is built at all, that definition is
            # instanced where this one stands - see #_find_reusable_panel
            # and #_get_panel_mirror_transformations
            instance = active_entities.add_instance(candidate_definition, active_transformation.inverse * candidate_world_transformation)

            instance_defs[index] = [ candidate_definition, candidate_world_transformation ]

          end

          # Marked as a panel, so that the cavity detection can go on reading the
          # carcass bare - see SmartDrawPanelActionHandler#_get_cavities_def and
          # LayerAttributes.
          instance.layer = LayerAttributes.fetch_or_create_layer(model, _panel_layer_type, _fetch_option_layer_name)

          created_entity_count += 1

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
                  # One name for the whole batch : the panels of one opening
                  # are as many definitions, and they are all the part the
                  # user just named
                  created_definitions.each { |created_definition| created_definition.name = name unless created_definition.deleted? }
                end
              end
            end
          }

          if _fetch_option_ask_name?
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

    # Everything the batch does to the EXISTING model, run inside
    # #_create_entity's operation and BEFORE anything is built - see there.
    # Answers the container path the panels are to be built in, which is the
    # batch's own unless this changed it.
    #
    # Nothing here : laying a panel on a carcass leaves the carcass alone.
    # Raises rather than returning half a job : the caller's rescue aborts the
    # whole operation, which is the only safe outcome once the model has been
    # touched.
    def _prepare_panels!(panel_defs)
      panel_defs.first.container_path
    end

    # For each panel of the batch, [ the WORLD transformation carrying the
    # panel it is a mirror image of onto it, the index of that one ] - nil for
    # every panel built on its own. None here : a panel is laid the way the
    # mouth gives it, and a mirror it does not have would be a lie in the
    # model (see SmartDrawFrontPanelActionHandler, where a pair of leaves
    # opens on a common seam).
    def _get_panel_mirror_transformations(panel_defs)
      panel_defs.map { nil }
    end

    # [ definition, WORLD transformation ] of a panel of the SAME batch the
    # given one is one more occurrence of, or nil : the caller then builds
    # nothing and instances that definition instead, so the panels of one
    # mouth are ONE part in the cutlist rather than as many identical ones.
    # nil unless the reuse option is on.
    #
    # The criterion is the OUTLINE alone, and it can be : the panels of a
    # batch come from one contour shared equally, and they carry the same
    # thickness and the same overlay setting by construction - so two of them with
    # superposable outlines are the same solid, full stop. No neighbourhood
    # test like the divider's is needed either : what makes them the same
    # part is not a coincidence to be confirmed, it is how they were cut.
    #
    # Deliberately limited to the panels of ONE batch. Two panels drawn on two
    # separate picks may well look alike, but the user drew them apart, and
    # silently linking them would make editing one edit the other.
    def _find_reusable_panel(panel_def, sibling_panel_defs)
      return nil unless _fetch_option_reuse_definition?

      sibling_panel_defs.each do |sibling_outline, definition, world_transformation|
        next if definition.deleted?
        offset = _outlines_translation_offset(panel_def.outline, sibling_outline)
        next if offset.nil?

        # The definition's own geometry is +sibling_outline+'s, so carrying
        # that panel onto this one carries its transformation the same way.
        # A plain translation composes on the LEFT : the definition is placed
        # where it was, then moved.
        return [ definition, Geom::Transformation.translation(offset) * world_transformation ]
      end

      nil
    end

    # The WORLD translation carrying +other_outline+ onto +outline+ when one
    # is the other merely moved - nil when they are not congruent that way.
    #
    # The two are CLOSED contours, so the match may start on any of the
    # other's vertices : every cyclic shift is tried, and the offset returned
    # is the one that shift implies.
    #
    # Translations only. A panel superposable by a ROTATION is not the same
    # part : it would carry the grain of its panel the other way round, and
    # nothing here would tell the two apart afterwards.
    def _outlines_translation_offset(outline, other_outline)
      count = outline.length
      return nil unless other_outline.length == count && count > 2

      tolerance = SolidMeshDef::TOLERANCE

      (0...count).each do |shift|

        dx = outline[0].x.to_f - other_outline[shift].x.to_f
        dy = outline[0].y.to_f - other_outline[shift].y.to_f
        dz = outline[0].z.to_f - other_outline[shift].z.to_f

        matches = (1...count).all? { |index|
          point = outline[index]
          other_point = other_outline[(shift + index) % count]
          (point.x.to_f - other_point.x.to_f - dx).abs < tolerance &&
          (point.y.to_f - other_point.y.to_f - dy).abs < tolerance &&
          (point.z.to_f - other_point.z.to_f - dz).abs < tolerance
        }
        next unless matches

        return Geom::Vector3d.new(dx, dy, dz)
      end

      nil
    end

    # Builds the panel as real geometry inside +entities+, in the given
    # transformation's local space : the outline as a face - SketchUp
    # triangulates and closes it, however many points and however concave it
    # is - pushed to its thickness INTO the cavity. Returns the created
    # faces, empty when the outline could not be built.
    def _build_panel_faces(entities, panel_def, world_transformation)
      ti = world_transformation.inverse
      points = panel_def.outline.map { |point| point.transform(ti) }

      face = entities.add_face(points)
      return [] if face.nil?

      # The outline lies on z = 0 and the panel grows towards -z when it is
      # fitted INTO the cavity, +z when it is laid in applique ON its front.
      # The face is turned to look that way first, so that #pushpull extrudes
      # on the right side whichever way add_face wound it.
      face.reverse! if (face.normal.z > 0) != panel_def.overlay?
      face.pushpull(panel_def.thickness)

      entities.grep(Sketchup::Face)
    end

    # -----

    # What one pick resolves to, shared by every panel it yields : the cavity
    # and the opening the panels go on, the frame that opening is read in, the
    # NOMINAL contour they are cut out of (in that frame), and the direction
    # they succeed one another along (in that frame too, [ x, y ] unit
    # Floats, nil when none could be read).
    MouthPanelContext = Struct.new(:cavities_def, :fragment_def, :opening_def, :transformation, :points, :direction) do

      def container_path
        cavities_def.container_path
      end

      # The split direction back in WORLD coordinates - what the panels' own
      # widths are measured along.
      def world_direction
        return nil if direction.nil?
        @world_direction ||= Geom::Vector3d.new(direction[0], direction[1], 0).transform(transformation)
      end

    end

    # One panel : the opening it fills, the outline it is cut to (WORLD
    # coordinates, closed, the closing point not repeated), its thickness,
    # whether it is laid in applique on the opening rather than fitted into
    # it, the WORLD direction the panels of its batch succeed one another
    # along - the one its own width is read on - and the index of the band of
    # that batch it was cut from, which it may share with other pieces of the
    # same band (see #_split_points).
    MouthPanelDef = Struct.new(:container_path, :fragment_def, :opening_def, :outline, :thickness, :overlay, :direction, :band, :plane_outline) do

      def overlay?
        !!overlay
      end

      # Center of the outline's bounds - where the width label hangs.
      def center
        return @center if defined?(@center)
        bounds = Geom::BoundingBox.new
        outline.each { |point| bounds.add(point) }
        @center = bounds.center
      end

      # The panel's own extent along the batch's split direction : its WIDTH,
      # the dimension the count shares. 0 when there is no direction to read
      # it on (a lone panel on a panel nothing pointed a direction at).
      def width
        return @width if defined?(@width)
        return @width = 0 if direction.nil?
        projections = outline.map { |point| point.x.to_f * direction.x + point.y.to_f * direction.y + point.z.to_f * direction.z }
        @width = projections.max - projections.min
      end

      # Origin of the panel's own frame : the first point of its outline, on
      # the opening plane.
      def origin
        outline.first
      end

      # [ X, Y, Z ] of the panel's own frame, Z being the opening's outward
      # normal. Right-handed (Vector3d#axes), so the transformation built on
      # it is a pure rotation - never a mirror.
      def axes
        @axes ||= opening_def.normal.axes
      end

      # The panel as a raw mesh - [ vertices, face_indices, face_ids ] - for
      # the preview : the outline triangulated (see #cap_triangles), and the
      # same outline pushed by the thickness, on the side the overlay setting puts the
      # body. The cap's own interior edges are traversed once each way and
      # cancel out, so the net contour
      # (SolidFragmentDef#unique_boundary_segments) draws the panel's real
      # outline, not its tessellation.
      def mesh_3f
        return @mesh_3f if defined?(@mesh_3f)

        normal = opening_def.normal
        count = outline.length

        # The ring the caps are wound on is always the one the outward
        # normal looks out of : the mouth when the panel is fitted into the
        # cavity, the panel's own outer face when it is laid in applique in
        # front of it. The body then runs from it towards -normal either way,
        # and the mesh stays wound the right way out.
        offset_outline = outline.map { |point| point.offset(normal, overlay? ? thickness : -thickness) }
        front_outline, back_outline = overlay? ? [ offset_outline, outline ] : [ outline, offset_outline ]

        vertices = []
        front_outline.each { |point| vertices << point.x.to_f << point.y.to_f << point.z.to_f }
        back_outline.each { |point| vertices << point.x.to_f << point.y.to_f << point.z.to_f }

        face_indices = []
        cap_triangles.each do |a, b, c|
          face_indices << a << b << c                                                    # front cap
          face_indices << count + c << count + b << count + a                            # back cap, the other way round
        end
        (0...count).each do |index|
          following = (index + 1) % count
          face_indices << index << count + index << count + following                    # side
          face_indices << index << count + following << following
        end

        @mesh_3f = [ vertices, face_indices, Array.new(face_indices.length / 3, 0) ]
      end

      # The outline cut into triangles, as index triples wound the way the
      # outline itself runs - what #mesh_3f builds its two caps on. Memoized.
      #
      # A fan opened from the first vertex would do for a CONVEX outline, and
      # stops doing once a panel spans several merged cavities : an L is star
      # shaped from some of its corners only, and a fan opened from any of
      # the others lays triangles OUTSIDE it. Their edges then meet the
      # neighbouring ones the same way round rather than head to tail, so
      # nothing cancels and the preview draws the fan itself - strokes
      # straight across the panel. Which corner the union hands over first is
      # nobody's decision, so the fan is simply not an option any more.
      #
      # Ear clipping instead : it only ever cuts a triangle the outline
      # already contains, so every edge it adds is interior twice over. O(n2)
      # on a contour of a dozen points at most, recomputed only when the pick
      # changes.
      def cap_triangles
        return @cap_triangles if defined?(@cap_triangles)

        count = outline.length
        x_axis, y_axis = axes

        # The outline read flat, in the opening's own basis : the panel lies
        # on a plane, whatever its slant in the model.
        us = outline.map { |point| point.x.to_f * x_axis.x + point.y.to_f * x_axis.y + point.z.to_f * x_axis.z }
        vs = outline.map { |point| point.x.to_f * y_axis.x + point.y.to_f * y_axis.y + point.z.to_f * y_axis.z }

        # Ears are cut counterclockwise ; an outline running the other way in
        # that basis is walked backwards and its triangles flipped back, so
        # the caps come out wound like the outline either way.
        doubled_area = 0.0
        (0...count).each do |index|
          following = (index + 1) % count
          doubled_area += us[index] * vs[following] - us[following] * vs[index]
        end
        reversed = doubled_area < 0

        remaining = (0...count).to_a
        remaining.reverse! if reversed

        triangles = []
        while remaining.length > 2
          position = (0...remaining.length).find { |candidate| _ear?(us, vs, remaining, candidate) }
          break if position.nil?
          a, b, c = remaining[position - 1], remaining[position], remaining[(position + 1) % remaining.length]
          triangles << (reversed ? [ c, b, a ] : [ a, b, c ])
          remaining.delete_at(position)
        end

        # A self touching or otherwise degenerate outline left an ear the
        # test would not take : back to the fan, which is wrong on a concave
        # contour but never leaves a hole - and a hole is the one thing that
        # would make the preview show LESS than the panel.
        triangles = (1...(count - 1)).map { |index| [ 0, index, index + 1 ] } if triangles.length != count - 2

        @cap_triangles = triangles
      end

      # Whether the vertex at +position+ of the +remaining+ ring is an EAR :
      # convex, and cutting a triangle no other vertex of the ring falls in.
      # A vertex sitting exactly ON the triangle counts as falling in - the
      # ear is refused rather than cut through something the outline touches.
      def _ear?(us, vs, remaining, position)
        a = remaining[position - 1]
        b = remaining[position]
        c = remaining[(position + 1) % remaining.length]

        return false if _cross(us, vs, a, b, c) <= 0    # Reflex corner, or three points in a line

        remaining.each do |index|
          next if index == a || index == b || index == c
          return false if _cross(us, vs, a, b, index) >= 0 && _cross(us, vs, b, c, index) >= 0 && _cross(us, vs, c, a, index) >= 0
        end

        true
      end

      # Twice the signed area of the flattened triangle a-b-c : positive when
      # it turns counterclockwise in the opening's basis.
      def _cross(us, vs, a, b, c)
        (us[b] - us[a]) * (vs[c] - vs[a]) - (vs[b] - vs[a]) * (us[c] - us[a])
      end

    end

  end

  # Draws a FRONT PANEL on an opening of a cavity : the panel that CLOSES the
  # compartment towards the user - a door, a drawer front, a fixed front.
  #
  # What it adds to the mouth panel pipeline is what a front is about :
  #
  #   CLEARANCE : a front has to open, so it stands back from its nominal
  #               contour on every edge - which is also what leaves the gap
  #               between two leaves of a pair (see #_apply_panel_clearance).
  #   MIRROR    : a pair of leaves opening on a common seam is ONE part laid
  #               twice, the second one reflected - see
  #               #_get_panel_mirror_transformations.
  #
  # It touches nothing else in the model : a front is laid ON the carcass, and
  # needs nothing cut into it.
  class SmartDrawFrontPanelActionHandler < SmartDrawMouthPanelActionHandler

    LAYER_2D_MIRROR = 101

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_FRONT_PANEL, tool, previous_action_handler)
    end

    # -----

    protected

    # -----

    def _panel_i18n_key_suffix
      'front_panel'
    end

    def _panel_layer_type
      LayerAttributes::TYPE_FRONT_PANEL
    end

    def _panel_operation_name
      'OCL Create Front Panel'
    end

    # -----

    # A length SUFFIXED with "x" - "3x" - sets the clearance, the same VCB
    # grammar the other actions read their shape offset with (see
    # #_read_offset). A bare length is already the thickness here, so the
    # suffix is what tells the two apart.
    def _read_panel_lengths(tool, text, view)
      read = _read_suffixed_offset(tool, text, 'x', SmartDrawTool::ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET)
      read.nil? ? super : read
    end

    # -----

    def _fetch_option_front_panel_offset
      @tool.fetch_action_option_length(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET)
    end

    def _fetch_option_mirror?
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MIRROR)
    end

    # -----

    # The nominal contour pulled back by the CLEARANCE on every edge.
    #
    # A real polygon offset (Clippy, the same one the shape offset of the
    # other actions uses), not a scaling : a contour is not always a
    # rectangle - a canted or notched one keeps its angles, and every edge
    # stands back by the same distance, which is what a clearance means.
    #
    # Pulled back that way, a contour narrowing somewhere to less than twice
    # the clearance loses that neck altogether and breaks into several rings
    # - the two legs of a U whose bridge is thinner than that. Each is a panel
    # of its own, exactly as the pieces a band is clipped to are, for the very
    # same reason : the clearance is taken on every edge of every leaf, and a
    # neck that narrow has nothing left between the two edges it runs along.
    def _apply_panel_clearance(points)

      front_panel_offset = _fetch_option_front_panel_offset
      return super if front_panel_offset.nil? || front_panel_offset <= 0

      # The union normalizes the winding, and the winding is what decides
      # which side a negative delta offsets towards.
      paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(points) ])
      paths = Fiddle::Clippy.inflate_paths(
        paths: paths,
        delta: -front_panel_offset.to_f,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )

      _clean_pieces(paths).map { |path| Fiddle::Clippy.rpath_to_points(path) }
    end

    # -----

    # For each panel of the batch, [ the WORLD transformation carrying
    # the panel it mirrors onto it, the index of that one ] when the
    # mirror option lays it in mirror - nil for every other one.
    #
    # Only the panels of the EVEN bands (the 2nd, the 4th... counted
    # from the low end of the split direction, so the measure reversed option
    # decides which ones they are) are laid in mirror, each of a panel
    # of the band just before it : pairs of leaves opening on their common
    # seam. A band the contour cuts in several pieces (see #_split_points)
    # pairs piece to piece : each one takes, among the pieces of the band
    # before that it is the mirror image of, the one standing SQUARELY across
    # the seam from it - the reflection that slides it the least along the
    # seam - rather than the same leg of a U on its other side. A panel
    # that is NOT the mirror image of any - a pinned width, an applied contour
    # cut differently at each end - is simply left alone : a mirror it does
    # not have would be a lie in the model.
    #
    # Nothing to mirror when the panels are only construction lines.
    def _get_panel_mirror_transformations(panel_defs)
      mirror = _fetch_option_mirror? && !_fetch_option_construction?
      panel_defs.map { |panel_def|
        next nil unless mirror && panel_def.band.odd?

        best = nil
        best_slide = nil
        panel_defs.each_with_index do |other_panel_def, other_index|
          next unless other_panel_def.band == panel_def.band - 1
          next if (transformation = _get_panel_mirror_transformation(panel_def, other_panel_def)).nil?
          slide = _vector_rejection(transformation.origin - ORIGIN, panel_def.direction.normalize).length.to_f
          next unless best_slide.nil? || slide < best_slide
          best = [ transformation, other_index ]
          best_slide = slide
        end
        best
      }
    end

    # The WORLD reflection carrying +other_panel_def+ onto
    # +panel_def+, across a plane square to the batch's split direction -
    # nil when the one is not the other's mirror image that way.
    #
    # The reflection is read across the plane through the origin first, and
    # whatever translation then carries the reflected outline onto the other
    # one places that plane : on the seam between two leaves, or wherever a
    # contour stepped along the way puts it. Reflecting reverses the way an
    # outline turns, so the reflected one is matched walked backwards too.
    #
    # Its determinant is -1 : instanced with it, the neighbour's definition
    # is a MIRRORED occurrence, one the cutlist reads as flipped.
    def _get_panel_mirror_transformation(panel_def, other_panel_def)
      direction = panel_def.direction
      return nil if direction.nil? || !direction.valid?

      dx, dy, dz = direction.normalize.to_a

      reflected_outline = other_panel_def.outline.map { |point|
        k = 2.0 * (point.x.to_f * dx + point.y.to_f * dy + point.z.to_f * dz)
        Geom::Point3d.new(point.x.to_f - k * dx, point.y.to_f - k * dy, point.z.to_f - k * dz)
      }

      offset = _outlines_translation_offset(panel_def.outline, reflected_outline.reverse) ||
               _outlines_translation_offset(panel_def.outline, reflected_outline)
      return nil if offset.nil?

      # I - 2 d dT : symmetric, so row or column major reads the same
      reflection = Geom::Transformation.new([
        1.0 - 2.0 * dx * dx,      -2.0 * dx * dy,       -2.0 * dx * dz, 0.0,
             -2.0 * dx * dy, 1.0 - 2.0 * dy * dy,       -2.0 * dy * dz, 0.0,
             -2.0 * dx * dz,      -2.0 * dy * dz,  1.0 - 2.0 * dz * dz, 0.0,
                        0.0,                 0.0,                  0.0, 1.0
      ])

      Geom::Transformation.translation(offset) * reflection
    end

    # -----

    def _preview_2d_layers
      super + [ LAYER_2D_MIRROR ]
    end

    # The mirror motif on the seam of every pair laid in mirror - and only of
    # those : an even panel that is not its neighbour's mirror image is built
    # on its own, and says so by showing none.
    def _preview_panel_decorations(panel_defs, view, color)
      _get_panel_mirror_transformations(panel_defs).each_with_index do |mirror, index|
        next if mirror.nil?

        _, mirrored_index = mirror
        panel_def = panel_defs[index]
        seam_point = Geom.linear_combination(0.5, panel_defs[mirrored_index].center, 0.5, panel_def.center)

        # The motif's axis stands across the split direction as the screen
        # shows it : upright between panels side by side, lying between
        # stacked ones.
        screen_seam_point = view.screen_coords(seam_point)
        screen_along_point = view.screen_coords(seam_point.offset(panel_def.direction, view.pixels_to_model(10, seam_point)))
        side_by_side = (screen_along_point.x - screen_seam_point.x).abs >= (screen_along_point.y - screen_seam_point.y).abs

        unit = @tool.get_unit(view)

        k_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(side_by_side ? SmartDrawTool::MIRROR_MOTIF_VERTICAL_PATH : SmartDrawTool::MIRROR_MOTIF_HORIZONTAL_PATH))
        k_motif.layout_data = Kuix::StaticLayoutDataWithSnap.new(seam_point, unit * 5, unit * 5, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        k_motif.padding.set_all!(unit)
        k_motif.set_style_attribute(:color, Kuix::COLOR_WHITE)
        k_motif.set_style_attribute(:background_color, color)
        @tool.append_2d(k_motif, LAYER_2D_MIRROR)

      end
    end

  end

  # Draws a BACK PANEL on an opening of a cavity : the panel that closes the
  # compartment AWAY from the user - the back of a carcass.
  #
  # Shaped exactly like a front panel, and that is the whole difficulty : only
  # what the part is FOR tells the two apart (see LayerAttributes). What it
  # really does differently is how it is HELD :
  #
  #   INSET   : a back is not laid in its mouth, it is let into a GROOVE cut
  #             around it. So its contour is the mouth GROWN by the depth of
  #             that groove (see #_grow_nominal_points), it stands back from
  #             the mouth plane by the SETBACK (see #_panel_outline_offset) -
  #             which is what leaves room behind it for a cleat or a cable -
  #             and the parts around it are CUT (see #_prepare_panels!). It is
  #             the only handler of the draw tool that touches anything it did
  #             not create.
  #   OVERLAY : nailed on the back of the carcass, over its whole silhouette.
  #             Nothing is grown, nothing stands back, and nothing is cut : the
  #             pipeline of the mouth panel, unchanged.
  #
  # No CLEARANCE and no MIRROR, unlike a front panel : a back does not have to
  # open, and there is no pair of leaves to reflect.
  class SmartDrawBackPanelActionHandler < SmartDrawMouthPanelActionHandler

    # How far a CROSSING cut is pushed past the part it takes off, on every side
    # - see #_compute_machining_defs. Big enough that nothing of the cut lands
    # within the model tolerance of a face of that part, small enough to stay
    # invisible had anything of it survived.
    CROSSING_OVERSHOOT = 1.mm

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_BACK_PANEL, tool, previous_action_handler)
    end

    # -----

    protected

    # -----

    def _panel_i18n_key_suffix
      'back_panel'
    end

    def _panel_layer_type
      LayerAttributes::TYPE_BACK_PANEL
    end

    def _panel_operation_name
      'OCL Create Back Panel'
    end

    # -----

    # AWAY from the camera, where a front panel reads towards it : a carcass is
    # modelled, and looked at, from the front, and its back closes the far end
    # of that very look. Asking the user to orbit behind the case to give it a
    # back would be tedious ; worse, reading the near mouth would quietly build
    # the back where the FRONT goes, and the two are indistinguishable
    # afterwards but for their tag.
    #
    # A compartment with nothing open at the far end is then a compartment with
    # no candidate at all, and the pick is refused - which is right : there is
    # nowhere for a back to go.
    def _panel_opening_facing_vector(view)
      direction = view.camera.direction
      [ direction.x, direction.y, direction.z ]
    end

    # -----

    # Two SUFFIXED lengths here, where a front panel has one : "8x" is the
    # groove DEPTH, "8r" the SETBACK. A bare length is the thickness, as
    # everywhere.
    def _read_panel_lengths(tool, text, view)
      read = _read_suffixed_offset(tool, text, 'x', SmartDrawTool::ACTION_OPTION_OFFSET_BACK_PANEL_DEPTH)
      return read unless read.nil?
      read = _read_suffixed_offset(tool, text, 'r', SmartDrawTool::ACTION_OPTION_OFFSET_BACK_PANEL_SETBACK)
      read.nil? ? super : read
    end

    # -----

    # How deep the panel runs into the parts around its mouth - and so how much
    # WIDER than that mouth it is cut, on every edge.
    def _fetch_option_back_panel_depth
      @tool.fetch_action_option_length(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_BACK_PANEL_DEPTH)
    end

    # How far the panel stands back from the mouth plane, towards the inside of
    # the carcass - where the groove is cut, and what is left free behind the
    # panel.
    def _fetch_option_back_panel_setback
      @tool.fetch_action_option_length(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_BACK_PANEL_SETBACK)
    end

    def _fetch_option_machining
      @tool.fetch_action_option_value(@action, SmartDrawTool::ACTION_OPTION_MACHINING)
    end

    # Not exposed in the action's options panel, like the layer name : what a
    # machining is called is a technical setting - only the modal gives access
    # to it. Blank falls back on the name the materials tab gives the type, so
    # that the material reads in the user's own language.
    def _fetch_option_machining_material_name
      name = @tool.fetch_action_option_string(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MACHINING_MATERIAL_NAME)
      return name if name.is_a?(String) && !name.strip.empty?
      PLUGIN.get_i18n_string("tab.materials.type_#{MaterialAttributes::TYPE_MACHINING}")
    end

    def _fetch_option_machining_layer_name
      @tool.fetch_action_option_string(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MACHINING_LAYER_NAME)
    end

    # -----

    # The mouth GROWN by the groove depth, on every edge - the contour the
    # panel is really cut to when it is let into one.
    #
    # A real polygon offset, like the front panel's clearance and for the same
    # reason : a mouth is not always a rectangle, and every edge has to gain
    # the same depth whatever the angles.
    #
    # CLIPPED to the container's silhouette, and silently. A mouth edge that
    # already stands on the silhouette has no material beyond it to cut a
    # groove in - a carcass open on one side, a back running out to the very
    # edge of a stile - and the panel simply comes out flush there. That is a
    # perfectly ordinary carcass, not a mistake to report : the preview shows
    # the contour that will be cut, and #_prepare_panels! finds no host to
    # groove on that edge, which is exactly right.
    def _grow_nominal_points(points, opening_def, ti)
      return points if _fetch_option_overlay_full_overlay?

      depth = _fetch_option_back_panel_depth
      return points if depth.nil? || depth <= 0

      # The union normalizes the winding, and the winding is what decides which
      # side a positive delta grows towards.
      mouth_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(points) ])
      grown_paths = Fiddle::Clippy.inflate_paths(
        paths: mouth_paths,
        delta: depth.to_f,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      return nil if grown_paths.empty?

      silhouette_paths = _get_silhouette_paths(opening_def, ti)
      unless silhouette_paths.nil? || silhouette_paths.empty?
        clipped_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: grown_paths, clips: silhouette_paths)
        grown_paths = clipped_paths unless clipped_paths.empty?
      end

      best_path = _best_overlapping_path(grown_paths, mouth_paths)
      best_path.nil? ? nil : Fiddle::Clippy.rpath_to_points(best_path)
    end

    # ALWAYS, where a front panel merges in applique alone.
    #
    # The reason the base gives for that restriction is a door's reason : an
    # inset door spanning two compartments would have to be notched around the
    # panel that separates them. A back stands BACK from its mouth, inside the
    # carcass : it runs straight past that panel, which is simply SHORTENED by
    # as much as the back takes - and that is how a one piece back is built,
    # rather than the exception the notch would be.
    def _merge_allowed?
      true
    end

    # The MOUTHS of the gathered cavities, plus the panels the merged back runs
    # straight across, the whole grown by the groove depth.
    #
    # Two mouths of neighbouring compartments stand a whole panel apart, so
    # their union alone is two rings, and no panel : what closes it is the
    # panel between them, taken WHOLE (see #_get_crossed_footprint_paths).
    # Whole, and not merely bridged by the growth, because a groove is 8 mm deep
    # where a divider is 18 mm thick - the growth from either side would not meet
    # in the middle, and the back would come out in two pieces over a divider it
    # is meant to pass in front of.
    #
    # Taking it whole is also what tells #_compute_machining_defs the truth
    # about it : the panel then falls in the RING - the contour minus the mouths -
    # over its whole footprint, so it is machined over its whole width, which is
    # exactly a divider stopped short of the back by the setback and the
    # thickness.
    def _merge_nominal_points(share_paths, mouth_paths, opening_def, ti)
      return super if _fetch_option_overlay_full_overlay?

      crossed_paths = _get_crossed_drawing_defs(share_paths, opening_def, ti).flat_map { |drawing_def| _get_panel_footprint_paths(drawing_def, opening_def, ti) }
      points = _merge_points(mouth_paths + crossed_paths)
      return nil if points.nil?

      _grow_nominal_points(points, opening_def, ti)
    end

    # The panels the merge SURROUNDS - the ones a back spanning the gathered
    # cavities has to run across, and so to shorten.
    #
    # What tells them apart from the frame around the merge is where they stand
    # with respect to the merged SHARES : the shares run out to the container's
    # silhouette, so a stile of the frame REACHES their border, and so does a
    # divider the merge only took one side of - its share was cut through the
    # middle of that very divider by the bisector. A divider standing between two
    # gathered cavities reaches nothing : the frame stands between it and the
    # outside.
    #
    # Read by shrinking the shares by a hair and looking for what then sticks
    # out, scored the way #_merge_adjacent? scores a contact : a panel reaching
    # the border sticks out over a hair times the length of that border, one
    # surrounded by the merge sticks out over nothing at all. Orders of magnitude
    # apart, so the reading needs no finesse.
    #
    # A divider that runs out to the silhouette itself - flush with the back of a
    # carcass at both its ends - is left out on purpose : crossing it would show
    # from the outside. The mouths then stay two rings, #_merge_points reads no
    # panel in them, and the drag simply does not take that cavity.
    def _get_crossed_drawing_defs(share_paths, opening_def, ti)
      return [] if share_paths.length < 2
      return [] unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)

      merged_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: share_paths)
      inner_paths = Fiddle::Clippy.inflate_paths(
        paths: merged_paths,
        delta: -MERGE_ADJACENCY_DELTA,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      return [] if inner_paths.empty?

      cavities_def.drawing_defs.select { |drawing_def|

        # A panel already laid on the carcass is not carcass : a back never runs
        # across another back, nor across a front.
        next false if LayerAttributes.panel_type?(LayerAttributes.type_of(drawing_def.container))

        footprint_paths = _get_panel_footprint_paths(drawing_def, opening_def, ti)
        next false if footprint_paths.nil? || footprint_paths.empty?

        outside_paths, _ = Fiddle::Clippy.execute_difference(closed_subjects: footprint_paths, clips: inner_paths)
        area = outside_paths.inject(0.0) { |sum, outside_path| sum + Fiddle::Clippy.get_rpath_area(outside_path).abs }
        area <= MERGE_ADJACENCY_DELTA * MERGE_MIN_SHARED_BORDER

      }
    end

    # The SETBACK, and only when the panel is let into a groove : one laid on
    # the back of the carcass is laid ON it, there is nothing to stand back
    # from.
    def _panel_outline_offset(opening_def)
      return 0 if _fetch_option_overlay_full_overlay?
      setback = _fetch_option_back_panel_setback
      setback.nil? || setback <= 0 ? 0 : setback
    end

    # -----

    # Cuts the GROOVES the panels are let into, in the parts around their
    # mouth, and answers the container path the panels are then to be built in
    # (see SmartDrawMouthPanelActionHandler#_create_entity, which runs this
    # inside its own operation and before it builds anything).
    #
    # Everything is measured BEFORE the first write : separating a shared
    # definition clones it, and every entity read beforehand then belongs to
    # the definition nobody sees any more. The hosts are therefore found again
    # afterwards by their POSITION, not by the reference that was held on them.
    # Two cuts of a DIFFERENT NATURE, and the difference is not a matter of
    # taste :
    #
    #   A GROOVE bites into a part that stays WHOLE. A machining volume is
    #   exactly right for it - the part keeps its dimensions, which is the truth
    #   a grooved stile owes the cutlist, the pocket is read off the volume by
    #   CommonDrawingProjectionWorker for the CNC, and deleting the volume gives
    #   the part back. Nothing of it shows either : the panel's edge is buried
    #   inside an opaque part.
    #
    #   A CROSSING ends a part. A machining volume is WRONG for it, and not just
    #   to look at : BoundingBoxHelper skips machining volumes outright
    #   (bounding_box_helper.rb:27), so the part would keep the length it no
    #   longer has and the cutlist would call for a divider that does not fit.
    #   The volume has to come off for real - hence the subtraction.
    #
    # Order matters. The grooves go first, by position, separating what they must
    # as they go ; the crossings are resolved only afterwards, on a container
    # that has stopped moving, and their own sharing is left to
    # CommonSolidBooleanApplyWorker, which preserves a definition two identical
    # dividers share when the cut leaves them identical - something a separation
    # of our own would have thrown away.
    def _prepare_panels!(panel_defs)
      container_path = panel_defs.first.container_path.dup

      machining_defs = _compute_machining_defs(panel_defs)
      return container_path if machining_defs.empty?

      # The container first : it is the ancestor every host hangs under, and
      # separating it after them would strand the cuts in the definition nobody
      # sees any more.
      _make_unique_instances_in_path(container_path)

      opening_transformation = _get_opening_transformation(panel_defs.first.opening_def)

      cut = _nest_machinings!(container_path, opening_transformation, machining_defs.reject { |machining_def| machining_def.crossed })
      cut += _subtract_crossings!(container_path, opening_transformation, machining_defs.select { |machining_def| machining_def.crossed })

      # The cavities were read on entities a separation may have replaced, and
      # so was the active part : both are dropped rather than left pointing at
      # geometry nobody sees any more. The next pick pays for a detection again,
      # and only in that case.
      _reset_cavities_def
      _reset_active_part

      # Worth saying only when a groove was ASKED for and none could be cut :
      # the panel is then loose in its mouth, which is not what the options
      # describe. A groove the silhouette clipped away on some edges is not
      # this case - see #_grow_nominal_points.
      @tool.notify_warnings([ [ "tool.smart_draw.warning.no_#{_panel_i18n_key_suffix}_machining" ] ]) if cut == 0

      container_path
    end

    # Nests one machining volume per given groove, in the part it is cut in.
    # Answers how many parts took one.
    def _nest_machinings!(container_path, opening_transformation, machining_defs)
      return 0 if machining_defs.empty?

      model = Sketchup.active_model
      material = MaterialAttributes.fetch_or_create_material(model, _fetch_option_machining_material_name, MaterialAttributes::TYPE_MACHINING, SmartDrawTool::COLOR_DEFAULT_MACHINING_MATERIAL)
      layer_name = _fetch_option_machining_layer_name
      layer = layer_name.is_a?(String) && !layer_name.strip.empty? ? (model.layers[layer_name] || model.layers.add(layer_name)) : nil

      grooved = 0
      machining_defs.each do |machining_def|

        host_path = _make_unique_descendant_path(container_path, machining_def.host_index_path)
        next if host_path.nil?

        host = host_path.last
        next unless host.respond_to?(:definition)

        group = host.definition.entities.add_group
        # Set BEFORE the faces go in, so that they are drawn in the opening's
        # own frame - the very frame the ring was computed in.
        group.transformation = PathUtils.get_transformation(host_path, IDENTITY).inverse * opening_transformation

        machining_def.paths.each do |path|
          _build_machining_prism(group.entities, Fiddle::Clippy.rpath_to_points(path), machining_def.z_low, machining_def.z_high)
        end

        if group.entities.grep(Sketchup::Face).empty?
          group.erase!
          next
        end

        group.material = material unless material.nil?
        group.layer = layer unless layer.nil?

        grooved += 1

      end
      grooved
    end

    # Takes the crossed parts down to the panel, for real : the volume standing
    # on the far side of it is SUBTRACTED from each of them. Answers how many
    # parts were cut.
    #
    # One single call for all of them - one Manifold pass, one shared definition
    # plan. The cut volumes are built as plain groups beside the hosts and are
    # consumed by the operation (keep_cuts: false).
    #
    # wrap_operation: false : the subtraction joins the operation the panel is
    # being built in, so ONE undo takes back the panel and every part it cut. A
    # failure is raised rather than reported, so that #_create_entity's own
    # rescue aborts that operation whole - a carcass half cut is worse than no
    # panel at all.
    def _subtract_crossings!(container_path, opening_transformation, machining_defs)
      return 0 if machining_defs.empty?

      container = container_path.last
      return 0 unless container.respond_to?(:definition)

      container_transformation_inverse = PathUtils.get_transformation(container_path, IDENTITY).inverse

      src_ipaths = []
      cut_ipaths = []
      machining_defs.each do |machining_def|

        host_path = _descendant_path(container_path, machining_def.host_index_path)
        next if host_path.nil?
        next unless host_path.last.respond_to?(:definition)

        # Beside the hosts, not inside them : a cut is an operand of the
        # operation, not a part of anything.
        group = container.definition.entities.add_group
        # Set BEFORE the faces go in, so that they are drawn in the opening's own
        # frame - the very frame the contours were computed in.
        group.transformation = container_transformation_inverse * opening_transformation

        machining_def.paths.each do |path|
          _build_machining_prism(group.entities, Fiddle::Clippy.rpath_to_points(path), machining_def.z_low, machining_def.z_high)
        end

        if group.entities.grep(Sketchup::Face).empty?
          group.erase!
          next
        end

        src_ipaths << Sketchup::InstancePath.new(host_path)
        cut_ipaths << Sketchup::InstancePath.new(container_path + [ group ])

      end
      return 0 if src_ipaths.empty?

      # The very parameters the reshape tool's own boolean handler uses : the
      # container tree preserved (flatten: false), and the hosts' existing
      # machinings left out of the operand, so a part already grooved is not
      # rebuilt around its own pockets.
      parameters = {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: true,
        ignore_soft_edges: true,
        ignore_clines: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS,
        flatten: false
      }
      fn_decompose = lambda { |ipath| CommonDrawingDecompositionWorker.new([ ipath ], **parameters).run }

      src_drawing_defs = src_ipaths.map { |ipath| fn_decompose.call(ipath) }
      cut_drawing_defs = cut_ipaths.map { |ipath| fn_decompose.call(ipath) }
      raise "Unable to read the parts the #{_panel_i18n_key_suffix} runs across" unless (src_drawing_defs + cut_drawing_defs).all? { |drawing_def| drawing_def.is_a?(DrawingDef) }

      result_def = CommonSolidBooleanApplyWorker.new(
        src_drawing_defs,
        cut_drawing_defs,
        operation: CommonSolidBooleanWorker::OPERATION_SUBTRACTION,
        keep_cuts: false,
        wrap_operation: false
      ).run
      raise "Unable to cut the parts the #{_panel_i18n_key_suffix} runs across : #{result_def.errors.inspect}" unless result_def.success?

      src_ipaths.length
    end

    # The path +index_path+ leads to from +container_path+, walked by POSITION
    # and separating nothing on the way - what a host is found again by once the
    # container has been made unique. nil when the chain no longer leads
    # anywhere.
    def _descendant_path(container_path, index_path)
      path = container_path.dup
      index_path.each do |index|
        parent = path.last
        return nil unless parent.respond_to?(:definition)
        entity = parent.definition.entities.to_a[index]
        return nil unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        path << entity
      end
      path
    end

    # One cut to make : the part it goes in (as the chain of positions leading to
    # it from the cavity container, read before anything moved), the contours in
    # the OPENING's frame, the range along that frame's normal it runs between,
    # and whether the panel CROSSES that part rather than merely biting into it.
    #
    # +crossed+ is what decides how the cut is made at all, and the two are not
    # interchangeable - see #_prepare_panels!.
    MachiningDef = Struct.new(:host_index_path, :paths, :z_low, :z_high, :crossed)

    # The grooves the given panels call for, one per part they run into -
    # measured, never written.
    #
    # The RING is what does the work : the panels' own contours, minus the
    # mouth. What is left is exactly the material they are driven into, and
    # nothing else - the seam between two panels of one shared contour falls
    # INSIDE the mouth and drops out of the ring on its own, which is why the
    # growth has to happen before the sharing and not after.
    #
    # The ring is then cut up by the parts it lies over : intersected with each
    # panel's own footprint (see #_get_panel_footprint_paths), it gives that
    # part's groove and no other's. A part the ring does not reach, or one that
    # has no material at the depth the panel sits at, takes none.
    def _compute_machining_defs(panel_defs)
      return [] if _fetch_option_construction?
      return [] if _fetch_option_overlay_full_overlay?
      return [] unless _fetch_option_machining == SmartDrawTool::ACTION_OPTION_MACHINING_VOLUME

      depth = _fetch_option_back_panel_depth
      return [] if depth.nil? || depth <= 0

      thickness = _fetch_option_thickness
      return [] if thickness.nil? || thickness <= 0

      return [] unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      opening_def = panel_defs.first.opening_def

      t = _get_opening_transformation(opening_def)
      ti = t.inverse

      # EVERY mouth the panel spans, not just the picked one : over a merge, the
      # ring read off a single mouth would count the whole of the other
      # compartments as material to cut into.
      raw_mouth_paths = _merge_mouth_paths
      if raw_mouth_paths.empty?
        mouth = opening_def.outer_loop
        return [] if mouth.nil? || mouth.length < 3
        raw_mouth_paths = [ Fiddle::Clippy.points_to_rpath(mouth.map { |point| point.transform(ti) }) ]
      end

      panel_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: panel_defs.map { |panel_def| Fiddle::Clippy.points_to_rpath(panel_def.plane_outline) })
      mouth_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: raw_mouth_paths)
      ring_paths, _ = Fiddle::Clippy.execute_difference(closed_subjects: panel_paths, clips: mouth_paths)
      return [] if ring_paths.empty?

      # The slot the panel itself occupies, along the opening's normal : it
      # stands back by the setback, and runs inwards by its thickness.
      setback = _panel_outline_offset(opening_def).to_f
      slot_high = -setback
      slot_low = -setback - thickness.to_f

      # The parts the panel runs STRAIGHT ACROSS, over a merge - see
      # #_get_crossed_drawing_defs. They take a cut of another nature entirely,
      # and are told apart here, once.
      crossed_drawing_defs = _get_crossed_drawing_defs(_merge_share_paths, opening_def, ti)

      machining_defs = []
      cavities_def.drawing_defs.each do |drawing_def|

        # A panel already laid on the carcass is not carcass : nothing is ever
        # grooved into another back, or into a front.
        next if LayerAttributes.panel_type?(LayerAttributes.type_of(drawing_def.container))

        host_index_path = _entity_index_path(cavities_def.container_path, drawing_def.container_path)
        next if host_index_path.nil? || host_index_path.empty?

        z_min, z_max = _drawing_def_plane_extent(drawing_def, ti)
        next if z_min.nil?
        # Nothing of this part stands where the panel does : no groove to cut.
        next if z_max <= slot_low + SolidMeshDef::TOLERANCE || z_min >= slot_high - SolidMeshDef::TOLERANCE

        host_paths = _get_panel_footprint_paths(drawing_def, opening_def, ti)
        next if host_paths.nil? || host_paths.empty?

        groove_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: ring_paths, clips: host_paths)
        groove_paths = _clean_pieces(groove_paths)
        next if groove_paths.empty?

        crossed = crossed_drawing_defs.any? { |crossed_drawing_def| crossed_drawing_def.equal?(drawing_def) }

        if crossed
          # OVERSHOT, on every side. A crossing cut is flush with the part it
          # takes off on three of its faces at once - its walls stand on that
          # part's own sides, its far face on that part's far face - which is the
          # degeneracy a boolean is worst at. Pushed out by a hair it is flush
          # with nothing, and it removes not one cubic millimetre more : there is
          # no material of that part out there, and the cut is subtracted from
          # the parts it is meant for and from no others.
          overshot_paths = Fiddle::Clippy.inflate_paths(
            paths: groove_paths,
            delta: CROSSING_OVERSHOOT.to_f,
            join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
            miter_limit: 100.0
          )
          groove_paths = overshot_paths unless overshot_paths.empty?
        end

        # A CROSSED part is cut from the panel's inner face OUT, through whatever
        # of it stood beyond : the panel passes in front of it, so everything on
        # the far side of the panel is material that has nowhere left to be - the
        # lip a setback would otherwise leave standing behind the panel included.
        # A GROOVE is clamped to the slot the panel occupies, and to the part
        # itself : it never sticks out of the part whatever the setback and the
        # thickness say.
        machining_defs << MachiningDef.new(host_index_path, groove_paths, [ slot_low, z_min ].max, crossed ? z_max + CROSSING_OVERSHOOT.to_f : [ slot_high, z_max ].min, crossed)

      end

      machining_defs
    end

    # The chain of POSITIONS leading from +container_path+ down to
    # +entity_path+ - what a host is found again by once a separation has
    # replaced the entities on the way to it. nil when the one is not under the
    # other at all.
    def _entity_index_path(container_path, entity_path)
      return nil unless container_path.is_a?(Array) && entity_path.is_a?(Array)
      return nil unless entity_path.length > container_path.length
      return nil unless entity_path[0, container_path.length] == container_path

      index_path = []
      parent = container_path.last
      entity_path[container_path.length..-1].each do |entity|
        return nil unless parent.respond_to?(:definition)
        index = parent.definition.entities.to_a.index(entity)
        return nil if index.nil?
        index_path << index
        parent = entity
      end
      index_path
    end

    # Walks +index_path+ down from +container_path+, separating every instance
    # on the way that shares its definition, and answers the path to what it
    # lands on - so that what is about to be added down there is added THERE
    # and nowhere else. nil when the chain no longer leads anywhere.
    #
    # Walked from the container EVERY time, by position : a separation on one
    # host replaces the entities its siblings are read through as well, and
    # reading them again is what keeps the next host right.
    def _make_unique_descendant_path(container_path, index_path)
      path = container_path.dup
      index_path.each do |index|
        parent = path.last
        return nil unless parent.respond_to?(:definition)
        entity = parent.definition.entities.to_a[index]
        return nil if entity.nil?
        step = [ entity ]
        _make_unique_instances_in_path(step)
        path << step.first
      end
      path
    end

    # How far the given part reaches along the opening's normal, as [ min, max ]
    # in the opening's frame - read off its BOUNDS, so conservative for an L
    # shaped part. That is enough : it only ever rules out a part that stands
    # nowhere near the panel, and the footprint intersection does the real work.
    def _drawing_def_plane_extent(drawing_def, ti)
      bounds = drawing_def.bounds
      return [ nil, nil ] if bounds.nil? || bounds.empty?

      transformation = drawing_def.transformation
      transformation = IDENTITY unless transformation.is_a?(Geom::Transformation)

      z_min = nil
      z_max = nil
      (0..7).each do |index|
        z = bounds.corner(index).transform(transformation).transform(ti).z.to_f
        z_min = z if z_min.nil? || z < z_min
        z_max = z if z_max.nil? || z > z_max
      end
      [ z_min, z_max ]
    end

    # The groove itself : +points+, given in the opening's frame on z = 0,
    # standing up as a prism between +z_low+ and +z_high+. Drawn in a group
    # whose own frame IS the opening's, so the points go in as they are.
    def _build_machining_prism(entities, points, z_low, z_high)
      return [] if points.length < 3
      return [] if (z_high - z_low).abs <= SolidMeshDef::TOLERANCE

      face = entities.add_face(points.map { |point| Geom::Point3d.new(point.x, point.y, z_low) })
      return [] if face.nil?

      # Turned to look the way it is about to be pushed, so that #pushpull
      # extrudes towards +z whichever way add_face wound it.
      face.reverse! if face.normal.z < 0
      face.pushpull(z_high - z_low)

      entities.grep(Sketchup::Face)
    end

  end

end
