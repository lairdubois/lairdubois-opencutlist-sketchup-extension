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

      @direction = X_AXIS
      @normal = Z_AXIS

      update_ui
      SKETCHUP_CONSOLE.clear

      set_root_cursor(CURSOR_PENCIL_RECTANGLE)

    end

    def onResume(view)
      super
      update_ui
    end

    def onCancel(reason, view)
      reset_tool
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      return true if super

      @space.remove_all

      unless picked_second_point?
        if @mouse_ip.vertex

          vertex_manipulator = VertexManipulator.new(@mouse_ip.vertex, @mouse_ip.transformation)

          vertex_preview = Kuix::Points.new
          vertex_preview.add_points([ vertex_manipulator.point ])
          vertex_preview.size = 30
          vertex_preview.style = Kuix::POINT_STYLE_OPEN_SQUARE
          vertex_preview.color = Kuix::COLOR_MAGENTA
          @space.append(vertex_preview)

        elsif @mouse_ip.edge

          plane_manipulator = PlaneManipulator.new(Geom.fit_plane_to_points([ @picked_first_ip.position, @mouse_ip.edge.start.position, @mouse_ip.edge.end.position ]), @mouse_ip.transformation)

          @normal = plane_manipulator.normal

          edge_manipulator = EdgeManipulator.new(@mouse_ip.edge, @mouse_ip.transformation)

          edge_preview = Kuix::Segments.new
          edge_preview.add_segments(edge_manipulator.segment)
          edge_preview.color = Kuix::COLOR_MAGENTA
          edge_preview.line_width = 4
          edge_preview.on_top = true
          @space.append(edge_preview)

        elsif @mouse_ip.face

          @direction = X_AXIS

          if @mouse_ip.face && @mouse_ip.degrees_of_freedom == 2

            face_manipulator = FaceManipulator.new(@mouse_ip.face, @mouse_ip.transformation)

            @normal = face_manipulator.normal

            face_preview = Kuix::Mesh.new
            face_preview.add_triangles(face_manipulator.triangles)
            face_preview.background_color = Sketchup::Color.new(255, 0, 255, 50)
            @space.append(face_preview)

          end

        else
          @normal = Z_AXIS
        end

      end

      if picked_second_point?
        @mouse_ip.pick(view, x, y)

        if @mouse_ip.degrees_of_freedom > 2 || @mouse_ip.position.distance_to_plane([ @picked_second_ip.position, @normal ]).round(6) == 0
          _, picked_point = Geom::closest_points([ @picked_second_ip.position, @normal ], view.pickray(x, y))
          @picked_third_ip = Sketchup::InputPoint.new(picked_point)
        else
          @picked_third_ip.copy!(@mouse_ip)
        end

        t = get_transformation
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

      elsif picked_first_point?
        @mouse_ip.pick(view, x, y, @picked_first_ip)

        t = get_transformation
        ti = t.inverse

        points = picked_points
        p1 = points.first.transform(ti)
        p2 = points.last.transform(ti)

        bounds = Geom::BoundingBox.new
        bounds.add(p1, p2)

        rect = Kuix::RectangleMotif.new
        rect.bounds.origin.copy!(bounds.min)
        rect.bounds.size.set!(bounds.width, bounds.height, bounds.depth)
        rect.line_width = 2
        rect.color = Kuix::COLOR_DARK_GREY
        rect.transformation = t
        @space.append(rect)

        Sketchup.vcb_value = "#{bounds.width};#{bounds.height}"

      else
        @mouse_ip.pick(view, x, y)
      end

      x_axis, y_axis, z_axis = @normal.axes

      axes_helper = Kuix::AxesHelper.new
      axes_helper.transformation = Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)
      @space.append(axes_helper)

      view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      if picked_first_point? && picked_second_point?
        create_entity
        reset_tool
      else
        if !picked_first_point?
          @picked_first_ip.copy!(@mouse_ip)
        elsif !picked_second_point?
          @picked_second_ip.copy!(@mouse_ip)
          push_cursor(CURSOR_PENCIL_PUSHPULL)
        end
      end

      update_ui
      view.invalidate
    end

    def onKeyDown(key, repeat, flags, view)
      if key == VK_RIGHT
        @locked_normal = X_AXIS
        @normal = @locked_normal
      elsif key == VK_LEFT
        @locked_normal = Y_AXIS
        @normal = @locked_normal
      elsif key == VK_UP
        @locked_normal = Z_AXIS
        @normal = @locked_normal
      end
    end

    def onUserText(text, view)

      if picked_second_point?

        thickness = text.to_l

        t = get_transformation
        ti = t.inverse

        p2 = @picked_second_ip.position.transform(ti)
        p3 = @picked_third_ip.position.transform(ti)

        thickness *= -1 if p3.z < p2.z

        thickness = p3.z - p2.z if thickness == 0

        @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

        create_entity
        reset_tool

        Sketchup.vcb_value = ''

      elsif picked_first_point?

        d1, d2, d3 = text.split(';')

        if d1 || d2

          length = d1 ? d1.to_l : 0
          width = d2 ? d2.to_l : 0

          t = get_transformation
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

          update_ui
          view.invalidate

        end
        if d3

          thickness = d3.to_l

          t = get_transformation
          ti = t.inverse

          p2 = @picked_second_ip.position.transform(ti)
          p3 = @picked_third_ip.position.transform(ti)

          thickness *= -1 if p3.z < p2.z

          thickness = p3.z - p2.z if thickness == 0

          @picked_third_ip = Sketchup::InputPoint.new(Geom::Point3d.new(p2.x, p2.y, p2.z + thickness).transform(t))

          create_entity
          reset_tool

          Sketchup.vcb_value = ''

        end
      end

    end

    # Here we have hard coded a special ID for the pencil cursor in SketchUp.
    # Normally you would use `UI.create_cursor(cursor_path, 0, 0)` instead
    # with your own custom cursor bitmap:
    #
    #   CURSOR_PENCIL = UI.create_cursor(cursor_path, 0, 0)
    # def onSetCursor
    #   # Note that `onSetCursor` is called frequently so you should not do much
    #   # work here. At most you switch between different cursor representing
    #   # the state of the tool.
    #   UI.set_cursor(CURSOR_PENCIL)
    # end

    def draw(view)
      super
      if @picked_third_ip.valid?
        @picked_third_ip.draw(view)
      elsif @mouse_ip.valid?
        @mouse_ip.draw(view)
      end
    end

    def enableVCB?
      picked_first_point?
    end

    def getExtents
      return super if picked_points.empty?
      bounds = Geom::BoundingBox.new
      bounds.add(picked_points)
      bounds
    end

    private

    def get_transformation
      x_axis, y_axis, z_axis = @normal.axes
      Geom::Transformation.axes(@picked_first_ip.position, x_axis, y_axis, z_axis)
    end

    def update_ui
      if picked_second_point?
        Sketchup.status_text = 'Select end point.'
      elsif picked_first_point?
        Sketchup.status_text = 'Select second point.'
      else
        Sketchup.status_text = 'Select start point.'
      end
    end

    def reset_tool
      @mouse_ip.clear
      @picked_first_ip.clear
      @picked_second_ip.clear
      @picked_third_ip.clear
      @direction = X_AXIS
      @locked_normal = nil
      @normal = Z_AXIS
      Sketchup.active_model.active_view.lock_inference
      @space.remove_all
      update_ui
      Sketchup.vcb_value = ''
      pop_to_root_cursor
    end

    def picked_first_point?
      @picked_first_ip.valid?
    end

    def picked_second_point?
      @picked_second_ip.valid?
    end

    def picked_points
      points = []
      points << @picked_first_ip.position if picked_first_point?
      points << @picked_second_ip.position if picked_second_point?
      points << @picked_third_ip.position if @picked_third_ip.valid?
      points << @mouse_ip.position if @mouse_ip.valid?
      points
    end

    def create_entity

      model = Sketchup.active_model
      model.start_operation('Create Part', true)

      t = get_transformation
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
      face.pushpull(p1.z < pe.z ? -bounds.depth : bounds.depth, bounds.corner(4) - bounds.corner(0))
      face.reverse! if face.normal.samedirection?(Z_AXIS)

      model.active_entities.add_instance(definition, t)

      model.commit_operation

    end

  end

end