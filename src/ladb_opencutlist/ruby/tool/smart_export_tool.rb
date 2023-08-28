module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../helper/layer_visibility_helper'
  require_relative '../helper/edge_segments_helper'
  require_relative '../helper/entities_helper'
  require_relative '../model/cutlist/face_info'
  require_relative '../worker/common/common_export_instance_to_file_worker'
  require_relative '../worker/common/common_export_faces_to_file_worker'

  class SmartExportTool < SmartTool

    include LayerVisibilityHelper
    include EdgeSegmentsHelper
    include EntitiesHelper

    ACTION_EXPORT_PART_3D = 0
    ACTION_EXPORT_PART_2D = 1
    ACTION_EXPORT_FACE = 2

    ACTION_MODIFIER_SKP = 0
    ACTION_MODIFIER_STL = 1
    ACTION_MODIFIER_OBJ = 2
    ACTION_MODIFIER_SVG = 3
    ACTION_MODIFIER_DXF = 4

    ACTION_OPTION_FILE_FORMAT = 0
    ACTION_OPTION_UNIT = 1
    ACTION_OPTION_OPTIONS = 2

    ACTION_OPTION_FILE_FORMAT_SKP = 0
    ACTION_OPTION_FILE_FORMAT_STL = 1
    ACTION_OPTION_FILE_FORMAT_OBJ = 2
    ACTION_OPTION_FILE_FORMAT_SVG = 3
    ACTION_OPTION_FILE_FORMAT_DXF = 4

    ACTION_OPTION_UNIT_IN = 0
    ACTION_OPTION_UNIT_YD = 1
    ACTION_OPTION_UNIT_MM = 2
    ACTION_OPTION_UNIT_CM = 3
    ACTION_OPTION_UNIT_M = 4

    ACTION_OPTION_OPTIONS_DEPTH = 0
    ACTION_OPTION_OPTIONS_ANCHOR = 1

    GROUPS = {
      ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
      ACTION_OPTION_UNIT => [ ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_IN ],
      ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_DEPTH, ACTION_OPTION_OPTIONS_ANCHOR ]
    }

    ACTIONS = [
      {
        :action => ACTION_EXPORT_PART_3D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SKP, ACTION_OPTION_FILE_FORMAT_STL, ACTION_OPTION_FILE_FORMAT_OBJ, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_UNIT => [ ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_M, ACTION_OPTION_UNIT_IN, ACTION_OPTION_UNIT_YD ]
        }
      },
      {
        :action => ACTION_EXPORT_PART_2D,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_UNIT => [ ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_IN ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_DEPTH, ACTION_OPTION_OPTIONS_ANCHOR ]
        }
      },
      {
        :action => ACTION_EXPORT_FACE,
        :options => {
          ACTION_OPTION_FILE_FORMAT => [ ACTION_OPTION_FILE_FORMAT_SVG, ACTION_OPTION_FILE_FORMAT_DXF ],
          ACTION_OPTION_UNIT => [ ACTION_OPTION_UNIT_MM, ACTION_OPTION_UNIT_CM, ACTION_OPTION_UNIT_IN ]
        }
      },
      # { :action => ACTION_EXPORT_PART_3D, :modifiers => [ ACTION_MODIFIER_SKP, ACTION_MODIFIER_STL, ACTION_MODIFIER_OBJ, ACTION_MODIFIER_DXF ] },
      # { :action => ACTION_EXPORT_PART_2D, :modifiers => [ ACTION_MODIFIER_SVG, ACTION_MODIFIER_DXF ] },
      # { :action => ACTION_EXPORT_FACE, :modifiers => [ ACTION_MODIFIER_SVG, ACTION_MODIFIER_DXF ] },
    ].freeze

    COLOR_MESH = Sketchup::Color.new(200, 200, 0, 150).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(200, 200, 0, 200).freeze
    COLOR_MESH_DEEP = Sketchup::Color.new(50, 50, 0, 150).freeze
    COLOR_ACTION = Kuix::COLOR_MAGENTA
    COLOR_ACTION_FILL = Sketchup::Color.new(255, 0, 255, 51).freeze
    COLOR_ACTION_FILL_HIGHLIGHTED = Sketchup::Color.new(255, 0, 255, 102).freeze

    @@action = nil
    @@action_modifiers = {} # { action => MODIFIER }

    def initialize(material = nil)
      super(true, false)

      @selected_faces = []

      # Create cursors
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

      case modifier
      when ACTION_MODIFIER_SKP
        return @cursor_export_skp
      when ACTION_MODIFIER_STL
        return @cursor_export_stl
      when ACTION_MODIFIER_OBJ
        return @cursor_export_obj
      when ACTION_MODIFIER_DXF
        return @cursor_export_dxf
      when ACTION_MODIFIER_SVG
        return @cursor_export_svg
      end

      super
    end

    def get_action_modifier_btn_child(action, modifier)

      case action
      when ACTION_EXPORT_PART_3D
        case modifier
        when ACTION_MODIFIER_SKP
          lbl = Kuix::Label.new
          lbl.text = 'SKP'
          return lbl
        when ACTION_MODIFIER_STL
          lbl = Kuix::Label.new
          lbl.text = 'STL'
          return lbl
        when ACTION_MODIFIER_OBJ
          lbl = Kuix::Label.new
          lbl.text = 'OBJ'
          return lbl
        when ACTION_MODIFIER_DXF
          lbl = Kuix::Label.new
          lbl.text = 'DXF'
          return lbl
        end
      when ACTION_EXPORT_PART_2D
        case modifier
        when ACTION_MODIFIER_DXF
          lbl = Kuix::Label.new
          lbl.text = 'DXF'
          return lbl
        when ACTION_MODIFIER_SVG
          lbl = Kuix::Label.new
          lbl.text = 'SVG'
          return lbl
        end
      when ACTION_EXPORT_FACE
        case modifier
        when ACTION_MODIFIER_DXF
          lbl = Kuix::Label.new
          lbl.text = 'DXF'
          return lbl
        when ACTION_MODIFIER_SVG
          lbl = Kuix::Label.new
          lbl.text = 'SVG'
          return lbl
        end
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group
      when ACTION_OPTION_FILE_FORMAT
        case option
        when ACTION_OPTION_FILE_FORMAT_SKP
          lbl = Kuix::Label.new
          lbl.text = 'SKP'
          return lbl
        when ACTION_OPTION_FILE_FORMAT_STL
          lbl = Kuix::Label.new
          lbl.text = 'STL'
          return lbl
        when ACTION_OPTION_FILE_FORMAT_OBJ
          lbl = Kuix::Label.new
          lbl.text = 'OBJ'
          return lbl
        when ACTION_OPTION_FILE_FORMAT_SVG
          lbl = Kuix::Label.new
          lbl.text = 'SVG'
          return lbl
        when ACTION_OPTION_FILE_FORMAT_DXF
          lbl = Kuix::Label.new
          lbl.text = 'DXF'
          return lbl
        end
      when ACTION_OPTION_UNIT
        case option
        when ACTION_OPTION_UNIT_IN
          lbl = Kuix::Label.new
          lbl.text = 'in'
          return lbl
        when ACTION_OPTION_UNIT_YD
          lbl = Kuix::Label.new
          lbl.text = 'yd'
          return lbl
        when ACTION_OPTION_UNIT_MM
          lbl = Kuix::Label.new
          lbl.text = 'mm'
          return lbl
        when ACTION_OPTION_UNIT_CM
          lbl = Kuix::Label.new
          lbl.text = 'cm'
          return lbl
        when ACTION_OPTION_UNIT_M
          lbl = Kuix::Label.new
          lbl.text = 'm'
          return lbl
        end
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_ANCHOR
          motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.273,0L0.273,0.727L1,0.727 M0.091,0.545L0.455,0.545L0.455,0.909L0.091,0.909L0.091,0.545 M0.091,0.182L0.273,0L0.455,0.182 M0.818,0.545L1,0.727L0.818,0.909'))
          return motif
        when ACTION_OPTION_OPTIONS_DEPTH
          motif = Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.5,0.083L1,0.333L0.75,0.458L0.5,0.333L0.25,0.458L0,0.333L0.5,0.083Z M0.5,0.833L0.25,0.708L0.5,0.583L0.75,0.708L0.5,0.833Z'))
          return motif
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

    def is_action_export_part_3d?
      fetch_action == ACTION_EXPORT_PART_3D
    end

    def is_action_export_part_2d?
      fetch_action == ACTION_EXPORT_PART_2D
    end

    def is_action_export_face?
      fetch_action == ACTION_EXPORT_FACE
    end

    def is_action_modifier_skp?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_SKP
    end

    def is_action_modifier_stl?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_STL
    end

    def is_action_modifier_obj?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_OBJ
    end

    def is_action_modifier_dxf?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_DXF
    end

    def is_action_modifier_svg?
      fetch_action_modifier(fetch_action) == ACTION_MODIFIER_SVG
    end

    # -- Events --

    def onActivate(view)
      super
    end

    def onDeactivate(view)
      super
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

        notify_infos(part.name, infos)

        active_instance = @active_part_entity_path.last
        transformation = PathUtils::get_transformation(@active_part_entity_path)

        input_inner_transforamtion = PathUtils::get_transformation(@input_face_path - @active_part_entity_path)
        input_normal = @input_face.normal.transform(transformation * input_inner_transforamtion)

        if is_action_export_part_2d?

          @active_face_infos = _get_face_infos_by_normal(active_instance.definition.entities, input_normal, transformation)
          if @active_face_infos.empty?
            @active_face_infos = [ FaceInfo.new(@input_face, input_inner_transforamtion)  ]
          end

          origin, x_axis, y_axis, z_axis, @active_edge, auto = _get_input_axes(input_inner_transforamtion)
          if auto
            input_inner_normal = @input_face.normal.transform(input_inner_transforamtion)
            if input_inner_normal.parallel?(Z_AXIS)
              z_axis = input_inner_normal
              x_axis = z_axis.cross(X_AXIS).y < 0 ? X_AXIS.reverse : X_AXIS
              y_axis = z_axis.cross(x_axis)
              @active_edge = nil
            elsif input_inner_normal.parallel?(X_AXIS)
              z_axis = input_inner_normal
              x_axis = z_axis.cross(Y_AXIS).y < 0 ? Y_AXIS.reverse : Y_AXIS
              y_axis = z_axis.cross(x_axis)
              @active_edge = nil
            elsif input_inner_normal.parallel?(Y_AXIS)
              z_axis = input_inner_normal
              x_axis = z_axis.cross(X_AXIS).y < 0 ? X_AXIS.reverse : X_AXIS
              y_axis = z_axis.cross(x_axis)
              @active_edge = nil
            end
          end

          # Change axis transformation
          t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          t = t * Geom::Transformation.scaling(-1, 1, 1) if TransformationUtils.flipped?(transformation)
          ti = t.inverse

          # Compute new bounds
          bounds = Geom::BoundingBox.new
          @active_face_infos.each do |face_info|
            bounds.add(_compute_children_faces_triangles([ face_info.face ], ti * face_info.transformation))
          end

          # Compute face distance to 0
          origin = Geom::Point3d.new(bounds.min.x, bounds.min.y, bounds.max.z)
          @active_face_infos.each do |face_info|

            point = face_info.face.vertices.first.position
            vector = face_info.face.normal
            plane = [ point.transform(ti * face_info.transformation), vector.transform(ti * face_info.transformation) ]

            face_info.data[:depth] = origin.distance_to_plane(plane)

          end

          # Translate to 0,0 transformation
          to = Geom::Transformation.translation(Geom::Vector3d.new(bounds.min.x, bounds.min.y, bounds.max.z))

          tto = t * to
          export_transformation = tto.inverse

          # Update face infos transformations
          @active_face_infos.each do |face_info|
            face_info.transformation = export_transformation * face_info.transformation
          end

          face_helper = Kuix::Group.new
          face_helper.transformation = transformation * tto
          @space.append(face_helper)

            @active_face_infos.each do |face_info|

              # Highlight face
              mesh = Kuix::Mesh.new
              mesh.add_triangles(_compute_children_faces_triangles([ face_info.face ], face_info.transformation))
              mesh.background_color = COLOR_MESH_DEEP.blend(highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH, bounds.depth > 0 ? face_info.data[:depth] / bounds.depth : 0.0)
              face_helper.append(mesh)

            end

            # Box helper
            box_helper = Kuix::BoxMotif.new
            box_helper.bounds.size.copy!(bounds)
            box_helper.bounds.size.depth = 0
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 2
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            box_helper.on_top = true
            face_helper.append(box_helper)

            # Axes helper
            inch_offset = Sketchup.active_model.active_view.pixels_to_model(10, Geom::Point3d.new.transform(transformation))
            axes_helper = Kuix::AxesHelper.new
            axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(inch_offset, inch_offset, 0))
            axes_helper.box_0.visible = false
            axes_helper.box_z.visible = false
            face_helper.append(axes_helper)

            if @active_edge

              # Highlight input edge
              segments = Kuix::Segments.new
              segments.add_segments(_compute_children_edge_segments(@input_face.edges, tto.inverse * input_inner_transforamtion,[ @active_edge ]))
              segments.color = COLOR_ACTION
              segments.line_width = 4
              segments.on_top = true
              face_helper.append(segments)

            end

        else

          part_helper = Kuix::Group.new
          part_helper.transformation = transformation
          @space.append(part_helper)

            # Highlight active part
            mesh = Kuix::Mesh.new
            mesh.add_triangles(_compute_children_faces_triangles(active_instance.definition.entities))
            mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
            part_helper.append(mesh)

            bounds = Geom::BoundingBox.new
            bounds.add(_compute_children_faces_triangles(active_instance.definition.entities))

            # Box helper
            box_helper = Kuix::BoxMotif.new
            box_helper.bounds.origin.copy!(bounds.min)
            box_helper.bounds.size.copy!(bounds)
            box_helper.color = Kuix::COLOR_BLACK
            box_helper.line_width = 2
            box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            part_helper.append(box_helper)

            # Axes helper
            axes_helper = Kuix::AxesHelper.new
            part_helper.append(axes_helper)

        end

      else

        @active_face_infos = nil

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

          # Box helper
          box_helper = Kuix::BoxMotif.new
          box_helper.bounds.size.copy!(bounds)
          box_helper.color = Kuix::COLOR_BLACK
          box_helper.line_width = 2
          box_helper.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
          face_helper.append(box_helper)

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          inch_offset = Sketchup.active_model.active_view.pixels_to_model(10, Geom::Point3d.new.transform(transformation))
          axes_helper.transformation = Geom::Transformation.translation(Geom::Vector3d.new(inch_offset, inch_offset, 0))
          axes_helper.box_0.visible = false
          axes_helper.box_z.visible = false
          face_helper.append(axes_helper)

          # Highlight input edge
          segments = Kuix::Segments.new
          segments.add_segments(_compute_children_edge_segments(@active_face.edges, export_transformation,[ @active_edge ]))
          segments.color = COLOR_ACTION
          segments.line_width = 4
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

          if is_action_export_part_3d? || is_action_export_part_2d?

            input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
            if input_part_entity_path

              part = _generate_part_from_path(input_part_entity_path)
              if part
                _set_active_part(input_part_entity_path, part)
              else
                _reset_active_part
                notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_part')}", MESSAGE_TYPE_ERROR)
                push_cursor(@cursor_select_error)
              end
              return

            else
              _reset_active_part
              notify_message("⚠ #{Plugin.instance.get_i18n_string('tool.smart_paint.error.not_part')}", MESSAGE_TYPE_ERROR)
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

          if @active_part.nil?
            UI.beep
            return
          end

          instance_info = @active_part.def.instance_infos.values.first
          options = {}
          file_format = nil
          if is_action_modifier_skp?
            file_format = FILE_FORMAT_SKP
          elsif is_action_modifier_stl?
            file_format = FILE_FORMAT_STL
          elsif is_action_modifier_obj?
            file_format = FILE_FORMAT_OBJ
          elsif is_action_modifier_dxf?
            file_format = FILE_FORMAT_DXF
          end

          worker = CommonExportInstanceToFileWorker.new(instance_info, options, file_format, @active_part.name)
          response = worker.run

          # TODO
          puts Plugin.instance.get_i18n_string('tab.cutlist.success.exported_to', { :export_path => response[:export_path] })

        elsif is_action_export_part_2d? || is_action_export_face?

          if @active_face_infos.nil?
            UI.beep
            return
          end

          options = {}
          file_format = nil
          if is_action_modifier_dxf?
            file_format = FILE_FORMAT_DXF
          elsif is_action_modifier_svg?
            file_format = FILE_FORMAT_SVG
          end

          worker = CommonExportFacesToFileWorker.new(@active_face_infos, options, file_format, @active_part.nil? ? 'Face' : @active_part.name)
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

    def _get_face_infos_by_normal(entities, normal, root_transformation, inner_transformation = Geom::Transformation.new)
      face_infos = []
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            face_infos.push(FaceInfo.new(entity, inner_transformation)) if entity.normal.transform(root_transformation * inner_transformation) == normal
          elsif entity.is_a?(Sketchup::Group)
            face_infos += _get_face_infos_by_normal(entity.entities, normal, root_transformation, inner_transformation * entity.transformation)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            face_infos += _get_face_infos_by_normal(entity.definition.entities, normal, root_transformation, inner_transformation * entity.transformation)
          end
        end
      end
      face_infos
    end

  end

end