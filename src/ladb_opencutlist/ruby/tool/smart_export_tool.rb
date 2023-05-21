module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../helper/edge_segments_helper'
  require_relative '../helper/entities_helper'
  require_relative '../worker/common/common_export_face_to_2d_worker'
  require_relative '../worker/cutlist/cutlist_part_export_to_3d_worker'

  class SmartExportTool < SmartTool

    include EdgeSegmentsHelper
    include EntitiesHelper

    ACTION_EXPORT_PART = 0
    ACTION_EXPORT_FACE = 1

    ACTION_MODIFIER_SKP = 0
    ACTION_MODIFIER_STL = 1
    ACTION_MODIFIER_OBJ = 2
    ACTION_MODIFIER_DXF = 3
    ACTION_MODIFIER_SVG = 4

    ACTIONS = [
      { :action => ACTION_EXPORT_PART, :modifiers => [ACTION_MODIFIER_SKP, ACTION_MODIFIER_STL, ACTION_MODIFIER_OBJ, ACTION_MODIFIER_DXF ] },
      { :action => ACTION_EXPORT_FACE, :modifiers => [ACTION_MODIFIER_DXF, ACTION_MODIFIER_SVG ] },
    ].freeze

    COLOR_MESH = Sketchup::Color.new(200, 200, 0, 100).freeze
    COLOR_MESH_HIGHLIGHTED = Sketchup::Color.new(200, 200, 0, 200).freeze
    COLOR_ACTION = COLOR_MAGENTA
    COLOR_ACTION_FILL = Sketchup::Color.new(255, 0, 255, 51).freeze
    COLOR_ACTION_FILL_HIGHLIGHTED = Sketchup::Color.new(255, 0, 255, 102).freeze

    @@action = nil
    @@action_modifiers = {} # { action => MODIFIER }

    def initialize(material = nil)
      super(true, false)

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
      when ACTION_EXPORT_PART
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

    def store_action_material(action, material)
      @@action_materials[action] = material
    end

    def fetch_action_material(action)
      @@action_materials[action]
    end

    def store_action_filters(action, filters)
      @@action_filters[action] = filters
    end

    def fetch_action_filters(action)
      @@action_filters[action]
    end

    def is_action_export_part?
      fetch_action == ACTION_EXPORT_PART
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
        notify_infos(part.name)

        active_instance = @active_part_entity_path.last
        transformation = PathUtils::get_transformation(@active_part_entity_path)

        part_helper = Kuix::Group.new
        part_helper.transformation = transformation
        @space.append(part_helper)

          # Highlight active part
          mesh = Kuix::Mesh.new
          mesh.add_triangles(_compute_children_faces_triangles(active_instance.definition.entities))
          mesh.background_color = highlighted ? COLOR_MESH_HIGHLIGHTED : COLOR_MESH
          part_helper.append(mesh)

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          part_helper.append(axes_helper)

      end

    end

    def _set_active_face(face_path, face, highlighted = false)
      super

      if face

        transformation = PathUtils::get_transformation(face_path)

        origin, x_axis, y_axis, z_axis, input_face, input_edge = _get_input_axes

        t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
        ti = t.inverse

        bounds = Geom::BoundingBox.new
        bounds.add(_compute_children_faces_triangles([ input_face ], ti))

        to = Geom::Transformation.translation(bounds.min)

        face_helper = Kuix::Group.new
        face_helper.transformation = transformation
        @space.append(face_helper)

          # Highlight input edge
          segments = Kuix::Segments.new
          segments.add_segments(_compute_children_edge_segments(input_face.edges, nil,[ input_edge ]))
          segments.color = COLOR_ACTION
          segments.line_width = 5
          face_helper.append(segments)

          # Highlight input face
          mesh = Kuix::Mesh.new
          mesh.add_triangles(_compute_children_faces_triangles([ input_face ], nil))
          mesh.background_color = highlighted ? COLOR_ACTION_FILL_HIGHLIGHTED : COLOR_ACTION_FILL
          face_helper.append(mesh)

          # Box helper
          box_helper = Kuix::BoxMotif.new
          box_helper.bounds.origin.copy!(bounds.min)
          box_helper.bounds.size.copy!(bounds)
          box_helper.color = COLOR_BLUE
          box_helper.line_width = 2
          box_helper.line_stipple = '-'
          box_helper.transformation = t
          face_helper.append(box_helper)

          # Axes helper
          axes_helper = Kuix::AxesHelper.new
          axes_helper.line_z.visible = false
          axes_helper.transformation = t * to
          face_helper.append(axes_helper)

      end

    end

    # -----

    private

    def _handle_mouse_event(event = nil)
      if event == :move

        if @input_face_path

          if is_action_export_part?

            input_part_entity_path = _get_part_entity_path_from_path(@input_face_path)
            if input_part_entity_path

              part = _generate_part_from_path(input_part_entity_path)
              if part
                _set_active_part(input_part_entity_path, part, event == :l_button_down)
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

        if is_action_export_part?
          _refresh_active_part(true)
        elsif is_action_export_face?
          _refresh_active_face(true)
        end

      elsif event == :l_button_up || event == :l_button_dblclick

        if is_action_export_part?

          if @active_part.nil?
            UI.beep
            return
          end

          file_format = nil
          if is_action_modifier_skp?
            file_format = CommonExportDefinitionTo3dWorker::FILE_FORMAT_SKP
          elsif is_action_modifier_stl?
            file_format = CommonExportDefinitionTo3dWorker::FILE_FORMAT_STL
          elsif is_action_modifier_obj?
            file_format = CommonExportDefinitionTo3dWorker::FILE_FORMAT_OBJ
          elsif is_action_modifier_dxf?
            file_format = CommonExportDefinitionTo3dWorker::FILE_FORMAT_DXF
          end

          settings = {
            'part_id' => @active_part.id,
            'file_format' => file_format,
          }

          worker = CutlistPartExportTo3dWorker.new(settings, @active_part.group.cutlist)
          response = worker.run

          ex = Sketchup.extensions['OpenCutList']
          unless ex.nil?
            notification = UI::Notification.new(ex, Plugin.instance.get_i18n_string('tab.cutlist.success.exported_to', { :export_path => response[:export_path] }))
            notification.icon_name = File.join(Plugin.instance.root_dir, 'img', 'icon-72x72.png')
            notification.on_accept(Plugin.instance.get_i18n_string('default.open')) { puts "OPEN" }
            notification.on_dismiss(Plugin.instance.get_i18n_string('default.close')) { puts "CLOSE" }
            notification.show
          end

        elsif is_action_export_face?

          file_format = nil
          if is_action_modifier_dxf?
            file_format = CommonExportFaceTo2dWorker::FILE_FORMAT_DXF
          elsif is_action_modifier_svg?
            file_format = CommonExportFaceTo2dWorker::FILE_FORMAT_SVG
          end

          origin, x_axis, y_axis, z_axis, input_face, input_edge = _get_input_axes

          t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          bounds = Geom::BoundingBox.new.add(_compute_children_faces_triangles([ input_face ], t.inverse))
          t = t * Geom::Transformation.translation(bounds.min)

          worker = CommonExportFaceTo2dWorker.new(input_face, t.inverse, file_format)
          response = worker.run

          ex = Sketchup.extensions['OpenCutList']
          unless ex.nil?
            notification = UI::Notification.new(ex, Plugin.instance.get_i18n_string('tab.cutlist.success.exported_to', { :export_path => response[:export_path] }))
            notification.icon_name = File.join(Plugin.instance.root_dir, 'img', 'icon-72x72.png')
            notification.on_accept(Plugin.instance.get_i18n_string('default.open')) { puts "OPEN" }
            notification.on_dismiss(Plugin.instance.get_i18n_string('default.close')) { puts "CLOSE" }
            notification.show
          end

        end

      end

    end

    def _get_input_axes

      transformation = nil #PathUtils.get_transformation(@input_face_path)

      input_face = @input_face
      input_edge = @input_edge
      if input_edge.nil? || !input_edge.used_by?(input_face)
        input_edge = _find_longest_outer_edge(input_face, transformation)
      end

      z_axis = input_face.normal
      x_axis = input_edge.line[1]
      y_axis = z_axis.cross(x_axis)

      [ ORIGIN, x_axis, y_axis, z_axis, input_face, input_edge ]
    end

  end

end