module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'

  class SmartDrawTool < SmartTool

    ACTION_DRAW_BOX = 0

    ACTION_OPTION_TOOLS = 'tools'
    ACTION_OPTION_OFFSET = 'offset'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_TOOLS_PUSHPULL = 'pushpull'
    ACTION_OPTION_TOOLS_MOVE = 'move'

    ACTION_OPTION_OFFSET_SECTION_OFFSET = 'section_offset'

    ACTION_OPTION_OPTIONS_CONSTRUCTION = 'construction'
    ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED = 'rectangle_centered'
    ACTION_OPTION_OPTIONS_BOX_CENTRED = 'box_centered'

    ACTIONS = [
      {
        :action => ACTION_DRAW_BOX,
        :options => {
          ACTION_OPTION_TOOLS => [ ACTION_OPTION_TOOLS_PUSHPULL, ACTION_OPTION_TOOLS_MOVE ],
          ACTION_OPTION_OFFSET => [ ACTION_OPTION_OFFSET_SECTION_OFFSET ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CONSTRUCTION, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, ACTION_OPTION_OPTIONS_BOX_CENTRED ],
        }
      }
    ].freeze

    COLOR_BRAND = Sketchup::Color.new(247, 127, 0).freeze
    COLOR_BRAND_DARK = Sketchup::Color.new(62, 59, 51).freeze
    COLOR_BRAND_LIGHT = Sketchup::Color.new(214, 212, 205).freeze

    CURSOR_PENCIL = 632
    CURSOR_PENCIL_RECTANGLE = 637
    CURSOR_PENCIL_PUSHPULL = 639
    CURSOR_MOVE = 641
    CURSOR_MOVE_PLUS = 642

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

    def get_action_status(action)

      super
    end

    def get_action_cursor(action)

      super
    end

    def get_action_options_modal?(action)
      true
    end

    def get_action_option_group_unique?(action, option_group)

      super
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_OFFSET
        case option
        when ACTION_OPTION_OFFSET_SECTION_OFFSET
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
        when ACTION_OPTION_OFFSET_SECTION_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option))
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

    def is_action_draw_box?
      fetch_action == ACTION_DRAW_BOX
    end

    # -- Events --

    def onActivate(view)
      super

      @mouse_x = -1
      @mouse_y = -1

      @mouse_ip = Sketchup::InputPoint.new
      @snap_ip = Sketchup::InputPoint.new
      @picked_first_ip = Sketchup::InputPoint.new
      @picked_second_ip = Sketchup::InputPoint.new
      @picked_third_ip = Sketchup::InputPoint.new
      @picked_fourth_ip = Sketchup::InputPoint.new

      @locked_normal = nil

      @direction = nil
      @normal = _get_active_z_axis

      _update_status_text

      set_root_cursor(CURSOR_PENCIL_RECTANGLE)

    end

    def onResume(view)
      super
      _update_status_text
    end

    def onCancel(reason, view)
      if _picked_third_point?
        @picked_third_ip.clear
        _reset
      elsif _picked_second_point?
        @picked_second_ip.clear
        pop_to_root_cursor
      elsif _picked_first_point?
        @picked_first_ip.clear
      else
        _reset
      end
      _refresh
    end

    def onMouseMove(flags, x, y, view)
      return true if super

      @mouse_x = x
      @mouse_y = y

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
      puts "---"

      @floating_panel.remove_all
      @space.remove_all

      Sketchup.vcb_value = ''

      if _picked_third_point?

        @snap_ip.copy!(@mouse_ip)

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p1 = points[0].transform(ti)
        p3 = points[2].transform(ti)
        p4 = points[3].transform(ti)

        mt = Geom::Transformation.translation(p3.vector_to(p4))

        bounds = Geom::BoundingBox.new
        bounds.add(p1, p3)

        section_offset = _fetch_section_offset
        if section_offset != 0
          k_box = Kuix::BoxMotif.new
          k_box.bounds.origin.copy!(bounds.min)
          k_box.bounds.size.set!(bounds.width, bounds.height, bounds.depth)
          k_box.line_width = 1.5
          k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_box.color = _get_normal_color
          k_box.transformation = t * mt
          @space.append(k_box)
        end

        o_min = bounds.min.offset(X_AXIS, -section_offset).offset!(Y_AXIS, -section_offset)
        o_max = bounds.max.offset(X_AXIS, section_offset).offset!(Y_AXIS, section_offset)

        o_bounds = Geom::BoundingBox.new
        o_bounds.add(o_min, o_max)

        k_box = Kuix::BoxMotif.new
        k_box.bounds.origin.copy!(o_bounds.min)
        k_box.bounds.size.set!(o_bounds.width, o_bounds.height, o_bounds.depth)
        k_box.line_width = 1.5
        k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CONSTRUCTION)
        k_box.color = _get_normal_color
        k_box.transformation = t * mt
        @space.append(k_box)

        unless view.inference_locked?

          k_line = Kuix::LineMotif.new
          k_line.start.copy!(@picked_third_ip.position)
          k_line.end.copy!(@snap_ip.position)
          k_line.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
          k_line.color = Kuix::COLOR_BLACK
          @space.append(k_line)

        end

        Sketchup.vcb_value = p3.vector_to(p4).length

      elsif _picked_second_point?

        # Pick third point

        if @mouse_ip.degrees_of_freedom > 2 ||
          @mouse_ip.instance_path.length == 0 ||
          @mouse_ip.position.on_plane?([ @picked_second_ip.position, @normal ]) ||
          @mouse_ip.face && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(@normal) ||
          @mouse_ip.edge && @mouse_ip.degrees_of_freedom == 1 && !@mouse_ip.edge.start.position.vector_to(@mouse_ip.edge.end.position).transform(@mouse_ip.transformation).perpendicular?(@normal)

          picked_point, _ = Geom::closest_points([ @picked_second_ip.position, @normal ], view.pickray(x, y))
          @snap_ip = Sketchup::InputPoint.new(picked_point)
          @mouse_ip.copy!(@snap_ip) # Set display? to false

        else

          # Force picked point to be projected to second picked point normal line
          @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_line([ @picked_second_ip.position, @normal ]))

        end

        if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED) || fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_BOX_CENTRED)

          # Draw first picked point
          k_points = Kuix::Points.new
          k_points.add_point(@picked_first_ip.position)
          k_points.line_width = 1
          k_points.size = 20
          k_points.style = Kuix::POINT_STYLE_PLUS
          @space.append(k_points)

          # Draw line from first picked point to snap point
          k_line = Kuix::LineMotif.new
          k_line.start.copy!(@picked_first_ip.position)
          k_line.end.copy!(@snap_ip.position)
          k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          @space.append(k_line)

        end

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p1 = points[0].transform(ti)
        p3 = points[2].transform(ti)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, p3)

        section_offset = _fetch_section_offset
        if section_offset != 0
          k_box = Kuix::BoxMotif.new
          k_box.bounds.origin.copy!(bounds.min)
          k_box.bounds.size.set!(bounds.width, bounds.height, bounds.depth)
          k_box.line_width = 1.5
          k_box.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_box.color = _get_normal_color
          k_box.transformation = t
          @space.append(k_box)
        end

        o_min = bounds.min.offset(X_AXIS, -section_offset).offset!(Y_AXIS, -section_offset)
        o_max = bounds.max.offset(X_AXIS, section_offset).offset!(Y_AXIS, section_offset)

        o_bounds = Geom::BoundingBox.new
        o_bounds.add(o_min, o_max)

        k_box = Kuix::BoxMotif.new
        k_box.bounds.origin.copy!(o_bounds.min)
        k_box.bounds.size.set!(o_bounds.width, o_bounds.height, o_bounds.depth)
        k_box.line_width = 1.5
        k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CONSTRUCTION)
        k_box.color = _get_normal_color
        k_box.transformation = t
        @space.append(k_box)

        Sketchup.vcb_value = bounds.depth

        d_screen_point = view.screen_coords(bounds.min.offset(Z_AXIS, bounds.depth / 2).transform(t))

        k_label_d = Kuix::Label.new
        k_label_d.text = bounds.depth.to_s
        k_label_d.layout_data = Kuix::StaticLayoutData.new(d_screen_point.x, d_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        k_label_d.set_style_attribute(:color, Kuix::COLOR_Z)
        k_label_d.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
        k_label_d.set_style_attribute(:border_color, _get_normal_color)
        k_label_d.border.set_all!(@unit * 0.25)
        k_label_d.padding.set!(@unit * 0.5, @unit * 0.5, @unit * 0.3, @unit * 0.5)
        k_label_d.text_size = @unit * 2.5
        @floating_panel.append(k_label_d)

      elsif _picked_first_point?

        # Pick second point

        ground_plane = [ @picked_first_ip.position, _get_active_z_axis ]

        if @mouse_ip.vertex

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?(ground_plane)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_x_axis ])

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_y_axis ])

            @normal = _get_active_y_axis

          else

            # vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)
            #
            # k_points = Kuix::Points.new
            # k_points.add_points([ vertex_manipulator.point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
            # k_points.color = Kuix::COLOR_MAGENTA
            # @space.append(k_points)
            #
            # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
            #
            #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
            #
            #   k_mesh = Kuix::Mesh.new
            #   k_mesh.add_triangles(face_manipulator.triangles)
            #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            #   @space.append(k_mesh)
            #
            # end

          end

        elsif @mouse_ip.edge

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_z_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_z_axis)

            @normal = _get_active_z_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_x_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_x_axis)

            @normal = _get_active_x_axis

          elsif @mouse_ip.position.on_plane?([ @picked_first_ip.position, _get_active_y_axis ]) && !edge_manipulator.direction.perpendicular?(_get_active_y_axis)

            @normal = _get_active_y_axis

          else

            unless @picked_first_ip.position.on_line?(edge_manipulator.line)

              plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_first_ip.position, edge_manipulator.start_point, edge_manipulator.end_point ]))

              @normal = plane_manipulator.normal

            end

            @direction = edge_manipulator.direction

            # k_points = Kuix::Points.new
            # k_points.add_points([ @picked_first_ip.position, edge_manipulator.start_point, edge_manipulator.end_point ])
            # k_points.size = 30
            # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
            # k_points.color = Kuix::COLOR_BLUE
            # @space.append(k_points)

            # k_segments = Kuix::Segments.new
            # k_segments.add_segments(edge_manipulator.segment)
            # k_segments.color = Kuix::COLOR_MAGENTA
            # k_segments.line_width = 4
            # k_segments.on_top = true
            # @space.append(k_segments)

          end

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

            @snap_ip = Sketchup::InputPoint.new(@mouse_ip.position.project_to_plane(locked_plane))
            @normal = @locked_normal

          else

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            if @picked_first_ip.position.on_plane?(face_manipulator.plane)

              @normal = face_manipulator.normal

            else

              p1 = @picked_first_ip.position
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_PLUS
              # k_points.color = Kuix::COLOR_RED
              # @space.append(k_points)

              plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
              plane_manipulator = PlaneManipulator.new(plane)

              @direction = _get_active_z_axis
              @normal = plane_manipulator.normal

            end

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
            # @space.append(k_mesh)

          end

        else

          if @locked_normal

            locked_plane = [ @picked_first_ip.position, @locked_normal ]

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

              p1 = @picked_first_ip.position
              p2 = @mouse_ip.position
              p3 = @mouse_ip.position.project_to_plane(ground_plane)

              # k_points = Kuix::Points.new
              # k_points.add_points([ p1, p2, p3 ])
              # k_points.size = 30
              # k_points.style = Kuix::POINT_STYLE_CROSS
              # k_points.color = Kuix::COLOR_RED
              # @space.append(k_points)

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

        @snap_ip.copy!(@mouse_ip) unless @snap_ip.valid?

        t = _get_transformation
        ti = t.inverse

        if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED)

          k_points = Kuix::Points.new
          k_points.add_point(@picked_first_ip.position)
          k_points.line_width = 1
          k_points.size = 20
          k_points.style = Kuix::POINT_STYLE_PLUS
          @space.append(k_points)

          k_line = Kuix::LineMotif.new
          k_line.start.copy!(@picked_first_ip.position)
          k_line.end.copy!(@snap_ip.position)
          k_line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          @space.append(k_line)

        end

        points = _get_picked_points
        p1 = points[0].transform(ti)
        p2 = points[1].transform(ti)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, p2)

        section_offset = _fetch_section_offset
        if section_offset != 0
          k_rectangle = Kuix::RectangleMotif.new
          k_rectangle.bounds.origin.copy!(bounds.min)
          k_rectangle.bounds.size.set!(bounds.width, bounds.height, 0)
          k_rectangle.line_width = 1.5
          k_rectangle.line_stipple = Kuix::LINE_STIPPLE_DOTTED
          k_rectangle.color = _get_normal_color
          k_rectangle.transformation = t
          @space.append(k_rectangle)
        end

        o_min = bounds.min.offset(X_AXIS, -section_offset).offset!(Y_AXIS, -section_offset)
        o_max = bounds.max.offset(X_AXIS, section_offset).offset!(Y_AXIS, section_offset)

        o_bounds = Geom::BoundingBox.new
        o_bounds.add(o_min, o_max)

        k_rectangle = Kuix::RectangleMotif.new
        k_rectangle.bounds.origin.copy!(o_bounds.min)
        k_rectangle.bounds.size.set!(o_bounds.width, o_bounds.height, 0)
        k_rectangle.line_width = @locked_normal ? 3 : 1.5
        k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CONSTRUCTION)
        k_rectangle.color = _get_normal_color
        k_rectangle.transformation = t
        @space.append(k_rectangle)

        Sketchup.vcb_value = "#{bounds.width}; #{bounds.height}"

        w_screen_point = view.screen_coords(bounds.min.offset(X_AXIS, bounds.width / 2).transform(t))
        h_screen_point = view.screen_coords(bounds.min.offset(Y_AXIS, bounds.height / 2).transform(t))

        k_label_w = Kuix::Label.new
        k_label_w.text = bounds.width.to_s
        k_label_w.layout_data = Kuix::StaticLayoutData.new(w_screen_point.x, w_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        k_label_w.set_style_attribute(:color, Kuix::COLOR_X)
        k_label_w.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
        k_label_w.set_style_attribute(:border_color, _get_normal_color)
        k_label_w.border.set_all!(@unit * 0.25)
        k_label_w.padding.set!(@unit * 0.5, @unit * 0.5, @unit * 0.3, @unit * 0.5)
        k_label_w.text_size = @unit * 2.5
        @floating_panel.append(k_label_w)

        k_label_h = Kuix::Label.new
        k_label_h.text = bounds.height.to_s
        k_label_h.layout_data = Kuix::StaticLayoutData.new(h_screen_point.x, h_screen_point.y, -1, -1, Kuix::Anchor.new(Kuix::Anchor::CENTER))
        k_label_h.set_style_attribute(:color, Kuix::COLOR_Y)
        k_label_h.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
        k_label_h.set_style_attribute(:border_color, _get_normal_color)
        k_label_h.border.set_all!(@unit * 0.25)
        k_label_h.padding.set!(@unit * 0.5, @unit * 0.5, @unit * 0.3, @unit * 0.5)
        k_label_h.text_size = @unit * 2.5
        @floating_panel.append(k_label_h)

      else

        # Pick first point

        if @mouse_ip.vertex

          vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)

          # k_points = Kuix::Points.new
          # k_points.add_points([ vertex_manipulator.point ])
          # k_points.size = 30
          # k_points.style = Kuix::POINT_STYLE_OPEN_SQUARE
          # k_points.color = Kuix::COLOR_MAGENTA
          # @space.append(k_points)

          # if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)
          #
          #   face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
          #   @space.append(k_mesh)
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
          # @space.append(k_segments)

          if @mouse_ip.face && @mouse_ip.edge.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            @normal = face_manipulator.normal

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(face_manipulator.triangles)
            # k_mesh.background_color = Sketchup::Color.new(255, 255, 0, 50)
            # @space.append(k_mesh)

          end

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

          @normal = face_manipulator.normal

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(face_manipulator.triangles)
          # k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 50)
          # @space.append(k_mesh)

        elsif @locked_normal.nil?

          @direction = nil
          @normal = _get_active_z_axis

        end

        @snap_ip.copy!(@mouse_ip) unless @snap_ip.valid?

      end

      # k_points = Kuix::Points.new
      # k_points.add_points([ @snap_ip.position ])
      # k_points.size = 30
      # k_points.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
      # k_points.color = Kuix::COLOR_YELLOW
      # @space.append(k_points)

      # k_axes_helper = Kuix::AxesHelper.new
      # k_axes_helper.transformation = Geom::Transformation.axes(@picked_first_ip.position, *_get_axes)
      # @space.append(k_axes_helper)

      view.tooltip = @snap_ip.tooltip if @snap_ip.valid?
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      return true if super

      @mouse_x = x
      @mouse_y = y

      if !_picked_first_point?
        @picked_first_ip.copy!(@snap_ip)
        _refresh
      elsif !_picked_second_point?
        if _valid_rectangle?
          @picked_second_ip.copy!(@snap_ip)
          if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_TOOLS, ACTION_OPTION_TOOLS_PUSHPULL)
            push_cursor(CURSOR_PENCIL_PUSHPULL)
            _refresh
          elsif fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_TOOLS, ACTION_OPTION_TOOLS_MOVE)
            @picked_third_ip.copy!(@snap_ip)
            push_cursor(CURSOR_MOVE)
            _refresh
          else
            _reset
          end
        else
          UI.beep
        end
      elsif !_picked_third_point?
        if _valid_box?
          @picked_third_ip.copy!(@snap_ip)
          _create_entity
          if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_TOOLS, ACTION_OPTION_TOOLS_MOVE)
            push_cursor(CURSOR_MOVE)
            _refresh
          else
            _reset
          end
        else
          UI.beep
        end
      elsif !_picked_fourth_point?
        @picked_fourth_ip.copy!(@snap_ip)
        _copy_entity
        _reset
      else
        UI.beep
      end

      view.lock_inference if view.inference_locked?

      _update_status_text
    end

    def onKeyUp(key, repeat, flags, view)
      return true if super
    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      if key == VK_ALT
        store_action_option_value(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED, !fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED), true) if _picked_first_point? && !_picked_second_point?
        store_action_option_value(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_BOX_CENTRED, !fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_BOX_CENTRED), true) if _picked_first_point? && _picked_second_point?
        _refresh
      end
      if _picked_third_point?
        if view.inference_locked?
          view.lock_inference
        else
          if key == VK_RIGHT
            view.lock_inference(@picked_third_ip, Sketchup::InputPoint.new(@picked_third_ip.position.offset(_get_active_x_axis)))
            _refresh
          elsif key == VK_LEFT
            view.lock_inference(@picked_third_ip, Sketchup::InputPoint.new(@picked_third_ip.position.offset(_get_active_y_axis)))
            _refresh
          elsif key == VK_UP
            view.lock_inference(@picked_third_ip, Sketchup::InputPoint.new(@picked_third_ip.position.offset(_get_active_z_axis)))
            _refresh
          end
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

    def onUserText(text, view)

      if _picked_third_point?

        distance = text.to_l

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p3 = points[2].transform(ti)
        p4 = points[3].transform(ti)

        v = p3.vector_to(p4)

        distance = v.length if distance == 0

        @picked_fourth_ip = Sketchup::InputPoint.new(p3.offset(v, distance).transform(t))

        _copy_entity
        _reset

        Sketchup.vcb_value = ''

      elsif _picked_second_point?

        thickness = text.to_l

        t = _get_transformation
        ti = t.inverse

        points = _get_picked_points
        p2 = points[1].transform(ti)
        p3 = points[2].transform(ti)

        thickness *= -1 if p3.z < p2.z

        thickness = p3.z - p2.z if thickness == 0
        thickness /= 2 if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_BOX_CENTRED)

        @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, thickness).transform(t))

        _create_entity

        if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_TOOLS, ACTION_OPTION_TOOLS_MOVE)
          push_cursor(CURSOR_MOVE)
          _refresh
        else
          _reset
        end

        Sketchup.vcb_value = ''

      elsif _picked_first_point?

        d1, d2, d3 = text.split(';')

        if d1 || d2

          length = d1 ? d1.to_l : 0
          width = d2 ? d2.to_l : 0

          t = _get_transformation
          ti = t.inverse

          p1 = @picked_first_ip.position.transform(ti)
          p2 = @snap_ip.position.transform(ti)

          length *= -1 if p2.x < p1.x
          length = p2.x - p1.x if length == 0
          length = length / 2 if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED)

          width *= -1 if p2.y < p1.y
          width = p2.y - p1.y if width == 0
          width = width / 2 if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED)

          @picked_second_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p1.x + length, p1.y + width, p1.z).transform(t))

          push_cursor(CURSOR_PENCIL_PUSHPULL) unless d3

          Sketchup.vcb_value = ''

          _refresh

        end
        if d3

          thickness = d3.to_l

          t = _get_transformation
          ti = t.inverse

          p2 = @picked_second_ip.position.transform(ti)
          p3 = @picked_third_ip.position.transform(ti)

          thickness *= -1 if p3.z < p2.z
          thickness = p3.z - p2.z if thickness == 0
          thickness = thickness / 2 if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_BOX_CENTRED)

          @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

          _create_entity
          _reset

          Sketchup.vcb_value = ''

        end
      end

    end

    def draw(view)
      super
      @mouse_ip.draw(view) if @mouse_ip.valid?
    end

    def enableVCB?
      true
    end

    def getExtents
      return super if _get_picked_points.empty?
      bounds = Geom::BoundingBox.new
      bounds.add(_get_picked_points)
      bounds
    end

    private

    def _fetch_section_offset
      fetch_action_option_value(ACTION_DRAW_BOX, ACTION_OPTION_OFFSET, ACTION_OPTION_OFFSET_SECTION_OFFSET).to_l
    end

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
      Geom::Transformation.axes(@picked_first_ip.position, *_get_axes)
    end

    def _update_status_text
      if _picked_second_point?
        Sketchup.status_text = 'Select end point.'
      elsif _picked_first_point?
        Sketchup.status_text = 'Select second point.'
      else
        Sketchup.status_text = 'Select start point.'
      end
    end

    def _refresh
      onMouseMove(0, @mouse_x, @mouse_y, Sketchup.active_model.active_view)
    end

    def _reset
      @mouse_ip.clear
      @snap_ip.clear
      @picked_first_ip.clear
      @picked_second_ip.clear
      @picked_third_ip.clear
      @picked_fourth_ip.clear
      @direction = nil
      @locked_normal = nil
      @normal = _get_active_z_axis
      @floating_panel.remove_all
      @space.remove_all
      _update_status_text
      Sketchup.vcb_value = ''
      pop_to_root_cursor
    end

    def _picked_first_point?
      @picked_first_ip.valid?
    end

    def _picked_second_point?
      @picked_second_ip.valid?
    end

    def _picked_third_point?
      @picked_third_ip.valid?
    end

    def _picked_fourth_point?
      @picked_fourth_ip.valid?
    end

    def _valid_rectangle?

      points = _get_picked_points
      return false if points.length < 2

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)

      p2.x - p1.x != 0 && p2.y - p1.y != 0
    end

    def _valid_box?

      points = _get_picked_points
      return false if points.length < 3

      t = _get_transformation
      ti = t.inverse

      p1 = points[0].transform(ti)
      p3 = points[2].transform(ti)

      p3.x - p1.x != 0 && p3.y - p1.y != 0 && p3.z - p1.z != 0
    end

    def _get_picked_points
      points = []
      points << @picked_first_ip.position if _picked_first_point?
      points << @picked_second_ip.position if _picked_second_point?
      points << @picked_third_ip.position if _picked_third_point?
      points << @picked_fourth_ip.position if _picked_fourth_point?
      points << @snap_ip.position if @snap_ip.valid?

      if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_RECTANGLE_CENTRED) && _picked_first_point? && points.length > 1
        points[0] = points[0].offset(points[1].vector_to(points[0]))
      end
      if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_BOX_CENTRED) && _picked_second_point? && points.length > 2
        offset = points[2].vector_to(points[1])
        points[0] = points[0].offset(offset)
        points[1] = points[1].offset(offset)
      end

      points
    end

    def _get_normal_color
      return Kuix::COLOR_X if @normal.parallel?(_get_active_x_axis)
      return Kuix::COLOR_Y if @normal.parallel?(_get_active_y_axis)
      return Kuix::COLOR_Z if @normal.parallel?(_get_active_z_axis)
      return Kuix::COLOR_MAGENTA if @normal == @locked_normal
      Kuix::COLOR_BLACK
    end

    def _create_entity

      model = Sketchup.active_model
      model.start_operation('Create Part', true)

      t = _get_transformation
      ti = t.inverse

      points = _get_picked_points
      p1 = points[0].transform(ti)
      p3 = points[2].transform(ti)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, p3)

      section_offset = _fetch_section_offset
      o_min = bounds.min.offset(X_AXIS, -section_offset).offset!(Y_AXIS, -section_offset)
      o_max = bounds.max.offset(X_AXIS, section_offset).offset!(Y_AXIS, section_offset)

      o_bounds = Geom::BoundingBox.new
      o_bounds.add(o_min, o_max)

      if fetch_action_option_enabled(ACTION_DRAW_BOX, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CONSTRUCTION)

        group = model.active_entities.add_group
        group.transformation = t

        group.entities.add_cline(o_bounds.corner(0), o_bounds.corner(1))
        group.entities.add_cline(o_bounds.corner(1), o_bounds.corner(3))
        group.entities.add_cline(o_bounds.corner(3), o_bounds.corner(2))
        group.entities.add_cline(o_bounds.corner(2), o_bounds.corner(0))

        group.entities.add_cline(o_bounds.corner(4), o_bounds.corner(5))
        group.entities.add_cline(o_bounds.corner(5), o_bounds.corner(7))
        group.entities.add_cline(o_bounds.corner(7), o_bounds.corner(6))
        group.entities.add_cline(o_bounds.corner(6), o_bounds.corner(4))

        group.entities.add_cline(o_bounds.corner(0), o_bounds.corner(4))
        group.entities.add_cline(o_bounds.corner(1), o_bounds.corner(5))
        group.entities.add_cline(o_bounds.corner(3), o_bounds.corner(7))
        group.entities.add_cline(o_bounds.corner(2), o_bounds.corner(6))

        @entity = group

      else

        definition = model.definitions.add('Part')

        face = definition.entities.add_face([
                                              o_bounds.corner(0),
                                              o_bounds.corner(1),
                                              o_bounds.corner(3),
                                              o_bounds.corner(2)
                                            ])
        face.reverse! if face.normal.samedirection?(Z_AXIS)
        face.pushpull(-o_bounds.depth)

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

end