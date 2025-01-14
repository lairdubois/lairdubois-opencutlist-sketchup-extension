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

    ACTION_COPY_LINE = 0
    ACTION_COPY_GRID = 1
    ACTION_DIVIDE = 2

    ACTION_OPTION_MEASURE_TYPE = 'measure_type'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_MEASURE_TYPE_OUTSIDE = 'outside'
    ACTION_OPTION_MEASURE_TYPE_CENTERED = 'centered'
    ACTION_OPTION_MEASURE_TYPE_INSIDE = 'inside'

    ACTION_OPTION_OPTIONS_MIRROR = 'mirror'

    ACTIONS = [
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
        :action => ACTION_DIVIDE,
      }
    ].freeze

    # -----

    attr_reader :cursor_select, :cursor_move, :cursor_move_copy, :cursor_pin_1, :cursor_pin_2

    def initialize
      super

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
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
      when ACTION_COPY_LINE, ACTION_COPY_GRID, ACTION_DIVIDE
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
      Sketchup.active_model.selection.clear if Sketchup.active_model

      super
    end

    def onActionChanged(action)

      case action
      when ACTION_COPY_LINE
        set_action_handler(SmartCopyLineActionHandler.new(self))
      when ACTION_COPY_GRID
        set_action_handler(SmartCopyGridActionHandler.new(self))
      when ACTION_DIVIDE
        set_action_handler(SmartDivideActionHandler.new(self))
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

      @mouse_ip = SmartInputPoint.new(@tool)

      @mouse_snap_point = nil

      @picked_handle_start_point = nil
      @picked_handle_end_point = nil

      set_state(STATE_SELECT)

    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_SELECT
        return @tool.cursor_select
      when STATE_HANDLE
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

    def onCancel(reason, view)

      case @state

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

      when STATE_HANDLE_START

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_all_3d

        _snap_handle_start(flags, x, y, view)

      when STATE_HANDLE

        @mouse_snap_point = nil
        @mouse_ip.pick(view, x, y)

        @tool.remove_all_2d
        @tool.remove_all_3d

        _snap_handle(flags, x, y, view)
        _preview_handle(view)

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

        puts "GRRR"

        onPartSelected

      when STATE_HANDLE
        @picked_handle_end_point = @mouse_snap_point
        _copy_entity
        set_state(STATE_HANDLE_COPIES)
        _restart

      end

    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)

      if key == ALT_MODIFIER_KEY
        @tool.store_action_option_value(@action, SmartHandleTool::ACTION_OPTION_OPTIONS, SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR, !_fetch_option_mirror, true)
        _refresh
        return true
      end

    end

    def onUserText(text, view)

      if @picked_handle_start_point.nil?
        return true if _read_handle_copies(text, view)
      end

      case @state

      when STATE_HANDLE
        return _read_handle(text, view)

      end

      false
    end

    def onPartSelected

      @picked_handle_start_point = @drawing_def.bounds.center.transform(@drawing_def.transformation)

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

    def _reset
      @mouse_ip.clear
      @mouse_snap_point = nil
      @picked_handle_start_point = nil
      @picked_handle_end_point = nil
      super
      set_state(STATE_SELECT)
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

    def _fetch_option_type
      @tool.fetch_action_option_value(@action, SmartHandleTool::ACTION_OPTION_MEASURE_TYPE)
    end

    def _fetch_option_mirror
      @tool.fetch_action_option_boolean(@action, SmartHandleTool::ACTION_OPTION_OPTIONS, SmartHandleTool::ACTION_OPTION_OPTIONS_MIRROR)
    end

    # -----

    def _copy_entity(operator_1 = '*', number_1 = 1)
    end

    # -----

    def _get_drawing_def
      @drawing_def
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

  end

  class SmartCopyLineActionHandler < SmartHandleActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartHandleTool::ACTION_COPY_LINE, tool, action_handler)
    end

    # -----

    def _snap_handle(flags, x, y, view)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.empty? && @mouse_ip.degrees_of_freedom > 1

        # Compute axis from 2D projection

        ps = view.screen_coords(@picked_handle_start_point)
        pe = Geom::Point3d.new(x, y, 0)

        move_axis = [ _get_active_x_axis, _get_active_y_axis, _get_active_z_axis ].map! { |axis| { d: pe.distance_to_line([ ps, ps.vector_to(view.screen_coords(@picked_handle_start_point.offset(axis))) ]), axis: axis } }.min { |a, b| a[:d] <=> b[:d] }[:axis]

        picked_point, _ = Geom::closest_points([@picked_handle_start_point, move_axis ], view.pickray(x, y))
        @mouse_snap_point = picked_point

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

        @mouse_snap_point = @mouse_ip.position.project_to_line([[@picked_handle_start_point, move_axis ]])

      end

      @mouse_snap_point = @mouse_ip.position if @mouse_snap_point.nil?

    end

    def _preview_handle(view)
      return if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_type)).nil?

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

    def _read_handle(text, view)
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, _fetch_option_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      v = dps.vector_to(dpe)

      distance = _read_user_text_length(text, v.length)
      return true if distance.nil?

      @picked_handle_end_point = dps.offset(v, distance)

      _copy_entity
      set_state(STATE_HANDLE_COPIES)
      _restart

      true
    end

    def _read_handle_copies(text, view)
      return false if @previous_action_handler.nil? || @previous_action_handler.fetch_state != STATE_HANDLE_COPIES

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

      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, _fetch_option_type)).nil?

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
      t *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 - f.abs * 2 }) if _fetch_option_mirror
      t *= @active_part_entity_path[-1].transformation
      (1..number_1).each do |i|
        entities.add_instance(@definition, Geom::Transformation.translation(Geom::Vector3d.new(ux * i, uy * i, uz * i)) * t)
      end

      model.commit_operation

    end

    # -----

    def _get_move_def(ps, pe, type = 0)
      return unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)
      return unless (v = ps.vector_to(pe)).valid?

      t = _get_edit_transformation
      ti = t.inverse

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

  class SmartCopyGridActionHandler < SmartHandleActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartHandleTool::ACTION_COPY_GRID, tool, action_handler)

      @normal = Z_AXIS

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
      return if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, @normal, _fetch_option_type)).nil?

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

        # if _fetch_option_options_mirror
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
      return false if (move_def = _get_move_def(@picked_handle_start_point, @mouse_snap_point, @normal, _fetch_option_type)).nil?

      dps, dpe = move_def.values_at(:dps, :dpe)
      v = dps.vector_to(dpe)

      d1, d2 = _split_user_text(text)

      if d1 || d2

        distance_x = _read_user_text_length(d1, v.x.abs)
        return true if distance_x.nil?

        distance_y = _read_user_text_length(d2, v.y.abs)
        return true if distance_y.nil?

        @picked_handle_end_point = dps.offset(Geom::Vector3d.new(v.x < 0 ? -distance_x : distance_x, v.y < 0 ? -distance_y : distance_y))

        _copy_entity
        set_state(STATE_HANDLE_COPIES)
        _restart

        return true
      end

      false
    end

    def _read_handle_copies(text, view)
      return false if @previous_action_handler.nil? || @previous_action_handler.fetch_state != STATE_HANDLE_COPIES

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

      return if (move_def = _get_move_def(@picked_handle_start_point, @picked_handle_end_point, @normal, _fetch_option_type)).nil?

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
          t *= Geom::Transformation.scaling(mps, *v.normalize.to_a.map { |f| 1.0 * (f == 0 ? 1 : -1) }) if _fetch_option_mirror
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
        vs

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

  class SmartDivideActionHandler < SmartHandleActionHandler

    def initialize(tool, action_handler = nil)
      super(SmartHandleTool::ACTION_DIVIDE, tool, action_handler)
    end

    # -- STATE --

    def get_state_cursor(state)

      case state
      when STATE_HANDLE_START
        return @tool.cursor_pin_1
      when STATE_HANDLE
        return @tool.cursor_pin_2
      end

      super
    end

    # -----

    def onCancel(reason, view)

      case @state

      when STATE_HANDLE
        set_state(STATE_HANDLE_START)
        _refresh
        return true

      end

      super
    end

    def onLButtonUp(flags, x, y, view)

      case @state

      when STATE_HANDLE_START
        @picked_handle_start_point = @mouse_snap_point
        set_state(STATE_HANDLE)
        _refresh
        return true

      end

      super
    end

    def onPartSelected

      puts "hop"

      set_state(STATE_HANDLE_START)
      _refresh

    end

    # -----

    def _snap_handle(flags, x, y, view)
      super
    end

    def _preview_handle(view)

      ps = @picked_handle_start_point
      pe = @mouse_snap_point
      v = ps.vector_to(pe)

      color = _get_vector_color(v)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(ps)
      k_line.end.copy!(pe)
      k_line.line_width = 1.5
      k_line.color = color
      k_line.on_top = true
      @tool.append_3d(k_line)

    end

  end

end