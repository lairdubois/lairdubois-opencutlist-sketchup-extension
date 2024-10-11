module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../manipulator/vertex_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/plane_manipulator'

  class BoxTool < Kuix::KuixTool

    COLOR_BRAND = Sketchup::Color.new(247, 127, 0).freeze
    COLOR_BRAND_DARK = Sketchup::Color.new(62, 59, 51).freeze
    COLOR_BRAND_LIGHT = Sketchup::Color.new(214, 212, 205).freeze

    CURSOR_PENCIL = 632
    CURSOR_PENCIL_RECTANGLE = 637
    CURSOR_PENCIL_PUSHPULL = 639

    def initialize
      super(false, false)

      @mouse_x = -1
      @mouse_y = -1

    end

    def get_unit(view = nil)
      return @unit unless @unit.nil?
      return 3 if view && Sketchup.active_model.nil?
      view = Sketchup.active_model.active_view if view.nil?
      if view.vpheight > 2000
        @unit = 8
      elsif view.vpheight > 1000
        @unit = 6
      elsif view.vpheight > 500
        @unit = 4
      else
        @unit = 3
      end
      @unit
    end

    def get_text_unit_factor
      case PLUGIN.language
      when 'ar'
        return 1.5
      else
        return 1.0
      end
    end

    def setup_entities(view)

      # 2D
      # --------

      @canvas.layout = Kuix::StaticLayout.new

      unit = get_unit(view)

      # -- TOP

      @top_panel = Kuix::Panel.new
      @top_panel.layout_data = Kuix::StaticLayoutData.new(0, 0, 1.0, -1)
      @top_panel.layout = Kuix::BorderLayout.new
      @canvas.append(@top_panel)

        # Actions panel

        actions_panel = Kuix::Panel.new
        actions_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::NORTH)
        actions_panel.layout = Kuix::BorderLayout.new
        actions_panel.set_style_attribute(:background_color, COLOR_BRAND_DARK)
        @actions_panel = actions_panel
        @top_panel.append(actions_panel)

          actions_lbl = Kuix::Label.new
          actions_lbl.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::WEST)
          actions_lbl.padding.set!(0, unit * 4, 0, unit * 4)
          actions_lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
          actions_lbl.text = "DESSINER"
          actions_lbl.text_size = unit * 3 * get_text_unit_factor
          actions_lbl.text_bold = true
          actions_panel.append(actions_lbl)

          actions_btns_panel = Kuix::Panel.new
          actions_btns_panel.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::CENTER)
          actions_btns_panel.layout = Kuix::InlineLayout.new(true, 0, Kuix::Anchor.new(Kuix::Anchor::CENTER))
          actions_panel.append(actions_btns_panel)

            actions_btn = Kuix::Button.new
            actions_btn.layout = Kuix::BorderLayout.new
            actions_btn.border.set!(0, unit / 4, 0, unit / 4)
            actions_btn.min_size.set_all!(unit * 10)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_DARK.blend(Kuix::COLOR_WHITE, 0.8))
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:border_color, COLOR_BRAND, :selected)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_DARK)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
            actions_btn.set_style_attribute(:background_color, COLOR_BRAND, :selected)
            lbl = actions_btn.append_static_label("Rectangle", unit * 3 * get_text_unit_factor)
            lbl.padding.set!(0, unit * 4, 0, unit * 4)
            lbl.set_style_attribute(:color, COLOR_BRAND_LIGHT)
            lbl.set_style_attribute(:color, COLOR_BRAND_DARK, :hover)
            lbl.set_style_attribute(:color, Kuix::COLOR_WHITE, :selected)
            actions_btns_panel.append(actions_btn)

          # Help Button

          help_btn = Kuix::Button.new
          help_btn.layout_data = Kuix::BorderLayoutData.new(Kuix::BorderLayoutData::EAST)
          help_btn.layout = Kuix::GridLayout.new
          help_btn.set_style_attribute(:background_color, Kuix::COLOR_WHITE)
          help_btn.set_style_attribute(:background_color, COLOR_BRAND_LIGHT, :hover)
          lbl = help_btn.append_static_label(PLUGIN.get_i18n_string("default.help").upcase, unit * 3 * get_text_unit_factor)
          lbl.min_size.set!(unit * 15, 0)
          lbl.padding.set!(0, unit * 4, 0, unit * 4)
          lbl.set_style_attribute(:color, COLOR_BRAND_DARK)
          actions_panel.append(help_btn)

    end

    def onActivate(view)
      super

      @mouse_ip = Sketchup::InputPoint.new
      @picked_first_ip = Sketchup::InputPoint.new
      @picked_second_ip = Sketchup::InputPoint.new
      @picked_third_ip = Sketchup::InputPoint.new

      @locked_normal = nil

      @direction = nil
      @normal = _get_active_z_axis

      _update_status_text
      SKETCHUP_CONSOLE.clear

      set_root_cursor(CURSOR_PENCIL_RECTANGLE)

    end

    def onResume(view)
      super
      _update_status_text
    end

    def onCancel(reason, view)
      if _picked_second_point?
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

      @mouse_ip.pick(view, x, y)

      SKETCHUP_CONSOLE.clear
      puts "---"
      puts "vertex = #{@mouse_ip.vertex}"
      puts "edge = #{@mouse_ip.edge}"
      puts "face = #{@mouse_ip.face}"
      puts "instance_path.length = #{@mouse_ip.instance_path.length}"
      puts "transformation.identity? = #{@mouse_ip.transformation.identity?}"
      puts "degrees_of_freedom = #{@mouse_ip.degrees_of_freedom}"
      puts "---"

      @space.remove_all

      if _picked_second_point?

        # Pick third point

        if @mouse_ip.degrees_of_freedom > 2 ||
          @mouse_ip.instance_path.length == 0 ||
          @mouse_ip.position.on_plane?([ @picked_second_ip.position, @normal ]) ||
          @mouse_ip.face && @mouse_ip.vertex.nil? && @mouse_ip.edge.nil? && !@mouse_ip.face.normal.transform(@mouse_ip.transformation).parallel?(@normal)
          _, picked_point = Geom::closest_points([ @picked_second_ip.position, @normal ], view.pickray(x, y))
          @picked_third_ip = Sketchup::InputPoint.new(picked_point)
        else
          @picked_third_ip.copy!(@mouse_ip)
        end

        t = _get_transformation
        ti = t.inverse

        points = picked_points
        p1 = points[0].transform(ti)
        p2 = points[1].transform(ti)
        p3 = points[2].transform(ti)

        pe = Geom::Point3d.new(p2.x, p2.y, p3.z)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, pe)

        box = Kuix::BoxMotif.new
        box.bounds.origin.copy!(bounds.min)
        box.bounds.size.set!(bounds.width, bounds.height, bounds.depth)
        box.line_width = 2
        box.color = Kuix::COLOR_DARK_GREY
        box.transformation = t
        @space.append(box)

        Sketchup.vcb_value = bounds.depth

      elsif _picked_first_point?

        # Pick second point

        z_plane = [ @picked_first_ip.position, _get_active_z_axis ]

        if @mouse_ip.position.on_plane?(z_plane)

          @normal = _get_active_z_axis

        elsif @mouse_ip.vertex

          vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)

          vertex_preview = Kuix::Points.new
          vertex_preview.add_points([ vertex_manipulator.point ])
          vertex_preview.size = 30
          vertex_preview.style = Kuix::POINT_STYLE_OPEN_SQUARE
          vertex_preview.color = Kuix::COLOR_MAGENTA
          @space.append(vertex_preview)

          if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            face_preview = Kuix::Mesh.new
            face_preview.add_triangles(face_manipulator.triangles)
            face_preview.background_color = Sketchup::Color.new(255, 255, 0, 50)
            @space.append(face_preview)

          end

        elsif @mouse_ip.edge

          t = @mouse_ip.transformation
          ps = @mouse_ip.edge.start.position.transform(t)
          pe = @mouse_ip.edge.end.position.transform(t)

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)
          plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_first_ip.position, ps, pe ]))

          @direction = ps.vector_to(pe)
          @normal = plane_manipulator.normal

          pts = Kuix::Points.new
          pts.add_points([ @picked_first_ip.position, ps, pe ])
          pts.size = 30
          pts.style = Kuix::POINT_STYLE_OPEN_TRIANGLE
          pts.color = Kuix::COLOR_BLUE
          @space.append(pts)

          edge_preview = Kuix::Segments.new
          edge_preview.add_segments(edge_manipulator.segment)
          edge_preview.color = Kuix::COLOR_MAGENTA
          edge_preview.line_width = 4
          edge_preview.on_top = true
          @space.append(edge_preview)

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

          if @picked_first_ip.position.on_plane?(face_manipulator.plane)

            @normal = face_manipulator.normal
            @direction = nil unless @direction.nil? || @direction.perpendicular?(@normal)

          else

            p1 = @picked_first_ip.position
            p2 = @mouse_ip.position
            p3 = @mouse_ip.position.project_to_plane(z_plane)

            pts = Kuix::Points.new
            pts.add_points([ p1, p2, p3 ])
            pts.size = 30
            pts.style = Kuix::POINT_STYLE_PLUS
            pts.color = Kuix::COLOR_RED
            @space.append(pts)

            plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
            plane_manipulator = PlaneManipulator.new(plane)

            @direction = _get_active_z_axis
            @normal = plane_manipulator.normal

          end

          face_preview = Kuix::Mesh.new
          face_preview.add_triangles(face_manipulator.triangles)
          face_preview.background_color = Sketchup::Color.new(255, 0, 255, 50)
          @space.append(face_preview)

        else

          if @mouse_ip.degrees_of_freedom > 2
            picked_point = Geom::intersect_line_plane(view.pickray(x, y), z_plane)
            @mouse_ip = Sketchup::InputPoint.new(picked_point) unless picked_point.nil?
          end

          if !@mouse_ip.position.on_plane?(z_plane)

            p1 = @picked_first_ip.position
            p2 = @mouse_ip.position
            p3 = @mouse_ip.position.project_to_plane(z_plane)

            pts = Kuix::Points.new
            pts.add_points([ p1, p2, p3 ])
            pts.size = 30
            pts.style = Kuix::POINT_STYLE_CROSS
            pts.color = Kuix::COLOR_RED
            @space.append(pts)

            plane = Geom.fit_plane_to_points([ p1, p2, p3 ])
            plane_manipulator = PlaneManipulator.new(plane)

            @direction = _get_active_z_axis
            @normal = plane_manipulator.normal

          else

            @direction = nil
            @normal = _get_active_z_axis

          end

        end

        t = _get_transformation
        ti = t.inverse

        points = picked_points
        p1 = points.first.transform(ti)
        p2 = points.last.transform(ti)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, p2)

        rect = Kuix::RectangleMotif.new
        rect.bounds.origin.copy!(bounds.min)
        rect.bounds.size.set!(bounds.width, bounds.height, 0)
        rect.line_width = 2
        rect.color = Kuix::COLOR_DARK_GREY
        rect.transformation = t
        @space.append(rect)

        Sketchup.vcb_value = "#{bounds.width};#{bounds.height}"

      else

        # Pick first point

        if @mouse_ip.vertex

          vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)

          vertex_preview = Kuix::Points.new
          vertex_preview.add_points([ vertex_manipulator.point ])
          vertex_preview.size = 30
          vertex_preview.style = Kuix::POINT_STYLE_OPEN_SQUARE
          vertex_preview.color = Kuix::COLOR_MAGENTA
          @space.append(vertex_preview)

          if @mouse_ip.face && @mouse_ip.vertex.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            face_preview = Kuix::Mesh.new
            face_preview.add_triangles(face_manipulator.triangles)
            face_preview.background_color = Sketchup::Color.new(255, 255, 0, 50)
            @space.append(face_preview)

          end

        elsif @mouse_ip.edge

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          edge_preview = Kuix::Segments.new
          edge_preview.add_segments(edge_manipulator.segment)
          edge_preview.color = Kuix::COLOR_MAGENTA
          edge_preview.line_width = 4
          edge_preview.on_top = true
          @space.append(edge_preview)

          if @mouse_ip.face && @mouse_ip.edge.faces.include?(@mouse_ip.face)

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            @normal = face_manipulator.normal

            face_preview = Kuix::Mesh.new
            face_preview.add_triangles(face_manipulator.triangles)
            face_preview.background_color = Sketchup::Color.new(255, 255, 0, 50)
            @space.append(face_preview)

          end

        elsif @mouse_ip.face && @mouse_ip.instance_path.length > 0

          face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

          @normal = face_manipulator.normal

          face_preview = Kuix::Mesh.new
          face_preview.add_triangles(face_manipulator.triangles)
          face_preview.background_color = Sketchup::Color.new(255, 0, 255, 50)
          @space.append(face_preview)

        else
          @direction = nil
          @normal = _get_active_z_axis
        end

      end

      axes_helper = Kuix::AxesHelper.new
      axes_helper.transformation = Geom::Transformation.axes(ORIGIN, *_get_axes)
      @space.append(axes_helper)

      view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      return true if super

      if _picked_first_point? && _picked_second_point?
        _create_entity
        _reset
      else
        if !_picked_first_point?
          @picked_first_ip.copy!(@mouse_ip)
        elsif !_picked_second_point?
          @picked_second_ip.copy!(@mouse_ip)
          push_cursor(CURSOR_PENCIL_PUSHPULL)
        end
      end

      _update_status_text
      view.invalidate
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_RIGHT
        @locked_normal = _get_active_x_axis
        @normal = @locked_normal
        _refresh
      elsif key == VK_LEFT
        @locked_normal = _get_active_y_axis
        @normal = @locked_normal
        _refresh
      elsif key == VK_UP
        @locked_normal = _get_active_z_axis
        @normal = @locked_normal
        _refresh
      end
    end

    def onUserText(text, view)

      if _picked_second_point?

        thickness = text.to_l

        t = _get_transformation
        ti = t.inverse

        p2 = @picked_second_ip.position.transform(ti)
        p3 = @picked_third_ip.position.transform(ti)

        thickness *= -1 if p3.z < p2.z

        thickness = p3.z - p2.z if thickness == 0

        @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

        _create_entity
        _reset

        Sketchup.vcb_value = ''

      elsif _picked_first_point?

        d1, d2, d3 = text.split(';')

        if d1 || d2

          length = d1 ? d1.to_l : 0
          width = d2 ? d2.to_l : 0

          t = _get_transformation
          ti = t.inverse

          p1 = @picked_first_ip.position.transform(ti)
          p2 = @mouse_ip.position.transform(ti)

          length *= -1 if p2.x < p1.x
          width *= -1 if p2.y < p1.y

          length = p2.x - p1.x if length == 0
          width = p2.y - p1.y if width == 0

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

          @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

          _create_entity
          _reset

          Sketchup.vcb_value = ''

        end
      end

    end

    def draw(view)
      super
      if @picked_third_ip.valid?
        @picked_third_ip.draw(view)
      elsif @mouse_ip.valid?
        @mouse_ip.draw(view)
      end
    end

    def enableVCB?
      _picked_first_point?
    end

    def getExtents
      return super if picked_points.empty?
      bounds = Geom::BoundingBox.new
      bounds.add(picked_points)
      bounds
    end

    private

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
        x_axis, y_axis, z_axis = @normal.axes
      else
        x_axis = @direction
        z_axis = @normal
        y_axis = z_axis * x_axis
      end

      [ x_axis, y_axis, z_axis ]
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
      @picked_first_ip.clear
      @picked_second_ip.clear
      @picked_third_ip.clear
      @direction = nil
      @locked_normal = nil
      @normal = _get_active_z_axis
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

    def picked_points
      points = []
      points << @picked_first_ip.position if _picked_first_point?
      points << @picked_second_ip.position if _picked_second_point?
      points << @picked_third_ip.position if @picked_third_ip.valid?
      points << @mouse_ip.position if @mouse_ip.valid?
      points
    end

    def _create_entity

      model = Sketchup.active_model
      model.start_operation('Create Part', true)

      t = _get_transformation
      ti = t.inverse

      points = picked_points
      p1 = points[0].transform(ti)
      p2 = points[1].transform(ti)
      p3 = points[2].transform(ti)

      pe = Geom::Point3d.new(p2.x, p2.y, p3.z)

      bounds = Geom::BoundingBox.new
      bounds.add(p1, pe)

      definition = model.definitions.add('Part')

      face = definition.entities.add_face([
                                       bounds.corner(0),
                                       bounds.corner(1),
                                       bounds.corner(3),
                                       bounds.corner(2)
                                     ])
      face.pushpull(p1.z < pe.z ? -bounds.depth : bounds.depth, bounds.corner(0).vector_to(bounds.corner(0)))
      face.reverse! if face.normal.samedirection?(Z_AXIS)

      model.active_entities.add_instance(definition, t)

      model.commit_operation

    end

  end

end