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

  class SmartAxesTool < SmartTool

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
      view.model.selection.clear if @highlighted_parts.nil?

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
      super
      refresh
    end

  end

  # -----

  class SmartAxesActionHandler < SmartSelectActionHandler

    LAYER_3D_ACTION_PREVIEW = 3

    COLOR_ACTION = Kuix::COLOR_MAGENTA
    COLOR_ACTION_FILL = Sketchup::Color.new(255, 0, 255, 0.2).blend(COLOR_PART, 0.5).freeze

    def initialize(action, tool, previous_action_handler = nil)
      super

      @tooltip_type = SmartTool::MESSAGE_TYPE_DEFAULT

      # Create 3D layers
      @tool.create_3d(LAYER_3D_PART_PREVIEW)
      @tool.create_3d(LAYER_3D_ACTION_PREVIEW)

    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SELECT
        return @tool.get_action_status(@tool.fetch_action)

      end

      super
    end

    # -----

    def onToolLButtonUp(tool, flags, x, y, view)
      super

      unless has_active_part?
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

    def onToolActionOptionStored(tool, action, option_group, option)
      _preview_action
    end

    def onPickerChanged(picker, view)
      super
      _preview_action
    end

    def onActivePartChanged(part_entity_path, part, highlighted = nil)
      super

      # Instance status
      if part && (definition = part.def.definition) && definition.count_used_instances > 1 && _preview_all_instances?
        @tool.show_message("⚠ #{PLUGIN.get_i18n_string('tool.smart_axes.warning.more_entities', { :count_used => definition.count_used_instances })}", SmartTool::MESSAGE_TYPE_WARNING)
      else
        @tool.hide_message
      end

    end

    # -----

    protected

    # -----

    def _reset
      @tooltip_type = SmartTool::MESSAGE_TYPE_DEFAULT
      super
    end

    # -----

    def _start_with_previous_selection?
      true
    end

    def _can_activate_part?(part)
      !part.is_a?(Part) || part.group.material_type != MaterialAttributes::TYPE_HARDWARE
    end

    def _get_cant_activate_part_tooltip(part)
      "⚠ #{PLUGIN.get_i18n_string('tool.smart_axes.error.not_orientable')}"
    end

    # -----

    def _preview_action
      _preview_action_clean
      _preview_action_draw
      _preview_action_tooltip
    end

    def _preview_action_clean
      @tool.clear_3d(LAYER_3D_ACTION_PREVIEW)
    end

    def _preview_action_draw
    end

    def _preview_action_tooltip

      # Show part infos
      @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ], @tooltip_type) if has_active_part?

    end

    def _do_action
    end

    # -----

    def _get_edit_transformation
      t = _get_global_instance_transformation(nil)
      return t unless t.nil?
      super
    end

    # -----

    def _update_orientation_locked_on_axis(definition)
      if PLUGIN.get_model_preset('cutlist_options')['auto_orient']
        definition_attributes = DefinitionAttributes.new(definition)
        definition_attributes.orientation_locked_on_axis = true
        definition_attributes.write_to_attributes
      end
    end

  end

  class SmartAxesFlipActionHandler < SmartAxesActionHandler

    PX_INFLATE_VALUE = 50

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
             ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_1') + '.'
    end

    # -----

    protected

    def _preview_part_axes?
      true
    end

    def _preview_part_arrows?
      true
    end

    def _preview_part_box?
      true
    end

    def _can_activate_part?(part)
      true
    end

    # -----

    def _preview_action_draw
      super
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        part = get_active_part
        size = part.def.size

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)

        inch_inflate_value = Sketchup.active_model.active_view.pixels_to_model(PX_INFLATE_VALUE, eb.center.transform(et))

        kebi = Kuix::Bounds3d.new.copy!(eb).inflate_all!(inch_inflate_value)
        patterns_transformations = {
          X_AXIS => Geom::Transformation.axes(ORIGIN, Z_AXIS, Y_AXIS, X_AXIS),
          Y_AXIS => Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS, Y_AXIS),
          Z_AXIS => IDENTITY
        }

        fn_preview_plane = lambda do |axis, color|

          oriented_axis = size.oriented_axis(axis)
          section = kebi.section_by_axis(oriented_axis)
          patterns_transformation = patterns_transformations[oriented_axis]

          k_rectangle = Kuix::RectangleMotif3d.new
          k_rectangle.bounds.copy!(section)
          k_rectangle.line_width = 1
          k_rectangle.line_stipple = size.auto_oriented? ? Kuix::LINE_STIPPLE_LONG_DASHES : Kuix::LINE_STIPPLE_SOLID
          k_rectangle.color = color
          k_rectangle.transformation = et
          k_rectangle.patterns_transformation = patterns_transformation
          @tool.append_3d(k_rectangle, LAYER_3D_ACTION_PREVIEW)

          k_mesh = Kuix::Mesh.new
          k_mesh.add_quads(section.get_quads)
          k_mesh.background_color = ColorUtils.color_translucent(color, 0.3)
          k_mesh.transformation = et
          @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

        end

        if _fetch_option_direction_length
          fn_preview_plane.call(X_AXIS, Kuix::COLOR_X)
        elsif _fetch_option_direction_width
          fn_preview_plane.call(Y_AXIS, Kuix::COLOR_Y)
        elsif _fetch_option_direction_thickness
          fn_preview_plane.call(Z_AXIS, Kuix::COLOR_Z)
        end

      end
    end

    # -----

    def _do_action
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)

        part = get_active_part
        size = part.def.size

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

          _get_instance.transformation *= t

        # Commit model modification operation
        model.commit_operation

        # Fire event
        PLUGIN.app_observer.model_observer.onDrawingChange

      end
    end

    # -----

    def _fetch_option_direction_length
      @tool.fetch_action_option_boolean(@action, SmartAxesTool::ACTION_OPTION_DIRECTION, SmartAxesTool::ACTION_OPTION_DIRECTION_LENGTH)
    end

    def _fetch_option_direction_width
      @tool.fetch_action_option_boolean(@action, SmartAxesTool::ACTION_OPTION_DIRECTION, SmartAxesTool::ACTION_OPTION_DIRECTION_WIDTH)
    end

    def _fetch_option_direction_thickness
      @tool.fetch_action_option_boolean(@action, SmartAxesTool::ACTION_OPTION_DIRECTION, SmartAxesTool::ACTION_OPTION_DIRECTION_THICKNESS)
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
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_2') + '.'
    end

    # -----

    protected

    def _preview_all_instances?
      true
    end

    def _preview_part_axes?
      true
    end

    def _preview_part_arrows?
      true
    end

    def _preview_part_box?
      true
    end

    # -----

    def _do_action

      part = get_active_part
      definition = part.def.definition

      size = part.def.size
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

        # Update definition attributes
        _update_orientation_locked_on_axis(definition)

      # Commit model modification operation
      model.commit_operation

      # Fire event
      PLUGIN.app_observer.model_observer.onDrawingChange

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
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_3') + '.'
    end

    # -----

    protected

    def _preview_all_instances?
      true
    end

    def _preview_part_axes?
      true
    end

    def _preview_part_arrows?
      true
    end

    def _preview_part_box?
      true
    end

    def _preview_action_draw
      super
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        et = _get_edit_transformation
        eb = _get_drawing_def_edit_bounds(drawing_def, et)

        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(eb)
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.color = Kuix::COLOR_BLACK
        k_box.transformation = et
        @tool.append_3d(k_box, LAYER_3D_ACTION_PREVIEW)

      end
    end

    # -----

    def _do_action

      part = get_active_part
      definition = part.def.definition

      size = part.def.size
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

        # Update definition attributes
        _update_orientation_locked_on_axis(definition)

      # Commit model modification operation
      model.commit_operation

      # Fire event
      PLUGIN.app_observer.model_observer.onDrawingChange

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

    # -----

    def onToolKeyDown(tool, key, repeat, flags, view)

      if tool.is_key_ctrl_or_option?(key)
        _preview_action
        return true
      end

      super
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if tool.is_key_ctrl_or_option?(key)
        _preview_action
        return true
      end

      super
    end

    # ------

    protected

    def _preview_all_instances?
      true
    end

    def _preview_part_arrows?
      true
    end

    def _preview_part_box?
      true
    end

    def _can_pick_deeper?
      false
    end

    # -----

    def _preview_action_draw
      super
      unless @picker.picked_face.nil? || !has_active_part?

        part = get_active_part
        instance_info = part.def.get_one_instance_info

        origin, x_axis, y_axis, z_axis, plane_manipulator, line_manipulator = _get_input_axes(instance_info)
        t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)

        # Offset transformation to force arrow and mesh to be on top of part preview
        ov = Geom::Vector3d.new(plane_manipulator.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        if plane_manipulator.is_a?(FaceManipulator)

          # Highlight picked face
          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(plane_manipulator.triangles)
          k_mesh.background_color = COLOR_ACTION_FILL
          k_mesh.transformation = ot
          @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

        end

        if (t * part.def.size.oriented_transformation).identity?

          # Already adapted, notify it by tooltip success color
          @tooltip_type = SmartTool::MESSAGE_TYPE_SUCCESS

        else

          # New orientation
          @tooltip_type = SmartTool::MESSAGE_TYPE_DEFAULT

        end

        bounds = Geom::BoundingBox.new
        bounds.add(_compute_children_faces_triangles(instance_info.entity.definition.entities, t.inverse))

        # Action Front arrow
        k_arrow = Kuix::ArrowFillMotif3d.new
        k_arrow.patterns_transformation = Geom::Transformation.translation(Z_AXIS)
        k_arrow.bounds.origin.copy!(bounds.min)
        k_arrow.bounds.size.copy!(bounds)
        k_arrow.color = COLOR_ACTION_FILL
        k_arrow.transformation = ot * ot * instance_info.transformation * t
        @tool.append_3d(k_arrow, LAYER_3D_ACTION_PREVIEW)

        k_arrow = Kuix::ArrowMotif3d.new
        k_arrow.patterns_transformation = Geom::Transformation.translation(Z_AXIS)
        k_arrow.bounds.origin.copy!(bounds.min)
        k_arrow.bounds.size.copy!(bounds)
        k_arrow.color = COLOR_ACTION
        k_arrow.line_width = 2
        k_arrow.transformation = ot * ot * instance_info.transformation * t
        @tool.append_3d(k_arrow, LAYER_3D_ACTION_PREVIEW)

        # Box helper
        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(bounds)
        k_box.color = COLOR_ACTION
        k_box.line_width = 1
        k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_box.transformation = instance_info.transformation * t
        @tool.append_3d(k_box, LAYER_3D_ACTION_PREVIEW)

        # Axes helper
        k_axes_helper = Kuix::AxesHelper.new
        k_axes_helper.transformation = instance_info.transformation * t
        @tool.append_3d(k_axes_helper, LAYER_3D_ACTION_PREVIEW)

        if line_manipulator.is_a?(LineManipulator)

          if line_manipulator.infinite?

            # Highlight picked line
            k_line = Kuix::Line.new
            k_line.position = line_manipulator.position
            k_line.direction = line_manipulator.direction
            k_line.color = COLOR_ACTION
            k_line.line_width = 2
            @tool.append_3d(k_line, LAYER_3D_ACTION_PREVIEW)

          else

            # Highlight picked segment
            k_segments = Kuix::Segments.new
            k_segments.add_segments(line_manipulator.segment)
            k_segments.color = COLOR_ACTION
            k_segments.line_width = 4
            k_segments.on_top = true
            @tool.append_3d(k_segments, LAYER_3D_ACTION_PREVIEW)

          end

        end

      end
    end

    # -----

    def _do_action

      part = get_active_part
      instance_info = part.def.get_one_instance_info
      definition = instance_info.definition

      origin, x_axis, y_axis, z_axis = _get_input_axes(instance_info)
      ti = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)

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

        # Update definition attributes
        _update_orientation_locked_on_axis(definition)

      # Commit model modification operation
      model.commit_operation

      # Fire event
      PLUGIN.app_observer.model_observer.onDrawingChange

    end

    # -----

    def _get_input_axes(instance_info)

      plane_manipulator = @picker.picked_plane_manipulator
      if plane_manipulator.nil?
        face, inner_path = _find_largest_face(instance_info.entity, instance_info.transformation)
        container_path = instance_info.path + inner_path
        plane_manipulator = FaceManipulator.new(face, PathUtils.get_transformation(container_path, IDENTITY))
      end

      line_manipulator = @picker.picked_line_manipulator
      if line_manipulator.nil? || !line_manipulator.direction.perpendicular?(plane_manipulator.normal)
        line_manipulator = EdgeManipulator.new(plane_manipulator.longest_outer_edge, plane_manipulator.transformation)
      end

      ti = instance_info.transformation.inverse

      z_axis = plane_manipulator.normal.transform(ti)
      x_axis = line_manipulator.direction.transform(ti)
      x_axis.reverse! if line_manipulator.respond_to?(:reversed_in?) && plane_manipulator.respond_to?(:face) && line_manipulator.reversed_in?(plane_manipulator.face)
      x_axis.reverse! if @tool.is_key_ctrl_or_option_down?
      y_axis = z_axis.cross(x_axis)

      [ ORIGIN, x_axis, y_axis, z_axis, plane_manipulator, line_manipulator ]
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
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_axes.action_0')
    end

    # -----

    protected

    def _preview_all_instances?
      true
    end

    def _preview_part_axes?
      true
    end

    def _preview_part_arrows?
      true
    end

    def _preview_part_box?
      true
    end

    def _can_activate_part?(part)
      true
    end

    def _can_pick_deeper?
      false
    end

    # -----

    def _preview_action_draw
      super
      unless @picker.picked_point.nil? || !has_active_part?

        et = _get_edit_transformation

        part = get_active_part
        instance_info = part.def.get_one_instance_info

        input_point = @picker.picked_point.transform(instance_info.transformation.inverse)
        ti = Geom::Transformation.translation(Geom::Vector3d.new(input_point.to_a))

        k_axes_helper = Kuix::AxesHelper.new
        k_axes_helper.transformation = et * ti
        @tool.append_3d(k_axes_helper, LAYER_3D_ACTION_PREVIEW)

      end
    end

    # -----

    def _do_action

      if @picker.picked_point.nil?
        UI.beep
        return true
      end

      part = get_active_part
      instance_info = part.def.get_one_instance_info

      input_point = @picker.picked_point.transform(instance_info.transformation.inverse)
      ti = Geom::Transformation.translation(Geom::Vector3d.new(input_point.to_a))
      t = ti.inverse

      definition = part.def.definition

      model = Sketchup.active_model
      model.start_operation('OCL Change Axes', true, false, false)

        # Transform definition's entities
        entities = definition.entities
        entities.transform_entities(t, entities.to_a)

        # Inverse transform definition's instances
        definition.instances.each do |instance|
          instance.transformation *= ti
        end

        # Update definition attributes
        _update_orientation_locked_on_axis(definition)

      # Commit model modification operation
      model.commit_operation

      # Fire event
      PLUGIN.app_observer.model_observer.onDrawingChange

    end


  end

end
