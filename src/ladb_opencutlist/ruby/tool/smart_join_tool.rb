module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/mass_utils'
  require_relative '../utils/path_utils'
  require_relative '../utils/transformation_utils'
  require_relative '../lib/geometrix/geometrix'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../lib/fiddle/skpy/skpy'
  require_relative '../helper/user_text_helper'
  require_relative '../helper/smart_action_handler_cavities_helper'
  require_relative '../controller/hardware_controller'
  require_relative '../helper/smart_action_handler_door_helper'
  require_relative '../model/door/door_def'
  require_relative '../model/hardware/hardware_descriptor_def'

  class SmartJoinTool < SmartTool

    ACTION_ADD_CONNECTORS = 0
    ACTION_REMOVE_CONNECTORS = 1
    ACTION_ADD_FITTINGS = 2
    ACTION_REMOVE_FITTINGS = 3
    ACTION_ADD_HINGES = 4
    ACTION_REMOVE_HINGES = 5

    ACTION_OPTION_HEIGHT = 'height'
    ACTION_OPTION_OFFSETS = 'offsets'
    ACTION_OPTION_SPACINGS = 'spacings'
    ACTION_OPTION_OPTIONS = 'options'
    ACTION_OPTION_DISTRIBUTION = 'distribution'
    ACTION_OPTION_GEOMETRY = 'geometry'

    ACTION_OPTION_OFFSETS_START_OFFSET = 'start_offset'
    ACTION_OPTION_OFFSETS_END_OFFSET = 'end_offset'

    ACTION_OPTION_SPACINGS_MIN_SPACING = 'min_spacing'
    ACTION_OPTION_SPACINGS_MAX_SPACING = 'max_spacing'

    ACTION_OPTION_OPTIONS_OPPOSITE = 'opposite'
    ACTION_OPTION_OPTIONS_MAKE_UNIQUE = 'make_unique'

    ACTION_OPTION_DISTRIBUTION_FREE = 'free'   # Only one, at the mouse position
    ACTION_OPTION_DISTRIBUTION_AUTO = 'auto'   # Every hardware of the joint

    ACTION_OPTION_GEOMETRY_HARDWARE = 'hardware'   # The HardwareDescriptorDef ref of the hardware laid - the last one picked
    ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME = 'hardware_material_name'
    ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME = 'machining_material_name'
    ACTION_OPTION_GEOMETRY_HARDWARE_LAYER_NAME = 'hardware_layer_name'
    ACTION_OPTION_GEOMETRY_MACHINING_LAYER_NAME = 'machining_layer_name'

    # The user's library folder the hardware descriptors of each type are
    # picked in - its '$OCL/…' counterpart holds the ones shipped with the
    # extension
    HARDWARE_LIBRARY_REFS = {
      HardwareDescriptorDef::TYPE_CONNECTOR => '$LIB/connectors',
      HardwareDescriptorDef::TYPE_FITTING => '$LIB/fittings',
      HardwareDescriptorDef::TYPE_HINGE => '$LIB/hinges',
      HardwareDescriptorDef::TYPE_FACE => '$LIB/faces',
      HardwareDescriptorDef::TYPE_SPAN => '$LIB/spans',
    }.freeze

    ACTIONS = [
      {
        :action => ACTION_ADD_CONNECTORS,
        :options => {
          ACTION_OPTION_DISTRIBUTION => [ ACTION_OPTION_DISTRIBUTION_FREE, ACTION_OPTION_DISTRIBUTION_AUTO ],
          ACTION_OPTION_HEIGHT => [ ACTION_OPTION_HEIGHT ],
          ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
          ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MAKE_UNIQUE ],
        }
      },
      {
        :action => ACTION_REMOVE_CONNECTORS,
        :options => {
          ACTION_OPTION_DISTRIBUTION => [ ACTION_OPTION_DISTRIBUTION_FREE, ACTION_OPTION_DISTRIBUTION_AUTO ],
        }
      },
      # {
      #   :action => ACTION_ADD_FITTINGS,
      #   :options => {
      #     ACTION_OPTION_DISTRIBUTION => [ ACTION_OPTION_DISTRIBUTION_FREE, ACTION_OPTION_DISTRIBUTION_AUTO ],
      #     ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
      #     ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
      #     ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_OPPOSITE, ACTION_OPTION_OPTIONS_MAKE_UNIQUE ],
      #   }
      # },
      # {
      #   :action => ACTION_REMOVE_FITTINGS,
      #   :options => {
      #     ACTION_OPTION_DISTRIBUTION => [ ACTION_OPTION_DISTRIBUTION_FREE, ACTION_OPTION_DISTRIBUTION_AUTO ],
      #     ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_OPPOSITE ],
      #   }
      # },
      {
        :action => ACTION_ADD_HINGES,
        :options => {
          ACTION_OPTION_DISTRIBUTION => [ ACTION_OPTION_DISTRIBUTION_FREE, ACTION_OPTION_DISTRIBUTION_AUTO ],
          ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
          ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MAKE_UNIQUE ],
        }
      },
      {
        :action => ACTION_REMOVE_HINGES,
        :options => {
          ACTION_OPTION_DISTRIBUTION => [ ACTION_OPTION_DISTRIBUTION_FREE, ACTION_OPTION_DISTRIBUTION_AUTO ],
        }
      }
    ].freeze

    # The actions sharing the distribution option : an add action and its
    # remove counterpart
    DISTRIBUTION_SYNC_ACTIONS = [
      [ ACTION_ADD_CONNECTORS, ACTION_REMOVE_CONNECTORS ],
      [ ACTION_ADD_FITTINGS, ACTION_REMOVE_FITTINGS ],
      [ ACTION_ADD_HINGES, ACTION_REMOVE_HINGES ],
    ].freeze

    REMOVE_ACTIONS = [ ACTION_REMOVE_CONNECTORS, ACTION_REMOVE_FITTINGS, ACTION_REMOVE_HINGES ].freeze

    # -----

    def initialize(

      current_action: nil

    )

      super(
        current_action: current_action
      )

    end

    def get_stripped_name
      'join'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_option_status(action, option_group, option)

      case option_group
      when ACTION_OPTION_DISTRIBUTION
        return PLUGIN.get_i18n_string("tool.smart_join.action_#{action}_option_distribution_#{option}_status")
      end

      super
    end

    def get_action_cursor(action)

      case action
      when ACTION_ADD_CONNECTORS
        return SmartCursorManager.cursor_select_join
      end

      super
    end

    def get_action_option_group_title(action, option_group)
      return PLUGIN.get_i18n_string("tool.smart_#{get_stripped_name}.action_remove_option_group_#{option_group}") if REMOVE_ACTIONS.index(action)
      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_ADD_CONNECTORS
        return true
      when ACTION_ADD_FITTINGS
        return true
      when ACTION_ADD_HINGES
        return true
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_DISTRIBUTION
        return true
      end

      super
    end

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_OPPOSITE
          return [ ACTION_ADD_FITTINGS, ACTION_REMOVE_FITTINGS ]
        end
      end

      super
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_HEIGHT
        case option
        when ACTION_OPTION_HEIGHT
          return false
        end
      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET
          return false
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING
          return false
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return true
        end
      end

      super
    end

    # A free distribution lays one hardware : no max spacing. The min spacing
    # still keeps it away from the hardware already there.
    def get_action_option_btn_disabled?(action, option_group, option, free = fetch_action_option_distribution_free?(action))

      case option_group
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MAX_SPACING
          return free
        end
      end

      super(action, option_group, option)
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_DISTRIBUTION
        case option
        when ACTION_OPTION_DISTRIBUTION_FREE
          return Kuix::Label.new('1')
        when ACTION_OPTION_DISTRIBUTION_AUTO
          return Kuix::Label.new('∞')
        end
      when ACTION_OPTION_HEIGHT
        case option
        when ACTION_OPTION_HEIGHT
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_OPPOSITE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0V1M.5,0V.25M.5,.75V1M.5,.375V.625M0,.5H1M.75,.25L1,.5L.75,.75'))
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,.167V.833M.417,.167V.833M0,.333H.583M0,.667H.583M.75,.333L1,.167V.833'))
        end
      end

      super
    end

    def get_action_option_btn_prefix(action, option_group, option)

      case option_group

      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_offsets_start_offset'))
        when ACTION_OPTION_OFFSETS_END_OFFSET
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_offsets_end_offset'))
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_spacings_min_spacing'))
        when ACTION_OPTION_SPACINGS_MAX_SPACING
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_spacings_max_spacing'))
        end
      end

      super
    end

    # The distribution in effect : the stored one, inverted while SHIFT is held
    # - but for typing in the VCB : SHIFT gives the digits of some keyboards.
    def fetch_action_option_distribution_free?(action, shift_down = is_key_shift_down? && !is_vcb_typing?)
      fetch_action_option_boolean(action, ACTION_OPTION_DISTRIBUTION, ACTION_OPTION_DISTRIBUTION_FREE) != shift_down
    end

    # -- Events --

    def onActivate(view)
      super

      # A descriptor written by the hardware editor : picked at once
      @hardware_saved_callback = PLUGIN.add_event_callback(PluginObserver::ON_HARDWARE_SAVED) do |params|
        @action_handler.onToolHardwareSaved(self, params[:ref]) if !@action_handler.nil? && @action_handler.respond_to?(:onToolHardwareSaved)
      end
      @hardware_deleted_callback = PLUGIN.add_event_callback(PluginObserver::ON_HARDWARE_DELETED) do |params|
        @action_handler.onToolHardwareDeleted(self, params[:ref]) if !@action_handler.nil? && @action_handler.respond_to?(:onToolHardwareDeleted)
      end

    end

    def onDeactivate(view)
      super
      PLUGIN.remove_event_callback(PluginObserver::ON_HARDWARE_SAVED, @hardware_saved_callback) unless @hardware_saved_callback.nil?
      @hardware_saved_callback = nil
      PLUGIN.remove_event_callback(PluginObserver::ON_HARDWARE_DELETED, @hardware_deleted_callback) unless @hardware_deleted_callback.nil?
      @hardware_deleted_callback = nil
    end

    def onKeyDown(key, repeat, flags, view)
      _refresh_distribution_btns(!is_vcb_typing?) if is_key_shift?(key)  # SHIFT is known as down only once super is called
      return true if super
      if is_key_alt_or_command?(key)
        case fetch_action
        when ACTION_ADD_CONNECTORS
          push_action(ACTION_REMOVE_CONNECTORS)
        when ACTION_ADD_FITTINGS
          push_action(ACTION_REMOVE_FITTINGS)
        when ACTION_ADD_HINGES
          push_action(ACTION_REMOVE_HINGES)
        end
        return true
      end
      false
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      _refresh_distribution_btns(false) if is_key_shift?(key)
      return true if super
      if is_key_alt_or_command?(key)
        pop_action
        return true
      end
      false
    end

    def onActionChanged(action)

      clear_all_2d
      clear_all_3d

      case action
      when ACTION_ADD_CONNECTORS
        set_action_handler(SmartJoinAddConnectorsActionHandler.new(self))
      when ACTION_REMOVE_CONNECTORS
        set_action_handler(SmartJoinRemoveConnectorsActionHandler.new(self))
      when ACTION_ADD_FITTINGS
        set_action_handler(SmartJoinAddFittingsActionHandler.new(self))
      when ACTION_REMOVE_FITTINGS
        set_action_handler(SmartJoinRemoveFittingsActionHandler.new(self))
      when ACTION_ADD_HINGES
        set_action_handler(SmartJoinAddHingesActionHandler.new(self))
      when ACTION_REMOVE_HINGES
        set_action_handler(SmartJoinRemoveHingesActionHandler.new(self))
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

    # -----

    private

    # Selects the distribution buttons of the current action as the
    # distribution in effect : SHIFT inverts the stored one while held.
    def _refresh_distribution_btns(shift_down)
      action = fetch_action
      free = fetch_action_option_distribution_free?(action, shift_down)
      { ACTION_OPTION_DISTRIBUTION_AUTO => !free, ACTION_OPTION_DISTRIBUTION_FREE => free }.each do |option, selected|
        btn = get_action_option_btn(action, ACTION_OPTION_DISTRIBUTION, option)
        btn.selected = selected if btn.is_a?(Kuix::Button)
      end
      btn = get_action_option_btn(action, ACTION_OPTION_SPACINGS, ACTION_OPTION_SPACINGS_MAX_SPACING)
      btn.disabled = get_action_option_btn_disabled?(action, ACTION_OPTION_SPACINGS, ACTION_OPTION_SPACINGS_MAX_SPACING, free) if btn.is_a?(Kuix::Button)
    end

  end

  class SmartJoinActionHandler < SmartActionHandler

    Skpy = Fiddle::Skpy

    include SmartActionHandlerPartHelper

    # The mouse position of a free hardware along its joint is rounded to this
    # step : the preview - and the propagation it resolves - is not computed
    # again on every pixel.
    FREE_POSITION_STEP = 1.mm

    # The end of the joint a free hardware is measured from sticks until the
    # mouse comes this close to the other one, in pixels.
    FREE_ORIGIN_SWITCH_PIXELS = 20

    COLOR_DEFAULT_HARDWARE_MATERIAL = Sketchup::Color.new('#999999').freeze
    COLOR_DEFAULT_MACHINING_MATERIAL = Sketchup::Color.new('#0068ff').freeze

    COLOR_PART_A = COLOR_PART
    COLOR_PART_B = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)

    COLOR_REF_FACE_A = Kuix::COLOR_MAGENTA.blend(COLOR_PART_A, 0.2).freeze
    COLOR_REF_FACE_B = Kuix::COLOR_MAGENTA.blend(COLOR_PART_B, 0.2).freeze
    COLOR_REF_DARKEN_A = ColorUtils.color_darken(COLOR_REF_FACE_A, 0.4).freeze
    COLOR_REF_DARKEN_B = ColorUtils.color_darken(COLOR_REF_FACE_B, 0.4).freeze

    COLOR_HARDWARE_PREVIEW = Kuix::COLOR_DARK_GREY
    COLOR_HARDWARE_PROPAGATED_PREVIEW = ColorUtils.color_translucent(COLOR_HARDWARE_PREVIEW, 0.3)
    COLOR_MACHINING_PREVIEW = Kuix::COLOR_CYAN
    COLOR_MACHINING_PROPAGATED_PREVIEW = ColorUtils.color_translucent(COLOR_MACHINING_PREVIEW, 0.3)

    COLOR_REMOVE_STROKE_PREVIEW = Kuix::COLOR_RED
    COLOR_REMOVE_STROKE_PROPAGATED_PREVIEW = ColorUtils.color_translucent(Kuix::COLOR_RED, 0.5)
    COLOR_REMOVE_FILL_PREVIEW = ColorUtils.color_translucent(COLOR_REMOVE_STROKE_PREVIEW, 0.3)
    COLOR_REMOVE_FILL_PROPAGATED_PREVIEW = ColorUtils.color_translucent(COLOR_REMOVE_STROKE_PREVIEW, 0.15)

    LAYER_3D_JOIN_PREVIEW = 3
    LAYER_3D_MACHINING_PREVIEW = 4
    LAYER_3D_HARDWARE_PREVIEW = 5
    LAYER_3D_SNAP_POINT_PREVIEW = 6

    LAYER_3D_PART_A_PREVIEW = 10
    LAYER_3D_PART_B_PREVIEW = 20

    LAYER_2D_DIMENSIONS = 100
    LAYER_2D_HARDWARE_LIBRARY = 110

    TRANSFORMATION_FLIP_X = Geom::Transformation.axes(ORIGIN, X_AXIS.reverse, Y_AXIS, Z_AXIS).freeze
    TRANSFORMATION_FLIP_Z = Geom::Transformation.axes(ORIGIN, X_AXIS, Y_AXIS, Z_AXIS.reverse).freeze

    # The frame a primitive along Y is given in - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#axis : [ x, y, z ] -> [ x, z, -y ].
    TRANSFORMATION_AXIS_Y = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS).freeze
    # The one of a mortise along Y whose length goes along Z : [ x, y, z ] -> [ -y, z, -x ].
    TRANSFORMATION_AXIS_Y_LENGTH_Z = Geom::Transformation.axes(ORIGIN, Z_AXIS.reverse, X_AXIS.reverse, Y_AXIS).freeze

    # How far behind the face _get_placement_height looks - toward -Z - off
    # the edge the face may share with the one it finds.
    PLACEMENT_HEIGHT_DEPTH = 0.1.mm

    # No usable hardware picked in the library : nothing can be picked in the
    # model until one is - as SmartBuildModuleActionHandler. The subclasses'
    # states follow.
    STATE_SOURCE = 0

    # The library folder browsed, by action. Remembered for the session only.
    @@hardware_dir_refs = {}

    # The descriptors listed in the library bar, by path : [ mtime, HardwareDescriptorDef ].
    # Kept across handlers to read a file only once while it is unchanged.
    @@listed_hardware_descriptor_defs = {}

    # -----

    def initialize(action, tool, previous_action_handler = nil)
      super

      # Create 3D layers
      tool.create_3d(LAYER_3D_PART_A_PREVIEW)
      tool.create_3d(LAYER_3D_PART_B_PREVIEW)
      tool.create_3d(LAYER_3D_JOIN_PREVIEW)
      tool.create_3d(LAYER_3D_MACHINING_PREVIEW)
      tool.create_3d(LAYER_3D_HARDWARE_PREVIEW)
      tool.create_3d(LAYER_3D_SNAP_POINT_PREVIEW)

      # The hardware library bar, for the actions that lay hardware
      @hardware_library_panel = _get_hardware_types.empty? ? nil : SmartLibraryPanel.new(tool, LAYER_2D_HARDWARE_LIBRARY, "smart_join_hardware_#{action}")

    end

    # -----

    def start
      _setup_hardware_library_panel
      super
    end

    def stop
      @tool.hide_status
      super
    end

    # -- STATE --

    def get_startup_state
      _hardware_missing? ? STATE_SOURCE : _get_select_state
    end

    def get_state_picker(state)
      return nil if state == STATE_SOURCE
      SmartPicker.new(tool: @tool, observer: self, pick_point: true, drawable: false, lockable: false)
    end

    def get_state_status(state)
      return PLUGIN.get_i18n_string('tool.smart_join.select_hardware_status') + '.' if state == STATE_SOURCE
      super +
        ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + @tool.get_action_option_status(@action, SmartJoinTool::ACTION_OPTION_DISTRIBUTION, _fetch_option_distribution_free? ? SmartJoinTool::ACTION_OPTION_DISTRIBUTION_AUTO : SmartJoinTool::ACTION_OPTION_DISTRIBUTION_FREE) + '.'
    end

    def get_state_vcb_label(state)
      return PLUGIN.get_i18n_string('tool.default.vcb_distance') if state != STATE_SOURCE && _fetch_option_distribution_free? && !SmartJoinTool::REMOVE_ACTIONS.include?(@action)
      super
    end

    # -----

    def onPickerChanged(picker, view)
      _pick_part(picker, view)
      super
    end

    # Nothing in progress : unpicks the hardware, back to STATE_SOURCE - as
    # SmartBuildModule unpicks its file.
    def onToolCancel(tool, reason, view)
      super
      _deselect_hardware if !@hardware_library_panel.nil? && @state != STATE_SOURCE && @state == get_startup_state
    end

    def onStateChanged(old_state, new_state)
      super
      if new_state == STATE_SOURCE
        @tool.show_status(get_state_status(new_state))
      else
        @tool.hide_status
      end
    end

    # A descriptor written by the hardware editor : picked if the action lays
    # its type - its files may have changed, even if it already was.
    def onToolHardwareSaved(tool, ref)
      return if @hardware_library_panel.nil?
      _select_hardware(ref)
      onToolGlobalPresetChanged(tool, nil, nil)
      _setup_hardware_library_panel   # The new file listed
      _restart
    end

    # Unpicked by the delete worker if it was : the list follows.
    def onToolHardwareDeleted(tool, ref)
      return if @hardware_library_panel.nil?
      onToolGlobalPresetChanged(tool, nil, nil)
      _setup_hardware_library_panel
      _restart
    end

    def onToolGlobalPresetChanged(tool, dictionary, section)
      @geometries_def = nil
      _update_hardware_library_panel_selection  # The picked descriptor may have changed with the preset
      _update_hardware_state
      _refresh
      if @state != STATE_SOURCE  # The SHIFT status and the VCB label follow the distribution
        Sketchup.set_status_text(get_state_status(@state), SB_PROMPT)
        Sketchup.set_status_text(get_state_vcb_label(@state), SB_VCB_LABEL)
      end
    end

    # -----

    protected

    # -----

    def _start_with_model_selection?
      false
    end

    def _clear_selection_on_start?
      true
    end

    # -----

    # The state the work starts in, once a hardware is picked.
    def _get_select_state
      raise NotImplementedError
    end

    # -----

    def _preview_all_instances?
      false
    end

    # -----

    def _reset
      super
      _setup_hardware_library_panel  # Cleared with all the 2D layers
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      return [ false, 'tool.smart_join.error.not_assemblable' ] if part.is_a?(Part) && part.group.material_type == MaterialAttributes::TYPE_HARDWARE
      super
    end

    # -----

    def _get_drawing_def_parameters
      {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: true,
        ignore_soft_edges: true,
        ignore_clines: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS
      }
    end

    # -----

    def _read_measure(tool, text, option_group, option, error_key, length_only: false)

      if !length_only && text.start_with?('/')

        divider = text[1..-1].gsub(',', '.').to_f
        if divider <= 0
          tool.notify_errors([[ error_key, { :value => text } ]])
          return true
        end
        divider = divider.to_i if divider.to_i == divider
        measure = "/#{divider.to_s.sub('.', DimensionUtils.decimal_separator)}"

      else

        measure = _read_user_text_length(tool, text)
        return true if measure.nil?

        if measure < 0
          tool.notify_errors([[ error_key, { :value => measure } ]])
          return true
        end

        measure = DimensionUtils.d_add_units(measure.to_s)

      end

      @tool.store_action_option_value(@action, option_group, option, measure.to_s, fire_event: true)

      false
    end

    # -----

    def _fetch_option_height
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT)
    end

    def _fetch_option_start_offset
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET)
    end

    def _fetch_option_end_offset
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET)
    end

    def _fetch_option_min_spacing
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING)
    end

    def _fetch_option_max_spacing
      @tool.fetch_action_option_factor_or_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING)
    end

    def _fetch_option_opposite?
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_OPPOSITE)
    end

    def _fetch_option_make_unique?
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE)
    end

    # SHIFT held included - see SmartJoinTool#fetch_action_option_distribution_free?
    def _fetch_option_distribution_free?
      @tool.fetch_action_option_distribution_free?(@action)
    end

    def _fetch_option_hardware
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE)
    end

    # The geometries of the picked hardware descriptor's components
    def _fetch_option_hardware_a
      _get_hardware_component_ref(:a, :hardware)
    end

    def _fetch_option_hardware_b
      _get_hardware_component_ref(:b, :hardware)
    end

    def _fetch_option_machining_a
      _get_hardware_component_ref(:a, :machining)
    end

    def _fetch_option_machining_b
      _get_hardware_component_ref(:b, :machining)
    end

    def _fetch_option_hardware_material_name
      if (descriptor = _get_hardware_descriptor_def) && (material = descriptor.hardware_material)
        return material
      end
      name = @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME)
      return PLUGIN.get_i18n_string('tab.materials.type_5') if !name.is_a?(String) || name.strip.empty?
      name
    end

    def _fetch_option_machining_material_name
      name = @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME)
      return PLUGIN.get_i18n_string('tab.materials.type_7') if !name.is_a?(String) || name.strip.empty?   # Same default as the BXF2 importer
      name
    end

    def _fetch_option_hardware_layer_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_LAYER_NAME)
    end

    def _fetch_option_machining_layer_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_LAYER_NAME)
    end

    # -- Free distribution --

    # SHIFT inverts the distribution while held : the statuses and the preview
    # follow. The pick is replayed rather than refreshed : the active part
    # has to survive the SHIFT that types the digits of some keyboards in the
    # VCB, without a mouse move to pick it again.
    def _on_shift_changed
      return if @tool.is_vcb_typing?
      Sketchup.set_status_text(get_state_status(@state), SB_PROMPT)
      Sketchup.set_status_text(get_state_vcb_label(@state), SB_VCB_LABEL)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      onPickerChanged(@picker, Sketchup.active_model.active_view) if @picker.is_a?(SmartPicker)
    end

    # The position of 'point' along a joint running from 'origin' in
    # 'direction', rounded to FREE_POSITION_STEP. nil without a point.
    def _get_free_position(origin, direction, point)
      return nil unless origin.is_a?(Geom::Point3d) && point.is_a?(Geom::Point3d)
      position = (point - origin) % direction.normalize
      ((position / FREE_POSITION_STEP).round * FREE_POSITION_STEP).to_l
    end

    # Whether the mouse at 'point' is close enough to 'end_point' to measure
    # from it - see FREE_ORIGIN_SWITCH_PIXELS.
    def _is_free_origin_switch?(point, end_point)
      point.distance(end_point) <= Sketchup.active_model.active_view.pixels_to_model(FREE_ORIGIN_SWITCH_PIXELS, end_point)
    end

    # Length#== raises against nil : positions are compared as floats.
    def _same_free_position?(position_1, position_2)
      return position_1.nil? && position_2.nil? if position_1.nil? || position_2.nil?
      position_1.to_f == position_2.to_f
    end

    # The [ min, max ] coords a free hardware may take on a joint of
    # 'total_length' : between the offsets, and far enough from the ends for
    # the hardware to fit. nil when there is no room.
    def _get_free_range(total_length, start_offset_length, end_offset_length, half_width)
      min = [ start_offset_length, half_width ].max
      max = total_length - [ end_offset_length, half_width ].max
      return nil if min > max
      [ min, max ]
    end

    # The coord of the one hardware laid at 'position' : held in the free
    # range - see #_get_free_range. nil when there is no room.
    def _get_free_coord(position, total_length, start_offset_length, end_offset_length, half_width)
      return nil if (range = _get_free_range(total_length, start_offset_length, end_offset_length, half_width)).nil?
      [ [ position, range.first ].max, range.last ].min
    end

    # Whether 'coord' stands closer than the min spacing to one of the
    # 'existing_coords' - the hardware already on the joint.
    def _is_free_coord_too_close?(coord, existing_coords)
      min_spacing = _fetch_option_min_spacing.to_f
      return false unless min_spacing > 0
      existing_coords.any? { |existing_coord| (existing_coord.to_f - coord.to_f).abs < min_spacing - 0.01.mm.to_f }
    end

    # The bounds of the free range, marked as the distributed anchors are,
    # and the point the free position is measured from.
    def _preview_free_range_bounds(join_def)

      @tool.append_3d(_create_floating_points(
                        points: [ join_def.start_point_3d, join_def.end_point_3d ],
                        style: Kuix::POINT_STYLE_PLUS,
                        stroke_color: Kuix::COLOR_MAGENTA
                      ), LAYER_3D_JOIN_PREVIEW)

      return unless join_def.origin_point_3d.is_a?(Geom::Point3d)

      @tool.append_3d(_create_floating_points(
                        points: join_def.origin_point_3d,
                        style: Kuix::POINT_STYLE_CIRCLE,
                        fill_color: Kuix::COLOR_MAGENTA,
                        stroke_color: nil,
                        size: 1.5
                      ), LAYER_3D_JOIN_PREVIEW)

    end

    # Shows the position of the free hardware at 'point', from 'origin' : in
    # the VCB, and in a label on the laying line - through 'point' along
    # 'direction' - centered between 'point' and the projection of 'origin'.
    # The origin of the connectors, a vertex of the active edge, stands off
    # that line by the height.
    def _preview_free_position(origin, direction, point)

      direction = direction.normalize
      position = ((point - origin) % direction).to_l

      Sketchup.set_status_text(position.to_s, SB_VCB_VALUE)

      return unless position > 0

      @tool.append_2d(_create_floating_label(
                        snap_point: point.offset(direction.reverse, position / 2),
                        text: position,
                        text_color: Kuix::COLOR_MAGENTA,
                        border_color: Kuix::COLOR_MAGENTA
                      ), LAYER_2D_DIMENSIONS)

    end

    # A position typed while free : lays one hardware there, from the origin of
    # the hovered joint - see #_add_at_free_position. false when the text is
    # not one position.
    def _read_free_position(tool, text, view)
      return false unless _fetch_option_distribution_free?
      return false if _split_user_text(text).length > 1  # Measures

      position = _read_user_text_length(tool, text, @free_position.nil? ? 0 : @free_position)
      return true if position.nil?

      @typed_free_position = position
      _add_at_free_position
      @typed_free_position = nil
      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    def _add_at_free_position
    end

    # -- Hardware --

    # The types of hardware descriptor the action lays - see
    # HardwareDescriptorDef::TYPES.
    def _get_hardware_types
      []
    end

    # The library folder the action's descriptors are picked in : the one of
    # its first type.
    def _get_hardware_library_ref
      SmartJoinTool::HARDWARE_LIBRARY_REFS[_get_hardware_types.first]
    end

    # Is a hardware descriptor picked - usable or not ?
    def _hardware?
      ref = _fetch_option_hardware
      ref.is_a?(String) && !ref.strip.empty?
    end

    # The picked hardware descriptor, nil when there is none or it can't be
    # used - the error is notified once. Read again when its file changes.
    def _get_hardware_descriptor_def
      return nil unless _hardware?
      ref = _fetch_option_hardware
      path = PLUGIN.resolve_library_ref(ref)
      key = [ ref, path.is_a?(String) && File.file?(path) ? File.mtime(path) : nil ]
      # Its parents' files too - see HardwareDescriptorDef#stale?
      return @hardware_descriptor_def if @hardware_descriptor_def_key == key && (@hardware_descriptor_def_loaded.nil? || !@hardware_descriptor_def_loaded.stale?)
      @hardware_descriptor_def_key = key
      @hardware_descriptor_def = @hardware_descriptor_def_loaded = HardwareDescriptorDef.load(path)
      if @hardware_descriptor_def.nil?
        @tool.notify_errors([ [ 'tool.smart_join.error.failed_to_load_hardware', { file: ref } ] ])
      elsif @hardware_descriptor_def.abstract?
        @tool.notify_errors([ [ 'tool.smart_join.error.invalid_hardware', { file: ref, error: 'abstract descriptor' } ] ])
        @hardware_descriptor_def = nil
      elsif !@hardware_descriptor_def.valid?
        @tool.notify_errors([ [ 'tool.smart_join.error.invalid_hardware', { file: ref, error: @hardware_descriptor_def.errors.first } ] ])
        @hardware_descriptor_def = nil
      elsif !_get_hardware_types.include?(@hardware_descriptor_def.type)
        @tool.notify_errors([ [ 'tool.smart_join.error.unsupported_hardware_type', { name: @hardware_descriptor_def.name, type: @hardware_descriptor_def.type } ] ])
        @hardware_descriptor_def = nil
      end
      @hardware_descriptor_def
    end

    # Picks the given hardware descriptor ref : its options become the
    # action's, where the action has them. Returns false if the descriptor
    # can't be used.
    def _select_hardware(ref)
      descriptor = HardwareDescriptorDef.load(ref)
      return false if descriptor.nil? || descriptor.abstract? || !descriptor.valid? || !_get_hardware_types.include?(descriptor.type)
      action_def = @tool.get_action_defs.find { |action_def| action_def[:action] == @action }
      option_groups = action_def.nil? || action_def[:options].nil? ? {} : action_def[:options]
      descriptor.options.each do |name, value|
        option_group, _ = option_groups.find { |_, options| options.include?(name) }
        @tool.store_action_option_value(@action, option_group, name, value) unless option_group.nil?
      end
      @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE, ref, fire_event: true)
      true
    end

    # Unpicks the hardware : nothing can be laid until another one is picked.
    def _deselect_hardware
      @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE, nil, fire_event: true)
    end

    # The measures the variants of the hardware components are selected by -
    # see HardwareDescriptorDef#resolve_component.
    def _get_hardware_context
      {}
    end

    def _get_hardware_component(slot)
      return nil if (descriptor = _get_hardware_descriptor_def).nil?
      descriptor.resolve_component(slot, _get_hardware_context)
    end

    # The ref of the given part - :hardware or :machining - of the given slot's
    # component. nil for a machining given as primitives - see
    # _get_hardware_component_primitives.
    def _get_hardware_component_ref(slot, part)
      return nil if (component = _get_hardware_component(slot)).nil?
      ref = component.send(part)
      ref.is_a?(String) ? ref : nil
    end

    # The primitives of the given part - :hardware or :machining - of the
    # given slot's component when it is given as such, nil otherwise.
    def _get_hardware_component_primitives(slot, part)
      return nil if (component = _get_hardware_component(slot)).nil?
      primitives = component.send(part)
      HardwareDescriptorDef.primitives?(primitives) ? primitives : nil
    end

    # The name the definition of the given part - :hardware or :machining - of
    # the given slot's component gets in the model, the one of the part in the
    # cut list : the component's name - or its variant's own one - then its
    # variant and part - "Charnière Clip Top (En applique, Usinage)". Without
    # a name, the hardware's one - the slot told for other slots than the
    # first : "Mine (b, Usinage)". A linked part is named after the slot it
    # comes from. nil when there is no such component.
    def _get_hardware_definition_name(slot, part)
      return nil if (descriptor = _get_hardware_descriptor_def).nil?
      return nil if (component = _get_hardware_component(slot)).nil?
      source_slot = (component.source_slot || slot).to_s
      part_slot = component.part_slots[part.to_s]
      return _get_hardware_definition_name(part_slot, part) if !part_slot.nil? && part_slot != source_slot  # A linked part : the file - and the definition - of another slot
      details = []
      name = component.variant_name || component.name
      if !name.is_a?(String) || name.strip.empty?
        name = descriptor.name
        details << source_slot unless source_slot == descriptor.slots.first
      end
      if !component.variant.nil? && component.variant_name.nil?
        details << PLUGIN.get_i18n_string("core.hardware_descriptor.variant_#{component.variant}").sub(/\Acore\.hardware_descriptor\.variant_/, '')  # Unknown variants by their key
      end
      details << PLUGIN.get_i18n_string('core.hardware_descriptor.part_machining') if part == :machining
      details.empty? ? name.strip : "#{name.strip} (#{details.join(', ')})"
    end

    # Gives the given definition the given name - made unique. Left as is when
    # it already has it, possibly made unique.
    def _name_hardware_definition(model, definition, name)
      return unless definition.is_a?(Sketchup::ComponentDefinition) && name.is_a?(String) && !name.empty?
      return if definition.name == name || definition.name =~ /\A#{Regexp.escape(name)}#\d+\z/
      unique_name = name
      index = 1
      unique_name = "#{name}##{index += 1}" until model.definitions[unique_name].nil?  # Not unique_name : it eats a trailing number - "M8" -> "M#2"
      definition.name = unique_name
    end

    # Gives the given hardware definition the attributes of the given slot's
    # component of the picked descriptor, and what the cut list reads :
    # description, price, url, mass. The definition is shared by every
    # occurrence : the attributes of the last one laid are those of all.
    def _write_hardware_attributes(definition, slot)
      return unless definition.is_a?(Sketchup::ComponentDefinition)
      return if (component = _get_hardware_component(slot)).nil?
      _write_component_attributes(definition, component)
      definition.description = component.description if component.description.is_a?(String) && definition.description != component.description
      unless component.price.nil?
        price = component.price.is_a?(Numeric) ? component.price.round(4).to_s : component.price.to_s
        definition.set_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, Plugin::SU_PRICE_ATTRIBUTE_KEY, price)
      end
      definition.set_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Url', component.url) if component.url.is_a?(String)
      unless component.mass.nil?
        mass = component.mass.is_a?(Numeric) ? "#{component.mass} #{MassUtils::UNIT_SYMBOL_KILOGRAM}" : component.mass.to_s  # A number in kg
        definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'mass', mass)
      end
    end

    # -- Hardware library --

    # The action lays hardware, and none usable is picked : nothing can be
    # picked in the model until one is, in the library bar.
    def _hardware_missing?
      !@hardware_library_panel.nil? && _get_hardware_descriptor_def.nil?
    end

    # To STATE_SOURCE - dropping what was picked - when the hardware went
    # missing, out of it when it is back.
    def _update_hardware_state
      if _hardware_missing?
        return if @state == STATE_SOURCE
        _reset
        set_state(STATE_SOURCE) unless @state == STATE_SOURCE  # The subclass' reset may have done it
      elsif @state == STATE_SOURCE
        set_state(get_startup_state)
      end
    end

    # The bottom bar : the browsed folder of the hardware library, its sub
    # folders and the descriptors the action lays - led by the picked one
    # when it is gone or can't be used.
    def _setup_hardware_library_panel
      return if @hardware_library_panel.nil?
      selected_ref = _hardware? ? _fetch_option_hardware : nil
      dir_ref = _get_hardware_library_dir_ref
      files = []
      if !selected_ref.nil? && _get_listed_hardware_descriptor_def(selected_ref).nil?
        files << SmartLibraryPanel::FileItem.new(selected_ref, File.basename(selected_ref, '.*'), true)
      end
      PLUGIN.list_library_files(dir_ref, '.json').each do |file_ref|
        descriptor = _get_listed_hardware_descriptor_def(file_ref)
        files << SmartLibraryPanel::FileItem.new(file_ref, descriptor.name) unless descriptor.nil?  # The unusable picked one is already in
      end
      @hardware_library_panel.setup(
        root_ref: _get_hardware_library_ref,
        dir_ref: dir_ref,
        selected_ref: selected_ref,
        files: files,
        empty_text: PLUGIN.get_i18n_string('tool.smart_join.warning.no_hardware_file'),
        on_browse: lambda { |ref|
          @@hardware_dir_refs[@action] = ref
          _deselect_hardware  # The pick only lives in its folder
          _restart
        },
        on_select: lambda { |ref|
          if _select_hardware(ref)
            _restart  # What was picked was for the previous hardware
          else
            UI.beep
          end
        },
        add_btn: {
          :selected => false,
          :on_click => lambda {
            HardwareController.show_editor(type: _get_hardware_types.first, dir_ref: dir_ref)
          }
        },
        selected_file_btns: selected_ref.nil? ? [] : [
          {
            :motif => SmartLibraryPanel::MOTIF_EDIT_PATH,
            :tooltip => PLUGIN.get_i18n_string(PLUGIN.library_readonly_ref?(selected_ref) ? 'tool.smart_join.hardware_view' : 'tool.smart_join.hardware_edit'),
            :on_click => lambda { HardwareController.show_editor(ref: selected_ref) }
          }
        ]
      )
    end

    # Picking a descriptor of the browsed folder only moves the selection.
    def _update_hardware_library_panel_selection
      return if @hardware_library_panel.nil?
      selected_ref = _hardware? ? _fetch_option_hardware : nil
      _setup_hardware_library_panel unless @hardware_library_panel.update_selection(selected_ref)
    end

    # The browsed folder : the one of the picked descriptor - a pick only
    # lives in its folder - else the last one browsed while it can still be,
    # else the virtual parent of both libraries.
    def _get_hardware_library_dir_ref
      root_ref = _get_hardware_library_ref
      ref = _hardware? ? _fetch_option_hardware : nil
      dir_ref = ref.nil? ? nil : File.dirname(ref)
      dir_ref = @@hardware_dir_refs[@action] unless SmartLibraryPanel.browsable?(root_ref, dir_ref)
      dir_ref = SmartLibraryPanel::LIBRARIES_REF unless SmartLibraryPanel.browsable?(root_ref, dir_ref)
      @@hardware_dir_refs[@action] = dir_ref
    end

    # The descriptor of the given ref the action can lay, nil if the file is
    # gone, isn't a descriptor, is abstract, invalid or of another type.
    def _get_listed_hardware_descriptor_def(ref)
      path = PLUGIN.resolve_library_ref(ref)
      return nil unless path.is_a?(String) && File.file?(path)
      mtime = File.mtime(path)
      cached = @@listed_hardware_descriptor_defs[path]
      # Its parents' files too - see HardwareDescriptorDef#stale?
      if cached.nil? || cached[0] != mtime || !cached[1].nil? && cached[1].stale?
        @@listed_hardware_descriptor_defs[path] = cached = [ mtime, HardwareDescriptorDef.load(path) ]
      end
      descriptor = cached[1]
      return nil if descriptor.nil? || descriptor.abstract? || !descriptor.valid? || !_get_hardware_types.include?(descriptor.type)
      descriptor
    end

    # -----

    def _get_geometries_def
      return @geometries_def if @geometries_def.is_a?(GeometriesDef) && @geometries_def.valid?

      model = Sketchup.active_model
      model.start_operation('OCL Loading Geometry', true)
      begin

        # A definition loaded from a SKP bears the portable ref of its file
        # and is found by it : its name is the one of the part - see
        # _get_hardware_definition_name - and the files of the components
        # folders are too plainly named - "a.skp" - to be told apart.
        fn_get_definition = lambda do |ref, definition_name|
          return nil if !ref.is_a?(String) || ref.strip.empty?
          ref = PLUGIN.resolve_library_ref(ref)   # '$LIB/…' and '$OCL/…' refs point to a file of a library
          return nil if ref.nil?
          if (extname = File.extname(ref)).downcase == '.skp'
            source = PLUGIN.library_ref_from_path(ref)
            definition = model.definitions.find { |d| d.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE) == source }
            if definition.nil?
              begin

                if Sketchup.version_number < 2100000000
                  skp_version_info = Skpy.get_skp_version_info({ filepath: ref })
                  if skp_version_info['error']
                    raise skp_version_info['error']
                  end
                  if skp_version_info['version_number'] > Sketchup.version_number
                    @tool.notify_errors([
                                          [ 'tool.smart_join.error.failed_to_load_skp_file', { file: ref } ],
                                          [ 'tool.smart_join.error.unsupported_skp_version', { version: skp_version_info['version_label'] } ]
                                        ])
                    return nil
                  end
                end

                existing_definitions = model.definitions.to_a
                definition = Sketchup.version_number >= 2100000000 ? model.definitions.load(ref.gsub('\\', '/'), allow_newer: true) : model.definitions.load(ref.gsub('\\', '/'))
                if definition && existing_definitions.include?(definition) && !definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE).nil?
                  # The load reused a definition already in the model - same
                  # GUID - loaded from another file copied from this one.
                  @tool.notify_warnings([ [ 'tool.smart_join.warning.shared_definition', { file_name: File.basename(ref, extname), definition_name: definition.name } ] ])
                  return definition
                end
                definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_SOURCE, source) unless definition.nil?

              rescue Exception => e
                @tool.notify_errors([ [ 'tool.smart_join.error.failed_to_load_skp_file', { file: ref } ] ])
              end
            end
            _name_hardware_definition(model, definition, definition_name)
          else
            definition = model.definitions[ref]
          end
          definition
        end

        hardware_a_definition = fn_get_definition.call(_fetch_option_hardware_a, _get_hardware_definition_name(:a, :hardware))
        hardware_b_definition = fn_get_definition.call(_fetch_option_hardware_b, _get_hardware_definition_name(:b, :hardware))
        machining_a_definition = fn_get_definition.call(_fetch_option_machining_a, _get_hardware_definition_name(:a, :machining))
        machining_b_definition = fn_get_definition.call(_fetch_option_machining_b, _get_hardware_definition_name(:b, :machining))

        _write_hardware_attributes(hardware_a_definition, :a)
        _write_hardware_attributes(hardware_b_definition, :b)

        fn_get_drawing_def = lambda do |definition|
          return nil if definition.nil?
          CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new([ definition ]) ],
                                               ignore_surfaces: true,
                                               ignore_faces: true,
                                               ignore_edges: false,
                                               ignore_soft_edges: false,
                                               container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL
          ).run
        end

        hardware_a_drawing_def = fn_get_drawing_def.call(hardware_a_definition)
        hardware_b_drawing_def = fn_get_drawing_def.call(hardware_b_definition)
        machining_a_drawing_def = fn_get_drawing_def.call(machining_a_definition)
        machining_b_drawing_def = fn_get_drawing_def.call(machining_b_definition)

        hardware_a_primitives = hardware_a_definition.nil? ? _get_hardware_component_primitives(:a, :hardware) : nil
        hardware_b_primitives = hardware_b_definition.nil? ? _get_hardware_component_primitives(:b, :hardware) : nil
        machining_a_primitives = machining_a_definition.nil? ? _get_hardware_component_primitives(:a, :machining) : nil
        machining_b_primitives = machining_b_definition.nil? ? _get_hardware_component_primitives(:b, :machining) : nil

        fn_get_material = lambda do |ref, default_color = nil, default_type = nil|
          return nil if !ref.is_a?(String) || ref.strip.empty?
          ref = PLUGIN.resolve_library_ref(ref)   # '$LIB/…' and '$OCL/…' refs point to a file of a library
          return nil if ref.nil?
          if File.extname(ref).downcase == '.skm'
            material = model.materials.load(ref)
          else
            material = model.materials[ref]
            if material.nil?
              material = model.materials.add(ref)
              material.color = default_color unless default_color.nil?
              unless default_type.nil?
                ma = MaterialAttributes.new(material)
                ma.type = default_type
                ma.write_to_attributes
              end
            end
          end
          material
        end

        hardware_material = fn_get_material.call(_fetch_option_hardware_material_name, COLOR_DEFAULT_HARDWARE_MATERIAL, MaterialAttributes::TYPE_HARDWARE)
        machining_material = fn_get_material.call(_fetch_option_machining_material_name, COLOR_DEFAULT_MACHINING_MATERIAL, MaterialAttributes::TYPE_MACHINING)

        fn_get_layer = lambda do |ref|
          return nil if !ref.is_a?(String) || ref.strip.empty?
          layer = model.layers[ref]
          if layer.nil?
            layer = model.layers.add(ref)
          end
          layer
        end

        hardware_layer = fn_get_layer.call(_fetch_option_hardware_layer_name)
        machining_layer = fn_get_layer.call(_fetch_option_machining_layer_name)

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
        return nil
      end

      component_a = _get_hardware_component(:a)
      component_b = _get_hardware_component(:b)
      mirror_a = !component_a.nil? && component_a.mirror
      mirror_b = !component_b.nil? && component_b.mirror

      geometries = [
        GeometriesEntityDef.new(hardware_a_definition, hardware_a_drawing_def, hardware_a_primitives, :a, :hardware, mirror_a),
        GeometriesEntityDef.new(hardware_b_definition, hardware_b_drawing_def, hardware_b_primitives, :b, :hardware, mirror_b),
        GeometriesEntityDef.new(machining_a_definition, machining_a_drawing_def, machining_a_primitives, :a, :machining, mirror_a),
        GeometriesEntityDef.new(machining_b_definition, machining_b_drawing_def, machining_b_primitives, :b, :machining, mirror_b),
      ]

      bounds = Geom::BoundingBox.new
      geometries.each do |geometry|
        if geometry.drawing_def
          mt = _get_geometry_mirror_transformation(geometry)
          bounds.add(geometry.drawing_def.bounds.min.transform(mt), geometry.drawing_def.bounds.max.transform(mt))
        elsif geometry.primitives
          bounds.add(_get_primitives_bounds(geometry.primitives, geometry.mirror))
        end
      end

      @geometries_def = GeometriesDef.new(
        *geometries,
        hardware_material,
        machining_material,
        hardware_layer,
        machining_layer,
        bounds,
      )
    end

    # -- Primitives --

    # The bounds of the given primitives in the laying frame, their
    # measures at 0 - what depends on them isn't known yet -, mirrored or not.
    def _get_primitives_bounds(primitives, mirror = false)
      bounds = Geom::BoundingBox.new
      variables = _resolve_hardware_variables(Hash[HardwareDescriptorDef.primitive_variables(primitives).map { |name| [ name, 0.0 ] }])
      HardwareDescriptorDef.primitive_cylinders(primitives, variables).each do |cylinder|
        r = cylinder.radius
        h = cylinder.round? ? r : cylinder.length / 2
        x = cylinder.x
        y = cylinder.y
        if mirror   # Across the YZ plane of the laying frame : its X is the solid's -Y along Z
          cylinder.axis == HardwareDescriptorDef::AXIS_Y_LENGTH_Z ? y = -y : x = -x
        end
        at = _get_primitive_axis_transformation(cylinder.axis)
        bounds.add(Geom::Point3d.new(x - h, y - r, cylinder.z_min).transform(at))
        bounds.add(Geom::Point3d.new(x + h, y + r, cylinder.z_max).transform(at))
      end
      bounds
    end

    # The variables of the hardware at the given placement : the measures its
    # lengths use, taken there - see HardwareDescriptorDef#measures - then its
    # own variables. Cached on the placement.
    def _get_placement_variables(placement)
      return placement.variables unless placement.variables.nil?
      measures = {}
      descriptor = _get_hardware_descriptor_def
      local_thicknesses = {}
      fn_measure = lambda do |target, variable|
        if variable == HardwareDescriptorDef::VARIABLE_THICKNESS
          _get_placement_thickness(target)
        elsif variable == HardwareDescriptorDef::VARIABLE_HEIGHT
          _get_placement_height(target)
        else
          local_thicknesses[target] ||= _get_placement_local_thicknesses(target)
          local_thicknesses[target][variable == HardwareDescriptorDef::VARIABLE_THICKNESS_MIN ? 0 : 1]
        end
      end
      (descriptor.nil? ? [] : descriptor.used_measures).each do |name|
        HardwareDescriptorDef::VARIABLES.each do |variable|
          if name == variable || name == "#{variable}_#{placement.role}"
            measures[name] = fn_measure.call(placement, variable)
          elsif !placement.partner.nil? && name == "#{variable}_#{placement.partner.role}"
            measures[name] = fn_measure.call(placement.partner, variable)
          end
        end
      end
      placement.variables = _resolve_hardware_variables(measures)
    end

    # The given measures completed by the hardware's own variables.
    def _resolve_hardware_variables(measures)
      descriptor = _get_hardware_descriptor_def
      descriptor.nil? ? measures : descriptor.resolve_variables(measures)
    end

    # The propagation of the given placements, less those where the
    # hardware's asserts fail - see HardwareDescriptorDef#asserts.
    def _check_hardware_asserts(placements)
      descriptor = _get_hardware_descriptor_def
      return PropagationDef.new(placements, [], []) if descriptor.nil? || descriptor.asserts.empty?
      failed_asserts = []
      refused, placements = placements.partition { |placement|
        failed = descriptor.failed_asserts(_get_placement_variables(placement))
        failed_asserts.concat(failed)
        failed.any?
      }
      PropagationDef.new(placements, refused, failed_asserts.uniq)
    end

    # Shows why anchors of the given propagation are refused. Is there any ?
    def _show_refused_anchors(propagation_def)
      return false if propagation_def.nil? || (count = propagation_def.refused_count) == 0
      k_points = _create_floating_points(
        points: propagation_def.refused.flat_map { |placement| (placement.instance_transformations || []).map { |t| ORIGIN.transform(t * placement.transformation) } },
        style: Kuix::POINT_STYLE_CROSS,
        stroke_color: Kuix::COLOR_RED,
        stroke_width: 2
      )
      @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)
      @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.refused_anchors', { :count => count, :asserts => propagation_def.failed_asserts.join(', ') }), SmartTool::MESSAGE_TYPE_ERROR)
      true
    end

    # How far the part of the given placement goes toward -Z of the laying
    # frame.
    def _get_placement_thickness(placement)
      ti = placement.transformation.inverse
      min_z = 0.0
      placement.definition.entities.each do |entity|
        next unless entity.is_a?(Sketchup::Edge)
        entity.vertices.each do |vertex|
          z = vertex.position.transform(ti).z.to_f
          min_z = z if z < min_z
        end
      end
      -min_z
    end

    # How far the part of the given placement goes toward +Y of the laying
    # frame from the anchor, just behind the face : where the nearest of its
    # faces the ray leaves it by is. nil when none is found.
    def _get_placement_height(placement)
      t = placement.transformation
      origin = Geom::Point3d.new(0, 0, -PLACEMENT_HEIGHT_DEPTH).transform(t)
      direction = Y_AXIS.transform(t).normalize
      on_face = [ Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex ]
      placement.definition.entities.grep(Sketchup::Face).map { |face|
        next nil if face == placement.face
        point = Geom.intersect_line_plane([ origin, direction ], face.plane)
        next nil if point.nil?
        distance = (point - origin) % direction
        next nil if distance <= 1e-3 || !on_face.include?(face.classify_point(point))
        distance
      }.compact.min
    end

    # How far the other face of the part of the given placement is, right
    # behind the solids of its slot - their centers and outlines - toward -Z
    # of the laying frame : [ nearest, farthest ]. The points off the face
    # or behind which nothing is found are skipped ; none left : its
    # thickness - see _get_placement_thickness - twice.
    def _get_placement_local_thicknesses(placement)
      t = placement.transformation
      direction = Z_AXIS.reverse.transform(t).normalize
      faces = placement.definition.entities.grep(Sketchup::Face)
      on_face = [ Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex ]
      depths = _get_placement_footprint(placement).map { |x, y|
        origin = Geom::Point3d.new(x, y, 0).transform(t)
        next nil unless on_face.include?(placement.face.classify_point(origin))
        # The nearest face the ray leaves the part by
        faces.map { |face|
          next nil if face == placement.face
          point = Geom.intersect_line_plane([ origin, direction ], face.plane)
          next nil if point.nil?
          distance = (point - origin) % direction
          next nil if distance <= 1e-3 || !on_face.include?(face.classify_point(point))
          distance
        }.compact.min
      }.compact
      if depths.empty?
        thickness = _get_placement_thickness(placement)
        return [ thickness, thickness ]
      end
      [ depths.min, depths.max ]
    end

    # The points, in the laying frame - [ x, y ] - the solids of the slot of
    # the given placement stand on : the anchor, and the centers and outlines
    # of its primitives, or the corners of its SKPs.
    def _get_placement_footprint(placement)
      geometries_def = _get_geometries_def
      return [ [ 0.0, 0.0 ] ] if geometries_def.nil?
      geometries = placement.role == :a ? [ geometries_def.hardware_a, geometries_def.machining_a ] : [ geometries_def.hardware_b, geometries_def.machining_b ]
      # The measures the outlines depend on aren't known yet : the thicknesses
      thicknesses = { placement.role => _get_placement_thickness(placement) }
      thicknesses[placement.partner.role] = _get_placement_thickness(placement.partner) unless placement.partner.nil?
      measures = {}
      HardwareDescriptorDef::VARIABLES.each do |variable|
        measures[variable] = thicknesses[placement.role]
        thicknesses.each { |role, thickness| measures["#{variable}_#{role}"] = thickness }
      end
      variables = _resolve_hardware_variables(measures)
      points = [ [ 0.0, 0.0 ] ]
      geometries.each do |geometry|
        sign = geometry.mirror ? -1 : 1
        if geometry.drawing_def
          bounds = geometry.drawing_def.bounds
          [ bounds.min.x, bounds.max.x ].product([ bounds.min.y, bounds.max.y ]).each { |x, y| points << [ sign * x, y ] }
        elsif geometry.primitives
          HardwareDescriptorDef.primitive_cylinders(geometry.primitives, variables).each do |cylinder|
            next unless cylinder.axis.nil?   # Not on the face
            points << [ sign * cylinder.x, cylinder.y ]
            r = cylinder.radius
            h = cylinder.round? ? 0.0 : cylinder.length / 2 - r
            8.times do |i|
              a = Math::PI * i / 4
              points << [ sign * (cylinder.x + r * Math.cos(a) + (Math.cos(a) > 1e-6 ? h : Math.cos(a) < -1e-6 ? -h : 0.0)), cylinder.y + r * Math.sin(a) ]
            end
          end
        end
      end
      points.uniq
    end

    # The solids of the given primitives resolved at the given placement, as
    # [ x, y, diameter, z_min, z_max ] - and length for an oblong one, nil
    # and the profile for a widened one, then the axis for one along Y, the
    # values before it nil if missing - in inches, rounded : the key of their
    # geometry. Centered, shifted along Z by their offset - see
    # _get_primitives_offset - before rounding.
    def _get_primitives_dimensions(primitives, placement, centered = false)
      offset = centered ? _get_primitives_offset(primitives, placement) : 0.0
      fn_round = lambda { |v| v.to_f.round(6) + 0.0 }  # + 0.0 : no -0.0 in the key
      HardwareDescriptorDef.primitive_cylinders(primitives, _get_placement_variables(placement)).map { |cylinder|
        values = [ cylinder.x, cylinder.y, cylinder.diameter, cylinder.z_min - offset, cylinder.z_max - offset ].map(&fn_round)
        values << fn_round.call(cylinder.length) unless cylinder.round?
        values << nil << cylinder.profile.map { |r, z| [ fn_round.call(r), fn_round.call(z - offset) ] } unless cylinder.profile.nil?
        values.fill(nil, values.length...7) << cylinder.axis unless cylinder.axis.nil?
        values
      }
    end

    # The Z center of the given primitives resolved at the given placement.
    def _get_primitives_offset(primitives, placement)
      cylinders = HardwareDescriptorDef.primitive_cylinders(primitives, _get_placement_variables(placement))
      return 0.0 if cylinders.empty?
      (cylinders.map(&:z_min).min + cylinders.map(&:z_max).max) / 2
    end

    # The transformation a primitive along the given axis is laid with - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#axis.
    def _get_primitive_axis_transformation(axis)
      case axis
      when HardwareDescriptorDef::AXIS_Y
        TRANSFORMATION_AXIS_Y
      when HardwareDescriptorDef::AXIS_Y_LENGTH_Z
        TRANSFORMATION_AXIS_Y_LENGTH_Z
      else
        IDENTITY
      end
    end

    # The segments of the circle of a primitive of the given diameter.
    def _get_primitive_num_segments(diameter)
      Geometrix::ArcUtils.num_segments_by_radius(diameter / 2)
    end

    # The outline of a primitive, as [ x, y ] points : a circle, or a slot
    # with round ends - length along X - when length is given.
    def _get_primitive_outline(x, y, diameter, length = nil)
      count = _get_primitive_num_segments(diameter)
      r = diameter / 2
      return (0...count).map { |i| a = 2 * Math::PI * i / count; [ x + r * Math.cos(a), y + r * Math.sin(a) ] } if length.nil?
      h = (length - diameter) / 2
      half = count / 2
      right = (0..half).map { |i| a = -Math::PI / 2 + Math::PI * i / half; [ x + h + r * Math.cos(a), y + r * Math.sin(a) ] }
      left = (0..half).map { |i| a = Math::PI / 2 + Math::PI * i / half; [ x - h + r * Math.cos(a), y + r * Math.sin(a) ] }
      right + left
    end

    # The edges of the given primitives dimensions, as segments in the laying
    # frame : both outlines and four generatrices of each solid.
    def _get_primitives_segments(dimensions)
      segments = []
      dimensions.each do |x, y, diameter, z_min, z_max, length, profile, axis|
        solid_segments = []
        if profile.nil?
          points = _get_primitive_outline(x, y, diameter, length)
          step = [ points.length / 4, 1 ].max
          points.each_with_index do |(px, py), i|
            nx, ny = points[(i + 1) % points.length]
            solid_segments << Geom::Point3d.new(px, py, z_max) << Geom::Point3d.new(nx, ny, z_max)
            solid_segments << Geom::Point3d.new(px, py, z_min) << Geom::Point3d.new(nx, ny, z_min)
            solid_segments << Geom::Point3d.new(px, py, z_max) << Geom::Point3d.new(px, py, z_min) if i % step == 0
          end
        else
          solid_segments = _get_profile_segments(x, y, profile)
        end
        at = _get_primitive_axis_transformation(axis)
        solid_segments.each { |point| point.transform!(at) } unless axis.nil?
        segments.concat(solid_segments)
      end
      segments
    end

    # The edges of a solid of the given profile - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#profile - around the given
    # axis : a circle at each of its points and four generatrices.
    def _get_profile_segments(x, y, profile)
      segments = []
      count = _get_primitive_num_segments(2 * profile.map(&:first).max)
      step = [ count / 4, 1 ].max
      fn_point = lambda { |r, z, i| a = 2 * Math::PI * i / count; Geom::Point3d.new(x + r * Math.cos(a), y + r * Math.sin(a), z) }
      count.times do |i|
        profile.each do |r, z|
          segments << fn_point.call(r, z, i) << fn_point.call(r, z, i + 1)
        end
        next unless i % step == 0
        profile.each_cons(2) do |(r0, z0), (r1, z1)|
          segments << fn_point.call(r0, z0, i) << fn_point.call(r1, z1, i)
        end
      end
      segments
    end

    # The segments to preview the given geometry - hardware or machining -
    # with at the given placement, nil when there is none.
    def _get_geometry_preview_segments(geometry, placement)
      if geometry.drawing_def
        segments = geometry.drawing_def.edge_manipulators.flat_map(&:segment) + geometry.drawing_def.curve_manipulators.flat_map(&:segments)
      elsif geometry.primitives
        segments = _get_primitives_segments(_get_primitives_dimensions(geometry.primitives, placement))
      else
        return nil
      end
      z_offset = _get_geometry_z_offset(geometry, placement)
      return segments if z_offset == 0
      segments.map { |point| Geom::Point3d.new(point.x, point.y, point.z + z_offset) }
    end

    # The transformation, in the laying frame, a geometry is laid with : the
    # mirror across the YZ plane - x negated - of a mirror_of component, its
    # definition - SKP or primitives - shared with the mirrored slot.
    def _get_geometry_mirror_transformation(geometry)
      geometry.mirror ? Geom::Transformation.scaling(ORIGIN, -1, 1, 1) : IDENTITY
    end

    # How far along Z of the laying frame the given geometry is laid off its
    # definition : a hardware is shifted by its z_offset, and one of
    # primitives is generated centered - see _get_geometry_definition - the
    # measures only shift it. 0 for a machining : it starts at the face.
    def _get_geometry_offset(geometry, placement)
      return 0.0 unless geometry.part == :hardware
      offset = _get_geometry_z_offset(geometry, placement)
      offset += _get_primitives_offset(geometry.primitives, placement) if geometry.definition.nil? && !geometry.primitives.nil?
      offset
    end

    # The z_offset the descriptor declares for the given hardware, evaluated
    # at the given placement - see HardwareDescriptorDef. 0 when there is
    # none, or it can't be evaluated there.
    def _get_geometry_z_offset(geometry, placement)
      return 0.0 unless geometry.part == :hardware
      component = _get_hardware_component(geometry.slot)
      return 0.0 if component.nil? || component.z_offset.nil?
      HardwareDescriptorDef.to_length(component.z_offset, true, _get_placement_variables(placement)) || 0.0
    end

    # The definition of the given geometry - hardware or machining - to lay
    # at the given placement : its SKP's one, or the one generated from its
    # primitives - one per set of measures they use, a part thickness -
    # found by the key of its geometry. A hardware - a shape - is generated
    # centered on Z, so that the same dowel shifted by the measures stays one
    # definition - one part in the cut list - see _add_geometry. A machining
    # holds each of its operations in a group of its own, painted with the
    # given material : an export tells them apart. To be called in an
    # operation.
    def _get_geometry_definition(geometry, placement, material = nil)
      return geometry.definition unless geometry.definition.nil?
      return nil if geometry.primitives.nil?

      model = Sketchup.active_model
      dimensions = _get_primitives_dimensions(geometry.primitives, placement, geometry.part == :hardware)
      return nil if dimensions.empty?
      key = _get_geometry_definition_key(geometry, dimensions)
      name = _get_hardware_definition_name(geometry.slot, geometry.part)

      definition = model.definitions.find { |d| d.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_PRIMITIVES) == key }
      if definition.nil?
        definition = model.definitions.add(name.is_a?(String) && !name.empty? ? name : geometry.part.to_s)
        dimensions.each do |x, y, diameter, z_min, z_max, length, profile, axis|
          at = _get_primitive_axis_transformation(axis)
          if geometry.part == :machining
            group = definition.entities.add_group
            group.material = material if material.is_a?(Sketchup::Material)
            entities = group.entities
          else
            entities = definition.entities
          end
          if profile.nil?
            _add_primitive_solid(entities, x, y, diameter, z_min, z_max, length, at)
          else
            _add_profile_solid(entities, x, y, profile, at)
          end
        end
        definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, HardwareDescriptorDef::DEFINITION_ATTRIBUTE_PRIMITIVES, key)
      end
      _name_hardware_definition(model, definition, name)
      _write_hardware_attributes(definition, geometry.slot) if geometry.part == :hardware
      definition
    end

    # Writes the "attributes" of the given resolved component in the OCL
    # dictionary of the given definition.
    def _write_component_attributes(definition, component)
      component.attributes.each do |name, value|
        definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, name, value) unless definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, name) == value
      end
    end

    # The key the definition generated from the given primitives - resolved
    # as the given dimensions - is found by : shared by any geometry of the
    # same part and dimensions.
    def _get_geometry_definition_key(geometry, dimensions)
      "#{geometry.part}:#{dimensions.to_json}"
    end

    # A solid along Z, from z_min to z_max : a cylinder, or a slot with round
    # ends - length along X - when length is given. Its ends are arcs, to
    # soften its sides. at : the transformation it is laid with - see
    # _get_primitive_axis_transformation.
    def _add_primitive_solid(entities, x, y, diameter, z_min, z_max, length = nil, at = IDENTITY)
      return if z_max <= z_min
      r = diameter / 2
      count = _get_primitive_num_segments(diameter)
      fn_point = lambda { |px, py| Geom::Point3d.new(px, py, z_max).transform(at) }
      x_axis = X_AXIS.transform(at)
      z_axis = Z_AXIS.transform(at)
      if length.nil?
        edges = entities.add_circle(fn_point.call(x, y), z_axis, r, count)
      else
        h = (length - diameter) / 2
        edges = entities.add_arc(fn_point.call(x + h, y), x_axis, z_axis, r, -Math::PI / 2, Math::PI / 2, count / 2) +
                entities.add_arc(fn_point.call(x - h, y), x_axis, z_axis, r, Math::PI / 2, 3 * Math::PI / 2, count / 2)
        edges << entities.add_line(fn_point.call(x + h, y + r), fn_point.call(x - h, y + r))
        edges << entities.add_line(fn_point.call(x - h, y - r), fn_point.call(x + h, y - r))
      end
      face = entities.add_face(edges)
      return if face.nil?
      face.reverse! if face.normal % z_axis > 0
      face.pushpull(z_max - z_min)  # Along its normal : toward -Z
    end

    # A solid of the given profile - see
    # HardwareDescriptorDef::PrimitiveCylinderDef#profile - turned around
    # the vertical axis at x, y : a drilling or a cylinder widened at one end.
    # at : the transformation it is laid with - see
    # _get_primitive_axis_transformation.
    def _add_profile_solid(entities, x, y, profile, at = IDENTITY)
      r_top, z_top = profile.first
      count = _get_primitive_num_segments(2 * profile.map(&:first).max)
      points = [ Geom::Point3d.new(x, y, z_top) ] +
               profile.map { |r, z| Geom::Point3d.new(x + r, y, z) } +
               [ Geom::Point3d.new(x, y, profile.last.last) ]
      points.each { |point| point.transform!(at) }
      path = entities.add_circle(Geom::Point3d.new(x, y, z_top).transform(at), Z_AXIS.transform(at), r_top, count)
      face = entities.add_face(points)
      return if face.nil?
      face.followme(path)
      # The path, where it isn't an edge of the solid
      entities.erase_entities(path.select { |edge| edge.valid? && edge.faces.length < 2 })
    end

    # -- UTILS --

    def _get_active_path
      @_active_path ||= Sketchup.active_model.active_path.to_a
    end

    def _get_grouped_glued_instances(face_manipulator, poly_3d)
      if (glued_instances = face_manipulator.face.get_glued_instances).any?

        fm_ti = face_manipulator.transformation.inverse
        poly_2d = poly_3d.map { |point| point.transform(fm_ti) }

        # Selects only the glued instances whose anchor point is on the segment.
        # And group them by anchor point coords
        return glued_instances.select { |glued_instance| Geom.point_in_polygon_2D(ORIGIN.transform(glued_instance.transformation), poly_2d, true) }
                              .group_by { |glued_instance| ORIGIN.transform(face_manipulator.transformation * glued_instance.transformation).to_a }  # Anchor point coords Array<Geom::Point3d>

      end
      {}
    end

    def _is_geometries_intersect_glued_instances?(geometries_bounds, anchor_point, glued_instances, fm, t, ti, at)
      glued_instances.any? { |glued_instance|

        fm_t = fm.transformation
        fm_ti = fm_t.inverse

        b_t = glued_instance.transformation
        min = glued_instance.definition.bounds.min.transform(b_t)
        max = glued_instance.definition.bounds.max.transform(b_t)
        glued_instance_bounds = Geom::BoundingBox.new.add(min, max)

        b_t = fm_ti * t * Geom::Transformation.translation(anchor_point.transform(ti)) * at
        min = geometries_bounds.min.transform(b_t)
        max = geometries_bounds.max.transform(b_t)
        new_instance_bounds = Geom::BoundingBox.new.add(min, max)

        glued_instance_bounds.intersect(new_instance_bounds).valid?
      }
    end

    # Lays the given geometry - hardware or machining - at the given
    # placement, glued to its face. Off its definition - see
    # _get_geometry_offset - it is laid in a group glued in its place, that
    # holds the offset : SketchUp puts a glued instance back on the plane of
    # its face when the model is reopened.
    def _add_geometry(geometry, placement, material, layer)
      definition = _get_geometry_definition(geometry, placement, material)
      return unless definition.is_a?(Sketchup::ComponentDefinition)
      material = nil if geometry.part == :machining && !geometry.definition.nil? && definition.behavior.cuts_opening? # A SKP machining that cuts its opening is not painted
      mt = _get_geometry_mirror_transformation(geometry)
      offset = _get_geometry_offset(geometry, placement)
      if offset.abs < 1e-6
        _add_glued_instance(definition, material, layer, placement.face, placement.entities, placement.transformation, ORIGIN, mt)
        return
      end
      wrapper = placement.entities.add_group
      wrapper.transformation = placement.transformation
      instance = wrapper.entities.add_instance(definition, mt * Geom::Transformation.translation([ 0, 0, offset ]))
      instance.material = material if material.is_a?(Sketchup::Material)
      instance.layer = layer if layer.is_a?(Sketchup::Layer)
      wrapper.layer = layer if layer.is_a?(Sketchup::Layer)
      wrapper.definition.behavior.no_scale_mask = 0b1111111
      wrapper.definition.behavior.is2d = true       # Gluing behavior
      wrapper.glued_to = placement.face if wrapper.respond_to?(:glued_to=) # Sketchup::Group#glued_to= requires SketchUp >= 2021.1
    end

    def _add_glued_instance(definition, material, layer, face, entities, dti, pt, at)
      if definition.is_a?(Sketchup::ComponentDefinition)
        definition.behavior.no_scale_mask = 0b1111111 # No scale in all direction
        definition.behavior.is2d = true               # Force 2D behavior to ba able to glue to face
        instance = entities.add_instance(definition, dti * Geom::Transformation.translation(pt) * at)
        instance.material = material if material.is_a?(Sketchup::Material)
        instance.layer = layer if layer.is_a?(Sketchup::Layer)
        instance.glued_to = face
      end
    end

    # -- Propagation --

    # Joinery is written into definitions, so it exists on every instance of the
    # touched definitions while it is only picked for one instance couple. The
    # helpers below walk the contact graph (A -> B -> A' -> B' -> ...) to keep
    # the mating parts consistent on every instance.

    # Walks the contact graph from the given seed placements. Placements are
    # deduplicated by (definition, anchor). For each accepted placement, every
    # instance of its owner definition is handed to the block as
    # |placement, world_frame, instance_path| - where 'world_frame' is the
    # placement frame transported on this instance - which probes for a mating
    # part and returns the placement to enqueue, or nil to stop the walk on this
    # branch. Returns the accepted placements, with their
    # 'instance_transformations' filled.
    def _walk_contact_graph(seeds, tolerance = 0.001.mm)

      model = Sketchup.active_model

      placements = []
      seen = {}
      queue = seeds.dup

      until queue.empty?

        placement = queue.shift

        o = ORIGIN.transform(placement.transformation)
        key = [ placement.definition.entityID, (o.x / tolerance).round, (o.y / tolerance).round, (o.z / tolerance).round ]
        next if seen.has_key?(key)
        seen[key] = true
        placements << placement

        # The placement lives in the shared definition => present on all its
        # instances. Look for a mating neighbor at each instance.
        instance_paths = []
        _instances_to_paths(placement.definition.instances, instance_paths, model.entities, [])

        placement.instance_transformations = []

        instance_paths.each do |instance_path|

          t_i = Sketchup::InstancePath.new(instance_path).transformation
          placement.instance_transformations << t_i

          n_placement = yield(placement, t_i * placement.transformation, instance_path)
          queue << n_placement unless n_placement.nil?

        end

      end

      placements
    end

    # Walks a ray through the model, resolving each hit to its host part (glued
    # instances - connectors - are resolved through 'glued_to' ; the source part
    # and already rejected parts are walked past), decomposes each candidate part
    # to 'world' space and returns its first face manipulator accepted by the
    # block, or nil - or [ face_manipulator, part_path ] with 'with_path'.
    def _raytest_part_face(ray_point, ray_vector, source_path, max_hits = 10, with_path: false)

      model = Sketchup.active_model

      source_serialized = PathUtils.serialize_path(source_path)
      tested = {}

      max_hits.times do

        hit_point, hit_path = model.raytest([ ray_point, ray_vector ])
        return nil if hit_path.nil?

        part_path = _get_part_entity_path_from_path(hit_path)

        # Resolve glued instances (connectors) to the part they are glued in
        while part_path.is_a?(Array) && part_path.length > 1 && part_path.last.respond_to?(:glued_to) && !part_path.last.glued_to.nil?
          part_path = _get_part_entity_path_from_path(part_path[0...-1])
        end

        if part_path.is_a?(Array) &&
           (serialized = PathUtils.serialize_path(part_path)) != source_serialized &&  # Exclude the source instance itself
           !tested.has_key?(serialized)

          tested[serialized] = true

          drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(part_path) ], **_get_drawing_def_parameters).run
          if drawing_def.is_a?(DrawingDef)

            # Bring face manipulators to 'world' space (same normalization as _get_neighborhood_def)
            drawing_def.transform!(drawing_def.transformation.inverse)

            fm = drawing_def.face_manipulators.find { |face_manipulator| yield(face_manipulator) }
            return with_path ? [ fm, part_path ] : fm unless fm.nil?

          end

        end

        # Walk past this hit
        ray_point = hit_point.offset(ray_vector, 0.01.mm)

      end

      nil
    end

    # Deterministic fallback of the ray probes : finds the part face passing
    # through 'world_point' accepted by the block, by walking the instance tree
    # bounded by point containment (only the parts whose world bounds contain
    # the point are candidates - the mate face passes through it). Used when a
    # ray misses the mate because its face is shadowed by a coplanar face of
    # another part (raytest reports a single arbitrary face per hit). Returns
    # [ face_manipulator, part_path ] with 'with_path'.
    def _find_part_face_at(world_point, source_path, tolerance, with_path: false)

      model = Sketchup.active_model

      source_serialized = PathUtils.serialize_path(source_path)

      point_bounds = Geom::BoundingBox.new
      point_bounds.add(world_point.offset(Geom::Vector3d.new(-1, -1, -1), tolerance * 10))
      point_bounds.add(world_point.offset(Geom::Vector3d.new(1, 1, 1), tolerance * 10))

      candidate_paths = {}
      fn_collect = lambda do |entities, path, transformation|
        entities.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
          next unless entity.visible? && _layer_visible?(entity.layer, path.empty?)
          t = transformation * entity.transformation
          definition_bounds = entity.definition.bounds
          entity_bounds = Geom::BoundingBox.new
          (0..7).each { |i| entity_bounds.add(definition_bounds.corner(i).transform(t)) }
          next unless entity_bounds.intersect(point_bounds).valid?
          child_path = path + [ entity ]
          if (part_path = _get_part_entity_path_from_path(child_path))

            # Resolve glued instances (connectors) to the part they are glued in
            while part_path.is_a?(Array) && part_path.length > 1 && part_path.last.respond_to?(:glued_to) && !part_path.last.glued_to.nil?
              part_path = _get_part_entity_path_from_path(part_path[0...-1])
            end

            if part_path.is_a?(Array) && (serialized = PathUtils.serialize_path(part_path)) != source_serialized  # Exclude the source instance itself
              candidate_paths[serialized] ||= part_path
            end

          end
          fn_collect.call(entity.definition.entities, child_path, t)
        end
      end
      fn_collect.call(model.entities, [], IDENTITY)

      candidate_paths.each_value do |part_path|

        drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(part_path) ], **_get_drawing_def_parameters).run
        next unless drawing_def.is_a?(DrawingDef)

        # Bring face manipulators to 'world' space (same normalization as _get_neighborhood_def)
        drawing_def.transform!(drawing_def.transformation.inverse)

        fm = drawing_def.face_manipulators.find { |face_manipulator| yield(face_manipulator) }
        return with_path ? [ fm, part_path ] : fm unless fm.nil?

      end

      nil
    end

    # Finds the part face touching at 'world_point', on the +'world_normal' side.
    # The mating part lies just behind the contact plane, so a ray shot from
    # slightly inside its material along +'world_normal' identifies it (the ray
    # exits through one of its faces) without walking the model entities. When
    # the exit face is shadowed by a coplanar face of the part behind (parts in
    # a row), the ray misses the mate : a deterministic point-containment search
    # takes over. Returns a 'world' space FaceManipulator (its transformation
    # maps the neighbor definition to world) or nil.
    def _find_touching_neighbor(world_point, world_normal, source_path, tolerance)

      fn_accept = lambda do |fm|
        fm.normal.parallel?(world_normal) &&
          !fm.normal.samedirection?(world_normal) &&                                     # Opposite normal
          world_point.distance_to_plane([ fm.position, fm.normal ]).to_f < tolerance &&  # Coplanar
          _is_point_on_face?(fm, world_point)                                            # Under the anchor
      end

      nfm = _raytest_part_face(world_point.offset(world_normal, tolerance * 10), world_normal, source_path, &fn_accept)
      nfm || _find_part_face_at(world_point, source_path, tolerance, &fn_accept)
    end

    def _is_point_on_face?(face_manipulator, world_point)
      local_point = world_point.transform(face_manipulator.transformation.inverse).project_to_plane(face_manipulator.face.plane)
      [ Sketchup::Face::PointInside, Sketchup::Face::PointOnVertex, Sketchup::Face::PointOnEdge ].include?(face_manipulator.face.classify_point(local_point))
    end

    # Returns the glued instances of 'face' intersecting 'bounds' placed at 'mt'
    # (both expressed in the face owner definition space).
    def _get_glued_instances_at(face, mt, bounds)
      placed_bounds = Geom::BoundingBox.new.add(bounds.min.transform(mt), bounds.max.transform(mt))
      face.get_glued_instances.select do |glued_instance|
        gt = glued_instance.transformation
        glued_instance_bounds = Geom::BoundingBox.new.add(glued_instance.definition.bounds.min.transform(gt), glued_instance.definition.bounds.max.transform(gt))
        placed_bounds.intersect(glued_instance_bounds).valid?
      end
    end

    # Returns the glued instances of 'face' anchored at the 'mt' origin (both
    # expressed in the face owner definition space). Unlike the bounds
    # intersection test, this works whatever the glued definitions' geometry
    # footprint is (it can be offset from the anchor).
    def _get_glued_instances_anchored_at(face, mt, tolerance = 0.001.mm)
      anchor = ORIGIN.transform(mt)
      face.get_glued_instances.select { |glued_instance| ORIGIN.transform(glued_instance.transformation).distance(anchor).to_f < tolerance }
    end

    # Data Structs -----

    GeometriesDef = Struct.new(:hardware_a, :hardware_b, :machining_a, :machining_b, :hardware_material, :machining_material, :hardware_layer, :machining_layer, :bounds) do
      def valid?
        hardware_a.valid? &&
          hardware_b.valid? &&
          machining_a.valid? &&
          machining_b.valid? &&
          (hardware_material.nil? || hardware_material.valid?) &&
          (machining_material.nil? || machining_material.valid?) &&
          (hardware_layer.nil? || hardware_layer.valid?) &&
          (machining_layer.nil? || machining_layer.valid?)
      end
    end
    # primitives : the Hash of the part given as primitives - generated where
    # it is laid - instead of a definition ; slot, part : whose it is ;
    # mirror : laid mirrored - mirror_of -, see _get_geometry_mirror_transformation.
    GeometriesEntityDef = Struct.new(:definition, :drawing_def, :primitives, :slot, :part, :mirror) do
      def empty?
        definition.nil? && primitives.nil? || !valid?
      end
      def valid?
        definition.nil? || definition.valid?
      end
    end

    # A joinery placement resolved once and applied to a shared definition
    # (so it propagates to all its instances). 'transformation' is the anchor
    # frame expressed in the target definition's local space (Z axis pointing
    # toward the mating part) ; 'role' (:a|:b) selects the geometry ;
    # 'instance_transformations' are the world transformations of the definition's
    # instances (used to preview the placement everywhere it will appear) ;
    # 'seed_transformation' is the picked instance's one - only set on the picked
    # couple's placements (seeds), nil on the placements discovered by walking
    # the contact graph ; 'glued_instances' holds the existing glued instances at
    # the anchor when the placement targets them (remove).
    # 'refused' holds the placements left out because the hardware's asserts
    # fail there, 'failed_asserts' those asserts.
    PropagationDef = Struct.new(:placements, :refused, :failed_asserts) do
      # The refused anchors : a refused couple counts once.
      def refused_count
        return 0 if refused.nil?
        refused.count { |placement| placement.role == :a || placement.partner.nil? || !refused.include?(placement.partner) }
      end
    end
    # 'partner' is the placement of the other slot at the same anchor - laid
    # or not - on the other part of the joint ; 'variables' caches the
    # measures taken there, see _get_placement_variables.
    PropagationPlacementDef = Struct.new(:definition, :face, :transformation, :role, :instance_transformations, :seed_transformation, :glued_instances, :partner, :variables) do
      def entities
        face.parent.entities
      end
      # Is this instance occurrence the picked one ?
      def picked?(instance_transformation)
        return false if seed_transformation.nil?
        return true if instance_transformation.equal?(seed_transformation)
        ta = instance_transformation.to_a
        sa = seed_transformation.to_a
        ta.each_index.all? { |i| (ta[i] - sa[i]).abs < 1e-6 }
      end
    end

  end

  # -- Connectors --

  class SmartJoinConnectorsActionHandler < SmartJoinActionHandler

    Clippy = Fiddle::Clippy

    STATE_SELECT = 1

    def initialize(action, tool, previous_action_handler = nil)
      super
    end

    # -----

    def onPickerChanged(picker, view)
      super
      if _pick_join
        _preview_join
      end
      _preview_snap_point
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)
      _preview_part(part_entity_path, part, LAYER_3D_PART_A_PREVIEW, highlighted: highlighted)
      _reset_neighborhood_def
    end

    # -----

    protected

    def _get_select_state
      STATE_SELECT
    end

    def _reset
      super
      @mouse_snap_point = nil
      _reset_active_part_a
      _reset_neighborhood_def
    end

    def _reset_active_part_a
      @active_face_manipulator_a = nil
      @active_edge_manipulator_a = nil
      @active_vertex_manipulator_a = nil
    end

    def _reset_neighborhood_def
      @neighborhood_def = nil
      @propagation_def = nil
    end

    # -- Propagation --

    # Probes for the part mating the given connector world frame 'wf' : parts
    # touch through the connector XY plane, so the mate lies just behind it,
    # along +Z. Returns [ face_manipulator, mt ] - where 'mt' is the mating
    # connector frame (Z flipped : at_a <-> at_b relationship) expressed in the
    # mate face owner definition space - or nil.
    def _find_mating_connector(wf, instance_path, tolerance = 0.001.mm)

      world_point = ORIGIN.transform(wf)
      world_normal = Z_AXIS.transform(wf)             # Points from this part toward the mate
      world_normal.normalize!

      nfm = _find_touching_neighbor(world_point, world_normal, instance_path, tolerance)
      return nil if nfm.nil?

      [ nfm, nfm.transformation.inverse * wf * TRANSFORMATION_FLIP_Z ]
    end

    def _refresh
      @mouse_snap_point = nil
      _reset_active_part_a
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    def _pick_join

      face_manipulator = @picker.picked_plane_manipulator
      if face_manipulator.is_a?(FaceManipulator) &&
         (neighborhood_def = _get_neighborhood_def).is_a?(SmartJoinConnectorsActionHandler::NeighborhoodDef)

        neighbor_defs = neighborhood_def.neighbor_defs

        pt = @picker.picked_point

        edge_manipulator = face_manipulator.loop_manipulators
                                           .flat_map { |lm| lm.edge_manipulators }
                                           .select { |em| neighbor_defs.any? { |nd| nd.touching_defs.any? { |td| td.face_manipulator.face != face_manipulator.face && td.face_manipulator.face.edges.include?(em.edge) } } }
                                           .min { |em1, em2| em1.distance_to(pt) <=> em2.distance_to(pt) }

        if edge_manipulator.is_a?(EdgeManipulator)

          vertex_manipulator = edge_manipulator.nearest_vertex_manipulator_to(pt)
          snap_point = pt

        else

          vertex_manipulator = nil
          snap_point = nil

        end

      else

        edge_manipulator = nil
        vertex_manipulator = nil
        snap_point = nil

      end

      # Check if the base context has changed since last pick iteration
      context_changed = @active_face_manipulator_a != face_manipulator || @active_edge_manipulator_a != edge_manipulator || @active_vertex_manipulator_a != vertex_manipulator

      @active_face_manipulator_a = face_manipulator
      @active_edge_manipulator_a = edge_manipulator
      @active_vertex_manipulator_a = vertex_manipulator
      @mouse_snap_point = snap_point

      context_changed
    end

    def _preview_join

      @tool.clear_3d([ LAYER_3D_PART_B_PREVIEW, LAYER_3D_JOIN_PREVIEW, LAYER_3D_HARDWARE_PREVIEW, LAYER_3D_MACHINING_PREVIEW ])
      @tool.clear_2d(LAYER_2D_DIMENSIONS)
      @tool.hide_message

      return true if (neighborhood_def = _get_neighborhood_def).nil?

      _preview_join_context(neighborhood_def)

    end

    def _preview_join_context(neighborhood_def)

      if @active_face_manipulator_a.is_a?(FaceManipulator)

        # Offset transformation to force mesh to be on top of part preview
        ov = Geom::Vector3d.new(@active_face_manipulator_a.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # Highlight picked face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(@active_face_manipulator_a.triangles)
        k_mesh.background_color = COLOR_REF_FACE_A
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

      end

      if @active_edge_manipulator_a.is_a?(EdgeManipulator)

        # Highlight picked segment
        k_segments = Kuix::Segments.new
        k_segments.add_segments(@active_edge_manipulator_a.segment)
        k_segments.color = COLOR_REF_DARKEN_A
        k_segments.line_width = 3
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_JOIN_PREVIEW)

      end

    end

    def _preview_snap_point
    end

    # -----

    def _get_neighborhood_def(tolerance = 0.001.mm, aperture = 1.mm)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      # Aperture must be greater or equal to tolerance
      aperture = tolerance if tolerance > aperture

      h_neighbor_defs = {}

      kbd = Kuix::Bounds3d.new.copy!(drawing_def.bounds)
      kbi = Kuix::Bounds3d.new.copy!(drawing_def.bounds).inflate_all!(aperture)

      # Hide instance
      _hide_instance

      begin

        model = Sketchup.active_model
        view = model.active_view

        ph = view.pick_helper

        fn_try_to_add_neighbor = lambda do |path|

          picked_part_entity_path = _get_part_entity_path_from_path(path)
          return nil if picked_part_entity_path.nil?                                                  # Exclude non-part entities
          return nil if h_neighbor_defs.has_key?(picked_part_entity_path)                             # Exclude already picked part
          return nil if picked_part_entity_path == get_active_selection_path                          # Exclude selected part
          return nil unless ArrayUtils.array_start_with?(picked_part_entity_path, _get_active_path)   # Exclude out of active path parts
          if (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

            # Exclude invalid drawing defs
            return unless picked_drawing_def.bounds.valid?

            # Transform the drawing def to the 'World' space
            picked_drawing_def.transform!(picked_drawing_def.transformation.inverse)

            # Store the new neighbor def
            h_neighbor_defs[picked_part_entity_path] = NeighborhoodNeighborDef.new(picked_part_entity_path, picked_drawing_def, [])

          end

        end

        # 1. Pick from the bounding box

        num_picked = ph.boundingbox_pick(kbi.to_b, Sketchup::PickHelper::PICK_CROSSING, drawing_def.transformation)
        num_picked.times do |index|

          path = ph.path_at(index)

          fn_try_to_add_neighbor.call(path)

        end

        # 2. Pick by 8 ray corners

        8.times do |corner|

          p0 = kbd.corner(corner).to_p.transform(drawing_def.transformation)
          p1 = kbi.corner(corner).to_p.transform(drawing_def.transformation)

          v = p0.vector_to(p1)
          dmax = v.length
          ray = [ p0.offset(v.reverse), v ]

          hit_point, path = model.raytest(ray)
          if hit_point

            next if p0.distance(hit_point) > dmax

            fn_try_to_add_neighbor.call(path)

          end

        end

      ensure

        # Restore instance visibility
        _unhide_instance

      end

      # Transform the drawing def to the 'World' space
      drawing_def.transform!(drawing_def.transformation.inverse)

      # 3. Search touching faces

      neighbor_defs = h_neighbor_defs.values
      neighbor_defs.select! do |neighbor_def|

        # Iterate on part faces
        drawing_def.face_manipulators.each do |fm|

          # Iterate on neighbor part faces
          neighbor_def.drawing_def.face_manipulators.each do |nfm|

            next unless fm.normal.parallel?(nfm.normal)
            next if fm.normal.samedirection?(nfm.normal)
            next unless fm.position.distance_to_plane([ nfm.position, nfm.normal ]).to_f < tolerance

            # Touching !

            # Compute the transformation to transform world space to touching 2D space
            origin = fm.position
            z_axis = fm.normal
            x_axis = fm.outer_loop_manipulator.edge_manipulators.first.direction.normalize  # Use first outer loop edge direction as arbitrary x axis
            y_axis = z_axis * x_axis
            at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
            ati = at.inverse

            # Compute part and neighbor touching intersections polygons
            f_2d_paths = fm.loop_manipulators
                           .map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ati) } }
                           .map! { |points| Clippy.points_to_rpath(points) }
            nf_2d_paths = nfm.loop_manipulators
                             .map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ati) } }
                             .map! { |points| Clippy.points_to_rpath(points) }

            touching_2d_paths, op = Clippy.execute_intersection(closed_subjects: f_2d_paths, clips: nf_2d_paths)
            touching_polys = touching_2d_paths.map { |path| Clippy.rpath_to_points(path, 0).map { |point| point.transform(at)} }

            neighbor_def.touching_defs << NeighborhoodTouchingDef.new(fm, nfm, touching_polys) if touching_polys.any?

          end

        end

        neighbor_def.touching_defs.any?
      end

      # 4. Keep useful data

      path = get_active_part_entity_path

      @neighborhood_def = NeighborhoodDef.new(
        path,
        drawing_def,
        neighbor_defs
      )
    end

    # Data Structs -----

    NeighborhoodDef = Struct.new(:path, :drawing_def, :neighbor_defs) do
      def instance_a
        path.last
      end
      def t_a
        @t_a ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_a
        @ti_a ||= t_a.inverse
      end
    end
    NeighborhoodNeighborDef = Struct.new(:path, :drawing_def, :touching_defs) do
      def instance_b
        path.last
      end
      def t_b
        @t_b ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_b
        @ti_b ||= t_b.inverse
      end
    end
    NeighborhoodTouchingDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :touching_polys)

  end

  class SmartJoinAddConnectorsActionHandler < SmartJoinConnectorsActionHandler

    include UserTextHelper

    TRANSFORMATION_ROTATION_Z_180 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees).freeze

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_ADD_CONNECTORS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      return super if state == STATE_SOURCE
      SmartCursorManager.cursor_select_join_plus
    end

    def get_state_status(state)
      return super if state == STATE_SOURCE
      super +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_1") + '.'
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      if has_active_part?
        _add_connectors
        _restart
        return true
      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_shift?(key)
        _on_shift_changed if repeat == 1
        return true
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key)
        _on_shift_changed
        return true
      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if _read_free_position(tool, text, view)
      return true if _read_measures(tool, text, view)

      super
    end

    # -----

    def enableVCB?
      @state != STATE_SOURCE
    end

    # -----

    protected

    def _get_hardware_types
      [ HardwareDescriptorDef::TYPE_CONNECTOR ]
    end

    def _reset
      super
      @free_position = nil
    end

    # -----

    # The joint frame the connectors are laid in : from the active vertex,
    # along the active edge. [ origin, x_axis ]
    def _get_free_axis
      origin = @active_vertex_manipulator_a.point
      x_axis = @active_edge_manipulator_a.direction
      x_axis = x_axis.reverse if origin == @active_edge_manipulator_a.end_point
      [ origin, x_axis ]
    end

    # Free : the connector follows the mouse along the active edge, measured
    # from the same vertex until the mouse comes close to the other one.
    def _pick_join
      previous_face_manipulator = @active_face_manipulator_a
      previous_edge_manipulator = @active_edge_manipulator_a
      previous_vertex_manipulator = @active_vertex_manipulator_a

      context_changed = super

      if _fetch_option_distribution_free? &&
         @active_vertex_manipulator_a.is_a?(VertexManipulator) && previous_vertex_manipulator.is_a?(VertexManipulator) &&
         @active_edge_manipulator_a == previous_edge_manipulator && @active_vertex_manipulator_a != previous_vertex_manipulator &&
         @mouse_snap_point.is_a?(Geom::Point3d) && !_is_free_origin_switch?(@mouse_snap_point, @active_vertex_manipulator_a.point)
        @active_vertex_manipulator_a = previous_vertex_manipulator
        context_changed = @active_face_manipulator_a != previous_face_manipulator
      end

      if _fetch_option_distribution_free? && @active_edge_manipulator_a.is_a?(EdgeManipulator) && @active_vertex_manipulator_a.is_a?(VertexManipulator)
        origin, x_axis = _get_free_axis
        free_position = _get_free_position(origin, x_axis, @mouse_snap_point)
      else
        free_position = nil
      end

      (context_changed || !_same_free_position?(@free_position, free_position)).tap { @free_position = free_position }
    end

    def _add_at_free_position
      if has_active_part? &&
         (neighborhood_def = _get_neighborhood_def) &&
         (joinery_def = _get_add_joinery_def(neighborhood_def)) &&
         joinery_def.neighbor_join_defs.any? { |neighbor_join_def| neighbor_join_def.join_defs.any? { |join_def| !join_def.anchor_points_3d.empty? } }
        _add_connectors
        _restart
      else
        UI.beep
      end
    end

    # -----

    def _preview_join_context(neighborhood_def)
      super

      unless (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

        neighbor_join_defs = joinery_def.neighbor_join_defs

        geometries_def = _get_geometries_def
        hardware_a = geometries_def.hardware_a
        hardware_b = geometries_def.hardware_b
        machining_a = geometries_def.machining_a
        machining_b = geometries_def.machining_b

        no_valid_join = true
        occupied_anchor_count = 0
        neighbor_join_defs.each do |neighbor_join_def|

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = COLOR_PART_B
          @tool.append_3d(k_mesh, LAYER_3D_PART_B_PREVIEW)

          neighbor_join_def.join_defs.each do |join_def|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if join_def.anchor_points_3d.empty?
            k_polyline.color = join_def.anchor_points_3d.empty? ? Kuix::COLOR_DARK_GREY : Kuix::COLOR_MAGENTA
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

            k_points = _create_floating_points(
              points: join_def.anchor_points_3d,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_MAGENTA
            )
            @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

            k_points = _create_floating_points(
              points: join_def.occupied_anchor_points_3d,
              style: Kuix::POINT_STYLE_CROSS,
              stroke_color: Kuix::COLOR_RED,
              stroke_width: 2
            )
            @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

            unless join_def.anchor_points_3d.empty?

              k_edge = Kuix::EdgeMotif3d.new
              k_edge.start.copy!(join_def.origin_point_3d || join_def.start_point_3d)
              k_edge.end.copy!(join_def.end_point_3d)
              k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
              k_edge.line_width = 1
              k_edge.color = Kuix::COLOR_MAGENTA
              k_edge.on_top = true
              @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

              _preview_free_range_bounds(join_def) if _fetch_option_distribution_free?

            end

            no_valid_join = false if join_def.anchor_points_3d.any?
            occupied_anchor_count += join_def.occupied_anchor_points_3d.length

          end

        end

        # Preview the connectors : only the picked couple's placements when
        # make_unique is true, every instance of the touched definitions otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b
          machining_segments = _get_geometry_preview_segments(machining, placement)
          hardware_segments = _get_geometry_preview_segments(hardware, placement)

          placement.instance_transformations.each do |instance_transformation|

            t = instance_transformation * placement.transformation
            picked = placement.picked?(instance_transformation)

            # -- Hardware --

            _preview_join_segments(
              hardware_segments,
              t * _get_geometry_mirror_transformation(hardware),
              picked ? COLOR_HARDWARE_PREVIEW : COLOR_HARDWARE_PROPAGATED_PREVIEW,
              1,
              LAYER_3D_HARDWARE_PREVIEW,
            ) if hardware_segments

            # -- Machinings --

            _preview_join_segments(
              machining_segments,
              t * _get_geometry_mirror_transformation(machining),
              picked ? COLOR_MACHINING_PREVIEW : COLOR_MACHINING_PROPAGATED_PREVIEW,
              0.5,
              LAYER_3D_MACHINING_PREVIEW
            ) if machining_segments

          end

        end

        if occupied_anchor_count > 0
          @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.occupied_anchors', { :count => occupied_anchor_count }), SmartTool::MESSAGE_TYPE_ERROR)
        elsif _show_refused_anchors(_get_propagation_def(neighborhood_def, joinery_def))
        elsif no_valid_join
          @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.no_valid_join'), SmartTool::MESSAGE_TYPE_ERROR)
        end

      end

      if _fetch_option_distribution_free? && @active_edge_manipulator_a.is_a?(EdgeManipulator) && @active_vertex_manipulator_a.is_a?(VertexManipulator) &&
         !joinery_def.nil? &&
         (anchor_points_3d = joinery_def.neighbor_join_defs.flat_map { |neighbor_join_def| neighbor_join_def.join_defs.flat_map(&:anchor_points_3d) }).length == 1
        origin, x_axis = _get_free_axis
        _preview_free_position(origin, x_axis, anchor_points_3d.first)
      end

      if @active_vertex_manipulator_a.is_a?(VertexManipulator)

        k_points = _create_floating_points(
          points: @active_vertex_manipulator_a.point,
          style: Kuix::POINT_STYLE_CIRCLE,
          fill_color: Kuix::COLOR_MAGENTA,
          stroke_color: Kuix::COLOR_WHITE,
        )
        @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      end

    end

    def _preview_snap_point

      @tool.clear_3d(LAYER_3D_SNAP_POINT_PREVIEW)

      if @mouse_snap_point.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@mouse_snap_point)
        k_edge.end.copy!(@active_vertex_manipulator_a.point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

      end

    end

    def _preview_join_segments(segments, transformation, color, line_width, layer)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(segments)
      k_segments.color = color
      k_segments.line_width = line_width
      k_segments.transformation = transformation
      k_segments.on_top = true
      @tool.append_3d(k_segments, layer)

    end

    # -----

    def _read_measures(tool, text, view)

      height, start_offset, end_offset, min_spacing, max_spacing = _split_user_text(text)

      if height.is_a?(String) && !height.empty?
        return true if _read_measure(tool, height, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT, 'tool.smart_join.error.invalid_height')
      end

      if start_offset.is_a?(String) && !start_offset.empty?
        return true if _read_measure(tool, start_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET, 'tool.smart_join.error.invalid_start_offset')
      end
      if end_offset.is_a?(String) && !end_offset.empty?
        return true if _read_measure(tool, end_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET, 'tool.smart_join.error.invalid_end_offset')
      end

      if min_spacing.is_a?(String) && !min_spacing.empty?
        return true if _read_measure(tool, min_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING, 'tool.smart_join.error.invalid_min_spacing', length_only: true)
      end
      if max_spacing.is_a?(String) && !max_spacing.empty?
        return true if _read_measure(tool, max_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING, 'tool.smart_join.error.invalid_max_spacing')
      end

      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _add_connectors
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      neighbor_join_defs = joinery_def.neighbor_join_defs

      instance_a = neighborhood_def.instance_a
      definition_a = instance_a.definition
      entities_a = definition_a.entities

      geometries_def = _get_geometries_def
      hardware_a = geometries_def.hardware_a
      hardware_b = geometries_def.hardware_b
      machining_a = geometries_def.machining_a
      machining_b = geometries_def.machining_b
      hardware_material = geometries_def.hardware_material
      machining_material = geometries_def.machining_material
      hardware_layer = geometries_def.hardware_layer
      machining_layer = geometries_def.machining_layer

      model = Sketchup.active_model
      model.start_operation('OCL Add Connectors', true)
      begin

        if _fetch_option_make_unique?

          # Make unique the picked instances (if necessary). The joinery def face
          # manipulators are re-targeted to the new definitions, so the placements
          # resolved below point to them (the propagation signature changes with
          # the definition ids, discarding the preview cache).

          if !hardware_a.empty? || !machining_a.empty?

            u_instance_a = instance_a.make_unique
            u_definition_a = u_instance_a.definition
            if u_definition_a != definition_a

              u_entities_a = u_definition_a.entities

              neighbor_join_defs.each do |neighbor_join_def|
                neighbor_join_def.join_defs.each do |join_def|
                  face = join_def.touching_def.face_manipulator.face
                  if face.parent == definition_a
                    face_index = entities_a.to_a.index(face)
                    u_face = u_entities_a[face_index]
                    if u_face
                      join_def.touching_def.face_manipulator = FaceManipulator.new(u_face, join_def.touching_def.face_manipulator.transformation)
                      break
                    end
                  end
                end
              end

            end

          end

          if !hardware_b.empty? || !machining_b.empty?

            neighbor_join_defs.each do |neighbor_join_def|

              instance_b = neighbor_join_def.neighbor_def.instance_b
              definition_b = instance_b.definition
              entities_b = definition_b.entities

              u_instance_b = instance_b.make_unique
              u_definition_b = u_instance_b.definition
              if u_definition_b != definition_b

                u_entities_b = u_definition_b.entities

                neighbor_join_def.join_defs.each do |join_def|
                  neighbor_face = join_def.touching_def.neighbor_face_manipulator.face
                  if neighbor_face.parent == definition_b
                    neighbor_face_index = entities_b.to_a.index(neighbor_face)
                    u_neighbor_face = u_entities_b[neighbor_face_index]
                    if u_neighbor_face
                      join_def.touching_def.neighbor_face_manipulator = FaceManipulator.new(u_neighbor_face, join_def.touching_def.neighbor_face_manipulator.transformation)
                    end
                  end
                end

              end

            end

          end

        end

        # Add the connectors : only the picked couple's placements when make_unique
        # is true, the whole contact graph (A -> B -> A' -> B' -> ...) otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b

          _add_geometry(hardware, placement, hardware_material, hardware_layer)
          _add_geometry(machining, placement, machining_material, machining_layer)

        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -----

    def _get_add_joinery_def(neighborhood_def)
      return nil if @active_face_manipulator_a.nil? || @active_edge_manipulator_a.nil? || @active_vertex_manipulator_a.nil?

      t_a = neighborhood_def.t_a
      ti_a = neighborhood_def.ti_a

      start_offset = _fetch_option_start_offset
      end_offset = _fetch_option_end_offset
      min_spacing = _fetch_option_min_spacing
      max_spacing = _fetch_option_max_spacing
      height = _fetch_option_height

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      fn_select_touching_defs = lambda do |neighbor_def|
        neighbor_def.touching_defs.select { |touching_def|
          touching_def.face_manipulator.face != @active_face_manipulator_a.face &&
          touching_def.face_manipulator.face.edges.any? { |edge| edge == @active_edge_manipulator_a.edge }
        }
      end

      # Free : one connector at the mouse position, on the touching poly
      # under the mouse - or the nearest one
      free = _fetch_option_distribution_free?
      free_position = @typed_free_position || @free_position
      if free && !free_position.nil?
        origin, x_axis = _get_free_axis
        free_touching_poly = neighborhood_def.neighbor_defs
                                             .flat_map { |neighbor_def| fn_select_touching_defs.call(neighbor_def).flat_map(&:touching_polys) }
                                             .min_by { |touching_poly|
                                               xs = touching_poly.map { |point| (point - origin) % x_axis }
                                               gap = [ xs.min - free_position, free_position - xs.max, 0 ].max
                                               [ gap.to_f, @mouse_snap_point.is_a?(Geom::Point3d) ? touching_poly.map { |point| point.distance(@mouse_snap_point).to_f }.min : 0 ]
                                             }
      else
        free_touching_poly = nil
      end

      neighbor_join_defs = []

      neighborhood_def.neighbor_defs.each do |neighbor_def|

        t_b = neighbor_def.t_b
        ti_b = neighbor_def.ti_b

        join_defs = []

        fn_select_touching_defs.call(neighbor_def).each do |touching_def|

          origin, x_axis = _get_free_axis
          z_axis = touching_def.face_manipulator.normal
          y_axis = z_axis * x_axis
          at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          ati = at.inverse

          touching_def.touching_polys.each do |touching_poly|

            touching_poly_2d = touching_poly.map { |point| point.transform(ati) }
            touching_poly_bounds = Geom::BoundingBox.new.add(touching_poly_2d)
            touching_vy = ORIGIN.vector_to([
                                             touching_poly_bounds.min.project_to_line([ ORIGIN, Y_AXIS ]),
                                             touching_poly_bounds.max.project_to_line([ ORIGIN, Y_AXIS ])
                                           ].max { |p1, p2| ORIGIN.distance(p1) <=> ORIGIN.distance(p2) })

            total_length = touching_poly_bounds.width
            start_offset_length = start_offset.is_a?(Length) ? start_offset : total_length * start_offset
            start_offset_length = 0 if start_offset_length < geometries_bounds.width / 2
            end_offset_length = end_offset.is_a?(Length) ? end_offset : total_length * end_offset
            end_offset_length = 0 if end_offset_length < geometries_bounds.width / 2
            min_spacing_length = [ min_spacing, geometries_bounds.width ].max

            if total_length < geometries_bounds.width
              # Touching face is not large enough to contain at least one join
              coords = []
            elsif free
              coord = touching_poly.equal?(free_touching_poly) ? _get_free_coord(free_position - touching_poly_bounds.min.x, total_length, start_offset_length, end_offset_length, geometries_bounds.width / 2) : nil
              coords = coord.nil? ? [] : [ coord ]
            else
              if total_length > start_offset_length + min_spacing_length + end_offset_length
                middle_length = total_length - start_offset_length - end_offset_length
                max_spacing_length = max_spacing.is_a?(Length) ? max_spacing : middle_length * max_spacing
                spacing_count = max_spacing_length <= 0 ? 1 : (middle_length / max_spacing_length).round(3).ceil
                spacing_count = 2 if spacing_count < 2 && start_offset_length == 0 && end_offset_length == 0
                spacing = middle_length / spacing_count
                if spacing < min_spacing_length
                  spacing_count = [ (middle_length / min_spacing_length).floor, 1 ].max
                  spacing = middle_length / spacing_count
                end
                coords = []
                coords << start_offset_length if start_offset_length > 0
                coords += (1...spacing_count).map { |i| start_offset_length + spacing * i }
                coords << total_length - end_offset_length if end_offset_length > 0
              else
                coords = [ total_length / 2 ]
              end
            end

            ly = if height.is_a?(Length)
                   height
                 else
                   touching_poly_bounds.height * height
                 end

            anchor_points_2d = coords.map! { |lx| ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + lx).offset(touching_vy, ly) }
                                     .delete_if { |point| !Geom.point_in_polygon_2D(point, touching_poly_2d, true) }

            anchor_points_3d = anchor_points_2d.map { |point| point.transform(at) }

            grouped_glued_instances_a = _get_grouped_glued_instances(touching_def.face_manipulator, touching_poly)
            grouped_glued_instances_b = _get_grouped_glued_instances(touching_def.neighbor_face_manipulator, touching_poly)

            at_a = Geom::Transformation.axes(
              ORIGIN,
              x_axis.transform(ti_a),
              y_axis.transform(ti_a),
              z_axis.transform(ti_a)
            )

            at_b = Geom::Transformation.axes(
              ORIGIN,
              x_axis.transform(ti_b),
              y_axis.transform(ti_b),
              z_axis.transform(ti_b).reverse!
            )

            if touching_vy.samedirection?(Y_AXIS)
              at_a *= TRANSFORMATION_ROTATION_Z_180
              at_b *= TRANSFORMATION_ROTATION_Z_180
            end

            # A free connector keeps the min spacing away from the ones already there
            existing_coords = free ? (grouped_glued_instances_a.keys + grouped_glued_instances_b.keys).map { |coords_3d| (Geom::Point3d.new(coords_3d) - origin) % x_axis } : []

            occupied_anchor_points_3d = []
            anchor_points_3d.delete_if do |point|
              occupied = grouped_glued_instances_a.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, touching_def.face_manipulator, t_a, ti_a, at_a) } ||
                         grouped_glued_instances_b.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, touching_def.neighbor_face_manipulator, t_b, ti_b, at_b)  } ||
                         _is_free_coord_too_close?((point - origin) % x_axis, existing_coords)
              occupied_anchor_points_3d << point if occupied
              occupied
            end

            if free && touching_poly.equal?(free_touching_poly) && total_length >= geometries_bounds.width &&
               (free_range = _get_free_range(total_length, start_offset_length, end_offset_length, geometries_bounds.width / 2))
              start_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + free_range.first).offset!(touching_vy, ly).transform!(at)
              end_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + free_range.last).offset!(touching_vy, ly).transform!(at)
              origin_point_3d = ORIGIN.offset(touching_vy, ly).transform!(at)  # The active vertex, projected on the laying line
            else
              origin_point_3d = nil
              start_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + (anchor_points_3d.length > 1 ? start_offset_length : 0)).offset!(touching_vy, ly).transform!(at)
              end_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + touching_poly_bounds.width - (anchor_points_3d.length > 1 ? end_offset_length : 0)).offset!(touching_vy, ly).transform!(at)
            end

            join_defs << AddJoineryJoinDef.new(touching_poly,
                                               touching_def,
                                               anchor_points_3d,
                                               occupied_anchor_points_3d,
                                               start_point_3d,
                                               end_point_3d,
                                               at_a,
                                               at_b,
                                               origin_point_3d
            )

          end

        end

        neighbor_join_defs << AddJoineryNeighborJoinDef.new(neighbor_def, join_defs) if join_defs.any?

      end

      AddJoineryDef.new(
        neighbor_join_defs
      )
    end

    # -- Propagation --

    # Resolves the connector placements to preview and to add.
    #
    # When make_unique is true, they are simply the picked couple's anchors.
    # When make_unique is false, connectors are written directly into shared
    # definitions, so they appear on every instance. But the join is only picked
    # for one instance couple : other instances of the same definition may touch
    # other parts at the same anchor, which must also receive the mating connector.
    # This walks the contact graph A -> B -> A' -> B' -> ... adding one placement
    # per (definition, anchor), alternating the A/B role at each contact.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      seeds = []

      # A placement targets the entities that own the face (face.parent). Expressing
      # the transformation as 'face.transformation.inverse * world_frame' matches the
      # existing add path (dti * translation(pt) * at) and also handles nested faces.
      # Both slots' placements are made - partners - even when only one is laid.
      fn_seed = lambda do |face, mt, role, owner_t|
        PropagationPlacementDef.new(face.parent, face, mt, role, [ owner_t ], owner_t)
      end

      # 1. Seed with the picked couple's placements

      ti_a = neighborhood_def.ti_a

      has_geometry_a = !geometries_def.hardware_a.empty? || !geometries_def.machining_a.empty?
      has_geometry_b = !geometries_def.hardware_b.empty? || !geometries_def.machining_b.empty?

      joinery_def.neighbor_join_defs.each do |neighbor_join_def|

        ti_b = neighbor_join_def.neighbor_def.ti_b

        neighbor_join_def.join_defs.each do |join_def|

          fm_a = join_def.touching_def.face_manipulator
          fm_b = join_def.touching_def.neighbor_face_manipulator
          face_a = fm_a.face
          face_b = fm_b.face

          dti_a = (ti_a * fm_a.transformation).inverse
          dti_b = (ti_b * fm_b.transformation).inverse

          join_def.anchor_points_3d.each do |point|

            pt_a = point.transform(ti_a).project_to_plane(face_a.plane)
            pt_b = point.transform(ti_b).project_to_plane(face_b.plane)
            placement_a = fn_seed.call(face_a, dti_a * Geom::Transformation.translation(pt_a) * join_def.at_a, :a, fm_a.transformation)
            placement_b = fn_seed.call(face_b, dti_b * Geom::Transformation.translation(pt_b) * join_def.at_b, :b, fm_b.transformation)
            placement_a.partner = placement_b
            placement_b.partner = placement_a
            seeds << placement_a if has_geometry_a
            seeds << placement_b if has_geometry_b

          end

        end

      end

      if _fetch_option_make_unique?

        # 2a. No graph walk : the picked instances are made unique on add, so the
        # connectors only target the picked couple.

        placements = seeds

      else

        # 2b. Walk the contact graph

        placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

          nfm, mt_n = _find_mating_connector(wf, instance_path)
          next nil if nfm.nil?

          role_n = placement.role == :a ? :b : :a

          # A frame transported through an instance whose mirror parity differs
          # from the one its placement was resolved on carries an extra mirror.
          # Restore the role handedness (world direct for :a, indirect for :b)
          # by reversing X - the only axis whose sign is not meaningful.
          mt_n *= TRANSFORMATION_FLIP_X if TransformationUtils.flipped?(nfm.transformation * mt_n) != (role_n == :b)

          # Skip if the neighbor anchor is already physically occupied by a glued instance
          next nil if _get_glued_instances_at(nfm.face, mt_n, geometries_bounds).any?

          PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, role_n, nil, nil, nil, placement)
        end

      end

      @propagation_signature = signature
      @propagation_def = _check_hardware_asserts(placements)
    end

    # Lightweight fingerprint of the joinery inputs (active part + neighbors + anchors).
    # Used to reuse the (heavy) propagation result while nothing relevant changed.
    # Definition ids are included so that making the picked instances unique (add
    # with make_unique) discards the placements resolved during the preview.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      sig = [ instance_a.entityID, instance_a.definition.entityID, _fetch_option_make_unique? ]
      joinery_def.neighbor_join_defs.each do |neighbor_join_def|
        instance_b = neighbor_join_def.neighbor_def.instance_b
        sig << instance_b.entityID
        sig << instance_b.definition.entityID
        neighbor_join_def.join_defs.each do |join_def|
          join_def.anchor_points_3d.each { |point| sig << point.to_a.map { |c| c.to_f.round(6) } }
        end
      end
      sig
    end

    # Data Structs -----

    AddJoineryDef = Struct.new(:neighbor_join_defs)
    AddJoineryNeighborJoinDef = Struct.new(:neighbor_def, :join_defs)
    AddJoineryJoinDef = Struct.new(:touching_poly, :touching_def, :anchor_points_3d, :occupied_anchor_points_3d, :start_point_3d, :end_point_3d, :at_a, :at_b, :origin_point_3d) # origin_point_3d : where a free position is measured from, nil when distributed

  end

  class SmartJoinRemoveConnectorsActionHandler < SmartJoinConnectorsActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_REMOVE_CONNECTORS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join_minus
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      if has_active_part?
        _remove_connectors
        if _fetch_option_distribution_free?
          _refresh  # Stays on the joint, to remove the next one
        else
          _restart
        end
        return true
      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end

      false
    end

    # -----

    protected

    def _reset
      super
      @snap_anchor = nil
    end

    # -----

    def _pick_join
      context_changed = super

      if _fetch_option_distribution_free? &&
         @mouse_snap_point.is_a?(Geom::Point3d) &&
         (neighborhood_def = _get_neighborhood_def) &&
         (joinery_def = _get_remove_joinery_def(neighborhood_def))

        snap_anchor = _get_anchors(joinery_def).min { |p1, p2| @mouse_snap_point.distance(p1) <=> @mouse_snap_point.distance(p2) }

      else
        snap_anchor = nil
      end

      (context_changed || @snap_anchor != snap_anchor).tap { @snap_anchor = snap_anchor }
    end

    def _preview_join_context(neighborhood_def)
      super

      count = 0

      unless (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

        neighbor_join_defs = joinery_def.neighbor_join_defs
        neighbor_join_defs.each do |neighbor_join_def|

          neighbor_join_def.join_defs.each do |join_def|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            k_polyline.color = Kuix::COLOR_DARK_GREY
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

          end

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = COLOR_PART_B
          @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

        end

        # Preview the connectors to remove : red boxes on the picked couple,
        # translucent ones on the placements propagated through the contact graph.
        anchors = {}
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          placement.instance_transformations.each do |instance_transformation|

            picked = placement.picked?(instance_transformation)

            placement.glued_instances.each do |glued_instance|

              t = instance_transformation * glued_instance.transformation

              k_box = Kuix::BoxFillMotif3d.new
              k_box.bounds.copy!(glued_instance.definition.bounds)
              k_box.line_width = 2
              k_box.color = picked ? COLOR_REMOVE_FILL_PREVIEW : COLOR_REMOVE_FILL_PROPAGATED_PREVIEW
              k_box.on_top = true
              k_box.transformation = t
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

              k_box = Kuix::BoxMotif3d.new
              k_box.bounds.copy!(glued_instance.definition.bounds)
              k_box.line_width = 2
              k_box.color = picked ? COLOR_REMOVE_STROKE_PREVIEW : COLOR_REMOVE_STROKE_PROPAGATED_PREVIEW
              k_box.on_top = true
              k_box.transformation = t
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

            end

            anchor = ORIGIN.transform(instance_transformation * placement.transformation)
            anchors[anchor.to_a.map { |coord| coord.round(3) }] = true

            k_point = _create_floating_points(
              points: anchor,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_BLACK,
              )
            @tool.append_3d(k_point, LAYER_3D_JOIN_PREVIEW)

          end

        end

        count = anchors.length

      end

      if count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.x_connectors_to_remove', { :count => count }), SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.no_connector_to_remove'), SmartTool::MESSAGE_TYPE_WARNING)
      end

    end

    def _preview_snap_point

      @tool.clear_3d(LAYER_3D_SNAP_POINT_PREVIEW)

      if @mouse_snap_point.is_a?(Geom::Point3d) && @snap_anchor.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@mouse_snap_point)
        k_edge.end.copy!(@snap_anchor)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

      end

    end

    # -----

    def _get_anchors(joinery_def)
      joinery_def.neighbor_join_defs
                 .flat_map { |neighbor_join_def| neighbor_join_def.join_defs }
                 .flat_map { |join_defs| (join_defs.grouped_glued_instances_a.keys + join_defs.grouped_glued_instances_b.keys) }
                 .map! { |coords| coords.map! { |coord| coord.round(6) }}
                 .uniq
                 .map! { |coords| Geom::Point3d.new(coords) }
    end

    def _is_snap_anchor?(anchor)
      !@snap_anchor.is_a?(Geom::Point3d) || @snap_anchor.distance(anchor).round(3) == 0
    end

    # -----

    def _remove_connectors
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      model = Sketchup.active_model
      model.start_operation('OCL Remove Connectors', true)
      begin

        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|
          placement.glued_instances.each do |glued_instance|
            next if glued_instance.deleted?
            glued_instance.erase!
          end
        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -- Propagation --

    # Resolves the connector placements to remove. Connectors live in shared
    # definitions : erasing one removes it from every instance, so the mating
    # connectors of the parts touching the other instances must be removed too,
    # walking the contact graph (A -> B -> A' -> B' -> ...). The walk stops on
    # branches where no glued instance exists at the anchor.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      seeds = []

      # The glued instance transformation is the connector frame in the face
      # owner definition space (Z axis pointing toward the mating part)
      fn_seed = lambda do |fm, grouped_glued_instances, role|
        grouped_glued_instances.each do |anchor_coords, glued_instances|
          next unless _is_snap_anchor?(Geom::Point3d.new(anchor_coords))
          seeds << PropagationPlacementDef.new(fm.face.parent, fm.face, glued_instances.first.transformation, role, [ fm.transformation ], fm.transformation, glued_instances)
        end
      end

      joinery_def.neighbor_join_defs.each do |neighbor_join_def|
        neighbor_join_def.join_defs.each do |join_def|
          fn_seed.call(join_def.touching_def.face_manipulator, join_def.grouped_glued_instances_a, :a)
          fn_seed.call(join_def.touching_def.neighbor_face_manipulator, join_def.grouped_glued_instances_b, :b)
        end
      end

      placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

        nfm, mt_n = _find_mating_connector(wf, instance_path)
        next nil if nfm.nil?

        # Only propagate onto anchors where a mating glued instance exists
        glued_instances = _get_glued_instances_anchored_at(nfm.face, mt_n)
        next nil if glued_instances.empty?

        PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, placement.role == :a ? :b : :a, nil, nil, glued_instances)
      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(placements)
    end

    # Lightweight fingerprint of the removal inputs (active part + neighbors +
    # glued anchors + snap anchor). Used to reuse the (heavy) propagation result
    # while nothing relevant changed.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      sig = [ instance_a.entityID, instance_a.definition.entityID, @snap_anchor ]
      joinery_def.neighbor_join_defs.each do |neighbor_join_def|
        instance_b = neighbor_join_def.neighbor_def.instance_b
        sig << instance_b.entityID
        sig << instance_b.definition.entityID
        neighbor_join_def.join_defs.each do |join_def|
          sig.concat(join_def.grouped_glued_instances_a.keys)
          sig.concat(join_def.grouped_glued_instances_b.keys)
        end
      end
      sig
    end

    # -----

    def _get_remove_joinery_def(neighborhood_def)
      return nil if @active_face_manipulator_a.nil? || @active_edge_manipulator_a.nil? || @active_vertex_manipulator_a.nil?

      neighbor_join_defs = []

      neighborhood_def.neighbor_defs.each do |neighbor_def|

        join_defs = []

        neighbor_def.touching_defs
                    .select { |touching_def|
                      touching_def.face_manipulator.face != @active_face_manipulator_a.face &&
                      touching_def.face_manipulator.face.edges.any? { |edge| edge == @active_edge_manipulator_a.edge }
                    }
                    .each do |touching_def|

          touching_def.touching_polys.each do |touching_poly|

            grouped_glued_instances_a = _get_grouped_glued_instances(touching_def.face_manipulator, touching_poly)
            grouped_glued_instances_b = _get_grouped_glued_instances(touching_def.neighbor_face_manipulator, touching_poly)

            join_defs << RemoveJoineryJoinDef.new(touching_poly, touching_def, grouped_glued_instances_a, grouped_glued_instances_b)

          end

        end

        neighbor_join_defs << RemoveJoineryNeighborJoinDef.new(neighbor_def, join_defs) if join_defs.any?

      end

      RemoveJoineryDef.new(
        neighbor_join_defs
      )
    end

    # Data Structs -----

    RemoveJoineryDef = Struct.new(:neighbor_join_defs)
    RemoveJoineryNeighborJoinDef = Struct.new(:neighbor_def, :join_defs)
    RemoveJoineryJoinDef = Struct.new(:touching_poly, :touching_def, :grouped_glued_instances_a, :grouped_glued_instances_b)

  end

  # -- LINKS --

  class SmartJoinFittingsActionHandler < SmartJoinActionHandler

    STATE_SELECT_A = 1
    STATE_SELECT_B = 2

    def initialize(action, tool, previous_action_handler = nil)
      super

      @active_part_entity_path_a = nil
      @active_part_entity_path_b = nil

      @active_part_a = nil
      @active_part_b = nil

    end

    # -----

    def close_doors_on_start?
      true
    end

    # -----

    # -- STATE --

    def get_state_status(state)
      return super if state == STATE_SOURCE
      PLUGIN.get_i18n_string("tool.smart_#{@tool.get_stripped_name}.action_#{@action}_state_#{state}_status") + '.' +
        ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_option_options_opposite_status") + '.'
    end

    def get_state_cursor(state)
      case state
      when STATE_SELECT_A
        return SmartCursorManager.cursor_select_a
      end
      super
    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      case @state

      when STATE_SELECT_B
        _reset

      end
      _refresh

    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_A
        if _has_active_part_a?
          set_state(STATE_SELECT_B)
          _refresh
        end
        return true

      end

      false
    end

    def onPickerChanged(picker, view)
      super

      case @state

      when STATE_SELECT_A
        @tool.clear_3d([ LAYER_3D_JOIN_PREVIEW ])
        @tool.hide_message
        if _pick_ref_face_a(picker)
          _reset_neighborhood_def
        end
        _preview_ref_face_a(picker)
        return true

      when STATE_SELECT_B
        @tool.clear_3d([ LAYER_3D_JOIN_PREVIEW, LAYER_3D_SNAP_POINT_PREVIEW ])
        @tool.clear_2d(LAYER_2D_DIMENSIONS)
        @tool.hide_message
        if _pick_ref_face_b(picker)
          _reset_neighborhood_def
        end
        if _snap_ref_point_b(picker)
          _reset_joinery_def
        end
        _preview_ref_face_a
        _preview_join(picker)
        return true

      end
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)

      case @state

      when STATE_SELECT_A
        _preview_part(part_entity_path, part, LAYER_3D_PART_A_PREVIEW, highlighted: highlighted)
        @active_part_entity_path_a = part_entity_path
        @active_part_a = part
        @active_face_manipulator_a = nil

      when STATE_SELECT_B
        _preview_part(part_entity_path, part, LAYER_3D_PART_B_PREVIEW, highlighted: highlighted)
        @active_part_entity_path_b = part_entity_path
        @active_part_b = part
        @active_face_manipulator_b = nil

      end

      _reset_neighborhood_def
    end

    # -----

    protected

    def _get_select_state
      STATE_SELECT_A
    end

    def _reset
      super
      @mouse_snap_point = nil
      _reset_active_part_a
      _reset_active_part_b
      _reset_neighborhood_def
      set_state(get_startup_state)
    end

    def _reset_active_part_a
      @active_part_entity_path_a = nil
      @active_part_a = nil
      @active_face_manipulator_a = nil
    end

    def _reset_active_part_b
      @active_part_entity_path_b = nil
      @active_part_b = nil
      @active_face_manipulator_b = nil
    end

    def _reset_neighborhood_def
      @neighborhood_def = nil
      @propagation_def = nil
      _reset_joinery_def
    end

    def _reset_joinery_def
      @joinery_def = nil
    end

    # -- Propagation --

    # Lateral step used to probe inside a face body from its axis edge
    PROPAGATION_PROBE_LATERAL_OFFSET = 1.mm

    # Characterizes the picked couple's dihedral relationship :
    # - 'mate_transformation' maps a fitting frame to its mating frame (a
    #   rotation around the shared X axis - the joint axis - by the dihedral
    #   angle) ; apply its inverse to go the other way (b -> a)
    # - 'side_a' / 'side_b' tell on which lateral side (+1 : +Y, -1 : -Y of
    #   their frame) each face body extends from the axis
    def _get_propagation_context(line_def)

      x_axis = line_def.line_manipulator.direction

      fm_a = line_def.face_manipulator
      fm_b = line_def.neighbor_face_manipulator

      z_axis_a = fm_a.normal
      y_axis_a = z_axis_a * x_axis
      z_axis_b = fm_b.normal
      y_axis_b = z_axis_b * x_axis

      point = line_def.start_point

      [
        Geom::Transformation.axes(ORIGIN, x_axis, y_axis_a, z_axis_a).inverse * Geom::Transformation.axes(ORIGIN, x_axis, y_axis_b, z_axis_b),
        (fm_a.centroid - point) % y_axis_a >= 0 ? 1 : -1,
        (fm_b.centroid - point) % y_axis_b >= 0 ? 1 : -1
      ]
    end

    # Probes for the part mating the given expected fitting world frame 'wf' :
    # the mate face lies on the frame XY plane (which contains the joint axis
    # = X) with its material behind (-Z). The anchor sits on the face's axis
    # edge, so the probe point is stepped laterally (side * +Y) into the face
    # body. Returns [ face_manipulator, mt ] - where 'mt' is the mating fitting
    # frame expressed in the mate face owner definition space - or nil.
    def _find_mating_fitting(wf, side, instance_path, tolerance = 0.001.mm)

      world_point = ORIGIN.transform(wf)
      world_y = Y_AXIS.transform(wf)
      world_y.normalize!
      world_z = Z_AXIS.transform(wf)
      world_z.normalize!

      probe_point = world_point.offset(world_y, PROPAGATION_PROBE_LATERAL_OFFSET * side)

      fn_accept = lambda do |fm|
        fm.normal.samedirection?(world_z) &&                                             # Same normal (the fitting is glued ON the face)
          world_point.distance_to_plane([ fm.position, fm.normal ]).to_f < tolerance &&  # Anchor on the face plane
          _is_point_on_face?(fm, probe_point)                                            # Probe point within the face
      end

      nfm = _raytest_part_face(probe_point.offset(world_z, tolerance * 10), world_z.reverse, instance_path, &fn_accept)
      nfm = _find_part_face_at(probe_point, instance_path, tolerance, &fn_accept) if nfm.nil?
      return nil if nfm.nil?

      [ nfm, nfm.transformation.inverse * wf ]
    end

    def _refresh
      _reset_active_part
      _reset_active_part_b
      @mouse_snap_point = nil
      @picker.invalidate if @picker.is_a?(SmartPicker)
      super
    end

    # -----

    def _get_active_part_preview_color(part, highlighted = false)
      case @state
      when STATE_SELECT_A
        COLOR_PART_A
      when STATE_SELECT_B
        COLOR_PART_B
      end
    end

    # B, previewed while A is still the active part - the hinge handlers pick
    # both at once.
    def _get_path_part_preview_color(path, part, highlighted = false)
      return COLOR_PART_B if !path.nil? && path == @active_part_entity_path_b && path != @active_part_entity_path
      super
    end

    # -----

    def _has_active_part_a?
      @active_part_a.is_a?(Part)
    end

    def _has_active_part_b?
      @active_part_b.is_a?(Part)
    end

    # -----

    def _pick_ref_face_a(picker)
      _pick_ref_face(picker, :_has_active_part_a?, :@active_face_manipulator_a)
    end

    def _pick_ref_face_b(picker)
      _pick_ref_face(picker, :_has_active_part_b?, :@active_face_manipulator_b)
    end

    def _pick_ref_face(picker, check_method_name, var_name)

      face_manipulator = self.send(check_method_name) ? picker.picked_plane_manipulator : nil
      if face_manipulator.is_a?(FaceManipulator)

        if _fetch_option_opposite?
          snap_point, face_manipulator = _pick_opposite_face_at(picker.picked_point, face_manipulator)
        else
          snap_point = picker.picked_point
        end

      else
        snap_point = nil
        face_manipulator = nil
      end

      (self.instance_variable_get(var_name) != face_manipulator).tap do
        @mouse_snap_point = snap_point
        self.instance_variable_set(var_name, face_manipulator)
      end
    end

    def _snap_ref_point_b(picker)
      false
    end

    def _preview_ref_face_a(picker = nil)
      _preview_ref_face(picker, @active_face_manipulator_a, COLOR_REF_FACE_A, COLOR_REF_DARKEN_A)
    end

    def _preview_ref_face_b(picker = nil)
      _preview_ref_face(picker, @active_face_manipulator_b, COLOR_REF_FACE_B, COLOR_REF_DARKEN_B)
    end

    def _preview_ref_face(picker, face_manipulator, color, darken_color)
      if face_manipulator.is_a?(FaceManipulator)

        arrow_length = Sketchup.active_model.active_view.pixels_to_model(60, face_manipulator.centroid)
        arrow_size = 15

        # Offset transformation to force mesh to be on top of part preview
        ov = Geom::Vector3d.new(face_manipulator.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # --

        # Colorize face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(face_manipulator.triangles)
        k_mesh.background_color = color
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

        # --

        # Draw face normal arrow
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(face_manipulator.centroid)
        k_edge.end.copy!(face_manipulator.centroid.offset(face_manipulator.normal, arrow_length))
        k_edge.line_width = 2
        k_edge.end_arrow = true
        k_edge.arrow_size = arrow_size
        k_edge.color = darken_color
        k_edge.on_top = false
        @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        # Draw face normal arrow (dashed)
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(face_manipulator.centroid)
        k_edge.end.copy!(face_manipulator.centroid.offset(face_manipulator.normal, arrow_length))
        k_edge.line_width = 1.5
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_edge.end_arrow = true
        k_edge.arrow_size = arrow_size
        k_edge.color = darken_color
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        # --

        # Draw face outer edges
        k_polyline = Kuix::Polyline.new
        k_polyline.add_points(face_manipulator.outer_loop_manipulator.points)
        k_polyline.line_width = 1
        k_polyline.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_polyline.color = darken_color
        k_polyline.closed = true
        k_polyline.on_top = true
        @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

        # --

        # Draw "opposite" point (if possible)
        if @mouse_snap_point && picker && @mouse_snap_point != picker.picked_point

          k_point = _create_floating_points(
            points: @mouse_snap_point,
            style: Kuix::POINT_STYLE_DIAMOND,
            fill_color: color,
            stroke_color: Kuix::COLOR_DARK_GREY,
            stroke_width: 1,
            )
          @tool.append_3d(k_point, LAYER_3D_JOIN_PREVIEW)

          k_edge = Kuix::EdgeMotif3d.new
          k_edge.start.copy!(picker.picked_point)
          k_edge.end.copy!(@mouse_snap_point)
          k_edge.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_edge.line_width = 1
          k_edge.color = Kuix::COLOR_DARK_GREY
          k_edge.on_top = true
          @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        end

      end
    end

    def _preview_join(picker)
      _preview_ref_face_b(picker)
    end

    # -----

    def _pick_opposite_face_at(point, face_manipulator)
      model = Sketchup.active_model
      view = model.active_view
      face_point = Geom.intersect_line_plane([ view.camera.eye, view.camera.eye.vector_to(point) ], face_manipulator.plane)
      point = face_point if face_point.is_a?(Geom::Point3d) # Point may be out of the face plane, so override it if we have found a best candidate.
      hit_point, hit_path = model.raytest([ point, face_manipulator.normal.reverse ], true)
      if hit_point &&
         (face = hit_path.last).is_a?(Sketchup::Face) &&
         face.parent == face_manipulator.face.parent &&
         (hit_face_manipulator = FaceManipulator.new(face, PathUtils.get_transformation(hit_path))).normal.parallel?(face_manipulator.normal)

        return [ hit_point, hit_face_manipulator ]

      end
      [ point, face_manipulator ]
    end

    # ------

    # The part A of the joint - the one its face A belongs to : the active
    # part A, unless the handler reads its face elsewhere.
    def _get_joint_part_entity_path_a
      @active_part_entity_path_a
    end

    # The points of the side A of the joint the joint line is bounded by : the
    # outer loop of its face A, unless the handler reads more than that face.
    def _get_joint_points_a
      @active_face_manipulator_a.outer_loop_manipulator.points
    end

    def _get_neighborhood_def(tolerance = 0.001)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless _has_active_part_a? && _has_active_part_b?
      return nil if (part_entity_path_a = _get_joint_part_entity_path_a) == @active_part_entity_path_b
      return nil unless @active_face_manipulator_a.is_a?(FaceManipulator) && @active_face_manipulator_b.is_a?(FaceManipulator)

      if (line = Geom.intersect_plane_plane(@active_face_manipulator_a.plane, @active_face_manipulator_b.plane))

        line_manipulator = LineManipulator.new(line)

        pos_a = _get_joint_points_a
                                        .map { |point| p = point.project_to_line(line); [ (p - line_manipulator.position) % line_manipulator.direction, p ] }
                                        .sort_by! { |pos, _| pos }
        pos_b = @active_face_manipulator_b.outer_loop_manipulator
                                        .points
                                        .map { |point| p = point.project_to_line(line); [ (p - line_manipulator.position) % line_manipulator.direction, p ] }
                                        .sort_by! { |pos, _| pos }

        # Compute bounds intersection

        pos_s, point_s = [ pos_a.first, pos_b.first ].max { |(pos1, _), (pos2, _)| pos1 <=> pos2 }
        pos_e, point_e = [ pos_a.last, pos_b.last ].min { |(pos1, _), (pos2, _)| pos1 <=> pos2 }

        return nil if pos_s > pos_e || point_s.distance(point_e).to_f < tolerance # No intersection

        neighbor_def = NeighborhoodNeighborDef.new(
          @active_part_entity_path_b,
          NeighborhoodLineDef.new(
            @active_face_manipulator_a,
            @active_face_manipulator_b,
            line_manipulator,
            point_s,
            point_e
          )
        )

      else
        return nil
      end

      # Keep useful data

      @neighborhood_def = NeighborhoodDef.new(
        part_entity_path_a,
        neighbor_def
      )
    end

    # Data Structs -----

    NeighborhoodDef = Struct.new(:path, :neighbor_def) do
      def instance_a
        path.last
      end
      def t_a
        @t_a ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_a
        @ti_a ||= t_a.inverse
      end
    end
    NeighborhoodNeighborDef = Struct.new(:path, :line_def) do
      def instance_b
        path.last
      end
      def t_b
        @t_b ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_b
        @ti_b ||= t_b.inverse
      end
    end
    NeighborhoodLineDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :line_manipulator, :start_point, :end_point)

  end

  class SmartJoinAddFittingsActionHandler < SmartJoinFittingsActionHandler

    include UserTextHelper
    include SmartActionHandlerDoorHelper

    def initialize(tool, previous_action_handler = nil, action = SmartJoinTool::ACTION_ADD_FITTINGS)
      super(action, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      case state
      when STATE_SELECT_B
        return SmartCursorManager.cursor_select_join_plus
      end
      super
    end

    def get_state_status(state)
      return super if state == STATE_SOURCE
      super +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_3") + '.'
    end

    # -----

    def onToolUserText(tool, text, view)
      return true if _read_free_position(tool, text, view)
      return true if _read_measures(tool, text, view)

      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_B
        if _has_active_part_b?
          _add_fittings
          _restart
        else
          UI.beep
        end
        return true

      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_shift?(key)
        _on_shift_changed if repeat == 1
        return true
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key)
        _on_shift_changed
        return true
      end
      if tool.is_key_ctrl_or_option?(key)
        @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_OPPOSITE, !_fetch_option_opposite?, fire_event: true)
        return true
      end

      false
    end

    # -----

    def enableVCB?
      @state != STATE_SOURCE
    end

    # -----

    protected

    def _get_hardware_types
      [ HardwareDescriptorDef::TYPE_FITTING ]
    end

    def _reset
      super
      @snap_start_point = nil
      @free_position = nil
    end

    # -----

    def _add_at_free_position
      _reset_joinery_def
      if _has_active_part_b? && (neighborhood_def = _get_neighborhood_def) && (joinery_def = _get_add_joinery_def(neighborhood_def)) && !joinery_def.join_def.anchor_points_3d.empty?
        _add_fittings
        _restart
      else
        _reset_joinery_def
        UI.beep
      end
    end

    # -----

    def _snap_ref_point_b(picker)
      return false if (neighborhood_def = _get_neighborhood_def).nil?
      return false unless (snap_origin_point = _get_snap_origin_point(picker)).is_a?(Geom::Point3d)

      line_def = neighborhood_def.neighbor_def.line_def

      snap_start_point = [ line_def.start_point, line_def.end_point ].min { |p1, p2| p1.distance(snap_origin_point) <=> p2.distance(snap_origin_point) }

      # Free : measured from the same end until the mouse comes close to the other one
      if _fetch_option_distribution_free? && @snap_start_point.is_a?(Geom::Point3d) && snap_start_point != @snap_start_point &&
         [ line_def.start_point, line_def.end_point ].include?(@snap_start_point) &&
         !_is_free_origin_switch?(snap_origin_point, snap_start_point)
        snap_start_point = @snap_start_point == line_def.start_point ? line_def.start_point : line_def.end_point
      end

      snap_end_point = snap_start_point == line_def.start_point ? line_def.end_point : line_def.start_point

      # Free : the hardware follows the mouse along the line
      free_position = _fetch_option_distribution_free? ? _get_free_position(snap_start_point, snap_start_point.vector_to(snap_end_point), snap_origin_point) : nil

      # Returns true if changed
      (@snap_start_point != snap_start_point || !_same_free_position?(@free_position, free_position)).tap {
        @snap_start_point = snap_start_point
        @free_position = free_position
      }
    end

    # The point the fittings are counted from the nearest end of the joint
    # line of - see #_snap_ref_point_b.
    def _get_snap_origin_point(picker)
      picker.picked_point
    end

    def _preview_join(picker)
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      super

      # Preview line

      line_def = neighborhood_def.neighbor_def.line_def

      k_points = _create_floating_points(
        points: [ line_def.start_point, line_def.end_point ],
        style: Kuix::POINT_STYLE_CIRCLE,
        fill_color: Kuix::COLOR_MAGENTA,
        stroke_color: nil,
        size: 1.5
      )
      @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      if @snap_start_point.is_a?(Geom::Point3d) && (snap_origin_point = _get_snap_origin_point(picker)).is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(snap_origin_point)
        k_edge.end.copy!(@snap_start_point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

        k_point = _create_floating_points(
          points: @snap_start_point,
          style: Kuix::POINT_STYLE_CIRCLE,
          fill_color: Kuix::COLOR_MAGENTA,
          stroke_color: Kuix::COLOR_WHITE,
          )
        @tool.append_3d(k_point, LAYER_3D_SNAP_POINT_PREVIEW)

      end

      join_def = joinery_def.join_def

      if _fetch_option_distribution_free? && @snap_start_point.is_a?(Geom::Point3d) && join_def.anchor_points_3d.length == 1
        snap_end_point = @snap_start_point == line_def.start_point ? line_def.end_point : line_def.start_point
        _preview_free_position(@snap_start_point, @snap_start_point.vector_to(snap_end_point), join_def.anchor_points_3d.first)
      end

      unless join_def.anchor_points_3d.empty?

        # Preview anchors

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(join_def.origin_point_3d || join_def.start_point_3d)
        k_edge.end.copy!(join_def.end_point_3d)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1.5
        k_edge.color = Kuix::COLOR_MAGENTA
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

        _preview_free_range_bounds(join_def) if _fetch_option_distribution_free?

        k_points = _create_floating_points(
          points: join_def.anchor_points_3d,
          style: Kuix::POINT_STYLE_PLUS,
          stroke_color: Kuix::COLOR_MAGENTA
        )
        @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

        # Preview geometries

        geometries_def = _get_geometries_def
        hardware_a = geometries_def.hardware_a
        hardware_b = geometries_def.hardware_b
        machining_a = geometries_def.machining_a
        machining_b = geometries_def.machining_b

        fn_preview_join_segments = lambda do |segments, transformation, color, line_width|

          k_segments = Kuix::Segments.new
          k_segments.add_segments(segments)
          k_segments.color = color
          k_segments.line_width = line_width
          k_segments.transformation = transformation
          k_segments.on_top = true
          @tool.append_3d(k_segments, LAYER_3D_JOIN_PREVIEW)

        end

        # Preview the fittings : only the picked couple's placements when
        # make_unique is true, every instance of the touched definitions otherwise.
        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

          hardware = placement.role == :a ? hardware_a : hardware_b
          machining = placement.role == :a ? machining_a : machining_b
          machining_segments = _get_geometry_preview_segments(machining, placement)
          hardware_segments = _get_geometry_preview_segments(hardware, placement)

          placement.instance_transformations.each do |instance_transformation|

            t = instance_transformation * placement.transformation
            picked = placement.picked?(instance_transformation)

            # -- Machinings --

            fn_preview_join_segments.call(
              machining_segments,
              t * _get_geometry_mirror_transformation(machining),
              picked ? COLOR_MACHINING_PREVIEW : COLOR_MACHINING_PROPAGATED_PREVIEW,
              0.5
            ) if machining_segments

            # -- Hardware --

            fn_preview_join_segments.call(
              hardware_segments,
              t * _get_geometry_mirror_transformation(hardware),
              picked ? COLOR_HARDWARE_PREVIEW : COLOR_HARDWARE_PROPAGATED_PREVIEW,
              1
            ) if hardware_segments

          end

        end

        # -- Door opening --

        _preview_door_opening(_get_propagation_def(neighborhood_def, joinery_def), geometries_def)

      end

      k_points = _create_floating_points(
        points: join_def.occupied_anchor_points_3d,
        style: Kuix::POINT_STYLE_CROSS,
        stroke_color: Kuix::COLOR_RED,
        stroke_width: 2
      )
      @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      no_valid_join = join_def.anchor_points_3d.empty?
      occupied_anchor_count = join_def.occupied_anchor_points_3d.length

      if occupied_anchor_count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.occupied_anchors', { :count => occupied_anchor_count }), SmartTool::MESSAGE_TYPE_ERROR)
      elsif !no_valid_join && _show_refused_anchors(_get_propagation_def(neighborhood_def, joinery_def))
      elsif no_valid_join
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.no_valid_join'), SmartTool::MESSAGE_TYPE_ERROR)
      end

    end

    # Previews how the part turns on the hinges being added, when the hardware
    # is a hinge (see DoorDef) : its axis, the arcs its far corners sweep, and
    # the part itself wide open. Read off the first picked placement of the
    # hinge's role - the others lie on the same joint line, so on the same axis.
    def _preview_door_opening(propagation_def, geometries_def)

      [ :a, :b ].each do |role|
        next if (geometry = _get_hinge_geometry(geometries_def, role)).nil?

        placement = propagation_def.placements.find { |p| p.role == role && !p.seed_transformation.nil? }
        next if placement.nil?
        next if (hinge_def = _get_preview_hinge_def(geometry, placement)).nil?
        next if (drawing_def = _get_door_drawing_def(placement.definition)).nil?

        # Door definition space -> world, from closed to wide open
        _preview_door_swing(placement.seed_transformation, hinge_def.axis_line, 0, hinge_def.max_angle, drawing_def, LAYER_3D_JOIN_PREVIEW)

      end

    end

    # The geometry of the given slot bearing the hinge's attributes - see
    # DoorDef - nil when that slot lays no hinge : its hardware, when its
    # SKP or its descriptor gives it the hinge role.
    def _get_hinge_geometry(geometries_def, slot)
      hardware = slot == :a ? geometries_def.hardware_a : geometries_def.hardware_b
      return nil if hardware.empty?
      return hardware if DefinitionAttributes.role_of(hardware.definition) == DefinitionAttributes::ROLE_HINGE
      component = _get_hardware_component(slot)
      !component.nil? && DefinitionAttributes.valid_role(component.attributes['role']) == DefinitionAttributes::ROLE_HINGE ? hardware : nil
    end

    # The hinge the given geometry will be, laid at the given placement : its
    # kinematics as they will be written - the descriptor's over those of its
    # SKP - and its transformation as it will be laid - mirrored, shifted by
    # its offset - set in the space the given transformation takes the
    # placement's definition to, its own by default. nil when they lack a
    # valid pivot or max angle.
    def _get_preview_hinge_def(geometry, placement, outer_transformation = IDENTITY)
      attributes = {}
      if geometry.definition.is_a?(Sketchup::ComponentDefinition) && (dictionary = geometry.definition.attribute_dictionary(Plugin::ATTRIBUTE_DICTIONARY))
        attributes = dictionary.to_h
      end
      component = _get_hardware_component(geometry.slot)
      attributes = attributes.merge(component.attributes) unless component.nil?
      transformation = placement.transformation * _get_geometry_mirror_transformation(geometry) * Geom::Transformation.translation([ 0, 0, _get_geometry_offset(geometry, placement) ])
      DoorHingeDef.from_attributes(attributes, outer_transformation * transformation)
    end

    # -----

    def _read_measures(tool, text, view)

      start_offset, end_offset, min_spacing, max_spacing = _split_user_text(text)

      if start_offset.is_a?(String) && !start_offset.empty?
        return true if _read_measure(tool, start_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET, 'tool.smart_join.error.invalid_start_offset')
      end
      if end_offset.is_a?(String) && !end_offset.empty?
        return true if _read_measure(tool, end_offset, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET, 'tool.smart_join.error.invalid_end_offset')
      end

      if min_spacing.is_a?(String) && !min_spacing.empty?
        return true if _read_measure(tool, min_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING, 'tool.smart_join.error.invalid_min_spacing', length_only: true)
      end
      if max_spacing.is_a?(String) && !max_spacing.empty?
        return true if _read_measure(tool, max_spacing, SmartJoinTool::ACTION_OPTION_SPACINGS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING, 'tool.smart_join.error.invalid_max_spacing')
      end

      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      true
    end

    # -----

    def _add_fittings
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      model = Sketchup.active_model
      model.start_operation('OCL Add Fittings', true)
      begin

        _add_joint_fittings(neighborhood_def, joinery_def)

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # Lays the fittings of the given joint - making its parts unique first
    # when make_unique. To call inside an operation.
    def _add_joint_fittings(neighborhood_def, joinery_def)

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      instance_a = neighborhood_def.instance_a
      definition_a = instance_a.definition
      entities_a = definition_a.entities

      instance_b = neighbor_def.instance_b
      definition_b = instance_b.definition
      entities_b = definition_b.entities

      geometries_def = _get_geometries_def
      hardware_a = geometries_def.hardware_a
      hardware_b = geometries_def.hardware_b
      machining_a = geometries_def.machining_a
      machining_b = geometries_def.machining_b
      hardware_material = geometries_def.hardware_material
      machining_material = geometries_def.machining_material
      hardware_layer = geometries_def.hardware_layer
      machining_layer = geometries_def.machining_layer

      if _fetch_option_make_unique?

        if !hardware_a.empty? || !machining_a.empty?

          # Make unique Part A (if necessary)

          u_instance_a = instance_a.make_unique
          u_definition_a = u_instance_a.definition
          if u_definition_a != definition_a

            u_entities_a = u_definition_a.entities

            face = line_def.face_manipulator.face
            if face.parent == definition_a
              face_index = entities_a.to_a.index(face)
              u_face = u_entities_a[face_index]
              if u_face
                line_def.face_manipulator = FaceManipulator.new(u_face, line_def.face_manipulator.transformation)
              end
            end

          end

        end

        if !hardware_b.empty? || !machining_b.empty?

          # Make unique Part B (if necessary)

          u_instance_b = instance_b.make_unique
          u_definition_b = u_instance_b.definition
          if u_definition_b != definition_b

            u_entities_b = u_definition_b.entities

            neighbor_face = line_def.neighbor_face_manipulator.face
            if neighbor_face.parent == definition_b
              neighbor_face_index = entities_b.to_a.index(neighbor_face)
              u_neighbor_face = u_entities_b[neighbor_face_index]
              if u_neighbor_face
                line_def.neighbor_face_manipulator = FaceManipulator.new(u_neighbor_face, line_def.neighbor_face_manipulator.transformation)
              end
            end

          end

        end

      end

      # Add the fittings : only the picked couple's placements when make_unique
      # is true, the whole contact graph (A -> B -> A' -> B' -> ...) otherwise.
      _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

        hardware = placement.role == :a ? hardware_a : hardware_b
        machining = placement.role == :a ? machining_a : machining_b

        _add_geometry(hardware, placement, hardware_material, hardware_layer)
        _add_geometry(machining, placement, machining_material, machining_layer)

      end

    end

    # -- Propagation --

    # Resolves the fitting placements to preview and to add.
    #
    # When make_unique is true, they are simply the picked couple's anchors.
    # When make_unique is false, fittings are written directly into shared
    # definitions, so they appear on every instance. Other instances of the same
    # definition may form the same dihedral configuration with other parts, which
    # must also receive the mating fitting : the contact graph walk adds one
    # placement per (definition, anchor), alternating the A/B role and skipping
    # anchors already occupied by a glued instance.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      ti_a = neighborhood_def.ti_a
      ti_b = neighbor_def.ti_b

      fm_a = line_def.face_manipulator
      fm_b = line_def.neighbor_face_manipulator
      face_a = fm_a.face
      face_b = fm_b.face

      dti_a = (ti_a * fm_a.transformation).inverse
      dti_b = (ti_b * fm_b.transformation).inverse

      has_geometry_a = !geometries_def.hardware_a.empty? || !geometries_def.machining_a.empty?
      has_geometry_b = !geometries_def.hardware_b.empty? || !geometries_def.machining_b.empty?

      # 1. Seed with the picked couple's placements

      seeds = []

      # Both slots' placements are made - partners - even when only one is laid.
      joinery_def.join_def.anchor_points_3d.each do |point|

        pt_a = point.transform(ti_a).project_to_plane(face_a.plane)
        pt_b = point.transform(ti_b).project_to_plane(face_b.plane)
        placement_a = PropagationPlacementDef.new(face_a.parent, face_a, dti_a * Geom::Transformation.translation(pt_a) * joinery_def.at_a, :a, [ fm_a.transformation ], fm_a.transformation)
        placement_b = PropagationPlacementDef.new(face_b.parent, face_b, dti_b * Geom::Transformation.translation(pt_b) * joinery_def.at_b, :b, [ fm_b.transformation ], fm_b.transformation)
        placement_a.partner = placement_b
        placement_b.partner = placement_a
        seeds << placement_a if has_geometry_a
        seeds << placement_b if has_geometry_b

      end

      if _fetch_option_make_unique?

        # 2a. No graph walk : the picked instances are made unique on add, so the
        # fittings only target the picked couple.

        placements = seeds

      else

        # 2b. Walk the contact graph

        mate_transformation, side_a, side_b = _get_propagation_context(line_def)
        mate_transformation_inverse = mate_transformation.inverse

        placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

          from_a = placement.role == :a
          nfm, mt_n = _find_mating_fitting(wf * (from_a ? mate_transformation : mate_transformation_inverse), from_a ? side_b : side_a, instance_path)
          next nil if nfm.nil?

          # A frame transported through an instance whose mirror parity differs
          # from the one its placement was resolved on carries an extra mirror.
          # Restore the handedness (world direct for both roles) by reversing X
          # - the only axis whose sign is not meaningful.
          mt_n *= TRANSFORMATION_FLIP_X if TransformationUtils.flipped?(nfm.transformation * mt_n)

          # Skip if the neighbor anchor is already physically occupied by a glued instance
          next nil if _get_glued_instances_at(nfm.face, mt_n, geometries_bounds).any?

          PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, from_a ? :b : :a, nil, nil, nil, placement)
        end

      end

      @propagation_signature = signature
      @propagation_def = _check_hardware_asserts(placements)
    end

    # Lightweight fingerprint of the joinery inputs (picked couple + anchors).
    # Definition ids are included so that making the picked instances unique (add
    # with make_unique) discards the placements resolved during the preview.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      instance_b = neighborhood_def.neighbor_def.instance_b
      sig = [ instance_a.entityID, instance_a.definition.entityID, instance_b.entityID, instance_b.definition.entityID, _fetch_option_make_unique? ]
      joinery_def.join_def.anchor_points_3d.each { |point| sig << point.to_a.map { |c| c.to_f.round(6) } }
      sig
    end

    # -----

    def _get_add_joinery_def(neighborhood_def)
      return @joinery_def unless @joinery_def.nil?

      return nil if neighborhood_def.neighbor_def.nil?

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      t_a = neighborhood_def.t_a
      ti_a = neighborhood_def.ti_a
      t_b = neighbor_def.t_b
      ti_b = neighbor_def.ti_b

      start_offset = _fetch_option_start_offset
      end_offset = _fetch_option_end_offset
      min_spacing = _fetch_option_min_spacing
      max_spacing = _fetch_option_max_spacing

      geometries_def = _get_geometries_def
      geometries_bounds = geometries_def.bounds

      v = line_def.start_point.vector_to(line_def.end_point)

      total_length = v.length
      start_offset_length = start_offset.is_a?(Length) ? start_offset : total_length * start_offset
      start_offset_length = 0 if start_offset_length < geometries_bounds.width / 2
      end_offset_length = end_offset.is_a?(Length) ? end_offset : total_length * end_offset
      end_offset_length = 0 if end_offset_length < geometries_bounds.width / 2

      min_spacing_length = [ min_spacing, geometries_bounds.width ].max

      free = _fetch_option_distribution_free?
      free_position = @typed_free_position || @free_position

      if total_length < geometries_bounds.width
        # Touching face is not large enough to contain at least one join
        coords = []
      elsif free
        coord = free_position.nil? ? nil : _get_free_coord(free_position, total_length, start_offset_length, end_offset_length, geometries_bounds.width / 2)
        coords = coord.nil? ? [] : [ coord ]
      else
        if total_length > start_offset_length + min_spacing_length + end_offset_length
          middle_length = total_length - start_offset_length - end_offset_length
          max_spacing_length = max_spacing.is_a?(Length) ? max_spacing : middle_length * max_spacing
          spacing_count = max_spacing_length <= 0 ? 1 : (middle_length / max_spacing_length).round(3).ceil
          spacing_count = 2 if spacing_count < 2 && start_offset_length == 0 && end_offset_length == 0
          spacing = middle_length / spacing_count
          if spacing < min_spacing_length
            spacing_count = [ (middle_length / min_spacing_length).floor, 1 ].max
            spacing = middle_length / spacing_count
          end
          coords = []
          coords << start_offset_length if start_offset_length > 0
          coords += (1...spacing_count).map { |i| start_offset_length + spacing * i }
          coords << total_length - end_offset_length if end_offset_length > 0
        else
          coords = [ total_length / 2 ]
        end
      end

      x_axis = line_def.line_manipulator.direction

      z_axis_a = line_def.face_manipulator.normal
      y_axis_a = z_axis_a * x_axis

      z_axis_b = line_def.neighbor_face_manipulator.normal
      y_axis_b = z_axis_b * x_axis

      at_a = Geom::Transformation.axes(
        ORIGIN,
        x_axis.transform(ti_a),
        y_axis_a.transform(ti_a),
        z_axis_a.transform(ti_a)
      )

      at_b = Geom::Transformation.axes(
        ORIGIN,
        x_axis.transform(ti_b),
        y_axis_b.transform(ti_b),
        z_axis_b.transform(ti_b)
      )

      if @snap_start_point == line_def.start_point
        ps = line_def.start_point
        pe = line_def.end_point
      else
        ps = line_def.end_point
        pe = line_def.start_point
        v = v.reverse
      end

      anchor_points_3d = coords.map { |lx| ps.offset(v, lx) }

      poly_3d = [ line_def.start_point, line_def.start_point, line_def.end_point ] # Fake flat poly by doubbleling start point

      grouped_glued_instances_a = _get_grouped_glued_instances(line_def.face_manipulator, poly_3d)
      grouped_glued_instances_b = _get_grouped_glued_instances(line_def.neighbor_face_manipulator, poly_3d)

      # A free hardware keeps the min spacing away from the ones already there
      existing_coords = free ? (grouped_glued_instances_a.keys + grouped_glued_instances_b.keys).map { |coords_3d| (Geom::Point3d.new(coords_3d) - ps) % v.normalize } : []

      occupied_anchor_points_3d = []
      anchor_points_3d.delete_if do |point|
        occupied = grouped_glued_instances_a.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, line_def.face_manipulator, t_a, ti_a, at_a) } ||
                   grouped_glued_instances_b.any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, line_def.neighbor_face_manipulator, t_b, ti_b, at_b)  } ||
                   _is_free_coord_too_close?((point - ps) % v.normalize, existing_coords)
        occupied_anchor_points_3d << point if occupied
        occupied
      end

      if free && total_length >= geometries_bounds.width && (free_range = _get_free_range(total_length, start_offset_length, end_offset_length, geometries_bounds.width / 2))
        start_point_3d = ps.offset(v, free_range.first)
        end_point_3d = ps.offset(v, free_range.last)
        origin_point_3d = ps
      else
        origin_point_3d = nil
        start_point_3d = ps.offset(v, anchor_points_3d.length > 1 ? start_offset_length : 0)
        end_point_3d = pe.offset(v.reverse, anchor_points_3d.length > 1 ? end_offset_length : 0)
      end

      @joinery_def = AddJoineryDef.new(
        at_a,
        at_b,
        AddJoineryJoinDef.new(
          anchor_points_3d,
          occupied_anchor_points_3d,
          start_point_3d,
          end_point_3d,
          origin_point_3d
        )
      )
    end

    # Data Structs -----

    AddJoineryDef = Struct.new(:at_a, :at_b, :join_def)
    AddJoineryJoinDef = Struct.new(:anchor_points_3d, :occupied_anchor_points_3d, :start_point_3d, :end_point_3d, :origin_point_3d) # origin_point_3d : where a free position is measured from, nil when distributed

  end

  # HINGES : the fittings of a door (see DoorDef), laid by HOVERING the
  # FRONT PANEL near the edge it turns on, and a click.
  #
  # The side of the carcass the door turns on is read off the CAVITIES of the
  # carcass rather than off the model (see CavitiesDef#pick_ray) : the front
  # panel stands in the mouth, in front of everything it could turn on, and
  # an applied panel is no wall of the cavities it closes. A probe ray is
  # cast into them, past the hovered edge, from in front of the door ; the
  # wall it lands on, facing that edge, is the side's inner face (B) - and
  # the back of the door, the face turned towards the cavities, is A. A
  # being the door is what sets the fitting frame the hinge data are read in.
  #
  # The edge is the one nearest the cursor, the LONG edges favoured - the
  # sides of an ordinary door - without being the only ones : a square door,
  # a flap turning on its top edge, a door of more than four edges.
  #
  # Whether the door is laid ON the carcass or IN its mouth is read off the
  # same two faces - an inset door's back stands behind the front of the
  # side. A door covering no more than half the front edge of the side - the
  # middle side two doors share, whatever the other one is - or laid on a
  # side ANOTHER front panel is laid on too, is a HALF overlay one. The kind
  # picks the hardware and machining of A.
  #
  # A door may be made of SEVERAL parts - the stiles and rails of a frame
  # door - held by a group or a component bearing ROLE_FRONT_PANEL : any of
  # them picks it. Its back is then the union of the backs of its parts
  # lying on one plane (see DoorBackDef), and each hinge is laid into the
  # part under it - one straddling two parts is left out. The joint gets one
  # part A per part a hinge lands on (see #_get_hinge_joints), and making
  # them unique goes down from the door (see #_make_unique_door_parts) : the
  # door is the instance that turns (see DoorDef).
  class SmartJoinAddHingesActionHandler < SmartJoinAddFittingsActionHandler

    include SmartActionHandlerCavitiesHelper

    # One pick : the door, near the side it turns on - handled as the
    # fittings' part A.
    STATE_SELECT = STATE_SELECT_A

    # How far the door may stand PAST the inner face of the side it turns on -
    # an applique covers the side's edge - and how far SHORT of it - an inset
    # door leaves a gap. Beyond, the side is no edge of that door : a divider
    # it runs across, a side of the neighbouring compartment.
    HINGE_SIDE_MAX_OVERHANG = 50.mm
    HINGE_SIDE_MAX_GAP = 10.mm

    # How far behind the front of the side the back of the door has to stand
    # to be read as INSET.
    INSET_MIN_DEPTH = 1.mm

    # How far from the door's back plane the back of a neighbouring front
    # panel laid on the same side may stand - a slight misalignment.
    HALF_OVERLAY_MAX_OFFSET = 10.mm

    HINGE_KIND_OVERLAY = :overlay
    HINGE_KIND_HALF_OVERLAY = :half_overlay
    HINGE_KIND_INSET = :inset

    # How squarely a cavity's mouth has to face the door for the cavity to be
    # one the door closes - about 8°. The same goes for the wall the probe ray
    # lands on, against the edge it was cast past.
    HINGE_MOUTH_MIN_DOT = 0.99

    # How deep, behind the door, a cavity's wall has to run along the side for
    # a hinge base to be screwed on it : the sliver a setback plinth leaves
    # behind the front plane is open towards the door too.
    HINGE_CAVITY_MIN_DEPTH = 20.mm

    # The probe ray (see #_probe_hinge_side) starts HINGE_PROBE_REACH in front
    # of the door's back and twice that inside its edge, and runs at 45°
    # towards the edge : it crosses the mouth HINGE_PROBE_REACH inside the
    # edge, clear of a side an applique covers, and meets the side as far
    # behind the mouth. Cast again further along the edge when it finds no
    # cavity - a fixed shelf, a plinth at the height of the cursor : by
    # HINGE_PROBE_STEP either way, then at the middle and the quarters of
    # the edge.
    HINGE_PROBE_REACH = 100.mm
    HINGE_PROBE_STEP = 60.mm

    def initialize(tool, previous_action_handler = nil)
      super(tool, previous_action_handler, SmartJoinTool::ACTION_ADD_HINGES)
    end

    # -----

    def stop
      _cancel_cavities_dwell
      super
    end

    # -----

    # -- STATE --

    def get_state_status(state)
      return super if state == STATE_SOURCE
      super +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_#{SmartJoinTool::ACTION_REMOVE_HINGES}") + '.'
    end

    def get_state_cursor(state)
      return super if state == STATE_SOURCE
      SmartCursorManager.cursor_select_join_plus
    end

    # -----

    # A pick on the move only designates carcasses in passing, see
    # SmartActionHandlerCavitiesHelper#_defer_cavities.
    def onToolMouseMove(tool, flags, x, y, view)
      _defer_cavities { super }
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      return true if _flush_cavities_dwell   # Still waiting for the cavities : the click asks for them
      if _has_active_part_b? && (neighborhood_def = _get_neighborhood_def) && (joinery_def = _get_add_joinery_def(neighborhood_def)) && !joinery_def.join_def.anchor_points_3d.empty?
        _add_fittings
        _restart
      else
        UI.beep
      end
      true
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      if tool.is_key_shift?(key)
        _on_shift_changed
        return true
      end
      false # No opposite face here : both faces are deduced
    end

    def onPickerChanged(picker, view)
      @tool.clear_3d([ LAYER_3D_JOIN_PREVIEW, LAYER_3D_SNAP_POINT_PREVIEW, LAYER_3D_PART_B_PREVIEW ])
      @tool.clear_2d(LAYER_2D_DIMENSIONS)
      @tool.hide_message
      _pick_part(picker, view)
      _reset_neighborhood_def if _pick_hinge_side(picker)
      _reset_joinery_def if _snap_ref_point_b(picker)
      if _has_active_part_b?
        _preview_part(@active_part_entity_path_b, @active_part_b, LAYER_3D_PART_B_PREVIEW)
        _preview_ref_face_a
        _preview_join(picker)
        _show_hinge_kind_tooltip
      else
        _remove_hinge_kind_tooltip
        @tool.show_message(PLUGIN.get_i18n_string(@hinge_side_error), SmartTool::MESSAGE_TYPE_ERROR) if @hinge_side_error.is_a?(String)
      end
      true
    end

    def onToolGlobalPresetChanged(tool, dictionary, section)
      @geometries_defs = nil
      super
    end

    def onToolTransactionUndo(tool, model)
      _reset_cavities_def
      _reset_door_caches
    end

    # -----

    protected

    def _get_select_state
      STATE_SELECT
    end

    def _get_hardware_types
      [ HardwareDescriptorDef::TYPE_HINGE ]
    end

    # The kind of the door selects the variant of A.
    def _get_hardware_context
      { 'hinge_kind' => @hinge_kind.to_s }
    end

    def _reset
      super
      @hinge_side_error = nil
      @hinge_pick_point = nil
      @hinge_kind = HINGE_KIND_OVERLAY
      @hinge_door_back = nil
      @hinge_edge = nil
      @hinge_part_entity_path_a = nil
    end

    def _reset_joinery_def
      super
      @hinge_forced_make_unique = nil
      @hinge_anchor_members = nil
      @hinge_joints = nil
      @hinge_propagation_def = nil
    end

    # What the faces of the door are read from changes with the model.
    def _reset_door_caches
      @door_face_manipulators = nil
      @door_part_entity_paths = nil
      @door_backs = nil
    end

    # Forced on when laying the hinges into the shared definitions would hang
    # a door on more than one edge, or a door made of several parts would get
    # them on its other occurrences - see #_get_propagation_def.
    def _fetch_option_make_unique?
      !@hinge_forced_make_unique.nil? || super
    end

    # The hardware of A is the hinge.
    def _write_hardware_attributes(definition, slot)
      super
      _write_hinge_attributes(definition) if slot == :a
    end

    # A hinge without hardware : the machining of A stands in for it, bearing
    # the hinge's attributes - in a definition of its own when it is given as
    # primitives, one of them being otherwise shared by any fitting drilled
    # the same.
    def _get_geometry_definition(geometry, placement, material = nil)
      definition = super
      if definition.is_a?(Sketchup::ComponentDefinition) && _hinge_machining?(geometry)
        _write_component_attributes(definition, _get_hardware_component(:a))
        _write_hinge_attributes(definition)
      end
      definition
    end

    # The geometry bearing the hinge's attributes - its hardware, or its
    # machining without one - is found by them too : two hinges drilled the
    # same may turn differently.
    def _get_geometry_definition_key(geometry, dimensions)
      return super unless geometry.slot == :a && (geometry.part == :hardware || _hinge_machining?(geometry))
      "#{DefinitionAttributes::ROLE_HINGE}:#{_get_hardware_component(:a).attributes.to_json}:#{super}"
    end

    # The hardware of the hinge given as primitives is generated as they
    # give it, not centered : its kinematics are given in that frame - the
    # one the bench shows them in.
    def _get_primitives_offset(primitives, placement)
      return 0.0 if primitives == _get_hardware_component_primitives(:a, :hardware)
      super
    end

    # A is the hinge : its hardware, or its machining without one.
    def _get_hinge_geometry(geometries_def, slot)
      return super unless slot == :a
      geometries_def.hardware_a.empty? ? (geometries_def.machining_a.empty? ? nil : geometries_def.machining_a) : geometries_def.hardware_a
    end

    # Is the given geometry the machining of a hinge without hardware ?
    def _hinge_machining?(geometry)
      return false unless geometry.slot == :a && geometry.part == :machining
      component = _get_hardware_component(:a)
      !component.nil? && component.hardware.nil?
    end

    # The given definition is a hinge : it bears the hinge role whatever its
    # descriptor or its SKP say - what DoorDef finds the hinges of a door by.
    # Its pivot lengths without a unit are in the unit of the model it is
    # laid in : they are given it, to read the same wherever it goes.
    def _write_hinge_attributes(definition)
      return unless definition.is_a?(Sketchup::ComponentDefinition)
      DefinitionAttributes.write_role(definition, DefinitionAttributes::ROLE_HINGE) unless DefinitionAttributes.role_of(definition) == DefinitionAttributes::ROLE_HINGE
      pivot = definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_PIVOT)
      unless HardwareDescriptorDef.hinge_pivot(pivot).nil?
        pivot_with_units = pivot.map { |value| DimensionUtils.get_unit_sign(value).nil? ? DimensionUtils.str_add_units(value, true) : value }
        definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, DoorDef::HINGE_ATTRIBUTE_PIVOT, pivot_with_units) unless pivot_with_units == pivot
      end
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      can_activate, error_key, error_vars = super
      return [ can_activate, error_key, error_vars ] unless can_activate
      return [ false, 'tool.smart_join.error.not_front_panel' ] if part_entity_path.is_a?(Array) && _get_door_entity_path(part_entity_path).nil?   # Nil path : a reset, always allowed
      true
    end

    # -- Door --

    # The DOOR the given part belongs to : the path to the nearest entity of
    # its path - the part itself, or a group or a component holding it -
    # bearing ROLE_FRONT_PANEL. nil when there is none.
    def _get_door_entity_path(part_entity_path = @active_part_entity_path_a)
      return nil unless part_entity_path.is_a?(Array)
      return nil if (index = part_entity_path.rindex { |entity| DefinitionAttributes.role_of(entity) == DefinitionAttributes::ROLE_FRONT_PANEL }).nil?
      part_entity_path[0..index]
    end

    # The part hovered of a door made of several stands for the whole door :
    # it is the whole door that is highlighted.
    def _preview_part(part_entity_path, part, layer = LAYER_3D_PART_PREVIEW, highlighted: false, clear_before: true)
      return super unless layer == LAYER_3D_PART_A_PREVIEW && part.is_a?(Part) && (door_entity_path = _get_door_entity_path(part_entity_path)).is_a?(Array) && door_entity_path.length < part_entity_path.length
      @tool.clear_3d(layer) if clear_before
      _preview_door_assembly(door_entity_path, _get_path_part_preview_color(part_entity_path, part, highlighted), _get_path_part_preview_offset(part_entity_path, part, highlighted), layer)
    end

    # Is the active door made of several parts - the active part being one of
    # them ?
    def _is_door_assembly?
      !(door_entity_path = _get_door_entity_path).nil? && door_entity_path.length < @active_part_entity_path_a.length
    end

    # The paths of the parts the given door is made of : itself, or the
    # components it holds - through the groups it holds too, as the cutlist
    # reads them. Neither what is laid in them - hardware, machinings,
    # hinges - nor a front or back panel held inside : a panel inside a panel
    # is none.
    def _get_door_part_entity_paths(door_entity_path)
      return [ door_entity_path ] if door_entity_path == @active_part_entity_path_a
      @door_part_entity_paths = {} unless @door_part_entity_paths.is_a?(Hash)
      key = PathUtils.serialize_path(door_entity_path)
      return @door_part_entity_paths[key] if @door_part_entity_paths.key?(key)

      fn_collect = lambda { |path, paths|
        path.last.definition.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          next if entity.definition.behavior.always_face_camera? || entity.definition.behavior.cuts_opening?
          next unless DoorDef.hinge_frame(entity).nil?
          next if DefinitionAttributes.applied_panel_role?(DefinitionAttributes.role_of(entity))
          type = _get_material_attributes(entity.material).type
          next if type == MaterialAttributes::TYPE_MACHINING || type == MaterialAttributes::TYPE_HARDWARE
          if entity.is_a?(Sketchup::ComponentInstance)
            paths << path + [ entity ]
          else
            fn_collect.call(path + [ entity ], paths)
          end
        end
        paths
      }
      @door_part_entity_paths[key] = fn_collect.call(door_entity_path, [])
    end

    # The BACK of the door : the faces of its parts turned towards the
    # cavities, on one plane - [ face_manipulator, part_entity_path ] pairs -
    # and the outline of their union, the outer loop of the face of a door
    # made of one part.
    DoorBackDef = Struct.new(:normal, :position, :members, :points) do
      def plane
        [ position, normal ]
      end
    end

    # -----

    # Nothing to lean the cavities on but the back panels : the front panel
    # the side is aimed through, laid on or in the mouth, has to leave that
    # mouth open - see CommonSolidFindCavitiesWorker, APPLIED PANELS. A back
    # set back in its groove still closes the compartment, as it does for
    # SmartBuildTool's front panels.
    def _cavities_recess_panel_types
      [ DefinitionAttributes::ROLE_BACK_PANEL ]
    end

    # The cavities are the carcass' : the door's container, not the
    # assembly a part of a frame door is held by.
    def _get_cavities_part_entity_path
      part_entity_path = get_active_part_entity_path
      _get_door_entity_path(part_entity_path) || part_entity_path
    end

    # The cavities of the door's carcass - nil while they wait for the pick
    # to dwell there, see SmartActionHandlerCavitiesHelper#_get_cavities_def.
    def _get_door_cavities_def
      return nil unless _has_active_part_a? && (door_entity_path = _get_door_entity_path).is_a?(Array)
      _get_cavities_def(door_entity_path, @active_part_a)
    end

    # -----

    # The side the hovered door turns on, and both faces of the joint - see
    # the class comment. Fills @active_part_entity_path_b, @active_part_b,
    # @active_face_manipulator_a and _b and @hinge_kind, or clears them and
    # names the reason in @hinge_side_error. Returns whether the joint
    # changed.
    def _pick_hinge_side(picker)

      side = nil
      door_back = nil
      @hinge_side_error = nil
      @hinge_pick_point = nil

      catch(:done) do

        throw :done unless (cavities_def = _get_door_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?
        throw :done unless (cursor = picker.picked_point).is_a?(Geom::Point3d)

        @hinge_side_error = 'tool.smart_join.error.no_hinge_cavity'
        throw :done unless (door_back = _get_door_back(cavities_def)).is_a?(DoorBackDef)

        @hinge_side_error = 'tool.smart_join.error.no_hinge_side'
        @hinge_pick_point = cursor.project_to_plane(door_back.plane)

        # The edges, nearest the cursor first - the distance to an edge
        # stretched by how much shorter it is than the longest one
        edges = _get_loop_edges(door_back.points)
        max_length = edges.map { |p1, p2| p1.distance(p2) }.max

        # A door already hung turns on one side only : the edge its hinges
        # run along
        unless (hinged_edge = _get_hinged_edge(edges)).nil?
          @hinge_side_error = 'tool.smart_join.error.hinged_side_lost'
          edges = [ hinged_edge ]
        end
        edges.map { |p1, p2|
          length = p1.distance(p2)
          point = _closest_point_on_segment(@hinge_pick_point, p1, p2)
          [ @hinge_pick_point.distance(point) * max_length / length, p1, p2, point ]
        }.sort_by(&:first).each do |_, p1, p2, point|
          side = _probe_hinge_side(cavities_def, door_back, p1, p2, point)
          break unless side.nil?
        end
        throw :done if side.nil?

        @hinge_side_error = nil

      end

      part_entity_path_b, part_b, face_manipulator_a, face_manipulator_b, kind, part_entity_path_a, edge = side
      kind = HINGE_KIND_OVERLAY if kind.nil?

      changed = @active_face_manipulator_a != face_manipulator_a || @active_face_manipulator_b != face_manipulator_b || @active_part_entity_path_b != part_entity_path_b || @hinge_kind != kind || @hinge_part_entity_path_a != part_entity_path_a

      @active_part_entity_path_b = part_entity_path_b
      @active_part_b = part_b
      @active_face_manipulator_a = face_manipulator_a
      @active_face_manipulator_b = face_manipulator_b
      @hinge_kind = kind
      @hinge_part_entity_path_a = part_entity_path_a
      @hinge_door_back = side.nil? ? nil : door_back
      @hinge_edge = edge

      changed
    end

    # The joint's part A is the part of the door its face A belongs to - the
    # door itself, unless it is made of several.
    def _get_joint_part_entity_path_a
      @hinge_part_entity_path_a || super
    end

    # The joint line runs along the whole edge of the door, whatever part
    # bears it.
    def _get_joint_points_a
      @hinge_door_back.is_a?(DoorBackDef) ? @hinge_door_back.points : super
    end

    # The edge, among the given ones of the door's back, its hinges already
    # run along - parallel to their joint lines, nearest their origins - nil
    # when the door has none yet.
    def _get_hinged_edge(edges)
      door_entity_path = _get_door_entity_path
      return nil if (hinges = DoorDef.door_hinge_instances(door_entity_path.last)).empty?

      t = PathUtils.get_transformation(door_entity_path, IDENTITY)
      hinge_transformations = hinges.map { |hinge, transformation| t * transformation * hinge.transformation }
      direction = hinge_transformations.first.xaxis
      edges.select { |p1, p2| p1.vector_to(p2).parallel?(direction) }.min_by { |p1, p2|
        hinge_transformations.map { |ht| ht.origin.distance_to_line([ p1, p2 ]) }.max
      }
    end

    # The side the door would turn on along the given edge of its back -
    # [ part_entity_path_b, part_b, face_manipulator_a, face_manipulator_b,
    # kind, part_entity_path_a, [ p1, p2, inward ] ] - or nil when the probe
    # ray cast past it finds none.
    def _probe_hinge_side(cavities_def, door_back, p1, p2, point)

      na = door_back.normal
      length = p1.distance(p2)
      direction = p1.vector_to(p2).normalize
      inward = (na * direction).normalize
      inward.reverse! unless _is_point_on_door_back?(door_back, Geom.linear_combination(0.5, p1, 0.5, p2).offset(inward, 1.mm))

      position = (point - p1) % direction
      [ position, position + HINGE_PROBE_STEP, position - HINGE_PROBE_STEP, length * 0.5, length * 0.25, length * 0.75 ].each do |probe_position|
        next unless probe_position >= 0 && probe_position <= length
        origin = p1.offset(direction, probe_position).offset(inward, HINGE_PROBE_REACH * 2).offset(na, -HINGE_PROBE_REACH)
        picked = cavities_def.pick_ray(origin, Geom::Vector3d.linear_combination(-1, inward, 1, na).normalize)
        next if picked.nil?

        _, wall_point, plane_manipulator, wall_drawing_def = picked
        next unless plane_manipulator.is_a?(PlaneManipulator)
        next unless wall_drawing_def.is_a?(DrawingDef) && (wall_path = wall_drawing_def.container_path).is_a?(Array) && !wall_path.empty?
        next unless (wall_part = cavities_def.part_of(wall_drawing_def)).is_a?(Part)

        # B : the face of the side the wall was read from, facing the edge
        wall_normal = plane_manipulator.normal
        face_manipulator_b = _get_part_face_manipulators(wall_path).find { |fm|
          fm.normal.parallel?(wall_normal) &&
            wall_point.distance_to_plane(fm.plane).to_f < 0.01.mm &&
            _is_point_on_face?(fm, wall_point)
        }
        next if face_manipulator_b.nil?
        next unless face_manipulator_b.normal % inward > HINGE_MOUTH_MIN_DOT

        # The side must be an EDGE of the door : the door ends near its inner face
        pb = face_manipulator_b.position
        nb = face_manipulator_b.normal
        overhang = door_back.points.map { |p| (pb - p) % nb }.max
        next unless overhang < HINGE_SIDE_MAX_OVERHANG && overhang > -HINGE_SIDE_MAX_GAP

        # INSET when the front of the side stands in front of the door's back
        pa = door_back.position
        if face_manipulator_b.outer_loop_manipulator.points.map { |p| (p - pa) % na }.min < -INSET_MIN_DEPTH
          kind = HINGE_KIND_INSET
        elsif _is_half_overlay?(wall_path, door_back, face_manipulator_b, overhang, [ p1.offset(direction, probe_position), p1.offset(direction, length * 0.5) ])
          kind = HINGE_KIND_HALF_OVERLAY
        else
          kind = HINGE_KIND_OVERLAY
        end

        # A : the face of the part of the door bearing the most of the edge
        face_manipulator_a, part_entity_path_a = _get_edge_door_member(door_back, p1, direction, inward, length)
        next if face_manipulator_a.nil?

        return [ wall_path, wall_part, face_manipulator_a, face_manipulator_b, kind, part_entity_path_a, [ p1, p2, inward ] ]
      end

      nil
    end

    # The member of the given door back - [ face_manipulator,
    # part_entity_path ] - bearing the most of the given edge of it, read just
    # inside it. nil when none does.
    def _get_edge_door_member(door_back, p1, direction, inward, length)
      return door_back.members.first if door_back.members.length == 1
      counts = Hash.new(0)
      (0..10).each do |i|
        point = p1.offset(direction, length * (i + 0.5) / 11.0).offset(inward, 1.mm)
        member = door_back.members.find { |fm, _| _is_point_on_face?(fm, point) }
        counts[member] += 1 unless member.nil?
      end
      return nil if counts.empty?
      counts.max_by { |_, count| count }.first
    end

    # The member of the door back - [ face_manipulator, part_entity_path ] -
    # the given anchor of the joint lands on : the one bearing its whole
    # width along the hinged edge, read just inside it. nil when the anchor
    # straddles two parts.
    def _get_anchor_door_member(point, half_width)
      p1, p2, inward = @hinge_edge
      direction = p1.vector_to(p2).normalize
      origin = point.project_to_line([ p1, direction ]).offset(inward, 1.mm)
      half_width = [ half_width.to_f - 0.1.mm.to_f, 0.0 ].max
      points = [ origin, origin.offset(direction, half_width), origin.offset(direction, -half_width) ]
      @hinge_door_back.members.find { |fm, _| points.all? { |p| _is_point_on_face?(fm, p) } }
    end

    def _is_point_on_door_back?(door_back, point)
      door_back.members.any? { |fm, _| _is_point_on_face?(fm, point) }
    end

    # Whether the door is a half overlay one : it covers no more than half the
    # front edge of the side - room left for another door, laid on or set in
    # the next mouth alike - or another front panel is laid on that edge, past
    # the door's edge - the other door of a pair sharing a middle side. The
    # ray is cast forward - against the back's normal, which points into the
    # carcass - from just behind the door's back plane, at the middle of what
    # the door leaves uncovered of the side's front edge, abreast of each of
    # the given points of the joint, up to HINGE_PROBE_REACH. The first front
    # panel it meets counts if its back lies on the door's back plane : the
    # ray may well miss that back, coplanar with the side's front edge -
    # raytest reports a single face per hit - and meet its front instead. A
    # door covering the whole edge leaves no room for one : a full overlay.
    def _is_half_overlay?(wall_path, door_back, face_manipulator_b, overhang, points)

      na = door_back.normal
      pa = door_back.position
      pb = face_manipulator_b.position
      nb = face_manipulator_b.normal
      forward = na.reverse

      # The side's outer face : the farthest from its inner face, back to back
      outer_distance = _get_part_face_manipulators(wall_path).select { |fm| fm.normal.samedirection?(nb.reverse) }.map { |fm| (pb - fm.position) % nb }.max
      return false if outer_distance.nil?
      uncovered = outer_distance.to_f - overhang.to_f
      return false if uncovered < 1.mm.to_f
      return true if overhang.to_f <= outer_distance.to_f / 2

      offset = overhang.to_f + uncovered / 2
      door_serialized = PathUtils.serialize_path(_get_door_entity_path)
      model = Sketchup.active_model

      points.any? do |point|

        # On the door's back plane, 'offset' outside the side's inner face
        origin = point.project_to_plane(face_manipulator_b.plane).offset(nb, -offset).project_to_plane(door_back.plane).offset(forward, -INSET_MIN_DEPTH)
        found = false
        10.times do
          hit_point, hit_path = model.raytest([ origin, forward ])
          break if hit_path.nil? || ((hit_point - pa) % forward).to_f > HINGE_PROBE_REACH.to_f

          part_path = _get_part_entity_path_from_path(hit_path)
          while part_path.is_a?(Array) && part_path.length > 1 && part_path.last.respond_to?(:glued_to) && !part_path.last.glued_to.nil?
            part_path = _get_part_entity_path_from_path(part_path[0...-1])
          end
          if part_path.is_a?(Array) && !part_path.empty? &&
             (other_door_path = _get_door_entity_path(part_path)).is_a?(Array) &&
             PathUtils.serialize_path(other_door_path) != door_serialized
            found = _get_part_face_manipulators(part_path).any? { |fm| fm.normal.samedirection?(na) && ((fm.position - pa) % na).abs < HALF_OVERLAY_MAX_OFFSET.to_f }
            break
          end

          origin = hit_point.offset(forward, 0.01.mm)
        end
        found
      end

    end

    # The kind of the door - see the class comment - and the hinge it gets,
    # next to the cursor. Rebuilt only when either changes, or when another
    # tooltip took its place.
    def _show_hinge_kind_tooltip
      hardware = _fetch_option_hardware_a
      key = [ @hinge_kind, hardware ]
      return if key == @hinge_kind_tooltip_key && @tool.current_tooltip?(@hinge_kind_tooltip_box)
      items = [ [ _get_hinge_kind_motif, "#" + PLUGIN.get_i18n_string("tool.smart_join.action_option_hardware_hinge_#{@hinge_kind}_a") ] ]
      items << _get_hardware_definition_name(:a, :hardware) if hardware.is_a?(String) && !hardware.empty?
      @hinge_kind_tooltip_key = key
      @hinge_kind_tooltip_box = @tool.show_tooltip(items)
    end

    # The kind of the door seen from above, the front down - drawn as
    # SmartBuildTool draws its overlay options : the hatched side, and the
    # door laid on its whole edge, sharing it with another, or set beside it.
    def _get_hinge_kind_motif
      case @hinge_kind
      when HINGE_KIND_INSET
        path = 'M0,.75V1H.625V.75ZM.75,0V1H1V0M.875,0L1,.125M.75,.875L.875,1M.75,.375L1,.625M.75,.625L1,.875M.75,.125L1,.375'
      when HINGE_KIND_HALF_OVERLAY
        path = 'M0,.75V1H.438V.75ZM.563,.75V1H1V.75ZM.375,0V.625H.625V0M.5,0L.625,.125M.375,.375L.625,.625M.375,.125L.625,.375'
      else
        path = 'M0,.75V1H1V.75ZM.75,0V.625H1V0M.875,0L1,.125M.75,.375L1,.625M.75,.125L1,.375'
      end
      Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(path))
    end

    # Removes the tooltip of #_show_hinge_kind_tooltip - not another one, the
    # error of a part that cannot be picked.
    def _remove_hinge_kind_tooltip
      @tool.remove_tooltip if @tool.current_tooltip?(@hinge_kind_tooltip_box)
      @hinge_kind_tooltip_key = nil
      @hinge_kind_tooltip_box = nil
    end

    # The BACK of the door (see DoorBackDef) : the broadest plane its parts
    # have faces on - their areas summed - turned towards the cavities : a
    # point a little in front of one of them lies in one. nil when none is.
    # Memoized per door, for the cavities it was read against.
    #
    # Not the centroid alone : a fixed shelf flush with the front, at mid
    # height of the door, stands right in front of it. Halfway towards each
    # corner too.
    #
    # Not the broadest alone either : the panel of a frame door, recessed,
    # may well be broader than the frame around it. The back is the plane
    # turned the same way standing the deepest towards the cavities - as
    # long as it is not a mere sliver of the door.
    def _get_door_back(cavities_def)
      door_entity_path = _get_door_entity_path
      @door_backs = {} unless @door_backs.is_a?(Hash)
      key = [ PathUtils.serialize_path(door_entity_path), cavities_def.object_id ]
      return @door_backs[key] if @door_backs.key?(key)

      planes = []
      _get_door_part_entity_paths(door_entity_path).each do |part_entity_path|
        _get_part_face_manipulators(part_entity_path).each do |fm|
          plane = planes.find { |pl| pl[:normal].samedirection?(fm.normal) && fm.position.distance_to_plane([ pl[:position], pl[:normal] ]).to_f < 0.01.mm.to_f }
          planes << (plane = { normal: fm.normal, position: fm.position, members: [], area: 0.0 }) if plane.nil?
          plane[:members] << [ fm, part_entity_path ]
          plane[:area] += fm.face.area(fm.transformation)
        end
      end

      back = planes.sort_by { |pl| -pl[:area] }.first(4).find { |pl|
        pl[:members].any? { |fm, _|
          centroid = fm.centroid
          points = [ centroid ] + fm.outer_loop_manipulator.points.map { |point| Geom.linear_combination(0.5, centroid, 0.5, point) }.select { |point| _is_point_on_face?(fm, point) }
          points.any? { |point| cavities_def.fragment_defs_for_point(point.offset(fm.normal, HINGE_CAVITY_MIN_DEPTH)).any? }
        }
      }
      unless back.nil?
        back = planes.select { |pl| pl[:normal].samedirection?(back[:normal]) && pl[:area] >= back[:area] * DOOR_BACK_MIN_AREA_RATIO }
                     .max_by { |pl| (pl[:position] - back[:position]) % back[:normal] }
      end
      @door_backs[key] = back.nil? ? nil : DoorBackDef.new(back[:normal], back[:position], back[:members], _get_door_back_outline(back[:members], back[:position], back[:normal]))
    end

    # How broad, at least, a plane standing deeper than the broadest one has
    # to be to be the back of the door - see #_get_door_back.
    DOOR_BACK_MIN_AREA_RATIO = 0.1

    # The outline of the union of the given faces, on the given plane, in
    # world space : the outer loop of the broadest piece of it. Faces
    # touching - the stiles and rails of a frame door - meet across a hair
    # of a gap closed before, and opened again after.
    DOOR_BACK_UNION_GAP = 0.1.mm

    def _get_door_back_outline(members, position, normal)
      return members.first.first.outer_loop_manipulator.points if members.length == 1

      t = Geom::Transformation.new(position, normal)
      ti = t.inverse
      rpaths = members.map { |fm, _| fm.outer_loop_manipulator.points.flat_map { |point| point.transform(ti).to_a[0..1].map(&:to_f) } }

      clippy = Fiddle::Clippy
      gap = DOOR_BACK_UNION_GAP.to_f
      rpaths = clippy.inflate_paths(paths: rpaths, delta: gap, join_type: clippy::JOIN_TYPE_MITER)
      rpaths, _ = clippy.execute_union(closed_subjects: rpaths)
      rpaths = clippy.inflate_paths(paths: rpaths, delta: -gap, join_type: clippy::JOIN_TYPE_MITER)
      rpath = rpaths.max_by { |path| clippy.get_rpath_area(path).abs }
      return members.max_by { |fm, _| fm.face.area(fm.transformation) }.first.outer_loop_manipulator.points if rpath.nil?

      clippy.rpath_to_points(rpath).map { |point| point.transform(t) }
    end

    # The edges of the given loop, as [ start, end ] pairs - consecutive
    # collinear segments merged.
    def _get_loop_edges(points)
      edges = []
      points.each_with_index do |point, index|
        next_point = points[(index + 1) % points.length]
        next if point == next_point
        if !edges.empty? && edges.last[0].vector_to(edges.last[1]).parallel?(point.vector_to(next_point))
          edges.last[1] = next_point
        else
          edges << [ point, next_point ]
        end
      end
      if edges.length > 1 && edges.last[0].vector_to(edges.last[1]).parallel?(edges.first[0].vector_to(edges.first[1]))
        edges.first[0] = edges.pop[0]
      end
      edges
    end

    def _closest_point_on_segment(point, p1, p2)
      v = p1.vector_to(p2)
      t = [ [ (point - p1) % v / (v % v), 0.0 ].max, 1.0 ].min
      Geom.linear_combination(1 - t, p1, t, p2)
    end

    # The joint line, cut down to the CAVITIES the door closes : the part of
    # the side's inner face that is a wall of a compartment behind the door.
    # A side runs past its compartments - over the top and the bottom, down
    # to the floor under a plinth - and the door past them too, over the
    # panels' edges : neither is where a hinge base can be screwed.
    def _get_neighborhood_def(tolerance = 0.001)
      return @neighborhood_def unless @neighborhood_def.nil?
      return nil if (neighborhood_def = super).nil?

      line_def = neighborhood_def.neighbor_def.line_def
      if (ranges = _get_hinge_cavity_ranges(line_def))
        start_point = line_def.start_point
        direction = start_point.vector_to(line_def.end_point).normalize
        @hinge_cavity_spans = ranges.map { |min, max| [ start_point.offset(direction, min), start_point.offset(direction, max) ] }
        line_def.end_point = @hinge_cavity_spans.last.last
        line_def.start_point = @hinge_cavity_spans.first.first
      else
        @hinge_cavity_spans = nil
        @neighborhood_def = nil
      end

      @neighborhood_def
    end

    # The hinges that would land BETWEEN two of the cavities - on the edge of
    # a fixed shelf, of a rail - are left out : only a hinge whose footprint
    # along the joint line stands whole against one cavity wall is kept. So
    # is, on a door made of several parts, one straddling two of them : each
    # hinge is laid into the part under it - see #_get_hinge_joints - and
    # one already laid in another part than A's is in the way as well.
    #
    # The anchors left out are kept in @hinge_rejected_anchor_points, to be
    # shown.
    def _get_add_joinery_def(neighborhood_def)
      return @joinery_def unless @joinery_def.nil?
      @hinge_rejected_anchor_points = []
      return nil if (joinery_def = super).nil?

      half_width = _get_geometries_def.bounds.width / 2

      if @hinge_cavity_spans.is_a?(Array) && @hinge_cavity_spans.length > 1

        origin = @hinge_cavity_spans.first.first
        direction = origin.vector_to(@hinge_cavity_spans.last.last).normalize
        spans = @hinge_cavity_spans.map { |p_min, p_max| [ (p_min - origin) % direction, (p_max - origin) % direction ] }

        joinery_def.join_def.anchor_points_3d.delete_if do |point|
          position = (point - origin) % direction
          rejected = spans.none? { |min, max| position - half_width >= min - 0.01.mm && position + half_width <= max + 0.01.mm }
          @hinge_rejected_anchor_points << point if rejected
          rejected
        end

      end

      if @hinge_door_back.is_a?(DoorBackDef) && @hinge_door_back.members.length > 1 && @hinge_edge.is_a?(Array)

        line_def = neighborhood_def.neighbor_def.line_def
        poly_3d = [ line_def.start_point, line_def.start_point, line_def.end_point ]
        geometries_bounds = _get_geometries_def.bounds
        main_face_manipulator = line_def.face_manipulator

        @hinge_anchor_members = []
        joinery_def.join_def.anchor_points_3d.delete_if do |point|
          member = _get_anchor_door_member(point, half_width)
          if member.nil?
            @hinge_rejected_anchor_points << point
            next true
          end
          fm, part_entity_path = member
          unless fm.face == main_face_manipulator.face && fm.transformation.to_a == main_face_manipulator.transformation.to_a
            t, ti, at = _get_joint_part_frame(part_entity_path, line_def)
            if _get_grouped_glued_instances(fm, poly_3d).any? { |_, glued_instances| _is_geometries_intersect_glued_instances?(geometries_bounds, point, glued_instances, fm, t, ti, at) }
              joinery_def.join_def.occupied_anchor_points_3d << point
              next true
            end
          end
          @hinge_anchor_members << [ point, member ]
          false
        end

      end

      joinery_def
    end

    # The transformation of the given part of the door, its inverse, and the
    # fitting frame of A in its space - see
    # SmartJoinAddFittingsActionHandler#_get_add_joinery_def.
    def _get_joint_part_frame(part_entity_path, line_def)
      t = PathUtils.get_transformation(part_entity_path, IDENTITY)
      ti = t.inverse
      x_axis = line_def.line_manipulator.direction
      z_axis = line_def.face_manipulator.normal
      at = Geom::Transformation.axes(ORIGIN, x_axis.transform(ti), (z_axis * x_axis).transform(ti), z_axis.transform(ti))
      [ t, ti, at ]
    end

    # The joints the given one is laid as - [ neighborhood_def, joinery_def ]
    # pairs : itself, unless its anchors land on several parts of the door,
    # or on another one than its part A. Then one per part, the anchors that
    # land on it and its face A.
    def _get_hinge_joints(neighborhood_def, joinery_def)
      return [ [ neighborhood_def, joinery_def ] ] unless neighborhood_def.equal?(@neighborhood_def) && joinery_def.equal?(@joinery_def) && @hinge_anchor_members.is_a?(Array)
      return @hinge_joints if @hinge_joints.is_a?(Array)

      line_def = neighborhood_def.neighbor_def.line_def
      main_part_serialized = PathUtils.serialize_path(neighborhood_def.path)
      groups = @hinge_anchor_members.group_by { |_, (_, part_entity_path)| PathUtils.serialize_path(part_entity_path) }

      if groups.empty? || groups.keys == [ main_part_serialized ]
        @hinge_joints = [ [ neighborhood_def, joinery_def ] ]
      else
        join_def = joinery_def.join_def
        @hinge_joints = groups.values.map { |anchor_members|
          fm, part_entity_path = anchor_members.first.last
          sub_line_def = NeighborhoodLineDef.new(fm, line_def.neighbor_face_manipulator, line_def.line_manipulator, line_def.start_point, line_def.end_point)
          sub_neighborhood_def = NeighborhoodDef.new(part_entity_path, NeighborhoodNeighborDef.new(neighborhood_def.neighbor_def.path, sub_line_def))
          _, _, at_a = _get_joint_part_frame(part_entity_path, sub_line_def)
          sub_joinery_def = AddJoineryDef.new(
            at_a,
            joinery_def.at_b,
            AddJoineryJoinDef.new(anchor_members.map(&:first), [], join_def.start_point_3d, join_def.end_point_3d, join_def.origin_point_3d)
          )
          [ sub_neighborhood_def, sub_joinery_def ]
        }
      end
      @hinge_joints
    end

    # The spans, along the joint line from its start point, of the cavity
    # walls the side's inner face bears under the door - sorted, overlapping
    # ones merged - nil when there is none.
    #
    # Only the cavities OPEN towards the door count, and DEEP enough behind
    # it : the void behind a plinth runs along the side under the door as
    # well, but the plinth is what closes it - and the sliver it leaves when
    # set back is no room for a hinge base.
    def _get_hinge_cavity_ranges(line_def)
      return nil unless (cavities_def = _get_door_cavities_def).is_a?(CavitiesDef) && cavities_def.valid?

      start_point = line_def.start_point
      length = start_point.distance(line_def.end_point)
      return nil if length <= 0
      direction = start_point.vector_to(line_def.end_point).normalize

      fm_b = line_def.neighbor_face_manipulator
      wall_normal = fm_b.normal.reverse                         # A cavity's walls face out of it : into the side
      mouth_normal = line_def.face_manipulator.normal.reverse   # And its mouth towards the door

      ranges = []
      cavities_def.fragment_defs.each do |fragment_def|
        next unless fragment_def.opening_defs.any? { |opening_def| opening_def.normal % mouth_normal > HINGE_MOUTH_MIN_DOT }
        points = fragment_def.wall_loops_on_plane(wall_normal, fm_b.position).flatten(1)
        next if points.empty?
        depths = points.map { |point| (point - start_point) % mouth_normal }
        next if depths.max - depths.min < HINGE_CAVITY_MIN_DEPTH
        positions = points.map { |point| (point - start_point) % direction }
        f_min = [ positions.min, 0 ].max
        f_max = [ positions.max, length ].min
        next if f_max - f_min < 1.mm   # A compartment the door does not cover
        ranges << [ f_min, f_max ]
      end
      return nil if ranges.empty?

      ranges.sort_by(&:first).each_with_object([]) do |(min, max), merged|
        if !merged.empty? && min <= merged.last.last + 0.01.mm
          merged.last[1] = [ merged.last.last, max ].max
        else
          merged << [ min, max ]
        end
      end
    end

    # The faces of the given part, in world space, memoized per path.
    def _get_part_face_manipulators(part_entity_path)
      @door_face_manipulators = {} unless @door_face_manipulators.is_a?(Hash)
      key = PathUtils.serialize_path(part_entity_path)
      return @door_face_manipulators[key] if @door_face_manipulators.key?(key)
      drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(part_entity_path) ], **_get_drawing_def_parameters).run
      if drawing_def.is_a?(DrawingDef)
        drawing_def.transform!(drawing_def.transformation.inverse)  # Face manipulators to 'world' space (same normalization as _raytest_part_face)
        face_manipulators = drawing_def.face_manipulators
      else
        face_manipulators = []
      end
      @door_face_manipulators[key] = face_manipulators
    end

    def _get_snap_origin_point(picker)
      @hinge_pick_point
    end

    def _preview_join(picker)
      super
      return if @joinery_def.nil?

      # The messages below say more : what is in the way
      join_def = @joinery_def.join_def
      if !@hinge_forced_make_unique.nil? && !join_def.anchor_points_3d.empty? && (propagation_def = _get_propagation_def(_get_neighborhood_def, @joinery_def)).is_a?(PropagationDef) && propagation_def.refused_count == 0
        @tool.show_message(PLUGIN.get_i18n_string(@hinge_forced_make_unique == :shared_door ? 'tool.smart_join.warning.hinge_forced_make_unique_door' : 'tool.smart_join.warning.hinge_forced_make_unique'), SmartTool::MESSAGE_TYPE_WARNING)
      end

      # The fittings in the way are hinges, and those of THIS door : it
      # turns on one side only (see #_get_hinged_edge)
      unless join_def.occupied_anchor_points_3d.empty?
        if join_def.anchor_points_3d.empty?
          @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.door_already_hinged'), SmartTool::MESSAGE_TYPE_ERROR)
        else
          @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.occupied_hinges', { :count => join_def.occupied_anchor_points_3d.length }), SmartTool::MESSAGE_TYPE_ERROR)
        end
      end

      return if !@hinge_rejected_anchor_points.is_a?(Array) || @hinge_rejected_anchor_points.empty?

      k_points = _create_floating_points(
        points: @hinge_rejected_anchor_points,
        style: Kuix::POINT_STYLE_CROSS,
        stroke_color: Kuix::COLOR_RED,
        stroke_width: 2
      )
      @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      # Occupied anchors say more : what is already there
      return unless @joinery_def.join_def.occupied_anchor_points_3d.empty?
      @tool.show_message(
        PLUGIN.get_i18n_string('tool.smart_join.error.hinge_rejected_anchors', { :count => @hinge_rejected_anchor_points.length }),
        @joinery_def.join_def.anchor_points_3d.empty? ? SmartTool::MESSAGE_TYPE_ERROR : SmartTool::MESSAGE_TYPE_WARNING
      )
    end

    # -- Propagation --

    # Without make_unique, the hinges are written into the SHARED definitions
    # and the walk hangs every door the side's other instances bear : the
    # opposite side of the same carcass - its mirror, sharing the definition -
    # gets base plates too, and the door cups on its other edge. A door turns
    # on one edge only : when the walk would give one - the picked one or
    # another - hinges on more than one edge, make_unique is forced on until
    # the joint changes, and a warning says so.
    #
    # A door made of several parts is made unique down to them whenever one
    # of them, or what holds them in the door, is shared : the hinges would
    # otherwise appear on the other occurrences of the door - its twin
    # elsewhere, the other stile when both share a definition.
    #
    # The propagation of a joint laid on several parts of the door is theirs
    # put together - see #_get_hinge_joints.
    def _get_propagation_def(neighborhood_def, joinery_def)
      joints = _get_hinge_joints(neighborhood_def, joinery_def)
      if joints.length > 1 || !joints.first.first.equal?(neighborhood_def)
        return @hinge_propagation_def[1] if @hinge_propagation_def.is_a?(Array) && @hinge_propagation_def[0] == _fetch_option_make_unique?
        propagation_defs = joints.map { |sub_neighborhood_def, sub_joinery_def| _get_propagation_def(sub_neighborhood_def, sub_joinery_def) }
        propagation_def = PropagationDef.new(
          propagation_defs.flat_map(&:placements),
          propagation_defs.flat_map { |pd| pd.refused || [] },
          propagation_defs.flat_map { |pd| pd.failed_asserts || [] }.uniq
        )
        @hinge_propagation_def = [ _fetch_option_make_unique?, propagation_def ]
        return propagation_def
      end

      @hinge_forced_make_unique = :shared_door if !_fetch_option_make_unique? && _is_door_assembly_shared?(neighborhood_def.path)
      propagation_def = super
      return propagation_def if _fetch_option_make_unique? || !_is_door_hinged_on_several_edges?(propagation_def.placements)
      @hinge_forced_make_unique = :several_edges
      super
    end

    # Whether the given part of the active door made of several, or anything
    # between the door and it - the door included - is shared : its
    # definition has other instances.
    def _is_door_assembly_shared?(part_entity_path)
      return false unless _is_door_assembly?
      door_index = _get_door_entity_path.length - 1
      part_entity_path[door_index..-1].any? { |entity| entity.definition.count_instances > 1 }
    end

    # Whether the given placements give a door - hinges it already has
    # included - hinges on more than one edge : their fitting frames, in the
    # door definition's space, not all on one line along their X axis - the
    # joint line.
    def _is_door_hinged_on_several_edges?(placements)
      placements.select { |placement| placement.role == :a }.group_by(&:definition).any? do |definition, door_placements|
        transformations = door_placements.map(&:transformation)
        transformations += DoorDef.hinge_instances(definition).map(&:transformation)
        line = [ transformations.first.origin, transformations.first.xaxis ]
        transformations.any? { |t| !t.xaxis.parallel?(line[1]) || t.origin.distance_to_line(line).to_f > DoorDef::AXIS_TOLERANCE.to_f }
      end
    end

    # Making the door or the side unique replaces the definition the faces
    # read so far belong to.
    #
    # A joint laid on several parts of the door is laid as one joint per part
    # - see #_get_hinge_joints - in one operation, the door made unique down
    # to them first - see #_make_unique_door_parts. The side is made unique
    # by the first one : the next ones are handed its face.
    def _add_fittings
      if _is_door_assembly? &&
         (neighborhood_def = _get_neighborhood_def) &&
         (joinery_def = _get_add_joinery_def(neighborhood_def)) &&
         _get_propagation_def(neighborhood_def, joinery_def)   # Sets whether make_unique is forced

        joints = _get_hinge_joints(neighborhood_def, joinery_def)

        model = Sketchup.active_model
        model.start_operation('OCL Add Fittings', true)
        begin

          _make_unique_door_parts(joints) if _fetch_option_make_unique?

          previous_line_def = nil
          joints.each do |sub_neighborhood_def, sub_joinery_def|
            line_def = sub_neighborhood_def.neighbor_def.line_def
            line_def.neighbor_face_manipulator = previous_line_def.neighbor_face_manipulator unless previous_line_def.nil?
            _add_joint_fittings(sub_neighborhood_def, sub_joinery_def)
            previous_line_def = line_def
          end

          model.commit_operation

        rescue Exception => e
          PLUGIN.dump_exception(e)
          model.abort_operation
        end

      else
        super
      end
      _reset_door_caches
    end

    # Makes the door unique, and everything between it and the parts of the
    # given joints - not the parts themselves : #_add_joint_fittings does.
    # The paths of the joints are set to the entities that took the place of
    # the old ones, read at the same index in the new definitions.
    def _make_unique_door_parts(joints)
      door_index = _get_door_entity_path.length - 1
      replacements = {}
      joints.each do |neighborhood_def, _|
        path = neighborhood_def.path.map { |entity| replacements[entity] || entity }
        (door_index...(path.length - 1)).each do |index|
          instance = path[index]
          definition = instance.definition
          instance.make_unique
          next if instance.definition == definition
          definition.entities.to_a.zip(instance.definition.entities.to_a).each { |old_entity, new_entity| replacements[old_entity] = new_entity }
          path[index + 1] = replacements[path[index + 1]] || path[index + 1]
        end
        neighborhood_def.path = path
      end
    end

    # The swing of a door made of several parts is the whole door's : the
    # hinge, read in the space of the part it is laid in, is set in the
    # door's.
    def _preview_door_opening(propagation_def, geometries_def)
      return super unless _is_door_assembly?
      return if (geometry = _get_hinge_geometry(geometries_def, :a)).nil?

      placement = propagation_def.placements.find { |p| p.role == :a && !p.seed_transformation.nil? }
      return if placement.nil?

      door_entity_path = _get_door_entity_path
      return if (drawing_def = _get_door_drawing_def(door_entity_path.last.definition)).nil?

      # Set in the door's space at once : the axis is read off the frame's
      # axes, a part mirrored in the door turns it the other way
      door_transformation = PathUtils.get_transformation(door_entity_path, IDENTITY)
      t = door_transformation.inverse * placement.seed_transformation   # Part definition space -> door definition space
      return if (hinge_def = _get_preview_hinge_def(geometry, placement, t)).nil?

      _preview_door_swing(door_transformation, hinge_def.axis_line, 0, hinge_def.max_angle, drawing_def, LAYER_3D_JOIN_PREVIEW)
    end

    # -----

    # One set of geometries per kind of door, all kept.
    def _get_geometries_def
      @geometries_defs = {} unless @geometries_defs.is_a?(Hash)
      @geometries_def = @geometries_defs[@hinge_kind]
      @geometries_defs[@hinge_kind] = super
    end

  end

  class SmartJoinRemoveFittingsActionHandler < SmartJoinFittingsActionHandler

    def initialize(tool, previous_action_handler = nil, action = SmartJoinTool::ACTION_REMOVE_FITTINGS)
      super(action, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      case state
      when STATE_SELECT_B
        return SmartCursorManager.cursor_select_join_minus
      end
      super
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT_B
        if _has_active_part_b?
          _remove_fittings
          if _fetch_option_distribution_free?
            _refresh
          else
            _restart
          end
        else
          UI.beep
        end
        return true

      end

      super
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_shift?(key)
        _refresh
        return true
      end
      if tool.is_key_ctrl_or_option?(key)
        @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_OPPOSITE, !_fetch_option_opposite?, fire_event: true)
        return true
      end

      false
    end

    # -----

    protected

    def _reset
      super
      @snap_anchor = nil
    end

    def _refresh
      @snap_anchor = nil
      super
    end

    # -----

    def _snap_ref_point_b(picker = nil)

      if _fetch_option_distribution_free? &&
         @mouse_snap_point.is_a?(Geom::Point3d) &&
         (neighborhood_def = _get_neighborhood_def) &&
         (joinery_def = _get_remove_joinery_def(neighborhood_def))

        snap_anchor = _get_anchors(joinery_def).min { |p1, p2| @mouse_snap_point.distance(p1) <=> @mouse_snap_point.distance(p2) }

      else
        snap_anchor = nil
      end

      # Returns true if changed
      (@snap_anchor != snap_anchor).tap { @snap_anchor = snap_anchor }
    end

    def _preview_join(picker)
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      super

      # Preview the fittings to remove : red boxes on the picked couple,
      # translucent ones on the placements propagated through the contact graph.
      anchors = {}
      _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|

        placement.instance_transformations.each do |instance_transformation|

          picked = placement.picked?(instance_transformation)

          placement.glued_instances.each do |glued_instance|

            t = instance_transformation * glued_instance.transformation

            k_box = Kuix::BoxFillMotif3d.new
            k_box.bounds.copy!(glued_instance.definition.bounds)
            k_box.line_width = 2
            k_box.color = picked ? COLOR_REMOVE_FILL_PREVIEW : COLOR_REMOVE_FILL_PROPAGATED_PREVIEW
            k_box.on_top = true
            k_box.transformation = t
            @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

            k_box = Kuix::BoxMotif3d.new
            k_box.bounds.copy!(glued_instance.definition.bounds)
            k_box.line_width = 2
            k_box.color = picked ? COLOR_REMOVE_STROKE_PREVIEW : COLOR_REMOVE_STROKE_PROPAGATED_PREVIEW
            k_box.on_top = true
            k_box.transformation = t
            @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

          end

          anchor = ORIGIN.transform(instance_transformation * placement.transformation)
          anchors[anchor.to_a.map { |coord| coord.round(3) }] = true

          k_point = _create_floating_points(
            points: anchor,
            style: Kuix::POINT_STYLE_PLUS,
            stroke_color: Kuix::COLOR_BLACK,
            )
          @tool.append_3d(k_point, LAYER_3D_JOIN_PREVIEW)

        end

      end

      _show_remove_count_message(anchors.length)

      if @mouse_snap_point.is_a?(Geom::Point3d) && @snap_anchor.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@mouse_snap_point)
        k_edge.end.copy!(@snap_anchor)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

      end

    end

    def _show_remove_count_message(count)
      if count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.x_fittings_to_remove', { :count => count }), SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.no_fitting_to_remove'), SmartTool::MESSAGE_TYPE_WARNING)
      end
    end

    # -----

    def _remove_fittings
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      model = Sketchup.active_model
      model.start_operation('OCL Remove Fittings', true)
      begin

        _get_propagation_def(neighborhood_def, joinery_def).placements.each do |placement|
          placement.glued_instances.each do |glued_instance|
            next if glued_instance.deleted?
            glued_instance.erase!
          end
        end

        model.commit_operation

      rescue Exception => e
        PLUGIN.dump_exception(e)
        model.abort_operation
      end

    end

    # -- Propagation --

    # Resolves the fitting placements to remove. Fittings live in shared
    # definitions : erasing one removes it from every instance, so the mating
    # fittings of the parts forming the same dihedral configuration with the
    # other instances must be removed too, walking the contact graph
    # (A -> B -> A' -> B' -> ...). The walk stops on branches where no glued
    # instance exists at the anchor.
    def _get_propagation_def(neighborhood_def, joinery_def)

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      line_def = neighborhood_def.neighbor_def.line_def

      seeds = []

      # The glued instance transformation is the fitting frame in the face
      # owner definition space (X axis along the joint axis)
      fn_seed = lambda do |fm, grouped_glued_instances, role|
        grouped_glued_instances.each do |anchor_coords, glued_instances|
          next unless _is_snap_anchor?(Geom::Point3d.new(anchor_coords))
          seeds << PropagationPlacementDef.new(fm.face.parent, fm.face, glued_instances.first.transformation, role, [ fm.transformation ], fm.transformation, glued_instances)
        end
      end

      fn_seed.call(line_def.face_manipulator, joinery_def.grouped_glued_instances_a, :a)
      fn_seed.call(line_def.neighbor_face_manipulator, joinery_def.grouped_glued_instances_b, :b)

      mate_transformation, side_a, side_b = _get_propagation_context(line_def)
      mate_transformation_inverse = mate_transformation.inverse

      placements = _walk_contact_graph(seeds) do |placement, wf, instance_path|

        from_a = placement.role == :a
        nfm, mt_n = _find_mating_fitting(wf * (from_a ? mate_transformation : mate_transformation_inverse), from_a ? side_b : side_a, instance_path)
        next nil if nfm.nil?

        # Only propagate onto anchors where a mating glued instance exists
        glued_instances = _get_glued_instances_anchored_at(nfm.face, mt_n)
        next nil if glued_instances.empty?

        PropagationPlacementDef.new(nfm.face.parent, nfm.face, mt_n, from_a ? :b : :a, nil, nil, glued_instances)
      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(placements)
    end

    # Lightweight fingerprint of the removal inputs (picked couple + glued
    # anchors + snap anchor). Used to reuse the (heavy) propagation result while
    # nothing relevant changed.
    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      instance_b = neighborhood_def.neighbor_def.instance_b
      sig = [ instance_a.entityID, instance_a.definition.entityID, instance_b.entityID, instance_b.definition.entityID, @snap_anchor ]
      sig.concat(joinery_def.grouped_glued_instances_a.keys)
      sig.concat(joinery_def.grouped_glued_instances_b.keys)
      sig
    end

    # -----

    def _get_anchors(joinery_def)
      (joinery_def.grouped_glued_instances_a.keys + joinery_def.grouped_glued_instances_b.keys).map! { |coords| coords.map! { |coord| coord.round(6) } }
                                                                                               .uniq
                                                                                               .map! { |coords| Geom::Point3d.new(coords) }
    end

    def _is_snap_anchor?(anchor)
      !@snap_anchor.is_a?(Geom::Point3d) || @snap_anchor.distance(anchor).round(3) == 0
    end

    # -----

    def _get_remove_joinery_def(neighborhood_def)
      return nil if neighborhood_def.neighbor_def.nil?

      neighbor_def = neighborhood_def.neighbor_def
      line_def = neighbor_def.line_def

      poly_3d = [ line_def.start_point, line_def.start_point, line_def.end_point ] # Fake flat poly by doubbleling start point

      grouped_glued_instances_a = _get_grouped_glued_instances(line_def.face_manipulator, poly_3d)
      grouped_glued_instances_b = _get_grouped_glued_instances(line_def.neighbor_face_manipulator, poly_3d)

      RemoveJoineryDef.new(
        grouped_glued_instances_a,
        grouped_glued_instances_b
      )
    end

    # Data Structs -----

    RemoveJoineryDef = Struct.new(:grouped_glued_instances_a, :grouped_glued_instances_b)

  end

  # HINGES removal : the hinges of a door (see DoorDef), removed by HOVERING
  # the door and a click - its whole hinged edge, or the hinge nearest the
  # cursor with Shift.
  #
  # The joint is read off the hinges themselves, not off the cavities as
  # SmartJoinAddHingesActionHandler does : each hinge is glued to the door's
  # back (A) with its frame origin on the joint line, X along it, +Z into the
  # carcass. The side's inner face (B) is the part face through that line,
  # facing +/-Y, found by probing just behind it. The mating fittings of B
  # stand at the same anchors : B's own glued instances there are removed too,
  # and so are those the contact graph reaches through the shared
  # definitions. When B is not found - a side moved away, a hinge without any
  # fitting on B - the hinges of the door are removed alone.
  #
  # A door made of several parts (see DoorDef) is picked by any of them, and
  # its hinges are read off all of them : a joint may run along several
  # parts - a hinge in each rail of a frame door. It is then removed as one
  # joint per part, put together (see #_get_part_joints).
  class SmartJoinRemoveHingesActionHandler < SmartJoinRemoveFittingsActionHandler

    include SmartActionHandlerDoorHelper

    # One pick : the door, near the side it turns on - handled as the
    # fittings' part A.
    STATE_SELECT = STATE_SELECT_A

    # How far a mating fitting may stand from a hinge anchor, and a face plane
    # from that anchor, to be read as the same joint.
    HINGE_ANCHOR_TOLERANCE = 0.01.mm

    # How far behind the door's back (+Z) the side's inner face is probed.
    HINGE_SIDE_PROBE_DEPTHS = [ 1.mm, 10.mm ].freeze

    def initialize(tool, previous_action_handler = nil)
      super(tool, previous_action_handler, SmartJoinTool::ACTION_REMOVE_HINGES)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join_minus
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)
      if (neighborhood_def = _get_neighborhood_def) && (joinery_def = _get_remove_joinery_def(neighborhood_def)) && !joinery_def.grouped_glued_instances_a.empty?
        _remove_fittings
        if _fetch_option_distribution_free?
          _refresh
        else
          _restart
        end
      else
        UI.beep
      end
      true
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      if tool.is_key_shift?(key)
        _refresh
        return true
      end
      false # No opposite face here : both faces are read off the hinges
    end

    def onPickerChanged(picker, view)
      @tool.clear_3d([ LAYER_3D_JOIN_PREVIEW, LAYER_3D_SNAP_POINT_PREVIEW, LAYER_3D_PART_B_PREVIEW ])
      @tool.hide_message
      _pick_part(picker, view)
      @mouse_snap_point = picker.picked_point
      _reset_neighborhood_def if _pick_hinge_joint(picker)
      _snap_ref_point_b(picker)
      _preview_part(@active_part_entity_path_b, @active_part_b, LAYER_3D_PART_B_PREVIEW) if _has_active_part_b?
      unless @hinge_joint.nil?
        _preview_ref_face_a
        _preview_join(picker)
      end
      true
    end

    def onToolTransactionUndo(tool, model)
      @hinge_joints = nil
      @part_propagation_def = nil
    end

    # -----

    protected

    def _get_select_state
      STATE_SELECT
    end

    def _reset
      super
      @hinge_joints = nil
      @hinge_joint = nil
      @part_propagation_def = nil
    end

    # -----

    def _can_activate_part?(part_entity_path, part)
      can_activate, error_key, error_vars = super
      return [ can_activate, error_key, error_vars ] unless can_activate
      return [ false, 'tool.smart_join.error.no_hinge_to_remove' ] if part_entity_path.is_a?(Array) && _get_door_hinges(_get_door_entity_path(part_entity_path)).empty?   # Nil path : a reset, always allowed
      true
    end

    # -- Door --

    # The DOOR the given part belongs to : the path to the nearest entity of
    # its path bearing ROLE_FRONT_PANEL - the part itself, or a group or a
    # component holding it - or the part itself when there is none.
    def _get_door_entity_path(part_entity_path = @active_part_entity_path_a)
      return nil unless part_entity_path.is_a?(Array)
      return part_entity_path if (index = part_entity_path.rindex { |entity| DefinitionAttributes.role_of(entity) == DefinitionAttributes::ROLE_FRONT_PANEL }).nil?
      part_entity_path[0..index]
    end

    # The part hovered of a door made of several stands for the whole door :
    # it is the whole door that is highlighted.
    def _preview_part(part_entity_path, part, layer = LAYER_3D_PART_PREVIEW, highlighted: false, clear_before: true)
      return super unless layer == LAYER_3D_PART_A_PREVIEW && part.is_a?(Part) && (door_entity_path = _get_door_entity_path(part_entity_path)).is_a?(Array) && door_entity_path.length < part_entity_path.length
      @tool.clear_3d(layer) if clear_before
      _preview_door_assembly(door_entity_path, _get_path_part_preview_color(part_entity_path, part, highlighted), _get_path_part_preview_offset(part_entity_path, part, highlighted), layer)
    end

    # The hinges of the given door, as [ hinge, part_entity_path ] pairs, the
    # path of the part each is glued into : the door itself, or - when it
    # bears ROLE_FRONT_PANEL - any part it holds, see
    # DoorDef.door_hinge_instances.
    def _get_door_hinges(door_entity_path)
      return [] unless door_entity_path.is_a?(Array)
      hinges = DoorDef.hinge_instances(door_entity_path.last).map { |hinge| [ hinge, door_entity_path ] }
      return hinges unless DefinitionAttributes.role_of(door_entity_path.last) == DefinitionAttributes::ROLE_FRONT_PANEL

      fn_collect = lambda { |path|
        path.last.definition.entities.each do |entity|
          next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          next unless DoorDef.hinge_frame(entity).nil?
          next if DefinitionAttributes.applied_panel_role?(DefinitionAttributes.role_of(entity))
          entity_path = path + [ entity ]
          DoorDef.hinge_instances(entity).each { |hinge| hinges << [ hinge, entity_path ] }
          fn_collect.call(entity_path)
        end
      }
      fn_collect.call(door_entity_path)
      hinges
    end

    # -----

    # The joint of the hovered door nearest the cursor - its hinges usually
    # run along a single edge. Fills @hinge_joint, @active_face_manipulator_a
    # and _b, @active_part_entity_path_b and @active_part_b. Returns whether
    # the joint changed.
    def _pick_hinge_joint(picker)

      hinge_joint = nil
      if (point = picker.picked_point).is_a?(Geom::Point3d)
        hinge_joint = _get_hinge_joints.min_by { |joint| point.distance_to_line([ joint.anchors.first, joint.direction ]) }
      end
      _resolve_hinge_side(hinge_joint) unless hinge_joint.nil?

      changed = !hinge_joint.equal?(@hinge_joint)

      @hinge_joint = hinge_joint
      @active_face_manipulator_a = hinge_joint.nil? ? nil : hinge_joint.face_manipulator_a
      @active_face_manipulator_b = hinge_joint.nil? ? nil : hinge_joint.face_manipulator_b
      @active_part_entity_path_b = hinge_joint.nil? ? nil : hinge_joint.part_entity_path_b
      @active_part_b = hinge_joint.nil? ? nil : hinge_joint.part_b

      changed
    end

    # The hinges of the active door grouped by joint : by line, and by the
    # side of it their faces stand - whatever part of the door each is glued
    # into. Memoized per door - the side of each joint is resolved on demand.
    def _get_hinge_joints
      return [] unless _has_active_part_a? && (door_entity_path = _get_door_entity_path).is_a?(Array)

      key = PathUtils.serialize_path(door_entity_path)
      @hinge_joints = {} unless @hinge_joints.is_a?(Hash)
      return @hinge_joints[key] if @hinge_joints.key?(key)

      joints = []
      transformations = {}

      # Whether they make it a door or not : a hinge without kinematics is removed too
      _get_door_hinges(door_entity_path).each do |hinge, part_entity_path|
        next if (face = _get_hinge_face(hinge)).nil?

        t = (transformations[part_entity_path] ||= PathUtils.get_transformation(part_entity_path, IDENTITY))
        ht = t * hinge.transformation
        anchor = ORIGIN.transform(ht)
        direction = (ht.yaxis * ht.zaxis).normalize   # X of the fitting frame, direct even on a mirrored hinge
        face_manipulator = FaceManipulator.new(face, t)

        joint = joints.find { |j| j.face_manipulator_a.normal.samedirection?(face_manipulator.normal) && anchor.distance_to_line([ j.anchors.first, j.direction ]).to_f < HINGE_ANCHOR_TOLERANCE.to_f }
        if joint.nil?
          joint = HingeJointDef.new(face_manipulator, nil, nil, nil, direction, [], false, [], part_entity_path)
          joints << joint
        end
        # Once per anchor : a hinge's hardware and its machining may both bear the role
        if joint.anchors.none? { |a| a.distance(anchor).to_f < HINGE_ANCHOR_TOLERANCE.to_f }
          joint.anchors << anchor
          joint.members << [ anchor, face_manipulator, part_entity_path ]
        end

      end

      # Anchors sorted along the joint line
      joints.each { |joint| joint.anchors.sort_by! { |anchor| (anchor - joint.anchors.first) % joint.direction } }

      @hinge_joints[key] = joints
    end

    # The face of the door the given hinge is glued to - or, the glue lost,
    # the face its frame lies on : origin on its plane, +Z along its normal.
    def _get_hinge_face(hinge)
      return hinge.glued_to if hinge.glued_to.is_a?(Sketchup::Face)

      origin = hinge.transformation.origin
      normal = hinge.transformation.zaxis.normalize
      hinge.parent.entities.grep(Sketchup::Face).find { |face|
        face.normal.samedirection?(normal) &&
          origin.distance_to_plane(face.plane).to_f < HINGE_ANCHOR_TOLERANCE.to_f &&
          [ Sketchup::Face::PointInside, Sketchup::Face::PointOnVertex, Sketchup::Face::PointOnEdge ].include?(face.classify_point(origin))
      }
    end

    # Finds, once, the side's inner face (B) of the given joint : the part
    # face whose plane holds the joint line, facing +/-Y of the fitting frame,
    # probed just behind the door's back (+Z) abreast of each anchor in turn.
    def _resolve_hinge_side(joint)
      return if joint.side_resolved
      joint.side_resolved = true

      fm_a = joint.face_manipulator_a
      z = fm_a.normal
      y = (z * joint.direction).normalize

      joint.anchors.each do |anchor|
        HINGE_SIDE_PROBE_DEPTHS.each do |depth|
          probe_point = anchor.offset(z, depth)

          fn_accept = lambda do |fm|
            fm.normal.parallel?(y) &&
              anchor.distance_to_plane(fm.plane).to_f < HINGE_ANCHOR_TOLERANCE.to_f &&
              _is_point_on_face?(fm, probe_point)
          end

          [ y, y.reverse ].each do |normal|
            found = _raytest_part_face(probe_point.offset(normal, HINGE_ANCHOR_TOLERANCE), normal.reverse, joint.part_entity_path_a, with_path: true, &fn_accept)
            return _set_hinge_side(joint, *found) unless found.nil?
          end

          found = _find_part_face_at(probe_point, joint.part_entity_path_a, HINGE_ANCHOR_TOLERANCE, with_path: true, &fn_accept)
          return _set_hinge_side(joint, *found) unless found.nil?

        end
      end

    end

    def _set_hinge_side(joint, face_manipulator_b, part_entity_path_b)
      joint.face_manipulator_b = face_manipulator_b
      joint.part_entity_path_b = part_entity_path_b
      joint.part_b = _generate_part_from_path(part_entity_path_b)
    end

    # -----

    def _get_neighborhood_def(tolerance = 0.001)
      return @neighborhood_def unless @neighborhood_def.nil?
      return nil if (joint = @hinge_joint).nil?

      start_point = joint.anchors.first
      end_point = joint.anchors.last

      @neighborhood_def = NeighborhoodDef.new(
        joint.part_entity_path_a,
        NeighborhoodNeighborDef.new(
          joint.part_entity_path_b,
          NeighborhoodLineDef.new(
            joint.face_manipulator_a,
            joint.face_manipulator_b,
            LineManipulator.new([ start_point, joint.direction ]),
            start_point,
            end_point
          )
        )
      )
    end

    # Only what stands at the hinge anchors : the hinges and their machining
    # on A - in whatever part of the door each is glued into - the mating
    # fittings on B.
    def _get_remove_joinery_def(neighborhood_def)
      return nil if (joint = @hinge_joint).nil?

      grouped_glued_instances_a = {}
      joint.members.group_by(&:last).each_value do |members|
        grouped_glued_instances_a.merge!(_get_anchored_instances(members.first[1], members.map(&:first)))
      end

      RemoveJoineryDef.new(
        grouped_glued_instances_a,
        joint.face_manipulator_b.nil? ? {} : _get_anchored_instances(joint.face_manipulator_b, joint.anchors)
      )
    end

    # The joints the given one is removed as - [ neighborhood_def,
    # joinery_def ] pairs : itself, unless the hinges of the active joint are
    # glued into several parts of the door, or into another one than its
    # part A. Then one per part, its anchors and its face A.
    def _get_part_joints(neighborhood_def, joinery_def)
      return [ [ neighborhood_def, joinery_def ] ] unless neighborhood_def.equal?(@neighborhood_def) && (joint = @hinge_joint)
      parts = joint.members.group_by(&:last)
      return [ [ neighborhood_def, joinery_def ] ] if parts.keys == [ neighborhood_def.path ]

      line_def = neighborhood_def.neighbor_def.line_def
      parts.map { |part_entity_path, members|
        face_manipulator = members.first[1]
        keys = members.map { |anchor, _, _| anchor.to_a }
        sub_line_def = NeighborhoodLineDef.new(face_manipulator, line_def.neighbor_face_manipulator, line_def.line_manipulator, line_def.start_point, line_def.end_point)
        [
          NeighborhoodDef.new(part_entity_path, NeighborhoodNeighborDef.new(neighborhood_def.neighbor_def.path, sub_line_def)),
          RemoveJoineryDef.new(
            joinery_def.grouped_glued_instances_a.select { |coords, _| keys.include?(coords) },
            joinery_def.grouped_glued_instances_b.select { |coords, _| keys.include?(coords) }
          )
        ]
      }
    end

    # The fittings of the given face's definition anchored at the given world
    # points, grouped by anchor coords - the glue alone is not relied on : a
    # reshape may have lost it.
    def _get_anchored_instances(face_manipulator, anchors)
      ti = face_manipulator.transformation.inverse
      instances = face_manipulator.face.parent.entities.select { |entity| entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group) && entity.respond_to?(:glued_to) }.select { |instance|
        instance.glued_to.is_a?(Sketchup::Face) || instance.is_a?(Sketchup::ComponentInstance) && DefinitionAttributes.role_of(instance.definition) == DefinitionAttributes::ROLE_HINGE
      }
      anchors.each_with_object({}) do |anchor, groups|
        local_anchor = anchor.transform(ti)
        anchored = instances.select { |instance| instance.transformation.origin.distance(local_anchor).to_f < HINGE_ANCHOR_TOLERANCE.to_f }
        groups[anchor.to_a] = anchored unless anchored.empty?
      end
    end

    # -- Propagation --

    # Without B, the hinges of the door alone : on every instance of its
    # definition, but no mate to walk to.
    #
    # The propagation of a joint along several parts of the door is theirs
    # put together - see #_get_part_joints.
    def _get_propagation_def(neighborhood_def, joinery_def)
      joints = _get_part_joints(neighborhood_def, joinery_def)
      if joints.length > 1 || !joints.first.first.equal?(neighborhood_def)
        key = [ neighborhood_def.object_id, @snap_anchor.to_a, joinery_def.grouped_glued_instances_a.keys, joinery_def.grouped_glued_instances_b.keys ]
        return @part_propagation_def[1] if @part_propagation_def.is_a?(Array) && @part_propagation_def[0] == key
        placements = joints.flat_map { |sub_neighborhood_def, sub_joinery_def| _get_propagation_def(sub_neighborhood_def, sub_joinery_def).placements }
        propagation_def = PropagationDef.new(placements)
        @part_propagation_def = [ key, propagation_def ]
        return propagation_def
      end

      return super unless neighborhood_def.neighbor_def.line_def.neighbor_face_manipulator.nil?

      signature = _get_propagation_signature(neighborhood_def, joinery_def)
      return @propagation_def if @propagation_def.is_a?(PropagationDef) && @propagation_signature == signature

      fm = neighborhood_def.neighbor_def.line_def.face_manipulator
      seeds = []
      joinery_def.grouped_glued_instances_a.each do |anchor_coords, glued_instances|
        next unless _is_snap_anchor?(Geom::Point3d.new(anchor_coords))
        seeds << PropagationPlacementDef.new(fm.face.parent, fm.face, glued_instances.first.transformation, :a, [ fm.transformation ], fm.transformation, glued_instances)
      end

      @propagation_signature = signature
      @propagation_def = PropagationDef.new(_walk_contact_graph(seeds) { nil })
    end

    def _get_propagation_signature(neighborhood_def, joinery_def)
      instance_a = neighborhood_def.instance_a
      fm_b = neighborhood_def.neighbor_def.line_def.neighbor_face_manipulator
      sig = [ instance_a.entityID, instance_a.definition.entityID, fm_b.nil? ? nil : fm_b.face.entityID, @snap_anchor ]
      sig.concat(joinery_def.grouped_glued_instances_a.keys)
      sig.concat(joinery_def.grouped_glued_instances_b.keys)
      sig
    end

    # -----

    def _show_remove_count_message(count)
      if count > 0
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.x_hinges_to_remove', { :count => count }), SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.warning.no_hinge_to_remove'), SmartTool::MESSAGE_TYPE_WARNING)
      end
    end

    # Data Structs -----

    # 'members' : [ anchor, face_manipulator, part_entity_path ] per anchor,
    # the face and the part of the door its hinge is glued into ;
    # 'part_entity_path_a' : the part of face_manipulator_a.
    HingeJointDef = Struct.new(:face_manipulator_a, :face_manipulator_b, :part_entity_path_b, :part_b, :direction, :anchors, :side_resolved, :members, :part_entity_path_a)

  end

end