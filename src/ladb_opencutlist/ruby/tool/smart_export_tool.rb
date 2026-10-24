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
        if fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_STL)
          return SmartCursorManager.cursor_select_stl
        elsif fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_OBJ)
          return SmartCursorManager.cursor_select_obj
        elsif fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return SmartCursorManager.cursor_select_dxf
        end
      when ACTION_EXPORT_PART_2D
        if fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return SmartCursorManager.cursor_select_svg
        elsif fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return SmartCursorManager.cursor_select_dxf
        end
      when ACTION_EXPORT_FACE
        if fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return SmartCursorManager.cursor_select_svg
        elsif fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return SmartCursorManager.cursor_select_dxf
        end
      when ACTION_EXPORT_PATHS
        if fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
          return SmartCursorManager.cursor_select_svg
        elsif fetch_action_option_boolean(action, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
          return SmartCursorManager.cursor_select_dxf
        end
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

    def get_action_option_sync_actions(action, option_group, option)

      case option_group
      when ACTION_OPTION_FILE_FORMAT
        return [ ACTION_EXPORT_PART_2D, ACTION_EXPORT_FACE, ACTION_EXPORT_PATHS ]
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_SMOOTHING
          return [ ACTION_EXPORT_PART_2D, ACTION_EXPORT_FACE, ACTION_EXPORT_PATHS ]
        end
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
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.25,0V.75H1M.083,.167L.25,0L.417,.167M.833,.583L1,.75L.833,.917M.042,.5V.958H.5V.5Z'))
        when ACTION_OPTION_OPTIONS_SMOOTHING
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,.719L.97,.548L.883,.398L.75,.286L.587,.227H.413L.25,.286L.117,.398L.03,.548L0,.719'))
        when ACTION_OPTION_OPTIONS_MERGE_HOLES
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,.167L.5,0L1,.167L.75,.25L.5,.167L.25,.25ZM.25,.833L.5,.75L.75,.833L.5,.917ZM.5,.333V.667M.667,.5H.333'))
        when ACTION_OPTION_OPTIONS_INCLUDE_PATHS
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M.167,0V1M0,.167H1M0,.833H1M.833,0V1'))
        end
      end

      super
    end


    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      view.model.selection.clear

    end

    def onActionChanged(action)

      case action
      when ACTION_EXPORT_PART_3D
        set_action_handler(SmartExportPart3dActionHandler.new(self, fetch_action_handler))
      when ACTION_EXPORT_PART_2D
        set_action_handler(SmartExportPart2dActionHandler.new(self, fetch_action_handler))
      when ACTION_EXPORT_FACE
        set_action_handler(SmartExportFaceActionHandler.new(self, fetch_action_handler))
      when ACTION_EXPORT_PATHS
        set_action_handler(SmartExportPathsActionHandler.new(self, fetch_action_handler))
      end

      super
    end

    def onActionOptionStored(action, option_group, option)
      super
      set_root_cursor(get_action_cursor(fetch_action))
    end

  end

  # -----

  # Shared by the export action handlers : the drawing def of the hovered
  # target is computed when its key changes, then previewed in its own 3D layer.
  module SmartExportActionHandlerHelper

    LAYER_3D_ACTION_PREVIEW = 3

    # -----

    def stop
      @tool.clear_all_3d
      @tool.hide_message
      @tool.remove_root_tooltip
      super
    end

    # -----

    def onToolActionOptionStored(tool, action, option_group, option)
      @drawing_key = nil  # Options change the drawing def
      _preview_action
    end

    def onToolTransactionUndo(tool, model)
      _restart  # The drawing def is outdated
    end

    def onToolTransactionRedo(tool, model)
      _restart  # The drawing def is outdated
    end

    # -----

    protected

    def _preview_action(highlighted = false)
      @previewed = true
      @tool.clear_3d(LAYER_3D_ACTION_PREVIEW)
      if (key = _get_drawing_key).nil?
        @drawing_key = nil
        @drawing_def = nil
        @projection_def = nil
        return
      end
      if key != @drawing_key
        @drawing_key = key
        @drawing_def = _compute_drawing_def
        @drawing_def = nil unless @drawing_def.is_a?(DrawingDef)
        @projection_def = @drawing_def.nil? ? nil : _compute_projection_def(@drawing_def)
        @projection_def = nil unless @projection_def.is_a?(DrawingProjectionDef)
      end
      _preview_action_draw(highlighted)
    end

    # The identity of the drawing def to export, nil if nothing to export
    def _get_drawing_key
      nil
    end

    def _compute_drawing_def
      nil
    end

    def _compute_projection_def(drawing_def)
      nil
    end

    def _preview_action_draw(highlighted)
      _preview_projection(highlighted) unless @projection_def.nil?
    end

    def _do_action
      return UI.beep if @drawing_def.nil?
      _write_drawing(_create_write_worker(@drawing_def))
      _preview_action
    end

    def _create_write_worker(drawing_def)
      nil
    end

    # -----

    def _is_picked_face_curved?(picker)
      face = picker.picked_face
      !face.nil? && !face.edges.index { |edge| edge.soft? }.nil? && !SurfaceManipulator.new.populate_from_face(face).flat?
    end

    def _show_error(error_key)
      @tool.set_root_tooltip("⚠ #{PLUGIN.get_i18n_string(error_key)}", SmartTool::MESSAGE_TYPE_ERROR)
      @tool.push_cursor(SmartCursorManager.cursor_select_error)
    end

    def _fetch_option_smoothing
      @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_SMOOTHING)
    end

    # -- Preview --

    def _get_projection_box_offset
      15
    end

    def _get_projection_layer_color(layer_def)
      SmartExportTool::COLOR_PART_UPPER
    end

    def _get_projection_poly_line_stipple(layer_def, poly_def)
      poly_def.is_a?(DrawingProjectionPolygonDef) && !poly_def.ccw? ? Kuix::LINE_STIPPLE_SHORT_DASHES : Kuix::LINE_STIPPLE_SOLID
    end

    def _preview_projection(highlighted)

      drawing_def = @drawing_def
      projection_def = @projection_def
      smoothing = _fetch_option_smoothing
      unit = @tool.get_unit

      inch_offset = Sketchup.active_model.active_view.pixels_to_model(_get_projection_box_offset, Geom::Point3d.new.transform(drawing_def.transformation))

      k_group = Kuix::Group.new
      k_group.transformation = drawing_def.transformation * projection_def.transformation
      @tool.append_3d(k_group, LAYER_3D_ACTION_PREVIEW)

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

        color = _get_projection_layer_color(layer_def)

        layer_def.poly_defs.each do |poly_def|

          line_stipple = _get_projection_poly_line_stipple(layer_def, poly_def)

          if smoothing && !poly_def.curve_def.nil?
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
            k_points.size = 2 * unit
            k_points.style = Kuix::POINT_STYLE_SQUARE
            k_points.fill_color = Kuix::COLOR_MEDIUM_GREY
            k_points.stroke_color = nil
            points_entities << k_points

            k_points = Kuix::Points.new
            k_points.add_points([ poly_def.points.last ])
            k_points.size = 2.5 * unit
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
      k_rectangle = Kuix::RectangleMotif3d.new
      k_rectangle.bounds.origin.copy!(projection_def.bounds.min)
      k_rectangle.bounds.size.copy!(projection_def.bounds)
      k_rectangle.bounds.inflate!(inch_offset, inch_offset, 0)
      k_rectangle.color = Kuix::COLOR_BLACK
      k_rectangle.line_width = 1
      k_rectangle.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      k_group.append(k_rectangle)

      if drawing_def.input_line_manipulator.is_a?(EdgeManipulator)

        # Highlight input edge
        k_segments = Kuix::Segments.new
        k_segments.transformation = projection_def.transformation.inverse
        k_segments.add_segments(drawing_def.input_line_manipulator.segment)
        k_segments.color = SmartExportTool::COLOR_ACTION
        k_segments.line_width = 3
        k_segments.on_top = true
        k_group.append(k_segments)

      elsif drawing_def.input_line_manipulator.is_a?(LineManipulator)

        # Highlight input line
        k_line = Kuix::Line.new
        k_line.transformation = projection_def.transformation.inverse
        k_line.position = drawing_def.input_line_manipulator.position
        k_line.direction = drawing_def.input_line_manipulator.direction
        k_line.color = SmartExportTool::COLOR_ACTION
        k_line.line_width = 2
        k_group.append(k_line)

      end

      # Axes helper
      k_axes_helper = Kuix::AxesHelper.new
      k_axes_helper.box_0.visible = false
      k_axes_helper.box_z.visible = false
      k_group.append(k_axes_helper)

    end

    # -- Write --

    def _write_drawing(worker)

      response = worker.run

      if response[:errors]
        @tool.notify_errors(response[:errors])
      elsif response[:export_path]
        @tool.notify_success(
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

  # -----

  # Exports a part : picked like a selection, without rectangle, multiple or tree selections
  class SmartExportPartActionHandler < SmartSelectActionHandler

    include SmartExportActionHandlerHelper

    def initialize(action, tool, previous_action_handler = nil)
      super

      # Create 3D layers
      tool.create_3d(LAYER_3D_PART_PREVIEW)
      tool.create_3d(LAYER_3D_ACTION_PREVIEW)

    end

    # -- STATE --

    def get_state_cursor(state)

      case state

      when STATE_SELECT
        return @tool.get_action_cursor(@action)

      end

      super
    end

    # -----

    def onToolLButtonDown(tool, flags, x, y, view)
      consumed = super
      @mouse_down_point_2d = nil  # No rectangle selection on drag
      _preview_action(true)
      consumed
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      UI.beep if @state == STATE_SELECT && !has_active_part?
      super
    end

    def onPickerChanged(picker, view)
      @previewed = false
      super
      _preview_action unless @previewed  # Already done if the active part changed
    end

    def onActivePartChanged(part_entity_path, part, highlighted = false)
      super
      _preview_action(highlighted)
    end

    def onSelected
      _do_action if has_active_part?
    end

    # -----

    protected

    def _start_with_model_selection?
      false
    end

    def _preview_part_mesh?
      false # The action preview draws it
    end

    def _get_part_error_cursor
      SmartCursorManager.cursor_select_error
    end

    def _check_flat_face?
      false
    end

    def _pick_part(picker, view)
      if picker.picked_face_path.is_a?(Array)

        if _check_flat_face? && _is_picked_face_curved?(picker)
          _reset_active_part
          return _show_error('tool.smart_export.error.not_flat_face')
        end

        if (picked_part_entity_path = _get_part_entity_path_from_path(picker.picked_face_path)).is_a?(Array)

          active_path = Sketchup.active_model.active_path
          if active_path &&
             @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_ANCHOR) &&
             active_path.length > picked_part_entity_path.length &&
             active_path.last != picked_part_entity_path.last
            _reset_active_part
            return _show_error('tool.smart_export.error.incompatible_active_path')
          end

          if (picked_part = _generate_part_from_path(picked_part_entity_path)).is_a?(Part)
            _set_active_part(picked_part_entity_path, picked_part)
            return
          end

        end

        _reset_active_part
        return _show_error('tool.smart_export.error.not_part')
      end
      _reset_active_part
    end

    # -----

    def _get_drawing_key
      return nil unless has_active_part?
      [ get_active_part_entity_path ]
    end

    def _preview_action(highlighted = false)
      super
      return unless has_active_part?
      @tool.pop_to_root_cursor

      # Show part infos
      @tool.set_root_tooltip([ [ "##{_get_active_part_name}", @drawing_def.nil? || @drawing_def.input_view.nil? ? nil : "(#{PLUGIN.get_i18n_string("core.component.three_viewer.view_#{@drawing_def.input_view}")})" ], _get_active_part_material_name, '-', _get_active_part_size, _get_active_part_icons ])

    end

  end

  class SmartExportPart3dActionHandler < SmartExportPartActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartExportTool::ACTION_EXPORT_PART_3D, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_picker(state)

      case state

      when STATE_SELECT
        return SmartPicker.new(tool: @tool, observer: self)

      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_1') + '.'
      end

      super
    end

    # -----

    protected

    def _compute_drawing_def
      CommonDrawingDecompositionWorker.new(Sketchup::InstancePath.new(get_active_part_entity_path),
        origin_position: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_ANCHOR) ? CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingDecompositionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
        ignore_surfaces: true,
        ignore_edges: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
      ).run
    end

    def _preview_action_draw(highlighted)
      return if @drawing_def.nil?

      inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@drawing_def.transformation))

      k_group = Kuix::Group.new
      k_group.transformation = @drawing_def.transformation
      @tool.append_3d(k_group, LAYER_3D_ACTION_PREVIEW)

        # Highlight faces
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(@drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
        k_mesh.background_color = highlighted ? SmartExportTool::COLOR_MESH_HIGHLIGHTED : SmartExportTool::COLOR_MESH
        k_group.append(k_mesh)

        # Box helper
        k_box = Kuix::BoxMotif3d.new
        k_box.bounds.copy!(@drawing_def.bounds)
        k_box.bounds.inflate_all!(inch_offset)
        k_box.color = Kuix::COLOR_BLACK
        k_box.line_width = 1
        k_box.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
        k_group.append(k_box)

        # Axes helper
        k_axes_helper = Kuix::AxesHelper.new
        k_group.append(k_axes_helper)

    end

    def _create_write_worker(drawing_def)
      CommonWriteDrawing3dWorker.new(drawing_def,
        file_name: _get_active_part_name(true),
        file_format: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_FILE_FORMAT),
        unit: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_UNIT),
        switch_yz: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_SWITCH_YZ)
      )
    end

  end

  class SmartExportPart2dActionHandler < SmartExportPartActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartExportTool::ACTION_EXPORT_PART_2D, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_picker(state)

      case state

      when STATE_SELECT
        return SmartPicker.new(tool: @tool, observer: self, pick_edges: true, pick_clines: true, pick_axes: true)

      end

      super
    end

    def get_state_status(state)

      case state

      when STATE_SELECT
        return super +
               ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_2') + '.'
      end

      super
    end

    # -----

    protected

    def _check_flat_face?
      true
    end

    # The projection follows the picked face and line, not only the part
    def _get_drawing_key
      return nil unless has_active_part? && !@picker.nil?
      [ get_active_part_entity_path, @picker.picked_face_path, @picker.picked_edge_path, @picker.picked_cline_path, @picker.picked_axes_path, @picker.picked_axes_line ]
    end

    def _compute_drawing_def
      part = get_active_part
      faces_one = @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_FACES, SmartExportTool::ACTION_OPTION_FACES_ONE)
      CommonDrawingDecompositionWorker.new(Sketchup::InstancePath.new(get_active_part_entity_path),
        input_local_x_axis: part.def.size.oriented_axis(X_AXIS),
        input_local_y_axis: part.def.size.oriented_axis(Y_AXIS),
        input_local_z_axis: part.def.size.oriented_axis(Z_AXIS),
        input_plane_manipulator: @picker.picked_plane_manipulator,
        input_line_manipulator: @picker.picked_line_manipulator,
        face_validator: faces_one ? CommonDrawingDecompositionWorker::FACE_VALIDATOR_ONE : CommonDrawingDecompositionWorker::FACE_VALIDATOR_ALL,
        ignore_edges: !@tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_INCLUDE_PATHS),
        edge_validator: faces_one ? CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY_COPLANAR : CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
      ).run
    end

    def _compute_projection_def(drawing_def)
      CommonDrawingProjectionWorker.new(drawing_def,
        origin_position: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_ANCHOR) ? CommonDrawingProjectionWorker::ORIGIN_POSITION_DEFAULT : CommonDrawingProjectionWorker::ORIGIN_POSITION_BOUNDS_MIN,
        merge_holes: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_MERGE_HOLES),
        merge_holes_overflow: @tool.fetch_action_option_length(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_MERGE_HOLES_OVERFLOW),
        include_borders_layers: true
      ).run
    end

    def _get_projection_box_offset
      30
    end

    def _get_projection_layer_color(layer_def)
      if layer_def.type_upper?
        SmartExportTool::COLOR_PART_UPPER
      elsif layer_def.type_holes?
        SmartExportTool::COLOR_PART_HOLES
      elsif layer_def.type_paths?
        layer_def.has_color? ? layer_def.color : SmartExportTool::COLOR_PART_PATH
      elsif layer_def.type_borders?
        border_color = get_active_part.group.def.material_color
        border_color.nil? ? SmartExportTool::COLOR_PART_BORDERS : border_color
      else
        SmartExportTool::COLOR_PART_DEPTH
      end
    end

    def _get_projection_poly_line_stipple(layer_def, poly_def)
      return Kuix::LINE_STIPPLE_SHORT_DASHES if poly_def.is_a?(DrawingProjectionPolygonDef) && !poly_def.ccw?
      layer_def.type_borders? ? Kuix::LINE_STIPPLE_LONG_DASHES : Kuix::LINE_STIPPLE_SOLID
    end

    def _create_write_worker(drawing_def)
      file_name = _get_active_part_name(true)
      file_name += " - #{PLUGIN.get_i18n_string("core.component.three_viewer.view_#{drawing_def.input_view}").upcase}" unless drawing_def.input_view.nil?
      CommonWriteDrawing2dWorker.new(drawing_def,
        file_name: file_name,
        file_format: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_FILE_FORMAT),
        dxf_depth_to_z: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'dxf_depth_to_z'),
        unit: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_UNIT),
        anchor: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_ANCHOR),
        smoothing: _fetch_option_smoothing,
        merge_holes: @tool.fetch_action_option_boolean(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_MERGE_HOLES),
        merge_holes_overflow: @tool.fetch_action_option_length(@action, SmartExportTool::ACTION_OPTION_OPTIONS, SmartExportTool::ACTION_OPTION_OPTIONS_MERGE_HOLES_OVERFLOW),
        parts_stroke_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_stroke_color'),
        parts_fill_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_fill_color'),
        parts_holes_stroke_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_holes_stroke_color'),
        parts_holes_fill_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_holes_fill_color'),
        parts_depths_stroke_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_depths_stroke_color'),
        parts_depths_fill_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_depths_fill_color'),
        parts_paths_stroke_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_paths_stroke_color'),
        parts_paths_fill_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_paths_fill_color')
      )
    end

  end

  # -----

  # Exports a drawing that isn't a part : a face or paths
  class SmartExportDrawingActionHandler < SmartActionHandler

    include SmartExportActionHandlerHelper

    def initialize(action, tool, previous_action_handler = nil)
      super

      # Create 3D layers
      tool.create_3d(LAYER_3D_ACTION_PREVIEW)

    end

    # -----

    def onToolLButtonDown(tool, flags, x, y, view)
      _preview_action(true)
      true
    end

    def onToolLButtonUp(tool, flags, x, y, view)
      _do_action
      true
    end

    def onPickerChanged(picker, view)
      @tool.remove_root_tooltip
      @tool.pop_to_root_cursor
      if picker.picked_face_path.is_a?(Array) && _is_picked_face_curved?(picker)
        @error = true
        _show_error('tool.smart_export.error.not_flat_face')
      else
        @error = false
      end
      _preview_action
      super
    end

    # -----

    protected

    def _get_drawing_key
      return nil if @error || @picker.nil? || (input_path = _get_input_path).nil?
      [ input_path, @picker.picked_face_path, @picker.picked_edge_path, @picker.picked_cline_path, @picker.picked_axes_path, @picker.picked_axes_line ]
    end

    # The path of the entity to decompose
    def _get_input_path
      nil
    end

  end

  class SmartExportFaceActionHandler < SmartExportDrawingActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartExportTool::ACTION_EXPORT_FACE, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_edges: true, pick_clines: true, pick_axes: true)
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_3') + '.'
    end

    # -----

    protected

    def _get_input_path
      @picker.picked_face_path
    end

    def _compute_drawing_def
      CommonDrawingDecompositionWorker.new(Sketchup::InstancePath.new(@picker.picked_face_path),
        input_plane_manipulator: @picker.picked_plane_manipulator,
        input_line_manipulator: @picker.picked_line_manipulator,
        ignore_edges: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART,
      ).run
    end

    def _compute_projection_def(drawing_def)
      CommonDrawingProjectionWorker.new(drawing_def,
        origin_position: CommonDrawingProjectionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN
      ).run
    end

    def _create_write_worker(drawing_def)
      CommonWriteDrawing2dWorker.new(drawing_def,
        file_name: 'FACE',
        file_format: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_FILE_FORMAT),
        unit: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_UNIT),
        smoothing: _fetch_option_smoothing,
        parts_stroke_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_stroke_color'),
        parts_fill_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_fill_color')
      )
    end

  end

  class SmartExportPathsActionHandler < SmartExportDrawingActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartExportTool::ACTION_EXPORT_PATHS, tool, previous_action_handler)
    end

    # -- STATE --

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_context_by_edge: true, pick_edges: true, pick_clines: true, pick_axes: true)
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.tab_key") + ' = ' + PLUGIN.get_i18n_string('tool.smart_export.action_0') + '.'
    end

    # -----

    protected

    def _get_input_path
      return nil if @picker.picked_face_path.nil? && @picker.picked_edge_path.nil?
      @picker.picked_context_path
    end

    def _compute_drawing_def
      CommonDrawingDecompositionWorker.new(Sketchup::InstancePath.new(@picker.picked_context_path),
        ignore_faces: true,
        input_plane_manipulator: @picker.picked_plane_manipulator,
        input_line_manipulator: @picker.picked_line_manipulator,
        edge_validator: CommonDrawingDecompositionWorker::EDGE_VALIDATOR_COPLANAR,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_NONE,
      ).run
    end

    def _compute_projection_def(drawing_def)
      CommonDrawingProjectionWorker.new(drawing_def,
        origin_position: CommonDrawingProjectionWorker::ORIGIN_POSITION_EDGES_BOUNDS_MIN
      ).run
    end

    def _get_projection_layer_color(layer_def)
      layer_def.has_color? ? layer_def.color : SmartExportTool::COLOR_PART_PATH
    end

    def _get_projection_poly_line_stipple(layer_def, poly_def)
      Kuix::LINE_STIPPLE_SOLID
    end

    def _create_write_worker(drawing_def)
      CommonWriteDrawing2dWorker.new(drawing_def,
        file_name: 'PATHS',
        file_format: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_FILE_FORMAT),
        unit: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_UNIT),
        smoothing: _fetch_option_smoothing,
        parts_paths_stroke_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_paths_stroke_color'),
        parts_paths_fill_color: @tool.fetch_action_option_value(@action, SmartExportTool::ACTION_OPTION_OPTIONS, 'parts_paths_fill_color')
      )
    end

  end

end
