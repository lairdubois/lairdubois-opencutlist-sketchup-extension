module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../lib/fiddle/meshy/meshy'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'
  require_relative '../helper/face_matcher_helper'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/attributes/layer_attributes'
  require_relative '../model/solid/solid_mesh_def'
  require_relative '../model/solid/solid_boolean_result_def'
  require_relative '../utils/component_utils'
  require_relative '../utils/file_path_utils'
  require_relative '../utils/path_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_solid_find_cavities_worker'
  require_relative '../worker/common/common_solid_boolean_apply_worker'
  require_relative '../worker/common/common_stretch_split_worker'
  require_relative '../worker/common/common_stretch_apply_worker'

  class SmartBuildTool < SmartTool

    ACTION_BUILD_MODULE = 0
    ACTION_BUILD_DIVIDER = 1
    ACTION_BUILD_FRONT_PANEL = 2
    ACTION_BUILD_BACK_PANEL = 3

    ACTION_OPTION_THICKNESS = 'thickness'
    ACTION_OPTION_OFFSET = 'offset'
    ACTION_OPTION_GROOVE = 'groove'
    ACTION_OPTION_MEASURE_TYPE = 'measure_type'
    ACTION_OPTION_OVERLAY = 'overlay'
    ACTION_OPTION_AXES = 'axes'
    ACTION_OPTION_ANCHOR = 'anchor'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_THICKNESS_THICKNESS = 'thickness'

    ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET = 'front_panel_offset'

    ACTION_OPTION_GROOVE_DEPTH = 'groove_depth'
    ACTION_OPTION_GROOVE_SETBACK = 'groove_setback'
    ACTION_OPTION_GROOVE_THROUGH = 'groove_through'

    ACTION_OPTION_MEASURE_TYPE_INSIDE = 'inside'
    ACTION_OPTION_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_MEASURE_TYPE_OUTSIDE = 'outside'

    ACTION_OPTION_OVERLAY_INSET = 'inset'
    ACTION_OPTION_OVERLAY_FULL_OVERLAY = 'full_overlay'

    ACTION_OPTION_AXES_ACTIVE = 'active'
    ACTION_OPTION_AXES_CONTEXT = 'context'

    ACTION_OPTION_ANCHOR_CENTER_X = 'center_x'
    ACTION_OPTION_ANCHOR_CENTER_Y = 'center_y'
    ACTION_OPTION_ANCHOR_CENTER_Z = 'center_z'
    ACTION_OPTION_ANCHOR_ORIGIN = 'origin'

    ACTION_OPTION_OPTIONS_MEASURE_REVERSED = 'measure_reversed'
    ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE = 'reduce_envelope'
    ACTION_OPTION_OPTIONS_REUSE_DEFINITION = 'reuse_definition'
    ACTION_OPTION_OPTIONS_MIRROR = 'mirror'
    ACTION_OPTION_OPTIONS_FACE_CAMERA = 'face_camera'
    ACTION_OPTION_OPTIONS_TOP_UP = 'top_up'
    ACTION_OPTION_OPTIONS_ASK_NAME = 'ask_name'
    ACTION_OPTION_OPTIONS_LAYER_NAME = 'layer_name'

    # The library folder the module SKP files are picked in
    MODULES_LIBRARY_REF = '$LIB/components/modules'

    # The mirror motif - a dashed axis, a triangle on each side pointing at it
    # (the same as SmartHandleTool's) - and the same turned a quarter : the
    # axis then runs across, for front panels mirrored on top of one another.
    MIRROR_MOTIF_VERTICAL_PATH = 'M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2'
    MIRROR_MOTIF_HORIZONTAL_PATH = 'M0,0.5L0.2,0.5 M0.4,0.5L0.6,0.5 M0.8,0.5L1,0.5 M0.2,0L0.5,0.3L0.8,0L0.2,0 M0.2,1L0.5,0.7L0.8,1L0.2,1'

    ACTIONS = [
      {
        :action => ACTION_BUILD_DIVIDER,
        :options => {
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_MEASURE_TYPE => [ ACTION_OPTION_MEASURE_TYPE_INSIDE, ACTION_OPTION_MEASURE_TYPE_CENTERED, ACTION_OPTION_MEASURE_TYPE_OUTSIDE ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      },
      {
        :action => ACTION_BUILD_FRONT_PANEL,
        :options => {
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET ],
          ACTION_OPTION_OVERLAY => [ ACTION_OPTION_OVERLAY_INSET, ACTION_OPTION_OVERLAY_FULL_OVERLAY ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_MIRROR, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      },
      {
        :action => ACTION_BUILD_BACK_PANEL,
        :options => {
          ACTION_OPTION_THICKNESS => [ ACTION_OPTION_THICKNESS_THICKNESS ],
          ACTION_OPTION_GROOVE => [ ACTION_OPTION_GROOVE_DEPTH, ACTION_OPTION_GROOVE_SETBACK, ACTION_OPTION_GROOVE_THROUGH ],
          ACTION_OPTION_OVERLAY => [ ACTION_OPTION_OVERLAY_INSET, ACTION_OPTION_OVERLAY_FULL_OVERLAY ],
          ACTION_OPTION_AXES => [ ACTION_OPTION_AXES_ACTIVE, ACTION_OPTION_AXES_CONTEXT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, ACTION_OPTION_OPTIONS_REUSE_DEFINITION, ACTION_OPTION_OPTIONS_ASK_NAME ]
        }
      }
    ]

    if Sketchup.debug_mode?
      ACTIONS = [
                 {
                   :action => ACTION_BUILD_MODULE,
                   :options => {
                     ACTION_OPTION_ANCHOR => [ ACTION_OPTION_ANCHOR_CENTER_X, ACTION_OPTION_ANCHOR_CENTER_Y, ACTION_OPTION_ANCHOR_CENTER_Z, ACTION_OPTION_ANCHOR_ORIGIN ],
                     ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_FACE_CAMERA, ACTION_OPTION_OPTIONS_TOP_UP, ACTION_OPTION_OPTIONS_ASK_NAME ]
                   }
                 }
               ] + ACTIONS
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
      'build'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_BUILD_MODULE
        return SmartCursorManager.cursor_pencil_module
      when ACTION_BUILD_DIVIDER
          return SmartCursorManager.cursor_pencil_divider
      when ACTION_BUILD_FRONT_PANEL
          return SmartCursorManager.cursor_pencil_front_panel
      when ACTION_BUILD_BACK_PANEL
          return SmartCursorManager.cursor_pencil_back_panel
      end

      super
    end

    def get_action_option_status(action, option_group, option)

      case action
      when ACTION_BUILD_BACK_PANEL
        case option_group
        when ACTION_OPTION_OVERLAY
          return PLUGIN.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_option_#{option_group}_#{option}_status")
        end
      end

      super
    end

    def get_action_option_group_title(action, option_group)

      case action
      when ACTION_BUILD_FRONT_PANEL
        case option_group
        when ACTION_OPTION_OFFSET
          return PLUGIN.get_i18n_string("tool.smart_#{get_stripped_name}.action_#{action}_option_group_#{option_group}")
        end
      end

      super
    end

    def get_action_options_modal?(action)
      action == ACTION_BUILD_FRONT_PANEL || action == ACTION_BUILD_BACK_PANEL
    end

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_THICKNESS
        case option
        when ACTION_OPTION_THICKNESS_THICKNESS
          return [ ACTION_BUILD_DIVIDER, ACTION_BUILD_FRONT_PANEL ]
        end
      when ACTION_OPTION_AXES
        return [ ACTION_BUILD_DIVIDER, ACTION_BUILD_FRONT_PANEL, ACTION_BUILD_BACK_PANEL ]
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_ASK_NAME
          return [ ACTION_BUILD_MODULE, ACTION_BUILD_DIVIDER, ACTION_BUILD_FRONT_PANEL, ACTION_BUILD_BACK_PANEL ]
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
        when ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET
          return false
        end
      when ACTION_OPTION_GROOVE
        case option
        when ACTION_OPTION_GROOVE_DEPTH, ACTION_OPTION_GROOVE_SETBACK
          return false
        end
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_OVERLAY
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
        when ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_GROOVE
        case option
        when ACTION_OPTION_GROOVE_DEPTH, ACTION_OPTION_GROOVE_SETBACK
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        when ACTION_OPTION_GROOVE_THROUGH
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0H.5V.375H0ZM.75,.125V1M.5,0H1V1H.5ZM.625,.375L.75,.125L.875,.375'))
        end
      when ACTION_OPTION_MEASURE_TYPE
        case option
        when ACTION_OPTION_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.655,.917V.583H.989V.917ZM0,.25H1M0,.083V.417M1,.083V.417'))
        when ACTION_OPTION_MEASURE_TYPE_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.655,.917V.583H.989V.917ZM0,.25H.833M0,.083V.417M.833,.083V.417'))
        when ACTION_OPTION_MEASURE_TYPE_INSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.655,.917V.583H.989V.917ZM0,.25H.667M0,.083V.417M.667,.083V.417'))
        end
      when ACTION_OPTION_AXES
        case option
        when ACTION_OPTION_AXES_ACTIVE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,0V.833H1M0,.167L.167,0L.333,.167M.833,.667L1,.833L.833,1'))
        when ACTION_OPTION_AXES_CONTEXT
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,0V.833H1M0,.167L.167,0L.333,.167M.833,.667L1,.833L.833,1M.5,.083V.5H.917V.083Z'))
        end
      when ACTION_OPTION_ANCHOR
        case option
        when ACTION_OPTION_ANCHOR_CENTER_X
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.062,.313H.687V.938H.062ZM.687,.313L1,0M.063,.938L.375,.625M.687,.938L1,.625M.063,.313L.375,0M1,0V.625M.375,0V.625M.375,0H1M.375,.625H1M.313,.875H.438V1H.313Z'))
        when ACTION_OPTION_ANCHOR_CENTER_Y
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.062,.313H.687V.938H.062ZM.687,.313L1,0M.063,.938L.375,.625M.687,.938L1,.625M.063,.313L.375,0M1,0V.625M.375,0V.625M.375,0H1M.375,.625H1M.188,.688H.313V.813H.188Z'))
        when ACTION_OPTION_ANCHOR_CENTER_Z
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.062,.313H.687V.938H.062ZM.687,.313L1,0M.063,.938L.375,.625M.687,.938L1,.625M.063,.313L.375,0M1,0V.625M.375,0V.625M.375,0H1M.375,.625H1M0,.563H.125V.688H0Z'))
        when ACTION_OPTION_ANCHOR_ORIGIN
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.25,0V.75H1M.083,.167L.25,0L.417,.167M.833,.583L1,.75L.833,.917M.125,.625L.375,.875M.125,.875L.375,.625'))
        end
      when ACTION_OPTION_OVERLAY
        case option
        when ACTION_OPTION_OVERLAY_INSET
          case action
          when ACTION_BUILD_BACK_PANEL
            return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.75,1V.5M.75,.25V0H1V1M0,.25V.5H.875V.25ZM.875,1L1,.875M.875,.25L1,.125M.75,.125L.875,0M.75,.625L1,.375M.75,.875L1,.625'))
          else
            return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.75V1H.625V.75ZM.75,0V1H1V0M.875,0L1,.125M.75,.875L.875,1M.75,.375L1,.625M.75,.625L1,.875M.75,.125L1,.375'))
          end
        when ACTION_OPTION_OVERLAY_FULL_OVERLAY
          case action
          when ACTION_BUILD_BACK_PANEL
            return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.75,1V.25H1V1M0,0V.25H1V0ZM.875,1L1,.875M.75,.375L.875,.25M.75,.625L1,.375M.75,.875L1,.625'))
          else
            return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.75V1H1V.75ZM.75,0V.625H1V0M.875,0L1,.125M.75,.375L1,.625M.75,.125L1,.375'))
          end
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MEASURE_REVERSED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1V.667H1V1ZM.25,.667V.833M.5,.667V.833M.75,.667V.833M.861,.292L.708,.139L.5,.083L.292,.139L.14,.292M.14,.083V.292H.333'))
        when ACTION_OPTION_OPTIONS_ASK_NAME
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.25H1V.75H0ZM.438,.313V.688M.125,.625V.375L.313,.625V.375'))
        when ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0V1H1V0ZM0,.625H.625V.375H0'))
        when ACTION_OPTION_OPTIONS_REUSE_DEFINITION
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.333H.667V1H0ZM.333,.333V0H1V.667H.667'))
        when ACTION_OPTION_OPTIONS_MIRROR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(MIRROR_MOTIF_VERTICAL_PATH))
        when ACTION_OPTION_OPTIONS_FACE_CAMERA
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.688,.375L.875,.25V.625L.688,.5V.625H.375V.25H.687ZM.125,0V.875H1M0,.125L.125,0L.25,.125M.875,.75L1,.875L.875,1'))
        when ACTION_OPTION_OPTIONS_TOP_UP
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.125,0V1M0,.125L.125,0L.25,.125M.375,.25H.75L.375,.75H.75M.875,.375V.625M.75,.5H1'))
        end
      end

      super
    end

    def get_action_option_btn_prefix(action, option_group, option)
      case option
      when ACTION_OPTION_GROOVE_DEPTH
        return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.875,.625V0H.5V.25H.75V.5H.5V.625M.5,0H.875M.75,0L.875,.125M.75,.5L.875,.625M.5,.5L.625,.625M.625,.5L.75,.625M.75,.375L.875,.5M.5,.125L.625,.25M.625,0L.875,.25M.5,0L.875,.375M.75,.75V1M.5,.75V1M.75,.875H.5'))
      when ACTION_OPTION_GROOVE_SETBACK
        return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.875,.625V0H.5V.25H.75V.5H.5V.625M.5,0H.875M.75,0L.875,.125M.75,.5L.875,.625M.5,.5L.625,.625M.625,.5L.75,.625M.75,.375L.875,.5M.5,.125L.625,.25M.625,0L.875,.25M.5,0L.875,.375M.125,0H.375M.125,.25H.375M.25,0V.25'))
      end

      super
    end

    def get_action_option_btn_disabled?(action, option_group, option)

      case option_group

      when ACTION_OPTION_GROOVE
        case option
        when ACTION_OPTION_GROOVE_DEPTH, ACTION_OPTION_GROOVE_SETBACK, ACTION_OPTION_GROOVE_THROUGH
          return fetch_action_option_boolean(action, ACTION_OPTION_OVERLAY, ACTION_OPTION_OVERLAY_FULL_OVERLAY)
        end
      when ACTION_OPTION_ANCHOR
        case option
        when ACTION_OPTION_ANCHOR_CENTER_X, ACTION_OPTION_ANCHOR_CENTER_Y, ACTION_OPTION_ANCHOR_CENTER_Z
          return fetch_action_option_boolean(action, ACTION_OPTION_ANCHOR, ACTION_OPTION_ANCHOR_ORIGIN)  # The origin anchor overrides them
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MIRROR
          return !fetch_action_option_boolean(action, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
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
      when ACTION_BUILD_MODULE
        set_action_handler(SmartBuildModuleActionHandler.new(self))
      when ACTION_BUILD_DIVIDER
        set_action_handler(SmartBuildDividerActionHandler.new(self))
      when ACTION_BUILD_FRONT_PANEL
        set_action_handler(SmartBuildFrontPanelActionHandler.new(self))
      when ACTION_BUILD_BACK_PANEL
        set_action_handler(SmartBuildBackPanelActionHandler.new(self))
      end

      super
    end

    def onViewChanged(view)
      super
      refresh
    end

  end

  # -----

  class SmartBuildActionHandler < SmartActionHandler

    include SmartActionHandlerAutoOrientHelper
    include UserTextHelper

    # -----

    def stop
      @tool.clear_all_3d
      @tool.clear_all_2d
      super
    end

    # -----

    def onToolTransactionUndo(tool, model)
      _refresh
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    def _fetch_option_ask_name?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_ASK_NAME)
    end

  end

  # Builds a module imported from an SKP file - picked in the bottom bar among
  # the files of SmartBuildTool::MODULES_LIBRARY_REF and its sub folders -
  # by drawing its bounding box in 4 clicks : its origin, then its X, Y and Z
  # edges - Y perpendicular to X, Z normal to the XY plane. SHIFT locks the
  # current edge on the source size. The imported content is exploded into a
  # new group, then resized axis by axis with the Stretch workers, cut where the
  # 'stretch_cutters' of the SKP definition (as SmartReshape stores them) say.
  #
  # The module is never mirrored : X and the Z side give its orientation, Y is
  # deduced (right-handed) and the Y click only gives the depth and the side
  # the box extends to.
  class SmartBuildModuleActionHandler < SmartBuildActionHandler

    include MaterialAttributesCachingHelper

    STATE_SOURCE = 0  # No file picked in the library
    STATE_ORIGIN = 1
    STATE_X = 2
    STATE_Y = 3
    STATE_Z = 4
    STATE_ADD = 5     # Picking an instance to save as a file of the browsed folder

    # The least sine between X and an XY plane normal locked by the arrow
    # keys : a 10 degree threshold.
    LOCKED_XY_NORMAL_MIN_SINE = 0.17

    LAYER_3D_BOX_PREVIEW = 200

    LAYER_2D_DIMENSIONS = 100
    LAYER_2D_LIBRARY = 110

    # The library folder browsed and the source file picked, as '$LIB/…' refs.
    # Remembered for the session only.
    @@dir_ref = nil
    @@source_ref = nil

    # The first visible row of the folders and files rows of the library
    # panel, for the folder browsed : { :dir_ref, :dirs, :files }. Kept across
    # handlers to find the panel scrolled as it was left.
    @@library_scroll = nil

    # Source probes, by file path : { :mtime, :cutters, :content_bounds, :compression_distances, … }.
    # Kept across handlers to probe a file only once while it is unchanged.
    @@sources = {}

    def initialize(tool, previous_action_handler = nil)
      super(SmartBuildTool::ACTION_BUILD_MODULE, tool, previous_action_handler)

      @mouse_ip = SmartInputPoint.new(tool)
      @mouse_snap_point = nil
      @source_size_point = nil      # Current edge end at the source size, nil if none
      @source_size_snapped = false  # The mouse is snapped on it

      @picked_origin = nil
      @picked_x_point = nil
      @picked_y_point = nil

      @front_flipped = false  # The user swapped the front with the back
      @up_flipped = false     # The user turned the content upside down

      @origin_directions = []   # Directions of the edges and clines touching the picked origin
      @origin_segments = []     # The edge each origin direction comes from, as a world segment - nil for a cline
      @locked_x_axis = nil      # X direction locked by the arrow keys
      @snapped_x_axis = nil     # X direction the mouse is snapped on (locked or auto)
      @locked_xy_normal = nil   # XY plane normal locked by the arrow keys

      @source = nil

      @add_instance = nil  # Instance hovered in STATE_ADD
      @add_tooltip_instance = nil  # Instance the STATE_ADD tooltip describes

      @double_click_time = nil  # To ignore the button up closing a double click

      tool.create_2d(LAYER_2D_LIBRARY, :bottom)

    end

    # -----

    def start
      _check_library_refs
      @source = _get_source
      _setup_library_panel
      super
    end

    def stop
      @tool.hide_message
      super
    end

    # -- State --

    def get_startup_state
      @source.nil? ? STATE_SOURCE : STATE_ORIGIN
    end

    def get_state_cursor(state)

      case state
      when STATE_Z
        return SmartCursorManager.cursor_pull
      when STATE_ADD
        return SmartCursorManager.cursor_select_module_plus
      end

      super
    end

    def get_state_status(state)

      case state
      when STATE_ORIGIN
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_flip_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_flip_up_status") + '.'
      when STATE_X, STATE_Y, STATE_Z
        return PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_state_#{state}_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string('default.constrain_key') + ' = ' + PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_state_#{state}_lock_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_flip_status") + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_flip_up_status") + '.' +
               (state == STATE_X || state == STATE_Y ? ' | ' + PLUGIN.get_i18n_string("tool.smart_build.action_#{@action}_state_#{state}_arrows_status") + '.' : '')
      end

      super
    end

    def get_state_vcb_label(state)

      case state
      when STATE_X, STATE_Y, STATE_Z
        return PLUGIN.get_i18n_string('tool.default.vcb_length')
      end

      super
    end

    def onStateChanged(old_state, new_state)
      super
      _show_locked_axis_message
      @tool.notify(get_state_status(new_state)) if new_state == STATE_ADD  # Hidden on leave by _show_locked_axis_message
      if old_state == STATE_ADD
        @add_tooltip_instance = nil
        @tool.remove_tooltip
      end
    end

    # -- Events --

    def onToolCancel(tool, reason, view)
      super

      case @state
      when STATE_SOURCE
        _reset
      when STATE_ORIGIN
        _select_source(nil)  # Unpicks the file, back to STATE_SOURCE
      when STATE_X
        @picked_origin = nil
        @origin_directions = []
        @origin_segments = []
        @locked_x_axis = nil
        set_state(STATE_ORIGIN)
      when STATE_Y
        @picked_x_point = nil
        @locked_xy_normal = nil
        set_state(STATE_X)
      when STATE_Z
        @picked_y_point = nil
        set_state(STATE_Y)
      when STATE_ADD
        _leave_add_mode
      end
      _refresh

    end

    def onToolMouseMove(tool, flags, x, y, view)
      super

      return if @state == STATE_SOURCE

      @mouse_ip.pick(view, x, y, _get_previous_input_point)
      @mouse_snap_point = nil
      @source_size_point = nil
      @source_size_snapped = false

      @tool.clear_3d(LAYER_3D_BOX_PREVIEW)
      @tool.clear_2d(LAYER_2D_DIMENSIONS)

      case @state
      when STATE_ORIGIN
        @mouse_snap_point = @mouse_ip.position
        _preview_source(view)
      when STATE_X
        _snap_x(x, y, view)
        _preview_box(view)
      when STATE_Y
        _snap_y(x, y, view)
        _preview_box(view)
      when STATE_Z
        _snap_z(x, y, view)
        _preview_box(view)
      when STATE_ADD
        _pick_add_instance(x, y, view)
      end

      view.tooltip = @state == STATE_ADD ? '' : @mouse_ip.tooltip
      view.invalidate

    end

    def onToolMouseLeave(tool, view)
      @tool.clear_3d(LAYER_3D_BOX_PREVIEW)
      @tool.clear_2d(LAYER_2D_DIMENSIONS)
      @mouse_ip.clear
      view.tooltip = ''
      if @state == STATE_ADD
        @add_instance = @add_tooltip_instance = nil
        @tool.remove_tooltip
      end
      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      # The button up closing a double click, if the platform sends one
      double_click_time, @double_click_time = @double_click_time, nil
      return if !double_click_time.nil? && Time.now - double_click_time < 0.5
      return (@add_instance.nil? ? UI.beep : _save_add_instance) if @state == STATE_ADD
      return UI.beep if @mouse_snap_point.nil? || @source.nil?
      _pick(@mouse_snap_point)
      _refresh
    end

    # Builds the module at once, the edges not drawn yet at the source sizes.
    # The first click of the double click already picked its point.
    def onToolLButtonDoubleClick(tool, flags, x, y, view)
      return false if @source.nil?
      x_size = nil
      case @state
      when STATE_X
        points = [ _get_default_x_point(@picked_origin) ]
        x_size = @source[:sizes][0]
      when STATE_Y
        points = [ @picked_x_point ]
      when STATE_Z
        points = [ @picked_x_point, @picked_y_point ]
      end
      return false if points.nil?
      return UI.beep if (box = _get_box(*points, complete: true, x_size: x_size)).nil?
      @double_click_time = Time.now
      _create_module(box)
      _reset
      _refresh
      true
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_alt_or_command?(key)
        return true # Block default behavior for the ALT key on Windows
      end

      if tool.is_key_shift?(key) && [ STATE_X, STATE_Y, STATE_Z ].include?(@state)
        _refresh
        return true
      end

      if key == Kuix::VK_ADD && repeat == 1 && !tool.is_vcb_typing?
        @state == STATE_ADD ? _leave_add_mode : _enter_add_mode  # As the add button
        return true
      end

      if @state == STATE_X
        axis = { VK_RIGHT => _get_active_x_axis, VK_LEFT => _get_active_y_axis, VK_UP => _get_active_z_axis }[key]
        unless axis.nil?
          @locked_x_axis = @locked_x_axis == axis ? nil : axis
          _refresh
          return true
        end
      end
      if @state == STATE_Y
        axis = { VK_RIGHT => _get_active_x_axis, VK_LEFT => _get_active_y_axis, VK_UP => _get_active_z_axis }[key]
        unless axis.nil?
          if @locked_xy_normal == axis
            @locked_xy_normal = nil
          else
            if _get_locked_y_axis(axis).nil?
              UI.beep  # Along X : can't be the XY plane normal
              return true
            end
            @locked_xy_normal = axis
          end
          _refresh
          return true
        end
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      if tool.is_key_shift?(key) && [ STATE_X, STATE_Y, STATE_Z ].include?(@state)
        _refresh
        return true
      end
      if tool.is_key_ctrl_or_option?(key) && is_quick
        @front_flipped = !@front_flipped
        _refresh
        return true
      end
      if tool.is_key_alt_or_command?(key) && is_quick
        @up_flipped = !@up_flipped
        _refresh
        return true
      end
      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      case @state

      when STATE_ORIGIN
        return _read_origin(tool, text, view)

      when STATE_X, STATE_Y, STATE_Z
        return _read_edge(tool, text, view)

      end

      false
    end

    def onToolActionOptionStored(tool, action, option_group, option)

      case option_group
      when SmartBuildTool::ACTION_OPTION_ANCHOR
        _refresh  # The center buttons are disabled by the origin one
      when SmartBuildTool::ACTION_OPTION_OPTIONS
        case option
        when SmartBuildTool::ACTION_OPTION_OPTIONS_FACE_CAMERA, SmartBuildTool::ACTION_OPTION_OPTIONS_TOP_UP
          _refresh  # The content turns in the box
        end
      end

    end

    # -----

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid? && ![ STATE_SOURCE, STATE_ADD ].include?(@state)
    end

    # -----

    protected

    def _reset
      @mouse_ip.clear
      @mouse_snap_point = nil
      @source_size_point = nil
      @source_size_snapped = false
      @picked_origin = nil
      @picked_x_point = nil
      @picked_y_point = nil
      @front_flipped = false
      @up_flipped = false
      @origin_directions = []
      @origin_segments = []
      @locked_x_axis = nil
      @snapped_x_axis = nil
      @locked_xy_normal = nil
      super
      _setup_library_panel  # Cleared with all the 2D layers
      set_state(get_startup_state)
    end

    # -- Snap --

    def _snap_x(x, y, view)
      on_geometry = _is_mouse_on_geometry?
      @snapped_x_axis = nil
      point = @mouse_ip.position
      if @locked_x_axis
        # Locked by the arrow keys
        point = _snap_on_origin_line(@locked_x_axis, x, y, view)
        @snapped_x_axis = @locked_x_axis
      elsif @mouse_ip.degrees_of_freedom >= 2
        # Auto locked on the closest origin direction, within a few pixels
        best_distance = 10
        @origin_directions.each do |direction|
          p = _snap_on_origin_line(direction, x, y, view)
          sp = view.screen_coords(p)
          distance = Math.hypot(sp.x - x, sp.y - y)
          next unless distance < best_distance
          best_distance = distance
          point = p
          @snapped_x_axis = direction
        end
      else
        # Snapped by SketchUp (on the origin edge itself, its other end, an
        # inference along it…) : the origin direction it lies on, if any
        @snapped_x_axis = @origin_directions.find { |direction| point.on_line?([ @picked_origin, direction ]) }
      end
      @mouse_ip.clear unless @snapped_x_axis.nil? || @mouse_ip.degrees_of_freedom < 2
      @mouse_snap_point = _lock_on_source_size(_snap_on_source_size(point, on_geometry, x, y, view))
    end

    def _snap_y(x, y, view)
      on_geometry = _is_mouse_on_geometry?
      if (y_axis = _get_locked_y_axis)
        # Locked by the arrow keys : on the line perpendicular to X and the normal
        point = _snap_on_origin_line(y_axis, x, y, view)
        @mouse_ip.clear unless @mouse_ip.degrees_of_freedom < 2
      elsif @mouse_ip.degrees_of_freedom > 2
        # Free : on the plane holding the X edge and the default Y direction
        x_axis = _get_x_axis
        point = Geom.intersect_line_plane(view.pickray(x, y), [ @picked_origin, x_axis * _get_default_y_axis(x_axis) ])
      else
        point = @mouse_ip.position
      end
      @mouse_snap_point = _lock_on_source_size(_snap_on_source_size(point, on_geometry, x, y, view))
    end

    def _snap_z(x, y, view)
      on_geometry = _is_mouse_on_geometry?
      line = [ _get_z_edge_base, _get_xy_normal ]  # Along the Z edge as drawn
      if @mouse_ip.degrees_of_freedom > 2 || @mouse_ip.position.on_plane?([ @picked_origin, _get_xy_normal ])
        point, _ = Geom.closest_points(line, view.pickray(x, y))
        @mouse_ip.clear
      else
        point = @mouse_ip.position.project_to_line(line)
      end
      @mouse_snap_point = _lock_on_source_size(_snap_on_source_size(point, on_geometry, x, y, view))
    end

    # The closest point to the mouse ray on the line through the origin along
    # the given direction : its projection when the input point is snapped.
    def _snap_on_origin_line(direction, x, y, view)
      line = [ @picked_origin, direction ]
      return @mouse_ip.position.project_to_line(line) if @mouse_ip.degrees_of_freedom < 2
      point, _ = Geom.closest_points(line, view.pickray(x, y))
      point
    end

    # Keeps the current edge end at the source size - on the mouse side - in
    # '@source_size_point', on the edge as drawn (not on an axis locked at the
    # source size), and snaps the given point on it if the mouse isn't snapped
    # by SketchUp on some geometry and is a few pixels away from it.
    def _snap_on_source_size(point, on_geometry, x, y, view)
      return point if @source.nil? || (box = _get_box(*_get_state_points(point))).nil?
      index = @state - STATE_X
      return point if @source[:locked_axes][box[:source_indices][index]]
      return point if (source_size_point = _get_source_size_point(point)).nil?
      @source_size_point = source_size_point.project_to_line([ _get_current_edge(box).first.transform(box[:t]), [ box[:t].xaxis, box[:t].yaxis, box[:t].zaxis ][index] ])
      return point if on_geometry
      sp = view.screen_coords(@source_size_point)
      return point unless Math.hypot(sp.x - x, sp.y - y) < 10
      @mouse_ip.clear
      @source_size_snapped = true
      source_size_point
    end

    # Replaces the length of the given snapped point along the current edge by
    # the source size if SHIFT is down.
    def _lock_on_source_size(point)
      return point unless @tool.is_key_shift_down?
      _get_source_size_point(point) || point
    end

    # The mouse input point snapped by SketchUp on some geometry (a vertex, an
    # edge, a cline) - not on a mere inference line (an axis…).
    def _is_mouse_on_geometry?
      @mouse_ip.degrees_of_freedom < 2 && !(@mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && @mouse_ip.cline.nil?)
    end

    # The current edge end making the box its source size along the current
    # axis, on the side of the given point. Y and Z edges start at the X point,
    # as drawn - only their part along their direction counts.
    def _get_source_size_point(point)
      return nil if @source.nil? || point.nil?
      direction, length = _get_edge_direction_and_length(point)
      return nil if direction.nil?
      measure = _get_anchor_measure(point, @source[:sizes][_get_current_source_index(point)])
      (@state == STATE_X ? @picked_origin : @picked_x_point).offset(direction, length < 0 ? -measure : measure)
    end

    # -- Preview --

    def _preview_box(view)

      case @state
      when STATE_X
        points = [ @mouse_snap_point ]
      when STATE_Y
        points = [ @picked_x_point, @mouse_snap_point ]
      when STATE_Z
        points = [ @picked_x_point, @picked_y_point, @mouse_snap_point ]
      end
      return if points.nil?

      # The first clicked point
      @tool.append_3d(_create_floating_points(points: [ @picked_origin ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_DARK_GREY), LAYER_3D_BOX_PREVIEW)

      # The current edge end at the source size, filled once the mouse snaps on it
      unless @source_size_point.nil?
        color = [ Kuix::COLOR_X, Kuix::COLOR_Y, Kuix::COLOR_Z ][@state - STATE_X]
        @tool.append_3d(_create_floating_points(
                          points: [ @source_size_point ],
                          style: Kuix::POINT_STYLE_CIRCLE,
                          fill_color: color,
                          stroke_color: nil,
                          size: 1.5
                        ), LAYER_3D_BOX_PREVIEW)
      end

      return if (box = _get_box(*points)).nil?

      _show_locked_axis_message(box)  # The content may have turned

      t = box[:t]
      w, d, h = box[:sizes].map { |size| size.to_l }

      # Dotted : the whole box, the edges not drawn yet at the source sizes
      box_complete = _get_box(*points, complete: true)
      _preview_box_complete(view, box_complete)

      p1, p2 = _get_current_edge(box)
      color = [ Kuix::COLOR_X, Kuix::COLOR_Y, Kuix::COLOR_Z ][@state - STATE_X]
      direction = [ X_AXIS, Y_AXIS, Z_AXIS ][@state - STATE_X]
      axis_color = _get_vector_color(direction.transform(t), nil)  # Color of the active axis the current edge follows, if any
      edge_snapped = @state == STATE_X && !@snapped_x_axis.nil?  # Along a neighbor edge (or an axis locked by the arrow keys)

      # The neighbor edge the X direction is snapped on - or perpendicular to - highlighted
      if edge_snapped && (index = @origin_directions.index { |direction| direction.equal?(@snapped_x_axis) }) && (segment = @origin_segments[index])

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segment)
        k_segments.line_width = 1.5
        k_segments.color = Kuix::COLOR_MAGENTA
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_BOX_PREVIEW)

      end

      # Thin dotted : the line the current edge lies on, in the color of the axis it follows, magenta if snapped on a neighbor edge, black otherwise
      k_line = Kuix::Line.new
      k_line.position = p1
      k_line.direction = direction
      k_line.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_line.color = axis_color || (edge_snapped ? Kuix::COLOR_MAGENTA : Kuix::COLOR_BLACK)
      k_line.transformation = t
      @tool.append_3d(k_line, LAYER_3D_BOX_PREVIEW)

      # The current edge, in its axis color : solid if aligned on an active axis or snapped on a neighbor edge, long dashes otherwise
      if p1 != p2

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(p1)
        k_edge.end.copy!(p2)
        k_edge.line_width = 2
        k_edge.line_stipple = axis_color.nil? && !edge_snapped ? Kuix::LINE_STIPPLE_LONG_DASHES : Kuix::LINE_STIPPLE_SOLID
        k_edge.color = color
        k_edge.transformation = t
        @tool.append_3d(k_edge, LAYER_3D_BOX_PREVIEW)

      end

      # The label of the current edge
      point = Geom.linear_combination(0.5, p1, 0.5, p2)
      measure = [ w, d, h ][@state - STATE_X]
      if measure > 0

        length_locked = @tool.is_key_shift_down? || @source[:locked_axes][box[:source_indices][@state - STATE_X]] || @source_size_snapped

        @tool.append_2d(_create_floating_label(
                          snap_point: point.transform(t),
                          text: measure,
                          text_color: length_locked ? Kuix::COLOR_WHITE : color,
                          background_color: length_locked ? color : Kuix::COLOR_WHITE,
                          border_color: color
                        ), LAYER_2D_DIMENSIONS)

      end

      Sketchup.set_status_text(box[:sizes][@state - STATE_X].to_l.to_s, SB_VCB_VALUE)

    end

    # The source content at its own sizes, its X edge starting at the mouse
    # point along the active X axis.
    def _preview_source(view)
      return if @mouse_snap_point.nil? || @source.nil?
      box_complete = _get_box(_get_default_x_point(@mouse_snap_point), complete: true, origin: @mouse_snap_point, x_size: @source[:sizes][0])
      _preview_box_complete(view, box_complete) unless box_complete.nil?
    end

    # The source content stretched to the given whole box, its dotted edges
    # and arrows out of its front, top and X+ faces.
    def _preview_box_complete(view, box_complete)

      unit = @tool.get_unit(view)

      if @source[:preview_points].any?
        k_segments = Kuix::Segments.new
        k_segments.add_segments(_get_source_preview_points(box_complete[:content_sizes]))
        k_segments.line_width = 1
        k_segments.color = Kuix::COLOR_DARK_GREY
        k_segments.transformation = box_complete[:content_t] * Geom::Transformation.translation(@source[:origin].vector_to(ORIGIN))
        @tool.append_3d(k_segments, LAYER_3D_BOX_PREVIEW)
      end

      k_segments = Kuix::Segments.new
      k_segments.add_segments(_get_box_segments(*box_complete[:sizes]))
      k_segments.line_width = 1
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      k_segments.color = Kuix::COLOR_DARK_GREY
      k_segments.transformation = box_complete[:t]
      k_segments.on_top = true
      @tool.append_3d(k_segments, LAYER_3D_BOX_PREVIEW)

      # An arrow out of the front face center of the whole box (Y color)
      cw, cd, ch = box_complete[:sizes]
      front_center = Geom::Point3d.new(cw / 2, box_complete[:flipped] ? cd : 0, ch / 2)
      length = view.pixels_to_model(unit * 10, front_center.transform(box_complete[:t]))
      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(front_center)
      k_edge.end.copy!(front_center.offset(Y_AXIS, box_complete[:flipped] ? length : -length))
      k_edge.end_arrow = true
      k_edge.arrow_size = unit * 1.5
      k_edge.line_width = 1.5
      k_edge.color = Kuix::COLOR_Y
      k_edge.transformation = box_complete[:t]
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_BOX_PREVIEW)

      # An arrow out of the content's top face center (Z color) : the box
      # face its top turned to
      top = box_complete[:top]
      top_center = Geom::Point3d.new(cw * (1 + top.x) / 2, cd * (1 + top.y) / 2, ch * (1 + top.z) / 2)
      length = view.pixels_to_model(unit * 10, top_center.transform(box_complete[:t]))
      k_edge = Kuix::EdgeMotif3d.new
      k_edge.start.copy!(top_center)
      k_edge.end.copy!(top_center.offset(top, length))
      k_edge.end_arrow = true
      k_edge.arrow_size = unit * 1.5
      k_edge.line_width = 1.5
      k_edge.color = Kuix::COLOR_Z
      k_edge.transformation = box_complete[:t]
      k_edge.on_top = true
      @tool.append_3d(k_edge, LAYER_3D_BOX_PREVIEW)

    end

    # The current edge as drawn, in the box frame : the X edge along the box
    # min Y and Z, the Y edge from the X end, and the Z edge rising from the
    # corner the Y edge ends on - on the Y face picked, whichever way the frame
    # turned since.
    def _get_current_edge(box)
      w, d, h = box[:sizes]
      case @state
      when STATE_X
        [ ORIGIN, Geom::Point3d.new(w, 0, 0) ]
      when STATE_Y
        [ Geom::Point3d.new(w, 0, 0), Geom::Point3d.new(w, d, 0) ]
      when STATE_Z
        y = @picked_y_point.transform(box[:t].inverse).y < d / 2.0 ? 0 : d
        [ Geom::Point3d.new(w, y, 0), Geom::Point3d.new(w, y, h) ]
      end
    end

    # The edges of a box of the given sizes, in its frame : the X edge alone
    # while it's flat on Y, its bottom rectangle while it's flat on Z.
    def _get_box_segments(w, d, h)
      bottom = [ [ 0, 0, 0 ], [ w, 0, 0 ], [ w, d, 0 ], [ 0, d, 0 ] ].map { |coords| Geom::Point3d.new(coords) }
      return bottom[0..1] unless d > 0
      segments = bottom.zip(bottom.rotate).flatten(1)
      return segments unless h > 0
      top = bottom.map { |point| point.offset(Z_AXIS, h) }
      segments + top.zip(top.rotate).flatten(1) + bottom.zip(top).flatten(1)
    end

    # The source edges stretched to the given sizes, in the source space
    def _get_source_preview_points(sizes)
      offsets = [ X_AXIS, Y_AXIS, Z_AXIS ].each_with_index.map { |axis, index|
        split_def = @source[:split_defs][index]
        coefs = Array.new(split_def.section_defs.length, 0.0)
        distance = sizes[index] - @source[:sizes][index]
        if distance.to_l != 0 && (stretch_def = split_def.stretch_def_by_distance(distance)).is_a?(StretchDef)
          stretch_def.edvs.each { |section_def, edv| coefs[section_def.index] = edv % axis }
        end
        coefs
      }
      ox, oy, oz = offsets
      ix, iy, iz = @source[:preview_section_indices]
      @source[:preview_points].each_with_index.map { |point, index|
        Geom::Point3d.new(point.x + ox[ix[index]], point.y + oy[iy[index]], point.z + oz[iz[index]])
      }
    end

    # -- Read --

    # An absolute [x,y,z] or relative <x,y,z> coordinate, relative to the active axes origin
    def _read_origin(tool, text, view)
      point = _read_user_text_point(tool, text, @mouse_snap_point || ORIGIN)
      return false if point.nil?

      _pick(point)
      _refresh

      true
    end

    # The typed value is the box size : the edge to the dragged face
    def _read_edge(tool, text, view)
      return false if @mouse_snap_point.nil?

      direction, base = _get_edge_direction_and_length(@mouse_snap_point)
      return true if direction.nil?

      length = _read_user_text_length(tool, text, base)
      return true if length.nil?

      measure = _get_anchor_measure(@picked_origin.offset(direction, length), length.abs)
      _pick(@picked_origin.offset(direction, length < 0 ? -measure : measure))
      _refresh

      true
    end

    # -- Pick --

    def _get_previous_input_point
      return Sketchup::InputPoint.new(@picked_origin) unless @picked_origin.nil?
      nil
    end

    # Picks the given point for the current state, or beeps if it doesn't make
    # a valid edge.
    def _pick(point)
      case @state
      when STATE_ORIGIN
        @picked_origin = point
        origin_directions = @mouse_ip.valid? && @mouse_ip.position == point ? _get_origin_directions : []  # Not on the mouse if typed
        @origin_directions = origin_directions.map(&:first)
        @origin_segments = origin_directions.map(&:last)
        set_state(STATE_X)
      when STATE_X
        return UI.beep if _get_edge_direction_and_length(point).first.nil?
        @picked_x_point = point
        set_state(STATE_Y)
      when STATE_Y
        return UI.beep if _get_edge_direction_and_length(point).last == 0
        @picked_y_point = point
        set_state(STATE_Z)
      when STATE_Z
        return UI.beep if (box = _get_box(@picked_x_point, @picked_y_point, point)).nil?
        _create_module(box)
        _reset
      end
    end

    # The directions of the edges the mouse input point touches and of the
    # clines passing through it - read when the origin is picked on it - and
    # their perpendiculars in the horizontal plane (none for a vertical one),
    # each as a [ direction, segment ] pair : the world segment of the edge or
    # cline it comes from, nil for an infinite cline.
    def _get_origin_directions
      return [] unless @mouse_ip.valid?
      edges = []
      if @mouse_ip.vertex
        edges += @mouse_ip.vertex.edges
      elsif @mouse_ip.edge
        edges << @mouse_ip.edge
      end
      pairs = edges.map do |edge|
        manipulator = EdgeManipulator.new(edge, @mouse_ip.transformation)
        [ manipulator.direction, manipulator.segment ]
      end
      pairs += _get_origin_clines.map do |cline, transformation|
        manipulator = ClineManipulator.new(cline, transformation)
        [ manipulator.direction, cline.start.nil? || cline.end.nil? ? nil : manipulator.segment ]
      end
      pairs = pairs.select { |direction, _| direction.valid? }
      z_axis = _get_active_z_axis
      pairs += pairs.map { |direction, segment| [ z_axis * direction, segment ] }.select { |direction, _| direction.valid? }
      pairs.each_with_object([]) { |(direction, segment), uniques| uniques << [ direction.normalize, segment ] unless uniques.any? { |unique, _| unique.parallel?(direction) } }
    end

    # The clines passing through the mouse input point, as [ cline,
    # transformation ] pairs : searched in the context of the entity it is
    # picked on, and in the active context. That entity is read on the input
    # point's path first : on a cline end, snapped by SketchUp itself, the
    # cline is only there - and a face may be reported from another context.
    def _get_origin_clines
      model = Sketchup.active_model
      origin = @mouse_ip.position
      entity = @mouse_ip.instance_path.leaf
      entity = @mouse_ip.vertex || @mouse_ip.edge || @mouse_ip.cline || @mouse_ip.face if entity.nil? || entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      contexts = []
      contexts << [ entity.parent.entities, @mouse_ip.transformation ] unless entity.nil?
      contexts << [ model.active_entities, model.edit_transform ] unless contexts.any? { |entities, _| entities == model.active_entities }
      contexts.flat_map do |entities, transformation|
        entities.grep(Sketchup::ConstructionLine).select do |cline|
          direction = cline.direction.transform(transformation)
          next false unless origin.on_line?([ cline.position.transform(transformation), direction ])
          s = cline.start.nil? ? nil : cline.start.transform(transformation)
          e = cline.end.nil? ? nil : cline.end.transform(transformation)
          next false if !s.nil? && origin != s && (origin - s).dot(direction) < 0  # Before its start
          next false if !e.nil? && origin != e && (e - origin).dot(direction) < 0  # After its end
          true
        end.map { |cline| [ cline, transformation ] }
      end
    end

    # -- Library --

    # Falls back on the library root with no file picked if the browsed folder
    # is gone (or on first use), and on no file picked if the picked file is
    # gone. Otherwise the last pick is kept.
    def _check_library_refs
      dir = @@dir_ref.nil? ? nil : PLUGIN.resolve_library_ref(@@dir_ref)
      unless dir.is_a?(String) && File.directory?(dir)
        @@dir_ref = SmartBuildTool::MODULES_LIBRARY_REF
        @@source_ref = nil
      end
      path = _get_source_path
      @@source_ref = nil unless path.is_a?(String) && File.file?(path)
    end

    # Browses the given folder, with no file picked
    def _browse_library_dir(dir_ref)
      @@dir_ref = dir_ref
      _select_source(nil)
    end

    # Browsing a folder in STATE_ADD stays in it, picking a file leaves it.
    def _select_source(source_ref)
      if @state == STATE_ADD
        return _browse_add_dir if source_ref.nil?
        @add_instance = nil
        @tool.clear_3d(LAYER_3D_BOX_PREVIEW)
        set_state(STATE_SOURCE)
      end
      @@source_ref = source_ref
      @source = _get_source
      if source_ref.nil?
        _setup_library_panel
      else
        _update_library_panel_selection  # Same folder : the panel is kept as is, and so its scroll
      end
      if @source.nil?
        _reset
      else
        set_state(STATE_ORIGIN) if @state == STATE_SOURCE
        _refresh
      end
    end

    # The bottom bar : a row of the sub folders of the browsed folder - led by
    # its parent below the library root - above the buttons of its SKP files.
    def _setup_library_panel

      _save_library_scroll

      @tool.clear_2d(LAYER_2D_LIBRARY)
      @library_file_btns = {}
      @library_add_btn = nil

      # The scroll is kept while the browsed folder is
      scroll = !@@library_scroll.nil? && @@library_scroll[:dir_ref] == @@dir_ref ? @@library_scroll : {}
      @library_dir_ref = @@dir_ref

      unit = @tool.get_unit
      text_size = unit * 3 * @tool.get_text_unit_factor

      root_ref = SmartBuildTool::MODULES_LIBRARY_REF
      dir_refs = PLUGIN.list_library_dirs(@@dir_ref)
      file_refs = PLUGIN.list_library_files(@@dir_ref, '.skp')

      # Both rows share the same columns
      num_dirs = dir_refs.length + 1
      num_cols = [ [ num_dirs, file_refs.length, 5 ].max, 10 ].min

      fn_create_btn = lambda { |text, color, selected, disabled = false, hover_background = true, &block|

        bg_color = color
        bg_active_color = ColorUtils.color_darken(color, 0.1)
        text_color = ColorUtils.color_is_dark?(bg_color) ? Kuix::COLOR_WHITE : Kuix::COLOR_BLACK

        btn = Kuix::Button.new
        btn.min_size.set!(unit * 20, unit * 10)
        btn.set_style_attribute(:background_color, bg_color)
        btn.set_style_attribute(:background_color, bg_active_color, :active)
        btn.set_style_attribute(:background_color, bg_active_color, :hover) if hover_background
        btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND, :selected)
        if block
          block.call(btn)
        else
          btn.append_static_label(text, text_size)
             .set_style_attribute(:color, text_color)
             .set_style_attribute(:color, text_color, :hover)
             .set_style_attribute(:color, Kuix::COLOR_WHITE, :selected)
        end
        btn.selected = selected
        btn.disabled = disabled
        btn
      }

      # Each row overflows its 2 lines of buttons
      dirs_overflow = num_dirs > num_cols * 2
      files_overflow = file_refs.length > num_cols * 2

      # A scroll buttons column on the right of a row : reserved on both rows
      # as soon as one overflows, to keep their columns aligned, with its
      # buttons only on the rows that overflow.
      fn_append_scroll_btns = lambda { |row, scroll_panel, overflow, start_row|

        scroll_btns = Kuix::Panel.new
        scroll_btns.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
        scroll_btns.layout = Kuix::GridLayout.new(1, 2)
        scroll_btns.min_size.set!(unit * 8, 0)
        scroll_btns.visible = dirs_overflow || files_overflow
        row.append(scroll_btns)

          [ [ 'M0,1L1,1L0.5,0L0,1Z', -1 ], [ 'M0,0L1,0L0.5,1L0,0Z', 1 ] ].each do |path, delta|

            btn = Kuix::Button.new
            btn.layout = Kuix::StaticLayout.new
            btn.min_size.set!(unit * 8, unit * 8)
            btn.visible = overflow
            btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_DARK)
            btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_LIGHT, :hover)
            scroll_btns.append(btn)
            delta < 0 ? scroll_panel.bind_scroll_up_btn(btn) : scroll_panel.bind_scroll_down_btn(btn)

              motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(path))
              motif.padding.set_all!(unit * 2)
              motif.min_size.set_all!(unit * 6)
              motif.line_width = unit <= 4 ? 1 : 2
              motif.set_style_attribute(:color, SmartTool::COLOR_BRAND_LIGHT)
              motif.set_style_attribute(:color, SmartTool::COLOR_BRAND_DARK, :hover)
              motif.set_style_attribute(:color, Kuix::COLOR_MEDIUM_GREY, :disabled)
              btn.append(motif)

          end

        scroll_panel.layout.start_row = start_row.to_i
        scroll_panel.scroll(0)  # Clamped, and the buttons enabled accordingly

      }

      panel = Kuix::Panel.new
      panel.layout_data = Kuix::StaticLayoutData.new(0, 1.0, 1.0, -1, Kuix::Anchor.new(Kuix::Anchor::BOTTOM_LEFT))
      panel.layout = Kuix::BorderLayout.new(0, unit)
      panel.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_DARK)
      @tool.append_2d(panel, LAYER_2D_LIBRARY)

      # Folders

      if num_dirs > 0

        dirs_row = Kuix::Panel.new
        dirs_row.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        dirs_row.layout = Kuix::BorderLayout.new
        dirs_row.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
        panel.append(dirs_row)

          dirs_panel = Kuix::ScrollPanel.new(num_cols, [ (num_dirs / num_cols.to_f).ceil, 2 ].min, 1, 1)
          dirs_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
          dirs_row.append(dirs_panel)

            root_btn_text = "#{File.basename(@@dir_ref)}"
            root_btn_disabled = @@dir_ref == root_ref
            parent_ref = File.dirname(@@dir_ref)
            btn = fn_create_btn.call(root_btn_text, SmartTool::COLOR_BRAND_DARK, false, root_btn_disabled, true) { |btn|

              btn.layout = Kuix::BorderLayout.new

              lbl = Kuix::Label.new(root_btn_text.capitalize)
              lbl.text_size = text_size + 1
              lbl.text_bold = true
              lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
              lbl.set_style_attribute(:color, Kuix::COLOR_WHITE)
              btn.append(lbl)

              unless root_btn_disabled
                motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,.917H.5V.083M.25,.333L.5,.083L.75,.333'))
                motif.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
                motif.padding.set_all!(unit * 2)
                motif.min_size.set_all!(unit * 6)
                motif.line_width = unit <= 4 ? 1 : 2
                motif.set_style_attribute(:color, Kuix::COLOR_WHITE)
                btn.append(motif)
              end

            }
            btn.on(:click) { _browse_library_dir(parent_ref) }
            dirs_panel.append(btn)

            dir_refs.each do |dir_ref|
              btn = fn_create_btn.call(File.basename(dir_ref), ColorUtils.color_lighten(SmartTool::COLOR_BRAND_DARK, 0.3), !@@source_ref.nil? && @@source_ref.start_with?("#{dir_ref}/"), false, true)
              btn.on(:click) { _browse_library_dir(dir_ref) }
              dirs_panel.append(btn)
            end

          dirs_explore_btn = Kuix::Button.new
          dirs_explore_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
          dirs_explore_btn.layout = Kuix::StaticLayout.new
          dirs_explore_btn.min_size.set!(unit * 8, unit * 8)
          dirs_explore_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_DARK)
          dirs_explore_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_LIGHT, :hover)
          dirs_explore_btn.on(:click) {
            begin
              PLUGIN.open_dir(PLUGIN.ensure_library_dir(@@dir_ref))  # The browsed folder may not exist yet
            rescue SystemCallError
              UI.beep
            end
          }
          dirs_row.append(dirs_explore_btn)

            dirs_explore_btn_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.875,.417V.208H.5L.375,.083H0V.917H.792L1,.417H.208L0,.917'))
            dirs_explore_btn_motif.padding.set_all!(unit * 2)
            dirs_explore_btn_motif.min_size.set_all!(unit * 6)
            dirs_explore_btn_motif.line_width = unit <= 4 ? 1 : 2
            dirs_explore_btn_motif.set_style_attribute(:color, Kuix::COLOR_LIGHT_GREY)
            dirs_explore_btn_motif.set_style_attribute(:color, SmartTool::COLOR_BRAND_DARK, :hover)
            dirs_explore_btn.append(dirs_explore_btn_motif)

          fn_append_scroll_btns.call(dirs_row, dirs_panel, dirs_overflow, scroll[:dirs])
          @library_dirs_panel = dirs_panel

      end

      # Files

      files_row = Kuix::Panel.new
      files_row.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
      files_row.layout = Kuix::BorderLayout.new
      panel.append(files_row)

        if file_refs.empty?

          lbl = Kuix::Label.new
          lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
          lbl.text = PLUGIN.get_i18n_string('tool.smart_build.warning.no_module_file')
          lbl.text_size = text_size
          lbl.padding.set_all!(unit * 3)
          lbl.set_style_attribute(:color, Kuix::COLOR_WHITE)
          files_row.append(lbl)

        else

          files_panel = Kuix::ScrollPanel.new(num_cols, [ [ (file_refs.length / num_cols.to_f).ceil, 1 ].max, 2 ].min, 1, 1)
          files_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
          files_row.append(files_panel)

            file_refs.each do |file_ref|
              btn = fn_create_btn.call(File.basename(file_ref, '.*'), ColorUtils.color_darken(SmartTool::COLOR_BRAND_LIGHT, 0.1), file_ref == @@source_ref)
              btn.on(:click) { _select_source(file_ref) unless file_ref == @@source_ref }
              files_panel.append(btn)
              @library_file_btns[file_ref] = btn
            end

          fn_append_scroll_btns.call(files_row, files_panel, files_overflow, scroll[:files])
          @library_files_panel = files_panel

        end

        files_add_btn = Kuix::Button.new
        files_add_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
        files_add_btn.layout = Kuix::StaticLayout.new
        files_add_btn.min_size.set!(unit * 8, unit * 8)
        files_add_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_DARK)
        files_add_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND_LIGHT, :hover)
        files_add_btn.set_style_attribute(:background_color, SmartTool::COLOR_BRAND, :selected)
        files_add_btn.selected = @state == STATE_ADD
        files_add_btn.on(:click) { @state == STATE_ADD ? _leave_add_mode : _enter_add_mode }
        files_row.append(files_add_btn)
        @library_add_btn = files_add_btn

          files_add_btn_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.5L0.5,0.5L0.5,0L0.5,0.5L1,0.5L0.5,0.5L0.5,1'))
          files_add_btn_motif.padding.set_all!(unit * 2)
          files_add_btn_motif.min_size.set_all!(unit * 6)
          files_add_btn_motif.line_width = unit <= 4 ? 1 : 2
          files_add_btn_motif.set_style_attribute(:color, SmartTool::COLOR_BRAND_LIGHT)
          files_add_btn_motif.set_style_attribute(:color, SmartTool::COLOR_BRAND_DARK, :hover)
          files_add_btn_motif.set_style_attribute(:color, SmartTool::COLOR_BRAND_DARK, :selected)
          files_add_btn.append(files_add_btn_motif)

    end

    # Read off the panel about to be rebuilt - by this handler or, on a
    # restart, by the one it replaces.
    def _save_library_scroll
      return if @library_dirs_panel.nil? && @library_files_panel.nil?
      @@library_scroll = {
        :dir_ref => @library_dir_ref,
        :dirs => @library_dirs_panel.nil? ? 0 : @library_dirs_panel.layout.start_row,
        :files => @library_files_panel.nil? ? 0 : @library_files_panel.layout.start_row
      }
      @library_dirs_panel = nil
      @library_files_panel = nil
    end

    # Picking a file of the browsed folder only moves the selection : the
    # panel is not rebuilt, which would scroll its rows back to the top.
    def _update_library_panel_selection
      return _setup_library_panel if @library_file_btns.nil?
      @library_file_btns.each { |file_ref, btn| btn.selected = file_ref == @@source_ref }
      @library_add_btn.selected = @state == STATE_ADD unless @library_add_btn.nil?
    end

    # -- Add --

    # The picked file - and any drawing in progress - is dropped.
    def _enter_add_mode
      @@source_ref = nil
      @source = nil
      _reset
      @add_instance = nil
      set_state(STATE_ADD)
      _setup_library_panel  # The add button selected
      _refresh
    end

    # Back to STATE_SOURCE, in the browsed folder.
    def _leave_add_mode
      @add_instance = nil
      @tool.clear_3d(LAYER_3D_BOX_PREVIEW)
      set_state(get_startup_state)
      _setup_library_panel
      _refresh
    end

    def _browse_add_dir
      @@source_ref = nil
      _setup_library_panel
      _refresh
    end

    # The top level instance of the active context under the mouse, framed.
    def _pick_add_instance(x, y, view)

      model = Sketchup.active_model
      ph = view.pick_helper
      ph.do_pick(x, y)
      entity = ph.best_picked
      active_parent = model.active_path.nil? ? model : model.active_path.last.definition
      @add_instance = (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && entity.parent == active_parent ? entity : nil
      _show_add_instance_tooltip
      return if @add_instance.nil?

      kb = Kuix::Bounds3d.new.copy!(@add_instance.definition.bounds).inflate_all!(1)
      t = PathUtils.get_transformation(model.active_path.to_a + [ @add_instance ], IDENTITY)

      k_box = Kuix::BoxCornersMotif3d.new
      k_box.bounds.copy!(kb)
      k_box.corner_size = 20
      k_box.color = Kuix::COLOR_BLUE
      k_box.line_width = 2.0
      k_box.line_stipple = Kuix::LINE_STIPPLE_SOLID
      k_box.transformation = t
      @tool.append_3d(k_box, LAYER_3D_BOX_PREVIEW)

      k_box = Kuix::BoxMotif3d.new
      k_box.bounds.copy!(kb)
      k_box.color = Kuix::COLOR_BLUE
      k_box.line_width = 1.5
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.transformation = t
      @tool.append_3d(k_box, LAYER_3D_BOX_PREVIEW)

      k_axes = Kuix::AxesHelper.new(20)
      k_axes.transformation = t
      @tool.append_3d(k_axes, LAYER_3D_BOX_PREVIEW)

    end

    # The name proposed to save the given instance : the instance name of a
    # group, the definition name of a component.
    def _get_add_instance_name(instance)
      instance.is_a?(Sketchup::Group) && !instance.name.empty? ? instance.name : instance.definition.name
    end

    # The hovered instance's proposed name and definition sizes - what the file
    # will hold - in a tooltip. Rebuilt only once the hovered instance changed.
    def _show_add_instance_tooltip
      return if @add_instance == @add_tooltip_instance
      @add_tooltip_instance = @add_instance
      return @tool.remove_tooltip if @add_instance.nil?
      bounds = @add_instance.definition.bounds
      @tool.show_tooltip([
        "##{_get_add_instance_name(@add_instance)}",
        "#{bounds.width.to_l} x #{bounds.height.to_l} x #{bounds.depth.to_l}"
      ])
    end

    # Saves the hovered instance's definition as a file of the browsed folder,
    # named in an input box - the instance name of a group, the definition
    # name of a component - and back to STATE_SOURCE. A cancelled input box
    # stays in STATE_ADD.
    def _save_add_instance
      instance = @add_instance
      dir = PLUGIN.resolve_library_ref(@@dir_ref)
      return UI.beep unless dir.is_a?(String)

      name = _get_add_instance_name(instance)
      path = nil
      loop do
        input = UI.inputbox([ PLUGIN.get_i18n_string('tool.smart_build.action_0_add_name') ], [ name ], PLUGIN.get_i18n_string('tool.smart_build.action_0_add_title'))
        return unless input.is_a?(Array)
        name = input[0].to_s.strip
        name = File.basename(FilePathUtils.sanitize_file_name("#{name}.skp"), '.skp') unless name.empty?  # Forbidden characters are replaced
        if name.empty? || name.start_with?('.') || name.end_with?('~')  # Hidden and backup files aren't listed
          UI.messagebox(PLUGIN.get_i18n_string('tool.smart_build.error.module_file_invalid_name', { :name => name }))
          next
        end
        path = File.join(dir, "#{name}.skp")
        break unless File.exist?(path)
        break if UI.messagebox(PLUGIN.get_i18n_string('tool.smart_build.action_0_add_overwrite', { :name => name }), MB_YESNO) == IDYES
      end

      # The browsed folder may not exist yet (e.g. the library root on first use)
      begin
        PLUGIN.ensure_library_dir(@@dir_ref)
      rescue SystemCallError
        # save_as fails below and reports it
      end

      if instance.valid? && instance.definition.save_as(path)
        @tool.notify_success(PLUGIN.get_i18n_string('tool.smart_build.success.module_file_saved', { :name => name }))
      else
        @tool.notify_errors([ [ 'tool.smart_build.error.module_file_save_failed', { :name => name } ] ])
      end
      _leave_add_mode

    end

    # -- Source --

    def _get_source_path
      @@source_ref.nil? ? nil : PLUGIN.resolve_library_ref(@@source_ref)
    end

    # The selected source - probed once while its file is unchanged - with its
    # bounds.
    def _get_source
      return nil if @@source_ref.nil?  # No file in the library : the bar says it
      path = _get_source_path
      unless path.is_a?(String) && File.exist?(path)
        @tool.notify_errors([ [ 'tool.smart_build.error.module_file_not_found', { :file => @@source_ref } ] ])
        return nil
      end

      mtime = File.mtime(path)
      probe = @@sources[path]
      probe = _probe_source(path, mtime) if probe.nil? || probe[:mtime] != mtime
      return nil if probe.nil?

      _get_source_with_bounds(probe)
    end

    # Why the source axis the current edge measures - the given box's, the
    # content possibly turned - can't be stretched, in the message panel -
    # hidden on the other states. Shown again only once that axis changed.
    def _show_locked_axis_message(box = nil)
      index = [ STATE_X, STATE_Y, STATE_Z ].index(@state)
      index = box[:source_indices][index] unless index.nil? || box.nil?
      key = [ @state, index, @source.nil? ? nil : @source[:locked_axes] ]
      return if !box.nil? && key == @locked_axis_message_key
      @locked_axis_message_key = key
      if index.nil? || @source.nil? || !@source[:locked_axes][index]
        @tool.hide_message
        return
      end
      axis = %w[X Y Z][index]
      # Manual lock (component behavior) takes precedence over the curve intersection
      warning = @source[:no_scale_axes][index] ? 'module_axis_no_scale' : 'module_axis_curve_intersect'
      @tool.show_message("⚠ #{PLUGIN.get_i18n_string("tool.smart_build.warning.#{warning}", { :axis => axis })}", SmartTool::MESSAGE_TYPE_WARNING)
    end

    # Probes the source file : its cutters, its content bounds (as the stretch
    # measures them), the max compression distance of each axis and the axes
    # it can't be stretched along - forbidden by the component behavior, or
    # a cutter crossing a curve the stretch would deform. The file is loaded
    # in an aborted operation : nothing is left in the model.
    def _probe_source(path, mtime)

      model = Sketchup.active_model
      model.start_operation('OCL Probe Module', true)
      begin

        definition = _load_source_definition(model, path)
        raise "Failed to load #{path}" unless definition.is_a?(Sketchup::ComponentDefinition)

        cutters = _read_cutters(definition)
        no_scale_axes = _read_no_scale_axes(definition)
        instance = model.entities.add_instance(definition, IDENTITY)

        content_bounds = nil
        compression_distances = []
        curve_intersect_axes = []
        split_defs = []
        [ X_AXIS, Y_AXIS, Z_AXIS ].each do |axis|
          split_def = _split(Sketchup::InstancePath.new([ instance ]), IDENTITY, axis, cutters[axis])
          raise "Failed to split #{path}" unless split_def.is_a?(StretchSplitDef)
          content_bounds = split_def.eb
          compression_distances << split_def.max_compression_distance
          curve_intersect_axes << !split_def.sections_valid?
          split_defs << split_def
        end

        probe = @@sources[path] = {
          :mtime => mtime,
          :cutters => cutters,
          :content_bounds => Geom::BoundingBox.new.add(content_bounds.min, content_bounds.max),
          :compression_distances => compression_distances,
          :no_scale_axes => no_scale_axes,
          :curve_intersect_axes => curve_intersect_axes,
          :split_defs => split_defs,
        }.merge(_get_source_preview(split_defs))

      rescue Exception => e
        PLUGIN.dump_exception(e)
        @tool.notify_errors([ [ 'tool.smart_build.error.module_file_invalid', { :file => @@source_ref } ] ])
        probe = nil
      ensure
        model.abort_operation
      end

      probe
    end

    # The probe completed by the module bounds in the source space : the
    # content bounds - as :origin (min corner), :sizes and :min_sizes (sizes minus the max
    # compression distance of each axis), the :locked_axes - kept at their
    # source size - and the :origin_coefs - the [ a, k ] placing the source
    # file origin on each axis from the bounds min for a size S :
    # a + k * (S - source size), the origin moving with its section - the
    # nearest one when out of the content, its gap to the content then kept.
    def _get_source_with_bounds(probe)
      bounds = probe[:content_bounds]
      sizes = [ bounds.width, bounds.height, bounds.depth ]
      origin_coefs = [ X_AXIS, Y_AXIS, Z_AXIS ].each_with_index.map { |axis, index|
        split_def = probe[:split_defs][index]
        xyz = ORIGIN.send(split_def.xyz_method)
        k = 0.0
        distance = [ sizes[index], 1.0 ].max  # The stretch is linear : any distance gives the ratio
        if (stretch_def = split_def.stretch_def_by_distance(distance)).is_a?(StretchDef)
          section_def = split_def.section_defs.min_by { |section_def| [ section_def.min_xyz - xyz, xyz - section_def.max_xyz, 0 ].max }
          stretch_def.edvs.each { |edv_section_def, edv| k = (edv % axis) / distance if edv_section_def == section_def }
        end
        [ -bounds.min.to_a[index], k ]
      }
      probe.merge(
        :origin_coefs => origin_coefs,
        :origin => bounds.min,
        :sizes => sizes,
        :min_sizes => sizes.each_with_index.map { |size, index| [ size - probe[:compression_distances][index], 0 ].max },
        :locked_axes => probe[:no_scale_axes].zip(probe[:curve_intersect_axes]).map { |no_scale, curve_intersect| no_scale || curve_intersect },
      )
    end

    # The edges of the source content - read while it's loaded, the preview
    # outlives it - and the section of each of their ends on each axis :
    # { :preview_points => [ Point3d ] (segment ends), :preview_section_indices
    # => [ [ index ] ] (by axis, by point) }. Soft edges are left out.
    def _get_source_preview(split_defs)

      fn_key = lambda { |edge_def| [ edge_def.edge, edge_def.transformation.to_a.map { |value| value.round(6) } ] }

      # The section indices by axis of each edge end, keyed on the edge and its transformation
      axes_indices = split_defs.map { |split_def|
        split_def.container_defs.flat_map(&:edge_defs).map { |edge_def|
          [ fn_key.call(edge_def), [ edge_def.start_section_def.index, edge_def.end_section_def.index ] ]
        }.to_h
      }

      # The nearest section of a point, for the edges a split left out
      fn_nearest_index = lambda { |split_def, point|
        xyz = point.send(split_def.xyz_method)
        split_def.section_defs.min_by { |section_def| [ section_def.min_xyz - xyz, xyz - section_def.max_xyz, 0 ].max }.index
      }

      points = []
      section_indices = [ [], [], [] ]
      split_defs.first.container_defs.flat_map(&:edge_defs).each do |edge_def|
        edge = edge_def.edge
        next if edge.soft? || edge.hidden?
        key = fn_key.call(edge_def)
        ends = [ edge.start.position.transform(edge_def.transformation), edge.end.position.transform(edge_def.transformation) ]
        points.concat(ends)
        split_defs.each_with_index do |split_def, axis_index|
          indices = axes_indices[axis_index][key] || ends.map { |point| fn_nearest_index.call(split_def, point) }
          section_indices[axis_index].concat(indices)
        end
      end

      {
        :preview_points => points,
        :preview_section_indices => section_indices,
      }
    end

    # Loads the source SKP file in the given model and returns its definition.
    # Must run inside an operation.
    def _load_source_definition(model, path)
      Sketchup.version_number >= 2100000000 ? model.definitions.load(path, allow_newer: true) : model.definitions.load(path)
    end

    # The source definition, followed by the definition of its single top
    # level container when the file holds the module as a group.
    def _get_module_definitions(definition)
      definitions = [ definition ]
      containers = definition.entities.select { |entity| entity.respond_to?(:definition) }
      definitions << containers.first.definition if containers.one? && definition.entities.count { |entity| entity.is_a?(Sketchup::Face) || entity.is_a?(Sketchup::Edge) } == 0
      definitions
    end

    # The 'stretch_cutters' of the module definitions - the first holding
    # them - as { axis => ratios }, 0.5 on a missing axis.
    def _read_cutters(definition)
      data = _get_module_definitions(definition).map { |module_definition| PLUGIN.get_attribute(module_definition, 'stretch_cutters') }.compact.first
      fn_ratios = lambda { |xyz|
        ratios = data.is_a?(Hash) && data[xyz].is_a?(Array) ? data[xyz].map(&:to_f).select { |ratio| ratio > 0 && ratio < 1.0 } : []
        ratios.empty? ? [ 0.5 ] : ratios
      }
      {
        X_AXIS => fn_ratios.call('x'),
        Y_AXIS => fn_ratios.call('y'),
        Z_AXIS => fn_ratios.call('z'),
      }
    end

    # The axes the module definitions' behavior forbids to scale along
    # ('no_scale_mask' bits 0, 1 and 2 : red, green and blue), as booleans.
    def _read_no_scale_axes(definition)
      mask = _get_module_definitions(definition).map { |module_definition| module_definition.behavior.no_scale_mask? }.reduce(0, :|)
      (0..2).map { |bit| mask & (1 << bit) != 0 }
    end

    # -- Create --

    def _create_module(box)
      return UI.beep if box[:sizes].any? { |size| size <= 0 }

      path = _get_source_path

      model = Sketchup.active_model
      model.start_operation('OCL Build Module', true, false, !active?)
      begin

        definition = _load_source_definition(model, path)
        raise "Failed to load #{path}" unless definition.is_a?(Sketchup::ComponentDefinition)

        # Import the content in a new group
        active_path = model.active_path.to_a
        group = ComponentUtils.component_to_group(model.active_entities.add_instance(definition, IDENTITY))

        # The imported containers still share their definitions with the source
        # definition - and SketchUp would reuse them by GUID on the next load of
        # the file : detach them before any deformation, then purge the source.
        _make_unique_containers(group.entities)
        model.definitions.remove(definition) if definition.count_instances == 0 && model.definitions.respond_to?(:remove)  # SU 2018+

        # Put the content bounds min corner on the box min corner
        group.transformation = PathUtils.get_transformation(active_path, IDENTITY).inverse * box[:content_t] * Geom::Transformation.translation(@source[:origin].vector_to(ORIGIN))

        # Stretch it to the box sizes, axis by axis
        [ X_AXIS, Y_AXIS, Z_AXIS ].each_with_index do |axis, index|
          next if @source[:locked_axes][index]  # Kept at the source size

          et = PathUtils.get_transformation(active_path + [ group ], IDENTITY)
          split_def = _split(Sketchup::InstancePath.new(active_path + [ group ]), et, axis, @source[:cutters][axis])
          raise "Failed to split" unless split_def.is_a?(StretchSplitDef) && split_def.sections_valid?

          distance = box[:content_sizes][index] - _get_split_size(split_def)
          next if distance.to_l == 0

          stretch_def = split_def.stretch_def_by_distance(distance)
          raise "Failed to stretch" unless stretch_def.is_a?(StretchDef)

          result_def = CommonStretchApplyWorker.new(
            stretch_def,
            selection_path: active_path,
            selection_instances: [ group ],
            make_unique: true,   # Never propagate to the shared HARDWARE definitions' extern instances
            wrap_operation: false
          ).run
          raise "Failed to stretch : #{result_def.errors}" unless result_def.success?

          group = result_def.selection_instances.first

        end

        # Named after the file, not the loaded definition (suffixed if already in the model)
        group.name = File.basename(path, '.*')

        # Keep the cutters to allow further stretches with SmartReshape
        PLUGIN.set_attribute(group.definition, 'stretch_cutters', {
          'x' => @source[:cutters][X_AXIS],
          'y' => @source[:cutters][Y_AXIS],
          'z' => @source[:cutters][Z_AXIS],
        })

        if active?

          fn_ask_name = lambda {
            unless group.deleted?
              if (data = UI.inputbox([ PLUGIN.get_i18n_string('tab.cutlist.edit_part.name') ], [ group.name ], PLUGIN.get_i18n_string('default.rename')))
                name = data.first
                if name.empty?
                  UI.beep
                else
                  group.name = name
                end
              end
            end
          }

          if _fetch_option_ask_name?
            fn_ask_name.call
          else
            @tool.notify_success(
              PLUGIN.get_i18n_string('tool.smart_build.success.module_created', { :name => group.name }),
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

        # Fire event
        PLUGIN.app_observer.model_observer.onDrawingChange

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
        @tool.notify_errors([ [ 'tool.smart_build.error.module_stretch_failed' ] ])
      end

    end

    # Gives every container of the given entities - recursively - its own
    # definition. Component instances sharing a definition keep sharing the
    # new one ; groups are made unique one by one.
    # HARDWARE components keep their definition, shared with the other
    # modules : the stretch makes unique the ones it deforms.
    def _make_unique_containers(entities, definitions_map = {}, inherited_material = nil)
      entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        material = _get_non_virtual_material(entity) || inherited_material
        if entity.is_a?(Sketchup::Group)
          entity.make_unique
          _make_unique_containers(entity.definition.entities, definitions_map, material)
        elsif !_hardware_component?(entity, inherited_material)
          if (new_definition = definitions_map[entity.definition])
            entity.definition = new_definition
          else
            definition = entity.definition
            definitions_map[definition] = entity.make_unique.definition
            _make_unique_containers(entity.definition.entities, definitions_map, material)
          end
        end
      end
    end

    # -- Utils : axes --

    # The unit direction of the current edge and the signed length of the
    # given point along it : the X direction itself, the part of the point
    # perpendicular to X, the normal to the XY plane.
    def _get_edge_direction_and_length(point)
      v = @picked_origin.vector_to(point)
      case @state
      when STATE_X
        return [ nil, 0 ] unless v.valid?
        return [ v.normalize, v.length ]
      when STATE_Y
        x_axis = _get_x_axis
        v = v - Geom::Vector3d.linear_combination(v % x_axis, x_axis, 0, x_axis)
        return [ _get_default_y_axis(x_axis), 0 ] unless v.valid? && v.length > 0.001
        return [ v.normalize, v.length ]
      when STATE_Z
        n = _get_xy_normal
        return [ n, v % n ]
      end
      [ nil, 0 ]
    end

    # The X edge end at the source size along the active X axis
    def _get_default_x_point(origin)
      origin.offset(_get_active_x_axis.normalize, @source[:sizes][0])
    end

    def _get_x_axis
      @picked_origin.vector_to(@picked_x_point).normalize
    end

    # The Y unit direction as picked : the part of the Y point perpendicular to X
    def _get_y_axis
      x_axis = _get_x_axis
      v = @picked_origin.vector_to(@picked_y_point)
      (v - Geom::Vector3d.linear_combination(v % x_axis, x_axis, 0, x_axis)).normalize
    end

    def _get_xy_normal
      (_get_x_axis * _get_y_axis).normalize
    end

    # The corner the Z edge rises from : the X end, on the Y face picked
    def _get_z_edge_base
      x_axis = _get_x_axis
      v = @picked_origin.vector_to(@picked_y_point)
      @picked_x_point.offset(v - Geom::Vector3d.linear_combination(v % x_axis, x_axis, 0, x_axis))
    end

    # The Y line direction the given XY plane normal (the locked one by
    # default) leaves once X is drawn : perpendicular to both. Only the
    # normal's part perpendicular to X counts, a normal too close to X (under
    # 10 degrees) giving nil. Its side is the mouse's.
    def _get_locked_y_axis(normal = @locked_xy_normal, x_axis = nil)
      return nil unless normal.is_a?(Geom::Vector3d) && normal.valid?
      y_axis = normal * (x_axis || _get_x_axis)
      return nil if y_axis.length.to_f < LOCKED_XY_NORMAL_MIN_SINE
      y_axis.normalize
    end

    # The Y unit direction while Y isn't drawn : the one the locked XY plane
    # normal leaves, else the active horizontal direction perpendicular to X -
    # making XY the active horizontal plane if X is horizontal. X being
    # vertical : the one facing the camera.
    def _get_default_y_axis(x_axis)
      y_axis = _get_locked_y_axis(@locked_xy_normal, x_axis)
      return y_axis unless y_axis.nil?
      y_axis = _get_active_z_axis * x_axis
      y_axis = x_axis * Sketchup.active_model.active_view.camera.direction unless y_axis.valid?
      y_axis = x_axis.axes[1] unless y_axis.valid?
      y_axis.normalize
    end

    # -- Utils : box / anchor --

    # The box drawn so far, sizes raised to the source minimal sizes : its
    # frame (origin on the box min corner) and its sizes along the frame axes.
    # 'px', 'py' and 'pz' are the X, Y and Z edge points ('py' and 'pz'
    # optional) : the distance from the origin to the dragged face, whose
    # position depends on the anchor of the axis (see _get_anchor_modes).
    # 'complete' gives the source sizes to the edges not drawn yet, 'x_size'
    # overrides the X size (then anchored as an edge not drawn). 'origin'
    # overrides the picked origin.
    # The content is set in the box by ':content_t' : its front (-Y) on a box
    # Y side - the one facing the camera, see _is_front_on_y_max? - and its top
    # (+Z) on a box Z side, or X side if turned a quarter around its front
    # axis to face upward (see _get_top_axis), then turned upside down if the
    # user asked so. ':top' is the frame axis its top follows,
    # ':source_indices' the source axis index along each frame axis,
    # ':content_sizes' the box sizes along the source axes.
    # ':measures' are the signed edge measures along the frame axes (nil if
    # not drawn), ':origin_coefs' the [ o0, o1 ] giving the source file origin
    # on each frame axis from the box min for a box size S : o0 + o1 * S,
    # ':anchor_modes' the anchor of each frame axis.
    def _get_box(px, py = nil, pz = nil, complete: false, origin: @picked_origin, x_size: nil)
      return nil if origin.nil? || px.nil? || @source.nil?

      vx = origin.vector_to(px)
      return nil unless vx.valid?
      x_axis = vx.normalize

      measures = [ x_size.nil? ? vx.length : nil, nil, nil ]

      # The part of the Y point perpendicular to X, nil while there is none
      unless py.nil?
        vy = origin.vector_to(py)
        vy = vy - Geom::Vector3d.linear_combination(vy % x_axis, x_axis, 0, x_axis)
        vy = nil unless vy.valid? && vy.length > 0.001
      end

      # Y not drawn yet : the default Y direction. Drawn : Z normal to the XY
      # plane, its side set below.
      if vy.nil?
        y_axis = _get_default_y_axis(x_axis)
        z_axis = x_axis * y_axis
      else
        z_axis = (x_axis * vy).normalize
      end

      # The content's top axis - its side doesn't matter to the frame one -
      # gives the source axis along each frame axis, and so their anchors
      top_on_x = _get_top_axis(x_axis, z_axis).x != 0
      source_indices = top_on_x ? [ 2, 1, 0 ] : [ 0, 1, 2 ]
      source_anchor_modes = _get_anchor_modes
      anchor_modes = source_indices.map { |source_index| source_anchor_modes[source_index] }

      unless vy.nil?

        # Z upward while not drawn - the frame then matches the whole box one.
        # Drawn : on the side of the Z point anchored on an edge, else kept
        # upward - the anchor holding the box, the Z point giving its face.
        # Y deduced to keep the frame right-handed.
        z_axis = z_axis.reverse if (pz.nil? || anchor_modes[2] != :edge) && z_axis % _get_active_z_axis < 0
        unless pz.nil?
          dz = origin.vector_to(pz) % z_axis
          if anchor_modes[2] == :edge
            z_axis = z_axis.reverse if dz < 0
            dz = dz.abs
          end
          measures[2] = dz
        end
        y_axis = z_axis * x_axis

        measures[1] = vy % y_axis

      end

      # Raised to the minimal size, or set to the source size on a locked axis
      fn_clamp = lambda { |value, index|
        source_index = source_indices[index]
        @source[:locked_axes][source_index] ? @source[:sizes][source_index] : [ value, @source[:min_sizes][source_index] ].max
      }

      # The front side from the box anchored on its edges - the anchor then
      # slides it a little, not enough to turn it
      edge_sizes = measures.each_with_index.map { |measure, index|
        next fn_clamp.call(measure.abs, index) unless measure.nil?
        next x_size if index == 0
        complete ? @source[:sizes][source_indices[index]] : 0
      }
      edge_t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis) * Geom::Transformation.translation(Geom::Vector3d.new(0, measures[1].to_f < 0 ? -edge_sizes[1] : 0, 0))
      flipped = _is_front_on_y_max?(edge_t, edge_sizes, measures[1].to_f >= 0) != @front_flipped

      # The source axes in the frame : Y backward if flipped (the front on the
      # box max Y side), Z on the top axis - reversed if upside down - and X
      # keeping them right-handed
      top = _get_top_axis(x_axis, z_axis)
      top = top.reverse if @up_flipped
      content_axes = [ nil, flipped ? Y_AXIS.reverse : Y_AXIS.clone, top ]
      content_axes[0] = content_axes[1] * content_axes[2]

      # The source file origin on each frame axis : the source axis running
      # backward along it or not
      reversed = source_indices.each_with_index.map { |source_index, index| content_axes[source_index].to_a[index] < 0 }
      origin_coefs = source_indices.each_with_index.map { |source_index, index|
        a, k = @source[:origin_coefs][source_index]
        c0 = a - k * @source[:sizes][source_index]  # c(S) = c0 + k * S, from the content min
        reversed[index] ? [ -c0, 1 - k ] : [ c0, k ]
      }

      # The size of each axis and its min from the origin. An axis not drawn
      # yet - flat while not complete - lies on the whole box min face.
      sizes = []
      mins = []
      measures.each_with_index do |measure, index|
        o0, o1 = origin_coefs[index]
        if measure.nil?
          size = edge_sizes[index]
          complete_size = index == 0 ? size : @source[:sizes][source_indices[index]]
          min = case anchor_modes[index]
                when :center then -complete_size / 2.0
                when :origin then -(o0 + o1 * complete_size)
                else 0
                end
        else
          case anchor_modes[index]
          when :center
            size = fn_clamp.call(2 * measure.abs, index)
            min = -size / 2.0
          when :origin
            if (g = _get_anchor_face_coefs(o0, o1, measure < 0)).nil?
              # That face bound to the origin : the box between the origin and the mouse
              size = fn_clamp.call(measure.abs, index)
              min = measure < 0 ? -size : 0
            else
              # The dragged face at the measure : g0 + g1 * S = |measure|
              g0, g1 = g
              size = fn_clamp.call((measure.abs - g0) / g1, index)
              min = -(o0 + o1 * size)
            end
          else
            size = fn_clamp.call(measure.abs, index)
            min = measure < 0 ? -size : 0
          end
        end
        sizes << size
        mins << min
      end

      # The content min corner on the box max side of each frame axis a source
      # axis runs backward along
      t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis) * Geom::Transformation.translation(Geom::Vector3d.new(*mins))
      content_t = t * Geom::Transformation.translation(Geom::Vector3d.new(*sizes.each_with_index.map { |size, index| reversed[index] ? size : 0 })) * Geom::Transformation.axes(ORIGIN, *content_axes)
      {
        :t => t,
        :sizes => sizes,
        :content_sizes => (0..2).map { |source_index| sizes[source_indices.index(source_index)] },
        :source_indices => source_indices,
        :flipped => flipped,
        :top => top,
        :content_t => content_t,
        :measures => measures,
        :origin_coefs => origin_coefs,
        :anchor_modes => anchor_modes
      }
    end

    # The frame axis the content's top follows - before any upside down turn -
    # given the frame X and Z axes (unit vectors) : Z while the 'top up'
    # option is off. On, the one of X and Z the most vertical - on its upward
    # side - if it is also more vertical than Y, the content then turned a
    # quarter around its front axis for X. Y the most vertical - the front
    # axis, which the content doesn't turn around - leaves it on Z.
    def _get_top_axis(x_axis, z_axis)
      return Z_AXIS.clone unless _fetch_option_top_up?
      up = _get_active_z_axis.normalize
      y_axis = z_axis * x_axis
      dx, dy, dz = [ x_axis, y_axis, z_axis ].map { |axis| axis % up }
      if dx.abs > dz.abs
        return Z_AXIS.clone if dy.abs >= dx.abs
        dx < 0 ? X_AXIS.reverse : X_AXIS.clone
      else
        return Z_AXIS.clone if dy.abs >= dz.abs
        dz < 0 ? Z_AXIS.reverse : Z_AXIS.clone
      end
    end

    # Whether the box front is its max Y side : the Y side facing the camera
    # the most - with the 'face camera' option on. Seen from above (no side
    # clearly facing it), or with the option off, the one away from the X edge
    # - 'x_edge_on_y_min' - as the X edge is drawn along the back.
    def _is_front_on_y_max?(t, sizes, x_edge_on_y_min)
      return x_edge_on_y_min unless _fetch_option_face_camera?
      camera = Sketchup.active_model.active_view.camera
      v = camera.perspective? ? Geom::Point3d.new(sizes[0] / 2, sizes[1] / 2, sizes[2] / 2).transform(t).vector_to(camera.eye) : camera.direction.reverse
      return x_edge_on_y_min unless v.valid?
      cos = t.yaxis.normalize % v.normalize
      return x_edge_on_y_min if cos.abs < 0.15
      cos > 0
    end

    # The anchor of each source axis : :edge (the origin on its min or max
    # face), :center or :origin (the source file origin). The box reads them
    # along its frame axes (see _get_box).
    def _get_anchor_modes
      return [ :origin ] * 3 if @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_ANCHOR, SmartBuildTool::ACTION_OPTION_ANCHOR_ORIGIN)
      [ SmartBuildTool::ACTION_OPTION_ANCHOR_CENTER_X, SmartBuildTool::ACTION_OPTION_ANCHOR_CENTER_Y, SmartBuildTool::ACTION_OPTION_ANCHOR_CENTER_Z ].map { |option|
        @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_ANCHOR, option) ? :center : :edge
      }
    end

    # The edge points drawn so far, the given one on the current state
    def _get_state_points(point)
      case @state
      when STATE_X
        [ point ]
      when STATE_Y
        [ @picked_x_point, point ]
      when STATE_Z
        [ @picked_x_point, @picked_y_point, point ]
      end
    end

    # The source axis index the current edge measures, the given point on it :
    # the content may be turned in the box (see _get_box).
    def _get_current_source_index(point)
      index = @state - STATE_X
      return index if (points = _get_state_points(point)).nil? || (box = _get_box(*points)).nil?
      box[:source_indices][index]
    end

    # The distance from the origin to the dragged face - the current edge
    # measure - making a box of the given size along the current axis, the
    # given point giving the side.
    def _get_anchor_measure(point, size)
      index = @state - STATE_X
      return size if (points = _get_state_points(point)).nil? || (box = _get_box(*points)).nil?
      case box[:anchor_modes][index]
      when :center
        size / 2.0
      when :origin
        return size if (g = _get_anchor_face_coefs(*box[:origin_coefs][index], box[:measures][index].to_f < 0)).nil?  # Nil measure : Y point still on the X line
        g0, g1 = g
        g0 + g1 * size
      else
        size
      end
    end

    # The distance from the source file origin - at o0 + o1 * S from the box
    # min - to the face the mouse drags for a box size S : [ g0, g1 ] giving
    # g0 + g1 * S. The max face, the min one if 'negative'. Nil if that face is
    # bound to the origin (its section moving with it) : the mouse can't drag
    # it, the box then goes between the origin and the mouse.
    def _get_anchor_face_coefs(o0, o1, negative)
      g = negative ? [ o0, o1 ] : [ -o0, 1 - o1 ]
      g.last.abs > 1e-6 ? g : nil
    end

    # -- Utils : stretch --

    def _split(ipath, et, axis, ratios)
      CommonStretchSplitWorker.new(
        [ ipath ],
        et: et,
        axis: axis,
        grip_index: Kuix::Bounds3d.faces_by_axis(axis).last,  # Pull the max face : the min corner stays in place
        ratios: ratios
      ).run
    end

    # The content size along the split axis, in the split edit space
    def _get_split_size(split_def)
      eb = split_def.eb
      [ eb.width, eb.height, eb.depth ][[ X_AXIS, Y_AXIS, Z_AXIS ].index(split_def.axis)]
    end

    # -- Utils : materials --

    # Whether the cutlist sees the given component instance as a HARDWARE
    # part : its material resolved as CutlistGenerateWorker#_get_material does
    # - its own, else the dominant one of its children, else the inherited one.
    def _hardware_component?(instance, inherited_material)
      material = _get_non_virtual_material(instance) || _get_dominant_child_material(instance) || inherited_material
      _get_material_attributes(material).type == MaterialAttributes::TYPE_HARDWARE
    end

    # See CutlistGenerateWorker#_get_dominant_child_material
    def _get_dominant_child_material(entity, level = 0)
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) && (level == 0 || entity.definition.behavior.cuts_opening?)
        counts = Hash.new(0)
        entity.definition.entities.each do |child_entity|
          child_material = _get_dominant_child_material(child_entity, level + 1)
          counts[child_material] += 1 unless child_material.nil?
        end
        return counts.min_by { |material, count| [ -count, MaterialAttributes.type_order(_get_material_attributes(material).type) ] }.first if counts.any?
        return _get_non_virtual_material(entity) if level > 0
      elsif entity.is_a?(Sketchup::Face)
        return _get_non_virtual_material(entity)
      end
      nil
    end

    def _get_non_virtual_material(entity)
      entity.material unless MaterialAttributes.is_virtual?(_get_material_attributes(entity.material))
    end

    # -- Options --

    def _fetch_option_face_camera?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_FACE_CAMERA)
    end

    def _fetch_option_top_up?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_TOP_UP)
    end

  end

  # Base of the action handlers that draw a panel INSIDE an existing
  # enclosure - a divider fitted to a compartment, a front panel fitted to its
  # opening. What they share is the CAVITIES of the container the pick lands
  # in : one boolean pass, cached on that container, that all of them read.
  class SmartBuildPanelActionHandler < SmartBuildActionHandler

    include SmartActionHandlerPartHelper

    LAYER_3D_CAVITY_PREVIEW = 100

    # How many containers #_get_cavities_def keeps the cavities of at once.
    CAVITIES_CACHE_SIZE = 16

    # How long, in seconds, the pick has to stay on a container whose cavities
    # are not known yet before they are detected - see #_schedule_cavities_def.
    CAVITIES_DWELL_DELAY = 0.15

    # How long, in seconds, the detection may run before it gives up (see
    # CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX) and the container is
    # refused. Measured 2026-09-14 with the envelope reduced : a machined open
    # carcass takes ~3 s, an assembly of sculpted CNC slices ~7.5 s.
    CAVITIES_TIME_BUDGET = 3.0

    def initialize(action, tool, previous_action_handler = nil)
      super
    end

    def stop
      _cancel_cavities_dwell
      super
    end

    # -----

    # A pick on the move only designates containers in passing : the cavities
    # of one not known yet are not detected under it, but once it has dwelt
    # there - see #_get_cavities_def. Anything else (a click, a key, a panel
    # being built) still gets them on the spot.
    def onToolMouseMove(tool, flags, x, y, view)
      deferring = @cavities_deferring
      @cavities_deferring = true
      super
    ensure
      @cavities_deferring = deferring
    end

    # -----

    protected

    def _reset
      _reset_cavities_def
      super
    end

    # Drops the cavities of EVERY container kept, not only the active one's :
    # what changes the model under one container may change it under the
    # others - its ancestors hold it.
    #
    # All but the verdicts of excess complexity (see
    # CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX) : nothing this handler
    # does can simplify a container it refuses to work in, and forgetting them
    # would pay for the detection again at the very next pass over it.
    def _reset_cavities_def
      @cavities_defs = @cavities_defs.is_a?(Array) ? @cavities_defs.select(&:too_complex?) : nil
      _reset_picked_cavity
    end

    # What a pick resolved to in the cavities, for the handlers that read it
    # there (see SmartBuildDividerActionHandler#_snap_point) : dropped with the
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
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_AXES, SmartBuildTool::ACTION_OPTION_AXES_CONTEXT)
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

    # Which kinds of APPLIED PANEL already drawn (see LayerAttributes::
    # TYPES_PANEL) make the openings they fill recede - see
    # CommonSolidFindCavitiesWorker, INSET FRONT PANELS. None here : a handler
    # that fits a panel ONTO an opening has to read that opening as the
    # carcass leaves it, or it would lay its front panel against the back of
    # the one already there. A handler that fits a panel INTO a compartment
    # must name them, on pain of telescoping into an inset panel.
    def _cavities_recess_panel_types
      []
    end

    # Which kinds of APPLIED PANEL already drawn are read aside as the panels
    # STANDING IN THE WAY - handed to nobody, kept on the CavitiesDef so that a
    # handler can tell an opening it has already filled from a bare one. None
    # here : a handler that draws no panel has none of its own to run into.
    #
    # Deliberately NOT the same list as #_cavities_recess_panel_types, and
    # never overlapping it : a panel that recedes an opening is one the cavity
    # STOPS at, a panel read aside here is one the cavity is blind to - which
    # is precisely why it has to be looked for by hand.
    def _cavities_own_panel_types
      []
    end

    # How many opening planes a cavity may have and still be a compartment -
    # see CommonSolidFindCavitiesWorker, max_opening_planes. Generous here : a
    # part fitted INTO a compartment is at home in one open on every side it
    # does not lean on.
    def _cavities_max_opening_planes
      4
    end

    # Whether the openings of a cavity must turn their backs on one another
    # for it to be a compartment - see CommonSolidFindCavitiesWorker,
    # apart_opening_planes. Off here, for the same reason as above.
    def _cavities_apart_opening_planes?
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

    # The pick, read on the CAVITIES themselves rather than on the model : the
    # ray under the cursor is cast at the compartments, and the compartment it
    # enters through a mouth, the point where it first meets a wall of it, and
    # that wall are kept in @picked_fragment_def, @picked_point and
    # @picked_plane_manipulator (see CavitiesDef#pick_ray) ; true when it
    # really lands in one.
    #
    # What stands in a mouth stands between the cursor and the compartment : a
    # front panel, a drawer front, a plinth, the neighbouring carcass. Reading
    # the pick off the model makes every one of them opaque - the picker hands
    # back the face in FRONT, a point that lies in no cavity - and the only way
    # through is to hide them. The cavities, themselves, are not hidden by what
    # fills their mouth : the mouths are their own geometry.
    #
    # What #_snap_point does and this one does not : SketchUp's inference
    # (endpoints, midpoints, edges) no longer takes part, the point being read
    # off the cavity wall alone.
    def _snap_point_through_cavities(picker)

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

    # The paths of the APPLIED PANELS the given container holds - a front
    # panel or a back, see LayerAttributes::TYPES_PANEL - of the given TYPES,
    # at any depth and WHATEVER its visibility.
    #
    # A panel of a type NOT asked for is skipped, never descended into : it is
    # read whole or not at all, exactly like one that is kept.
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
    def _fetch_applied_panel_entity_paths(container, container_path, types, applied_panel_entity_paths = [])
      return applied_panel_entity_paths unless container.respond_to?(:definition)
      container.definition.entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        next if entity.definition.behavior.always_face_camera?
        entity_path = container_path + [ entity ]
        type = LayerAttributes.type_of(entity)
        if LayerAttributes.panel_type?(type)
          applied_panel_entity_paths << entity_path if types.include?(type)   # An applied panel is read WHOLE : what it holds is its own business, and a panel inside a panel is none
        else
          _fetch_applied_panel_entity_paths(entity, entity_path, types, applied_panel_entity_paths)
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
      #
      # Several containers are kept, most recently used first : a pick that
      # slides from a carcass onto the drawers it holds and back would
      # otherwise pay again, at every crossing, for a detection the previous
      # crossing had already paid for - and the carcass is the dearest of them.
      @cavities_defs = [] unless @cavities_defs.is_a?(Array)
      options_key = _cavities_options_key
      if (index = @cavities_defs.index { |cavities_def| cavities_def.container_path == container_path && cavities_def.options_key == options_key })
        @cavities_defs.unshift(@cavities_defs.delete_at(index)) if index > 0
        return @cavities_defs.first
      end

      return nil if !part.is_a?(Part) || part.group.material_is_virtual || part.group.material_type == MaterialAttributes::TYPE_HARDWARE

      # Not known yet, and the pick merely passing over it : detected once it
      # has dwelt there (see #onToolMouseMove) - PENDING until then, see
      # #_cavities_pending?.
      if @cavities_deferring
        _schedule_cavities_def(container_path)
        return nil
      end
      _cancel_cavities_dwell if _cavities_pending?(part_entity_path)

      cutlist = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_options'))
                                                     .merge({ active_entity: container, active_path: container_path[0...-1] })
      ).run

      parts = cutlist.groups
                     .reject { |group| group.material_is_virtual || group.material_type == MaterialAttributes::TYPE_HARDWARE}
                     .flat_map { |group| group.get_parts }

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

      drawing_defs = panel_instance_infos.map { |instance_info| _decompose_cavity_panel(instance_info.path, false) }
      # An applied panel is read whole and blind to what the model shows : the tag it
      # is marked with is the tag its own faces are likely to carry, and hidden
      # once it is the mesh that would come back empty.
      #
      # The SAME walk serves the two readings an applied panel gets - the ones
      # that make an opening recede, and the ones read aside as standing in the
      # way (see #_cavities_own_panel_types) - and a panel of neither kind is
      # not decomposed at all, so a handler that asks for nothing pays nothing.
      recess_panel_types = _cavities_recess_panel_types
      own_panel_types = _cavities_own_panel_types
      front_panel_drawing_defs = []
      own_panel_drawing_defs = []
      unless recess_panel_types.empty? && own_panel_types.empty?
        _fetch_applied_panel_entity_paths(container, container_path, recess_panel_types + own_panel_types).each do |entity_path|
          type = LayerAttributes.type_of(entity_path.last)
          drawing_def = _decompose_cavity_panel(entity_path, true)
          front_panel_drawing_defs << drawing_def if recess_panel_types.include?(type)
          own_panel_drawing_defs << drawing_def if own_panel_types.include?(type)
        end
      end

      result_def = CommonSolidFindCavitiesWorker.new(drawing_defs,
                                                     max_opening_planes: _cavities_max_opening_planes,
                                                     apart_opening_planes: _cavities_apart_opening_planes?,
                                                     reduce_envelope: _cavities_reduce_envelope?,
                                                     overall_cavity: _cavities_overall?,
                                                     ignore_applied_panels: _cavities_ignore_applied_panels?,
                                                     front_panel_drawing_defs: front_panel_drawing_defs,
                                                     time_budget: CAVITIES_TIME_BUDGET
      ).run

      cavities_def = CavitiesDef.new(container_path, result_def, drawing_defs, own_panel_drawing_defs, options_key, front_panel_drawing_defs)
      @cavities_defs.unshift(cavities_def)
      @cavities_defs.pop while @cavities_defs.length > CAVITIES_CACHE_SIZE

      # A refusal for excess complexity is said where the pick is, see #_can_activate_part?
      unless result_def.success? || cavities_def.too_complex?
        @tool.notify_errors(result_def.errors)
      end

      cavities_def
    end

    # One panel of a container, the way #_get_cavities_def reads it.
    #
    # The glued cuts-opening machinings stay IN : SketchUp punches their
    # opening in the host face tessellation, so a drilled panel without them
    # is an open shell (one open edge loop per mortise) that no boolean can
    # take. They are what closes it back — SolidMeshDef marks them virtual,
    # and CommonSolidFindCavitiesWorker drops the voids they enclose. Hence
    # flatten: false, without which they land in the drawing def's own faces
    # and lose that provenance.
    def _decompose_cavity_panel(entity_path, ignore_visibility)
      CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(entity_path) ],
                                           ignore_surfaces: true,
                                           ignore_edges: true,
                                           container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS,
                                           ignore_visibility: ignore_visibility,
                                           flatten: false
      ).run
    end

    # Reads again, for every container kept, the applied panels of the
    # handler's OWN kinds (see #_cavities_own_panel_types) - and only them.
    #
    # What a handler that has just built such a panel calls : the cavities
    # themselves are blind to it and stand as they were, but the panels read
    # aside are precisely the ones that tell an opening it has just closed from
    # a bare one. Every container kept is read, the one the panel went into as
    # much as its ancestors - they hold it too.
    def _refresh_cavities_own_panels
      return unless @cavities_defs.is_a?(Array)
      own_panel_types = _cavities_own_panel_types
      return if own_panel_types.empty?
      @cavities_defs.each do |cavities_def|
        next unless cavities_def.valid?
        container_path = cavities_def.container_path
        cavities_def.own_panel_drawing_defs = _fetch_applied_panel_entity_paths(container_path.last, container_path, own_panel_types).map { |entity_path| _decompose_cavity_panel(entity_path, true) }
      end
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

    # What the cavities of a container depend on besides the container itself :
    # the way this handler reads it. See #_get_cavities_def.
    def _cavities_options_key
      [ _cavities_reduce_envelope?, _cavities_overall?, _cavities_ignore_applied_panels?, _cavities_recess_panel_types, _cavities_own_panel_types, _cavities_max_opening_planes, _cavities_apart_opening_planes? ]
    end

    # Whether the cavities of the given part's container - by default the
    # active part's - are PENDING : not known yet, and waiting for the pick to
    # dwell there (see #_schedule_cavities_def). Nothing can be said of a
    # position in them in the meantime, either way.
    def _cavities_pending?(part_entity_path = get_active_part_entity_path)
      !@cavities_dwell.nil? && part_entity_path.is_a?(Array) && @cavities_dwell.first == part_entity_path[0...-1]
    end

    # Arms the detection of the given container's cavities, to run once the
    # pick has stayed on it CAVITIES_DWELL_DELAY. A pick still on the same
    # container leaves the count running : moving over its panels is dwelling
    # on it all the same.
    def _schedule_cavities_def(container_path)
      return if !@cavities_dwell.nil? && @cavities_dwell.first == container_path
      _cancel_cavities_dwell
      timer_id = UI.start_timer(CAVITIES_DWELL_DELAY, false) { _on_cavities_dwell(timer_id) }
      @cavities_dwell = [ container_path, timer_id ]
    end

    def _cancel_cavities_dwell
      return if @cavities_dwell.nil?
      UI.stop_timer(@cavities_dwell.last)
      @cavities_dwell = nil
    end

    def _on_cavities_dwell(timer_id)
      return if @cavities_dwell.nil? || @cavities_dwell.last != timer_id  # Called off, or superseded
      container_path = @cavities_dwell.first
      @cavities_dwell = nil
      return unless active?

      # Only for the container the pick is still on : it may have left it for
      # nothing since, which armed no other count
      part_entity_path = get_active_part_entity_path
      return unless part_entity_path.is_a?(Array) && part_entity_path[0...-1] == container_path

      model = Sketchup.active_model
      return if model.nil?

      # The detection freezes the view : the message is painted first
      # (View#refresh, SketchUp 2020+)
      @tool.show_tooltip(PLUGIN.get_i18n_string('tool.smart_build.detecting_cavities'))
      model.active_view.refresh if model.active_view.respond_to?(:refresh)

      _get_cavities_def(part_entity_path, get_active_part)
      @tool.remove_tooltip
      _refresh
    end

    # Detects at once the cavities the pick is dwelling on, if it is : what a
    # click on a container still waiting for them asks for. Returns whether it
    # did - the click then stands for that, and for nothing more.
    def _flush_cavities_dwell
      return false unless _cavities_pending?
      _cancel_cavities_dwell
      _get_cavities_def
      _refresh
      true
    end

    # -----

    # +own_panel_drawing_defs+ : the APPLIED PANELS the cavities were read
    # BLIND to - see #_cavities_own_panel_types. Nothing in the fragments says
    # they are there, which is exactly what they are kept here for.
    #
    # +options_key+ : the reading they were detected with, see
    # SmartBuildPanelActionHandler#_cavities_options_key.
    #
    # +recess_panel_drawing_defs+ : the APPLIED PANELS the openings were made
    # to RECEDE behind - see #_cavities_recess_panel_types. The wall a recess
    # leaves is a cap like any opening, and they are what stands behind it.
    CavitiesDef = Struct.new(:container_path, :result_def, :drawing_defs, :own_panel_drawing_defs, :options_key, :recess_panel_drawing_defs) do
      def valid?
        result_def.is_a?(SolidBooleanResultDef) && result_def.success?
      end
      # Whether the detection gave up on the container for excess complexity -
      # see CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX.
      def too_complex?
        result_def.is_a?(SolidBooleanResultDef) && result_def.errors.any? { |key, _vars| key == CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX }
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
          #
          # A cap PAST the mouth is no wall either, unless an applied panel
          # stands behind it : an opening receded to the back of the panel
          # fitted in it is closed by that panel, and aiming at it through the
          # front is aiming at a wall of the compartment.
          point = nil
          plane_manipulator = nil
          hits.each_with_index do |(_distance, hit_point, triangle_index), hit_index|
            if fragment_def.triangle_face_id(triangle_index).to_i == 0
              next if hit_index == 0   # The mouth the ray came in by, or the eye inside : the wall behind the eye
              plane_manipulator = _recess_plane_manipulator(fragment_def, triangle_index, hit_point)
            else
              plane_manipulator = _wall_plane_manipulator(fragment_def, triangle_index, hit_point)
            end
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

      # The wall a ray hit on a RECESSED opening, read as #_wall_plane_manipulator
      # reads a panel's : carried by the transformation of the recess panel the
      # hit point lies on - the cap stands against its back. nil when none
      # does : the cap is a real opening.
      def _recess_plane_manipulator(fragment_def, triangle_index, point)
        return nil unless recess_panel_drawing_defs.is_a?(Array)
        normal = fragment_def.triangle_normal(triangle_index)
        return nil if normal.nil?
        margin = SolidMeshDef::TOLERANCE * 10
        recess_panel_drawing_defs.each do |drawing_def|
          next unless drawing_def.is_a?(DrawingDef) && (transformation = drawing_def.transformation).is_a?(Geom::Transformation)
          bounds = drawing_def.bounds
          next if bounds.empty?
          ti = transformation.inverse
          local_point = point.transform(ti)
          next unless (0..2).all? { |axis| local_point[axis] >= bounds.min[axis] - margin && local_point[axis] <= bounds.max[axis] + margin }
          return PlaneManipulator.new([ local_point, normal.transform(ti) ], transformation)
        end
        nil
      end

    end

  end

  class SmartBuildDividerActionHandler < SmartBuildPanelActionHandler

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
      super(SmartBuildTool::ACTION_BUILD_DIVIDER, tool, previous_action_handler)

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
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_build.action_option_options_measure_reversed_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_build.action_option_options_reduce_envelope_status') + '.'
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

      return true if _flush_cavities_dwell

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

      case @state

      when STATE_PLACE, STATE_DISTRIBUTE

        if tool.is_key_shift_down? && !tool.is_vcb_typing?
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
          @tool.store_action_option_value(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED, !_fetch_option_measure_reversed?, fire_event: true)
          return true
        end
        if tool.is_key_alt_or_command?(key) && is_quick
          @tool.store_action_option_value(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, !_fetch_option_reduce_envelope?, fire_event: true)
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
          if _snap_point(picker) || _cavities_pending?  # Pending : nothing to say of this position yet, either way
            @tool.remove_tooltip
            @tool.pop_cursor(SmartCursorManager.cursor_select_error)
          else
            @tool.show_tooltip(PLUGIN.get_i18n_string('tool.smart_build.error.invalid_divider_cavity'), SmartTool::MESSAGE_TYPE_ERROR)
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
      when SmartBuildTool::ACTION_OPTION_MEASURE_TYPE
        _refresh
      when SmartBuildTool::ACTION_OPTION_AXES
        @locked_normal = nil
        _refresh
      when SmartBuildTool::ACTION_OPTION_OPTIONS
        case option
        when SmartBuildTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED
          _refresh
        when SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE
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
      return [ false, 'tool.smart_build.error.invalid_divider_seed' ] unless (!part.is_a?(Part) || part.group.material_type != MaterialAttributes::TYPE_HARDWARE)
      return [ false, 'tool.smart_build.error.invalid_divider_container' ] if !part_entity_path.nil? && part_entity_path.one?

      # The inherited tests first : no point paying for a cavity detection on a part that will be refused anyway.
      can_activate, _ = super_result = super
      return super_result unless can_activate

      return [ false, 'tool.smart_build.error.no_divider_cavity' ] if (cavities_def = _get_cavities_def(part_entity_path, part)).is_a?(CavitiesDef) && cavities_def.valid? && cavities_def.fragment_defs.empty?
      # A detection that failed says why - a panel the booleans cannot take
      # (open or non manifold edges, named), a container too complex (see
      # CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX) - rather than let the
      # pick go on and land on "no cavity at this position"
      return [ false, *cavities_def.result_def.errors.first ] if cavities_def.is_a?(CavitiesDef) && !cavities_def.valid?

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

          k_segments = Kuix::Segments.new
          k_segments.add_segments(segments)
          k_segments.color = color
          k_segments.line_width = @locked_normal ? 2.5 : 1.5
          @tool.append_3d(k_segments, LAYER_3D_DIVIDER_PREVIEW)

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
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED)
    end

    def _fetch_option_reduce_envelope?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE)
    end

    # The reduction is the divider's own option : a divider is fitted BETWEEN
    # the panels it lands on, so pulling the envelope back to a recessed
    # chant is a legitimate reading of the compartment - see
    # SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE.
    def _cavities_reduce_envelope?
      _fetch_option_reduce_envelope?
    end

    # A divider is fitted INTO the compartment it divides : a panel already
    # standing in one of its mouths is in the way, and the compartment stops at
    # its back - see CommonSolidFindCavitiesWorker, INSET FRONT PANELS. BOTH
    # kinds : a divider is no more allowed to telescope into a back than into a
    # front panel. One laid in applique is no obstacle and recedes nothing,
    # which the worker reads off the cavities themselves : there is nothing to
    # tell it here.
    def _cavities_recess_panel_types
      LayerAttributes::TYPES_PANEL
    end

    # -----

    # The pick, read THROUGH what closes the compartment - see
    # #_snap_point_through_cavities. A divider is fitted INSIDE a compartment,
    # so whatever closes it is precisely what stands in the way.
    #
    # The inference lost on the way costs nothing here : a divider is placed at
    # a distance or by distribution, not on a vertex.
    def _snap_point(picker)
      _snap_point_through_cavities(picker)
    end

    # The pick designates ONE compartment, and #_snap_point already knows
    # which : looking it up again from the point would hand back every cavity
    # that point touches, and it lies exactly on a wall two of them may share.
    def _get_preview_cavity_fragment_defs(cavities_def)
      @picked_fragment_def.is_a?(SolidCavityFragmentDef) ? [ @picked_fragment_def ] : []
    end

    # -----

    def _fetch_option_reuse_definition?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
    end

    def _fetch_option_measure_type_inside?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_MEASURE_TYPE, SmartBuildTool::ACTION_OPTION_MEASURE_TYPE_INSIDE)
    end

    def _fetch_option_measure_type_outside?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_MEASURE_TYPE, SmartBuildTool::ACTION_OPTION_MEASURE_TYPE_OUTSIDE)
    end

    # -----

    # Rebuilds the divider fragments as real geometry inside the model,
    # names and selects the resulting part - the same tail conventions
    # (ask_name option / success notification) as the other draw handlers'
    # _create_entity.
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

        if active?

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
            @tool.notify_success(PLUGIN.get_i18n_string("tool.smart_build.success.part_reused", { :name => reused_definition.nil? ? '' : reused_definition.name, :count => count }))
          elsif _fetch_option_ask_name?
            fn_ask_name.call
          else
            @tool.notify_success(
              PLUGIN.get_i18n_string("tool.smart_build.success.part_created", { :name => new_definition.name, :count => count }),
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
          tool.notify_errors([ [ 'tool.smart_build.error.divider_number_overflow', { :number => @number } ] ])
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
  # SmartBuildFrontPanelActionHandler and SmartBuildBackPanelActionHandler for
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
  # (#_cavities_overall? stays false, see SmartBuildPanelActionHandler) : it is
  # what a FULL HEIGHT panel spans, but a pick would then land in two cavities
  # at once - its compartment and the overall one - and which of them the user
  # means is a rule of its own, not something to settle by fragment order.
  class SmartBuildMouthPanelActionHandler < SmartBuildPanelActionHandler

    include SmartActionHandlerSolidBooleanHelper

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

    # What share of a mouth the panels already standing on it have to cover
    # for that opening to count as CLOSED - see #_opening_already_panelled?.
    # Half : a mouth genuinely filled is covered whole bar the clearances, and
    # anything that leaves the better part of it open is furniture standing in
    # the compartment, not the panel closing it.
    OPENING_CLOSED_MIN_COVERAGE = 0.5

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

    # Raised while the batch touches the model, to REFUSE it : the operation is
    # aborted like on any failure, but the user is told why with +errors+ (i18n
    # tuples, see SmartTool#notify_errors) rather than handed a crash report.
    class RefusedError < StandardError

      attr_reader :errors

      def initialize(errors)
        super(errors.inspect)
        @errors = errors
      end

    end

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
               ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_build.action_option_options_measure_reversed_status') + '.' +
               ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_build.action_option_options_reduce_envelope_status') + '.'
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

      return true if _flush_cavities_dwell

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
            #
            # The panels of its own kind read aside are, though : the one just
            # built is among them now, and it is what says its opening is closed
            # (see #_opening_already_panelled?).
            _refresh_cavities_own_panels
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

      case @state

      when STATE_PLACE

        if tool.is_key_shift_down? && !tool.is_vcb_typing?
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
          @tool.store_action_option_value(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED, !_fetch_option_measure_reversed?, fire_event: true)
          return true
        end
        if tool.is_key_alt_or_command?(key) && is_quick
          @tool.store_action_option_value(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE, !_fetch_option_reduce_envelope?, fire_event: true)
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
            snapped = _snap_point(picker)
            if !snapped && _cavities_pending?
              # Not known yet : nothing to say of this position, either way
              @tool.remove_tooltip
              @tool.pop_cursor(SmartCursorManager.cursor_select_error)
            elsif !snapped
              @tool.show_tooltip(PLUGIN.get_i18n_string("tool.smart_build.error.invalid_#{_panel_i18n_key_suffix}_cavity"), SmartTool::MESSAGE_TYPE_ERROR)
              @tool.push_cursor(SmartCursorManager.cursor_select_error)
            elsif _picked_on_closed_opening?(view)
              # The cavity is a fine one, it is simply already closed on the
              # side this handler draws on - and says so rather than offering
              # a second panel on top of the one there (see
              # #_opening_already_panelled?).
              @tool.show_tooltip(PLUGIN.get_i18n_string("tool.smart_build.error.closed_#{_panel_i18n_key_suffix}_opening"), SmartTool::MESSAGE_TYPE_ERROR)
              @tool.push_cursor(SmartCursorManager.cursor_select_error)
            else
              @tool.remove_tooltip
              @tool.pop_cursor(SmartCursorManager.cursor_select_error)
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
      @locked_direction = nil if option_group == SmartBuildTool::ACTION_OPTION_AXES
      # OVERLAY is folded into #_cavities_reduce_envelope? itself (an applied
      # panel never wants a receded mouth - see there), so flipping it can
      # change what the cavities compute to just as much as the option does.
      if option_group == SmartBuildTool::ACTION_OPTION_OVERLAY ||
         (option_group == SmartBuildTool::ACTION_OPTION_OPTIONS && option == SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE)
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

    # The footprints of the panels read aside are keyed by their drawing def
    # (see #_get_panel_footprint_paths), which the refresh replaces.
    def _refresh_cavities_own_panels
      @panel_footprint_container_path = nil
      @panel_footprint_paths_cache = nil
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
      return [ false, "tool.smart_build.error.invalid_#{_panel_i18n_key_suffix}_seed" ] unless (!part.is_a?(Part) || part.group.material_type != MaterialAttributes::TYPE_HARDWARE)
      return [ false, "tool.smart_build.error.invalid_#{_panel_i18n_key_suffix}_container" ] if !part_entity_path.nil? && part_entity_path.one?

      # The inherited tests first : no point paying for a cavity detection on a part that will be refused anyway.
      can_activate, _ = super_result = super
      return super_result unless can_activate

      return [ false, "tool.smart_build.error.no_#{_panel_i18n_key_suffix}_cavity" ] if (cavities_def = _get_cavities_def(part_entity_path, part)).is_a?(CavitiesDef) && cavities_def.valid? && cavities_def.fragment_defs.empty?
      # A detection that failed says why - a panel the booleans cannot take
      # (open or non manifold edges, named), a container too complex (see
      # CommonSolidFindCavitiesWorker::ERROR_TOO_COMPLEX) - rather than let the
      # pick go on and land on "no cavity at this position"
      return [ false, *cavities_def.result_def.errors.first ] if cavities_def.is_a?(CavitiesDef) && !cavities_def.valid?

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
    #
    # A pick read through the cavities designates ONE compartment, for the
    # reason SmartBuildDividerActionHandler#_get_preview_cavity_fragment_defs
    # gives.
    def _get_preview_cavity_fragment_defs(cavities_def)
      return @merge_fragment_defs if _merging?
      return (@picked_fragment_def.is_a?(SolidCavityFragmentDef) ? [ @picked_fragment_def ] : []) if _snap_point_through_panels?
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

      @tool.store_action_option_value(@action, SmartBuildTool::ACTION_OPTION_THICKNESS, SmartBuildTool::ACTION_OPTION_THICKNESS_THICKNESS, thickness.to_s, fire_event: true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # The SUFFIXED lengths of the VCB, which a bare length cannot stand for
    # here - it is already the thickness. None by default : what a panel has
    # besides its thickness is its own business (see
    # SmartBuildFrontPanelActionHandler#_read_panel_lengths for the clearance,
    # and SmartBuildBackPanelActionHandler for the groove depth and the
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

      @tool.store_action_option_value(@action, SmartBuildTool::ACTION_OPTION_OFFSET, option, length.to_s, fire_event: true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _fetch_option_thickness
      @tool.fetch_action_option_length(@action, SmartBuildTool::ACTION_OPTION_THICKNESS, SmartBuildTool::ACTION_OPTION_THICKNESS_THICKNESS)
    end

    def _fetch_option_overlay_full_overlay?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OVERLAY, SmartBuildTool::ACTION_OPTION_OVERLAY_FULL_OVERLAY)
    end

    def _fetch_option_reuse_definition?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_REUSE_DEFINITION)
    end

    def _fetch_option_measure_reversed?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED)
    end

    def _fetch_option_reduce_envelope?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_REDUCE_ENVELOPE)
    end

    # Not exposed in the action's options panel : the layer panels are put on
    # is a technical setting, not a drawing option - only the modal (see
    # modal-smart-draw-tool-action-4.twig and -5) gives access to it.
    def _fetch_option_layer_name
      @tool.fetch_action_option_string(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_LAYER_NAME)
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
    # TWO at most : a front and a back, the mouth a panel closes and the one
    # facing it. A cavity open on a third side is not a compartment a front or
    # a back closes - the notch a U shaped carcass leaves between its legs,
    # the top compartment of a carcass without a top - and kept, it would
    # also stand as a NEIGHBOUR of the real compartments beside it, sharing
    # out the frame of the panel in applique that closes them (see
    # #_get_overlay_points) : that panel would stop halfway across the
    # dividers and the shelf walling the notch off, where it has every reason
    # to cover them whole.
    def _cavities_max_opening_planes
      2
    end

    # And those two standing APART, for the same reasons : a CORNER
    # compartment, open at the front and on top - the top of a carcass
    # without a top, but with a back - or on a side, is no more a compartment
    # a front or a back closes than one open on three sides. Apart, not
    # parallel : a sloped front, a trapezoidal carcass, a rear bridged by a
    # slanted hull cap all keep their front and their back - and a top made
    # of two rails, open between them, keeps its front, the front rail
    # standing between the two mouths.
    def _cavities_apart_opening_planes?
      true
    end

    def _cavities_reduce_envelope?
      _fetch_option_reduce_envelope? && !_fetch_option_overlay_full_overlay?
    end

    # The OTHER kind of panel, never its own - see LayerAttributes.
    #
    # A panel of the other kind is a wall of the compartment being faced : a
    # back set back in its groove closes the carcass a board's thickness -
    # plus its setback - short of the rear, and a compartment whose divider
    # stops on that very face communicates with its neighbour through what is
    # left behind it. Read without the back, the two come out as ONE cavity,
    # and the tool offers one panel where two compartments stand. Handed in
    # aside, the back merely makes the rear opening RECEDE to its own face,
    # the divider then reaches it, and each compartment is its own cavity
    # again - without the back becoming a wall of the carcass, which is what
    # its tag says it is not (see CommonSolidFindCavitiesWorker, APPLIED
    # PANELS and INSET FRONT PANELS). One laid in APPLIQUE stands outside the
    # cavity and recedes nothing, which is right too : the compartments it
    # closes do communicate behind a divider that stops short of it.
    #
    # Its OWN kind stays out, for the reason the base class gives : the mouth
    # a panel is fitted onto has to be read as the CARCASS leaves it, or the
    # next panel would be laid against the back of the one already there.
    def _cavities_recess_panel_types
      LayerAttributes::TYPES_PANEL - [ _panel_layer_type ]
    end

    # Its OWN kind, and only it : the panels the cavities are blind to are
    # precisely the ones this handler would build a second copy of. See
    # #_opening_already_panelled?.
    def _cavities_own_panel_types
      [ _panel_layer_type ]
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
    #
    # And only one standing IN the mouth the pick resolves to : a compartment
    # open at both ends, already closed at the FAR one, is looked into through
    # its near mouth - and the ray stops on the inner face of the panel that
    # closes the other end. That panel is the back wall of the cavity being
    # faced, exactly like a back panel, and refusing it would refuse a mouth
    # that is wide open. See #_panel_fills_mouth?.
    def _picked_on_existing_panel?(picker, view)
      return false unless (picked_face_path = picker.picked_face_path).is_a?(Array)
      return false if (index = picked_face_path.index { |entity| LayerAttributes.type_of(entity) == _panel_layer_type }).nil?

      # Nothing to tell where it stands : refused, as any panel of its kind was
      return true unless @picked_point.is_a?(Geom::Point3d)
      return true unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?
      return true unless (picked_plane_manipulator = picker.picked_plane_manipulator).is_a?(PlaneManipulator)
      return true unless (fragment_def = _get_cavity_fragment_def(cavities_def, @picked_point, picked_plane_manipulator)).is_a?(SolidCavityFragmentDef)
      return true if (opening_def = _get_panel_opening_def(fragment_def, view)).nil?

      ti = _get_opening_transformation(opening_def).inverse
      panel = picked_face_path[index]
      bounds = panel.definition.bounds
      z_min, z_max = _z_range((0..7).flat_map { |corner| bounds.corner(corner).to_a }, ti * PathUtils.get_transformation(picked_face_path[0..index], IDENTITY))

      _panel_fills_mouth?(z_min, z_max, _z_range(fragment_def.vertices, ti).first)
    end

    # Whether a panel reaching [ z_min, z_max ] along an opening's normal - in
    # the opening's own frame, the mouth on z = 0 and the cavity down to
    # cavity_z_min - is one that FILLS that mouth.
    #
    # Neither one standing in front of the mouth - laid OVER it, a panel of
    # another pose or of another carcass - nor one standing in the far HALF of
    # the cavity or beyond : that one closes the other end of the compartment,
    # or the compartment behind it. The half matters because the cavity is
    # blind to the panels of this kind (see #_cavities_own_panel_types) : a
    # compartment closed at the far end by one of them still reads open right
    # through, its far end is that other mouth, and the panel filling it stands
    # INSIDE the cavity's depth.
    def _panel_fills_mouth?(z_min, z_max, cavity_z_min)
      return false if z_min >= SolidMeshDef::TOLERANCE   # In front of the mouth : laid OVER it, not IN it
      (z_min + z_max) / 2.0 > cavity_z_min / 2.0          # Nearer this mouth than the far end
    end

    # Whether the pick is read THROUGH the panels standing in the way - see
    # SmartBuildPanelActionHandler#_snap_point_through_cavities. Off here : a
    # panel laid on the mouth the camera faces has nothing to look through, and
    # the model's own pick keeps its inference. A handler whose opening lies at
    # the FAR end of the look turns it on (see SmartBuildBackPanelActionHandler).
    #
    # Read through, a pick never lands on a panel at all - the ray is cast at
    # the cavities, which no applied panel of this handler's own kind is part
    # of - so #_picked_on_existing_panel? has nothing left to catch, and a
    # mouth already closed is told by #_opening_already_panelled? alone.
    def _snap_point_through_panels?
      false
    end

    # A pick on an existing panel snaps to nothing : see
    # #_picked_on_existing_panel?. Nothing at all - the point is dropped, or
    # #_preview_cavity would go on drawing the cavity it landed in.
    def _snap_point(picker)
      return _snap_point_through_cavities(picker) if _snap_point_through_panels?
      return false unless super
      return true unless _picked_on_existing_panel?(picker, picker.view)
      @picked_point = nil
      false
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

      resolved = _resolve_pick(point, view)
      return nil if resolved.nil?
      cavities_def, fragment_def, opening_def, picked_face_manipulator = resolved

      t = _get_opening_transformation(opening_def)
      ti = t.inverse

      # Already closed on that side : the panel would be laid on the one
      # standing there. See #_opening_already_panelled?.
      return nil if _opening_already_panelled?(fragment_def, opening_def, ti)

      points = _get_panel_nominal_points(fragment_def, opening_def, ti)
      return nil if points.nil? || points.length < 3

      MouthPanelContext.new(cavities_def, fragment_def, opening_def, t, points, _get_split_direction(picked_face_manipulator, opening_def, ti, view))
    end

    # What a pick designates, before a single contour is cut :
    # [ cavities_def, fragment_def, opening_def ] - the cavities of the
    # container, the compartment the pick lands in, and the opening the panel
    # is meant for. nil when it designates none.
    #
    # Split out of #_compute_panel_context because it is the CHEAP half - a
    # point lookup and a dot product, no Clipper at all - and the only half
    # #_picked_on_closed_opening? needs to answer while the cursor moves.
    def _resolve_pick(point, view)
      return nil unless point.is_a?(Geom::Point3d)
      return nil unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      if _snap_point_through_panels?
        # The pick already knows the compartment and the wall : the picker's
        # own face is whatever stood in front of them.
        return nil unless (fragment_def = @picked_fragment_def).is_a?(SolidCavityFragmentDef)
        return nil unless (picked_face_manipulator = @picked_plane_manipulator).is_a?(PlaneManipulator)
      else
        return nil if _picked_on_existing_panel?(@picker, view)
        return nil unless (picked_face_manipulator = @picker.picked_plane_manipulator).is_a?(PlaneManipulator)
        fragment_def = _get_cavity_fragment_def(cavities_def, point, picked_face_manipulator)
        return nil unless fragment_def.is_a?(SolidCavityFragmentDef)
      end

      opening_def = _get_panel_opening_def(fragment_def, view)
      return nil if opening_def.nil?

      [ cavities_def, fragment_def, opening_def, picked_face_manipulator ]
    end

    # Whether the pick lands on a cavity this handler has already closed - what
    # the cursor says, and what #_compute_panel_context refuses on.
    def _picked_on_closed_opening?(view)
      return false if _merging?

      resolved = _resolve_pick(@picked_point, view)
      return false if resolved.nil?
      _, fragment_def, opening_def = resolved

      _opening_already_panelled?(fragment_def, opening_def, _get_opening_transformation(opening_def).inverse)
    end

    # Whether a panel of this handler's OWN kind already closes that opening.
    #
    # Nothing in the cavity says so, and that is deliberate : an applied panel
    # of the kind being drawn is held out of the detection altogether, or the
    # mouth would be read on the back of the panel filling it instead of on the
    # carcass (see #_cavities_recess_panel_types). The cavity therefore reads
    # WIDE OPEN on a side that is already closed, and the tool cheerfully
    # offers to build the very panel standing there - which is the one thing
    # #_picked_on_existing_panel? cannot catch, since the panel in question is
    # at the FAR end of the look and never under the cursor.
    #
    # Read on the MOUTH and on all the own panels TOGETHER : a mouth shared
    # between two panels is closed by neither of them alone, and a single
    # panel merged over several compartments closes each of their mouths
    # whole.
    #
    # Two gates keep a panel that closes something ELSE out of the reckoning,
    # both read along the opening's own normal (see #_panel_fills_mouth?) :
    #
    #   - one standing in the far HALF of the cavity, or beyond, closes its
    #     other end or the compartment behind it, not this mouth ;
    #   - one standing OUTSIDE the mouth is laid over it - a panel of another
    #     pose, or of another carcass - and is not what fills it.
    #
    # A panel's extent is read off its BOUNDS rather than its mesh : the mouth
    # coverage below is what decides, and a bounding box can only ever widen
    # the window a panel is accepted in, never narrow it.
    def _opening_already_panelled?(fragment_def, opening_def, ti)
      return false unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef)
      own_panel_drawing_defs = cavities_def.own_panel_drawing_defs
      return false if own_panel_drawing_defs.nil? || own_panel_drawing_defs.empty?

      mouth = opening_def.outer_loop
      return false if mouth.nil? || mouth.length < 3
      mouth_path = Fiddle::Clippy.points_to_rpath(mouth.map { |point| point.transform(ti) })
      mouth_area = Fiddle::Clippy.get_rpath_area(mouth_path).abs
      return false if mouth_area <= 0

      cavity_z_min = _z_range(fragment_def.vertices, ti).first

      paths = own_panel_drawing_defs.flat_map { |drawing_def|
        next [] unless _panel_fills_mouth?(*_drawing_def_z_range(drawing_def, ti), cavity_z_min)
        _get_panel_footprint_paths(drawing_def, opening_def, ti) || []
      }
      return false if paths.empty?

      covered_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: paths, clips: [ mouth_path ])
      covered_area = covered_paths.inject(0.0) { |sum, covered_path| sum + Fiddle::Clippy.get_rpath_area(covered_path).abs }

      covered_area >= mouth_area * OPENING_CLOSED_MIN_COVERAGE
    end

    # How far a drawing def reaches along the opening's normal, as
    # [ z_min, z_max ] in the opening's frame - read off its BOUNDS, whose
    # eight corners bound whatever it holds however it is turned.
    def _drawing_def_z_range(drawing_def, ti)
      bounds = drawing_def.bounds
      t = ti * drawing_def.transformation
      _z_range((0..7).flat_map { |index| bounds.corner(index).to_a }, t)
    end

    # [ z_min, z_max ] of a FLAT array of coordinates - [ x, y, z, x, y, z, … ],
    # the way a SolidMeshDef writes its vertices - once transformed.
    def _z_range(coords, t)
      z_min = nil
      z_max = nil
      index = 0
      while index < coords.length
        z = Geom::Point3d.new(coords[index], coords[index + 1], coords[index + 2]).transform(t).z.to_f
        z_min = z if z_min.nil? || z < z_min
        z_max = z if z_max.nil? || z > z_max
        index += 3
      end
      [ z_min.nil? ? 0.0 : z_min, z_max.nil? ? 0.0 : z_max ]
    end

    # The opening's OWN frame, where the mouth lies flat on z = 0 and
    # everything below is computed.
    #
    # CANONICAL for the PLANE - its origin is the world origin projected on it,
    # its axes come from the normal alone - so two cavities sharing a panel read
    # their neighbours and the container's silhouette in the very same
    # coordinates, the silhouette can be computed once for them all, and anyone
    # holding nothing but an opening_def (see
    # SmartBuildBackPanelActionHandler#_prepare_panels!) reads the same frame the
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
        tool.notify_errors([ [ "tool.smart_build.error.#{_panel_i18n_key_suffix}_number_overflow", { :number => @number } ] ])
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
    # the viewer SEES the most of, looking the way
    # #_panel_opening_facing_vector asks for.
    #
    # Nothing in the cavity says which of its mouths is which - a through tube
    # has two, congruent ones. What says it is the VIEWER, and which way round
    # depends on what is being drawn : a front panel goes on the mouth the
    # camera faces, a back panel on the one at the far end of the same look
    # (see the hook). An opening turned the other way, or seen edge-on
    # (OPENING_FACING_MIN_DOT), is not a candidate at all.
    #
    # Among the candidates, the APPARENT area decides - the area times the
    # facing dot, what the opening covers on screen - and the facing alone
    # breaks a tie. Facing alone is not enough since a compartment may open
    # on two planes square to each other, provided a panel stands between the
    # two mouths (see #_cavities_apart_opening_planes?) : a carcass whose top
    # is two rails, open between them, looked at from above at more than 45°,
    # would get its front panel on the narrow slot between the rails rather
    # than on the front it is plainly meant for. The area alone would be wrong
    # the other way round, a big mouth seen almost edge-on outweighing the one
    # the user faces - which is why the two are weighed together. And what
    # made area first wrong once, a corner compartment offering a side mouth
    # several times the front's in a three quarter view, is no candidate here
    # any more : its two mouths meet, and the cavity is not a compartment a
    # front or a back closes.
    def _get_panel_opening_def(fragment_def, view)
      facing = _panel_opening_facing_vector(view)

      best = nil
      best_score = nil
      fragment_def.opening_defs.each do |opening_def|
        normal = opening_def.normal
        dot = normal.x * facing[0] + normal.y * facing[1] + normal.z * facing[2]
        next if dot < OPENING_FACING_MIN_DOT
        score = [ opening_def.area * dot, dot ]
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
    # SmartBuildBackPanelActionHandler.
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
    # runs into the parts around it (see SmartBuildBackPanelActionHandler), and
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
    # SmartBuildBackPanelActionHandler) and the whole of the rest of the
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
    # SmartBuildBackPanelActionHandler) ; the world one is what gets built.
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
    #
    # +min_width+ is what the caller is sizing. PANEL_MIN_WIDTH wherever the
    # region IS a panel, which is all of them but one : #_cut_host_defs sizes
    # the footprint of a GROOVE, and a groove is only as wide as it is deep -
    # see there.
    def _clean_pieces(paths, min_width = PANEL_MIN_WIDTH)
      return [] if paths.empty?

      delta = min_width.to_f / 2.0
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
    # SmartBuildFrontPanelActionHandler, where a pair of leaves has to open).
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
    #
    # A bisector is only a sound cut between CONVEX mouths : it is then the
    # line that separates them. Around a U shaped mouth with a neighbour
    # standing in its notch, the shortest segment may well be the one to the
    # floor of that notch, and the bisector across it takes both legs of the
    # U away. So both mouths are read as their CONVEX PIECES (see
    # #_convex_pieces), each piece of ours is cut by every piece of the
    # neighbours, and our share is the union of what each piece keeps : a
    # point belongs to us as soon as it belongs to one of our pieces. A
    # convex mouth is one piece, and reads exactly as before.
    #
    # What is cut is the silhouette, OUR MOUTH INCLUDED, rather than the bare
    # footprint. The footprint has the mouth as a hole, and a cut running
    # across that hole - which a piece's own cut does, through the pieces
    # beside it - opens it onto the outside : the outer contour then hugs the
    # frame and holds no mouth at all. A mouth that is a NOTCH in the
    # silhouette's own border - a compartment open on the edge of the
    # container - is not even inside the footprint to begin with.
    def _get_overlay_points(fragment_def, opening_def, mouth_points, ti)

      silhouette_paths = _get_silhouette_paths(opening_def, ti)
      return nil if silhouette_paths.nil? || silhouette_paths.empty?

      # Through a union, so that the mouth is wound the way Clipper expects
      # whichever way the opening handed it over.
      mouth_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(mouth_points) ])
      return nil if mouth_paths.empty?

      subject_polytree = Fiddle::Clippy.execute_polytree(clip_type: Fiddle::Clippy::CLIP_TYPE_UNION, closed_subjects: silhouette_paths + mouth_paths)
      subject_paths = Fiddle::Clippy.polytree_to_polyshapes(subject_polytree).map { |polyshape| polyshape.paths.first }.compact
      return nil if subject_paths.empty?

      reach = _paths_reach(subject_paths)

      sibling_pieces = _get_sibling_mouth_points(fragment_def, opening_def, ti).flat_map { |sibling_points| _convex_pieces(sibling_points) }

      share_paths = _convex_pieces(mouth_points).map { |piece|

        clips = []
        sibling_pieces.each do |sibling_piece|
          near_point, far_point = _loops_closest_points(piece, sibling_piece)
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
          closed_subjects: subject_paths,
          clips: clips
        )

        # No cut crosses the piece - a bisector separates it from the
        # neighbour's - so the piece lies whole in one region, the one kept.
        piece_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: [ Fiddle::Clippy.points_to_rpath(piece) ])
        _best_overlapping_path(Fiddle::Clippy.polytree_to_polyshapes(polytree).map { |polyshape| polyshape.paths.first }, piece_paths)

      }.compact
      return nil if share_paths.empty?

      polytree = Fiddle::Clippy.execute_polytree(clip_type: Fiddle::Clippy::CLIP_TYPE_UNION, closed_subjects: share_paths)

      best_path = _best_overlapping_path(Fiddle::Clippy.polytree_to_polyshapes(polytree).map { |polyshape| polyshape.paths.first }, mouth_paths)
      return nil if best_path.nil?

      Fiddle::Clippy.rpath_to_points(best_path)
    end

    # +points+ - a closed contour of the opening's frame - as a list of CONVEX
    # contours that tile it, each one a list of points. The contour itself
    # when it already is convex, which is what nearly every mouth is.
    #
    # Ear clipping first, then Hertel-Mehlhorn : two neighbouring pieces are
    # merged back across their common diagonal whenever the union stays
    # convex, which leaves a U as its two legs and its base rather than as
    # six triangles.
    #
    # The vertices that draw no corner are dropped beforehand (see
    # #_flatten_outline) : a 179.999 degree vertex would read as REFLEX and
    # split a rectangle for nothing. A contour the clipping gets stuck on -
    # a self touching one - is handed back whole, which is what reading it as
    # one piece always did.
    def _convex_pieces(points)
      return [ points ] if points.length <= 3

      coords = _flatten_outline(points).map { |point| [ point.x.to_f, point.y.to_f ] }
      return [ points ] if coords.length <= 3

      signed_area = 0.0
      coords.each_with_index { |(x, y), index| following_x, following_y = coords[(index + 1) % coords.length] ; signed_area += x * following_y - following_x * y }
      coords.reverse! if signed_area < 0   # Counter clockwise : a convex vertex turns left

      fn_convex = lambda { |indices| indices.each_index.all? { |i| _cross_2d(coords[indices[i - 1]], coords[indices[i]], coords[indices[(i + 1) % indices.length]]) >= 0 } }

      indices = (0...coords.length).to_a
      return [ points ] if fn_convex.call(indices)

      # Ear clipping
      polygons = []
      while indices.length > 3
        count = indices.length
        ear = (0...count).find { |i|
          a, b, c = indices[i - 1], indices[i], indices[(i + 1) % count]
          next false unless _cross_2d(coords[a], coords[b], coords[c]) > 0
          indices.none? { |j|
            next false if coords[j] == coords[a] || coords[j] == coords[b] || coords[j] == coords[c]
            _cross_2d(coords[a], coords[b], coords[j]) >= 0 && _cross_2d(coords[b], coords[c], coords[j]) >= 0 && _cross_2d(coords[c], coords[a], coords[j]) >= 0
          }
        }
        return [ points ] if ear.nil?
        polygons << [ indices[ear - 1], indices[ear], indices[(ear + 1) % count] ]
        indices.delete_at(ear)
      end
      polygons << indices

      # Hertel-Mehlhorn : an edge u -> v of one polygon is v -> u in the other
      merged = true
      while merged
        merged = false
        polygons.each_with_index do |polygon, index|
          polygons.each_with_index do |other_polygon, other_index|
            next if other_index <= index
            polygon.each_with_index do |u, i|
              v = polygon[(i + 1) % polygon.length]
              j = other_polygon.index(v)
              next unless !j.nil? && other_polygon[(j + 1) % other_polygon.length] == u
              candidate = polygon.rotate(i + 1) + other_polygon.rotate(j + 1)[1...-1]   # v ... u, then the other one from past u to short of v
              next unless fn_convex.call(candidate)
              polygons[index] = candidate
              polygons.delete_at(other_index)
              merged = true
              break
            end
            break if merged
          end
          break if merged
        end
      end

      polygons.map { |polygon| polygon.map { |i| Geom::Point3d.new(coords[i][0], coords[i][1], 0.0) } }
    end

    # Twice the signed area of the triangle +o+ +a+ +b+ - [ x, y ] Floats -,
    # positive when it turns left.
    def _cross_2d(o, a, b)
      (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
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
        @silhouette_paths_cache = nil   # Keyed by plane alone, like the footprint : the carcass next door has its front on that very plane
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
    # ALWAYS. In applique the merged panel simply covers the shares it gathered,
    # and nothing stands in its way. INSET it runs into the panels separating the
    # compartments it spans, and those are CUT to let it through - a back passes
    # in front of a divider, which is shortened by as much ; a front takes the
    # divider's nose off over its own thickness. Either way the panel comes out
    # as ONE piece, which is what the gesture is for. See
    # #_get_crossed_drawing_defs and #_prepare_panels!.
    def _merge_allowed?
      true
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

      picked_point, picked_fragment_def, picked_plane_manipulator = @picked_point, @picked_fragment_def, @picked_plane_manipulator
      unless _snap_point(picker)
        # A pick on nothing is not a pick : the cavity preview keeps the point it had
        @picked_point, @picked_fragment_def, @picked_plane_manipulator = picked_point, picked_fragment_def, picked_plane_manipulator
        return
      end

      fragment_def = _snap_point_through_panels? ? @picked_fragment_def : _get_cavity_fragment_def(@merge_context.cavities_def, @picked_point, picker.picked_plane_manipulator)
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

      own_opening_def = _get_cavity_opening_def(fragment_def, @merge_context.opening_def)
      return false if own_opening_def.nil?

      # Already closed : gathering it would build the common panel over the one
      # standing there, see #_opening_already_panelled?. The drag simply does
      # not take that cavity - the seed was refused for the same reason before
      # it ever opened.
      return false if _opening_already_panelled?(fragment_def, own_opening_def, ti)

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
    # Two POSES again, and they read opposite things :
    #
    #   OVERLAY : the SHARES, and only them. A panel in applique is the share of
    #             the front each compartment is entitled to, and several of them
    #             is their union, nothing more (see #_merge_add). It covers what
    #             separates them without touching it, so the mouths are of no use
    #             to it.
    #   INSET   : the MOUTHS, plus the panels the merged panel runs straight
    #             across, the whole then grown by whatever the pose grows by.
    #
    # Two mouths of neighbouring compartments stand a whole panel apart, so their
    # union alone is two rings, and no panel : what closes it is the panel
    # between them, taken WHOLE (see #_get_crossed_drawing_defs). Whole, and not
    # merely bridged by a growth : a back's groove is 8 mm deep where a divider
    # is 18 mm thick, so the growth from either side would not meet in the
    # middle, and a front grows by nothing at all.
    #
    # Taking it whole is also what tells #_cut_host_defs the truth about it - a
    # part the merged panel spans end to end is a part the panel ENDS, and the
    # piece of it left behind the panel is dropped (see #_drop_offcuts!), which
    # is exactly a divider stopped short of the panel.
    def _merge_nominal_points(share_paths, mouth_paths, opening_def, ti)
      return _merge_points(share_paths) if _fetch_option_overlay_full_overlay?

      crossed_paths = _get_crossed_drawing_defs(share_paths, opening_def, ti).flat_map { |drawing_def| _get_panel_footprint_paths(drawing_def, opening_def, ti) }
      points = _merge_points(mouth_paths + crossed_paths)
      return nil if points.nil?

      _grow_nominal_points(points, opening_def, ti)
    end

    # The panels the merge SURROUNDS - the ones a panel spanning the gathered
    # cavities has to run across, and so to cut.
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
    # A divider that runs out to the silhouette itself - flush with the face of
    # the carcass at both its ends - is left out on purpose : crossing it would
    # show from the outside. The mouths then stay two rings, #_merge_points reads
    # no panel in them, and the drag simply does not take that cavity.
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

        # A panel already laid on the carcass is not carcass : a panel never runs
        # across another back, nor across a front.
        next false if LayerAttributes.panel_type?(LayerAttributes.type_of(drawing_def.container))

        footprint_paths = _get_panel_footprint_paths(drawing_def, opening_def, ti)
        next false if footprint_paths.nil? || footprint_paths.empty?

        outside_paths, _ = Fiddle::Clippy.execute_difference(closed_subjects: footprint_paths, clips: inner_paths)
        area = outside_paths.inject(0.0) { |sum, outside_path| sum + Fiddle::Clippy.get_rpath_area(outside_path).abs }
        area <= MERGE_ADJACENCY_DELTA * MERGE_MIN_SHARED_BORDER

      }
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
      own_opening_def = _get_cavity_opening_def(fragment_def, opening_def)
      return nil if own_opening_def.nil?

      mouth = own_opening_def.outer_loop
      return nil if mouth.nil? || mouth.length < 3

      mouth.map { |point| point.transform(ti) }
    end

    # The opening ONE cavity offers on the reference opening's plane - the
    # largest, for the reason #_get_cavity_mouth_points gives. nil when it does
    # not open there at all.
    def _get_cavity_opening_def(fragment_def, opening_def)
      _get_opening_defs_on_plane(fragment_def, opening_def).max_by { |other_opening_def| other_opening_def.area }
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

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.color = color
        k_segments.line_width = locked ? 2.5 : 1.5
        @tool.append_3d(k_segments, LAYER_3D_PANEL_PREVIEW)

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
        # SmartBuildBackPanelActionHandler) may have to make an ancestor unique
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
          # carcass bare - see SmartBuildPanelActionHandler#_get_cavities_def and
          # LayerAttributes.
          instance.layer = LayerAttributes.fetch_or_create_layer(model, _panel_layer_type, _fetch_option_layer_name)

          created_entity_count += 1

        end

        if created_entity_count == 0
          model.abort_operation
          return false
        end

        if active?

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
              PLUGIN.get_i18n_string("tool.smart_build.success.part_created", { :name => new_definition.name, :count => count }),
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

      rescue RefusedError => e
        model.abort_operation
        @tool.notify_errors(e.errors)
        return false
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
    # Everything is measured BEFORE the first write : separating a shared
    # definition clones it, and every entity read beforehand then belongs to
    # the definition nobody sees any more. The hosts are therefore found again
    # afterwards by their POSITION, not by the reference that was held on them.
    #
    # ONE shape drives all of it - the panel's own, grown by the depth it is
    # let in by (#_cut_contour_paths) - and every part it reaches is subtracted
    # from in ONE pass. What tells the parts apart is only what happens after :
    #
    #   A part the panel merely bites into comes out GROOVED, and that is the
    #   end of it.
    #
    #   A part the panel CROSSES comes out SEVERED - the panel passes right
    #   through it - and the piece left standing behind the panel is dropped
    #   (see #_drop_offcuts!), which is what ends that part at the panel. It has
    #   to come off for real : BoundingBoxHelper skips machining volumes outright
    #   (bounding_box_helper.rb:27), so a part merely MARKED as cut would keep
    #   the length it no longer has and the cutlist would call for a divider
    #   that does not fit.
    #
    # The sharing of two identical dividers is left to
    # CommonSolidBooleanApplyWorker, which preserves a definition they share
    # when the cut leaves them identical - something a separation of our own
    # would have thrown away.
    #
    # Raises rather than returning half a job : the caller's rescue aborts the
    # whole operation, which is the only safe outcome once the model has been
    # touched.
    def _prepare_panels!(panel_defs)
      container_path = panel_defs.first.container_path.dup
      opening_def = panel_defs.first.opening_def

      extension_defs = _cut_extension_defs(opening_def, _get_opening_transformation(opening_def).inverse)
      host_defs = _cut_host_defs(panel_defs, extension_defs)

      groove_index_paths = host_defs.reject { |_host_index_path, crossed| crossed }.map { |host_index_path, _crossed| host_index_path }

      # Worth saying only when a groove was ASKED for and nothing borders the
      # panel at the depth it sits at : the panel is then loose in its mouth,
      # which is not what the options describe. A CROSSING never gets here - it
      # raises rather than quietly failing.
      delta = _cut_growth_delta
      if !delta.nil? && delta > 0 && groove_index_paths.empty?
        @tool.notify_warnings([ [ "tool.smart_build.warning.no_#{_panel_i18n_key_suffix}_machining" ] ])
      end

      return container_path if host_defs.empty?

      # The container first : it is the ancestor every host hangs under, and
      # separating it after them would strand the cut in the definition nobody
      # sees any more.
      _make_unique_instances_in_path(container_path)

      _subtract_panel_cut!(container_path, opening_def, host_defs)

      # The cavities were read on entities a separation may have replaced, and
      # so was the active part : both are dropped rather than left pointing at
      # geometry nobody sees any more. The next pick pays for a detection again,
      # and only in that case.
      _reset_cavities_def
      _reset_active_part

      container_path
    end

    # Subtracts the cut from the given parts (see #_cut_host_defs). Answers how
    # many parts were handed to it.
    #
    # ONCE per part, and that is not a convenience : a cut chained with a
    # second one leaves zero-thickness membranes along the planes the two
    # share, at the ends of any part they both touch, on every carcass that is
    # not aligned to the world axes. One solid per part, one operation, no seam.
    #
    # In PASSES, though, over sets of parts that never meet : the parts a
    # groove runs THROUGH (see #_cut_extension_defs) are cut by a contour that
    # spills past their faces onto their neighbours, and those neighbours must
    # not be cut by it - they take the plain contour, or the contour of a pass
    # of their own when a groove runs through them too (see
    # #_cut_pass_groups).
    #
    # The CROSSED parts come out SEVERED - the panel passes right through them
    # - and the piece left standing behind the panel is dropped, which is what
    # ends them at the panel.
    def _subtract_panel_cut!(container_path, opening_def, host_defs)
      return 0 if host_defs.empty?

      count = 0
      host_defs.group_by { |_host_index_path, _crossed, pass| pass }.sort_by(&:first).each do |_pass, pass_host_defs|
        count += _subtract_panel_cut_pass!(container_path, opening_def, pass_host_defs.map(&:first), pass_host_defs.first[3], pass_host_defs.select { |_host_index_path, crossed| crossed }.map(&:first))
      end

      _drop_offcuts!(container_path, opening_def, host_defs.select { |_host_index_path, crossed| crossed }.map(&:first))

      count
    end

    # One pass of #_subtract_panel_cut! : the cut built on the grown mouths
    # united with +extension_paths+, subtracted from the parts at
    # +host_index_paths+. The parts are found again by POSITION, which is what
    # survives the previous pass rebuilding its own.
    #
    # A part the panel only GROOVES - one not in +crossed_index_paths+ - has to
    # come out of the cut in as many pieces as it went in. One that does not
    # has been cut right through, and not by a panel spanning it : by grooves
    # meeting inside it, two backs let 10 mm into either side of a 19 mm stile,
    # or by a groove deeper than the part is thick. That is no joint anyone can
    # machine, and nothing would ever show it - each piece is a sound solid -
    # so the batch is REFUSED, naming the parts. Read on the computed result,
    # before anything of the boolean is written, which then applies that very
    # result.
    def _subtract_panel_cut_pass!(container_path, opening_def, host_index_paths, extension_paths, crossed_index_paths = [])
      return 0 if host_index_paths.empty?

      cut_group = _build_panel_cut_group(container_path, opening_def, extension_paths)
      return 0 if cut_group.nil?

      src_ipaths = []
      src_crossed = []
      host_index_paths.each do |host_index_path|
        host_path = _descendant_path(container_path, host_index_path)
        next if host_path.nil? || !host_path.last.respond_to?(:definition)
        src_ipaths << Sketchup::InstancePath.new(host_path)
        src_crossed << crossed_index_paths.include?(host_index_path)
      end
      if src_ipaths.empty?
        cut_group.erase!
        return 0
      end

      src_drawing_defs = _decompose_for_solid_boolean(src_ipaths)
      cut_drawing_defs = _decompose_for_solid_boolean([ Sketchup::InstancePath.new(container_path + [ cut_group ]) ])
      raise "Unable to read the parts the #{_panel_i18n_key_suffix} runs into" unless (src_drawing_defs + cut_drawing_defs).all? { |drawing_def| drawing_def.is_a?(DrawingDef) }

      result_def = CommonSolidBooleanWorker.new(src_drawing_defs, cut_drawing_defs, operation: CommonSolidBooleanWorker::OPERATION_SUBTRACTION).run
      raise "Unable to cut the parts the #{_panel_i18n_key_suffix} runs into : #{result_def.errors.inspect}" unless result_def.success?

      severed_names = []
      src_drawing_defs.each_with_index do |drawing_def, index|
        next if src_crossed[index]
        next unless result_def.fragment_defs.count { |fragment_def| fragment_def.src_indices.include?(index) } > _drawing_def_shell_count(drawing_def)
        container = drawing_def.container
        severed_names << (container.respond_to?(:definition) ? container.definition.name : container.name)
      end
      unless severed_names.empty?
        cut_group.erase!   # The abort takes it back too, but nothing of a refused batch is left standing on the way there
        raise RefusedError.new([ [ "tool.smart_build.error.#{_panel_i18n_key_suffix}_severs_parts", { :names => severed_names.uniq.join(', ') } ] ])
      end

      result_def = _apply_solid_boolean(
        src_drawing_defs,
        cut_drawing_defs,
        operation: CommonSolidBooleanWorker::OPERATION_SUBTRACTION,
        keep_cuts: false,
        result_def: result_def
      )
      raise "Unable to cut the parts the #{_panel_i18n_key_suffix} runs into : #{result_def.errors.inspect}" unless result_def.success?

      src_ipaths.length
    end

    # How many separate solids the given part is made of - its connected sets
    # of triangles, read on the mesh the boolean itself is fed with.
    def _drawing_def_shell_count(drawing_def)
      mesh_def = SolidMeshDef.from_drawing_def(drawing_def)
      return 0 if mesh_def.nil? || mesh_def.empty?

      parent = (0...mesh_def.vertex_count).to_a
      fn_find = lambda { |index|
        index = parent[index] = parent[parent[index]] while parent[index] != index
        index
      }
      mesh_def.face_indices.each_slice(3) do |a, b, c|
        root = fn_find.call(a)
        [ b, c ].each { |vertex| other = fn_find.call(vertex) ; parent[other] = root unless other == root }
      end

      mesh_def.face_indices.map { |index| fn_find.call(index) }.uniq.length
    end

    # The parts the cut is to be subtracted from : each as the chain of
    # POSITIONS leading to it from the cavity container - read before anything
    # is written, because a separation replaces the entities on the way - and
    # whether the panel CROSSES it rather than merely biting into it, and the
    # PASS it is cut in with the extension paths of that pass : pass 0 and none
    # for a part no groove runs through, see #_cut_pass_groups for the others.
    #
    # A part makes the list only when the cut really reaches it : it stands at
    # the depth the panel sits at, AND its footprint meets the cut's contour.
    # That second test is what keeps the list tight, and it matters - the
    # worker rebuilds every src it is given, changed by the operation or not.
    def _cut_host_defs(panel_defs, extension_defs)
      return [] if _fetch_option_overlay_full_overlay?
      return [] unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      opening_def = panel_defs.first.opening_def
      ti = _get_opening_transformation(opening_def).inverse

      cut_paths = _cut_contour_paths(opening_def, ti, extension_defs.map(&:last))
      return [] if cut_paths.nil? || cut_paths.empty?

      slot = _cut_slot_range(opening_def)
      return [] if slot.nil?

      # The parts the panel runs STRAIGHT ACROSS, over a merge : told apart
      # here, once, because what ends them is not the cut but the drop that
      # follows it.
      crossed_drawing_defs = _get_crossed_drawing_defs(_merge_share_paths, opening_def, ti)

      host_defs = []
      host_drawing_defs = []
      _cut_slot_drawing_defs(cavities_def, slot, ti).each do |drawing_def|

        host_index_path = _entity_index_path(cavities_def.container_path, drawing_def.container_path)
        next if host_index_path.nil? || host_index_path.empty?

        host_paths = _get_panel_footprint_paths(drawing_def, opening_def, ti)
        next if host_paths.nil? || host_paths.empty?

        # Sized at the MERGE TOLERANCE, not at PANEL_MIN_WIDTH : what is being
        # measured here is not a panel but the footprint of a GROOVE, and a
        # groove is exactly #_cut_growth_delta wide by construction - 5 mm by
        # default, which is PANEL_MIN_WIDTH itself. Put through the panel gate,
        # every groove asked for at that depth or less erodes to nothing and
        # NO part is ever found to border the panel.
        #
        # All this has to reject is a contact WITHOUT overlap - a footprint
        # merely touching the contour along an edge, which is what every part
        # around the mouth gives when the panel is laid on rather than let in
        # (delta 0, the contour being then the mouth itself) - and a contact
        # like that is a region of zero width.
        overlap_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: cut_paths, clips: host_paths)
        next if _clean_pieces(overlap_paths, SolidMeshDef::TOLERANCE).empty?

        host_defs << [ host_index_path, crossed_drawing_defs.any? { |crossed_drawing_def| crossed_drawing_def.equal?(drawing_def) }, 0, [] ]
        host_drawing_defs << drawing_def

      end

      through_drawing_defs = host_drawing_defs.select { |drawing_def| extension_defs.any? { |extension_drawing_def, _path| extension_drawing_def.equal?(drawing_def) } }
      _cut_pass_groups(through_drawing_defs, extension_defs, opening_def, ti).each_with_index do |group, index|
        extension_paths = extension_defs.select { |extension_drawing_def, _path| group.any? { |drawing_def| drawing_def.equal?(extension_drawing_def) } }.map(&:last)
        group.each do |drawing_def|
          host_def = host_defs[host_drawing_defs.index { |host_drawing_def| host_drawing_def.equal?(drawing_def) }]
          host_def[2] = index + 1
          host_def[3] = extension_paths
        end
      end

      host_defs
    end

    # The parts a groove runs THROUGH, gathered into as few passes as can be
    # cut together - see #_subtract_panel_cut!. Two of them share a pass unless
    # the extensions of either SPILL onto the other : the one it lands on would
    # be cut by it. That is the PINWHEEL, where every part covers the end of
    # the next and is covered by the one before ; anywhere else the spills land
    # on parts no groove runs through, and all of them are cut in one pass -
    # which also lets identical stiles keep sharing their definition.
    #
    # Greedy, in the order given : the first pass that has no conflict with a
    # part takes it. A pinwheel of four comes out in two passes.
    def _cut_pass_groups(drawing_defs, extension_defs, opening_def, ti)
      spills_onto = lambda { |from_drawing_def, onto_drawing_def|
        paths = extension_defs.select { |extension_drawing_def, _path| extension_drawing_def.equal?(from_drawing_def) }.map(&:last)
        footprint_paths = _get_panel_footprint_paths(onto_drawing_def, opening_def, ti)
        next false if paths.empty? || footprint_paths.nil? || footprint_paths.empty?
        overlap_paths, _ = Fiddle::Clippy.execute_intersection(closed_subjects: paths, clips: footprint_paths)
        !_clean_pieces(overlap_paths, SolidMeshDef::TOLERANCE).empty?
      }

      groups = []
      drawing_defs.each do |drawing_def|
        group = groups.find { |members| members.none? { |member| spills_onto.call(drawing_def, member) || spills_onto.call(member, drawing_def) } }
        if group.nil?
          groups << [ drawing_def ]
        else
          group << drawing_def
        end
      end
      groups
    end

    # The parts of the carcass that stand where the panel does - at the depth
    # of +slot+ along the opening's normal. The only ones a cut can reach, and
    # the only ones that can hide one.
    #
    # A panel already laid on the carcass is not carcass : nothing is ever cut
    # into another back, or into a front.
    def _cut_slot_drawing_defs(cavities_def, slot, ti)
      cavities_def.drawing_defs.select { |drawing_def|
        next false if LayerAttributes.panel_type?(LayerAttributes.type_of(drawing_def.container))
        z_min, z_max = _drawing_def_plane_extent(drawing_def, ti)
        !z_min.nil? && z_max > slot[0] + SolidMeshDef::TOLERANCE && z_min < slot[1] - SolidMeshDef::TOLERANCE
      }
    end

    # Ends the crossed parts at the panel, for real : the cut SEVERED each of
    # them - it runs right through - and what is left standing on the far side
    # of the panel is material with nowhere to be. Erased. Answers how many
    # pieces came off.
    #
    # Read on the parts' own faces rather than on the operation's result : the
    # worker rebuilds every fragment inside the container it came from, so both
    # pieces of a severed part come back in ONE container, as two sets of
    # connected faces.
    #
    # A part the panel merely grooves is never severed - its single set of
    # faces straddles the slot, so it can never lie wholly beyond it - which
    # makes the test self-selecting. The crossed list is there to keep the
    # sweep off the parts nobody asked about, not to make the test work.
    def _drop_offcuts!(container_path, opening_def, host_index_paths)
      return 0 if host_index_paths.empty?

      slot = _cut_slot_range(opening_def)
      return 0 if slot.nil?

      t = _get_opening_transformation(opening_def)
      # The panel's own far face : everything beyond it, on a part the panel
      # passes through, is what the panel has taken the place of.
      threshold = slot[1] - SolidMeshDef::TOLERANCE

      # One entity collection at a time, sub containers INCLUDED : the worker
      # rebuilds a fragment inside the sub container node its faces came from,
      # so an offcut can land one level down from the part itself.
      fn_sweep = nil
      fn_sweep = lambda { |entities, to_opening|
        dropped = 0

        # Every connected set collected BEFORE anything is erased : erasing one
        # invalidates what a walk in progress is holding.
        seen = {}
        offcuts = []
        entities.grep(Sketchup::Face).each do |face|
          next if seen[face.entityID]
          connected = face.all_connected
          faces = connected.grep(Sketchup::Face)
          faces.each { |f| seen[f.entityID] = true }
          next if faces.empty?
          next unless faces.all? { |f| f.vertices.all? { |vertex| vertex.position.transform(to_opening).z.to_f > threshold } }
          offcuts << connected
        end
        offcuts.each do |connected|
          entities.erase_entities(connected.reject { |entity| entity.deleted? })
          dropped += 1
        end

        entities.to_a.each do |entity|
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          next if entity.deleted?
          dropped += fn_sweep.call(entity.definition.entities, to_opening * entity.transformation)
          # A node the drop emptied is dead weight, but only its own : a
          # definition displayed elsewhere is left alone.
          entity.erase! if entity.definition.entities.length.zero? && entity.definition.instances.length == 1
        end

        dropped
      }

      dropped = 0
      host_index_paths.each do |host_index_path|

        host_path = _descendant_path(container_path, host_index_path)
        raise "Unable to end the parts the #{_panel_i18n_key_suffix} runs across" if host_path.nil? || !host_path.last.respond_to?(:definition)

        # Faces live in their definition's space ; the slot is measured in the
        # opening's.
        dropped += fn_sweep.call(host_path.last.definition.entities, t.inverse * PathUtils.get_transformation(host_path, IDENTITY))

      end
      dropped
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

    # How far the CUT grows beyond the mouth, on every edge. Zero here : a
    # panel laid on its mouth is driven into nothing, so there is nothing of
    # the parts around it to take.
    #
    # A panel let into a GROOVE runs into them by the groove depth, and that
    # is exactly the material the cut has to remove - see
    # SmartBuildBackPanelActionHandler.
    def _cut_growth_delta
      0
    end

    # The contour the CUT is built on, in the opening's frame : every mouth
    # the panel spans, unioned, grown by #_cut_growth_delta.
    #
    # NEITHER intersected with a host's footprint NOR clipped to the container
    # silhouette, and that is the whole point. Both of those stop the contour
    # ON a plane of a part, and a face laid exactly in a plane of the solid it
    # cuts is the one configuration a boolean has to work to resolve. Left
    # whole, the cut runs THROUGH the part it grooves and out the other side
    # into the cavity - or, where the silhouette would have clipped it, into
    # the air outside the carcass, where there is no material left to remove
    # anyway. The contour carries no face of its own on any plane of any part.
    #
    # EVERY mouth, not just the picked one : over a merge, a contour read off
    # a single mouth would leave the other compartments' grooves uncut.
    #
    # United with +extension_paths+, when there are any - see
    # #_cut_extension_defs.
    #
    # Answers nil when there is no contour to cut with.
    def _cut_contour_paths(opening_def, ti, extension_paths = [])
      mouth_paths = _cut_mouth_paths(opening_def, ti)
      return nil if mouth_paths.nil?

      delta = _cut_growth_delta
      return _weld_rpaths(mouth_paths) if delta.nil? || delta <= 0

      # Every path kept, unlike the panel's own contour : a merge of
      # compartments too far apart to grow into one another cuts in two
      # places, and both of them are the cut.
      grown_paths = Fiddle::Clippy.inflate_paths(
        paths: mouth_paths,
        delta: delta.to_f,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      )
      return nil if grown_paths.empty?
      return _weld_rpaths(grown_paths) if extension_paths.empty?

      united_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: grown_paths + extension_paths)
      return _weld_rpaths(grown_paths) if united_paths.empty?

      _weld_rpaths(united_paths)
    end

    # +rpaths+ welded (see #_weld_rpath), those left with fewer than 3 vertices
    # dropped.
    #
    # On EVERY contour the cut is built on, not only an extended one : a union
    # leaves vertices a hair apart wherever several contours meet on one corner
    # - the mouths of a merge and the dividers closing them do, off by a few
    # millionths of an inch - and #add_face refuses any two closer than
    # SketchUp's own tolerance.
    def _weld_rpaths(rpaths)
      rpaths.map { |rpath| _weld_rpath(rpath, SolidMeshDef::TOLERANCE) }.select { |rpath| rpath.length >= 6 }
    end

    # The MOUTHS the cut is grown from, in the opening's frame, unioned - every
    # mouth the panel spans. nil when there is none.
    def _cut_mouth_paths(opening_def, ti)
      raw_mouth_paths = _merge_mouth_paths
      if raw_mouth_paths.empty?
        mouth = opening_def.outer_loop
        return nil if mouth.nil? || mouth.length < 3
        raw_mouth_paths = [ Fiddle::Clippy.points_to_rpath(mouth.map { |point| point.transform(ti) }) ]
      else

        # Over a MERGE, the mouths ALONE are not what the panel covers, and
        # growing them is not enough to make them so : two mouths of
        # neighbouring compartments stand a whole divider apart, and a back's
        # groove is 8 mm deep where a divider is 18 mm thick - the two growths
        # stop 2 mm short of one another and leave the divider standing, with a
        # groove cut in each of its faces. Which is exactly a merge that did not
        # happen.
        #
        # What closes the contour is the divider itself, taken WHOLE - the same
        # way #_merge_nominal_points closes the PANEL's own outline, and
        # necessarily so : the panel and the cut are one shape, and this is
        # where they have to agree on it.
        raw_mouth_paths += _get_crossed_drawing_defs(_merge_share_paths, opening_def, ti).flat_map { |drawing_def| _get_panel_footprint_paths(drawing_def, opening_def, ti) || [] }

      end

      # The union normalizes the winding, and the winding is what decides which
      # side a positive delta grows towards.
      mouth_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: raw_mouth_paths)
      mouth_paths.empty? ? nil : mouth_paths
    end

    # +rpath+ without its vertices closer than +tolerance+ to the previous one
    # kept - the closing pair included.
    def _weld_rpath(rpath, tolerance)
      points = []
      rpath.each_slice(2) do |x, y|
        previous = points.last
        next if !previous.nil? && (x - previous[0]).abs <= tolerance && (y - previous[1]).abs <= tolerance
        points << [ x, y ]
      end
      points.pop while points.length > 1 && (points.last[0] - points.first[0]).abs <= tolerance && (points.last[1] - points.first[1]).abs <= tolerance
      points.flatten(1)
    end

    # What the cut runs on BEYOND the grown mouths, in the opening's frame, as
    # [ [ the part it runs through, its path ], ... ]. Nothing here : a groove
    # stops where its mouth, grown, stops - see SmartBuildBackPanelActionHandler
    # for the one that may not.
    #
    # Read before anything is written, like everything the cut is built from.
    def _cut_extension_defs(opening_def, ti)
      []
    end

    # The slot the panel occupies along the opening's normal : it stands back
    # by the setback and runs inwards by its thickness. [ z_low, z_high ], or
    # nil when there is no slot to speak of.
    #
    # Bounded by the panel and by NOTHING else - no clamp to the part being
    # cut, unlike a machining volume's : a boolean cannot remove what is not
    # there, so keeping the cut inside its host is work the operation already
    # does, and does in 3D rather than on a projection.
    def _cut_slot_range(opening_def)
      thickness = _fetch_option_thickness
      return nil if thickness.nil? || thickness <= 0
      setback = _panel_outline_offset(opening_def).to_f
      [ -setback - thickness.to_f, -setback ]
    end

    # The cut itself, as a throwaway group standing beside the parts it is
    # about to be subtracted from - built, never kept :
    # CommonSolidBooleanApplyWorker consumes it (keep_cuts: false).
    #
    # A COPY of the panel's shape rather than the panel itself, for two reasons
    # that have nothing to do with geometry : the panels are not built yet when
    # the cut is needed - #_prepare_panels! measures everything before the first
    # write, because separating a shared definition invalidates every entity
    # read beforehand - and a copy can be pushed past a face the panel itself
    # has to stop at, which is what a flush pose asks for.
    #
    # Answers the group, or nil when there is nothing to cut with.
    def _build_panel_cut_group(container_path, opening_def, extension_paths = [])
      container = container_path.last
      return nil unless container.respond_to?(:definition)

      t = _get_opening_transformation(opening_def)

      paths = _cut_contour_paths(opening_def, t.inverse, extension_paths)
      return nil if paths.nil? || paths.empty?

      slot = _cut_slot_range(opening_def)
      return nil if slot.nil?

      group = container.definition.entities.add_group
      # Set BEFORE the faces go in, so that they are drawn in the opening's own
      # frame - the very frame the contour was computed in.
      group.transformation = PathUtils.get_transformation(container_path, IDENTITY).inverse * t

      paths.each do |path|
        _build_machining_prism(group.entities, Fiddle::Clippy.rpath_to_points(path), slot[0], slot[1])
      end

      if group.entities.grep(Sketchup::Face).empty?
        group.erase!
        return nil
      end

      group
    end

    # The cut itself : +points+, given in the opening's frame on z = 0, standing
    # up as a prism between +z_low+ and +z_high+. Drawn in a group whose own
    # frame IS the opening's, so the points go in as they are.
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

    # For each panel of the batch, [ the WORLD transformation carrying the
    # panel it is a mirror image of onto it, the index of that one ] - nil for
    # every panel built on its own. None here : a panel is laid the way the
    # mouth gives it, and a mirror it does not have would be a lie in the
    # model (see SmartBuildFrontPanelActionHandler, where a pair of leaves
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
  class SmartBuildFrontPanelActionHandler < SmartBuildMouthPanelActionHandler

    LAYER_2D_MIRROR = 101

    def initialize(tool, previous_action_handler = nil)
      super(SmartBuildTool::ACTION_BUILD_FRONT_PANEL, tool, previous_action_handler)
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
      read = _read_suffixed_offset(tool, text, 'x', SmartBuildTool::ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET)
      read.nil? ? super : read
    end

    # -----

    def _fetch_option_front_panel_offset
      @tool.fetch_action_option_length(@action, SmartBuildTool::ACTION_OPTION_OFFSET, SmartBuildTool::ACTION_OPTION_OFFSET_FRONT_PANEL_OFFSET)
    end

    def _fetch_option_mirror?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_OPTIONS_MIRROR)
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
    def _get_panel_mirror_transformations(panel_defs)
      mirror = _fetch_option_mirror?
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

        k_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(side_by_side ? SmartBuildTool::MIRROR_MOTIF_VERTICAL_PATH : SmartBuildTool::MIRROR_MOTIF_HORIZONTAL_PATH))
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
  #             and the parts around it are GROOVED for it (see
  #             SmartBuildMouthPanelActionHandler#_prepare_panels!). Cutting
  #             into what it did not create is the base's doing now, and a
  #             merged front panel does as much ; a groove is what this
  #             handler adds to it.
  #   OVERLAY : nailed on the back of the carcass, over its whole silhouette.
  #             Nothing is grown, nothing stands back, and nothing is cut : the
  #             pipeline of the mouth panel, unchanged.
  #
  # No CLEARANCE and no MIRROR, unlike a front panel : a back does not have to
  # open, and there is no pair of leaves to reflect.
  class SmartBuildBackPanelActionHandler < SmartBuildMouthPanelActionHandler

    # How far a through groove spills past its host's face onto the neighbour
    # it covers - see #_cut_extension_defs. Ten times the tolerance the solid
    # booleans snap coplanar faces within, so that it is never snapped back.
    THROUGH_GROOVE_SPILL = SolidMeshDef::TOLERANCE * 10

    def initialize(tool, previous_action_handler = nil)
      super(SmartBuildTool::ACTION_BUILD_BACK_PANEL, tool, previous_action_handler)
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

    # READ THROUGH the panels, like the divider : the back closes the far end
    # of the look, so everything laid on the near mouth - a front panel, a
    # drawer front - stands between the cursor and the compartment it is drawn
    # for. Picked off the model, the front panels already drawn would have to be
    # hidden before the carcass could get its back.
    #
    # The compartment still has to be ENTERED by a mouth (see
    # CavitiesDef#pick_ray), and an INSET front panel is no exception : it
    # recedes that mouth to its own back face (see #_cavities_recess_panel_types),
    # which the ray crosses just the same.
    def _snap_point_through_panels?
      true
    end

    # -----

    # Two SUFFIXED lengths here, where a front panel has one : "8x" is the
    # groove DEPTH, "8d" the SETBACK. A bare length is the thickness, as
    # everywhere.
    def _read_panel_lengths(tool, text, view)
      read = _read_suffixed_offset(tool, text, 'x', SmartBuildTool::ACTION_OPTION_GROOVE_DEPTH)
      return read unless read.nil?
      read = _read_suffixed_offset(tool, text, 'd', SmartBuildTool::ACTION_OPTION_GROOVE_SETBACK)
      read.nil? ? super : read
    end

    # -----

    # How deep the panel runs into the parts around its mouth - and so how much
    # WIDER than that mouth it is cut, on every edge.
    def _fetch_option_groove_depth
      @tool.fetch_action_option_length(@action, SmartBuildTool::ACTION_OPTION_GROOVE, SmartBuildTool::ACTION_OPTION_GROOVE_DEPTH)
    end

    # How far the panel stands back from the mouth plane, towards the inside of
    # the carcass - where the groove is cut, and what is left free behind the
    # panel.
    def _fetch_option_groove_setback
      @tool.fetch_action_option_length(@action, SmartBuildTool::ACTION_OPTION_GROOVE, SmartBuildTool::ACTION_OPTION_GROOVE_SETBACK)
    end

    def _fetch_option_groove_through?
      @tool.fetch_action_option_boolean(@action, SmartBuildTool::ACTION_OPTION_OPTIONS, SmartBuildTool::ACTION_OPTION_GROOVE_THROUGH)
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

      depth = _fetch_option_groove_depth
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

    # The GROOVE DEPTH : how far the panel runs into the parts around its
    # mouth, and so exactly how much of them the cut has to take. The same
    # number #_grow_nominal_points grows the PANEL by - the panel and its
    # groove are one shape, read once.
    def _cut_growth_delta
      return 0 if _fetch_option_overlay_full_overlay?
      depth = _fetch_option_groove_depth
      depth.nil? ? 0 : depth
    end

    # The THROUGH GROOVES : a groove that stops inside a part COVERING the end
    # of its neighbour is run on out of that part - the way it is really cut,
    # end to end on a table saw or a spindle moulder, rather than stopped.
    #
    # Read at both ends of every mouth edge, running on along that edge, and
    # kept at an end only when all of this holds :
    #
    #   FLUSH   : the HOST - the part that edge's groove is cut in, read in the
    #             MIDDLE of the edge - runs on out to the
    #             container's silhouette. A stile standing on past the rail, on
    #             a foot, is not flush, nor is one capped by a top : its groove
    #             stays stopped.
    #   HIDDEN  : beside the groove, on the mouth side, stands material at the
    #             depth of the slot all the way to that silhouette - the rail
    #             whose end the host covers. A groove that would run past the
    #             mouth of another compartment, or open onto the gap between two
    #             feet, stays stopped at that end ; the other end may still run
    #             through.
    #
    # Orientation-blind : whichever of a stile or a rail covers the other, the
    # one that does is the one grooved through, and the one covered keeps a
    # groove that stops at its own end - where it already comes out.
    #
    # Only the grooves of THIS back : one an earlier back left stopped is not
    # revisited, the new cut merely runs into it.
    #
    # Each extension SPILLS past its host's face onto the neighbour it covers,
    # by THROUGH_GROOVE_SPILL. Stopped exactly on that face, its side would lie
    # in the very plane of the host's face, facing the same way - the one tie
    # Meshy leaves standing, which it resolves into a zero-thickness membrane
    # across the groove instead of opening it. The neighbour is not cut by it :
    # the host is cut in a pass of its own (see #_subtract_panel_cut! and
    # #_cut_pass_groups).
    def _cut_extension_defs(opening_def, ti)
      return [] unless _fetch_option_groove_through?
      delta = _cut_growth_delta
      return [] if delta.nil? || delta <= 0
      return [] unless (cavities_def = _get_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      mouth_paths = _cut_mouth_paths(opening_def, ti)
      return [] if mouth_paths.nil?

      silhouette_paths = _get_silhouette_paths(opening_def, ti)
      return [] if silhouette_paths.nil? || silhouette_paths.empty?

      slot = _cut_slot_range(opening_def)
      return [] if slot.nil?

      # Each part apart, to tell the host ; all of them together, to tell what
      # covers the groove - two neighbours flush with one another cover it as
      # one.
      part_defs = _cut_slot_drawing_defs(cavities_def, slot, ti).map { |drawing_def|
        [ drawing_def, _get_panel_footprint_paths(drawing_def, opening_def, ti) ]
      }.reject { |_drawing_def, paths| paths.nil? || paths.empty? }
      return [] if part_defs.empty?
      part_paths_list = part_defs.map(&:last)

      cover_paths, _ = Fiddle::Clippy.execute_union(closed_subjects: part_paths_list.flatten(1))
      return [] if cover_paths.empty?

      depth = delta.to_f
      reach = _paths_reach(silhouette_paths)

      # Which side of an edge is OUT of the mouth : the union winds every outer
      # contour one way and every hole the other, so one reading - on the
      # widest contour, necessarily an outer one - holds for all of them.
      side = _rpath_signed_area(mouth_paths.max_by { |path| _rpath_signed_area(path).abs }) > 0 ? 1.0 : -1.0

      extension_defs = []
      mouth_paths.each do |path|
        count = path.length / 2
        next if count < 3

        (0...count).each do |index|
          ax = path[index * 2].to_f
          ay = path[index * 2 + 1].to_f
          bx = path[(index + 1) % count * 2].to_f
          by = path[(index + 1) % count * 2 + 1].to_f
          length = Math.sqrt((bx - ax) ** 2 + (by - ay) ** 2)
          next if length <= SolidMeshDef::TOLERANCE

          ux = (bx - ax) / length
          uy = (by - ay) / length

          # Both ends, each read running AWAY from its edge : the outside of the
          # mouth stays on the same side either way.
          [ [ bx, by, ux, uy ], [ ax, ay, -ux, -uy ] ].each do |ox, oy, dx, dy|
            frame = [ ox, oy, dx, dy, uy * side, -ux * side ]
            run, host_index = _through_groove_run(frame, length / 2.0, depth, reach, part_paths_list, silhouette_paths, cover_paths)
            next if run.nil?

            # On past the silhouette by the depth, for the same reason it
            # spills onto the neighbour : a cut stopped ON the end face of its
            # host would lay a face in a plane of the solid it cuts. Beyond the
            # silhouette there is nothing left of the container to take.
            extension_defs << [ part_defs[host_index].first, _band_rpath(frame, 0.0, run + depth, -THROUGH_GROOVE_SPILL, depth, side > 0) ]
          end
        end
      end

      extension_defs
    end

    # [ how far past the end of its edge the groove runs through - measured
    # from that end, along the edge -, the index of its host in
    # +part_paths_list+ ], or nil when it stops there. +frame+ is the end,
    # the direction running away from the edge and the normal pointing out of
    # the mouth ; +back+ how much of the edge itself is read to find the host.
    # See #_cut_extension_defs.
    #
    # The host is read from the MIDDLE of the edge, and not just before its
    # end : at an acute corner, the groove band already runs into the part
    # standing across it well before the corner - the grown mitre is cut in
    # both - and read there, the stile would pass for the host of the rail's
    # groove, which would then run right through it.
    def _through_groove_run(frame, back, depth, reach, part_paths_list, silhouette_paths, cover_paths)

      # Read on LINES rather than on the band as a whole : a part ending on a
      # bevel, or a silhouette standing askew to the groove, lets one edge of
      # the band run further than the other, and only an edge compared with
      # the same edge says whether they stop together. Each line a hair inside
      # the band, never ON the boundary of a part - which is exactly where its
      # edges lie.
      inset = SolidMeshDef::TOLERANCE

      # FLUSH, on both edges of the groove.
      runs = [ inset, depth - inset ].map { |t|
        line = _band_line(frame, -back, reach, t)
        silhouette_run = _line_run(frame, line, -back, silhouette_paths)
        return nil if silhouette_run.nil?
        host_runs = part_paths_list.map { |part_paths| _line_run(frame, line, -back, part_paths) }
        host_run = host_runs.compact.max
        return nil if host_run.nil? || host_run < silhouette_run - SolidMeshDef::TOLERANCE
        [ silhouette_run, host_runs.index(host_run) ]
      }
      return nil unless runs.first[1] == runs.last[1]   # One host, the same on both edges of the groove
      host_index = runs.first[1]
      runs = runs.map(&:first)

      run = runs.max
      # Out of the carcass within the grown corner already : nothing to add.
      return nil if run <= depth + SolidMeshDef::TOLERANCE

      # HIDDEN, along the side of the groove that faces the neighbour - as far
      # as that side runs in the host. Allowed to fall short by up to the
      # depth, and on both counts for the same reason, the obliqueness of what
      # the line meets : a neighbour meeting the host on a slant starts
      # covering a little past the corner, and stops a little short of where
      # the host does. A groove that would really show falls short by a whole
      # compartment, or a whole foot.
      cover_run = _line_run(frame, _band_line(frame, 0.0, reach, -inset), 0.0, cover_paths, depth)
      return nil if cover_run.nil? || cover_run < runs.first - depth

      [ run, host_index ]
    end

    # How far along +line+ the region of +paths+ it STARTS in runs, measured
    # along +frame+'s direction from its origin - nil when the line does not
    # start in that region, within +slack+ of +start+.
    def _line_run(frame, line, start, paths, slack = SolidMeshDef::TOLERANCE)
      ox, oy, dx, dy = frame
      _, pieces = Fiddle::Clippy.execute_intersection(open_subjects: [ line ], clips: paths)
      run = nil
      pieces.each do |piece|
        runs = (0...piece.length / 2).map { |index| (piece[index * 2] - ox) * dx + (piece[index * 2 + 1] - oy) * dy }
        next if runs.min > start + slack
        run = runs.max if run.nil? || runs.max > run
      end
      run
    end

    # The segment [ +s0+, +s1+ ] along +frame+'s direction, at +t+ along its
    # normal, as an open path.
    def _band_line(frame, s0, s1, t)
      ox, oy, dx, dy, nx, ny = frame
      [ ox + dx * s0 + nx * t, oy + dy * s0 + ny * t, ox + dx * s1 + nx * t, oy + dy * s1 + ny * t ]
    end

    # The rectangle [ +s0+, +s1+ ] along +frame+'s direction by [ +t0+, +t1+ ]
    # along its normal, wound counter clockwise when +positive+, clockwise
    # otherwise - whatever the frame's handedness. United with the grown mouths
    # on NON ZERO, a rectangle not wound the way their outer contours are would
    # cancel out where it overlaps them.
    def _band_rpath(frame, s0, s1, t0, t1, positive = true)
      ox, oy, dx, dy, nx, ny = frame
      rpath = [ [ s0, t0 ], [ s1, t0 ], [ s1, t1 ], [ s0, t1 ] ].flat_map { |s, t| [ ox + dx * s + nx * t, oy + dy * s + ny * t ] }
      (_rpath_signed_area(rpath) > 0) == positive ? rpath : Fiddle::Clippy.reverse_rpath(rpath)
    end

    # The signed area of a closed path, positive when wound counter clockwise.
    def _rpath_signed_area(rpath)
      count = rpath.length / 2
      sum = 0.0
      (0...count).each do |index|
        following = (index + 1) % count
        sum += rpath[index * 2].to_f * rpath[following * 2 + 1].to_f - rpath[following * 2].to_f * rpath[index * 2 + 1].to_f
      end
      sum / 2.0
    end

    # The SETBACK, and only when the panel is let into a groove : one laid on
    # the back of the carcass is laid ON it, there is nothing to stand back
    # from.
    def _panel_outline_offset(opening_def)
      return 0 if _fetch_option_overlay_full_overlay?
      setback = _fetch_option_groove_setback
      setback.nil? || setback <= 0 ? 0 : setback
    end

  end

end
