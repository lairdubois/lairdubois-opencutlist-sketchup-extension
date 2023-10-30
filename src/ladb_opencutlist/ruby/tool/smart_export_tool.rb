module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geometrix/geometrix'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/edge_segments_helper'
  require_relative '../helper/entities_helper'
  require_relative '../manipulator/face_manipulator'
  require_relative '../manipulator/edge_manipulator'
  require_relative '../manipulator/loop_manipulator'
  require_relative '../worker/common/common_export_drawing2d_worker'
  require_relative '../worker/common/common_export_drawing3d_worker'
  require_relative '../worker/common/common_decompose_drawing_worker'
  require_relative '../worker/common/common_projection_worker'

  require 'benchmark'

  class SmartExportTool < SmartTool

    include Benchmark

    include LayerVisibilityHelper
    include EdgeSegmentsHelper
    include EntitiesHelper

    ACTION_EXPORT_PART_3D = 0
    ACTION_EXPORT_PART_2D = 1
    ACTION_EXPORT_FACE = 2

    ACTION_OPTION_FILE_FORMAT = 0
    ACTION_OPTION_UNIT = 1
    ACTION_OPTION_FACE = 2
    ACTION_OPTION_OPTIONS = 3

    ACTION_OPTION_FILE_FORMAT_DXF = 0
    ACTION_OPTION_FILE_FORMAT_STL = 1
    ACTION_OPTION_FILE_FORMAT_OBJ = 2
    ACTION_OPTION_FILE_FORMAT_SVG = 3

    ACTION_OPTION_UNIT_IN = DimensionUtils::INCHES
    ACTION_OPTION_UNIT_FT = DimensionUtils::FEET
    ACTION_OPTION_UNIT_MM = DimensionUtils::MILLIMETER
    ACTION_OPTION_UNIT_CM = DimensionUtils::CENTIMETER
    ACTION_OPTION_UNIT_M = DimensionUtils::METER

    ACTION_OPTION_FACE_ONE = 0
    ACTION_OPTION_FACE_ALL = 1

    ACTION_OPTION_OPTIONS_ANCHOR = 0
    ACTION_OPTION_OPTIONS_CURVES = 1
    ACTION_OPTION_OPTIONS_GUIDES = 2

    ACTIONS = [
      {
        :action => ACTION_EXPORT_PART_3D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_DXF, ACTION_OPTION_FILE_FORMAT_STL, ACTION_OPTION_FILE_FORMAT_OBJ ],
          ACTION_OPTION_UNIT => [ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_M, ACTION_OPTION_UNIT_IN, ACTION_OPTION_UNIT_FT ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_ANCHOR ]
        }
      },
      {
        :action => ACTION_EXPORT_PART_2D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_DXF, ACTION_OPTION_FILE_FORMAT_SVG ],
          ACTION_OPTION_UNIT => [ ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_IN ],
          ACTION_OPTION_FACE => [ ACTION_OPTION_FACE_ONE, ACTION_OPTION_FACE_ALL ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_ANCHOR, ACTION_OPTION_OPTIONS_CURVES, ACTION_OPTION_OPTIONS_GUIDES ]
        }
      },
      {
        :action => ACTION_EXPORT_FACE,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_DXF, ACTION_OPTION_FILE_FORMAT_SVG ],
          ACTION_OPTION_UNIT => [ ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_IN ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_CURVES ]
        }
      }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(0, 0, 255, 100).freeze # Sketchup::Color.new(200, 200, 0, 150).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(200, 200, 0, 200).freeze
    COLOR_MESH_DEEP = Sketchup::Color.new(50, 50, 0, 150).freeze
    COLOR_GUIDE = Kuix::COLOR_CYAN #Sketchup::Color.new(0, 104, 255).freeze
    COLOR_ACTION = Kuix::COLOR_MAGENTA
    COLOR_ACTION_FILL = Sketchup::Color.new(255, 0, 255, 51).freeze
    COLOR_ACTION_FILL_HIGHLIGHTED = Sketchup::Color.new(255, 0, 255, 102).freeze

    @@action = nil
    @@action_modifiers = {} # { action => MODIFIER }
    @@action_options = {} # { action => { OPTION_GROUP => { OPTION => bool } } }

    def initialize(material = nil)
      super(true, false)

      # Create cursors
      @cursor_export_part_3d = create_cursor('export-part-3d', 0, 0)
      @cursor_export_part_2d = create_cursor('export-part-2d', 0, 0)
      @cursor_export_face = create_cursor('export-part-2d', 0, 0)

      @cursor_export_skp = create_cursor('export-skp', 0, 0)
      @cursor_export_stl = create_cursor('export-stl', 0, 0)
      @cursor_export_obj = create_cursor('export-obj', 0, 0)
      @cursor_export_dxf = create_cursor('export-dxf', 0, 0)
      @cursor_export_svg = create_cursor('export-svg', 0, 0)

    end

    def get_stripped_name
      'export'
    end

    def setup_entities(view)
      super

    end

    # -- Actions --

    def get_action_defs  # Array<{ :action => THE_ACTION, :modifiers => [ MODIFIER_1, MODIFIER_2, ... ] }>
      ACTIONS
    end

    def get_action_status(action)


      super
    end

    def get_action_cursor(action, modifier)

      case action
      when ACTION_EXPORT_PART_3D
        return @cursor_export_part_3d
      when ACTION_EXPORT_PART_2D
        return @cursor_export_part_2d
      when ACTION_EXPORT_FACE
        return @cursor_export_face
      end

      super
    end

    def get_action_option_group_unique?(action, option_group)

      case option_group
      when ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_UNIT, ACTION_OPTION_FACE
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
      when ACTION_OPTION_UNIT
        case option
        when ACTION_OPTION_UNIT_IN
          return Kuix::Label.new(DimensionUtils::UNIT_STRIPPEDNAME_INCHES)
        when ACTION_OPTION_UNIT_FT
          return Kuix::Label.new(DimensionUtils::UNIT_STRIPPEDNAME_FEET)
        when ACTION_OPTION_UNIT_MM
          return Kuix::Label.new(DimensionUtils::UNIT_STRIPPEDNAME_MILLIMETER)
        when ACTION_OPTION_UNIT_CM
          return Kuix::Label.new(DimensionUtils::UNIT_STRIPPEDNAME_CENTIMETER)
        when ACTION_OPTION_UNIT_M
          return Kuix::Label.new(DimensionUtils::UNIT_STRIPPEDNAME_METER)
        end
      when ACTION_OPTION_FACE
        case option
        when ACTION_OPTION_FACE_ONE
          return Kuix::Label.new('1')
        when ACTION_OPTION_FACE_ALL
          return Kuix::Label.new('∞')
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_ANCHOR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.273,0L0.273,0.727L1,0.727 M0.091,0.545L0.455,0.545L0.455,0.909L0.091,0.909L0.091,0.545 M0.091,0.182L0.273,0L0.455,0.182 M0.818,0.545L1,0.727L0.818,0.909'))
        when ACTION_OPTION_OPTIONS_CURVES
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M1,0.5L0.97,0.329L0.883,0.179L0.75,0.067L0.587,0.008L0.413,0.008L0.25,0.067L0.117,0.179L0.03,0.329L0,0.5'))
        when ACTION_OPTION_OPTIONS_GUIDES
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0L0.167,1 M0,0.167L1,0.167 M0,0.833L1,0.833 M0.833,0L0.833,1'))
        end
      end

      super
    end

    def store_action(action)
      @@action = action
    end

    def fetch_action
      @@action
    end

    def store_action_modifier(action, modifier)
      @@action_modifiers[action] = modifier
    end

    def fetch_action_modifier(action)
      @@action_modifiers[action]
    end

    def store_action_option(action, option_group, option, enabled)
      @@action_options[action] = {} if @@action_options[action].nil?
      @@action_options[action][option_group] = {} if @@action_options[action][option_group].nil?
      @@action_options[action][option_group][option] = enabled
    end

    def fetch_action_option(action, option_group, option)
      return get_startup_action_option(action, option_group, option) if @@action_options[action].nil? || @@action_options[action][option_group].nil? || @@action_options[action][option_group][option].nil?
      @@action_options[action][option_group][option]
    end

    def get_startup_action_option(action, option_group, option)

      case option_group
      when ACTION_OPTION_FILE_FORMAT
        case option
        when ACTION_OPTION_FILE_FORMAT_DXF
          return true
        end
      when ACTION_OPTION_UNIT
        case option
        when ACTION_OPTION_UNIT_IN
          return !DimensionUtils.instance.model_unit_is_metric
        when ACTION_OPTION_UNIT_MM
          return DimensionUtils.instance.model_unit_is_metric
        end
      when ACTION_OPTION_FACE
        case option
        when ACTION_OPTION_FACE_ALL
          return true
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_ANCHOR
          return true
        end
      end

      false
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

    # -- Events --

    def onActivate(view)
      super

      # Clear current selection
      Sketchup.active_model.selection.clear if Sketchup.active_model

    end

    def onActionChange(action, modifier)

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

        infos = [ "#{part.length} x #{part.width} x #{part.thickness}" ]
        infos << "#{part.material_name} (#{Plugin.instance.get_i18n_string("tab.materials.type_#{part.group.material_type}")})" unless part.material_name.empty?
        infos << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0L0.5,0.2 M0.5,0.4L0.5,0.6 M0.5,0.8L0.5,1 M0,0.2L0.3,0.5L0,0.8L0,0.2 M1,0.2L0.7,0.5L1,0.8L1,0.2')) if part.flipped
        infos << Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.6,0L0.4,0 M0.6,0.4L0.8,0.2L0.5,0.2 M0.8,0.2L0.8,0.5 M0.8,0L1,0L1,0.2 M1,0.4L1,0.6 M1,0.8L1,1L0.8,1 M0.2,0L0,0L0,0.2 M0,1L0,0.4L0.6,0.4L0.6,1L0,1')) if part.resized

        show_infos("#{part.saved_number ? "[#{part.saved_number}] " : ''}#{part.name}", infos)

        if is_action_export_part_2d?

          @active_drawing_def = CommonDecomposeDrawingWorker.new(@active_part_entity_path, {
            'input_face_path' => @input_face_path,
            'input_edge_path' => @input_edge.nil? ? nil : @input_face_path + [ @input_edge ],
            'use_bounds_min_as_origin' => !fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR),
            'face_validator' => fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACE, ACTION_OPTION_FACE_ONE) ? CommonDecomposeDrawingWorker::FACE_VALIDATOR_ONE : CommonDecomposeDrawingWorker::FACE_VALIDATOR_ALL,
            'ignore_edges' => !fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_GUIDES),
            'edge_validator' => CommonDecomposeDrawingWorker::EDGE_VALIDATOR_STRAY_COPLANAR
          }).run
          if @active_drawing_def.is_a?(DrawingDef)

            inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

            projection_def = CommonProjectionWorker.new(@active_drawing_def, {
              'down_to_top_union' => false,
              'passthrough_holes' => false
            }).run

            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation
            @space.append(preview)

            projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top
              layer_def.polygon_defs.each do |polygon_def|

                segments = Kuix::Segments.new
                segments.add_segments(polygon_def.segments)
                case layer_def.position
                when CommonProjectionWorker::LAYER_POSITION_TOP
                  segments.color = Kuix::COLOR_BLUE
                when CommonProjectionWorker::LAYER_POSITION_BOTTOM
                  segments.color = Kuix::COLOR_RED
                else
                  segments.color = Kuix::COLOR_BLUE.blend(Kuix::COLOR_WHITE, 0.5)
                end
                segments.line_width = 2
                segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES unless polygon_def.outer?
                segments.on_top = true
                preview.append(segments)

                # Highlight arcs (if activated)
                if fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CURVES)
                  polygon_def.loop_def.portions.grep(Geometrix::ArcLoopPortionDef).each do |portion|

                    segments = Kuix::Segments.new
                    segments.add_segments(portion.segments)
                    segments.color = COLOR_BRAND
                    segments.line_width = 2
                    segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES unless polygon_def.outer?
                    segments.on_top = true
                    preview.append(segments)

                  end
                end

              end
            end

            @active_drawing_def.edge_manipulators.each do |edge_manipulator|

              # Highlight edge
              segments = Kuix::Segments.new
              segments.add_segments(edge_manipulator.segment)
              segments.color = COLOR_GUIDE
              segments.line_width = 2
              segments.on_top = true
              preview.append(segments)

            end

            bounds = Geom::BoundingBox.new
            bounds.add(Geom::Point3d.new(@active_drawing_def.bounds.min.x, @active_drawing_def.bounds.min.y, @active_drawing_def.bounds.max.z))
            bounds.add(@active_drawing_def.bounds.max)
            bounds.add(Geom::Point3d.new(0, 0, @active_drawing_def.bounds.max.z))

            # Box helper
            box_helper = Kuix::RectangleMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 1
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            preview.append(box_helper)

            if @active_drawing_def.input_edge_manipulator

              # Highlight input edge
              segments = Kuix::Segments.new
              segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
              segments.color = COLOR_ACTION
              segments.line_width = 3
              segments.on_top = true
              preview.append(segments)

            end

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, @active_drawing_def.bounds.max.z))
            axes_helper.box_0.visible = false
            axes_helper.box_z.visible = false
            preview.append(axes_helper)

          end

        else

          @active_drawing_def = CommonDecomposeDrawingWorker.new(@active_part_entity_path, {
            'use_bounds_min_as_origin' => !fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR),
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
              mesh.background_color = COLOR_MESH
              preview.append(mesh)

            end

            @active_drawing_def.edge_manipulators.each do |edge_info|

              # Highlight edge
              segments = Kuix::Segments.new
              segments.add_segments(EdgeManipulator.new(edge_info.edge, edge_info.transformation).segment)
              segments.color = COLOR_GUIDE
              segments.line_width = 2
              segments.on_top = true
              preview.append(segments)

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

        end

      else

        @active_drawing_def = nil

      end

    end

    def _set_active_face(face_path, face, highlighted = false)
      super

      if face

        @active_drawing_def = CommonDecomposeDrawingWorker.new(@input_face_path, {
          'use_bounds_min_as_origin' => true,
          'input_face_path' => @input_face_path,
          'input_edge_path' => @input_edge.nil? ? nil : @input_face_path + [ @input_edge ],
        }).run
        if @active_drawing_def.is_a?(DrawingDef)

          projection_def = CommonProjectionWorker.new(@active_drawing_def).run

          inch_offset = Sketchup.active_model.active_view.pixels_to_model(15, Geom::Point3d.new.transform(@active_drawing_def.transformation))

          preview = Kuix::Group.new
          preview.transformation = @active_drawing_def.transformation
          @space.append(preview)

          projection_def.layer_defs.reverse.each do |layer_def| # reverse layer order to present from Bottom to Top
            layer_def.polygon_defs.each do |polygon_def|

              segments = Kuix::Segments.new
              segments.add_segments(polygon_def.segments)
              segments.color = Kuix::COLOR_BLUE
              segments.line_width = 2
              segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES unless polygon_def.outer?
              segments.on_top = true
              preview.append(segments)

              # Highlight arcs (if activated)
              if fetch_action_option(ACTION_EXPORT_FACE, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CURVES)
                polygon_def.loop_def.portions.grep(Geometrix::ArcLoopPortionDef).each do |portion|

                  segments = Kuix::Segments.new
                  segments.add_segments(portion.segments)
                  segments.color = COLOR_BRAND
                  segments.line_width = 2
                  segments.on_top = true
                  preview.append(segments)

                end
              end

              bounds = Geom::BoundingBox.new
              bounds.add(Geom::Point3d.new(@active_drawing_def.bounds.min.x, @active_drawing_def.bounds.min.y, @active_drawing_def.bounds.max.z))
              bounds.add(@active_drawing_def.bounds.max)
              bounds.add(Geom::Point3d.new(0, 0, @active_drawing_def.bounds.max.z))

              # Box helper
              box_helper = Kuix::RectangleMotif.new
              box_helper.bounds.origin.copy!(bounds.min)
              box_helper.bounds.size.copy!(bounds)
              box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
              box_helper.color = Kuix::COLOR_BLACK
              box_helper.line_width = 1
              box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
              preview.append(box_helper)

              if @active_drawing_def.input_edge_manipulator

                # Highlight input edge
                segments = Kuix::Segments.new
                segments.add_segments(@active_drawing_def.input_edge_manipulator.segment)
                segments.color = COLOR_ACTION
                segments.line_width = 3
                segments.on_top = true
                preview.append(segments)

              end

              # Axes helper
              axes_helper = Kuix::AxesHelper.new
              axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, @active_drawing_def.bounds.max.z))
              axes_helper.box_0.visible = false
              axes_helper.box_z.visible = false
              preview.append(axes_helper)

            end
          end

        end

      else

        @active_edge = nil

      end

    end

    # -----

    private

    def _handle_mouse_event(event = nil)
      if event == :move

        if @input_face_path

          # Check if face is not curved
          if (is_action_export_part_2d? || is_action_export_face?) && @input_face.edges.index { |edge| edge.soft? }
            _reset_ui
            show_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_flat_face')}", MESSAGE_TYPE_ERROR)
            push_cursor(@cursor_select_error)
            return
          end

          if is_action_export_part_3d? || is_action_export_part_2d?

            input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
            if input_part_entity_path

              part = _generate_part_from_path(input_part_entity_path)
              if part
                _set_active_part(input_part_entity_path, part)
              else
                _reset_active_part
                show_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
              end
              return

            else
              _reset_active_part
              show_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
              push_cursor(@cursor_select_error)
              return
            end

          elsif is_action_export_face?

            _set_active_face(@input_face_path, @input_face)
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
        end

      elsif event == :l_button_up || event == :l_button_dblclick

        if is_action_export_part_3d?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = @active_part.name
          file_format = nil
          if fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_STL)
            file_format = FILE_FORMAT_STL
          elsif fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_OBJ)
            file_format = FILE_FORMAT_OBJ
          elsif fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
            file_format = FILE_FORMAT_DXF
          end
          unit = nil
          if fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_IN)
            unit = DimensionUtils::INCHES
          elsif fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_FT)
            unit = DimensionUtils::FEET
          elsif fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_MM)
            unit = DimensionUtils::MILLIMETER
          elsif fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_CM)
            unit = DimensionUtils::CENTIMETER
          elsif fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_M)
            unit = DimensionUtils::METER
          end

          worker = CommonExportDrawing3dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('tool.smart_export.success.exported_to', { :export_path => response[:export_path] }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

        elsif is_action_export_part_2d?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = @active_part.nil? ? nil : @active_part.name
          file_format = nil
          if fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
            file_format = FILE_FORMAT_DXF
          elsif fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
            file_format = FILE_FORMAT_SVG
          end
          unit = nil
          if fetch_action_option(fetch_action, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_IN)
            unit = DimensionUtils::INCHES
          elsif fetch_action_option(fetch_action, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_MM)
            unit = DimensionUtils::MILLIMETER
          elsif fetch_action_option(fetch_action, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_CM)
            unit = DimensionUtils::CENTIMETER
          end
          anchor = fetch_action_option(fetch_action, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR)
          curves = fetch_action_option(fetch_action, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CURVES)

          worker = CommonExportDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'anchor' => anchor,
            'curves' => curves
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('tool.smart_export.success.exported_to', { :export_path => response[:export_path] }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

        elsif is_action_export_face?

          if @active_drawing_def.nil?
            UI.beep
            return
          end

          file_name = 'FACE'
          file_format = nil
          if fetch_action_option(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_DXF)
            file_format = FILE_FORMAT_DXF
          elsif fetch_action_option(ACTION_EXPORT_FACE, ACTION_OPTION_FILE_FORMAT, ACTION_OPTION_FILE_FORMAT_SVG)
            file_format = FILE_FORMAT_SVG
          end
          unit = nil
          if fetch_action_option(fetch_action, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_IN)
            unit = DimensionUtils::INCHES
          elsif fetch_action_option(fetch_action, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_MM)
            unit = DimensionUtils::MILLIMETER
          elsif fetch_action_option(fetch_action, ACTION_OPTION_UNIT, ACTION_OPTION_UNIT_CM)
            unit = DimensionUtils::CENTIMETER
          end
          curves = fetch_action_option(fetch_action, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CURVES)

          worker = CommonExportDrawing2dWorker.new(@active_drawing_def, {
            'file_name' => file_name,
            'file_format' => file_format,
            'unit' => unit,
            'curves' => curves
          })
          response = worker.run

          if response[:errors]
            notify_errors(response[:errors])
          elsif response[:export_path]
            notify_success(
              Plugin.instance.get_i18n_string('tool.smart_export.success.exported_to', { :export_path => response[:export_path] }),
              [
                {
                  :label => Plugin.instance.get_i18n_string('default.open'),
                  :block => lambda { Plugin.instance.execute_command('core_open_external_file', { 'path' => response[:export_path] }) }
                }
              ]
            )
          end

        end

      end

    end

  end

end