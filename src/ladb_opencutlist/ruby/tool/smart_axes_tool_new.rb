module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/kuix/kuix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/face_triangles_helper'
  require_relative '../helper/bounding_box_helper'
  require_relative '../helper/entities_helper'
  require_relative '../model/attributes/definition_attributes'
  require_relative '../model/geom/size3d'
  require_relative '../observer/model_observer'
  require_relative '../utils/axis_utils'
  require_relative '../utils/transformation_utils'

  class SmartAxesToolNew < SmartTool

    include LayerVisibilityHelper
    include FaceTrianglesHelper
    include BoundingBoxHelper
    include EntitiesHelper
    include CutlistObserverHelper

    ACTION_FLIP = 0
    ACTION_SWAP_LENGTH_WIDTH = 1
    ACTION_SWAP_FRONT_BACK = 2
    ACTION_ADAPT_AXES = 3
    ACTION_MOVE_AXES = 4

    ACTION_OPTION_DIRECTION = 'direction'

    ACTION_OPTION_DIRECTION_LENGTH = 0
    ACTION_OPTION_DIRECTION_WIDTH = 1
    ACTION_OPTION_DIRECTION_THICKNESS = 2

    ACTIONS = [
      {
        :action => ACTION_FLIP,
        :options => {
          ACTION_OPTION_DIRECTION => [ ACTION_OPTION_DIRECTION_LENGTH, ACTION_OPTION_DIRECTION_WIDTH, ACTION_OPTION_DIRECTION_THICKNESS ]
        }
      },
      {
        :action => ACTION_SWAP_LENGTH_WIDTH
      },
      {
        :action => ACTION_SWAP_FRONT_BACK
      },
      {
        :action => ACTION_ADAPT_AXES
      },
      {
        :action => ACTION_MOVE_AXES
      }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(254, 222, 11, 200).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(254, 222, 11, 220).freeze
    COLOR_BOX = Kuix::COLOR_BLACK
    COLOR_ACTION = Kuix::COLOR_MAGENTA
    COLOR_ACTION_FILL = Sketchup::Color.new(255, 0, 255, 0.2).blend(COLOR_MESH, 0.5).freeze
    COLOR_LENGTH = Kuix::COLOR_RED
    COLOR_LENGTH_FILL = Sketchup::Color.new(255, 0, 0, 0.2).freeze
    COLOR_WIDTH = Kuix::COLOR_GREEN
    COLOR_WIDTH_FILL = Sketchup::Color.new(0, 255, 0, 0.2).freeze
    COLOR_THICKNESS = Kuix::COLOR_BLUE
    COLOR_THICKNESS_FILL = Sketchup::Color.new(0, 0, 255, 0.2).freeze

    # -----

    attr_reader :cursor_flip, :cursor_swap_length_width, :cursor_swap_front_back, :cursor_adapt_axes

    def initialize(

      tab_name_to_show_on_quit: nil,

      highlighted_parts: nil,

      current_action: nil

    )

      super(
        tab_name_to_show_on_quit: tab_name_to_show_on_quit,
        highlighted_parts: highlighted_parts,
        current_action: current_action,
        )

      # Create cursors
      @cursor_flip = create_cursor('flip', 0, 0)
      @cursor_swap_length_width = create_cursor('swap-length-width', 0, 0)
      @cursor_swap_front_back = create_cursor('swap-front-back', 0, 0)
      @cursor_adapt_axes = create_cursor('adapt-axes', 0, 0)

    end

    def get_stripped_name
      'axes'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_DIRECTION
        return true
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group
      when ACTION_OPTION_DIRECTION
        return Kuix::Label.new(PLUGIN.get_i18n_string("tool.smart_axes.action_option_#{option_group}_#{option}"))
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model && @highlighted_parts.nil?

      # Observe model events
      view.model.add_observer(self)

    end

    def onDeactivate(view)
      super

      # Stop observing model events
      view.model.remove_observer(self)

    end

    def onActionChanged(action)

      case action
      when ACTION_FLIP
        set_action_handler(SmartAxesFlipActionHandler.new(self))
      when ACTION_SWAP_LENGTH_WIDTH
        set_action_handler(SmartAxesSwapLengthWidthActionHandler.new(self))
      when ACTION_SWAP_FRONT_BACK
        set_action_handler(SmartAxesSwapFrontBackActionHandler.new(self))
      when ACTION_ADAPT_AXES
        set_action_handler(SmartAxesAdaptAxesActionHandler.new(self))
      when ACTION_MOVE_AXES
        set_action_handler(SmartAxesMoveAxesActionHandler.new(self))

      end

      refresh

    end

    def onViewChanged(view)
      super
      refresh
    end

    def onTransactionUndo(model)
      refresh
    end

  end

  # -----

  class SmartAxesActionHandler < SmartActionHandler

    include SmartActionHandlerPartHelper

    LAYER_3D_AXES_PREVIEW = 2
    LAYER_3D_ACTION_PREVIEW = 3

    def initialize(action, tool, previous_action_handler = nil)
      super

      @global_instance_transformation = nil
      @drawing_def = nil

    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)

      if @active_part_entity_path.nil?
        UI.beep
        return true
      end

      _do_action
      _restart

      false
    end

    def onToolLButtonDoubleClick(tool, flags, x, y, view)
      onToolLButtonUp(tool, flags, x, y, view)
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)
      @global_instance_transformation = nil
      @drawing_def = nil
      super
    end

    def onToolActionOptionStored(tool, action, option_group, option)
      _preview_action
    end

    def onPickerChanged(picker, view)
      _pick_part(picker, view)
      super
    end

    # -----

    protected

    def _reset
      @global_instance_transformation = nil
      @drawing_def = nil
      super
      set_state(0)
    end

    # -----

    def _preview_part(part_entity_path, part, layer = 0, highlighted = false)
      super
      if part

        # Show part infos
        @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

        _preview_action

      else

        @tool.remove_tooltip
        @tool.remove_3d(LAYER_3D_AXES_PREVIEW)
        @tool.remove_3d(LAYER_3D_ACTION_PREVIEW)

      end
    end

    def _preview_action

      @tool.remove_3d(LAYER_3D_ACTION_PREVIEW)

    end

    def _do_action
    end

    # -----

    def _get_edit_transformation
      t = _get_global_instance_transformation(nil)
      return t unless t.nil?
      super
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

  end

  class SmartAxesFlipActionHandler < SmartAxesActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartAxesTool::ACTION_FLIP, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_cursor(state)
      @tool.cursor_flip
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self)
    end

    def get_state_status(state)
      super +
             ' | ↑↓ + ' + PLUGIN.get_i18n_string('tool.default.transparency') + ' = ' + PLUGIN.get_i18n_string('tool.default.toggle_depth') + '.' +
             ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_1') + '.' +
             ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_3') + '.'
    end

    # ------

    def start
      super
    end

    # -----

    protected

    def _preview_axes?
      true
    end

    def _preview_arrows?
      true
    end

    def _preview_box?
      true
    end

    def _preview_action
      super
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)

        px_offset = Sketchup.active_model.active_view.pixels_to_model(50, eb.center.transform(et))

        fn_preview_plane = lambda do |color, section|

          k_box = Kuix::BoxMotif.new
          k_box.bounds.copy!(section)
          k_box.line_width = 2
          k_box.line_stipple = Kuix::LINE_STIPPLE_SOLID
          k_box.color = color
          k_box.transformation = et
          @tool.append_3d(k_box, LAYER_3D_ACTION_PREVIEW)

          k_mesh = Kuix::Mesh.new
          k_mesh.add_quands(section.get_quads)
          k_mesh.background_color = ColorUtils.color_translucent(color, 0.3)
          k_mesh.transformation = et
          @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

        end

        if _fetch_option_direction_length
          fn_preview_plane.call(Kuix::COLOR_X, Kuix::Bounds3d.new.copy!(eb).x_section.inflate!(0, px_offset, px_offset))
        elsif _fetch_option_direction_width
          fn_preview_plane.call(Kuix::COLOR_Y, Kuix::Bounds3d.new.copy!(eb).y_section.inflate!(px_offset, 0, px_offset))
        elsif _fetch_option_direction_thickness
          fn_preview_plane.call(Kuix::COLOR_Z, Kuix::Bounds3d.new.copy!(eb).z_section.inflate!(px_offset, px_offset, 0))
        end

      end
    end

    def _do_action
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)

        size = @active_part.def.size

        scaling = {
          X_AXIS => 1,
          Y_AXIS => 1,
          Z_AXIS => 1,
        }
        if _fetch_option_direction_length
          scaling[size.oriented_axis(X_AXIS)] = -1
        elsif _fetch_option_direction_width
          scaling[size.oriented_axis(Y_AXIS)] = -1
        elsif _fetch_option_direction_thickness
          scaling[size.oriented_axis(Z_AXIS)] = -1
        end

        t = Geom::Transformation.scaling(eb.center, scaling[X_AXIS], scaling[Y_AXIS], scaling[Z_AXIS])

        model = Sketchup.active_model
        model.start_operation('OCL Part Flip', true, false, false)

          _get_active_part_entity.transformation *= t

        # Commit model modification operation
        model.commit_operation

        # Fire event
        ModelObserver.instance.onDrawingChange

      end
    end

    # -----

    def _fetch_option_direction_length
      @tool.fetch_action_option_boolean(@action, SmartAxesToolNew::ACTION_OPTION_DIRECTION, SmartAxesToolNew::ACTION_OPTION_DIRECTION_LENGTH)
    end

    def _fetch_option_direction_width
      @tool.fetch_action_option_boolean(@action, SmartAxesToolNew::ACTION_OPTION_DIRECTION, SmartAxesToolNew::ACTION_OPTION_DIRECTION_WIDTH)
    end

    def _fetch_option_direction_thickness
      @tool.fetch_action_option_boolean(@action, SmartAxesToolNew::ACTION_OPTION_DIRECTION, SmartAxesToolNew::ACTION_OPTION_DIRECTION_THICKNESS)
    end

  end

  class SmartAxesSwapLengthWidthActionHandler < SmartAxesActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartAxesTool::ACTION_SWAP_LENGTH_WIDTH, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_cursor(state)
      @tool.cursor_swap_length_width
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self)
    end

    def get_state_status(state)
      super +
        ' | ↑↓ + ' + PLUGIN.get_i18n_string('tool.default.transparency') + ' = ' + PLUGIN.get_i18n_string('tool.default.toggle_depth') + '.' +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_2') + '.' +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_3') + '.'
    end

    # ------

    def start
      super
    end

    # -----

    protected

    def _preview_all_instances?
      true
    end

    def _preview_axes?
      true
    end

    def _preview_arrows?
      true
    end

    def _preview_box?
      true
    end

    def _preview_action
      super
    end

    def _do_action

      definition = @active_part.def.definition

      size = @active_part.def.size
      x_axis, y_axis, z_axis = size.axes

      ti = Geom::Transformation.axes(
        ORIGIN,
        AxisUtils.flipped?(y_axis, x_axis, z_axis) ? y_axis.reverse : y_axis,
        x_axis,
        z_axis
      )

      t = ti.inverse

      model = Sketchup.active_model
      model.start_operation('OCL Change Axes', true, false, false)

        # Transform definition's entities
        entities = definition.entities
        entities.transform_entities(t, entities.to_a)

        # Inverse transform definition's instances
        definition.instances.each do |instance|
          instance.transformation *= ti
        end

        if PLUGIN.get_model_preset('cutlist_options')['auto_orient']
          definition_attributes = DefinitionAttributes.new(definition)
          definition_attributes.orientation_locked_on_axis = true
          definition_attributes.write_to_attributes
        end

      # Commit model modification operation
      model.commit_operation

      # Fire event
      ModelObserver.instance.onDrawingChange

    end

  end

  class SmartAxesSwapFrontBackActionHandler < SmartAxesActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartAxesTool::ACTION_SWAP_FRONT_BACK, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_cursor(state)
      @tool.cursor_swap_front_back
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self)
    end

    def get_state_status(state)
      super +
        ' | ↑↓ + ' + PLUGIN.get_i18n_string('tool.default.transparency') + ' = ' + PLUGIN.get_i18n_string('tool.default.toggle_depth') + '.' +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_3') + '.' +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_3') + '.'
    end

    # ------

    def start
      super
    end


    # -----

    protected

    def _preview_all_instances?
      true
    end

    def _preview_axes?
      true
    end

    def _preview_arrows?
      true
    end

    def _preview_box?
      true
    end

    def _preview_action
      super
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)

        k_box = Kuix::BoxMotif.new
        k_box.bounds.copy!(eb)
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.color = Kuix::COLOR_BLACK
        k_box.transformation = et
        @tool.append_3d(k_box, LAYER_3D_ACTION_PREVIEW)

      end
    end

    def _do_action

      definition = @active_part.def.definition

      size = @active_part.def.size
      x_axis, y_axis, z_axis = size.axes

      ti = Geom::Transformation.axes(
        ORIGIN,
        x_axis,
        AxisUtils.flipped?(x_axis, y_axis, z_axis.reverse) ? y_axis.reverse : y_axis,
        z_axis.reverse
      )

      t = ti.inverse

      model = Sketchup.active_model
      model.start_operation('OCL Change Axes', true, false, false)

        # Transform definition's entities
        entities = definition.entities
        entities.transform_entities(t, entities.to_a)

        # Inverse transform definition's instances
        definition.instances.each do |instance|
          instance.transformation *= ti
        end

        if PLUGIN.get_model_preset('cutlist_options')['auto_orient']
          definition_attributes = DefinitionAttributes.new(definition)
          definition_attributes.orientation_locked_on_axis = true
          definition_attributes.write_to_attributes
        end

      # Commit model modification operation
      model.commit_operation

      # Fire event
      ModelObserver.instance.onDrawingChange

    end

  end

  class SmartAxesAdaptAxesActionHandler < SmartAxesActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartAxesTool::ACTION_ADAPT_AXES, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_cursor(state)
      @tool.cursor_adapt_axes
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_edges: true, pick_clines: true, pick_axes: true)
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_4') + '.'
    end

    # ------

    def start
      super

      puts "#{self.class.name} start"

    end

  end

  class SmartAxesMoveAxesActionHandler < SmartAxesActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartAxesTool::ACTION_MOVE_AXES, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_cursor(state)
      @tool.cursor_adapt_axes
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_point: true)
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_0') +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_3') + '.'
    end

    # ------

    def start
      super
    end

    # -----

    def onPickerChanged(picker, view)
      super
      @tool.remove_3d(LAYER_3D_ACTION_PREVIEW)
      _preview_action
    end

    # -----

    protected

    def _preview_all_instances?
      true
    end

    def _preview_axes?
      true
    end

    def _preview_arrows?
      true
    end

    def _preview_action
      super
      unless @picker.picked_point.nil? || @active_part.nil?

        k_axes_helper = Kuix::AxesHelper.new
        k_axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(@picker.picked_point.to_a))
        @tool.append_3d(k_axes_helper, LAYER_3D_ACTION_PREVIEW)

      end

    end

    def _do_action

    end


  end

end
