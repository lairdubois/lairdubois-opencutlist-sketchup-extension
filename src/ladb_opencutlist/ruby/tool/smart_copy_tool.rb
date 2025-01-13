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

  class SmartCopyTool < SmartTool

    ACTION_COPY_MOVE = 1
    ACTION_COPY_ARRAY = 2
    ACTION_COPY_ALONG = 3

    ACTIONS = [
      {
        :action => ACTION_COPY_MOVE,
      },
      {
        :action => ACTION_COPY_ARRAY,
      },
      {
        :action => ACTION_COPY_ALONG,
      }
    ].freeze

    # -----

    attr_reader :cursor_select, :cursor_move, :cursor_move_copy

    def initialize
      super

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
      @cursor_move = create_cursor('move', 16, 16)
      @cursor_move_copy = create_cursor('move-copy', 16, 16)

    end

    def get_stripped_name
      'copy'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_COPY_MOVE, ACTION_COPY_ARRAY, ACTION_COPY_ALONG
          return @cursor_move_copy
      end

      super
    end

    def get_action_options_modal?(action)
      false
    end

    def get_action_option_toggle?(action, option_group, option)
      false
    end

    def get_action_option_btn_child(action, option_group, option)
      super
    end

    # -- Events --

    def onActivate(view)

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

      super
    end

    def onActionChanged(action)

      case action
      when ACTION_COPY_MOVE
        set_action_handler(SmartCopyMoveActionHandler.new(self))
      when ACTION_COPY_ARRAY
        set_action_handler(SmartCopyArrayActionHandler.new(self))
      when ACTION_COPY_ALONG
        set_action_handler(SmartCopyAlongActionHandler.new(self))
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

  class SmartCopyActionHandler < SmartActionHandler

    include UserTextHelper
    include SmartActionHandlerPartHelper

    STATE_SELECT = 0
    STATE_COPY = 1
    STATE_COPY_COPIES = 2

    def initialize(action, tool, action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(@tool)

      @mouse_snap_point = nil

      @picked_copy_start_point = nil
      @picked_copy_end_point = nil

      @copy_axis = X_AXIS
      @copy_type = 0
      @copy_mirror = false

      set_state(STATE_SELECT)

    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT
        return @tool.cursor_select
      when STATE_COPY
        return @tool.cursor_move_copy
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
      super
    end

    def get_state_vcb_label(state)
      super
    end

    # -----

    def onMouseMove(flags, x, y, view)
      super

      case @state

      when STATE_SELECT

        _pick_part(@picker, view)

        if @active_part_entity_path.is_a?(Array) && @active_part_entity_path.length > 1

          parent = @active_part_entity_path[-2]
          parent_transformation = PathUtils.get_transformation(@active_part_entity_path[0...-2], IDENTITY)

          k_box = Kuix::BoxMotif.new
          k_box.bounds.copy!(parent.bounds)
          k_box.line_width = 1
          k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_box.transformation = parent_transformation
          @tool.append_3d(k_box)

        end

      when STATE_COPY

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_all_3d

        _snap_copy_point(flags, x, y, view)
        _preview_copy(view)

      end

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

    end

    def onMouseLeave(view)
      @tool.remove_all_2d
      @tool.remove_all_3d
      @mouse_ip.clear
      view.tooltip = ''
      super
    end

    def onLButtonUp(flags, x, y, view)

      case @state

      when STATE_SELECT

        if @active_part_entity_path.nil?
          UI.beep
          return true
        end

        @definition = @active_part_entity_path.last.definition
        @drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path,
                                                            ignore_surfaces: true,
                                                            ignore_faces: true,
                                                            ignore_edges: false,
                                                            ignore_soft_edges: false,
                                                            ignore_clines: false
        ).run

        @picked_copy_start_point = @drawing_def.bounds.center.transform(@drawing_def.transformation)

        set_state(STATE_COPY)
        _refresh

      when STATE_COPY
        @picked_copy_end_point = @mouse_snap_point
        _copy_entity
        set_state(STATE_COPY_COPIES)
        _restart

      end

    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)

      if key == COPY_MODIFIER_KEY
        @copy_type = (@copy_type + 1) % 3
        _refresh
      elsif key == ALT_MODIFIER_KEY
        @copy_mirror = !@copy_mirror
        _refresh
      end

    end

    def onUserText(text, view)

      if @picked_copy_start_point.nil?
        return true if _read_copy_copies(text, view)
      end

      case @state

      when STATE_COPY
        return _read_copy(text, view)

      end

      false
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

        ps = @picked_copy_start_point
        pe = @picked_copy_end_point.nil? ? @mouse_snap_point : @picked_copy_end_point

        unless ps.nil? || pe.nil?

          v = ps.vector_to(pe)
          bounds.add(min.offset(v))
          bounds.add(max.offset(v))

        end

        bounds
      end
    end

    # -----

    def _reset
      @mouse_ip.clear
      @mouse_snap_point = nil
      @picked_copy_start_point = nil
      @picked_copy_end_point = nil
      super
      set_state(STATE_SELECT)
    end

    # -----

    def _snap_copy_point(flags, x, y, view)

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_copy(view)
    end

    def _read_copy(text, view)
      false
    end

    def _read_copy_copies(text, view)
      false
    end

    # -----

    def _copy_entity(operator_1 = '*', number_1 = 1)
    end

    # -----

    def _get_drawing_def
      @drawing_def
    end

  end

  class SmartCopyMoveActionHandler < SmartCopyActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartCopyTool::ACTION_COPY_MOVE, tool, action_handler)
    end

    # -----

    def _snap_copy_point(flags, x, y, view)

      move_axis = _get_move_axis(@picked_copy_start_point, @mouse_ip.position)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        picked_point, _ = Geom::closest_points([ @picked_copy_start_point, move_axis ], view.pickray(x, y))
        @mouse_snap_point = picked_point

      else

        @mouse_snap_point = @mouse_ip.position.project_to_line([[ @picked_copy_start_point, move_axis ]])

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_copy(view)
      return if (move_def = _get_move_def(@picked_copy_start_point, @mouse_snap_point, @copy_type)).nil?

      drawing_def, bounds, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :bounds, :mps, :mpe, :dps, :dpe)

      v = mps.vector_to(mpe)
      color = _get_vector_color(v)

      segments = []
      segments += drawing_def.cline_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
      segments += drawing_def.edge_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
      segments += drawing_def.curve_manipulators.map { |manipulator| manipulator.segments }.flatten(1)

      mt = Geom::Transformation.translation(v)
      mt *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 - f.abs * 2 }) if @copy_mirror

      k_segments = Kuix::Segments.new
      k_segments.add_segments(segments)
      k_segments.line_width = 1.5
      k_segments.color = Kuix::COLOR_BLACK
      k_segments.transformation = mt * drawing_def.transformation
      @tool.append_3d(k_segments, 1)

      @tool.append_3d(_create_floating_points(points: [ mps, mpe ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_MEDIUM_GREY), 1)
      @tool.append_3d(_create_floating_points(points: [ dps, dpe ], style: Kuix::POINT_STYLE_CIRCLE, stroke_color: color), 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(dps)
      k_line.end.copy!(dpe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      k_line.color = Kuix::COLOR_MEDIUM_GREY
      k_line.on_top = true
      @tool.append_3d(k_line, 1)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(dps)
      k_line.end.copy!(dpe)
      k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
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
          screen_point: view.screen_coords(dps.offset(v, distance / 2)),
          text: distance,
          text_color: Kuix::COLOR_X,
          border_color: color
        )
        @tool.append_2d(k_label)

      end

    end

    def _read_copy(text, view)
      return false if (move_def = _get_move_def(@picked_copy_start_point, @mouse_snap_point, @copy_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      v = dps.vector_to(dpe)

      distance = _read_user_text_length(text, v.length)
      return true if distance.nil?

      @picked_copy_end_point = dps.offset(v, distance)

      _copy_entity
      set_state(STATE_COPY_COPIES)
      _restart

      true
    end

    def _read_copy_copies(text, view)
      return false if @previous_action_handler.nil? || @previous_action_handler.fetch_state != STATE_COPY_COPIES

      v, _ = _split_user_text(text)

      if v && (match = v.match(/^([x*\/])(\d+)$/))

        operator, value = match ? match[1, 2] : [ nil, nil ]

        number = value.to_i

        if !value.nil? && number == 0
          UI.beep
          @tool.notify_errors([ [ "tool.smart_draw.error.invalid_#{operator == '/' ? 'divider' : 'multiplicator'}", { :value => value } ] ])
          return true
        end

        operator = operator.nil? ? '*' : operator

        number = number == 0 ? 1 : number

        @previous_action_handler._copy_entity(operator, number)
        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    # -----

    def _copy_entity(operator_1 = '*', number_1 = 1)
      return if @definition.nil? || !@drawing_def.is_a?(DrawingDef)

      return if (move_def = _get_move_def(@picked_copy_start_point, @picked_copy_end_point, @copy_type)).nil?

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

      if @active_part_entity_path.one?
        entities = model.entities
      else
        entities = @active_part_entity_path[-2].definition.entities
      end
      t = IDENTITY
      t *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 - f.abs * 2 }) if @copy_mirror
      t *= @active_part_entity_path[-1].transformation
      (1..number_1).each do |i|
        entities.add_instance(@definition, Geom::Transformation.translation(Geom::Vector3d.new(ux * i, uy * i, uz * i)) * t)
      end

      model.commit_operation

    end

    # -----

    def _get_move_axis(ps, pe)

      v = ps.vector_to(pe)
      return X_AXIS unless v.valid?

      bounds = Geom::BoundingBox.new
      bounds.add([ -1, -1, -1], [ 1, 1, 1 ])

      line = [ ORIGIN, v ]

      plane_btm = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(2))
      ibtm = Geom.intersect_line_plane(line, plane_btm)
      if !ibtm.nil? && bounds.contains?(ibtm)
        return Z_AXIS
      else
        plane_lft = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(2), bounds.corner(4))
        ilft = Geom.intersect_line_plane(line, plane_lft)
        if !ilft.nil? && bounds.contains?(ilft)
          return X_AXIS
        else
          plane_frt = Geom.fit_plane_to_points(bounds.corner(0), bounds.corner(1), bounds.corner(4))
          ifrt = Geom.intersect_line_plane(line, plane_frt)
          if !ifrt.nil? && bounds.contains?(ifrt)
            return Y_AXIS
          end
        end
      end

      X_AXIS
    end

    def _get_move_def(ps, pe, type = 0)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      v = ps.vector_to(pe)
      return unless v.valid?

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
      when 0  # Out
        mps = center
        mpe = lpe.offset(vs)
        dps = lps.offset(vs)
        dpe = lpe
      when 1  # Centered
        mps = lps
        mpe = lpe
        dps = lps
        dpe = lpe
      when 2  # In
        mps = center
        mpe = lpe.offset(ve)
        dps = lps.offset(ve)
        dpe = lpe
      end

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

  class SmartCopyArrayActionHandler < SmartCopyActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartCopyTool::ACTION_COPY_ARRAY, tool, action_handler)
    end

    # -----

    def _snap_copy_point(flags, x, y, view)

      plane = [ @picked_copy_start_point, Z_AXIS ]

      @mouse_snap_point = @mouse_ip.position.project_to_plane(plane)

    end

    def _preview_copy(view)
      return if (move_def = _get_move_def(@picked_copy_start_point, @mouse_snap_point, Z_AXIS, @copy_type)).nil?

      drawing_def, bounds, mps, mpe, dps, dpe = move_def.values_at(:drawing_def, :bounds, :mps, :mpe, :dps, :dpe)

      color = _get_vector_color(Z_AXIS)

      m_bounds = Geom::BoundingBox.new
      m_bounds.add(mps, mpe)

      d_bounds = Geom::BoundingBox.new
      d_bounds.add(dps, dpe)

      segments = []
      segments += drawing_def.cline_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
      segments += drawing_def.edge_manipulators.map { |manipulator| manipulator.segment }.flatten(1)
      segments += drawing_def.curve_manipulators.map { |manipulator| manipulator.segments }.flatten(1)

      (0..3).each do |i|

        p = m_bounds.corner(i)
        v = mps.vector_to(p)

        mt = Geom::Transformation.translation(v)
        mt *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 * (f == 0 ? 1 : -1) }) if @copy_mirror

        # if @copy_mirror
        #
        #   k_axes = Kuix::AxesHelper.new
        #   k_axes.transformation = mt * drawing_def.transformation
        #   @tool.append_3d(k_axes, 1)
        #
        # end

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

      @tool.append_3d(_create_floating_points(points: [ mps, mpe ], style: Kuix::POINT_STYLE_PLUS, stroke_color: Kuix::COLOR_MEDIUM_GREY), 1)
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

    def _read_copy(text, view)
      return false if (move_def = _get_move_def(@picked_copy_start_point, @mouse_snap_point, @copy_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      v = dps.vector_to(dpe)

      distance = _read_user_text_length(text, v.length)
      return true if distance.nil?

      @picked_copy_end_point = dps.offset(v, distance)

      _copy_entity
      set_state(STATE_COPY_COPIES)
      _restart

      true
    end

    def _read_copy_copies(text, view)
      return false if @previous_action_handler.nil? || @previous_action_handler.fetch_state != STATE_COPY_COPIES

      v, _ = _split_user_text(text)

      if v && (match = v.match(/^([x*\/])(\d+)$/))

        operator, value = match ? match[1, 2] : [ nil, nil ]

        number = value.to_i

        if !value.nil? && number == 0
          UI.beep
          @tool.notify_errors([ [ "tool.smart_draw.error.invalid_#{operator == '/' ? 'divider' : 'multiplicator'}", { :value => value } ] ])
          return true
        end

        operator = operator.nil? ? '*' : operator

        number = number == 0 ? 1 : number

        @previous_action_handler._copy_entity(operator, number)
        Sketchup.set_status_text('', SB_VCB_VALUE)

        return true
      end

      false
    end

    # -----

    def _copy_entity(operator_1 = '*', number_1 = 1)
      return if @definition.nil? || !@drawing_def.is_a?(DrawingDef)

      return if (move_def = _get_move_def(@picked_copy_start_point, @picked_copy_end_point, Z_AXIS, @copy_type)).nil?

      mps, mpe = move_def.values_at(:mps, :mpe)

      m_bounds = Geom::BoundingBox.new
      m_bounds.add(mps, mpe)

      model = Sketchup.active_model
      model.start_operation('Copy Part', true)

        (0..3).each do |i|

          p = m_bounds.corner(i)
          v = mps.vector_to(p)
          next if p == mps

          if @active_part_entity_path.one?
            entities = model.entities
          else
            entities = @active_part_entity_path[-2].definition.entities
          end
          t = Geom::Transformation.translation(v)
          t *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 * (f == 0 ? 1 : -1) }) if @copy_mirror
          t *= @active_part_entity_path[-1].transformation

          entities.add_instance(@definition, t)

        end

      model.commit_operation

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

    def _get_move_def(ps, pe, n, type = 0)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      v = ps.vector_to(pe)
      return unless v.valid?

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
        vs

        ve = vs.reverse

        [ vs, ve ]
      }

      vsx, vex = fn_compute.call([ center, X_AXIS ], vx)
      vsy, vey = fn_compute.call([ center, Y_AXIS ], vy)

      vs = vsx + vsy
      ve = vex + vey

      case type
      when 0  # Out
        mps = center
        mpe = lpe.offset(vs)
        dps = lps.offset(vs)
        dpe = lpe
      when 1  # Centered
        mps = lps
        mpe = lpe
        dps = lps
        dpe = lpe
      when 2  # In
        mps = center
        mpe = lpe.offset(ve)
        dps = lps.offset(ve)
        dpe = lpe
      end

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

  class SmartCopyAlongActionHandler < SmartCopyActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartCopyTool::ACTION_COPY_ALONG, tool, action_handler)
    end

  end

end