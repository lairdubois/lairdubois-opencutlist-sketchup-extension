module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/path_utils'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../helper/user_text_helper'

  class SmartJoinTool < SmartTool

    ACTION_0 = 0

    ACTION_OPTION_DEPTH = 'depth'
    ACTION_OPTION_OFFSETS = 'offsets'
    ACTION_OPTION_SPACINGS = 'spacings'
    ACTION_OPTION_GEOMETRY = 'geometry'

    ACTION_OPTION_OFFSETS_START_OFFSET = 'start_offset'
    ACTION_OPTION_OFFSETS_END_OFFSET = 'end_offset'

    ACTION_OPTION_SPACINGS_MIN_SPACING = 'min_spacing'
    ACTION_OPTION_SPACINGS_MAX_SPACING = 'max_spacing'

    ACTION_OPTION_DEPTH_CENTRED = 'depth_centred'
    ACTION_OPTION_DEPTH_DISTANCE = 'depth_distance'

    ACTION_OPTION_GEOMETRY_HARDWARE_A = 'hardware_a'
    ACTION_OPTION_GEOMETRY_HARDWARE_B = 'hardware_b'
    ACTION_OPTION_GEOMETRY_MACHINING_A = 'machining_a'
    ACTION_OPTION_GEOMETRY_MACHINING_B = 'machining_b'
    ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME = 'hardware_material_name'
    ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME = 'machining_material_name'

    ACTIONS = [
      {
        :action => ACTION_0,
        :options => {
          ACTION_OPTION_DEPTH => [ ACTION_OPTION_DEPTH_CENTRED, ACTION_OPTION_DEPTH_DISTANCE ],
          ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
          ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
        }
      }
    ].freeze

    # -----

    def initialize(

      current_action: nil

    )

      super(
        current_action: current_action
      )

    end

    def get_stripped_name
      'join'
    end

    # -- Actions --

    def get_action_defs
      ACTIONS
    end

    def get_action_cursor(action)

      case action
      when ACTION_0
        return SmartCursorManager.cursor_select_join
      end

      super
    end

    def get_action_options_modal?(action)
      true
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_DEPTH
        case option
        when ACTION_OPTION_DEPTH_CENTRED
          return true
        when ACTION_OPTION_DEPTH_DISTANCE
          return false
        end
      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET
          return false
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING
          return false
        end
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_DEPTH
        case option
        when ACTION_OPTION_DEPTH_CENTRED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L1,0 M0,1L1,1 M0.5,0L0.5,0.25 M0.5,0.75L0.5,1 M0.5,0.375L0.5,0.625 M0.625,0.5L0.375,0.5'))
        when ACTION_OPTION_DEPTH_DISTANCE
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        end
      end

      super
    end

    def get_action_option_btn_prefix(action, option_group, option)

      case option_group

      when ACTION_OPTION_OFFSETS
        case option
        when ACTION_OPTION_OFFSETS_START_OFFSET
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_offsets_start_offset'))
        when ACTION_OPTION_OFFSETS_END_OFFSET
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_offsets_end_offset'))
        end
      when ACTION_OPTION_SPACINGS
        case option
        when ACTION_OPTION_SPACINGS_MIN_SPACING
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_spacings_min_spacing'))
        when ACTION_OPTION_SPACINGS_MAX_SPACING
          return Kuix::Label.new(PLUGIN.get_i18n_string('tool.smart_join.action_option_spacings_max_spacing'))
        end
      end

      super
    end

    # -- Events --

    def onActivate(view)
      super
    end

    def onActionChanged(action)

      case action
      when ACTION_0
        set_action_handler(SmartJoin0ActionHandler.new(self))
      end

      super
    end

    def onViewChanged(view)
      super
      refresh
    end

    def onTransactionUndo(model)
      super
      refresh
    end

  end

  class SmartJoin0ActionHandler < SmartSelectActionHandler

    include UserTextHelper

    LAYER_3D_ACTION_PREVIEW = 3

    STATE_JOIN_START = 1
    STATE_JOIN = 2

    Clippy = Fiddle::Clippy

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_0, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_point: true)
    end

    def get_state_vcb_label(state)
      PLUGIN.get_i18n_string('tool.default.vcb_depth')
    end

    # -----

    def onToolUserText(tool, text, view)
      return true if super

      return true if _read_depth(tool, text, view)

      false
    end

    def onPickerChanged(picker, view)
      super
      _snap_join(view)
      _preview_join(view)
    end

    def onActivePartChanged(part_entity_path, part, highlighted = nil)
      super
      @neighborhood_def = nil
    end

    def onSelected
      _do_join(Sketchup.active_model.active_view)
      _restart
    end

    def onToolGlobalPresetChanged(tool, dictionary, section)
      @geometry_def = nil
      _refresh
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    protected

    def _reset
      super
      @snap_point = nil
      @face_manipulator = nil
      @edge_manipulator = nil
      @vertex_manipulator = nil
      @neighborhood_def = nil
    end

    # -----

    def _start_with_model_selection?
      false
    end

    def _clear_selection_on_start?
      true
    end

    # -----

    def _snap_join(view)

      return if (neighborhood_def = _get_neighborhood_def(view)).nil?

      @face_manipulator = @picker.picked_plane_manipulator
      unless @face_manipulator.is_a?(FaceManipulator)
        @snap_point = nil
        @face_manipulator = nil
        @edge_manipulator = nil
        @vertex_manipulator = nil
        return
      end

      neighbor_defs = neighborhood_def[:neighbor_defs]

      pt = @picker.picked_point

      @edge_manipulator = @face_manipulator.loop_manipulators
                                           .flat_map { |lm| lm.edge_manipulators }
                                           .select { |em| neighbor_defs.any? { |nd| nd.touching_defs.any? { |td| td.face_manipulator.face != @face_manipulator.face && td.face_manipulator.face.edges.include?(em.edge) } } }
                                           .min { |em1, em2| em1.distance_to_edge(pt) <=> em2.distance_to_edge(pt) }

      if @edge_manipulator.is_a?(EdgeManipulator)

        @vertex_manipulator = @edge_manipulator.nearest_vertex_manipulator_to(pt)

      else
        @snap_point = nil
        @face_manipulator = nil
        @edge_manipulator = nil
        @vertex_manipulator = nil
        return
      end

      @snap_point = pt

    end

    def _preview_join(view)

      @tool.clear_3d(LAYER_3D_ACTION_PREVIEW)

      return if (neighborhood_def = _get_neighborhood_def(view)).nil?

      if @face_manipulator.is_a?(FaceManipulator)

        # Offset transformation to force arrow and mesh to be on top of part preview
        ov = Geom::Vector3d.new(@face_manipulator.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # Highlight picked face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(@face_manipulator.triangles)
        k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 0.2).blend(COLOR_PART, 0.5).freeze
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

      end

      if @edge_manipulator.is_a?(EdgeManipulator)

        # Highlight picked segment
        # k_segments = Kuix::Segments.new
        # k_segments.add_segments(edge_manipulator.segment)
        # k_segments.color = Kuix::COLOR_MAGENTA
        # k_segments.line_width = 2
        # k_segments.on_top = true
        # @tool.append_3d(k_segments, LAYER_3D_ACTION_PREVIEW)

      end

      if @vertex_manipulator.is_a?(VertexManipulator)

        k_points = _create_floating_points(
          points: @vertex_manipulator.point,
          style: Kuix::POINT_STYLE_SQUARE,
        )
        @tool.append_3d(k_points, LAYER_3D_ACTION_PREVIEW)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@snap_point)
        k_edge.end.copy!(@vertex_manipulator.point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_ACTION_PREVIEW)

      end

      return if (joinery_def = _get_joinery_def(neighborhood_def)).nil?

      neighbor_join_defs = joinery_def[:neighbor_join_defs]

      if neighbor_join_defs.empty?

        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.no_valid_join'), SmartTool::MESSAGE_TYPE_ERROR)

      else

        @tool.hide_message

        ti_a = joinery_def[:ti_a]

        geometry_def = _get_geometry_def
        hardware_a_drawing_def = geometry_def[:hardware_a_drawing_def]
        hardware_b_drawing_def = geometry_def[:hardware_b_drawing_def]
        machining_a_drawing_def = geometry_def[:machining_a_drawing_def]
        machining_b_drawing_def = geometry_def[:machining_b_drawing_def]

        neighbor_join_defs.each do |neighbor_join_def|

          ti_b = neighbor_join_def.ti_b
          at_a = neighbor_join_def.at_a
          at_b = neighbor_join_def.at_b

          neighbor_join_def.join_defs.each do |join_def|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.color = Kuix::COLOR_MAGENTA
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_ACTION_PREVIEW)

            k_points = _create_floating_points(
              points: join_def.anchor_points_3d,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_MAGENTA
            )
            @tool.append_3d(k_points, LAYER_3D_ACTION_PREVIEW)

            k_edge = Kuix::EdgeMotif3d.new
            k_edge.start.copy!(join_def.start_point_3d)
            k_edge.end.copy!(join_def.end_point_3d)
            k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
            k_edge.line_width = 1
            k_edge.color = Kuix::COLOR_MAGENTA
            k_edge.on_top = true
            @tool.append_3d(k_edge, LAYER_3D_ACTION_PREVIEW)

            rot = join_def.reversed_y ? Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees) : IDENTITY

            join_def.anchor_points_3d.each do |point|

              pt_a = point.transform(ti_a)
              pt_b = point.transform(ti_b)

              _preview_join_drawing_def(machining_a_drawing_def, ti_a.inverse * Geom::Transformation.translation(pt_a) * at_a * rot, Kuix::COLOR_CYAN, 0.5) if machining_a_drawing_def
              _preview_join_drawing_def(machining_b_drawing_def, ti_b.inverse * Geom::Transformation.translation(pt_b) * at_b, Kuix::COLOR_CYAN, 0.5) if machining_b_drawing_def
              _preview_join_drawing_def(hardware_a_drawing_def, ti_a.inverse * Geom::Transformation.translation(pt_a) * at_a, Kuix::COLOR_DARK_GREY, 1) if hardware_a_drawing_def
              _preview_join_drawing_def(hardware_b_drawing_def, ti_b.inverse * Geom::Transformation.translation(pt_b) * at_b, Kuix::COLOR_DARK_GREY, 1) if hardware_b_drawing_def

            end

          end

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)
          @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

        end

      end

    end

    def _preview_join_drawing_def(drawing_def, transformation, color, line_width)

      k_segments = Kuix::Segments.new
      k_segments.add_segments(
        drawing_def.edge_manipulators.flat_map(&:segment) +
        drawing_def.curve_manipulators.flat_map(&:segments)
      )
      k_segments.color = color
      k_segments.line_width = line_width
      k_segments.transformation = transformation
      k_segments.on_top = true
      @tool.append_3d(k_segments, LAYER_3D_ACTION_PREVIEW)

    end

    # -----

    def _read_depth(tool, text, view)

      depth = _read_user_text_length(tool, text)
      return true if depth.nil?

      if depth < 0
        tool.notify_errors([[ 'tool.default.error.invalid_depth', { :value => depth } ]])
        return true
      end

      @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_DEPTH, SmartJoinTool::ACTION_OPTION_DEPTH_DISTANCE, depth.to_s, true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      false
    end

    # -----

    def _do_join(view)
      return if (neighborhood_def = _get_neighborhood_def(view)).nil?
      return if (joinery_def = _get_joinery_def(neighborhood_def)).nil?

      ti_a, neighbor_join_defs = joinery_def.values_at(:ti_a, :neighbor_join_defs)

      instance_a = _get_active_part_entity
      instance_a_entities = instance_a.definition.entities

      geometry_def = _get_geometry_def
      hardware_a_definition = geometry_def[:hardware_a_definition]
      hardware_b_definition = geometry_def[:hardware_b_definition]
      machining_a_definition = geometry_def[:machining_a_definition]
      machining_b_definition = geometry_def[:machining_b_definition]
      hardware_material = geometry_def[:hardware_material]
      machining_material = geometry_def[:machining_material]

      model = Sketchup.active_model
      model.start_operation('OCL Join', true)

        begin

          neighbor_join_defs.each do |neighbor_join_def|

            instance_b = neighbor_join_def.neighbor_def.path.last
            instance_b_entities = instance_b.definition.entities
            ti_b = neighbor_join_def.ti_b
            at_a = neighbor_join_def.at_a
            at_b = neighbor_join_def.at_b

            neighbor_join_def.join_defs.each do |join_def|

              rot = join_def.reversed_y ? Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees) : IDENTITY

              join_def.anchor_points_3d.each do |point|

                pt_a = point.transform(ti_a)
                pt_b = point.transform(ti_b)

                # -- A --
                if hardware_a_definition.is_a?(Sketchup::ComponentDefinition)
                  hardware_a_instance = instance_a_entities.add_instance(hardware_a_definition, Geom::Transformation.translation(pt_a) * at_a * rot)
                  hardware_a_instance.material = hardware_material
                  hardware_a_instance.glued_to = join_def.touching_def.face_manipulator.face if hardware_a_definition.behavior.is2d?
                end
                if machining_a_definition.is_a?(Sketchup::ComponentDefinition)
                  machining_a_instance = instance_a_entities.add_instance(machining_a_definition, Geom::Transformation.translation(pt_a) * at_a * rot)
                  machining_a_instance.material = machining_material
                  machining_a_instance.glued_to = join_def.touching_def.face_manipulator.face if machining_a_definition.behavior.is2d?
                end

                # -- B --
                if hardware_b_definition.is_a?(Sketchup::ComponentDefinition)
                  hardware_b_instance = instance_b_entities.add_instance(hardware_b_definition, Geom::Transformation.translation(pt_b) * at_b * rot)
                  hardware_b_instance.material = hardware_material
                  hardware_b_instance.glued_to = join_def.touching_def.neighbor_face_manipulator.face if hardware_b_definition.behavior.is2d?
                end
                if machining_b_definition.is_a?(Sketchup::ComponentDefinition)
                  machining_b_instance = instance_b_entities.add_instance(machining_b_definition, Geom::Transformation.translation(pt_b) * at_b * rot)
                  machining_b_instance.material = machining_material
                  machining_b_instance.glued_to = join_def.touching_def.neighbor_face_manipulator.face if machining_b_definition.behavior.is2d?
                end

              end

            end

          end

        rescue Exception => e
          PLUGIN.dump_exception(e)
          model.abort_operation
          return
        end

      model.commit_operation

    end

    # -----

    def _fetch_option_start_offset
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_START_OFFSET)
    end

    def _fetch_option_end_offset
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_OFFSETS_END_OFFSET)
    end

    def _fetch_option_min_spacing
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_SPACINGS_MIN_SPACING)
    end

    def _fetch_option_max_spacing
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_OFFSETS, SmartJoinTool::ACTION_OPTION_SPACINGS_MAX_SPACING)
    end

    def _fetch_option_depth_distance
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_DEPTH, SmartJoinTool::ACTION_OPTION_DEPTH_DISTANCE)
    end

    def _fetch_option_depth_centred
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_DEPTH, SmartJoinTool::ACTION_OPTION_DEPTH_CENTRED)
    end

    def _fetch_option_hardware_a
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_A)
    end

    def _fetch_option_hardware_b
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_B)
    end

    def _fetch_option_machining_a
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_A)
    end

    def _fetch_option_machining_b
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_B)
    end

    def _fetch_option_hardware_material_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME)
    end

    def _fetch_option_machining_material_name
      @tool.fetch_action_option_string(@action, SmartJoinTool::ACTION_OPTION_GEOMETRY, SmartJoinTool::ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME)
    end

    # -----

    def _get_drawing_def_parameters
      {
        ignore_surfaces: true,
        ignore_faces: false,
        ignore_edges: true,
        ignore_soft_edges: true,
        ignore_clines: true,
        container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS
      }
    end

    # -----

    def _get_neighborhood_def(view, aperture = 1.mm)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      h_neighbor_defs = {}

      kbd = Kuix::Bounds3d.new
                         .copy!(drawing_def.bounds)
                         .inflate_all!(-aperture / 2.0) # Deflate of 1/2x aperture
      kbi = Kuix::Bounds3d.new
                         .copy!(drawing_def.bounds)
                         .inflate_all!(aperture)        # Inflate of 1x aperture

      # k_box = Kuix::BoxMotif3d.new
      # k_box.bounds.copy!(kbi)
      # k_box.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      # k_box.line_width = 1.5
      # k_box.color = Kuix::COLOR_RED
      # k_box.transformation = drawing_def.transformation
      # @tool.append_3d(k_box, 200)

      # Hide instance
      _hide_instance

      begin

        ph = view.pick_helper

        # 1. Pick from the bounding box

        num_picked = ph.boundingbox_pick(kbi.to_b, Sketchup::PickHelper::PICK_CROSSING, drawing_def.transformation)
        num_picked.times do |index|

          path = ph.path_at(index)

          # if path.last.is_a?(Sketchup::Edge)
          #
          #   edge_manipulator = EdgeManipulator.new(path.last, ph.transformation_at(index))
          #
          #   k_edge = Kuix::EdgeMotif3d.new
          #   k_edge.start.copy!(edge_manipulator.start_point)
          #   k_edge.end.copy!(edge_manipulator.end_point)
          #   k_edge.line_stipple = Kuix::LINE_STIPPLE_SOLID
          #   k_edge.line_width = 3
          #   k_edge.color = Kuix::COLOR_MAGENTA
          #   k_edge.on_top = true
          #   @tool.append_3d(k_edge, LAYER_3D_ACTION_PREVIEW)
          #
          # elsif path.last.is_a?(Sketchup::Face)
          #
          #   face_manipulator = FaceManipulator.new(path.last, ph.transformation_at(index))
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_MAGENTA, 0.3)
          #   @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)
          #
          # end

          _try_to_add_neighbor(path, h_neighbor_defs)

        end

        # 2. Pick by 8 ray corners

        8.times do |corner|

          # p0 = drawing_def.bounds.corner(corner).transform(drawing_def.transformation)
          p0 = kbd.corner(corner).to_p.transform(drawing_def.transformation)
          p1 = kbi.corner(corner).to_p.transform(drawing_def.transformation)

          v = p0.vector_to(p1)
          dmax = v.length
          ray = [ p0.offset(v.reverse), v ]

          hit_point, path = view.model.raytest(ray)
          if hit_point

            next if p0.distance(hit_point) > dmax

            # t = PathUtils.get_transformation(path)

            # if path.last.is_a?(Sketchup::Edge)
            #
            #   edge_manipulator = EdgeManipulator.new(path.last, t)
            #
            #   k_edge = Kuix::EdgeMotif3d.new
            #   k_edge.start.copy!(edge_manipulator.start_point)
            #   k_edge.end.copy!(edge_manipulator.end_point)
            #   k_edge.line_stipple = Kuix::LINE_STIPPLE_SOLID
            #   k_edge.line_width = 3
            #   k_edge.color = Kuix::COLOR_MAGENTA
            #   k_edge.on_top = true
            #   @tool.append_3d(k_edge, LAYER_3D_ACTION_PREVIEW)
            #
            # elsif path.last.is_a?(Sketchup::Face)
            #
            #   face_manipulator = FaceManipulator.new(path.last, t)
            #
            #   k_mesh = Kuix::Mesh.new
            #   k_mesh.add_triangles(face_manipulator.triangles)
            #   k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_MAGENTA, 0.3)
            #   @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)
            #
            # end

            _try_to_add_neighbor(path, h_neighbor_defs)

          end

        end

      ensure

          # Restore instance visibility
          _unhide_instance

      end

      # Transform the drawing def to the 'World' space
      drawing_def.transform!(drawing_def.transformation.inverse)

      # 3. Search touching faces

      neighbor_defs = h_neighbor_defs.values.each do |neighbor_def|

        # Iterate on part faces
        drawing_def.face_manipulators.each do |fm|

          # Iterate on neighbor faces
          neighbor_def.drawing_def.face_manipulators.each do |nfm|

            next unless fm.normal.parallel?(nfm.normal)
            next if fm.normal.samedirection?(nfm.normal)
            next unless fm.position.distance_to_plane([ nfm.position, nfm.normal ]) < 0.001

            # Touching !

            # Compute the transformation matrix to transform world space to touching 2D space
            origin = fm.position
            z_axis = fm.normal
            x_axis = fm.outer_loop_manipulator.edge_manipulators.first.direction.normalize  # Use first edge direction as arbitrary x axis
            y_axis = z_axis * x_axis
            at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
            ati = at.inverse

            # Compute part and neighbor touching intersections polygons
            f_2d_paths = fm.loop_manipulators
                                      .map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ati) } }
                                      .map! { |points| Clippy.points_to_rpath(points) }
            nf_2d_paths = nfm.loop_manipulators
                                      .map { |loop_manipulator| loop_manipulator.points.map { |point| point.transform(ati) } }
                                      .map! { |points| Clippy.points_to_rpath(points) }

            touching_2d_paths, op = Clippy.execute_intersection(closed_subjects: f_2d_paths, clips: nf_2d_paths)
            touching_polys = touching_2d_paths.map { |path| Clippy.rpath_to_points(path, 0).map { |point| point.transform(at)} }

            neighbor_def.touching_defs << NeighborTouchingDef.new(fm, nfm, touching_polys)

          end

        end

      end

      # 4. Remove not touching neighbors

      neighbor_defs.delete_if { |neighbor_def| neighbor_def.touching_defs.empty? }

      @neighborhood_def = {
        drawing_def: drawing_def,
        neighbor_defs: neighbor_defs
      }
    end

    def _try_to_add_neighbor(path, h_neighbor_defs)
      picked_part_entity_path = _get_part_entity_path_from_path(path)
      return nil if picked_part_entity_path.nil?                      # Exclude non-part entities
      return nil if h_neighbor_defs.has_key?(picked_part_entity_path) # Exclude already picked part
      if picked_part_entity_path != get_active_selection_path &&
         (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

        # Transform the drawing def to the 'World' space
        picked_drawing_def.transform!(picked_drawing_def.transformation.inverse)

        # Exclude invalid drawing defs
        return unless picked_drawing_def.bounds.valid?

        # Store the new neighbor def
        h_neighbor_defs[picked_part_entity_path] = NeighborDef.new(picked_part_entity_path, picked_drawing_def)

      end
    end

    def _get_joinery_def(neighborhood_def)
      return nil if @face_manipulator.nil? || @edge_manipulator.nil? || @vertex_manipulator.nil?

      instance_a = _get_active_part_entity
      ti_a = (PathUtils.get_transformation(get_active_selection_path, IDENTITY) * instance_a.transformation).inverse

      neighbor_join_defs = []

      neighborhood_def[:neighbor_defs].each do |neighbor_def|

        ti_b = PathUtils.get_transformation(neighbor_def.path, IDENTITY).inverse

        join_defs = []

        neighbor_def.touching_defs
                    .select { |touching_def|
                      touching_def.touching_polys.any? &&
                        touching_def.face_manipulator.face != @face_manipulator.face &&
                        touching_def.face_manipulator.face.edges.any? { |edge| edge == @edge_manipulator.edge }
                    }
                    .each do |touching_def|

          origin = @vertex_manipulator.point
          x_axis = @edge_manipulator.direction
          x_axis = x_axis.reverse if origin == @edge_manipulator.end_point
          z_axis = touching_def.face_manipulator.normal
          y_axis = z_axis * x_axis
          at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          ati = at.inverse

          at_a = Geom::Transformation.axes(
            ORIGIN,
            x_axis.transform(ti_a),
            y_axis.transform(ti_a),
            z_axis.transform(ti_a)
          )

          at_b = Geom::Transformation.axes(
            ORIGIN,
            x_axis.transform(ti_b),
            y_axis.transform(ti_b),
            z_axis.transform(ti_b).reverse!
          )

          touching_def.touching_polys.each do |touching_poly|

            touching_poly_2d = touching_poly.map { |point| point.transform(ati) }
            touching_poly_bounds = Geom::BoundingBox.new.add(touching_poly_2d)
            touching_vy = ORIGIN.vector_to([
                                             touching_poly_bounds.min.project_to_line([ ORIGIN, Y_AXIS ]),
                                             touching_poly_bounds.max.project_to_line([ ORIGIN, Y_AXIS ])
                                           ].max { |p1, p2| ORIGIN.distance(p1) <=> ORIGIN.distance(p2) })

            touching_length = touching_poly_bounds.width

            start_offset = _fetch_option_start_offset
            end_offset = _fetch_option_end_offset
            min_spacing = _fetch_option_min_spacing
            max_spacing = _fetch_option_max_spacing
            depth_distance = _fetch_option_depth_distance
            depth_centred = _fetch_option_depth_centred

            if touching_length > start_offset + min_spacing + end_offset
              middle_length = touching_poly_bounds.width - start_offset - end_offset
              spacing_count = max_spacing <= 0 ? 1 : (middle_length / max_spacing).ceil
              spacing_count = 2 if spacing_count < 2 && start_offset == 0 && end_offset == 0
              spacing = middle_length / spacing_count
              if spacing < min_spacing
                spacing_count -= 1
                spacing = middle_length / spacing_count
              end
              coords = []
              coords << start_offset if start_offset > 0
              coords += (1...spacing_count).map { |i| start_offset + spacing * i }
              coords << touching_poly_bounds.width - end_offset if end_offset > 0
            else
              coords = [ touching_poly_bounds.width / 2 ]
            end

            ly = if depth_centred
                   touching_vy.length - touching_poly_bounds.height * 0.5
                 else
                   depth_distance
                 end

            anchor_points_2d = coords.map! { |lx| ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + lx).offset(touching_vy, ly) }
                                     .delete_if { |point| !Geom.point_in_polygon_2D(point, touching_poly_2d, true) }

            next if coords.empty?

            anchor_points_3d = anchor_points_2d.map { |point| point.transform(at) }
            start_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + start_offset).offset(touching_vy, ly).transform(at)
            end_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + touching_poly_bounds.width - end_offset).offset(touching_vy, ly).transform(at)

            join_defs << JoinDef.new(touching_def, touching_poly, anchor_points_3d, start_point_3d, end_point_3d, touching_vy.samedirection?(Y_AXIS))

          end

          neighbor_join_defs << NeighborJoinDef.new(neighbor_def, join_defs, x_axis, y_axis, z_axis, ti_b, at_a, at_b) if join_defs.any?

        end

      end

      {
        ti_a: ti_a,
        neighbor_join_defs: neighbor_join_defs
      }
    end

    def _get_geometry_def
      return @geometry_def unless @geometry_def.nil?

      model = Sketchup.active_model

      fn_get_definition = lambda do |ref|
        return nil if !ref.is_a?(String) || ref.strip.empty?
        if (extname = File.extname(ref)).downcase == '.skp'
          name = File.basename(ref, extname)
          definition = model.definitions[name]  # Try to get definition from DefinitionList first
          definition = model.definitions.load(ref) if definition.nil?
        else
          definition = model.definitions[ref]
        end
        definition
      end

      hardware_a_definition = fn_get_definition.call(_fetch_option_hardware_a)
      hardware_b_definition = fn_get_definition.call(_fetch_option_hardware_b)
      machining_a_definition = fn_get_definition.call(_fetch_option_machining_a)
      machining_b_definition = fn_get_definition.call(_fetch_option_machining_b)

      fn_get_drawing_def = lambda do |definition|
        return nil if definition.nil?
        CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new([ definition ]) ],
          ignore_surfaces: true,
          ignore_faces: true,
          ignore_edges: false,
          ignore_soft_edges: false,
          container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL
        ).run
      end

      hardware_a_drawing_def = fn_get_drawing_def.call(hardware_a_definition)
      hardware_b_drawing_def = fn_get_drawing_def.call(hardware_b_definition)
      machining_a_drawing_def = fn_get_drawing_def.call(machining_a_definition)
      machining_b_drawing_def = fn_get_drawing_def.call(machining_b_definition)

      fn_get_material = lambda do |ref, default_color = nil, default_type = nil|
        return nil if !ref.is_a?(String) || ref.strip.empty?
        if File.extname(ref).downcase == '.skm'
          material = model.materials.load(ref)
        else
          material = model.materials[ref]
          if material.nil?
            material = model.materials.add(ref)
            material.color = default_color unless default_color.nil?
            unless default_type.nil?
              ma = MaterialAttributes.new(material)
              ma.type = default_type
              ma.write_to_attributes
            end
          end
        end
        material
      end

      hardware_material = fn_get_material.call(_fetch_option_hardware_material_name, Kuix::COLOR_BLACK, MaterialAttributes::TYPE_HARDWARE)
      machining_material = fn_get_material.call(_fetch_option_machining_material_name, '#0068ff', MaterialAttributes::TYPE_MACHINING)

      @geometry_def = {
        hardware_a_definition: hardware_a_definition,
        hardware_b_definition: hardware_b_definition,
        machining_a_definition: machining_a_definition,
        machining_b_definition: machining_b_definition,
        hardware_a_drawing_def: hardware_a_drawing_def,
        hardware_b_drawing_def: hardware_b_drawing_def,
        machining_a_drawing_def: machining_a_drawing_def,
        machining_b_drawing_def: machining_b_drawing_def,
        hardware_material: hardware_material,
        machining_material: machining_material
      }
    end

    # Data Structs -----

    NeighborDef = Struct.new(:path, :drawing_def, :touching_defs) do
      def initialize(path, drawing_def, touching_defs = [])
        super(path, drawing_def, touching_defs)
      end
    end
    NeighborTouchingDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :touching_polys) do
      def initialize(face_manipulator, neighbor_face_manipulator, touching_polys = [])
        super(face_manipulator, neighbor_face_manipulator, touching_polys)
      end
    end

    NeighborJoinDef = Struct.new(:neighbor_def, :join_defs, :x_axis, :y_axis, :z_axis, :ti_b, :at_a, :at_b)
    JoinDef = Struct.new(:touching_def, :touching_poly, :anchor_points_3d, :start_point_3d, :end_point_3d, :reversed_y)


  end

end