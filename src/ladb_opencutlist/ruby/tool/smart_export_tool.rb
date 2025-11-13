module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geometrix/geometrix'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/loop_manipulator'
  require_relative '../worker/common/common_write_drawing2d_worker'
  require_relative '../worker/common/common_write_drawing3d_worker'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_drawing_projection_worker'
  require_relative '../observer/plugin_observer'

  class SmartExportTool < SmartTool

    ACTION_EXPORT_PART_3D = 0
    ACTION_EXPORT_PART_2D = 1
    ACTION_EXPORT_FACE = 2
    ACTION_EXPORT_PATHS = 3

    ACTION_OPTION_FILE_FORMAT = 'file_format'
    ACTION_OPTION_UNIT = 'unit'
    ACTION_OPTION_FACES = 'faces'
    ACTION_OPTION_OPTIONS = 'options'

    ACTION_OPTION_FILE_FORMAT_DXF = FILE_FORMAT_DXF
    ACTION_OPTION_FILE_FORMAT_STL = FILE_FORMAT_STL
    ACTION_OPTION_FILE_FORMAT_OBJ = FILE_FORMAT_OBJ
    ACTION_OPTION_FILE_FORMAT_SVG = FILE_FORMAT_SVG

    ACTION_OPTION_FACES_ONE = 0
    ACTION_OPTION_FACES_ALL = 1

    ACTION_OPTION_OPTIONS_ANCHOR = 'anchor'
    ACTION_OPTION_OPTIONS_SWITCH_YZ = 'switch_yz'
    ACTION_OPTION_OPTIONS_SMOOTHING = 'smoothing'
    ACTION_OPTION_OPTIONS_MERGE_HOLES = 'merge_holes'
    ACTION_OPTION_OPTIONS_MERGE_HOLES_OVERFLOW = 'merge_holes_overflow'
    ACTION_OPTION_OPTIONS_INCLUDE_PATHS = 'include_paths'

    ACTIONS = [
      {
        :action => ACTION_EXPORT_PART_3D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_STL, ACTION_OPTION_FILE_FORMAT_OBJ ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_ANCHOR ]
        }
      },
      {
        :action => ACTION_EXPORT_PART_2D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_FACES => [ ACTION_OPTION_FACES_ONE, ACTION_OPTION_FACES_ALL ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_ANCHOR, ACTION_OPTION_OPTIONS_SMOOTHING, ACTION_OPTION_OPTIONS_MERGE_HOLES, ACTION_OPTION_OPTIONS_INCLUDE_PATHS ]
        }
      },
      {
        :action => ACTION_EXPORT_FACE,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_SMOOTHING ]
        }
      },
      {
        :action => ACTION_EXPORT_PATHS,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_SMOOTHING ]
        }
      }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(0, 0, 255, 100).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(0, 0, 255, 200).freeze
    COLOR_PART_UPPER = Kuix::COLOR_BLUE
    COLOR_PART_HOLES = Sketchup::Color.new('#D783FF').freeze
    COLOR_PART_DEPTH = COLOR_PART_UPPER.blend(Kuix::COLOR_WHITE, 0.5).freeze
    COLOR_PART_BORDERS = Kuix::COLOR_WHITE
    COLOR_PART_PATH = Kuix::COLOR_CYAN
    COLOR_ACTION = Kuix::COLOR_MAGENTA

    def initialize(

      current_action: nil

    )

      super(
        current_action: current_action
      )

      # Create cursors
      @cursor_export_stl = create_cursor('export-stl', 0, 0)
      @cursor_export_obj = create_cursor('export-obj', 0, 0)
      @cursor_export_dxf = create_cursor('export-dxf', 0, 0)
      @cursor_export_svg = create_cursor('export-svg', 0, 0)

    end

    def get_stripped_name
      'export'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_status(action)

      case action
      when ACTION_EXPORT_PART_3D
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_1') + '.'
      when ACTION_EXPORT_PART_2D
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_2') + '.'
      when ACTION_EXPORT_FACE
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_3') + '.'
      when ACTION_EXPORT_PATHS
        return super +
          ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_0') + '.'
      end

      super
    end

    def get_action_cursor(action)

      case action
      when ACTION_EXPORT_PART_3D
        if fetch_action_option_boolean(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_STL)
          return @cursor_export_stl
        elsif fetch_action_option_boolean(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_OBJ)
          return @cursor_export_obj
        elsif fetch_action_option_boolean(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_PART_2D
        if fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_FACE
        if fetch_action_option_boolean(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_boolean(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_PATHS
        if fetch_action_option_boolean(ACTION_EXPORT_PATHS, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_boolean(ACTION_EXPORT_PATHS, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      end

      super
    end

    def get_action_picker(action)

      case action
      when ACTION_EXPORT_PART_3D
        return SmartPicker.new(tool: self)
      when ACTION_EXPORT_PART_2D, ACTION_EXPORT_FACE
        return SmartPicker.new(tool: self, pick_edges: true, pick_clines: true, pick_axes: true)
      when ACTION_EXPORT_PATHS
        return SmartPicker.new(tool: self, pick_context_by_edge: true, pick_edges: true, pick_clines: true, pick_axes: true)
      end

      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_EXPORT_PART_3D, ACTION_EXPORT_PART_2D, ACTION_EXPORT_FACE, ACTION_EXPORT_PATHS
        return true
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_UNIT, ACTION_OPTION_FACES
        return true
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group
      when ACTION_OPTION_FILE_FORMAT
        case option
        when ACTION_OPTION_FILE_FORMAT_STL
          return Kuix::Label.new('STL')
        when ACTION_OPTION_FILE_FORMAT_OBJ
          return Kuix::Label.new('OBJ')
        when ACTION_OPTION_FILE_FORMAT_DXF
          return Kuix::Label.new('DXF')
        when ACTION_OPTION_FILE_FORMAT_SVG
          return Kuix::Label.new('SVG')
        end
      when ACTION_OPTION_FACES
        case option
        when ACTION_OPTION_FACES_ONE
          return Kuix::Label.new('1')
        when ACTION_OPTION_FACES_ALL
          return Kuix::Label.new('∞')
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_ANCHOR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.25,0L0.25,0.75L1,0.75 M0.083,0.167L0.25,0L0.417,0.167 M0.833,0.583L1,0.75L0.833,0.917 M0.042,0.5L0.042,0.958L0.5,0.958L0.5,0.5L0.042,0.5'))
        when ACTION_OPTION_OPTIONS_SMOOTHING
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0.719L0.97,0.548L0.883,0.398L0.75,0.286L0.587,0.227L0.413,0.227L0.25,0.286L0.117,0.398L0.03,0.548L0,0.719'))
        when ACTION_OPTION_OPTIONS_MERGE_HOLES
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.167L0.5,0L1,0.167L0.75,0.25L0.5,0.167L0.25,0.25L0,0.167 M0.25,0.833L0.5,0.75L0.75,0.833L0.5,0.917L0.25,0.833 M0.5,0.333L0.5,0.667 M0.667,0.5L0.333,0.5'))
        when ACTION_OPTION_OPTIONS_INCLUDE_PATHS
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,1 M0,0.167L1,0.167 M0,0.833L1,0.833 M0.833,0L0.833,1'))
        end
      end

      super
    end

    def is_action_export_part_3d?
      fetch_action == ACTION_EXPORT_PART_3D
    end

    def is_action_export_part_2d?
      fetch_action == ACTION_EXPORT_PART_2D
    end

    def is_action_export_face?
      fetch_action == ACTION_EXPORT_FACE
    end

    def is_action_export_paths?
      fetch_action == ACTION_EXPORT_PATHS
    end

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
      false
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      false
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_down)
      end
      false
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_up)
      end
      false
    end

    def onMouseLeave(view)
      return true if super
      _reset_active_part
      _reset_active_face
      false
    end

    def onMouseLeaveSpace(view)
      return true if super
      _reset_active_part
      _reset_active_face
      false
    end

    def onPickerChanged(picker, view)
      super
      _handle_mouse_event(:move)
    end

    # -----

    protected

    def _set_active_part(part_entity_path, part, highlighted = false)
      super

      if part

        if is_action_export_part_3d?

          # Part 3D

          @active_drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path,
            origin_position: fetch_action_option_boolean(ACTION_EXPORT_PART_3D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) ? CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingDecompositionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
            ignore_surfaces: true,
            ignore_edges: true,
            container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
          ).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            k_group = Kuix::Group.new
            k_group.transformation = @active_drawing_def.transformation
            @overlay_layer.append(k_group)

              # Highlight faces
              k_mesh = Kuix::Mesh.new
              k_mesh.add_triangles(@active_drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
              k_mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
              k_group.append(k_mesh)

              # Box helper
              k_box = Kuix::BoxMotif.new
              k_box.bounds.copy!(@active_drawing_def.bounds)
              k_box.bounds.inflate_all!(inch_offset)
              k_box.color = Kuix::COLOR_BLACK
              k_box.line_width = 1
              k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
              k_group.append(k_box)

              # Axes helper
              k_axes_helper = Kuix::AxesHelper.new
              k_group.append(k_axes_helper)

          end

        elsif is_action_export_part_2d?

          # Part 2D

          local_x_axis = part.def.size.oriented_axis(X_AXIS)
          local_y_axis = part.def.size.oriented_axis(Y_AXIS)
          local_z_axis = part.def.size.oriented_axis(Z_AXIS)

          @active_drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path,
            input_local_x_axis: local_x_axis,
            input_local_y_axis: local_y_axis,
            input_local_z_axis: local_z_axis,
            input_plane_manipulator: @picker.picked_plane_manipulator,
            input_line_manipulator: @picker.picked_line_manipulator,
            face_validator: fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACES, ACTION_OPTION_FACES_ONE) ? CommonDrawingDecompositionWorker::FACE_VALIDATOR_ONE : CommonDrawingDecompositionWorker::FACE_VALIDATOR_ALL,
            ignore_edges: !fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_INCLUDE_PATHS),
            edge_validator: fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACES, ACTION_OPTION_FACES_ONE) ? CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY_COPLANAR : CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY,
            container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
          ).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(30, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def,
                                                               origin_position: fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) ? CommonDrawingProjectionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingProjectionWorker::ORIGIN_POSITION_BOUNDS_MIN,
                                                               merge_holes: fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES),
                                                               merge_holes_overflow: fetch_action_option_length(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES_OVERFLOW),
                                                               include_borders_layers: true
            ).run
            if projection_def.is_a?(DrawingProjectionDef)

              k_group = Kuix::Group.new
              k_group.transformation = @active_drawing_def.transformation * projection_def.transformation
              @overlay_layer.append(k_group)

              fn_append_polyline = lambda do |points, color, line_width, line_stipple, closed|

                k_polyline = Kuix::Polyline.new
                k_polyline.add_points(points)
                k_polyline.color = color
                k_polyline.line_width = highlighted ? line_width + 1 : line_width
                k_polyline.line_stipple = line_stipple
                k_polyline.on_top = true
                k_polyline.closed = closed
                k_group.append(k_polyline)

              end

              border_color = @active_part.group.def.material_color
              border_color = COLOR_PART_BORDERS if border_color.nil?

              projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top

                points_entities = []

                if layer_def.type_upper?
                  color = COLOR_PART_UPPER
                elsif layer_def.type_holes?
                  color = COLOR_PART_HOLES
                elsif layer_def.type_paths?
                  color = layer_def.has_color? ? layer_def.color : COLOR_PART_PATH
                elsif layer_def.type_borders?
                  color = border_color
                else
                  color = COLOR_PART_DEPTH
                end

                layer_def.poly_defs.each do |poly_def|

                  line_stipple = if poly_def.is_a?(DrawingProjectionPolygonDef) && !poly_def.ccw?
                                   Kuix::LINE_STIPPLE_SHORT_DASHES
                                 else
                                   layer_def.type_borders? ? Kuix::LINE_STIPPLE_LONG_DASHES : Kuix::LINE_STIPPLE_SOLID
                                 end

                  if fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                    poly_def.curve_def.portions.each do |portion|
                      fn_append_polyline.call(portion.points, color, portion.is_a?(Geometrix::ArcCurvePortionDef) ? 4 : 2, line_stipple, false)
                    end
                  else
                    fn_append_polyline.call(poly_def.points, color, 2, line_stipple, poly_def.is_a?(DrawingProjectionPolygonDef))
                  end

                  if poly_def.is_a?(DrawingProjectionPolylineDef) && !layer_def.type_borders?

                    # It's a polyline, create 'start' and 'end' points entities

                    k_points = Kuix::Points.new
                    k_points.add_points([ poly_def.points.first ])
                    k_points.size = 2 * @unit
                    k_points.style = Kuix::POINT_STYLE_SQUARE
                    k_points.fill_color = Kuix::COLOR_MEDIUM_GREY
                    k_points.stroke_color = nil
                    points_entities << k_points

                    k_points = Kuix::Points.new
                    k_points.add_points([ poly_def.points.last ])
                    k_points.size = 2.5 * @unit
                    k_points.style = Kuix::POINT_STYLE_SQUARE
                    k_points.stroke_color = Kuix::COLOR_DARK_GREY
                    k_points.stroke_width = 2
                    points_entities << k_points

                  end

                end

                # Append points after to be on top of segments
                points_entities.each { |entity| k_group.append(entity) }

              end

              # Box helper
              k_box = Kuix::RectangleMotif.new
              k_box.bounds.origin.copy!(projection_def.bounds.min)
              k_box.bounds.size.copy!(projection_def.bounds)
              k_box.bounds.inflate!(inch_offset, inch_offset, 0)
              k_box.color = Kuix::COLOR_BLACK
              k_box.line_width = 1
              k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
              k_group.append(k_box)

              if @active_drawing_def.input_line_manipulator.is_a?(EdgeManipulator)

                # Highlight input edge
                k_polyline = Kuix::Segments.new
                k_polyline.transformation = projection_def.transformation.inverse
                k_polyline.add_segments(@active_drawing_def.input_line_manipulator.segment)
                k_polyline.color = COLOR_ACTION
                k_polyline.line_width = 3
                k_polyline.on_top = true
                k_group.append(k_polyline)

              elsif @active_drawing_def.input_line_manipulator.is_a?(LineManipulator)

                # Highlight input line
                k_line = Kuix::Line.new
                k_line.transformation = projection_def.transformation.inverse
                k_line.position = @active_drawing_def.input_line_manipulator.position
                k_line.direction = @active_drawing_def.input_line_manipulator.direction
                k_line.color = COLOR_ACTION
                k_line.line_width = 2
                k_group.append(k_line)

              end

              # Axes helper
              k_axes_helper = Kuix::AxesHelper.new
              k_axes_helper.box_0.visible = false
              k_axes_helper.box_z.visible = false
              k_group.append(k_axes_helper)

            end

          end

        end

        # Show part infos
        show_tooltip([ [ "##{_get_active_part_name}", @active_drawing_def.nil? || @active_drawing_def.input_view.nil? ? nil : "(#{PLUGIN.get_i18n_string("core.component.three_viewer.view_#{@active_drawing_def.input_view}")})" ], _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

      else

        @active_drawing_def = nil

      end

    end

    def _set_active_face(face_path, face, highlighted = false)
      super

      if face

        @active_drawing_def = CommonDrawingDecompositionWorker.new(@picker.picked_face_path,
          input_plane_manipulator: @picker.picked_plane_manipulator,
          input_line_manipulator: @picker.picked_line_manipulator,
          ignore_edges: true,
          container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
        ).run
        if @active_drawing_def.is_a?(DrawingDef)

          projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def,
            origin_position: CommonDrawingProjectionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN
          ).run
          if projection_def.is_a?(DrawingProjectionDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            k_group = Kuix::Group.new
            k_group.transformation = @active_drawing_def.transformation * projection_def.transformation
            @overlay_layer.append(k_group)

            fn_append_polyline = lambda do |points, line_width, line_stipple, closed|

              k_polyline = Kuix::Polyline.new
              k_polyline.add_points(points)
              k_polyline.color = COLOR_PART_UPPER
              k_polyline.line_width = highlighted ? line_width + 1 : line_width
              k_polyline.line_stipple = line_stipple
              k_polyline.on_top = true
              k_polyline.closed = closed
              k_group.append(k_polyline)

            end

            projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top
              layer_def.poly_defs.each do |poly_def|

                line_stipple = poly_def.ccw? ? Kuix::LINE_STIPPLE_SOLID : Kuix::LINE_STIPPLE_SHORT_DASHES

                if fetch_action_option_boolean(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                  poly_def.curve_def.portions.each do |portion|
                    fn_append_polyline.call(portion.points, portion.is_a?(Geometrix::ArcCurvePortionDef) ? 4 : 2, line_stipple, false)
                  end
                else
                  fn_append_polyline.call(poly_def.points, 2, line_stipple, true)
                end

              end
            end

            # if fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING) && projection_def.layer_defs.one?
            #   layer_def = projection_def.layer_defs.first
            #   if layer_def.poly_defs.one?
            #     poly_def = layer_def.poly_defs.first
            #     curve_def = poly_def.curve_def
            #     if curve_def.ellipse?
            #       portion_def = curve_def.portions.first
            #       if curve_def.circle?
            #         show_tooltip([ '#CIRCLE', "Radius = #{portion_def.ellipse_def.xradius.to_mm.round(3)} mm" ])
            #       else
            #         show_tooltip([ '#ELLIPSE', "Radius 1 = #{portion_def.ellipse_def.xradius.to_mm.round(3)} mm", "Radius 2 = #{portion_def.ellipse_def.yradius.to_mm.round(3)} mm", "Angle = #{portion_def.ellipse_def.angle.radians.round(3)}°" ])
            #       end
            #     else
            #       show_tooltip('#POLYGON')
            #     end
            #   end
            # end

            # Box helper
            k_rectangle = Kuix::RectangleMotif.new
            k_rectangle.bounds.origin.copy!(projection_def.bounds.min)
            k_rectangle.bounds.size.copy!(projection_def.bounds)
            k_rectangle.bounds.inflate!(inch_offset, inch_offset, 0)
            k_rectangle.color = Kuix::COLOR_BLACK
            k_rectangle.line_width = 1
            k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            k_group.append(k_rectangle)

            if @active_drawing_def.input_line_manipulator.is_a?(EdgeManipulator)

              # Highlight input edge
              k_segments = Kuix::Segments.new
              k_segments.transformation = projection_def.transformation.inverse
              k_segments.add_segments(@active_drawing_def.input_line_manipulator.segment)
              k_segments.color = COLOR_ACTION
              k_segments.line_width = 3
              k_segments.on_top = true
              k_group.append(k_segments)

            elsif @active_drawing_def.input_line_manipulator.is_a?(LineManipulator)

              # Highlight input line
              k_line = Kuix::Line.new
              k_line.transformation = projection_def.transformation.inverse
              k_line.position = @active_drawing_def.input_line_manipulator.position
              k_line.direction = @active_drawing_def.input_line_manipulator.direction
              k_line.color = COLOR_ACTION
              k_line.line_width = 2
              k_group.append(k_line)

            end

            # Axes helper
            k_axes_helper = Kuix::AxesHelper.new
            k_axes_helper.box_0.visible = false
            k_axes_helper.box_z.visible = false
            k_group.append(k_axes_helper)

          end

        end

      else

        @active_edge = nil

      end

    end

    def _set_active_context(context_path, highlighted = false)
      super

      if context_path

        @active_drawing_def = CommonDrawingDecompositionWorker.new(context_path,
          ignore_faces: true,
          input_plane_manipulator: @picker.picked_plane_manipulator,
          input_line_manipulator: @picker.picked_line_manipulator,
          edge_validator: CommonDrawingDecompositionWorker::EDGE_VALIDATOR_COPLANAR,
          container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_NONE,
        ).run
        if @active_drawing_def.is_a?(DrawingDef)

          projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def,
            origin_position: CommonDrawingProjectionWorker::ORIGIN_POSITION_EDGES_BOUNDS_MIN
          ).run
          if projection_def.is_a?(DrawingProjectionDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            k_group = Kuix::Group.new
            k_group.transformation = @active_drawing_def.transformation * projection_def.transformation
            @overlay_layer.append(k_group)

            fn_append_polyline = lambda do |points, color, line_width, line_stipple, closed|

              k_polyline = Kuix::Polyline.new
              k_polyline.add_points(points)
              k_polyline.color = color
              k_polyline.line_width = highlighted ? line_width + 1 : line_width
              k_polyline.line_stipple = line_stipple
              k_polyline.on_top = true
              k_polyline.closed = closed
              k_group.append(k_polyline)

            end

            projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top

              points_entities = []

              layer_def.poly_defs.each do |poly_def|

                color = layer_def.has_color? ? layer_def.color : COLOR_PART_PATH
                line_stipple = Kuix::LINE_STIPPLE_SOLID

                if fetch_action_option_boolean(ACTION_EXPORT_PATHS, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING) && !poly_def.curve_def.nil?
                  poly_def.curve_def.portions.each do |portion|
                    fn_append_polyline.call(portion.points, color, portion.is_a?(Geometrix::ArcCurvePortionDef) ? 4 : 2, line_stipple, false)
                  end
                else
                  fn_append_polyline.call(poly_def.points, color, 2, line_stipple, poly_def.is_a?(DrawingProjectionPolygonDef))
                end

                if poly_def.is_a?(DrawingProjectionPolylineDef)

                  # It's a polyline, create 'start' and 'end' points entities

                  k_points = Kuix::Points.new
                  k_points.add_points([ poly_def.points.first ])
                  k_points.size = 2 * @unit
                  k_points.style = Kuix::POINT_STYLE_SQUARE
                  k_points.fill_color = Kuix::COLOR_MEDIUM_GREY
                  k_points.stroke_color = nil
                  points_entities << k_points

                  k_points = Kuix::Points.new
                  k_points.add_points([ poly_def.points.last ])
                  k_points.size = 2.5 * @unit
                  k_points.style = Kuix::POINT_STYLE_SQUARE
                  k_points.stroke_color = Kuix::COLOR_DARK_GREY
                  k_points.stroke_width = 2
                  points_entities << k_points

                end

              end

              # Append points after to be on top of segments
              points_entities.each { |entity| k_group.append(entity) }

            end

            # Box helper
            k_rectangle = Kuix::RectangleMotif.new
            k_rectangle.bounds.origin.copy!(projection_def.bounds.min)
            k_rectangle.bounds.size.copy!(projection_def.bounds)
            k_rectangle.bounds.inflate!(inch_offset, inch_offset, 0)
            k_rectangle.color = Kuix::COLOR_BLACK
            k_rectangle.line_width = 1
            k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            k_group.append(k_rectangle)

            if @active_drawing_def.input_line_manipulator.is_a?(EdgeManipulator)

              # Highlight input edge
              k_segments = Kuix::Segments.new
              k_segments.transformation = projection_def.transformation.inverse
              k_segments.add_segments(@active_drawing_def.input_line_manipulator.segment)
              k_segments.color = COLOR_ACTION
              k_segments.line_width = 3
              k_segments.on_top = true
              k_group.append(k_segments)

            elsif @active_drawing_def.input_line_manipulator.is_a?(LineManipulator)

              # Highlight input line
              k_line = Kuix::Line.new
              k_line.transformation = projection_def.transformation.inverse
              k_line.position = @active_drawing_def.input_line_manipulator.position
              k_line.direction = @active_drawing_def.input_line_manipulator.direction
              k_line.color = COLOR_ACTION
              k_line.line_width = 2
              k_group.append(k_line)

            end

            # Axes helper
            k_axes_helper = Kuix::AxesHelper.new
            k_axes_helper.box_0.visible = false
            k_axes_helper.box_z.visible = false
            k_group.append(k_axes_helper)

          end

        end

      end

    end

    # -----

    private

    def _handle_mouse_event(event = nil)
      if event == :move

        if @picker.picked_face_path

          # Check if face is not curved
          if (is_action_export_part_2d? || is_action_export_face? || is_action_export_paths?) && @picker.picked_face.edges.index { |edge| edge.soft? } && !SurfaceManipulator.new.populate_from_face(@picker.picked_face).flat?
            _reset_active_part
            show_tooltip("⚠ #{PLUGIN.get_i18n_string('tool.smart_export.error.not_flat_face')}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_select_error)
            return
          end

          if is_action_export_part_3d? || is_action_export_part_2d?

            picked_part_entity_path = _get_part_entity_path_from_path(@picker.picked_face_path)
            if picked_part_entity_path

              if Sketchup.active_model.active_path &&
                fetch_action_option_value(fetch_action, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) &&
                Sketchup.active_model.active_path.length > picked_part_entity_path.length &&
                Sketchup.active_model.active_path.last != picked_part_entity_path.last

                _reset_active_part
                show_tooltip("⚠ #{PLUGIN.get_i18n_string('tool.smart_export.error.incompatible_active_path')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
                return

              end

              part = _generate_part_from_path(picked_part_entity_path)
              if part
                _set_active_part(picked_part_entity_path, part)
              else
                _reset_active_part
                show_tooltip("⚠ #{PLUGIN.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
              end
              return

            else
              _reset_active_part
              show_tooltip("⚠ #{PLUGIN.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_select_error)
              return
            end

          elsif is_action_export_face?

            _set_active_face(@picker.picked_face_path, @picker.picked_face)
            return

          elsif is_action_export_paths?

            _set_active_context(@picker.picked_context_path)
            return

          end

        elsif @picker.picked_edge_path

          if is_action_export_paths?
            _set_active_context(@picker.picked_context_path)
            return
          end

        end
        _reset_active_context  # No input
        _reset_active_face  # No input
        _reset_active_part  # No input

      elsif event == :l_button_down

        if is_action_export_part_3d?
          _refresh_active_part(true)
        elsif is_action_export_part_2d?
          _refresh_active_part(true)
        elsif is_action_export_face?
          _refresh_active_face(true)
        elsif is_action_export_paths?
          _refresh_active_context(true)
        end

      elsif event == :l_button_up || event == :l_button_dblclick

        if is_action_export_part_3d?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = _get_active_part_name(true)
          file_format = fetch_action_option_value(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT)
          switch_yz = fetch_action_option_boolean(ACTION_EXPORT_PART_3D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SWITCH_YZ)

          worker = CommonWriteDrawing3dWorker.new(@active_drawing_def,
            file_name: file_name,
            file_format: file_format,
            unit: unit,
            switch_yz: switch_yz
          )
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              PLUGIN.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => PLUGIN.get_i18n_string('default.open'),
                  :block => lambda { PLUGIN.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_part_2d?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = _get_active_part_name(true)
          file_name += " - #{PLUGIN.get_i18n_string("core.component.three_viewer.view_#{@active_drawing_def.input_view}").upcase}" unless @active_drawing_def.nil? || @active_drawing_def.input_view.nil?
          file_format = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_UNIT)
          anchor = fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR)
          smoothing = fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          merge_holes = fetch_action_option_boolean(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES)
          merge_holes_overflow = fetch_action_option_length(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES_OVERFLOW)
          parts_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_stroke_color')
          parts_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_fill_color')
          parts_holes_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_holes_stroke_color')
          parts_holes_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_holes_fill_color')
          parts_depths_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_depths_stroke_color')
          parts_depths_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_depths_fill_color')
          parts_paths_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_paths_stroke_color')
          parts_paths_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_paths_fill_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def,
                                                  file_name: file_name,
                                                  file_format: file_format,
                                                  unit: unit,
                                                  anchor: anchor,
                                                  smoothing: smoothing,
                                                  merge_holes: merge_holes,
                                                  merge_holes_overflow: merge_holes_overflow,
                                                  parts_stroke_color: parts_stroke_color,
                                                  parts_fill_color: parts_fill_color,
                                                  parts_holes_stroke_color: parts_holes_stroke_color,
                                                  parts_holes_fill_color: parts_holes_fill_color,
                                                  parts_depths_stroke_color: parts_depths_stroke_color,
                                                  parts_depths_fill_color: parts_depths_fill_color,
                                                  parts_paths_stroke_color: parts_paths_stroke_color,
                                                  parts_paths_fill_color: parts_paths_fill_color
          )
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              PLUGIN.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => PLUGIN.get_i18n_string('default.open'),
                  :block => lambda { PLUGIN.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_face?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = 'FACE'
          file_format = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_UNIT)
          smoothing = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          parts_stroke_color = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, 'parts_stroke_color')
          parts_fill_color = fetch_action_option_value(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, 'parts_fill_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def,
            file_name: file_name,
            file_format: file_format,
            unit: unit,
            smoothing: smoothing,
            parts_stroke_color: parts_stroke_color,
            parts_fill_color: parts_fill_color
          )
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              PLUGIN.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => PLUGIN.get_i18n_string('default.open'),
                  :block => lambda { PLUGIN.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_paths?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = 'PATHS'
          file_format = fetch_action_option_value(ACTION_EXPORT_PATHS, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_PATHS, ACTION_OPTION_UNIT)
          smoothing = fetch_action_option_value(ACTION_EXPORT_PATHS, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          parts_paths_stroke_color = fetch_action_option_value(ACTION_EXPORT_PATHS, ACTION_OPTION_OPTIONS, 'parts_paths_stroke_color')
          parts_paths_fill_color = fetch_action_option_value(ACTION_EXPORT_PATHS, ACTION_OPTION_OPTIONS, 'parts_paths_fill_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def,
            file_name: file_name,
            file_format: file_format,
            unit: unit,
            smoothing: smoothing,
            parts_paths_stroke_color: parts_paths_stroke_color,
            parts_paths_fill_color: parts_paths_fill_color
          )
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              PLUGIN.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => PLUGIN.get_i18n_string('default.open'),
                  :block => lambda { PLUGIN.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        end

      end

    end

  end

end