module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../lib/geom2d/geom2d'
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

    ACTION_OPTION_FACE_SINGLE = 0
    ACTION_OPTION_FACE_COPLANAR = 1
    ACTION_OPTION_FACE_PARALLEL = 2
    ACTION_OPTION_FACE_EXPOSED = 3

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
          ACTION_OPTION_FACE => [ ACTION_OPTION_FACE_SINGLE, ACTION_OPTION_FACE_COPLANAR, ACTION_OPTION_FACE_PARALLEL, ACTION_OPTION_FACE_EXPOSED ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_ANCHOR, ACTION_OPTION_OPTIONS_CURVES, ACTION_OPTION_OPTIONS_GUIDES ]
        }
      }
    ].freeze

    COLOR_MESH = Sketchup::Color.new(200, 200, 0, 150).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(200, 200, 0, 200).freeze
    COLOR_MESH_DEEP = Sketchup::Color.new(50, 50, 0, 150).freeze
    COLOR_GUIDE = Sketchup::Color.new(0, 104, 255).freeze
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
        when ACTION_OPTION_FACE_SINGLE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.375L0.25,0.25L0.5,0.375L0.25,0.5L0,0.375Z'))
        when ACTION_OPTION_FACE_COPLANAR
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.375L0.25,0.25L0.5,0.375L0.25,0.5L0,0.375Z M0.25,0.25L0.5,0.125L1,0.375L0.75,0.5L0.5,0.375Z'))
        when ACTION_OPTION_FACE_PARALLEL
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.375L0.25,0.25L0.5,0.375L0.25,0.5L0,0.375Z M0.25,0.25L0.5,0.125L1,0.375L0.75,0.5L0.5,0.375Z M0.5,0.813L0.25,0.688L0.5,0.563L0.75,0.688L0.5,0.813Z'))
        when ACTION_OPTION_FACE_EXPOSED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0.375L0.25,0.25L0.5,0.375L0.25,0.5L0,0.375Z M0.25,0.25L0.5,0.125L1,0.375L0.75,0.5L0.5,0.375Z M0.5,0.813L0.25,0.688L0.5,0.563L0.75,0.688L0.5,0.813Z'))
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
        when ACTION_OPTION_FACE_PARALLEL
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

    def onDeactivate(view)
      super

      # @group.erase! unless @group.nil?

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

        notify_infos("#{part.saved_number ? "[#{part.saved_number}] " : ''}#{part.name}", infos)

        transformation = PathUtils::get_transformation(@active_part_entity_path)

        inch_offset = Sketchup.active_model.active_view.pixels_to_model(5, Geom::Point3d.new.transform(transformation))

        if is_action_export_part_2d?

          if fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACE, ACTION_OPTION_FACE_EXPOSED)
            face_validator = CommonDecomposeDrawingWorker::FACE_VALIDATOR_EXPOSED
          elsif fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACE, ACTION_OPTION_FACE_PARALLEL)
            face_validator = CommonDecomposeDrawingWorker::FACE_VALIDATOR_PARALLEL
          elsif fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_FACE, ACTION_OPTION_FACE_COPLANAR)
            face_validator = CommonDecomposeDrawingWorker::FACE_VALIDATOR_COPLANAR
          else
            face_validator = CommonDecomposeDrawingWorker::FACE_VALIDATOR_SINGLE
          end

          options = {
            'input_face_path' => @input_face_path,
            'input_edge_path' => @input_edge.nil? ? nil : @input_face_path + [ @input_edge ],
            'use_bounds_min_as_origin' => !fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR),
            'face_validator' => face_validator,
            'ignore_edges' => !fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_GUIDES),
            'edge_validator' => CommonDecomposeDrawingWorker::EDGE_VALIDATOR_STRAY_COPLANAR
          }

          @active_drawing_def = CommonDecomposeDrawingWorker.new(@active_part_entity_path, options).run
          if @active_drawing_def.is_a?(DrawingDef)

            # Compute face depths
            @active_drawing_def.face_manipulators.each do |face_manipulator|
              if face_manipulator.parallel?(@active_drawing_def.input_face_manipulator) && @active_drawing_def.bounds.depth > 0
                face_manipulator.data[:depth] = @active_drawing_def.bounds.max.distance_to_plane(face_manipulator.plane).round(6)
                face_manipulator.data[:depth_ratio] = face_manipulator.data[:depth] / @active_drawing_def.bounds.depth
              else
                face_manipulator.data[:depth] = (@active_drawing_def.bounds.max.z - face_manipulator.outer_loop_points.max { |p1, p2| p1.z <=> p2.z }.z).round(6)
                face_manipulator.data[:depth_ratio] = 0.0
              end

            end


            # DEBUG

            # _draw_outer_shape(@active_drawing_def)

            # DEBUG




            preview = Kuix::Group.new
            preview.transformation = @active_drawing_def.transformation
            @space.append(preview)

            @active_drawing_def.face_manipulators.each do |face_manipulator|

              # Highlight face
              mesh = Kuix::Mesh.new
              mesh.add_triangles(face_manipulator.triangles)
              mesh.background_color = COLOR_MESH_DEEP.blend((highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH), face_manipulator.data[:depth_ratio])
              preview.append(mesh)

              # Highlight arcs (if activated)
              if fetch_action_option(ACTION_EXPORT_PART_2D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_CURVES)
                face_manipulator.loop_manipulators.each do |loop_manipulator|
                  loop_manipulator.loop_def.portions.grep(Geometrix::ArcLoopPortionDef).each do |portion|

                    segments = Kuix::Segments.new
                    segments.add_segments(portion.segments)
                    segments.color = COLOR_BRAND
                    segments.line_width = 3
                    segments.on_top = true
                    preview.append(segments)

                    # DEBUG

                    # # xaxis
                    # line = Kuix::LineMotif.new
                    # line.start.copy!(portion.ellipse_def.center)
                    # line.end.copy!(portion.ellipse_def.center.transform(Geom::Transformation.translation(portion.ellipse_def.xaxis)))
                    # line.color = Kuix::COLOR_RED
                    # line.line_width = 2
                    # line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
                    # line.on_top = true
                    # preview.append(line)
                    #
                    # # yaxis
                    # line = Kuix::LineMotif.new
                    # line.start.copy!(portion.ellipse_def.center)
                    # line.end.copy!(portion.ellipse_def.center.transform(Geom::Transformation.translation(portion.ellipse_def.yaxis)))
                    # line.color = Kuix::COLOR_GREEN
                    # line.line_width = 2
                    # line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
                    # line.on_top = true
                    # preview.append(line)
                    #
                    # # normal
                    # line = Kuix::LineMotif.new
                    # line.start.copy!(portion.ellipse_def.center)
                    # line.end.copy!(portion.ellipse_def.center.transform(Geom::Transformation.translation(portion.normal)))
                    # line.color = Kuix::COLOR_BLUE
                    # line.line_width = 2
                    # line.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
                    # line.on_top = true
                    # preview.append(line)
                    #
                    # # start point
                    # axes_helper = Kuix::AxesHelper.new(200, 5, Kuix::COLOR_GREEN)
                    # axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(portion.start_point.to_a))
                    # axes_helper.box_x.visible = false
                    # axes_helper.box_y.visible = false
                    # axes_helper.box_z.visible = false
                    # preview.append(axes_helper)
                    #
                    # # mid point
                    # axes_helper = Kuix::AxesHelper.new(200, 5, Kuix::COLOR_CYAN)
                    # axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(portion.mid_point.to_a))
                    # axes_helper.box_x.visible = false
                    # axes_helper.box_y.visible = false
                    # axes_helper.box_z.visible = false
                    # preview.append(axes_helper)
                    #
                    # # end point
                    # axes_helper = Kuix::AxesHelper.new(200, 5, Kuix::COLOR_RED)
                    # axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(portion.end_point.to_a))
                    # axes_helper.box_x.visible = false
                    # axes_helper.box_y.visible = false
                    # axes_helper.box_z.visible = false
                    # preview.append(axes_helper)

                    # DEBUG

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
            box_helper.line_width = 2
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

          options = {
            'use_bounds_min_as_origin' => !fetch_action_option(ACTION_EXPORT_PART_3D, ACTION_OPTION_OPTIONS, ACTION_OPTION_OPTIONS_ANCHOR),
            'ignore_edges' => true
          }

          @active_drawing_def = CommonDecomposeDrawingWorker.new(@active_part_entity_path, options).run
          if @active_drawing_def.is_a?(DrawingDef)

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
            box_helper.line_width = 2
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

        transformation = PathUtils::get_transformation(face_path)

        origin, x_axis, y_axis, z_axis, @active_edge = _get_input_axes

        # Change axis transformation
        t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
        ti = t.inverse

        # Compute new bounds
        bounds = Geom::BoundingBox.new
        bounds.add(_compute_children_faces_triangles([ @active_face ], ti))

        # Translate to 0,0 transformation
        to = Geom::Transformation.translation(bounds.min)

        # Combine
        tto = t * to
        export_transformation = tto.inverse

        @active_face_infos = [ FaceInfo.new(@active_face, export_transformation) ]

        face_helper = Kuix::Group.new
        face_helper.transformation = transformation * tto
        @space.append(face_helper)

          # Highlight input face
          mesh = Kuix::Mesh.new
          mesh.add_triangles(_compute_children_faces_triangles([ @active_face ], export_transformation))
          mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
          face_helper.append(mesh)

          inch_offset = Sketchup.active_model.active_view.pixels_to_model(5, Geom::Point3d.new.transform(transformation))

          # Box helper
          box_helper = Kuix::BoxMotif.new
          box_helper.bounds.size.copy!(bounds)
          box_helper.bounds.apply_offset(inch_offset, inch_offset, 0)
          box_helper.color = Kuix::COLOR_BLACK
          box_helper.line_width = 2
          box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          face_helper.append(box_helper)

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          axes_helper.box_0.visible = false
          axes_helper.box_z.visible = false
          face_helper.append(axes_helper)

          # Highlight input edge
          segments = Kuix::Segments.new
          segments.add_segments(_compute_children_edge_segments(@active_face.edges, export_transformation,[ @active_edge ]))
          segments.color = COLOR_ACTION
          segments.line_width = 3
          segments.on_top = true
          face_helper.append(segments)

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
            notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_flat_face')}", MESSAGE_TYPE_ERROR)
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
                notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
              end
              return

            else
              _reset_active_part
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_export.error.not_part')}", MESSAGE_TYPE_ERROR)
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

          # TODO
          puts Plugin.instance.get_i18n_string('tab.cutlist.success.exported_to', { :export_path => response[:export_path] })

        elsif is_action_export_part_2d? || is_action_export_face?

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
            'curves' => curves,
            'max_depth' => 0
          })
          response = worker.run

          # TODO
          puts Plugin.instance.get_i18n_string('tab.cutlist.success.exported_to', { :export_path => response[:export_path] })

        end

      end

    end

    def _get_input_axes(transformation = nil)

      input_edge = @input_edge
      if input_edge.nil? || !input_edge.used_by?(@input_face)
        input_edge = _find_longest_outer_edge(@input_face, transformation)
      end

      z_axis = @input_face.normal
      z_axis.transform!(transformation).normalize! unless transformation.nil?
      x_axis = input_edge.line[1]
      x_axis.transform!(transformation).normalize! unless transformation.nil?
      x_axis.reverse! if input_edge.reversed_in?(@input_face)
      y_axis = z_axis.cross(x_axis)

      [ ORIGIN, x_axis, y_axis, z_axis, input_edge, input_edge != @input_edge ]
    end

    def _draw_outer_shape(drawing_def)

      SKETCHUP_CONSOLE.clear

      @group = Sketchup.active_model.entities.add_group if @group.nil?
      @group.entities.clear!

      face_defs = []

      Benchmark.benchmark(CAPTION, 20, FORMAT, "TOTAL :") do |x|

        tp = x.report("Get points :")   {

          drawing_def.face_manipulators.each do |face_manipulator|

            face_def = {
              :outer => face_manipulator.outer_loop_points.map { |point| [ point.x, point.y ] },
              :holes => [],
              :depth => face_manipulator.data[:depth]
            }
            face_defs << face_def

            face_manipulator.loop_manipulators.each do |loop_manipulator|
              next if loop_manipulator.loop.outer?

              face_def[:holes] << loop_manipulator.points.map { |point| [ point.x, point.y ] }

            end

          end

        }

        layer_defs = {}
        layer_defs[drawing_def.bounds.min.z] = {
          :depth => drawing_def.bounds.min.z,
          :ps => Geom2D::PolygonSet.new
        }

        tl = x.report("Get layers :")   {

          face_defs.each do |face_def|

            f_ps = Geom2D::PolygonSet.new
            f_ps << Geom2D::Polygon.new(face_def[:outer])
            face_def[:holes].each { |hole|
              f_ps << Geom2D::Polygon.new(hole)
            }

            layer_def = layer_defs[face_def[:depth]]
            if layer_def.nil?
              layer_def = {
                :depth => face_def[:depth],
                :ps => f_ps
              }
              layer_defs[face_def[:depth]] = layer_def
            else
              layer_def[:ps] = Geom2D::Algorithms::PolygonOperation.run(layer_def[:ps], f_ps, :union)
            end

          end

        }

        ld = layer_defs.values.sort_by { |layer_def| layer_def[:depth] }

        td = x.report("Diff Up -> Down :")   {

          # Up to Down diff
          ld.each_with_index do |layer_def, index|
            next if layer_def[:ps].polygons.empty?
            ld[(index + 1)..-1].each do |lower_layer_def|
              next if lower_layer_def[:ps].polygons.empty?
              lower_layer_def[:ps] = Geom2D::Algorithms::PolygonOperation.run(lower_layer_def[:ps], layer_def[:ps], :difference)
            end
          end

        }

        tu = x.report("Union Down -> Up :")   {

          # Down to Up union
          ld.each_with_index do |layer_def, index|
            next if layer_def[:ps].polygons.empty?
            ld[(index + 1)..-1].reverse.each do |lower_layer_def|
              next if lower_layer_def[:ps].polygons.empty?
              ld[index][:ps] = Geom2D::Algorithms::PolygonOperation.run(ld[index][:ps], lower_layer_def[:ps], :union)
            end
          end

        }

        tdr = x.report("Draw :")   {

          ld.each_with_index do |layer_def, layer_index|
            next if layer_def[:ps].polygons.empty?
            bbox0 = layer_def[:ps].polygons[0].bbox
            layer_def[:ps].polygons.each_with_index do |polygon, polygon_index|

              hole = polygon_index > 0 &&
                polygon.bbox.min_x > bbox0.min_x && polygon.bbox.min_y > bbox0.min_y &&
                polygon.bbox.max_x < bbox0.max_x && polygon.bbox.max_y < bbox0.max_y

              face = @group.entities.add_face(polygon.each_vertex.map { |point| Geom::Point3d.new(point.x, point.y, layer_def[:depth]) })
              face.reverse! unless face.normal.samedirection?(Z_AXIS)
              if hole
                face.material = 'White'
              elsif layer_def[:depth] > 0
                face.material = 'DarkGray'
              else
                face.material = 'Black'
              end

            end
          end

        }

        [ tp + tl + td + tu + tdr ]
      end

      puts "--> Faces    : #{drawing_def.face_manipulators.length}"
      puts "--> Segments : #{face_defs.map { |face_def| face_def[:outer].length + face_def[:holes].map { |hole| hole.length }.sum }.sum}"

    end

  end

end