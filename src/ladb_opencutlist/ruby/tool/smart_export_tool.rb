module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geometrix/geometrix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/edge_segments_helper'
  require_relative '../helper/entities_helper'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/loop_manipulator'
  require_relative '../worker/common/common_write_drawing2d_worker'
  require_relative '../worker/common/common_write_drawing3d_worker'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_drawing_projection_worker'
  require_relative '../observer/plugin_observer'

  class SmartExportTool < SmartTool

    include LayerVisibilityHelper
    include EdgeSegmentsHelper
    include EntitiesHelper

    ACTION_EXPORT_PART_3D = 0
    ACTION_EXPORT_PART_2D = 1
    ACTION_EXPORT_FACE = 2
    ACTION_EXPORT_EDGES = 3

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
    ACTION_OPTION_OPTIONS_SMOOTHING = 'smoothing'
    ACTION_OPTION_OPTIONS_MERGE_HOLES = 'merge_holes'
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
      # {
      #   :action => ACTION_EXPORT_EDGES,
      #   :options => {
      #     ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
      #     ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_SMOOTHING ]
      #   }
      # }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(0, 0, 255, 100).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(0, 0, 255, 200).freeze
    COLOR_PART_UPPER = Kuix::COLOR_BLUE
    COLOR_PART_HOLES = Sketchup::Color.new('#D783FF').freeze
    COLOR_PART_DEPTH = COLOR_PART_UPPER.blend(Kuix::COLOR_WHITE, 0.5).freeze
    COLOR_PART_PATH = Kuix::COLOR_CYAN
    COLOR_ACTION = Kuix::COLOR_MAGENTA

    def initialize(material = nil)
      super(true, false)

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

    def get_action_cursor(action)

      case action
      when ACTION_EXPORT_PART_3D
        if fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_STL)
          return @cursor_export_stl
        elsif fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_OBJ)
          return @cursor_export_obj
        elsif fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_PART_2D
        if fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_FACE
        if fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      when ACTION_EXPORT_EDGES
        if fetch_action_option_enabled(ACTION_EXPORT_EDGES, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return @cursor_export_svg
        elsif fetch_action_option_enabled(ACTION_EXPORT_EDGES, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return @cursor_export_dxf
        end
      end

      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_EXPORT_PART_3D, ACTION_EXPORT_PART_2D, ACTION_EXPORT_FACE, ACTION_EXPORT_EDGES
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
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.273,0L0.273,0.727L1,0.727 M0.091,0.545L0.455,0.545L0.455,0.909L0.091,0.909L0.091,0.545 M0.091,0.182L0.273,0L0.455,0.182 M0.818,0.545L1,0.727L0.818,0.909'))
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

    def is_action_export_edges?
      fetch_action == ACTION_EXPORT_EDGES
    end

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

    end

    def onActionChange(action)

      # Simulate mouse move event
      _handle_mouse_event(:move)

    end

    def onKeyDown(key, repeat, flags, view)
      return true if super
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
    end

    def onLButtonDown(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_down)
      end
    end

    def onLButtonUp(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:l_button_up)
      end
    end

    def onMouseMove(flags, x, y, view)
      return true if super
      unless is_action_none?
        _handle_mouse_event(:move)
      end
    end

    def onMouseLeave(view)
      return true if super
      _reset_active_part
      _reset_active_face
    end

    # -----

    protected

    def _set_active_part(part_entity_path, part, highlighted = false)
      super

      if part

        # Show part infos
        show_tooltip([ "##{_get_active_part_name}", _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

        if is_action_export_part_3d?

          # Part 3D

          @active_drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path, {
            'origin_position' => fetch_action_option_enabled(ACTION_EXPORT_PART_3D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) ? CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingDecompositionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
            'ignore_surfaces' => true,
            'ignore_edges' => true
          }).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation
            @space.append(preview)

            @active_drawing_def.face_manipulators.each do |face_info|

              # Highlight face
              mesh = Kuix::Mesh.new
              mesh.add_triangles(FaceManipulator.new(face_info.face, face_info.transformation).triangles)
              mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
              preview.append(mesh)

            end

            bounds = Geom::BoundingBox.new
            bounds.add(@active_drawing_def.bounds.min)
            bounds.add(@active_drawing_def.bounds.max)
            bounds.add(ORIGIN)

            # Box helper
            box_helper = Kuix::BoxMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, inch_offset)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            preview.append(axes_helper)

          end

        elsif is_action_export_part_2d?

          # Part 2D

          local_x_axis = part.def.size.oriented_axis(X_AXIS)
          local_y_axis = part.def.size.oriented_axis(Y_AXIS)
          local_z_axis = part.def.size.oriented_axis(Z_AXIS)

          @active_drawing_def = CommonDrawingDecompositionWorker.new(@active_part_entity_path, {
            'input_local_x_axis' => local_x_axis,
            'input_local_y_axis' => local_y_axis,
            'input_local_z_axis' => local_z_axis,
            'input_face_path' => @input_face_path,
            'input_edge_path' => @input_edge_path,
            'face_validator' => fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACES, ACTION_OPTION_FACES_ONE) ? CommonDrawingDecompositionWorker::FACE_VALIDATOR_ONE : CommonDrawingDecompositionWorker::FACE_VALIDATOR_ALL,
            'ignore_edges' => !fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_INCLUDE_PATHS),
            'edge_validator' => fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACES, ACTION_OPTION_FACES_ONE) ? CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY_COPLANAR : CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY
          }).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def, {
              'origin_position' => fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) ? CommonDrawingProjectionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingProjectionWorker::ORIGIN_POSITION_BOUNDS_MIN,
              'merge_holes' => fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES)
            }).run
            if projection_def.is_a?(DrawingProjectionDef)

              preview = Kuix::Group.new
              preview.transformation = @active_drawing_def.transformation * projection_def.transformation
              @space.append(preview)

              fn_append_segments = lambda do |segments, color, line_width, line_stipple|

                entity = Kuix::Segments.new
                entity.add_segments(segments)
                entity.color = color
                entity.line_width = highlighted ? line_width + 1 : line_width
                entity.line_stipple = line_stipple
                entity.on_top = true
                preview.append(entity)

              end

              projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top

                points_entities = []

                if layer_def.type_upper?
                  color = COLOR_PART_UPPER
                elsif layer_def.type_holes?
                  color = COLOR_PART_HOLES
                elsif layer_def.type_path?
                  color = COLOR_PART_PATH
                else
                  color = COLOR_PART_DEPTH
                end

                layer_def.poly_defs.each do |poly_def|

                  line_stipple = poly_def.is_a?(DrawingProjectionPolygonDef) && !poly_def.ccw? ? Kuix::LINE_STIPPLE_SHORT_DASHES : Kuix::LINE_STIPPLE_SOLID

                  if fetch_action_option_enabled(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                    poly_def.curve_def.portions.each do |portion|
                      fn_append_segments.call(portion.segments, color, portion.is_a?(Geometrix::ArcCurvePortionDef) ? 4 : 2, line_stipple)
                    end
                  else
                    fn_append_segments.call(poly_def.segments, color, 2, line_stipple)
                  end

                  if poly_def.is_a?(DrawingProjectionPolylineDef)

                    # It's a polyline, create 'start' and 'end' points entities

                    entity = Kuix::Points.new
                    entity.add_points([ poly_def.points.first ])
                    entity.size = 16
                    entity.style = Kuix::POINT_STYLE_FILLED_SQUARE
                    entity.color = Kuix::COLOR_MEDIUM_GREY
                    points_entities << entity

                    entity = Kuix::Points.new
                    entity.add_points([ poly_def.points.last ])
                    entity.size = 18
                    entity.style = Kuix::POINT_STYLE_OPEN_SQUARE
                    entity.color = Kuix::COLOR_DARK_GREY
                    points_entities << entity

                  end

                end

                # Append points after to be on top of segments
                points_entities.each { |entity| preview.append(entity) }

              end

              # Box helper
              box_helper = Kuix::RectangleMotif.new
              box_helper.bounds.origin.copy!(projection_def.bounds.min)
              box_helper.bounds.size.copy!(projection_def.bounds)
              box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
              box_helper.color = Kuix::COLOR_BLACK
              box_helper.line_width = 1
              box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
              preview.append(box_helper)

              if @active_drawing_def.input_edge_manipulator

                # Highlight input edge
                segments = Kuix::Segments.new
                segments.transformation = projection_def.transformation.inverse
                segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
                segments.color = COLOR_ACTION
                segments.line_width = 3
                segments.on_top = true
                preview.append(segments)

              end

              # Axes helper
              axes_helper = Kuix::AxesHelper.new
              axes_helper.box_0.visible = false
              axes_helper.box_z.visible = false
              preview.append(axes_helper)

            end

          end

        end

      else

        @active_drawing_def = nil

      end

    end

    def _set_active_face(face_path, face, highlighted = false)
      super

      if face

        @active_drawing_def = CommonDrawingDecompositionWorker.new(@input_face_path, {
          'input_face_path' => @input_face_path,
          'input_edge_path' => @input_edge_path,
          'ignore_edges' => true
        }).run
        if @active_drawing_def.is_a?(DrawingDef)

          projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def, {
            'origin_position' => CommonDrawingProjectionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN
          }).run
          if projection_def.is_a?(DrawingProjectionDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation * projection_def.transformation
            @space.append(preview)

            fn_append_segments = lambda do |segments, line_width, line_stipple|

              entity = Kuix::Segments.new
              entity.add_segments(segments)
              entity.color = COLOR_PART_UPPER
              entity.line_width = highlighted ? line_width + 1 : line_width
              entity.line_stipple = line_stipple
              entity.on_top = true
              preview.append(entity)

            end

            projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top
              layer_def.poly_defs.each do |poly_def|

                line_stipple = poly_def.ccw? ? Kuix::LINE_STIPPLE_SOLID : Kuix::LINE_STIPPLE_SHORT_DASHES

                if fetch_action_option_enabled(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                  poly_def.curve_def.portions.each do |portion|
                    fn_append_segments.call(portion.segments, portion.is_a?(Geometrix::ArcCurvePortionDef) ? 4 : 2, line_stipple)
                  end
                else
                  fn_append_segments.call(poly_def.segments, 2, line_stipple)
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
            box_helper = Kuix::RectangleMotif.new
            box_helper.bounds.origin.copy!(projection_def.bounds.min)
            box_helper.bounds.size.copy!(projection_def.bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            if @active_drawing_def.input_edge_manipulator

              # Highlight input edge
              segments = Kuix::Segments.new
              segments.transformation = projection_def.transformation.inverse
              segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
              segments.color = COLOR_ACTION
              segments.line_width = 3
              segments.on_top = true
              preview.append(segments)

            end

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            axes_helper.box_0.visible = false
            axes_helper.box_z.visible = false
            preview.append(axes_helper)

          end

        end

      else

        @active_edge = nil

      end

    end

    def _set_active_context(context_path, highlighted = false)
      super

      if context_path

        @active_drawing_def = CommonDrawingDecompositionWorker.new(context_path, {
          'ignore_faces' => true,
          'input_face_path' => @input_face_path,
          'input_edge_path' => @input_edge_path,
          'edge_validator' => CommonDrawingDecompositionWorker::EDGE_VALIDATOR_COPLANAR
        }).run
        if @active_drawing_def.is_a?(DrawingDef)

          projection_def = CommonDrawingProjectionWorker.new(@active_drawing_def, {
            'origin_position' => CommonDrawingProjectionWorker::ORIGIN_POSITION_EDGES_BOUNDS_MIN
          }).run
          if projection_def.is_a?(DrawingProjectionDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation * projection_def.transformation
            @space.append(preview)

            fn_append_segments = lambda do |segments, line_width, line_stipple|

              entity = Kuix::Segments.new
              entity.add_segments(segments)
              entity.color = COLOR_PART_PATH
              entity.line_width = highlighted ? line_width + 1 : line_width
              entity.line_stipple = line_stipple
              entity.on_top = true
              preview.append(entity)

            end

            projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top

              points_entities = []

              layer_def.poly_defs.each do |poly_def|

                line_stipple = Kuix::LINE_STIPPLE_SOLID

                if fetch_action_option_enabled(ACTION_EXPORT_EDGES, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
                  poly_def.curve_def.portions.each do |portion|
                    fn_append_segments.call(portion.segments, portion.is_a?(Geometrix::ArcCurvePortionDef) ? 4 : 2, line_stipple)
                  end
                else
                  fn_append_segments.call(poly_def.segments, 2, line_stipple)
                end

                if poly_def.is_a?(DrawingProjectionPolylineDef)

                  # It's a polyline, create 'start' and 'end' points entities

                  entity = Kuix::Points.new
                  entity.add_points([ poly_def.points.first ])
                  entity.size = 16
                  entity.style = Kuix::POINT_STYLE_FILLED_SQUARE
                  entity.color = Kuix::COLOR_MEDIUM_GREY
                  points_entities << entity

                  entity = Kuix::Points.new
                  entity.add_points([ poly_def.points.last ])
                  entity.size = 18
                  entity.style = Kuix::POINT_STYLE_OPEN_SQUARE
                  entity.color = Kuix::COLOR_DARK_GREY
                  points_entities << entity

                end

              end

              # Append points after to be on top of segments
              points_entities.each { |entity| preview.append(entity) }

            end

            # Box helper
            box_helper = Kuix::RectangleMotif.new
            box_helper.bounds.origin.copy!(projection_def.bounds.min)
            box_helper.bounds.size.copy!(projection_def.bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            if @active_drawing_def.input_edge_manipulator

              # Highlight input edge
              segments = Kuix::Segments.new
              segments.transformation = projection_def.transformation.inverse
              segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
              segments.color = COLOR_ACTION
              segments.line_width = 3
              segments.on_top = true
              preview.append(segments)

            end

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            axes_helper.box_0.visible = false
            axes_helper.box_z.visible = false
            preview.append(axes_helper)

          end

        end

      end

    end

    # -----

    private

    def _handle_mouse_event(event = nil)
      if event == :move

        if @input_face_path

          # Check if face is not curved
          if (is_action_export_part_2d? || is_action_export_face?) && @input_face.edges.index { |edge| edge.soft? }
            _reset_active_part
            show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_flat_face')}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_select_error)
            return
          end

          if is_action_export_part_3d? || is_action_export_part_2d?

            input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
            if input_part_entity_path

              if Sketchup.active_model.active_path

                diff = Sketchup.active_model.active_path - input_part_entity_path
                unless diff.empty?
                  _reset_active_part
                  show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.incompatible_active_path')}", MESSAGE_TYPE_ERROR)
                  push_cursor(@cursor_select_error)
                  return
                end

              end

              part = _generate_part_from_path(input_part_entity_path)
              if part
                _set_active_part(input_part_entity_path, part)
              else
                _reset_active_part
                show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
              end
              return

            else
              _reset_active_part
              show_tooltip("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_select_error)
              return
            end

          elsif is_action_export_face?

            _set_active_face(@input_face_path, @input_face)
            return

          elsif is_action_export_edges?

            _set_active_context(@input_context_path)
            return

          end

        elsif @input_edge_path

          if is_action_export_edges?
            _set_active_context(@input_context_path)
            return

          end

        end
        _reset_active_part  # No input
        _reset_active_face  # No input

      elsif event == :l_button_down

        if is_action_export_part_3d?
          _refresh_active_part(true)
        elsif is_action_export_part_2d?
          _refresh_active_part(true)
        elsif is_action_export_face?
          _refresh_active_face(true)
        elsif is_action_export_edges?
          _refresh_active_edge(true)
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

          worker = CommonWriteDrawing3dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
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
          file_format = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_UNIT)
          anchor = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR) && (@active_drawing_def.bounds.min.x != 0 || @active_drawing_def.bounds.min.y != 0)    # No anchor if = (0, 0, z)
          smoothing = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          merge_holes = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_MERGE_HOLES)
          parts_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_stroke_color')
          parts_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_fill_color')
          parts_holes_fill_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_holes_fill_color')
          parts_holes_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_holes_stroke_color')
          parts_paths_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_paths_stroke_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'anchor' => anchor,
            'smoothing' => smoothing,
            'merge_holes' => merge_holes,
            'parts_stroke_color' => parts_stroke_color,
            'parts_fill_color' => parts_fill_color,
            'parts_holes_fill_color' => parts_holes_fill_color,
            'parts_holes_stroke_color' => parts_holes_stroke_color,
            'parts_paths_stroke_color' => parts_paths_stroke_color
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
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

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'smoothing' => smoothing,
            'parts_stroke_color' => parts_stroke_color,
            'parts_fill_color' => parts_fill_color
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

          # Focus SketchUp
          Sketchup.focus if Sketchup.respond_to?(:focus)

        elsif is_action_export_edges?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = 'EDGES'
          file_format = fetch_action_option_value(ACTION_EXPORT_EDGES, ACTION_OPTION_FILE_FORMAT)
          unit = fetch_action_option_value(ACTION_EXPORT_EDGES, ACTION_OPTION_UNIT)
          smoothing = fetch_action_option_value(ACTION_EXPORT_EDGES, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_SMOOTHING)
          parts_paths_stroke_color = fetch_action_option_value(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, 'parts_paths_stroke_color')

          worker = CommonWriteDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'smoothing' => smoothing,
            'parts_paths_stroke_color' => parts_paths_stroke_color
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('core.success.exported_to', { :path => File.basename(response[:export_path]) }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
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