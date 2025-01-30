module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative 'smart_handle_tool'
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

  class SmartDrawTool < SmartTool

    ACTION_DRAW_RECTANGLE = 0
    ACTION_DRAW_CIRCLE = 1
    ACTION_DRAW_POLYGON = 2

    ACTION_OPTION_OFFSET = 'offset'
    ACTION_OPTION_SEGMENTS = 'segments'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_OFFSET_SHAPE_OFFSET = 'shape_offset'

    ACTION_OPTION_SEGMENTS_SEGMENT_COUNT = 'segment_count'

    ACTION_OPTION_OPTIONS_CONSTRUCTION = 'construction'
    ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED = 'rectangle_centered'
    ACTION_OPTION_OPTIONS_SMOOTHING = 'smoothing'
    ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER = 'measure_from_diameter'
    ACTION_OPTION_OPTIONS_MEASURE_REVERSED = 'measure_reversed'
    ACTION_OPTION_OPTIONS_PULL_CENTRED = 'pull_centered'

    ACTIONS = [
      {
        :action => ACTION_DRAW_RECTANGLE,
        :options => {
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, ACTION_OPTION_OPTIONS_PULL_CENTRED ]
        }
      },
      {
        :action => ACTION_DRAW_CIRCLE,
        :options => {
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_SEGMENTS => [ ACTION_OPTION_SEGMENTS_SEGMENT_COUNT ],
          ACTION_OPTION_OPTIONS => [ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_SMOOTHING, ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER, ACTION_OPTION_OPTIONS_PULL_CENTRED ]
        }
      },
      {
        :action => ACTION_DRAW_POLYGON,
        :options => {
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_MEASURE_REVERSED, ACTION_OPTION_OPTIONS_PULL_CENTRED ]
        }
      }
    ].freeze

    # -----

    attr_reader :cursor_select, :cursor_pencil_rectangle, :cursor_pencil_circle, :cursor_pencil_rectangle, :cursor_pull

    def initialize(

                   current_action: nil

    )

      super(
        current_action: current_action
      )

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
      @cursor_pencil_rectangle = create_cursor('pencil-rectangle', 0, 31)
      @cursor_pencil_circle = create_cursor('pencil-circle', 0, 31)
      @cursor_pencil_polygon = create_cursor('pencil-polygon', 0, 31)
      @cursor_pull = create_cursor('pull', 16, 3)

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
          return @cursor_pencil_rectangle
      when ACTION_DRAW_CIRCLE
          return @cursor_pencil_circle
      when ACTION_DRAW_POLYGON
          return @cursor_pencil_polygon
      end

      super
    end

    def get_action_options_modal?(action)
      true
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
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_CONSTRUCTION
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,1L0,1L0,0.833 M0,0.667L0,0.333 M0,0.167L0,0L0.167,0 M0.333,0L0.667,0 M0.833,0L1,0L1,0.167 M1,0.333L1,0.667 M1,0.833L1,1L0.833,1 M0.333,1L0.667,1'))
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
        end
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

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
      when ACTION_DRAW_RECTANGLE
        set_action_handler(SmartDrawRectangleActionHandler.new(self))
      when ACTION_DRAW_CIRCLE
        set_action_handler(SmartDrawCircleActionHandler.new(self))
      when ACTION_DRAW_POLYGON
        set_action_handler(SmartDrawPolygonActionHandler.new(self))
      end

      super

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

  class SmartDrawActionHandler < SmartActionHandler

    include UserTextHelper
    include EntitiesHelper

    STATE_SHAPE_START = 0
    STATE_SHAPE = 1
    STATE_PULL = 2

    LAYER_2D_DIMENSIONS = 0
    LAYER_2D_FLOATING_TOOLS = 1

    @@last_pull_measure = 0

    attr_reader :picked_shape_start_point, :picked_shape_end_point, :picked_pull_end_point, :picked_move_end_point, :normal, :direction

    def initialize(action, tool, action_handler = nil)
      super

      @mouse_ip = SmartInputPoint.new(tool)

      @mouse_down_point = nil
      @mouse_snap_point = nil

      @picked_shape_start_point = nil
      @picked_shape_end_point = nil
      @picked_pull_end_point = nil

      @locked_direction = nil
      @locked_normal = nil
      @locked_axis = nil

      @direction = nil
      @normal = _get_active_z_axis

      @definition = nil

    end

    # -- STATE --

    def get_startup_state
      STATE_SHAPE_START
    end

    def get_state_cursor(state)

      case state

      when STATE_PULL
        return @tool.cursor_pull

      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string("tool.smart_draw.action_#{@action}_state_#{state}_status") + '.'

      when STATE_PULL
        return PLUGIN.get_i18n_string("tool.smart_draw.action_x_state_#{state}_status") + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.constrain_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_pull_locked_status') + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string('tool.smart_draw.action_option_options_pull_centered_status') + '.'

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
      if @previous_action_handler.is_a?(SmartHandleActionHandler)

        # Remove floating tool
        _remove_floating_tools

        # Copy last mouse position
        @tool.last_mouse_x = @previous_action_handler.tool.last_mouse_x
        @tool.last_mouse_y = @previous_action_handler.tool.last_mouse_y

      end

      super
    end

    def onToolCancel(tool, reason, view)

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

      @tool.remove_2d(LAYER_2D_DIMENSIONS)
      @tool.remove_all_3d

      case @state

      when STATE_SHAPE_START
        _snap_shape_start(flags, x, y, view)
        _preview_shape_start(view)
        if !@mouse_down_point.nil? && @mouse_snap_point.distance(@mouse_down_point) > view.pixels_to_model(20, @mouse_snap_point)  # Drag handled only if distance is > 20px
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

      # k_points = Kuix::Points.new
      # k_points.add_point(@mouse_snap_point)
      # k_points.size = 30
      # k_points.style = Kuix::POINT_STYLE_TRIANGLE
      # k_points.stroke_color = Kuix::COLOR_YELLOW
      # @tool.append_3d(k_points)

      # k_axes_helper = Kuix::AxesHelper.new
      # k_axes_helper.transformation = _get_transformation
      # @tool.append_3d(k_axes_helper)

      view.tooltip = @mouse_ip.tooltip
      view.invalidate

    end

    def onToolMouseLeave(tool, view)
      @tool.remove_2d(LAYER_2D_DIMENSIONS)
      @tool.remove_all_3d
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
        @picked_shape_start_point = @mouse_down_point
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
          measure /= 2 if _fetch_option_pull_centered
          @picked_pull_end_point = @picked_shape_end_point.offset(@normal, measure)

          _create_entity
          _restart

          return true
        end

      end

      false
    end

    def onToolKeyDown(tool, key, repeat, flags, view)

      if key <= 128
        key_char = key.chr
        if key_char == 'X' && @tool.is_key_down?(CONSTRAIN_MODIFIER_KEY)
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_CONSTRUCTION, !_fetch_option_construction, true)
          _refresh
          return true
        end
      end

      case @state

      when STATE_SHAPE_START, STATE_SHAPE

        if key == VK_RIGHT
          x_axis = _get_active_x_axis
          if @locked_normal == x_axis
            @locked_normal = nil
          else
            @locked_normal = x_axis
          end
          _refresh
          return true
        elsif key == VK_LEFT
          y_axis = _get_active_y_axis.reverse # Reverse to keep z axis on top
          if @locked_normal == y_axis
            @locked_normal = nil
          else
            @locked_normal = y_axis
          end
          _refresh
          return true
        elsif key == VK_UP
          z_axis = _get_active_z_axis
          if @locked_normal == z_axis
            @locked_normal = nil
          else
            @locked_normal = z_axis
          end
          _refresh
          return true
        elsif key == VK_DOWN
          face_normal = @mouse_ip.valid? && @mouse_ip.face ? @mouse_ip.face.normal.transform(@mouse_ip.transformation).normalize! : nil
          if !@locked_normal.nil? && !face_normal.nil? && @locked_normal.samedirection?(face_normal)
            @locked_normal = nil
          else
            @locked_normal = face_normal
          end
          _refresh
          return true
        end

      when STATE_PULL

        if key == CONSTRAIN_MODIFIER_KEY
          UI.beep if @@last_pull_measure == 0
          _refresh
          return true
        end

      end

      false
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_PULL
        if key == CONSTRAIN_MODIFIER_KEY
          _refresh
          return true
        elsif key == COPY_MODIFIER_KEY && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_PULL_CENTRED, !_fetch_option_pull_centered, true)
          _refresh
          return true
        end

      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      return true if _read_offset(tool, text, view)

      case @state

      when STATE_SHAPE
        return _read_shape(tool, text, view)

      when STATE_PULL
        return _read_pull(tool, text, view)

      end

      false
    end

    def onStateChanged(state)
      super
      _remove_floating_tools
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
      return Sketchup.active_model.bounds unless _picked_shape_start_point?

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      shape_points = _fetch_option_shape_offset > 0 ? _get_local_shapes_points_with_offset.flatten(1) : _get_local_shape_points

      bounds = Geom::BoundingBox.new
      bounds.add(shape_points.map { |point| point.transform(t) }) if shape_points.any?

      if _picked_shape_end_point?

        # Add Pull solid

        picked_points = _get_picked_points
        p2 = picked_points[1].transform(ti)
        p3 = picked_points[2].transform(ti)

        tt = Geom::Transformation.translation(p2.vector_to(p3))

        top_shape_points = shape_points.map { |point| point.transform(tt) }

        bounds.add(top_shape_points.map { |point| point.transform(t) })

      end

      bounds
    end

    # -----

    protected

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

      if _fetch_option_pull_centered && _picked_shape_end_point? && points.length > 2
        offset = points[2].vector_to(points[1])
        points[0] = points[0].offset(offset)
        points[1] = points[1].offset(offset)
      end

      points
    end

    def _picked_shape_start_point?
      !@picked_shape_start_point.nil?
    end

    def _picked_shape_end_point?
      !@picked_shape_end_point.nil?
    end

    # -----

    def _snap_shape_start(flags, x, y, view)

      if @locked_normal

        @normal = @locked_normal

      else

        if @mouse_ip.vertex

          # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
          #
          # k_points = Kuix::Points.new
          # k_points.add_points([ vertex_manipulator.point ])
          # k_points.size = 30
          # k_points.stroke_style = Kuix::POINT_STYLE_SQUARE
          # k_points.color = Kuix::COLOR_MAGENTA
          # @tool.append_3d(k_points)
          #
          # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
          #
          #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          #   @tool.append_3d(k_mesh)
          #
          # end

        elsif @mouse_ip.edge

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(edge_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments)

          if @mouse_ip.face && @mouse_ip.edge.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

            @normal = face_manipulator.normal

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            # @tool.append_3d(k_mesh)

          end

          @direction = edge_manipulator.direction
          @locked_direction = @direction

        elsif @mouse_ip.cline

          cline_manipulator = ClineManipulator.new(@mouse_ip.cline, @mouse_ip.transformation)

          if @mouse_ip.face

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.face_transformation)

            @normal = face_manipulator.normal

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            # @tool.append_3d(k_mesh)

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
          # @tool.append_3d(k_mesh)

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

      # Lock on last pull measure
      if @tool.is_key_down?(CONSTRAIN_MODIFIER_KEY) && @@last_pull_measure > 0
        measure = @@last_pull_measure
        measure /= 2 if _fetch_option_pull_centered
        @mouse_snap_point = @picked_shape_end_point.offset(@picked_shape_end_point.vector_to(@mouse_snap_point), measure) if measure > 0
      end

    end

    # -----

    def _preview_shape_start(view)
    end

    def _preview_shape(view)
    end

    def _preview_pull(view)

      if _fetch_option_pull_centered

        # Draw first picked point
        k_point = _create_floating_points(
          points: @picked_shape_start_point,
          style: Kuix::POINT_STYLE_PLUS
        )
        @tool.append_3d(k_point)

        # Draw line from first picked point to snap point
        k_edge = Kuix::EdgeMotif.new
        k_edge.start.copy!(@picked_shape_start_point)
        k_edge.end.copy!(@mouse_snap_point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        @tool.append_3d(k_edge)

      end

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)
      p3 = points[2].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p3)

      tt = Geom::Transformation.translation(p2.vector_to(p3))

      if _fetch_option_shape_offset != 0

        shape_points = _get_local_shape_points
        top_shape_points = shape_points.map { |point| point.transform(tt) }

        k_segments = Kuix::Segments.new
        k_segments.add_segments(_points_to_segments(shape_points))
        k_segments.add_segments(_points_to_segments(top_shape_points))
        k_segments.add_segments(shape_points.zip(top_shape_points).flatten(1))
        k_segments.line_width = 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

        k_segments = Kuix::Segments.new
        k_segments.add_segments(_points_to_segments(o_shape_points))
        k_segments.add_segments(_points_to_segments(o_top_shape_points))
        k_segments.add_segments(o_shape_points.zip(o_top_shape_points).flatten(1))
        k_segments.line_width = _fetch_option_construction ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      Sketchup.set_status_text(bounds.depth, SB_VCB_VALUE)

      if bounds.depth > 0

        k_label = _create_floating_label(
          snap_point: p1.project_to_plane([ bounds.min, Z_AXIS ]).offset(Z_AXIS, bounds.depth / 2).transform(t),
          text: bounds.depth,
          text_color: Kuix::COLOR_Z,
          border_color: _get_normal_color
        )
        @tool.append_2d(k_label)

      end

    end

    # -----

    def _read_offset(tool, text, view)

      if (match = /^(.+)x$/.match(text))

        value = match[1]

        begin
          offset = value.to_l
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_SHAPE_OFFSET, offset.to_s, true)
          Sketchup.set_status_text('', SB_VCB_VALUE)
          _refresh
        rescue ArgumentError
          UI.beep
          tool.notify_errors([ [ 'tool.smart_draw.error.invalid_offset', { :value => value } ] ])
        end

        return true
      end

      false
    end

    def _read_shape(tool, text, view)
      if @picked_shape_start_point == @mouse_snap_point
        UI.beep
        tool.notify_errors([ "tool.smart_draw.error.no_direction" ])
        return true
      end
      false
    end

    def _read_pull(tool, text, view)

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      points = _get_picked_points
      p2 = points[1].transform(ti)
      p3 = points[2].transform(ti)

      base_thickness = p3.z - p2.z
      thickness = _read_user_text_length(tool, text, base_thickness)
      return true if thickness.nil?
      thickness /= 2 if _fetch_option_pull_centered

      @picked_pull_end_point = Geom::Point3d.new(p2.x, p2.y, thickness).transform(t)

      _create_entity
      _restart

      Sketchup.set_status_text('', SB_VCB_VALUE)

      true
    end

    # -----

    def _fetch_option_shape_offset
      @tool.fetch_action_option_length(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_SHAPE_OFFSET)
    end

    def _fetch_option_construction
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_CONSTRUCTION)
    end

    def _fetch_option_pull_centered
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
      @picked_shape_start_point = nil
      @picked_shape_end_point = nil
      @picked_pull_end_point = nil
      @direction = nil
      @normal = _get_active_z_axis
      @locked_direction = nil
      @locked_normal = nil
      @locked_axis = nil
      super
      set_state(STATE_SHAPE_START)
    end

    def _restart
      new_action_handler = super

      @locked_direction = nil
      @locked_normal = nil
      @locked_axis = nil

      if @state == STATE_PULL && (drawing_def = _get_drawing_def).is_a?(DrawingDef) && !_fetch_option_construction
        _append_floating_tools_at(drawing_def.bounds.center.transform(drawing_def.transformation), new_action_handler)
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

    def _create_faces(definition, p1, p2)
      _get_local_shapes_points_with_offset.map { |shape_points| definition.entities.add_face(shape_points) }
    end

    def _create_entity

      model = Sketchup.active_model
      model.start_operation('Create Part', true)

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)
      p3 = points[2].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p3)

      @@last_pull_measure = bounds.depth

      if _fetch_option_construction || bounds.depth == 0

        tt = Geom::Transformation.translation(p2.vector_to(p3))

        group = model.active_entities.add_group
        group.transformation = t

        if !_fetch_option_construction

          # Flat drawing, just add to group

          faces = _create_faces(group.definition, p1, p2)
          faces.each do |face|
            face.reverse! unless face.normal.samedirection?(Z_AXIS)
          end

        else

          # Construction

          _get_local_shapes_points_with_offset.each do |o_shape_points|

            _points_to_segments(o_shape_points, true, false).each { |segment| group.entities.add_cline(*segment) }

            if bounds.depth > 0

              o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

              _points_to_segments(o_top_shape_points, true, false).each { |segment| group.entities.add_cline(*segment) }
              o_shape_points.zip(o_top_shape_points).each { |segment| group.entities.add_cline(*segment) }

            end

          end

        end

        instance = group

      else

        # Solid drawing create a component definition + instance

        definition = model.definitions.add(PLUGIN.get_i18n_string('default.part_single').capitalize)

        faces = _create_faces(definition, p1, p2)
        faces.each do |face|

          if bounds.depth > 0

            face.reverse! if face.normal.samedirection?(Z_AXIS)
            face.pushpull(bounds.depth * (p3.z < p1.z ? 1 : -1))

          else

            face.reverse! unless face.normal.samedirection?(Z_AXIS)

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

        instance = model.active_entities.add_instance(definition, t)

        # Notify part created and propose renaming
        @tool.notify_success(
          PLUGIN.get_i18n_string("tool.smart_draw.success.part_created", { :name => definition.name }),
          [
            {
              :label => PLUGIN.get_i18n_string('default.rename'),
              :block => lambda {
                if (data = UI.inputbox([ PLUGIN.get_i18n_string('tab.cutlist.edit_part.name') ], [ definition.name ], PLUGIN.get_i18n_string('default.rename')))
                  name = data.first
                  if name.empty?
                    UI.beep
                  else
                    definition.name = name
                  end
                end
              },
            }
          ]
        )

      end

      model.commit_operation

      # Keep definition
      @definition = instance.definition

      # Reset DrawingDef
      @drawing_def = nil

    end

    # --

    def _get_instance
      return nil if @definition.nil? || @definition.deleted?
      @definition.instances.first
    end

    def _get_drawing_def
      return nil if @definition.nil?
      return @drawing_def unless @drawing_def.nil?

      model = Sketchup.active_model
      return nil if model.nil?

      instance = _get_instance
      instance_path = (model.active_path.nil? ? [] : model.active_path) + [ instance ]

      @drawing_def = CommonDrawingDecompositionWorker.new(instance_path,
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

    def _get_auto_orient_transformation(definition, transformation = IDENTITY)

      largest_face, inner_path = _find_largest_face(definition, transformation)
      unless largest_face.nil?

        longest_edge = _find_longest_outer_edge(largest_face, transformation)
        unless longest_edge.nil?

          face_manipulator = FaceManipulator.new(largest_face)  # Should not be nested in subgroups : no inner transformation
          edge_manipulator = EdgeManipulator.new(longest_edge)

          z_axis = face_manipulator.normal
          x_axis = edge_manipulator.direction
          y_axis = z_axis * x_axis

          return Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
        end

      end

      IDENTITY
    end

    # --

    def _append_floating_tools_at(position, callback_action_handler)

      unit = @tool.get_unit

      tool_defs = [
        {
          path: 'M0,0.667L0.333,0.667L0.333,1L0,1L0,0.667 M0.667,0L1,0L1,0.333L0.667,0.333L0.667,0 M0.417,0.583L0.583,0.417',
          block: lambda {
            Sketchup.active_model.tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_COPY_LINE,
              callback_action_handler: callback_action_handler
            ))
          }
        },
        {
          path: 'M0.333,0.667L0,0.667L0,1L0.333,1L0.333,0.667 M1,0.667L0.667,0.667L0.667,1L1,1L1,0.667 M0.333,0L0,0L0,0.333L0.333,0.333L0.333,0 M1,0L0.667,0L0.667,0.333L1,0.333L1,0 M0.167,0.417L0.167,0.583 M0.417,0.833L0.583,0.833',
          block: lambda {
            Sketchup.active_model.tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_COPY_GRID,
              callback_action_handler: callback_action_handler
            ))
          }
        },
        {
          path: 'M0.666,0L1,0L1,0.334L0.666,0.334L0.666,0M0.083,0.917L0.583,0.417',
          block: lambda {
            Sketchup.active_model.tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_MOVE_LINE,
              callback_action_handler: callback_action_handler
            ))
          }
        },
        {
          path: 'M0.333,0.333L0.667,0.333L0.667,0.667L0.333,0.667L0.333,0.333 M0.083,0.917L0.25,0.75 M0.75,0.25L0.917,0.083',
          block: lambda {
            Sketchup.active_model.tools.push_tool(SmartHandleTool.new(
              current_action: SmartHandleTool::ACTION_DISTRIBUTE,
              callback_action_handler: callback_action_handler
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
          Sketchup.active_model.selection.clear
          Sketchup.active_model.selection.add(_get_instance)
        end
        k_btn.on(:leave) do
          Sketchup.active_model.selection.clear
        end
        k_btn.on(:click) do
          # k_panel.remove
          tool_def[:block].call
        end
        k_panel.append(k_btn)

        k_motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path(tool_def[:path]))
        k_motif.min_size.set_all!(unit * 4)
        k_motif.set_style_attribute(:color, Kuix::COLOR_BLACK)
        k_motif.set_style_attribute(:color, Kuix::COLOR_WHITE, :active)
        k_btn.append(k_motif)

      end

    end

    def _remove_floating_tools
      @tool.remove_2d(LAYER_2D_FLOATING_TOOLS)
    end

    # -- UTILS --

    def _points_to_segments(points, closed = true, flatten = true)
      segments = points.each_cons(2).to_a
      segments << [ points.last, points.first ] if closed && !points.empty?
      segments.flatten!(1) if flatten
      segments
    end

  end

  class SmartDrawRectangleActionHandler < SmartDrawActionHandler

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

    # -----

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE_START, STATE_SHAPE
        if key == COPY_MODIFIER_KEY && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, !_fetch_option_rectangle_centered, true)
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
          # @tool.append_3d(k_points)
          #
          # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
          #
          #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          #   @tool.append_3d(k_mesh)
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
          # @tool.append_3d(k_points)
          #
          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(edge_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments)

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
          # @tool.append_3d(k_points)
          #
          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(cline_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments)

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
            # @tool.append_3d(k_points)

            plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
            plane_manipulator = PlaneManipulator.new(plane)

            @direction = _get_active_z_axis if @locked_direction.nil?
            @normal = plane_manipulator.normal

            @mouse_snap_point = @mouse_ip.position

          end

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(face_manipulator.triangles)
          # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
          # @tool.append_3d(k_mesh)

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
            # @tool.append_3d(k_points)

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

      width = view.pixels_to_model(40, @mouse_snap_point)
      height = width / 2

      shape_offset = _fetch_option_shape_offset
      if shape_offset > 0
        offset = width * 0.1
      elsif shape_offset < 0
        offset = width * -0.1
      else
        offset = 0
      end

      if offset != 0

        k_rectangle = Kuix::RectangleMotif.new
        k_rectangle.bounds.size.set!(width, height)
        k_rectangle.line_width = 1
        k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_rectangle.color = _get_normal_color
        k_rectangle.on_top = true
        k_rectangle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
        k_rectangle.transformation *= Geom::Transformation.translation(Geom::Vector3d.new(-width / 2, -height / 2)) if _fetch_option_rectangle_centered
        @tool.append_3d(k_rectangle)

      end

      k_rectangle = Kuix::RectangleMotif.new
      k_rectangle.bounds.origin.set!(-offset, -offset)
      k_rectangle.bounds.size.set!(width + 2 * offset, height + 2 * offset)
      k_rectangle.line_width = @locked_normal ? 3 : 1.5
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_rectangle.color = _get_normal_color
      k_rectangle.on_top = true
      k_rectangle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
      k_rectangle.transformation *= Geom::Transformation.translation(Geom::Vector3d.new(-width / 2, -height / 2)) if _fetch_option_rectangle_centered
      @tool.append_3d(k_rectangle)

    end

    def _preview_shape(view)

      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse

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
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_segments = _points_to_segments(o_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(o_segments)
        k_segments.line_width = @locked_normal ? 3 : _fetch_option_construction ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      Sketchup.set_status_text("#{bounds.width}#{Sketchup::RegionalSettings.list_separator} #{bounds.height}", SB_VCB_VALUE)

      if bounds.valid?

        if bounds.width == bounds.height && bounds.width != 0

          k_edge = Kuix::EdgeMotif.new
          k_edge.start.copy!(_fetch_option_rectangle_centered ? @picked_shape_start_point.offset(@mouse_snap_point.vector_to(@picked_shape_start_point)) : @picked_shape_start_point)
          k_edge.end.copy!(@mouse_snap_point)
          k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          k_edge.color = _get_normal_color
          @tool.append_3d(k_edge)

        end

        if _fetch_option_rectangle_centered

          k_points = _create_floating_points(
            points: @picked_shape_start_point,
            style: Kuix::POINT_STYLE_PLUS
          )
          @tool.append_3d(k_points)

          if bounds.width != bounds.height

            k_edge = Kuix::EdgeMotif.new
            k_edge.start.copy!(@picked_shape_start_point)
            k_edge.end.copy!(@mouse_snap_point)
            k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            @tool.append_3d(k_edge)

          end

        end

        if view.pixels_to_model(30, bounds.min) < bounds.min.distance(bounds.max)

          if bounds.width != 0

            k_label = _create_floating_label(
              snap_point: bounds.min.offset(X_AXIS, bounds.width / 2).transform(t),
              text: bounds.width,
              text_color: Kuix::COLOR_X,
              border_color: _get_normal_color
            )
            @tool.append_2d(k_label)

          end

          if bounds.height != 0

            k_label = _create_floating_label(
              snap_point: bounds.min.offset(Y_AXIS, bounds.height / 2).transform(t),
              text: bounds.height,
              text_color: Kuix::COLOR_Y,
              border_color: _get_normal_color
            )
            @tool.append_2d(k_label)

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

        rectangle_centred = _fetch_option_rectangle_centered

        base_length = p2.x - p1.x
        base_length *= 2 if rectangle_centred
        length = _read_user_text_length(tool, d1, base_length)
        return true if length.nil?
        length = length / 2 if rectangle_centred

        base_width = p2.y - p1.y
        base_width *= 2 if rectangle_centred
        width = _read_user_text_length(tool, d2, base_width)
        return true if width.nil?
        width = width / 2 if rectangle_centred

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
        thickness = thickness / 2 if _fetch_option_pull_centered

        @picked_pull_end_point = Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t)

        _create_entity
        _restart

        return true
      end

      true
    end

    # -----

    def _fetch_option_rectangle_centered
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED)
    end

    # -----

    def get_state_vcb_label(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string('tool.default.vcb_size')

      end

      super
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

      if _fetch_option_rectangle_centered && _picked_shape_start_point? && points.length > 1
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

  class SmartDrawCircleActionHandler < SmartDrawActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_CIRCLE, tool, previous_action_handler)
    end

    # -----

    def get_state_status(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string("tool.smart_draw.action_#{@action}_state_1_#{_fetch_option_measure_from_diameter ? 'diameter' : 'radius'}_status") + '.' +
          ' | ' + PLUGIN.get_i18n_string("default.copy_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_draw.action_option_options_measure_from_#{_fetch_option_measure_from_diameter ? 'radius' : 'diameter'}_status") + '.'

      end

      super
    end

    def get_state_vcb_label(state)

      case state

      when STATE_SHAPE
        return PLUGIN.get_i18n_string("tool.default.vcb_#{_fetch_option_measure_from_diameter ? 'diameter' : 'radius'}")

      end

      super
    end

    # -----

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE_START, STATE_SHAPE
        if key == COPY_MODIFIER_KEY && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_FROM_DIAMETER, !_fetch_option_measure_from_diameter, true)
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

      super
    end

    # -----

    def _preview_shape_start(view)

      diameter = view.pixels_to_model(40, @mouse_snap_point)

      shape_offset = _fetch_option_shape_offset
      if shape_offset > 0
        offset = diameter * 0.2
      elsif shape_offset < 0
        offset = diameter * -0.2
      else
        offset = 0
      end

      if offset != 0

        k_circle = Kuix::CircleMotif.new(_fetch_option_segment_count)
        k_circle.bounds.size.set_all!(diameter)
        k_circle.line_width = 1
        k_circle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_circle.color = _get_normal_color
        k_circle.on_top = true
        k_circle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation * Geom::Transformation.translation(Geom::Vector3d.new(-diameter / 2, -diameter / 2))
        @tool.append_3d(k_circle)

      end

      k_circle = Kuix::CircleMotif.new(_fetch_option_segment_count)
      k_circle.bounds.size.set_all!(diameter + offset)
      k_circle.line_width = @locked_normal ? 3 : 1.5
      k_circle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_circle.color = _get_normal_color
      k_circle.on_top = true
      k_circle.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation * Geom::Transformation.translation(Geom::Vector3d.new(-(diameter + offset) / 2, -(diameter + offset) / 2))
      @tool.append_3d(k_circle)

    end

    def _preview_shape(view)

      measure_start = _fetch_option_measure_from_diameter ? @picked_shape_start_point.offset(@mouse_snap_point.vector_to(@picked_shape_start_point)) : @picked_shape_start_point
      measure_vector = measure_start.vector_to(@mouse_snap_point)
      measure = measure_vector.length

      k_points = _create_floating_points(
        points: @picked_shape_start_point,
        style: Kuix::POINT_STYLE_PLUS
      )
      @tool.append_3d(k_points)

      k_edge = Kuix::EdgeMotif.new
      k_edge.start.copy!(measure_start)
      k_edge.end.copy!(@mouse_snap_point)
      k_edge.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      k_edge.color = _get_direction_color
      @tool.append_3d(k_edge)

      t = _get_transformation(@picked_shape_start_point)

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 1.1
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_segments = _points_to_segments(o_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(o_segments)
        k_segments.line_width = @locked_normal ? 3 : _fetch_option_construction ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      Sketchup.set_status_text("#{measure}", SB_VCB_VALUE)

      if measure > 0 && view.pixels_to_model(30, measure_start) < measure

        k_label = _create_floating_label(
          snap_point: measure_start.offset(measure_vector, measure / 2),
          text: measure,
          text_color: Kuix::COLOR_X,
          border_color: _get_direction_color
        )
        @tool.append_2d(k_label)

      end

    end

    # -----

    def _read_shape(tool, text, view)
      return true if super

      d1, d2 = _split_user_text(text)

      if d1

        measure_start = _fetch_option_measure_from_diameter ? @picked_shape_start_point.offset(@mouse_snap_point.vector_to(@picked_shape_start_point)) : @picked_shape_start_point
        measure_vector = measure_start.vector_to(@mouse_snap_point)
        measure = measure_vector.length
        measure = _read_user_text_length(tool, d1, measure)
        return true if measure.nil?

        @picked_shape_end_point = @picked_shape_start_point.offset(measure_vector, _fetch_option_measure_from_diameter ? measure / 2.0 : measure)

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
      if (match = /^(.+)s$/.match(text))

        value = match[1]
        segment_count = value.to_i

        if segment_count < 3 || segment_count > 999
          UI.beep
          @tool.notify_errors([ [ 'tool.smart_draw.error.invalid_segment_count', { :value => value } ] ])
          return true
        end

        @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_SEGMENTS, SmartDrawTool::ACTION_OPTION_SEGMENTS_SEGMENT_COUNT, segment_count, true)
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

    def _fetch_option_smoothed
      @tool.fetch_action_option_boolean(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_SMOOTHING)
    end

    def _fetch_option_measure_from_diameter
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

    def _create_faces(definition, p1, p2)
      if _fetch_option_smoothed
        edge = definition.entities.add_circle(p1, Z_AXIS, p1.distance(p2) + _fetch_option_shape_offset, _fetch_option_segment_count).first
      else
        edge = definition.entities.add_ngon(p1, Z_AXIS, p1.distance(p2) + _fetch_option_shape_offset, _fetch_option_segment_count).first
      end
      edge.find_faces
      edge.faces
    end

    def _get_auto_orient_transformation(definition, transformation = IDENTITY)
      # TODO only if elevation > diameter
      Geom::Transformation.axes(ORIGIN, Z_AXIS, Y_AXIS.reverse, X_AXIS) # Set length (X axis) along elevation
    end

  end

  class SmartDrawPolygonActionHandler < SmartDrawActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartDrawTool::ACTION_DRAW_POLYGON, tool, previous_action_handler)

      @picked_points = []         # Geometry ordered
      @picked_points_stack = []   # Pick ordered

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
        return super                              # 2. Process auto pull if possible

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
            p = _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(x_axis)))
          end
          _refresh
          return true
        elsif key == VK_LEFT
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
            p = _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(y_axis)))
          end
          _refresh
          return true
        elsif key == VK_UP
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
            p = _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(z_axis)))
          end
          _refresh
          return true
        elsif key == VK_DOWN
          UI.beep
          return true
        end

      end

      super
    end

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)

      case @state

      when STATE_SHAPE_START, STATE_SHAPE
        if key == COPY_MODIFIER_KEY && is_quick
          @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_MEASURE_REVERSED, !_fetch_option_measure_reversed, true)
          Sketchup.set_status_text(get_state_status(fetch_state), SB_PROMPT)
          Sketchup.set_status_text(get_state_vcb_label(fetch_state), SB_VCB_LABEL)
          if view.inference_locked?
            p = _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last
            view.lock_inference(Sketchup::InputPoint.new(p), Sketchup::InputPoint.new(p.offset(@locked_axis)))
          end
          _refresh
          return true
        end

      end

      super
    end

    protected

    def _add_picked_point(point, view)

      if _fetch_option_measure_reversed
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
          if ph.test_point(point)

            k_points = _create_floating_points(
              points: point,
              style: Kuix::POINT_STYLE_SQUARE,
              fill_color: Kuix::COLOR_BLACK,
              stroke_color: Kuix::COLOR_WHITE
            )
            @tool.append_3d(k_points)

            if @locked_axis
              @mouse_snap_point = point.project_to_line([ _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last , @locked_axis ])
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
            # @tool.append_3d(k_points)
            #
            # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
            #
            #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
            #
            #   k_mesh = Kuix::Mesh.new
            #   k_mesh.add_triangles(face_manipulator.triangles)
            #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            #   @tool.append_3d(k_mesh)
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
            # @tool.append_3d(k_points)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(edge_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @tool.append_3d(k_segments)

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
            # @tool.append_3d(k_points)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(cline_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @tool.append_3d(k_segments)

          end

        elsif @mouse_ip.face && @mouse_ip.degrees_of_freedom == 2

          if @locked_normal

            locked_plane = [ @picked_shape_start_point, @locked_normal ]

            @mouse_snap_point = @mouse_ip.position.project_to_plane(locked_plane)
            @normal = @locked_normal

          else

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

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
              # @tool.append_3d(k_points)

              plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
              plane_manipulator = PlaneManipulator.new(plane)

              @direction = _get_active_z_axis
              @normal = plane_manipulator.normal

            end

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
            # @tool.append_3d(k_mesh)

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
              # @tool.append_3d(k_points)

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
    end

    # -----

    def _preview_shape_start(view)

      width = view.pixels_to_model(40, @mouse_snap_point)
      height = width / 2

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
        k_motif.color = _get_normal_color
        k_motif.on_top = true
        k_motif.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
        @tool.append_3d(k_motif)

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
      k_motif.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_motif.color = _get_normal_color
      k_motif.on_top = true
      k_motif.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*@mouse_snap_point.to_a)) * _get_transformation
      @tool.append_3d(k_motif)

    end

    def _preview_shape(view)

      t = _get_transformation(@picked_shape_start_point)

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      _get_local_shapes_points_with_offset.each do |o_shape_points|

        o_segments = _points_to_segments(o_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(o_segments)
        k_segments.line_width = @locked_normal ? 3 : _fetch_option_construction ? 1 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES if _fetch_option_construction
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      if @picked_points.length >= 1

        measure_start = _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last
        measure_vector = measure_start.vector_to(@mouse_snap_point)
        measure = measure_vector.length

        Sketchup.set_status_text("#{measure}", SB_VCB_VALUE)

        k_points = _create_floating_points(
          points: measure_start,
          style: Kuix::POINT_STYLE_PLUS
        )
        @tool.append_3d(k_points)

        if measure_vector.valid?

          k_line = Kuix::Line.new
          k_line.position = measure_start
          k_line.direction = measure_vector
          k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
          k_line.color = _get_vector_color(measure_vector, Kuix::COLOR_DARK_GREY)
          @tool.append_3d(k_line)

          k_segments = Kuix::Segments.new
          k_segments.add_segments([ measure_start, @mouse_snap_point ])
          k_segments.line_width = @locked_axis ? 3 : _fetch_option_construction ? 1 : 1.5
          k_segments.line_stipple = _fetch_option_shape_offset != 0 ? Kuix::LINE_STIPPLE_DOTTED : (_fetch_option_construction ? Kuix::LINE_STIPPLE_LONG_DASHES : Kuix::LINE_STIPPLE_SOLID)
          k_segments.color = _get_vector_color(@locked_axis, _get_normal_color)
          k_segments.on_top = true
          @tool.append_3d(k_segments)

          if view.pixels_to_model(60, measure_start) < measure

            k_label = _create_floating_label(
              snap_point: measure_start.offset(measure_vector, measure / 2),
              text: measure,
              border_color: _get_normal_color
            )
            @tool.append_2d(k_label)

          end

        end

      end

    end

    # -----

    def _read_shape(tool, text, view)
      return true if super

      measure_start = _fetch_option_measure_reversed ? @picked_points.first : @picked_points.last
      measure_vector = measure_start.vector_to(@mouse_snap_point)
      measure = measure_vector.length
      measure = _read_user_text_length(tool, text, measure)
      return true if measure.nil?

      _add_picked_point(measure_start.offset(measure_vector, measure), view)
      _refresh

      true
    end

    # -----

    def _fetch_option_measure_reversed
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
      Sketchup::InputPoint.new(_fetch_option_measure_reversed ? @picked_points.first : @picked_points.last)
    end

    # -----

    def _get_local_shape_points
      t = _get_transformation(@picked_shape_start_point)
      ti = t.inverse
      if _picked_shape_end_point?
        points = @picked_points.map { |point| point.transform(ti) }

        if _fetch_option_pull_centered
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
    end

  end

end