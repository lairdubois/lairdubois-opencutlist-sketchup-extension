module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'
  require_relative '../lib/geometrix/finder/circle_finder'
  require_relative '../lib/fiddle/clippy/clippy'

  class SmartDrawTool < SmartTool

    ACTION_DRAW_RECTANGLE = 0
    ACTION_DRAW_CIRCLE = 1
    ACTION_DRAW_POLYGON = 2

    ACTION_OPTION_TOOLS = 'tools'
    ACTION_OPTION_OFFSET = 'offset'
    ACTION_OPTION_SEGMENTS = 'segments'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_TOOLS_PUSHPULL = 'pushpull'
    ACTION_OPTION_TOOLS_MOVE = 'move'

    ACTION_OPTION_OFFSET_SHAPE_OFFSET = 'shape_offset'

    ACTION_OPTION_SEGMENTS_SEGMENT_COUNT = 'segment_count'

    ACTION_OPTION_OPTIONS_CONSTRUCTION = 'construction'
    ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED = 'rectangle_centered'
    ACTION_OPTION_OPTIONS_BOX_CENTRED = 'box_centered'

    ACTIONS = [
      {
        :action => ACTION_DRAW_RECTANGLE,
        :options => {
          ACTION_OPTION_TOOLS => [ ACTION_OPTION_TOOLS_PUSHPULL, ACTION_OPTION_TOOLS_MOVE ],
          ACTION_OPTION_OFFSET => [ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, ACTION_OPTION_OPTIONS_BOX_CENTRED ],
        }
      },
      {
        :action => ACTION_DRAW_CIRCLE,
        :options => {
          ACTION_OPTION_TOOLS => [ ACTION_OPTION_TOOLS_PUSHPULL, ACTION_OPTION_TOOLS_MOVE ],
          ACTION_OPTION_OFFSET => [ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_SEGMENTS => [ ACTION_OPTION_SEGMENTS_SEGMENT_COUNT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_BOX_CENTRED ],
        }
      },
      {
        :action => ACTION_DRAW_POLYGON,
        :options => {
          ACTION_OPTION_TOOLS => [ ACTION_OPTION_TOOLS_PUSHPULL, ACTION_OPTION_TOOLS_MOVE ],
          ACTION_OPTION_OFFSET => [ACTION_OPTION_OFFSET_SHAPE_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_BOX_CENTRED ],
        }
      }
    ].freeze

    CURSOR_PENCIL = 632
    CURSOR_RECTANGLE = 637
    CURSOR_PUSHPULL = 639
    CURSOR_MOVE = 641
    CURSOR_MOVE_COPY = 642

    # -----

    def initialize
      super
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
          return CURSOR_RECTANGLE
      when ACTION_DRAW_CIRCLE
          return CURSOR_RECTANGLE
      when ACTION_DRAW_POLYGON
          return CURSOR_PENCIL
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
      when ACTION_OPTION_TOOLS
        case option
        when ACTION_OPTION_TOOLS_PUSHPULL
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.611L0,0.778L0.5,1L1,0.778L1,0.611 M0.333,0.5L0,0.611L0.5,0.778L1,0.611L0.667,0.5 M0.583,0.583L0.583,0.333L0.75,0.333L0.5,0L0.25,0.333L0.417,0.333L0.417,0.583L0.583,0.583'))
        when ACTION_OPTION_TOOLS_MOVE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0.357L0.5,0 M0.357,0.143L0.5,0L0.643,0.143 M0.643,0.5L1,0.5 M0.857,0.357L1,0.5L0.857,0.643 M0.357,0.5L0,0.5 M0.143,0.357L0,0.5L0.143,0.643 M0.5,0.643L0.5,1 M0.357,0.857L0.5,1L0.643,0.857'))
        end
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SHAPE_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option))
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
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L1,0L1,1L0,1L0,0 M0.5,0.667L0.5,0.333 M0.333,0.5L0.667,0.5 '))
        when ACTION_OPTION_OPTIONS_BOX_CENTRED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,1L0.667,1L1,0.667L1,0L0.333,0L0,0.333L0,1 M0,0.333L0.667,0.333L0.667,1 M0.667,0.333L1,0 M0.333,0.5L0.333,0.833 M0.167,0.667L0.5,0.667'))
        end
      end

      super
    end

    def is_action_draw_rectangle?
      fetch_action == ACTION_DRAW_RECTANGLE
    end

    def is_action_draw_circle?
      fetch_action == ACTION_DRAW_CIRCLE
    end

    def is_action_draw_polygon?
      fetch_action == ACTION_DRAW_POLYGON
    end

    # -- Events --

    def onActivate(view)
      @action_handler = nil
      super
    end

    def onResume(view)
      refresh
    end

    def onCancel(reason, view)
      return @action_handler.onCancel(reason, view) if !@action_handler.nil? && @action_handler.respond_to?(:onCancel)
      super
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      @action_handler.onMouseMove(flags, x, y, view) if !@action_handler.nil? && @action_handler.respond_to?(:onMouseMove)
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      @action_handler.onLButtonDown(flags, x, y, view) if !@action_handler.nil? && @action_handler.respond_to?(:onLButtonDown)
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      @action_handler.onLButtonUp(flags, x, y, view) if !@action_handler.nil? && @action_handler.respond_to?(:onLButtonUp)
    end

    def onLButtonDoubleClick(flags, x, y, view)
      return true if super
      @action_handler.onLButtonDoubleClick(flags, x, y, view) if !@action_handler.nil? && @action_handler.respond_to?(:onLButtonDoubleClick)
    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      @action_handler.onKeyDown(key, repeat, flags, view) if !@action_handler.nil? && @action_handler.respond_to?(:onKeyDown)
    end

    def onKeyUp(key, repeat, flags, view)
      return true if super
      @action_handler.onKeyUp(key, repeat, flags, view) if !@action_handler.nil? && @action_handler.respond_to?(:onKeyUp)
    end

    def onUserText(text, view)
      @action_handler.onUserText(text, view) if !@action_handler.nil? && @action_handler.respond_to?(:onUserText)
    end

    def onActionChanged(action)

      case action
      when ACTION_DRAW_RECTANGLE
        @action_handler = SmartDrawRectangleActionHandler.new(self)
      when ACTION_DRAW_CIRCLE
        @action_handler = SmartDrawCircleActionHandler.new(self)
      when ACTION_DRAW_POLYGON
        @action_handler = SmartDrawPolygonActionHandler.new(self)
      end

      super

      refresh

    end

    def draw(view)
      super
      @action_handler.draw(view) unless @action_handler.nil? && @action_handler.respond_to?(:draw)
    end

    def enableVCB?
      return @action_handler.enableVCB? unless @action_handler.nil? && @action_handler.respond_to?(:enableVCB?)
      false
    end

    def getExtents
      return @action_handler.getExtents unless @action_handler.nil? && @action_handler.respond_to?(:getExtents)
      super
    end

    # -----

    def remove_all_3d
      @space.remove_all
    end

    def append_3d(entity)
      @space.append(entity)
    end

    def remove_all_2d
      @floating_panel.remove_all
    end

    def append_2d(entity)
      @floating_panel.append(entity)
    end

    # -----

    def refresh
      onMouseMove(0, @last_mouse_x, @last_mouse_y, Sketchup.active_model.active_view)
    end

  end

  # -----

  class SmartDrawActionHandler < SmartActionHandler

    def initialize(action, tool)
      super

      @mouse_ip = Sketchup::InputPoint.new
      @down_ip = Sketchup::InputPoint.new
      @snap_ip = Sketchup::InputPoint.new
      @picked_shape_first_ip = Sketchup::InputPoint.new
      @picked_shape_last_ip = Sketchup::InputPoint.new
      @picked_pushpull_ip = Sketchup::InputPoint.new
      @picked_move_ip = Sketchup::InputPoint.new

      @locked_normal = nil
      @locked_axis = nil

      @direction = nil
      @normal = _get_active_z_axis

    end

    def onCancel(reason, view)
      if _picked_pushpull_point?
        @picked_pushpull_ip.clear
        _reset
      elsif _picked_shape_last_point?
        @picked_shape_last_ip.clear
        @tool.pop_cursor
      elsif _picked_shape_first_point?
        @picked_shape_first_ip.clear
      else
        _reset
      end
      _refresh
    end

    def onMouseMove(flags, x, y, view)

      @snap_ip.clear
      @mouse_ip.pick(view, x, y)

      SKETCHUP_CONSOLE.clear
      puts "---"
      puts "vertex = #{@mouse_ip.vertex}"
      puts "edge = #{@mouse_ip.edge}"
      puts "face = #{@mouse_ip.face}"
      puts "instance_path.length = #{@mouse_ip.instance_path.length}"
      puts "transformation.identity? = #{@mouse_ip.transformation.identity?}"
      puts "degrees_of_freedom = #{@mouse_ip.degrees_of_freedom}"
      puts "view.inference_locked? = #{view.inference_locked?}"
      puts "@down_ip.valid? = #{@down_ip.valid?}"
      puts "---"

      @tool.remove_all_3d
      @tool.remove_all_2d

      Sketchup.vcb_value = ''

      if _picked_pushpull_point?
        _snap_move_point(flags, x, y, view)
        _preview_move(view)
      elsif _picked_shape_last_point?
        _snap_pushpull_point(flags, x, y, view)
        _preview_pushpull(view)
      elsif _picked_shape_first_point?
        _snap_shape_points(flags, x, y, view)
        _preview_shape(view)
      else
        _snap_first_shape_point(flags, x, y, view)
        _preview_first_point(view)
        if @snap_ip.position.distance(@down_ip.position) > view.pixels_to_model(10, @snap_ip.position)  # Drag handled only if distance is > 10px
          @picked_shape_first_ip.copy!(@down_ip)
          @down_ip.clear
        end
      end

      # k_points = Kuix::Points.new
      # k_points.add_point(@snap_ip.position)
      # k_points.size = 30
      # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
      # k_points.color = Kuix::COLOR_YELLOW
      # @tool.append_3d(k_points)

      # k_axes_helper = Kuix::AxesHelper.new
      # k_axes_helper.transformation = Geom::Transformation.axes(@picked_shape_first_ip.position, *_get_axes)
      # @tool.append_3d(k_axes_helper)

      view.tooltip = @snap_ip.tooltip if @snap_ip.valid?
      view.invalidate

    end

    def onLButtonDown(flags, x, y, view)
      @down_ip.copy!(@snap_ip)
    end

    def onLButtonUp(flags, x, y, view)

      if !_picked_shape_first_point?
        @picked_shape_first_ip.copy!(@down_ip)
        @down_ip.clear
        _refresh
      elsif !_picked_shape_last_point?
        if _valid_shape?
          @picked_shape_last_ip.copy!(@snap_ip)
          if _fetch_option_tool_pushpull
            @tool.push_cursor(SmartDrawTool::CURSOR_PUSHPULL)
            _refresh
          else
            if _fetch_option_tool_move
              @picked_pushpull_ip.copy!(@snap_ip)
              _create_entity
              @tool.push_cursor(SmartDrawTool::CURSOR_MOVE)
              _refresh
            else
              _create_entity
              _reset
            end
          end
        else
          UI.beep
        end
      elsif !_picked_pushpull_point?
        if _valid_solid?
          @picked_pushpull_ip.copy!(@snap_ip)
          _create_entity
          if _fetch_option_tool_move
            @tool.push_cursor(SmartDrawTool::CURSOR_MOVE)
            _refresh
          else
            _reset
          end
        else
          UI.beep
        end
      elsif !_picked_move_point?
        @picked_move_ip.copy!(@snap_ip)
        _copy_entity
        _reset
      else
        UI.beep
      end

      @down_ip.clear

      view.lock_inference if view.inference_locked?
      @locked_axis = nil unless @locked_axis.nil?

    end

    def onLButtonDoubleClick(flags, x, y, view)
    end

    def onKeyDown(key, repeat, flags, view)

      if _picked_pushpull_point?
        if key == VK_RIGHT
          x_axis = _get_active_x_axis
          if @locked_axis == x_axis
            @locked_axis = nil
            view.lock_inference
          else
            @locked_axis = x_axis
            view.lock_inference(@picked_pushpull_ip, Sketchup::InputPoint.new(@picked_pushpull_ip.position.offset(x_axis)))
          end
          _refresh
        elsif key == VK_LEFT
          y_axis = _get_active_y_axis
          if @locked_axis == y_axis
            @locked_axis = nil
            view.lock_inference
          else
            @locked_axis = y_axis
            view.lock_inference(@picked_pushpull_ip, Sketchup::InputPoint.new(@picked_pushpull_ip.position.offset(y_axis)))
          end
          _refresh
        elsif key == VK_UP
          z_axis = _get_active_z_axis
          if @locked_axis == z_axis
            @locked_axis = nil
            view.lock_inference
          else
            @locked_axis = z_axis
            view.lock_inference(@picked_pushpull_ip, Sketchup::InputPoint.new(@picked_pushpull_ip.position.offset(z_axis)))
          end
          _refresh
        end
      else
        if key == VK_RIGHT
          x_axis = _get_active_x_axis
          if @locked_normal == x_axis
            @locked_normal = nil
          else
            @locked_normal = x_axis
          end
          _refresh
        elsif key == VK_LEFT
          y_axis = _get_active_y_axis
          if @locked_normal == y_axis
            @locked_normal = nil
          else
            @locked_normal = y_axis
          end
          _refresh
        elsif key == VK_UP
          z_axis = _get_active_z_axis
          if @locked_normal == z_axis
            @locked_normal = nil
          else
            @locked_normal = z_axis
          end
          _refresh
        elsif key == VK_DOWN
          if @locked_normal
            @locked_normal = nil
          else
            @locked_normal = @normal
          end
          _refresh
        end
      end

    end

    def onKeyUp(key, repeat, flags, view)

      if key == VK_ALT
        @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_BOX_CENTRED, !_fetch_option_box_centered, true) if _picked_shape_first_point? && _picked_shape_last_point? && !_picked_pushpull_point?
        _refresh
      end

    end

    def onUserText(text, view)

      if text.end_with?('o')

        offset = text.to_i
        @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_SHAPE_OFFSET, offset, true)
        _refresh

        return true
      elsif _picked_pushpull_point?

        distance = text.to_l

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p3 = points[2].transform(ti)
        p4 = points[3].transform(ti)

        v = p3.vector_to(p4)

        distance = v.length if distance == 0

        @picked_move_ip = Sketchup::InputPoint.new(p3.offset(v, distance).transform(t))

        _copy_entity
        _reset

        Sketchup.vcb_value = ''

        return true
      elsif _picked_shape_last_point?

        thickness = text.to_l

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p2 = points[1].transform(ti)
        p3 = points[2].transform(ti)

        if thickness == 0
          thickness = p3.z - p2.z
        else
          thickness *= -1 if p3.z < p2.z
          thickness /= 2 if _fetch_option_box_centered
        end

        @picked_pushpull_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, thickness).transform(t))

        _create_entity

        if _fetch_option_tool_move
          @tool.push_cursor(SmartDrawTool::CURSOR_MOVE)
          _refresh
        else
          _reset
        end

        Sketchup.vcb_value = ''

        return true
      end

      false
    end

    def draw(view)
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    def enableVCB?
      true
    end

    def getExtents
      Sketchup.active_model.bounds
    end

    protected

    def _picked_shape_first_point?
      @picked_shape_first_ip.valid?
    end

    def _picked_shape_last_point?
      @picked_shape_last_ip.valid?
    end

    def _picked_pushpull_point?
      @picked_pushpull_ip.valid?
    end

    def _picked_move_point?
      @picked_move_ip.valid?
    end

    # -----

    def _snap_first_shape_point(flags, x, y, view)

      if @mouse_ip.vertex

        vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)

        # k_points = Kuix::Points.new
        # k_points.add_points([ vertex_manipulator.point ])
        # k_points.size = 30
        # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
        # k_points.color = Kuix::COLOR_MAGENTA
        # @tool.append_3d(k_points)

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

        # edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)
        #
        # k_segments = Kuix::Segments.new
        # k_segments.add_segments(edge_manipulator.segment)
        # k_segments.color = Kuix::COLOR_MAGENTA
        # k_segments.line_width = 4
        # k_segments.on_top = true
        # @tool.append_3d(k_segments)

        if @mouse_ip.face && @mouse_ip.edge.faces.include?(@mouse_ip.face)

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

          @normal = face_manipulator.normal

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(face_manipulator.triangles)
          # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          # @tool.append_3d(k_mesh)

        end

      elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

        face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

        @normal = face_manipulator.normal

        # k_mesh = Kuix::Mesh.new
        # k_mesh.add_triangles(face_manipulator.triangles)
        # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
        # @tool.append_3d(k_mesh)

      elsif @locked_normal.nil?

        @direction = nil
        @normal = _get_active_z_axis

      end

      @snap_ip.copy!(@mouse_ip) unless @snap_ip.valid?

    end

    def _snap_shape_points(flags, x, y, view)

      @snap_ip.copy!(@mouse_ip) unless @snap_ip.valid?

    end

    def _snap_pushpull_point(flags, x, y, view)

      if @mouse_ip.degrees_of_freedom > 2 ||
        @mouse_ip.instance_path.length == 0 ||
        @mouse_ip.position.on_plane?([@picked_shape_last_ip.position, @normal ]) ||
        @mouse_ip.face && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(@normal) ||
        @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(@normal)

        picked_point, _ = Geom::closest_points([@picked_shape_last_ip.position, @normal ], view.pickray(x, y))
        @snap_ip = Sketchup::InputPoint.new(picked_point)
        @mouse_ip.copy!(@snap_ip) # Set display? to false

      else

        # Force picked point to be projected to shape last picked point normal line
        @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_line([@picked_shape_last_ip.position, @normal ]))

      end

    end

    def _snap_move_point(flags, x, y, view)

      @snap_ip.copy!(@mouse_ip)

    end

    # -----

    def _preview_first_point(view)
    end

    def _preview_shape(view)
    end

    def _preview_pushpull(view)

      if _fetch_option_box_centered

        # Draw first picked point
        k_points = Kuix::Points.new
        k_points.add_point(@picked_shape_first_ip.position)
        k_points.line_width = 1
        k_points.size = 20
        k_points.style = Kuix::POINT_STYLE_PLUS
        @tool.append_3d(k_points)

        # Draw line from first picked point to snap point
        k_line = Kuix::LineMotif.new
        k_line.start.copy!(@picked_shape_first_ip.position)
        k_line.end.copy!(@snap_ip.position)
        k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        @tool.append_3d(k_line)

      end

      t = _get_transformation
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

      o_shape_points = _get_local_shape_points_with_offset
      o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

      k_segments = Kuix::Segments.new
      k_segments.add_segments(_points_to_segments(o_shape_points))
      k_segments.add_segments(_points_to_segments(o_top_shape_points))
      k_segments.add_segments(o_shape_points.zip(o_top_shape_points).flatten(1))
      k_segments.line_width = 1.5
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_segments.color = _get_normal_color
      k_segments.transformation = t
      @tool.append_3d(k_segments)

      Sketchup.vcb_value = bounds.depth

      unit = @tool.get_unit

      d_screen_point = view.screen_coords(bounds.min.offset(Z_AXIS, bounds.depth / 2).transform(t))

      k_label_d = Kuix::Label.new
      k_label_d.text = bounds.depth.to_s
      k_label_d.layout_data = Kuix::StaticLayoutData.new(d_screen_point.x, d_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      k_label_d.set_style_attribute(:color, Kuix::COLOR_Z)
      k_label_d.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
      k_label_d.set_style_attribute(:border_color, _get_normal_color)
      k_label_d.border.set_all!(unit * 0.25)
      k_label_d.padding.set!(unit * 0.5, unit * 0.5, unit * 0.3, unit * 0.5)
      k_label_d.text_size = unit * 2.5
      @tool.append_2d(k_label_d)

    end

    def _preview_move(view)

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)
      p3 = points[2].transform(ti)
      p4 = points[3].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p3)

      tt = Geom::Transformation.translation(p2.vector_to(p3))
      mt = Geom::Transformation.translation(p3.vector_to(p4))

      o_shape_points = _get_local_shape_points_with_offset
      o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

      k_segments = Kuix::Segments.new
      k_segments.add_segments(_points_to_segments(o_shape_points))
      k_segments.add_segments(_points_to_segments(o_top_shape_points))
      k_segments.add_segments(o_shape_points.zip(o_top_shape_points).flatten(1))
      k_segments.line_width = 1.5
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_segments.color = _get_normal_color
      k_segments.transformation = t * mt
      @tool.append_3d(k_segments)

      Sketchup.vcb_value = p3.vector_to(p4).length

    end

    # -----

    def _fetch_option_tool_pushpull
      @tool.fetch_action_option_enabled(@action, SmartDrawTool::ACTION_OPTION_TOOLS, SmartDrawTool::ACTION_OPTION_TOOLS_PUSHPULL)
    end

    def _fetch_option_tool_move
      @tool.fetch_action_option_enabled(@action, SmartDrawTool::ACTION_OPTION_TOOLS, SmartDrawTool::ACTION_OPTION_TOOLS_MOVE)
    end

    def _fetch_option_shape_offset
      @tool.fetch_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OFFSET, SmartDrawTool::ACTION_OPTION_OFFSET_SHAPE_OFFSET).to_l
    end

    def _fetch_option_construction
      @tool.fetch_action_option_enabled(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_CONSTRUCTION)
    end

    def _fetch_option_box_centered
      @tool.fetch_action_option_enabled(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_BOX_CENTRED)
    end

    # -----

    def _get_active_x_axis
      X_AXIS.transform(_get_edit_transformation)
    end

    def _get_active_y_axis
      Y_AXIS.transform(_get_edit_transformation)
    end

    def _get_active_z_axis
      Z_AXIS.transform(_get_edit_transformation)
    end

    def _get_axes

      if @direction.nil? || !@direction.perpendicular?(@normal)

        active_x_axis = _get_active_x_axis
        active_x_axis = _get_active_y_axis if active_x_axis.parallel?(@normal)

        x_axis = ORIGIN.vector_to(ORIGIN.offset(active_x_axis).project_to_plane([ ORIGIN, @normal ]))

      else
        x_axis = @direction
      end
      z_axis = @normal
      y_axis = z_axis * x_axis

      [ x_axis.normalize!, y_axis.normalize!, z_axis.normalize! ]
    end

    def _get_edit_transformation
      return IDENTITY if Sketchup.active_model.nil? || Sketchup.active_model.edit_transform.nil?
      Sketchup.active_model.edit_transform
    end

    def _get_transformation
      Geom::Transformation.axes(@picked_shape_first_ip.position, *_get_axes)
    end

    def _get_normal_color
      return Kuix::COLOR_X if @normal.parallel?(_get_active_x_axis)
      return Kuix::COLOR_Y if @normal.parallel?(_get_active_y_axis)
      return Kuix::COLOR_Z if @normal.parallel?(_get_active_z_axis)
      return Kuix::COLOR_MAGENTA if @normal == @locked_normal
      Kuix::COLOR_BLACK
    end

    # -----

    def _refresh
      @tool.refresh
    end

    def _reset
      @mouse_ip.clear
      @down_ip.clear
      @snap_ip.clear
      @picked_shape_first_ip.clear
      @picked_shape_last_ip.clear
      @picked_pushpull_ip.clear
      @picked_move_ip.clear
      @direction = nil
      @locked_normal = nil
      @normal = _get_active_z_axis
      @tool.remove_all_2d
      @tool.remove_all_3d
      @tool.pop_to_root_cursor
      Sketchup.vcb_value = ''
    end

    # -----

    def _valid_shape?
      true
    end

    def _valid_solid?
      true
    end

    # -----

    def _points_to_segments(points, closed = true, flatten = true)
      segments = points.each_cons(2).to_a
      segments << [ points.last, points.first ] if closed
      segments.flatten!(1) if flatten
      segments
    end

    # -----

    def _get_local_shape_points
      []
    end

    def _get_local_shape_points_with_offset
      []
    end

    # -----

    def _create_face(definition, p1, p2)
      definition.entities.add_face(_get_local_shape_points_with_offset)
    end

    def _create_entity

      model = Sketchup.active_model
      model.start_operation('Create Part', true)

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)
      p3 = points[2].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p3)

      if _fetch_option_construction

        tt = Geom::Transformation.translation(p2.vector_to(p3))

        group = model.active_entities.add_group
        group.transformation = t

        o_shape_points = _get_local_shape_points_with_offset
        _points_to_segments(o_shape_points, true, false).each { |segment| group.entities.add_cline(*segment) }

        if bounds.depth > 0

          o_top_shape_points = o_shape_points.map { |point| point.transform(tt) }

          _points_to_segments(o_top_shape_points, true, false).each { |segment| group.entities.add_cline(*segment) }
          o_shape_points.zip(o_top_shape_points).each { |segment| group.entities.add_cline(*segment) }

        end

        @entity = group

      else

        definition = model.definitions.add('Part')

        face = _create_face(definition, p1, p2)

        if bounds.depth > 0

          face.reverse! if face.normal.samedirection?(Z_AXIS)
          face.pushpull(bounds.depth * (p3.z < p1.z ? 1 : -1))

        else

          face.reverse! unless face.normal.samedirection?(Z_AXIS)

        end

        @entity = model.active_entities.add_instance(definition, t)

      end

      model.commit_operation

    end

    def _copy_entity
      return if @entity.nil?

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p3 = points[2].transform(ti)
      p4 = points[3].transform(ti)

      model = Sketchup.active_model
      model.start_operation('Copy Part', true)

      model.active_entities.add_instance(@entity.definition, @entity.transformation * Geom::Transformation.translation(p3.vector_to(p4)))

      model.commit_operation

    end

  end

  class SmartDrawRectangleActionHandler < SmartDrawActionHandler

    def initialize(tool)
      super(SmartDrawTool::ACTION_DRAW_RECTANGLE, tool)
    end

    def onKeyUp(key, repeat, flags, view)
      super

      if key == VK_ALT
        @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, !_fetch_option_rectangle_centered, true) if _picked_shape_first_point? && !_picked_shape_last_point?
        _refresh
      end

    end

    def onUserText(text, view)
      return true if super

      if _picked_shape_first_point?

        d1, d2, d3 = text.split(';')

        if d1 || d2

          length = d1 ? d1.to_l : 0
          width = d2 ? d2.to_l : 0

          t = _get_transformation
          ti = t.inverse

          p1 = @picked_shape_first_ip.position.transform(ti)
          p2 = @snap_ip.position.transform(ti)

          if length == 0
            length = p2.x - p1.x
          else
            length *= -1 if p2.x < p1.x
            length = length / 2 if _fetch_option_rectangle_centered
          end

          if width == 0
            width = p2.y - p1.y
          else
            width *= -1 if p2.y < p1.y
            width = width / 2 if _fetch_option_rectangle_centered
          end

          @picked_shape_last_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p1.x + length, p1.y + width, p1.z).transform(t))

          if d3.nil?
            if _fetch_option_tool_pushpull
              @tool.push_cursor(SmartDrawTool::CURSOR_PUSHPULL)
              _refresh
              Sketchup.vcb_value = ''
            else
              @picked_pushpull_ip.copy!(@picked_shape_last_ip)
              if _fetch_option_tool_move
                @tool.push_cursor(SmartDrawTool::CURSOR_MOVE)
                _refresh
                Sketchup.vcb_value = ''
              else
                _create_entity
                _reset
              end
            end
          end

        end
        if d3

          thickness = d3.to_l

          t = _get_transformation
          ti = t.inverse

          p2 = @picked_shape_last_ip.position.transform(ti)
          p3 = @picked_pushpull_ip.position.transform(ti)

          if thickness == 0
            thickness = p3.z - p2.z
          else
            thickness *= -1 if p3.z < p2.z
            thickness = thickness / 2 if _fetch_option_box_centered
          end

          @picked_pushpull_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

          _create_entity
          _reset

          Sketchup.vcb_value = ''

        end

        return true
      end

      false
    end

    def getExtents
      return super if _get_picked_points.empty?
      bounds = Geom::BoundingBox.new
      bounds.add(_get_picked_points)
      bounds
    end

    protected

    def _snap_shape_points(flags, x, y, view)

      ground_plane = [@picked_shape_first_ip.position, _get_active_z_axis ]

      if @mouse_ip.vertex

        if @locked_normal

          locked_plane = [@picked_shape_first_ip.position, @locked_normal ]

          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
          @normal = @locked_normal

        elsif @mouse_ip.position.on_plane?(ground_plane)

          @normal = _get_active_z_axis

        elsif @mouse_ip.position.on_plane?([@picked_shape_first_ip.position, _get_active_x_axis ])

          @normal = _get_active_x_axis

        elsif @mouse_ip.position.on_plane?([@picked_shape_first_ip.position, _get_active_y_axis ])

          @normal = _get_active_y_axis

        else

          # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
          #
          # k_points = Kuix::Points.new
          # k_points.add_points([ vertex_manipulator.point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
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

        end

      elsif @mouse_ip.edge

        edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

        if @locked_normal

          locked_plane = [@picked_shape_first_ip.position, @locked_normal ]

          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
          @normal = @locked_normal

        elsif @mouse_ip.position.on_plane?([@picked_shape_first_ip.position, _get_active_z_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_z_axis)

          @normal = _get_active_z_axis

        elsif @mouse_ip.position.on_plane?([@picked_shape_first_ip.position, _get_active_x_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_x_axis)

          @normal = _get_active_x_axis

        elsif @mouse_ip.position.on_plane?([@picked_shape_first_ip.position, _get_active_y_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_y_axis)

          @normal = _get_active_y_axis

        else

          unless @picked_shape_first_ip.position.on_line?(edge_manipulator.line)

            plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([@picked_shape_first_ip.position, edge_manipulator.start_point, edge_manipulator.end_point ]))

            @normal = plane_manipulator.normal

          end

          @direction = edge_manipulator.direction

          # k_points = Kuix::Points.new
          # k_points.add_points([ @picked_first_ip.position, edge_manipulator.start_point, edge_manipulator.end_point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
          # k_points.color = Kuix::COLOR_BLUE
          # @tool.append_3d(k_points)

          # k_segments = Kuix::Segments.new
          # k_segments.add_segments(edge_manipulator.segment)
          # k_segments.color = Kuix::COLOR_MAGENTA
          # k_segments.line_width = 4
          # k_segments.on_top = true
          # @tool.append_3d(k_segments)

        end

      elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

        if @locked_normal

          locked_plane = [@picked_shape_first_ip.position, @locked_normal ]

          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
          @normal = @locked_normal

        else

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

          if @picked_shape_first_ip.position.on_plane?(face_manipulator.plane)

            @normal = face_manipulator.normal

          else

            p1 = @picked_shape_first_ip.position
            p2 = @mouse_ip.position
            p3 = @mouse_ip.position.project_to_plane(ground_plane)

            # k_points = Kuix::Points.new
            # k_points.add_points([ p1, p2, p3 ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_PLUS
            # k_points.color = Kuix::COLOR_RED
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

          locked_plane = [@picked_shape_first_ip.position, @locked_normal ]

          if @mouse_ip.degrees_of_freedom > 2
            @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), locked_plane))
          else
            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
          end
          @normal = @locked_normal

        else

          if @mouse_ip.degrees_of_freedom > 2
            picked_point = Geom::intersect_line_plane(view.pickray(x, y), ground_plane)
            @mouse_ip = Sketchup::InputPoint.new(picked_point) unless picked_point.nil?
          end

          if !@mouse_ip.position.on_plane?(ground_plane)

            p1 = @picked_shape_first_ip.position
            p2 = @mouse_ip.position
            p3 = @mouse_ip.position.project_to_plane(ground_plane)

            # k_points = Kuix::Points.new
            # k_points.add_points([ p1, p2, p3 ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_CROSS
            # k_points.color = Kuix::COLOR_RED
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

      super
    end

    def _preview_shape(view)

      if _fetch_option_rectangle_centered

        k_points = Kuix::Points.new
        k_points.add_point(@picked_shape_first_ip.position)
        k_points.line_width = 1
        k_points.size = 20
        k_points.style = Kuix::POINT_STYLE_PLUS
        @tool.append_3d(k_points)

        k_line = Kuix::LineMotif.new
        k_line.start.copy!(@picked_shape_first_ip.position)
        k_line.end.copy!(@snap_ip.position)
        k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        @tool.append_3d(k_line)

      end

      t = _get_transformation
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
        k_segments.line_width = @locked_normal ? 3 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      o_segments = _points_to_segments(_get_local_shape_points_with_offset)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(o_segments)
      k_segments.line_width = @locked_normal ? 3 : 1.5
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_segments.color = _get_normal_color
      k_segments.transformation = t
      @tool.append_3d(k_segments)

      Sketchup.vcb_value = "#{bounds.width}; #{bounds.height}"

      w_screen_point = view.screen_coords(bounds.min.offset(X_AXIS, bounds.width / 2).transform(t))
      h_screen_point = view.screen_coords(bounds.min.offset(Y_AXIS, bounds.height / 2).transform(t))

      unit = @tool.get_unit

      k_label_w = Kuix::Label.new
      k_label_w.text = bounds.width.to_s
      k_label_w.layout_data = Kuix::StaticLayoutData.new(w_screen_point.x, w_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      k_label_w.set_style_attribute(:color, Kuix::COLOR_X)
      k_label_w.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
      k_label_w.set_style_attribute(:border_color, _get_normal_color)
      k_label_w.border.set_all!(unit * 0.25)
      k_label_w.padding.set!(unit * 0.5, unit * 0.5, unit * 0.3, unit * 0.5)
      k_label_w.text_size = unit * 2.5
      @tool.append_2d(k_label_w)

      k_label_h = Kuix::Label.new
      k_label_h.text = bounds.height.to_s
      k_label_h.layout_data = Kuix::StaticLayoutData.new(h_screen_point.x, h_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      k_label_h.set_style_attribute(:color, Kuix::COLOR_Y)
      k_label_h.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
      k_label_h.set_style_attribute(:border_color, _get_normal_color)
      k_label_h.border.set_all!(unit * 0.25)
      k_label_h.padding.set!(unit * 0.5, unit * 0.5, unit * 0.3, unit * 0.5)
      k_label_h.text_size = unit * 2.5
      @tool.append_2d(k_label_h)

    end

    # -----

    def _fetch_option_rectangle_centered
      @tool.fetch_action_option_enabled(@action, SmartDrawTool::ACTION_OPTION_OPTIONS, SmartDrawTool::ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED)
    end

    # -----

    def _valid_shape?

      points = _get_picked_points
      return false if points.length < 2

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      (p2.x - p1.x).round(6) != 0 && (p2.y - p1.y).round(6) != 0
    end

    def _valid_solid?

      points = _get_picked_points
      return false if points.length < 3

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p3 = points[2].transform(ti)

      (p3.x - p1.x).round(6) != 0 && (p3.y - p1.y).round(6) != 0 && (p3.z - p1.z).round(6) != 0
    end

    # -----

    def _get_picked_points

      points = []
      points << @picked_shape_first_ip.position if _picked_shape_first_point?
      points << @picked_shape_last_ip.position if _picked_shape_last_point?
      points << @picked_pushpull_ip.position if _picked_pushpull_point?
      points << @picked_move_ip.position if _picked_move_point?
      points << @snap_ip.position if @snap_ip.valid?

      if _fetch_option_rectangle_centered && _picked_shape_first_point? && points.length > 1
        points[0] = points[0].offset(points[1].vector_to(points[0]))
      end
      if _fetch_option_box_centered && _picked_shape_last_point? && points.length > 2
        offset = points[2].vector_to(points[1])
        points[0] = points[0].offset(offset)
        points[1] = points[1].offset(offset)
      end

      points
    end

    def _get_local_shape_points

      t = _get_transformation
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

    def _get_local_shape_points_with_offset

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p2)

      shape_offset = _fetch_option_shape_offset

      o_min = bounds.min.offset(X_AXIS, -shape_offset).offset!(Y_AXIS, -shape_offset)
      o_max = bounds.max.offset(X_AXIS, shape_offset).offset!(Y_AXIS, shape_offset)

      o_bounds = Geom::BoundingBox.new
      o_bounds.add(o_min, o_max)

      [
        o_bounds.corner(0),
        o_bounds.corner(1),
        o_bounds.corner(3),
        o_bounds.corner(2)
      ]
    end

  end

  class SmartDrawCircleActionHandler < SmartDrawActionHandler

    def initialize(tool)
      super(SmartDrawTool::ACTION_DRAW_CIRCLE, tool)
    end

    # -----

    def onUserText(text, view)

      if text.end_with?('s')

        segment_count = text.to_i
        @tool.store_action_option_value(@action, SmartDrawTool::ACTION_OPTION_SEGMENTS, SmartDrawTool::ACTION_OPTION_SEGMENTS_SEGMENT_COUNT, segment_count, true)
        _refresh

      elsif super

        return true

      elsif _picked_shape_first_point?

        d1, d2 = text.split(';')

        if d1

          radius = d1 ? d1.to_l : 0

          puts "radius: #{radius}"

          t = _get_transformation
          ti = t.inverse

          p1 = @picked_shape_first_ip.position.transform(ti)
          p2 = @snap_ip.position.transform(ti)

          if radius == 0
            radius = p2.x - p1.x
          else
            radius *= -1 if p2.x < p1.x
          end

          @picked_shape_last_ip = Sketchup::InputPoint.new(p1.offset(p1.vector_to(p2), radius).transform(t))

          if d2.nil?
            if _fetch_option_tool_pushpull
              @tool.push_cursor(SmartDrawTool::CURSOR_PUSHPULL)
              _refresh
              Sketchup.vcb_value = ''
            else
              @picked_pushpull_ip.copy!(@picked_shape_last_ip)
              if _fetch_option_tool_move
                @tool.push_cursor(SmartDrawTool::CURSOR_MOVE)
                _refresh
                Sketchup.vcb_value = ''
              else
                _create_entity
                _reset
              end
            end
          end

        end
        if d2

          thickness = d2.to_l

          t = _get_transformation
          ti = t.inverse

          p2 = @picked_shape_last_ip.position.transform(ti)
          p3 = @picked_pushpull_ip.position.transform(ti)

          if thickness == 0
            thickness = p3.z - p2.z
          else
            thickness *= -1 if p3.z < p2.z
            thickness = thickness / 2 if _fetch_option_box_centered
          end

          @picked_pushpull_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

          _create_entity
          _reset

          Sketchup.vcb_value = ''

        end

        return true
      end

      false
    end

    protected

    def _snap_shape_points(flags, x, y, view)

      if @locked_normal

        locked_plane = [@picked_shape_first_ip.position, @locked_normal ]

        if @mouse_ip.degrees_of_freedom > 2
          @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), locked_plane))
        else
          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
        end
        @normal = @locked_normal

      else

        plane = [@picked_shape_first_ip.position, @normal ]

        if @mouse_ip.degrees_of_freedom > 2
          @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), plane))
        else
          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(plane))
        end

      end

      @direction = @picked_shape_first_ip.position.vector_to(@snap_ip.position)

      super
    end

    # -----

    def _preview_shape(view)

      k_points = Kuix::Points.new
      k_points.add_point(@picked_shape_first_ip.position)
      k_points.line_width = 1
      k_points.size = 20
      k_points.style = Kuix::POINT_STYLE_PLUS
      @tool.append_3d(k_points)

      k_line = Kuix::LineMotif.new
      k_line.start.copy!(@picked_shape_first_ip.position)
      k_line.end.copy!(@snap_ip.position)
      k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      @tool.append_3d(k_line)

      t = _get_transformation

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = @locked_normal ? 3 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      o_segments = _points_to_segments(_get_local_shape_points_with_offset)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(o_segments)
      k_segments.line_width = @locked_normal ? 3 : 1.5
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_segments.color = _get_normal_color
      k_segments.transformation = t
      @tool.append_3d(k_segments)

      radius_vector = @picked_shape_first_ip.position.vector_to(@snap_ip.position)
      radius = radius_vector.length

      Sketchup.vcb_value = "#{radius}"

      unit = @tool.get_unit

      r_screen_point = view.screen_coords(@picked_shape_first_ip.position.offset(radius_vector, radius / 2))

      k_label_r = Kuix::Label.new
      k_label_r.text = radius.to_s
      k_label_r.layout_data = Kuix::StaticLayoutData.new(r_screen_point.x, r_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
      k_label_r.set_style_attribute(:color, Kuix::COLOR_X)
      k_label_r.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
      k_label_r.set_style_attribute(:border_color, _get_normal_color)
      k_label_r.border.set_all!(unit * 0.25)
      k_label_r.padding.set!(unit * 0.5, unit * 0.5, unit * 0.3, unit * 0.5)
      k_label_r.text_size = unit * 2.5
      @tool.append_2d(k_label_r)

    end

    # -----

    def _fetch_option_segment_count
      @tool.fetch_action_option_value(@action, SmartDrawTool::ACTION_OPTION_SEGMENTS, SmartDrawTool::ACTION_OPTION_SEGMENTS_SEGMENT_COUNT).to_i
    end

    # -----

    def _valid_shape?

      points = _get_picked_points
      return false if points.length < 2

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      p1.distance(p2).round(6) > 0
    end

    # -----

    def _get_picked_points

      points = []
      points << @picked_shape_first_ip.position if _picked_shape_first_point?
      points << @picked_shape_last_ip.position if _picked_shape_last_point?
      points << @picked_pushpull_ip.position if _picked_pushpull_point?
      points << @picked_move_ip.position if _picked_move_point?
      points << @snap_ip.position if @snap_ip.valid?

      if _fetch_option_box_centered && _picked_shape_last_point? && points.length > 2
        offset = points[2].vector_to(points[1])
        points[0] = points[0].offset(offset)
        points[1] = points[1].offset(offset)
      end

      points
    end

    def _get_local_shape_points

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      segment_count = [ _fetch_option_segment_count, 3 ].max
      unit_angle = Geometrix::TWO_PI / segment_count
      start_angle = X_AXIS.angle_between(Geom::Vector3d.new(*p2.to_a))
      start_angle *= -1 if p2.y < 0
      circle_def = Geometrix::CircleDef.new(p1, p1.distance(p2))

      Array.new(segment_count) { |i| Geometrix::CircleFinder.circle_point_at_angle(circle_def, start_angle + i * unit_angle) }
    end

    def _get_local_shape_points_with_offset

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      segment_count = [ _fetch_option_segment_count, 3 ].max
      unit_angle = Geometrix::TWO_PI / segment_count
      start_angle = X_AXIS.angle_between(Geom::Vector3d.new(*p2.to_a))
      start_angle *= -1 if p2.y < 0
      circle_def = Geometrix::CircleDef.new(p1, p1.distance(p2) + _fetch_option_shape_offset)

      Array.new(segment_count) { |i| Geometrix::CircleFinder.circle_point_at_angle(circle_def, start_angle + i * unit_angle) }
    end

    # -----

    def _create_face(definition, p1, p2)
      edge = definition.entities.add_circle(p1, Z_AXIS, p1.distance(p2) + _fetch_option_shape_offset, _fetch_option_segment_count).first
      edge.find_faces
      edge.faces.first
    end

  end

  class SmartDrawPolygonActionHandler < SmartDrawActionHandler

    def initialize(tool)
      super(SmartDrawTool::ACTION_DRAW_POLYGON, tool)

      @picked_ips = []

    end

    # -----

    def onCancel(reason, view)
      if !_picked_shape_last_point? && @picked_ips.any?
        @picked_ips.pop
        if @picked_ips.empty?
          super
        else
          _refresh
        end
      else
        super
      end
    end

    def onMouseMove(flags, x, y, view)
      if !_picked_shape_first_point?
        super
        @picked_ips << @picked_shape_first_ip if _picked_shape_first_point?
      else
        super
      end
    end

    def onLButtonUp(flags, x, y, view)

      if !_picked_shape_first_point?

        super
        @picked_ips << @picked_shape_first_ip if _picked_shape_first_point?

      elsif !_picked_shape_last_point?

        return super if @picked_ips.find { |ip| ip.position == @snap_ip.position }

        @picked_ips << Sketchup::InputPoint.new(@snap_ip.position)
        _refresh

      else
        super
      end

    end

    def onLButtonDoubleClick(flags, x, y, view)

      if _picked_shape_first_point? && !_picked_shape_last_point?
        onLButtonUp(flags, x, y, view)
      end

    end

    def onKeyDown(key, repeat, flags, view)

      if key == Kuix::VK_ENTER && !_picked_shape_last_point? && @picked_ips.length >= 3
        # TODO
      end

      super
    end

    def onUserText(text, view)
      return true if super

      if _picked_shape_first_point?

        length = text.to_l

        t = _get_transformation
        ti = t.inverse

        p1 = @picked_ips.last.position.transform(ti)
        p2 = @snap_ip.position.transform(ti)
        v = p1.vector_to(p2)

        length = v.length if length == 0

        @picked_ips << Sketchup::InputPoint.new(p1.offset(v, length).transform(t))
        _refresh

        return true
      end

      false
    end

    protected

    def _snap_shape_points(flags, x, y, view)

      if @picked_ips.length < 2

        ground_plane = [ @picked_shape_first_ip.position, _get_active_z_axis ]

        if @mouse_ip.vertex

          if @locked_normal

            locked_plane = [ @picked_shape_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?(ground_plane)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_first_ip.position, _get_active_x_axis ])

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_first_ip.position, _get_active_y_axis ])

            @normal = _get_active_y_axis

          else

            # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
            #
            # k_points = Kuix::Points.new
            # k_points.add_points([ vertex_manipulator.point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
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

          end

        elsif @mouse_ip.edge

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          if @locked_normal

            locked_plane = [ @picked_shape_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?([ @picked_shape_first_ip.position, _get_active_z_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_z_axis)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_first_ip.position, _get_active_x_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_x_axis)

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_shape_first_ip.position, _get_active_y_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_y_axis)

            @normal = _get_active_y_axis

          else

            unless @picked_shape_first_ip.position.on_line?(edge_manipulator.line)

              plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_shape_first_ip.position, edge_manipulator.start_point, edge_manipulator.end_point ]))

              @normal = plane_manipulator.normal

            end

            @direction = edge_manipulator.direction

            # k_points = Kuix::Points.new
            # k_points.add_points([ @picked_first_ip.position, edge_manipulator.start_point, edge_manipulator.end_point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
            # k_points.color = Kuix::COLOR_BLUE
            # @tool.append_3d(k_points)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(edge_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @tool.append_3d(k_segments)

          end

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          if @locked_normal

            locked_plane = [ @picked_shape_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          else

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            if @picked_shape_first_ip.position.on_plane?(face_manipulator.plane)

              @normal = face_manipulator.normal

            else

              p1 = @picked_shape_first_ip.position
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_PLUS
              # k_points.color = Kuix::COLOR_RED
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

            locked_plane = [ @picked_shape_first_ip.position, @locked_normal ]

            if @mouse_ip.degrees_of_freedom > 2
              @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), locked_plane))
            else
              @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            end
            @normal = @locked_normal

          else

            if @mouse_ip.degrees_of_freedom > 2
              picked_point = Geom::intersect_line_plane(view.pickray(x, y), ground_plane)
              @mouse_ip = Sketchup::InputPoint.new(picked_point) unless picked_point.nil?
            end

            if !@mouse_ip.position.on_plane?(ground_plane)

              p1 = @picked_shape_first_ip.position
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_CROSS
              # k_points.color = Kuix::COLOR_RED
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

      elsif @picked_ips.length == 2

        if @locked_normal

          locked_plane = [ @picked_shape_first_ip.position, @locked_normal ]

          if @mouse_ip.degrees_of_freedom > 2
            @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), locked_plane))
          else
            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
          end
          @normal = @locked_normal

        else

          p1 = @picked_ips[0].position
          p2 = @picked_ips[1].position
          p3 = @mouse_ip.position

          plane = Geom::fit_plane_to_points(p1, p2, p3)
          plane_manipulator = PlaneManipulator.new(plane)

          @normal = plane_manipulator.normal

        end

      else

        # Test previously picked points
        ph = view.pick_helper(x, y, 50)
        @picked_ips.each do |ip|
          if ph.test_point(ip.position)

            k_points = Kuix::Points.new
            k_points.add_point(ip.position)
            k_points.size = 20
            k_points.style = Kuix::POINT_STYLE_FILLED_SQUARE
            k_points.color = Kuix::COLOR_BLACK
            @tool.append_3d(k_points)

            k_points = Kuix::Points.new
            k_points.add_point(ip.position)
            k_points.size = 20
            k_points.line_width = 1
            k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
            k_points.color = Kuix::COLOR_WHITE
            @tool.append_3d(k_points)

            @snap_ip.copy!(ip)
            @mouse_ip.copy!(ip)

            break
          end
        end

        unless @snap_ip.valid?

          plane = [ @picked_shape_first_ip.position, @normal ]

          if @mouse_ip.degrees_of_freedom > 2
            @snap_ip = Sketchup::InputPoint.new(Geom.intersect_line_plane(view.pickray(x, y), plane))
          else
            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(plane))
          end

        end

      end

      super
    end

    # -----

    def _preview_shape(view)

      t = _get_transformation
      ti = t.inverse

      if _fetch_option_shape_offset != 0

        segments = _points_to_segments(_get_local_shape_points)

        k_segments = Kuix::Segments.new
        k_segments.add_segments(segments)
        k_segments.line_width = @locked_normal ? 3 : 1.5
        k_segments.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_segments.color = _get_normal_color
        k_segments.transformation = t
        @tool.append_3d(k_segments)

      end

      o_segments = _points_to_segments(_get_local_shape_points_with_offset)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(o_segments)
      k_segments.line_width = @locked_normal ? 3 : 1.5
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if _fetch_option_construction
      k_segments.color = _get_normal_color
      k_segments.transformation = t
      @tool.append_3d(k_segments)

      if @picked_ips.length >= 1

        p1 = @picked_ips[-1].position.transform(ti)
        p2 = @snap_ip.position.transform(ti)
        v = p1.vector_to(p2)

        length = v.length

        Sketchup.vcb_value = "#{v.length}"

        if v.valid?

          unit = @tool.get_unit
          screen_point = view.screen_coords(p1.offset(v, length / 2).transform(t))

          k_label = Kuix::Label.new
          k_label.text = length.to_s
          k_label.layout_data = Kuix::StaticLayoutData.new(screen_point.x, screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
          k_label.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
          k_label.set_style_attribute(:border_color, _get_normal_color)
          k_label.border.set_all!(unit * 0.25)
          k_label.padding.set!(unit * 0.5, unit * 0.5, unit * 0.3, unit * 0.5)
          k_label.text_size = unit * 2.5
          @tool.append_2d(k_label)

        end

      end

    end

    # -----

    def _reset
      super
      @picked_ips.clear
    end

    # -----

    def _get_picked_points

      points = []
      points << @picked_shape_first_ip.position if _picked_shape_first_point?
      points << @picked_shape_last_ip.position if _picked_shape_last_point?
      points << @picked_pushpull_ip.position if _picked_pushpull_point?
      points << @picked_move_ip.position if _picked_move_point?
      points << @snap_ip.position if @snap_ip.valid?

      if _fetch_option_box_centered && _picked_shape_last_point? && points.length > 2
        offset = points[2].vector_to(points[1])
        points[0] = points[0].offset(offset)
        points[1] = points[1].offset(offset)
      end

      points
    end

    def _get_local_shape_points
      t = _get_transformation
      ti = t.inverse
      if @picked_shape_last_ip.valid?
        @picked_ips.map { |ip| ip.position.transform(ti) }
      else
        (@picked_ips + [ @snap_ip ]).map { |ip| ip.position.transform(ti) }
      end
    end

    def _get_local_shape_points_with_offset
      shape_offset = _fetch_option_shape_offset
      points = _get_local_shape_points
      return points if shape_offset == 0 || points.length < 3
      Fiddle::Clippy.rpath_to_points(Fiddle::Clippy.inflate_paths(
        paths: [ Fiddle::Clippy.points_to_rpath(points) ],
        delta: shape_offset,
        join_type: Fiddle::Clippy::JOIN_TYPE_MITER,
        miter_limit: 100.0
      ).first)
    end

  end

end