module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geometrix/finder/circle_finder'
  require_relative '../lib/fiddle/clippy/clippy'
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
    ACTION_DISTRIBUTE = 3

    ACTION_OPTION_MEASURE_TYPE = 'measure_type'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_MEASURE_TYPE_OUTSIDE = 'outside'
    ACTION_OPTION_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_MEASURE_TYPE_INSIDE = 'inside'

    ACTION_OPTION_OPTIONS_MIRROR = 'mirror'

    ACTIONS = [
      {
        :action => ACTION_SELECT,
      },
      {
        :action => ACTION_COPY_LINE,
        :options => {
          ACTION_OPTION_MEASURE_TYPE => [ACTION_OPTION_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_MEASURE_TYPE_CENTERED, ACTION_OPTION_MEASURE_TYPE_INSIDE ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MIRROR ]
        }
      },
      {
        :action => ACTION_COPY_GRID,
        :options => {
          ACTION_OPTION_MEASURE_TYPE => [ACTION_OPTION_MEASURE_TYPE_OUTSIDE, ACTION_OPTION_MEASURE_TYPE_CENTERED, ACTION_OPTION_MEASURE_TYPE_INSIDE ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MIRROR ]
        }
      },
      {
        :action => ACTION_DISTRIBUTE,
      }
    ].freeze

    # -----

    attr_reader :callback_action_handler,
                :cursor_select, :cursor_select_part, :cursor_select_copy_line, :cursor_select_copy_grid, :cursor_select_distribute, :cursor_move, :cursor_move_copy, :cursor_pin_1, :cursor_pin_2

    def initialize(current_action: nil, callback_action_handler: nil)
      super(current_action: current_action)

      @callback_action_handler = callback_action_handler

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
      @cursor_select_part = create_cursor('select-part', 0, 0)
      @cursor_select_copy_line = create_cursor('select-copy-line', 0, 0)
      @cursor_select_copy_grid = create_cursor('select-copy-grid', 0, 0)
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
      when ACTION_COPY_LINE, ACTION_COPY_GRID, ACTION_DISTRIBUTE
          return @cursor_move_copy
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

      when ACTION_OPTION_MEASURE_TYPE
        return true

      end

      false
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_MEASURE_TYPE
        case option
        when ACTION_OPTION_MEASURE_TYPE_OUTSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.333,0.583L0.333,0.917L0,0.917M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917 M0,0.25L1,0.25 M0,0.083L0,0.417 M1,0.083L1,0.417'))
        when ACTION_OPTION_MEASURE_TYPE_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.333,0.583L0.333,0.917L0,0.917 M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917 M0.167,0.25L0.822,0.25 M0.167,0.083L0.167,0.417 M0.822,0.083L0.822,0.417'))
        when ACTION_OPTION_MEASURE_TYPE_INSIDE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.917L0,0.583L0.333,0.583L0.333,0.917L0,0.917M0.655,0.917L0.655,0.583L0.989,0.583L0.989,0.917L0.655,0.917 M0.333,0.25L0.667,0.25 M0.333,0.083L0.333,0.417 M0.667,0.083L0.667,0.417'))
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

    def onActivate(view)

      # Clear current selection
      # Sketchup.active_model.selection.clear if Sketchup.active_model

      super
    end

    def onActionChanged(action)

      case action
      when ACTION_SELECT
        set_action_handler(SmartHandleSelectActionHandler.new(self))
      when ACTION_COPY_LINE
        set_action_handler(SmartHandleCopyLineActionHandler.new(self))
      when ACTION_COPY_GRID
        set_action_handler(SmartHandleCopyGridActionHandler.new(self))
      when ACTION_DISTRIBUTE
        set_action_handler(SmartHandleDistributeActionHandler.new(self))
      end

      super

      refresh

    end

    def onViewChanged(view)
      super
      refresh
    end

  end

  # -----

  class SmartHandleActionHandler < SmartActionHandler

    include UserTextHelper
    include SmartActionHandlerPartHelper

    STATE_SELECT = 0
    STATE_HANDLE_START = 1
    STATE_HANDLE = 2
    STATE_HANDLE_COPIES = 3

    def initialize(action, tool, action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(tool)

      @mouse_snap_point = nil

      @picked_handle_start_point = nil
      @picked_handle_end_point = nil

      @definition = nil
      @instances = []
      @drawing_def = nil

    end

    # ------

    def start
      super

      return if (model = Sketchup.active_model).nil?

      # Try to select part from current selection
      selection = model.selection
      entity = selection.first
      if entity.is_a?(Sketchup::ComponentInstance)
        path = (model.active_path.is_a?(Array) ? model.active_path : []) + [ entity ]
        part_entity_path = _get_part_entity_path_from_path(path)
        if (part = _generate_part_from_path(part_entity_path))
          _set_active_part(part_entity_path, part)
          onPartSelected
        end
      end

      # Clear current selection
      selection.clear

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
      when STATE_SELECT
        return SmartPicker.new(tool: @tool, pick_point: false)
      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_HANDLE
        return PLUGIN.get_i18n_string("tool.smart_handle.action_#{@action}_state_#{state}_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)
      super
    end

    # -----

    def onToolCancel(tool, reason, view)

      case @state

      when STATE_SELECT
        if @tool.callback_action_handler.nil?
          _reset
        else
          Sketchup.active_model.tools.push_tool(@tool.callback_action_handler)
          return true
        end

      when STATE_HANDLE_START
        @picked_shape_start_point = nil
        set_state(STATE_SELECT)
        _reset

      when STATE_HANDLE
        @picked_shape_start_point = nil
        set_state(STATE_SELECT)
        _reset

      end
      _refresh

    end

    def onToolMouseMove(tool, flags, x, y, view)
      super

      case @state

      when STATE_SELECT

        _pick_part(@picker, view)

        if @active_part_entity_path.is_a?(Array)

          # Show part infos
          @tool.show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

          if @active_part_entity_path.length > 1

            parent = @active_part_entity_path[-2]
            parent_transformation = PathUtils.get_transformation(@active_part_entity_path[0...-2], IDENTITY)

            k_box = Kuix::BoxMotif.new
            k_box.bounds.copy!(parent.bounds)
            k_box.line_width = 1
            k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
            k_box.transformation = parent_transformation
            @tool.append_3d(k_box)

          end

        else

          @tool.remove_tooltip

        end

      when STATE_HANDLE_START

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d(1)

        _snap_handle_start(flags, x, y, view)

      when STATE_HANDLE

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_3d(1)

        _snap_handle(flags, x, y, view)
        _preview_handle(view)

      end

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

    end

    def onToolMouseLeave(tool, view)
      @tool.remove_all_2d
      @tool.remove_3d(1)
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onToolLButtonUp(tool, flags, x, y, view)

      case @state

      when STATE_SELECT

        if @active_part_entity_path.nil?
          UI.beep
          return true
        end

        onPartSelected

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

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      if key == ALT_MODIFIER_KEY
        @tool.store_action_option_value(@action, SmartHandleTool::ACTION_OPTION_OPTIONS, SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR, !_fetch_option_mirror, true)
        _refresh
        return true
      end

    end

    def onToolUserText(tool, text, view)
      return true if super

      case @state

      when STATE_HANDLE
        return _read_handle(text, view)

      when STATE_HANDLE_COPIES
        return _read_handle_copies(text, view)

      end

      false
    end

    def onStateChanged(state)
      super

      @tool.remove_tooltip

    end

    def onPartSelected
      return if (instance = _get_instance).nil?

      @instances << instance
      @definition = instance.definition
      @drawing_def = nil

      drawing_def = _get_drawing_def

      @picked_handle_start_point = drawing_def.bounds.center.transform(drawing_def.transformation)

      set_state(STATE_HANDLE)
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

    def getExtents
      if (drawing_def = _get_drawing_def).is_a?(DrawingDef)

        min = drawing_def.bounds.min.transform(drawing_def.transformation)
        max = drawing_def.bounds.max.transform(drawing_def.transformation)

        bounds = Geom::BoundingBox.new
        bounds.add(min)
        bounds.add(max)

        ps = @picked_handle_start_point
        pe = @picked_handle_end_point.nil? ? @mouse_snap_point : @picked_handle_end_point

        unless ps.nil? || pe.nil?

          v = ps.vector_to(pe)
          bounds.add(min.offset(v))
          bounds.add(max.offset(v))

        end

        bounds
      end
    end

    # -----

    protected

    def _reset
      @mouse_ip.clear
      @mouse_snap_point = nil
      @picked_handle_start_point = nil
      @picked_handle_end_point = nil
      @definition = nil
      @instances.clear
      @drawing_def = nil
      super
      set_state(STATE_SELECT)
    end

    def _restart
      if @tool.callback_action_handler.nil?
        super
      else
        @tool.callback_action_handler.previous_action_handler = self
        Sketchup.active_model.tools.pop_tool
      end
    end

    # -----

    def _snap_handle_start(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _snap_handle(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_handle(view)
    end

    def _read_handle(text, view)
      false
    end

    def _read_handle_copies(text, view)
      false
    end

    # -----

    def _fetch_option_measure_type
      @tool.fetch_action_option_value(@action, SmartHandleTool::ACTION_OPTION_MEASURE_TYPE)
    end

    def _fetch_option_mirror
      @tool.fetch_action_option_boolean(@action, SmartHandleTool::ACTION_OPTION_OPTIONS, SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR)
    end

    # -----

    def _handle_entity
    end

    # -----

    def _get_instance
      return @active_part_entity_path.last if @active_part_entity_path.is_a?(Array)
      nil
    end

    def _get_drawing_def
      return nil if @active_part_entity_path.nil?
      return @drawing_def unless @drawing_def.nil?

      model = Sketchup.active_model
      return nil if model.nil?

      @drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path,
        ignore_surfaces: true,
        ignore_faces: true,
        ignore_edges: false,
        ignore_soft_edges: false,
        ignore_clines: false
      ).run
    end

    def _get_drawing_def_segments(drawing_def)
      segments = []
      if drawing_def.is_a?(DrawingDef)
        segments += drawing_def.cline_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
        segments += drawing_def.edge_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
        segments += drawing_def.curve_manipulators.map { |manipulator| manipulator.segments }.flatten(1)
      end
      segments
    end

    # -- UTILS --

    def _copy_instance_properties(src_instance, dst_instance)
      dst_instance.material = src_instance.material
      dst_instance.name = src_instance.name
      dst_instance.layer = src_instance.layer
      dst_instance.casts_shadows = src_instance.casts_shadows?
    end

  end

  class SmartHandleSelectActionHandler < SmartHandleActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartHandleTool::ACTION_SELECT, tool, action_handler)
    end

    # -----

    def onPartSelected

      Sketchup.active_model.selection.clear
      Sketchup.active_model.selection.add(@active_part_entity_path.last)

      set_state(STATE_SELECT)
      _refresh

    end

  end

  class SmartHandleCopyLineActionHandler < SmartHandleActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_COPY_LINE, tool, previous_action_handler)

      @locked_axis = nil

    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_HANDLE
        return @tool.cursor_select_copy_line
      end

      super
    end

    # -----

    def onToolKeyDown(tool, key, repeat, flags, view)

      if key == VK_RIGHT
        x_axis = _get_active_x_axis
        if @locked_axis == x_axis
          @locked_axis = nil
        else
          @locked_axis = x_axis
        end
        _refresh
        return true
      elsif key == VK_LEFT
        y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
        if @locked_axis == y_axis
          @locked_axis = nil
        else
          @locked_axis = y_axis
        end
        _refresh
        return true
      elsif key == VK_UP
        z_axis = _get_active_z_axis
        if @locked_axis == z_axis
          @locked_axis = nil
        else
          @locked_axis = z_axis
        end
        _refresh
        return true
      elsif key == VK_DOWN
        UI.beep
      end

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

          v = ps.vector_to(pe)
          if v.valid?

            bounds = Geom::BoundingBox.new
            bounds.add([ -1, -1, -1], [ 1, 1, 1 ])

            line = [ ORIGIN, v ]

            plane_btm = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(2))
            ibtm = Geom.intersect_line_plane(line, plane_btm)
            if !ibtm.nil? && bounds.contains?(ibtm)
              move_axis = _get_active_z_axis
            else
              plane_lft = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(2), bounds.corner(4))
              ilft = Geom.intersect_line_plane(line, plane_lft)
              if !ilft.nil? && bounds.contains?(ilft)
                move_axis = _get_active_x_axis
              else
                plane_frt = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(4))
                ifrt = Geom.intersect_line_plane(line, plane_frt)
                if !ifrt.nil? && bounds.contains?(ifrt)
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
      return if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_measure_type)).nil?

      drawing_def, bounds, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :bounds, :mps, :mpe, :dps, :dpe)

      return unless (v = mps.vector_to(mpe)).valid?
      color = _get_vector_color(v)

      segments = _get_drawing_def_segments(drawing_def)

      mt = Geom::Transformation.translation(v)
      mt *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 - f.abs * 2 }) if _fetch_option_mirror

      k_segments = Kuix::Segments.new
      k_segments.add_segments(segments)
      k_segments.line_width = 1.5
      k_segments.color = Kuix::COLOR_BLACK
      k_segments.transformation = mt * drawing_def.transformation
      @tool.append_3d(k_segments, 1)

      @tool.append_3d(_create_floating_points(points: [ mps, mpe ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_DARK_GREY), 1)
      @tool.append_3d(_create_floating_points(points: [ dps, dpe ], style: Kuix::POINT_STYLE_CIRCLE, stroke_color: color), 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(dps)
      k_line.end.copy!(dpe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.line_width = 1.5 unless @locked_axis.nil?
      k_line.color = Kuix::COLOR_MEDIUM_GREY
      k_line.on_top = true
      @tool.append_3d(k_line, 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(dps)
      k_line.end.copy!(dpe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.line_width = 1.5 unless @locked_axis.nil?
      k_line.color = color
      @tool.append_3d(k_line, 1)

      k_box = Kuix::BoxMotif.new
      k_box.bounds.copy!(bounds)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.color = color
      @tool.append_3d(k_box, 1)

      k_box = Kuix::BoxMotif.new
      k_box.bounds.copy!(bounds)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.color = color
      k_box.transformation = mt
      @tool.append_3d(k_box, 1)

      distance = dps.vector_to(dpe).length

      Sketchup.set_status_text(distance, SB_VCB_VALUE)

      if distance > 0

        k_label = _create_floating_label(
          screen_point: view.screen_coords(dps.offset(dps.vector_to(dpe), distance / 2)),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(text, view)
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_measure_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      v = dps.vector_to(dpe)

      distance = _read_user_text_length(text, v.length)
      return true if distance.nil?

      @picked_handle_end_point = dps.offset(v, distance)

      _handle_entity
      set_state(STATE_HANDLE_COPIES)
      _restart

      true
    end

    def _read_handle_copies(text, view)
      return if @definition.nil?

      v, _ = _split_user_text(text)

      if v && (match = v.match(/^([x*\/])(\d+)$/))

        operator, value = match ? match[1, 2] : [ nil, nil ]

        number = value.to_i

        if !value.nil? && number == 0
          UI.beep
          @tool.notify_errors([ [ "tool.default.error.invalid_#{operator == '/' ? 'divider' : 'multiplicator'}", { :value => value } ] ])
          return true
        end

        operator = operator.nil? ? '*' : operator

        number = number == 0 ? 1 : number

        _copy_line_entity(operator, number)
        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    # -----

    def _handle_entity
      _copy_line_entity
    end

    def _copy_line_entity(operator_1 = '*', number_1 = 1)
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, _fetch_option_measure_type)).nil?

      mps, mpe = move_def.values_at(:mps, :mpe)
      v = mps.vector_to(mpe)

      model = Sketchup.active_model
      model.start_operation('Copy Part', true)

        if operator_1 == '/'
          ux = v.x / number_1
          uy = v.y / number_1
          uz = v.z / number_1
        else
          ux = v.x
          uy = v.y
          uz = v.z
        end

        src_instance = @active_part_entity_path[-1]
        old_instances = @instances[1..-1]

        if @active_part_entity_path.one?
          entities = model.entities
        else
          entities = @active_part_entity_path[-2].definition.entities
        end

        entities.erase_entities(old_instances) if old_instances.any?
        @instances = [ src_instance ]

        (1..number_1).each do |i|

          next if i == 0  # Ignore src instance

          vt = Geom::Vector3d.new(ux * i, uy * i, uz * i)

          mt = Geom::Transformation.translation(vt)
          mt *= Geom::Transformation.scaling(mps, *vt.normalize.to_a.map { |f| 1.0 * (f == 0 ? 1 : -1) }) if _fetch_option_mirror
          mt *= src_instance.transformation

          dst_instance = entities.add_instance(@definition, mt)

          @instances << dst_instance

          _copy_instance_properties(src_instance, dst_instance)

        end

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe, type = 0)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return unless (v = ps.vector_to(pe)).valid?

      bounds = Geom::BoundingBox.new
      drawing_def.edge_manipulators.each { |edge_manipulator| bounds.add(edge_manipulator.start_point.transform(drawing_def.transformation), edge_manipulator.end_point.transform(drawing_def.transformation)) }

      center = bounds.center
      line = [ center, v ]

      plane_btm = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(2))
      ibtm = Geom.intersect_line_plane(line, plane_btm)
      if !ibtm.nil? && bounds.contains?(ibtm)
        vs = ibtm.vector_to(center)
        vs.reverse! if vs.samedirection?(v)
      else
        plane_lft = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(2), bounds.corner(4))
        ilft = Geom.intersect_line_plane(line, plane_lft)
        if !ilft.nil? && bounds.contains?(ilft)
          vs = ilft.vector_to(center)
          vs.reverse! if vs.samedirection?(v)
        else
          plane_frt = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(4))
          ifrt = Geom.intersect_line_plane(line, plane_frt)
          if !ifrt.nil? && bounds.contains?(ifrt)
            vs = ifrt.vector_to(center)
            vs.reverse! if vs.samedirection?(v)
          end
        end
      end

      lps = center
      lpe = pe.project_to_line(line)

      ve = vs.reverse

      case type
      when SmartHandleTool::ACTION_OPTION_MEASURE_TYPE_OUTSIDE
        mps = center
        mpe = lpe.offset(vs)
        dps = lps.offset(vs)
        dpe = lpe
      when SmartHandleTool::ACTION_OPTION_MEASURE_TYPE_CENTERED
        mps = lps
        mpe = lpe
        dps = lps
        dpe = lpe
      when SmartHandleTool::ACTION_OPTION_MEASURE_TYPE_INSIDE
        mps = center
        mpe = lpe.offset(ve)
        dps = lps.offset(ve)
        dpe = lpe
      else
        return
      end

      return unless mps.vector_to(mpe).valid? # No move

      {
        drawing_def: drawing_def,
        bounds: bounds,
        vs: vs,
        ve: ve,
        lps: lps,
        lpe: lpe,
        mps: mps,
        mpe: mpe,
        dps: dps,
        dpe: dpe
      }
    end

  end

  class SmartHandleCopyGridActionHandler < SmartHandleActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_COPY_GRID, tool, previous_action_handler)

      @normal = Z_AXIS

    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT, STATE_HANDLE
        return @tool.cursor_select_copy_grid
      end

      super
    end

    # -----

    def _snap_handle(flags, x, y, view)

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
      return if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, @normal, _fetch_option_measure_type)).nil?

      drawing_def, bounds, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :bounds, :mps, :mpe, :dps, :dpe)

      color = _get_vector_color(@normal)

      m_bounds = Geom::BoundingBox.new
      m_bounds.add(mps, mpe)

      d_bounds = Geom::BoundingBox.new
      d_bounds.add(dps, dpe)

      segments = _get_drawing_def_segments(drawing_def)

      (0..3).each do |i|

        p = m_bounds.corner(i)
        v = mps.vector_to(p)

        mt = Geom::Transformation.translation(v)
        mt *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 * (f == 0 ? 1 : -1) }) if _fetch_option_mirror

        k_box = Kuix::BoxMotif.new
        k_box.bounds.copy!(bounds)
        k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_box.color = color
        k_box.transformation = mt
        @tool.append_3d(k_box, 1)

        next if p == mps

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 1.5
        k_segments.color = Kuix::COLOR_BLACK
        k_segments.transformation = mt * drawing_def.transformation
        @tool.append_3d(k_segments, 1)

      end

      @tool.append_3d(_create_floating_points(points: [ m_bounds.corner(0), m_bounds.corner(1), m_bounds.corner(2), m_bounds.corner(3) ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_MEDIUM_GREY), 1)
      @tool.append_3d(_create_floating_points(points: [ d_bounds.corner(0), d_bounds.corner(1), d_bounds.corner(2), d_bounds.corner(3) ], style: Kuix::POINT_STYLE_CIRCLE, stroke_color: color), 1)

      k_rectangle = Kuix::RectangleMotif.new
      k_rectangle.bounds.copy!(d_bounds)
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_rectangle.color = Kuix::COLOR_MEDIUM_GREY
      k_rectangle.on_top = true
      @tool.append_3d(k_rectangle, 1)

      k_rectangle = Kuix::RectangleMotif.new
      k_rectangle.bounds.copy!(d_bounds)
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_rectangle.color = color
      @tool.append_3d(k_rectangle, 1)

      k_box = Kuix::BoxMotif.new
      k_box.bounds.copy!(bounds)
      k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_box.color = color
      @tool.append_3d(k_box, 1)

      distance_x = d_bounds.width
      distance_y = d_bounds.height

      Sketchup.set_status_text("#{distance_x}#{Sketchup::RegionalSettings.list_separator} #{distance_y}", SB_VCB_VALUE)

      if distance_x > 0

        k_label = _create_floating_label(
          screen_point: view.screen_coords(d_bounds.min.offset(X_AXIS, distance_x / 2)),
          text: distance_x,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end
      if distance_y > 0

        k_label = _create_floating_label(
          screen_point: view.screen_coords(d_bounds.min.offset(Y_AXIS, distance_y / 2)),
          text: distance_y,
          text_color: Kuix::COLOR_Y,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(text, view)
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, @normal, _fetch_option_measure_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      v = dps.vector_to(dpe)

      d1, d2 = _split_user_text(text)

      if d1 || d2

        distance_x = _read_user_text_length(d1, v.x.abs)
        return true if distance_x.nil?

        distance_y = _read_user_text_length(d2, v.y.abs)
        return true if distance_y.nil?

        @picked_handle_end_point = dps.offset(Geom::Vector3d.new(v.x < 0 ? -distance_x : distance_x, v.y < 0 ? -distance_y : distance_y))

        _handle_entity
        set_state(STATE_HANDLE_COPIES)
        _restart

        return true
      end

      false
    end

    def _read_handle_copies(text, view)
      return if @definition.nil?

      v1, v2 = _split_user_text(text)

      if v1 && (match_1 = v1.match(/^([x*\/])(\d+)$/)) || v2 && (match_2 = v2.match(/^([x*\/])(\d+)$/))

        operator_1, value_1 = match_1 ? match_1[1, 2] : [ nil, nil ]
        operator_2, value_2 = match_2 ? match_2[1, 2] : [ nil, nil ]

        number_1 = value_1.to_i
        number_2 = value_2.to_i

        if !value_1.nil? && number_1 == 0
          UI.beep
          @tool.notify_errors([ [ "tool.default.error.invalid_#{operator_1 == '/' ? 'divider' : 'multiplicator'}", { :value => value_1 } ] ])
          return true
        end
        if !value_2.nil? && number_2 == 0
          UI.beep
          @tool.notify_errors([ [ "tool.default.error.invalid_#{operator_2 == '/' ? 'divider' : 'multiplicator'}", { :value => value_2 } ] ])
          return true
        end

        has_separator = text.include?(Sketchup::RegionalSettings.list_separator)

        operator_1 = operator_1.nil? ? '*' : operator_1
        operator_2 = operator_2.nil? ? (has_separator ? '*' : operator_1) : operator_2

        number_1 = number_1 == 0 ? 1 : number_1
        number_2 = number_2 == 0 ? (has_separator ? 1 : number_1) : number_2

        _copy_grid_entity(operator_1, number_1, operator_2, number_2)
        Sketchup.set_status_text('', SB_VCB_VALUE)


        return true
      end

      false
    end

    # -----

    def _handle_entity
      _copy_grid_entity
    end

    def _copy_grid_entity(operator_1 = '*', number_1 = 1, operator_2 = '*', number_2 = 1)
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, @normal, _fetch_option_measure_type)).nil?

      mps, mpe = move_def.values_at(:mps, :mpe)
      v = mps.vector_to(mpe)

      model = Sketchup.active_model
      model.start_operation('Copy Part', true)

        if operator_1 == '/'
          ux = v.x / number_1
        else
          ux = v.x
        end
        if operator_2 == '/'
          uy = v.y / number_2
        else
          uy = v.y
        end

        src_instance = @active_part_entity_path[-1]
        old_instances = @instances[1..-1]

        if @active_part_entity_path.one?
          entities = model.entities
        else
          entities = @active_part_entity_path[-2].definition.entities
        end

        entities.erase_entities(old_instances) if old_instances.any?
        @instances = [ src_instance ]

        (0..number_1).each do |x|
          (0..number_2).each do |y|

            next if x == 0 && y == 0  # Ignore src instance

            vt = Geom::Vector3d.new(ux * x, uy * y)

            mt = Geom::Transformation.translation(vt)
            mt *= Geom::Transformation.scaling(mps, *vt.normalize.to_a.map { |f| 1.0 * (f == 0 ? 1 : -1) }) if _fetch_option_mirror
            mt *= src_instance.transformation

            dst_instance = entities.add_instance(@definition, mt)
            @instances << dst_instance

            _copy_instance_properties(src_instance, dst_instance)

          end
        end

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe, n, type = 0)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return unless ps.vector_to(pe).valid?

      bounds = Geom::BoundingBox.new
      drawing_def.edge_manipulators.each { |edge_manipulator| bounds.add(edge_manipulator.start_point.transform(drawing_def.transformation), edge_manipulator.end_point.transform(drawing_def.transformation)) }

      center = bounds.center
      plane = [ center, n ]
      line_x = [ center, X_AXIS ]
      line_y = [ center, Y_AXIS ]

      lps = center
      lpe = pe.project_to_plane(plane)

      vx = center.vector_to(lpe.project_to_line(line_x))
      vy = center.vector_to(lpe.project_to_line(line_y))

      fn_compute = lambda { |line, v|

        plane_btm = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(2))
        ibtm = Geom.intersect_line_plane(line, plane_btm)
        if !ibtm.nil? && bounds.contains?(ibtm)
          vs = ibtm.vector_to(center)
          vs.reverse! if v.valid? && vs.samedirection?(v)
        else
          plane_lft = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(2), bounds.corner(4))
          ilft = Geom.intersect_line_plane(line, plane_lft)
          if !ilft.nil? && bounds.contains?(ilft)
            vs = ilft.vector_to(center)
            vs.reverse! if v.valid? && vs.samedirection?(v)
          else
            plane_frt = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(4))
            ifrt = Geom.intersect_line_plane(line, plane_frt)
            if !ifrt.nil? && bounds.contains?(ifrt)
              vs = ifrt.vector_to(center)
              vs.reverse! if v.valid? && vs.samedirection?(v)
            end
          end
        end

        ve = vs.reverse

        [ vs, ve ]
      }

      vsx, vex = fn_compute.call([ center, X_AXIS ], vx)
      vsy, vey = fn_compute.call([ center, Y_AXIS ], vy)

      vs = vsx + vsy
      ve = vex + vey

      case type
      when SmartHandleTool::ACTION_OPTION_MEASURE_TYPE_OUTSIDE
        mps = center
        mpe = lpe.offset(vs)
        dps = lps.offset(vs)
        dpe = lpe
      when SmartHandleTool::ACTION_OPTION_MEASURE_TYPE_CENTERED
        mps = lps
        mpe = lpe
        dps = lps
        dpe = lpe
      when SmartHandleTool::ACTION_OPTION_MEASURE_TYPE_INSIDE
        mps = center
        mpe = lpe.offset(ve)
        dps = lps.offset(ve)
        dpe = lpe
      else
        return
      end

      return unless mps.vector_to(mpe).valid? # No move

      {
        drawing_def: drawing_def,
        bounds: bounds,
        lps: lps,
        lpe: lpe,
        vs: vs,
        ve: ve,
        mps: mps,
        mpe: mpe,
        dps: dps,
        dpe: dpe
      }
    end

  end

  class SmartHandleDistributeActionHandler < SmartHandleActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartHandleTool::ACTION_DISTRIBUTE, tool, previous_action_handler)

      @locked_axis = nil

    end

    # -----

    def stop
      unless (instance = _get_instance).nil?
        instance.hidden = false
      end
      super
    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT
        return @tool.cursor_select_distribute
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

    def onToolKeyDown(tool, key, repeat, flags, view)

      if key == VK_RIGHT
        x_axis = _get_active_x_axis
        if @locked_axis == x_axis
          @locked_axis = nil
        else
          @locked_axis = x_axis
        end
        _refresh
        return true
      elsif key == VK_LEFT
        y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
        if @locked_axis == y_axis
          @locked_axis = nil
        else
          @locked_axis = y_axis
        end
        _refresh
        return true
      elsif key == VK_UP
        z_axis = _get_active_z_axis
        if @locked_axis == z_axis
          @locked_axis = nil
        else
          @locked_axis = z_axis
        end
        _refresh
        return true
      elsif key == VK_DOWN
        UI.beep
      end

    end

    def onStateChanged(state)
      super

      unless (instance = _get_instance).nil?
        if state == STATE_HANDLE
          @tool.remove_3d(0)  # Remove part preview
          instance.hidden = true
        else
          instance.hidden = false
        end
      end

    end

    def onPartSelected

      instance = @active_part_entity_path.last

      @instances << instance
      @definition = instance.definition
      @drawing_def = nil

      @src_transformation = instance.transformation

      set_state(STATE_HANDLE_START)
      _refresh

    end

    # -----

    protected

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

        picked_point, _ = Geom::closest_points([@picked_handle_start_point, move_axis ], view.pickray(x, y))
        @mouse_snap_point = picked_point

      else

        if @locked_axis

          move_axis = @locked_axis

        else

          # Compute axis from 3D position

          ps = @picked_handle_start_point
          pe = @mouse_ip.position
          move_axis = _get_active_x_axis

          v = ps.vector_to(pe)
          if v.valid?

            bounds = Geom::BoundingBox.new
            bounds.add([ -1, -1, -1], [ 1, 1, 1 ])

            line = [ ORIGIN, v ]

            plane_btm = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(2))
            ibtm = Geom.intersect_line_plane(line, plane_btm)
            if !ibtm.nil? && bounds.contains?(ibtm)
              move_axis = _get_active_z_axis
            else
              plane_lft = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(2), bounds.corner(4))
              ilft = Geom.intersect_line_plane(line, plane_lft)
              if !ilft.nil? && bounds.contains?(ilft)
                move_axis = _get_active_x_axis
              else
                plane_frt = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(4))
                ifrt = Geom.intersect_line_plane(line, plane_frt)
                if !ifrt.nil? && bounds.contains?(ifrt)
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
      return if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point)).nil?

      drawing_def, ps, pe, center, v, lps, lpe, mps, mpe = move_def.values_at(:drawing_def, :ps, :pe, :center, :v, :lps, :lpe, :mps, :mpe)
      mv = mps.vector_to(mpe)
      color = _get_vector_color(v, Kuix::COLOR_DARK_GREY)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(ps)
      k_line.end.copy!(pe)
      k_line.line_width = 1.5
      k_line.color = color
      k_line.on_top = true
      @tool.append_3d(k_line, 1)

      k_points = _create_floating_points(points: [ center ], style: Kuix::POINT_STYLE_PLUS)
      @tool.append_3d(k_points, 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(lps)
      k_line.end.copy!(lpe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.line_width = 1.5 unless @locked_axis.nil?
      k_line.color = Kuix::COLOR_MEDIUM_GREY
      k_line.on_top = true
      @tool.append_3d(k_line, 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(lps)
      k_line.end.copy!(lpe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.line_width = 1.5 unless @locked_axis.nil?
      k_line.color = color
      @tool.append_3d(k_line, 1)

      @tool.append_3d(_create_floating_points(points: [ lps, lpe ], style: Kuix::POINT_STYLE_CIRCLE, stroke_color: color), 1)

      is_construction = drawing_def.cline_manipulators.any?

      segments = _get_drawing_def_segments(drawing_def)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(segments)
      k_segments.line_width = 1.5
      k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
      k_segments.color = Kuix::COLOR_DARK_GREY
      k_segments.transformation = drawing_def.transformation
      @tool.append_3d(k_segments, 1)

      count = 1
      Array.new(count) { |i| mps.offset(mv, mv.length * (i + 1) / (count + 1)) }.each do |point|

        mt = Geom::Transformation.translation(center.vector_to(point))

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = is_construction ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if is_construction
        k_segments.color = Kuix::COLOR_BLACK
        k_segments.transformation = mt * drawing_def.transformation
        @tool.append_3d(k_segments, 1)

      end

      distance = v.length

      Sketchup.set_status_text(distance, SB_VCB_VALUE)

      if distance > 0

        k_label = _create_floating_label(
          screen_point: view.screen_coords(ps.offset(v, distance / 2)),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: _get_vector_color(v, Kuix::COLOR_DARK_GREY)
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_handle(text, view)

      ps = @picked_handle_start_point
      pe = @mouse_snap_point
      v = ps.vector_to(pe)

      distance = _read_user_text_length(text, v.length)
      return true if distance.nil?

      @picked_handle_end_point = ps.offset(v, distance)

      _handle_entity
      set_state(STATE_HANDLE_COPIES)
      _restart

      true
    end

    def _read_handle_copies(text, view)

      if text && (match = text.match(/^([x*\/])(\d+)$/))

        operator, value = match ? match[1, 2] : [ nil, nil ]

        number = value.to_i

        if operator == '/' && number < 2
          UI.beep
          @tool.notify_errors([ [ "tool.smart_draw.error.invalid_divider", { :value => value } ] ])
          return true
        end
        if number == 0
          UI.beep
          @tool.notify_errors([ [ "tool.smart_draw.error.invalid_multiplicator", { :value => value } ] ])
          return true
        end

        count = operator == '/' ? number - 1 : number

        _distribute_entity(count)
        Sketchup.set_status_text('', SB_VCB_VALUE)

      end

    end

    # -----

    def _handle_entity
      _distribute_entity
    end

    def _distribute_entity(count = 1)
      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point)).nil?

      center, mps, mpe = move_def.values_at(:center, :mps, :mpe)
      mv = mps.vector_to(mpe)

      model = Sketchup.active_model
      model.start_operation('Copy Part', true)

        src_instance = @active_part_entity_path[-1]
        old_instances = @instances[1..-1]

        if @active_part_entity_path.one?
          entities = model.entities
        else
          entities = @active_part_entity_path[-2].definition.entities
        end

        entities.erase_entities(old_instances) if old_instances.any?
        @instances = [ src_instance ]

        (0...count).each do |i|

          mt = Geom::Transformation.translation(center.vector_to(mps.offset(mv, mv.length * (i + 1) / (count + 1))))
          mt *= @src_transformation

          if i == 0

            src_instance.transformation = mt

          else

            dst_instance = entities.add_instance(@definition, mt)

            @instances << dst_instance

            _copy_instance_properties(src_instance, dst_instance)

          end

        end

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return unless (v = ps.vector_to(pe)).valid?

      bounds = drawing_def.bounds

      t = drawing_def.transformation
      ti = t.inverse

      center = bounds.center.transform(t)
      corners = (0..6).map { |i| bounds.corner(i).transform(t) }
      line = [ center , v ]

      plane_btm = Geom.fit_plane_to_points(corners[0], corners[1], corners[2])
      ibtm = Geom.intersect_line_plane(line, plane_btm)
      if !ibtm.nil? && bounds.contains?(ibtm.transform(ti))
        vs = center.vector_to(ibtm)
        vs.reverse! if vs.samedirection?(v)
      else
        plane_lft = Geom.fit_plane_to_points(corners[0], corners[2], corners[4])
        ilft = Geom.intersect_line_plane(line, plane_lft)
        if !ilft.nil? && bounds.contains?(ilft.transform(ti))
          vs = center.vector_to(ilft)
          vs.reverse! if vs.samedirection?(v)
        else
          plane_frt = Geom.fit_plane_to_points(corners[0], corners[1], corners[4])
          ifrt = Geom.intersect_line_plane(line, plane_frt)
          if !ifrt.nil? && bounds.contains?(ifrt.transform(ti))
            vs = center.vector_to(ifrt)
            vs.reverse! if vs.samedirection?(v)
          end
        end
      end

      ve = vs.reverse

      lps = ps.project_to_line(line)
      lpe = pe.project_to_line(line)

      mps = vs.nil? ? lps : lps.offset(vs)
      mpe = ve.nil? ? lpe : lpe.offset(ve)

      {
        drawing_def: drawing_def,
        bounds: bounds,
        ps: ps,
        pe: pe,
        center: center,
        v: v,
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