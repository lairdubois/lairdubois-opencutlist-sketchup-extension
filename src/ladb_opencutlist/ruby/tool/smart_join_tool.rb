module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/path_utils'
  require_relative '../lib/fiddle/clippy/clippy'
  require_relative '../helper/user_text_helper'

  class SmartJoinTool < SmartTool

    ACTION_ADD_CONNECTORS = 0
    ACTION_REMOVE_CONNECTORS = 1

    ACTION_OPTION_HEIGHT = 'height'
    ACTION_OPTION_OFFSETS = 'offsets'
    ACTION_OPTION_SPACINGS = 'spacings'
    ACTION_OPTION_OPTIONS = 'options'
    ACTION_OPTION_GEOMETRY = 'geometry'

    ACTION_OPTION_OFFSETS_START_OFFSET = 'start_offset'
    ACTION_OPTION_OFFSETS_END_OFFSET = 'end_offset'

    ACTION_OPTION_SPACINGS_MIN_SPACING = 'min_spacing'
    ACTION_OPTION_SPACINGS_MAX_SPACING = 'max_spacing'

    ACTION_OPTION_HEIGHT_CENTERED = 'height_centered'
    ACTION_OPTION_HEIGHT_DISTANCE = 'height_distance'

    ACTION_OPTION_OPTIONS_MAKE_UNIQUE = 'make_unique'

    ACTION_OPTION_GEOMETRY_HARDWARE_A = 'hardware_a'
    ACTION_OPTION_GEOMETRY_HARDWARE_B = 'hardware_b'
    ACTION_OPTION_GEOMETRY_MACHINING_A = 'machining_a'
    ACTION_OPTION_GEOMETRY_MACHINING_B = 'machining_b'
    ACTION_OPTION_GEOMETRY_HARDWARE_MATERIAL_NAME = 'hardware_material_name'
    ACTION_OPTION_GEOMETRY_MACHINING_MATERIAL_NAME = 'machining_material_name'

    ACTIONS = [
      {
        :action => ACTION_ADD_CONNECTORS,
        :options => {
          ACTION_OPTION_HEIGHT => [ ACTION_OPTION_HEIGHT_CENTERED, ACTION_OPTION_HEIGHT_DISTANCE ],
          ACTION_OPTION_OFFSETS => [ ACTION_OPTION_OFFSETS_START_OFFSET, ACTION_OPTION_OFFSETS_END_OFFSET ],
          ACTION_OPTION_SPACINGS => [ ACTION_OPTION_SPACINGS_MIN_SPACING, ACTION_OPTION_SPACINGS_MAX_SPACING ],
          ACTION_OPTION_OPTIONS => [ ACTION_OPTION_OPTIONS_MAKE_UNIQUE ],
        }
      },
      {
        :action => ACTION_REMOVE_CONNECTORS
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
      when ACTION_ADD_CONNECTORS
        return SmartCursorManager.cursor_select_join
      end

      super
    end

    def get_action_options_modal?(action)

      case action
      when ACTION_ADD_CONNECTORS
        return true
      end

      super
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_HEIGHT
        case option
        when ACTION_OPTION_HEIGHT_CENTERED
          return true
        when ACTION_OPTION_HEIGHT_DISTANCE
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
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return true
        end
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_HEIGHT
        case option
        when ACTION_OPTION_HEIGHT_CENTERED
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0,0L1,0 M0,1L1,1 M0.5,0L0.5,0.25 M0.5,0.75L0.5,1 M0.5,0.375L0.5,0.625 M0.625,0.5L0.375,0.5'))
        when ACTION_OPTION_HEIGHT_DISTANCE
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
      when ACTION_OPTION_OPTIONS
        case option
        when ACTION_OPTION_OPTIONS_MAKE_UNIQUE
          return Kuix::Motif2d.new(Kuix::Motif2d.patterns_from_svg_path('M0.167,0.167L0.167,0.833 M0.417,0.167L0.417,0.833 M0,0.333L0.583,0.333 M0,0.667L0.583,0.667 M0.75,0.333L1,0.167L1,0.833'))
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

    def onKeyDown(key, repeat, flags, view)
      return true if super
      if is_key_alt_or_command?(key)
        push_action(ACTION_REMOVE_CONNECTORS) unless fetch_action == ACTION_REMOVE_CONNECTORS
        return true
      end
      false
    end

    def onKeyUpExtended(key, repeat, flags, view, after_down, is_quick)
      return true if super
      if is_key_alt_or_command?(key)
        pop_action
        return true
      end
      false
    end

    def onActionChanged(action)

      clear_all_2d
      clear_all_3d

      case action
      when ACTION_ADD_CONNECTORS
        set_action_handler(SmartJoinAddConnectorsActionHandler.new(self))
      when ACTION_REMOVE_CONNECTORS
        set_action_handler(SmartJointRemoveConnectorsActionHandler.new(self))
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

  class SmartJoinConnectorsActionHandler < SmartSelectActionHandler

    LAYER_3D_JOIN_PREVIEW = 3
    LAYER_3D_SNAP_POINT_PREVIEW = 4

    COLOR_REF_FACE = Sketchup::Color.new(255, 0, 255, 0.1).blend(COLOR_PART, 0.2).freeze
    COLOR_REF_EDGE = ColorUtils.color_darken(COLOR_REF_FACE, 0.3).freeze
    COLOR_NEIGHBOR = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)

    Clippy = Fiddle::Clippy

    def initialize(action, tool, previous_action_handler = nil)
      super
    end

    # -----

    # -- STATE --

    def get_state_status(state)
      PLUGIN.get_i18n_string("tool.smart_#{@tool.get_stripped_name}.action_#{@action}_state_#{state}_status") + '.'
    end

    def get_state_picker(state)
      SmartPicker.new(tool: @tool, observer: self, pick_point: true, drawable: false)
    end

    # -----

    def onToolGlobalPresetChanged(tool, dictionary, section)
      @geometries_def = nil
      _refresh
    end

    def onPickerChanged(picker, view)
      super
      if _snap_join(view)
        _preview_join(view)
      end
      _preview_snap_point
    end

    def onActivePartChanged(part_entity_path, part, highlighted = nil)
      super
      @neighborhood_def = nil
    end

    # -----

    protected

    def _reset
      super
      @snap_point = nil
      @snap_face_manipulator = nil
      @snap_edge_manipulator = nil
      @snap_vertex_manipulator = nil
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

    def _preview_all_instances?
      true
    end

    # -----

    def _snap_join(view)

      face_manipulator = @picker.picked_plane_manipulator
      if face_manipulator.is_a?(FaceManipulator) &&
         (neighborhood_def = _get_neighborhood_def).is_a?(SmartJoinConnectorsActionHandler::NeighborhoodDef)

        neighbor_defs = neighborhood_def.neighbor_defs

        pt = @picker.picked_point

        edge_manipulator = face_manipulator.loop_manipulators
                                           .flat_map { |lm| lm.edge_manipulators }
                                           .select { |em| neighbor_defs.any? { |nd| nd.touching_defs.any? { |td| td.face_manipulator.face != face_manipulator.face && td.face_manipulator.face.edges.include?(em.edge) } } }
                                           .min { |em1, em2| em1.distance_to(pt) <=> em2.distance_to(pt) }

        if edge_manipulator.is_a?(EdgeManipulator)

          vertex_manipulator = edge_manipulator.nearest_vertex_manipulator_to(pt)
          snap_point = pt

        else

          vertex_manipulator = nil
          snap_point = nil

        end

      else

        edge_manipulator = nil
        vertex_manipulator = nil
        snap_point = nil

      end

      # Check if the base context has changed since last snap iteration
      context_changed = @snap_face_manipulator != face_manipulator || @snap_edge_manipulator != edge_manipulator || @snap_vertex_manipulator != vertex_manipulator

      @snap_face_manipulator = face_manipulator
      @snap_edge_manipulator = edge_manipulator
      @snap_vertex_manipulator = vertex_manipulator
      @snap_point = snap_point

      context_changed
    end

    def _preview_join(view)

      @tool.clear_3d(LAYER_3D_JOIN_PREVIEW)
      @tool.hide_message

      return true if (neighborhood_def = _get_neighborhood_def).nil?

      _preview_join_context(neighborhood_def)

    end

    def _preview_join_context(neighborhood_def)

      if @snap_face_manipulator.is_a?(FaceManipulator)

        # Offset transformation to force mesh to be on top of part preview
        ov = Geom::Vector3d.new(@snap_face_manipulator.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # Highlight picked face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(@snap_face_manipulator.triangles)
        k_mesh.background_color = COLOR_REF_FACE
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

      end

      if @snap_edge_manipulator.is_a?(EdgeManipulator)

        # Highlight picked segment
        k_segments = Kuix::Segments.new
        k_segments.add_segments(@snap_edge_manipulator.segment)
        k_segments.color = COLOR_REF_EDGE
        k_segments.line_width = 3
        k_segments.on_top = true
        @tool.append_3d(k_segments, LAYER_3D_JOIN_PREVIEW)

      end

    end

    def _preview_snap_point
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

    def _get_neighborhood_def(aperture = 1.mm)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      h_neighbor_defs = {}

      kbd = Kuix::Bounds3d.new
                          .copy!(drawing_def.bounds)
                          .inflate_all!(-aperture / 2.0) # Deflate of 1/2x aperture
      kbi = Kuix::Bounds3d.new
                          .copy!(drawing_def.bounds)
                          .inflate_all!(aperture)        # Inflate of 1x aperture

      # Hide instance
      _hide_instance

      begin

        view = @picker.view
        ph = view.pick_helper

        fn_try_to_add_neighbor = lambda do |path|

          picked_part_entity_path = _get_part_entity_path_from_path(path)
          return nil if picked_part_entity_path.nil?                      # Exclude non-part entities
          return nil if h_neighbor_defs.has_key?(picked_part_entity_path) # Exclude already picked part
          if picked_part_entity_path != get_active_selection_path &&
             (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

            # Exclude invalid drawing defs
            return unless picked_drawing_def.bounds.valid?

            # Transform the drawing def to the 'World' space
            picked_drawing_def.transform!(picked_drawing_def.transformation.inverse)

            # Store the new neighbor def
            h_neighbor_defs[picked_part_entity_path] = NeighborhoodNeighborDef.new(picked_part_entity_path, picked_drawing_def, [])

          end

        end

        # 1. Pick from the bounding box

        num_picked = ph.boundingbox_pick(kbi.to_b, Sketchup::PickHelper::PICK_CROSSING, drawing_def.transformation)
        num_picked.times do |index|

          path = ph.path_at(index)

          fn_try_to_add_neighbor.call(path)

        end

        # 2. Pick by 8 ray corners

        8.times do |corner|

          p0 = kbd.corner(corner).to_p.transform(drawing_def.transformation)
          p1 = kbi.corner(corner).to_p.transform(drawing_def.transformation)

          v = p0.vector_to(p1)
          dmax = v.length
          ray = [ p0.offset(v.reverse), v ]

          hit_point, path = view.model.raytest(ray)
          if hit_point

            next if p0.distance(hit_point) > dmax

            fn_try_to_add_neighbor.call(path)

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

          # Iterate on neighbor part faces
          neighbor_def.drawing_def.face_manipulators.each do |nfm|

            next unless fm.normal.parallel?(nfm.normal)
            next if fm.normal.samedirection?(nfm.normal)
            next unless fm.position.distance_to_plane([ nfm.position, nfm.normal ]) < 0.001

            # Touching !

            # Compute the transformation matrix to transform world space to touching 2D space
            origin = fm.position
            z_axis = fm.normal
            x_axis = fm.outer_loop_manipulator.edge_manipulators.first.direction.normalize  # Use first outer loop edge direction as arbitrary x axis
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

            neighbor_def.touching_defs << NeighborhoodTouchingDef.new(fm, nfm, touching_polys) if touching_polys.any?

          end

        end

      end

      # 4. Remove not touching neighbors

      neighbor_defs.delete_if { |neighbor_def| neighbor_def.touching_defs.empty? }

      # 5. Keep useful data

      path = get_active_part_entity_path

      @neighborhood_def = NeighborhoodDef.new(
        path,
        drawing_def,
        neighbor_defs
      )
    end

    # Data Structs -----

    NeighborhoodDef = Struct.new(:path, :drawing_def, :neighbor_defs) do
      def instance_a
        path.last
      end
      def t_a
        @t_a ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_a
        @ti_a ||= t_a.inverse
      end
    end
    NeighborhoodNeighborDef = Struct.new(:path, :drawing_def, :touching_defs) do
      def instance_b
        path.last
      end
      def t_b
        @t_b ||= PathUtils.get_transformation(path, IDENTITY)
      end
      def ti_b
        @ti_b ||= t_b.inverse
      end
    end
    NeighborhoodTouchingDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :touching_polys)

  end

  class SmartJoinAddConnectorsActionHandler < SmartJoinConnectorsActionHandler

    include UserTextHelper

    COLOR_DEFAULT_HARDWARE_MATERIAL = Sketchup::Color.new('#999999').freeze
    COLOR_DEFAULT_MACHINING_MATERIAL = Sketchup::Color.new('#0068ff').freeze

    TRANSFORMATION_ROTATION_Z_180 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees).freeze

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_ADD_CONNECTORS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join_plus
    end

    def get_state_status(state)
      super +
        ' | ' + PLUGIN.get_i18n_string("default.alt_key_#{PLUGIN.platform_name}") + ' = ' + PLUGIN.get_i18n_string("tool.smart_join.action_option_options_make_unique_status") + '.'
    end

    def get_state_vcb_label(state)
      PLUGIN.get_i18n_string('tool.default.vcb_height')
    end

    # -----

    def onToolKeyUpExtended(tool, key, repeat, flags, view, after_down, is_quick)
      return true if super

      if tool.is_key_alt_or_command?(key) && is_quick && @state == STATE_SELECT
        @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE, !_fetch_option_make_unique?, true)
        _refresh
        return true
      end

      false
    end

    def onToolUserText(tool, text, view)
      return true if super

      return true if _read_height(tool, text, view)

      false
    end

    def onSelected
      _add_connectors
      _restart
    end

    # -----

    def enableVCB?
      true
    end

    # -----

    protected

    # -----

    def _preview_all_instances?
      !_fetch_option_make_unique?
    end

    # -----

    def _preview_join_context(neighborhood_def)
      super

      unless (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

        neighbor_join_defs = joinery_def.neighbor_join_defs

        t_a = neighborhood_def.t_a
        ti_a = neighborhood_def.ti_a

        geometries_def = _get_geometries_def
        hardware_a = geometries_def.hardware_a
        hardware_b = geometries_def.hardware_b
        machining_a = geometries_def.machining_a
        machining_b = geometries_def.machining_b

        no_valid_join = true
        neighbor_join_defs.each do |neighbor_join_def|

          t_b = neighbor_join_def.neighbor_def.t_b
          ti_b = neighbor_join_def.neighbor_def.ti_b

          neighbor_join_def.join_defs.each do |join_def|

            at_a = join_def.at_a
            at_b = join_def.at_b

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES if join_def.anchor_points_3d.empty?
            k_polyline.color = Kuix::COLOR_MAGENTA
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

            k_points = _create_floating_points(
              points: join_def.anchor_points_3d,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_MAGENTA
            )
            @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

            unless join_def.anchor_points_3d.empty?

              k_edge = Kuix::EdgeMotif3d.new
              k_edge.start.copy!(join_def.start_point_3d)
              k_edge.end.copy!(join_def.end_point_3d)
              k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
              k_edge.line_width = 1
              k_edge.color = Kuix::COLOR_MAGENTA
              k_edge.on_top = true
              @tool.append_3d(k_edge, LAYER_3D_JOIN_PREVIEW)

            end

            rot = join_def.reversed_y ? TRANSFORMATION_ROTATION_Z_180 : IDENTITY

            join_def.anchor_points_3d.each do |point|

              pt_a = point.transform(ti_a)
              pt_b = point.transform(ti_b)

              # -- Machinings --

              _preview_join_drawing_def(
                machining_a.drawing_def,
                t_a * Geom::Transformation.translation(pt_a) * at_a * rot,
                Kuix::COLOR_CYAN,
                0.5
              ) if machining_a.drawing_def

              _preview_join_drawing_def(
                machining_b.drawing_def,
                t_b * Geom::Transformation.translation(pt_b) * at_b * rot,
                Kuix::COLOR_CYAN,
                0.5
              ) if machining_b.drawing_def

              # -- Hardware --

              _preview_join_drawing_def(
                hardware_a.drawing_def,
                t_a * Geom::Transformation.translation(pt_a) * at_a * rot,
                Kuix::COLOR_DARK_GREY,
                1
              ) if hardware_a.drawing_def

              _preview_join_drawing_def(
                hardware_b.drawing_def,
                t_b * Geom::Transformation.translation(pt_b) * at_b * rot,
                Kuix::COLOR_DARK_GREY,
                1
              ) if hardware_b.drawing_def

            end

            no_valid_join = false if join_def.anchor_points_3d.any?

          end

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = COLOR_NEIGHBOR
          @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

        end

        @tool.show_message(PLUGIN.get_i18n_string('tool.smart_join.error.no_valid_join'), SmartTool::MESSAGE_TYPE_ERROR) if no_valid_join

      end

      if @snap_vertex_manipulator.is_a?(VertexManipulator)

        k_points = _create_floating_points(
          points: @snap_vertex_manipulator.point,
          style: Kuix::POINT_STYLE_CIRCLE,
          fill_color: Kuix::COLOR_MAGENTA,
          stroke_color: Kuix::COLOR_WHITE,
        )
        @tool.append_3d(k_points, LAYER_3D_JOIN_PREVIEW)

      end

    end

    def _preview_snap_point

      @tool.clear_3d(LAYER_3D_SNAP_POINT_PREVIEW)

      return unless @snap_point.is_a?(Geom::Point3d)

      if @snap_point.is_a?(Geom::Point3d)

        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(@snap_point)
        k_edge.end.copy!(@snap_vertex_manipulator.point)
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1
        k_edge.color = Kuix::COLOR_DARK_GREY
        k_edge.on_top = true
        @tool.append_3d(k_edge, LAYER_3D_SNAP_POINT_PREVIEW)

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
      @tool.append_3d(k_segments, LAYER_3D_JOIN_PREVIEW)

    end

    # -----

    def _read_height(tool, text, view)

      height = _read_user_text_length(tool, text)
      return true if height.nil?

      if height < 0
        tool.notify_errors([[ 'tool.default.error.invalid_height', { :value => height } ]])
        return true
      end

      @tool.store_action_option_value(@action, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT_DISTANCE, height.to_s, true)
      Sketchup.set_status_text('', SB_VCB_VALUE)
      _refresh

      false
    end

    # -----

    def _add_connectors
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_add_joinery_def(neighborhood_def)).nil?

      ti_a = neighborhood_def.ti_a
      neighbor_join_defs = joinery_def.neighbor_join_defs

      instance_a = neighborhood_def.instance_a
      definition_a = instance_a.definition
      entities_a = definition_a.entities

      geometries_def = _get_geometries_def
      hardware_a = geometries_def.hardware_a
      hardware_b = geometries_def.hardware_b
      machining_a = geometries_def.machining_a
      machining_b = geometries_def.machining_b
      hardware_material = geometries_def.hardware_material
      machining_material = geometries_def.machining_material

      model = Sketchup.active_model
      model.start_operation('OCL Add Join', true)

        begin

          if (make_unique = _fetch_option_make_unique?)

            # Make unique Part A (if necessary)

            u_instance_a = instance_a.make_unique
            u_definition_a = u_instance_a.definition
            if u_definition_a != definition_a

              u_entities_a = u_definition_a.entities

              neighbor_join_defs.each do |neighbor_join_def|
                neighbor_join_def.join_defs.each do |join_def|
                  face = join_def.touching_def.face_manipulator.face
                  if face.parent == definition_a
                    face_index = entities_a.to_a.index(face)
                    u_face = u_entities_a[face_index]
                    if u_face
                      join_def.touching_def.face_manipulator = FaceManipulator.new(u_face, join_def.touching_def.face_manipulator.transformation)
                      break
                    end
                  end
                end
              end

            end

          end

          neighbor_join_defs.each do |neighbor_join_def|

            instance_b = neighbor_join_def.neighbor_def.instance_b
            definition_b = instance_b.definition
            entities_b = definition_b.entities

            if make_unique

              # Make unique Part B (if necessary)

              u_instance_b = instance_b.make_unique
              u_definition_b = u_instance_b.definition
              if u_definition_b != definition_b

                u_entities_b = u_definition_b.entities

                neighbor_join_def.join_defs.each do |join_def|
                  neighbor_face = join_def.touching_def.neighbor_face_manipulator.face
                  if neighbor_face.parent == definition_b
                    neighbor_face_index = entities_b.to_a.index(neighbor_face)
                    u_neighbor_face = u_entities_b[neighbor_face_index]
                    if u_neighbor_face
                      join_def.touching_def.neighbor_face_manipulator = FaceManipulator.new(u_neighbor_face, join_def.touching_def.neighbor_face_manipulator.transformation)
                    end
                  end
                end

              end

            end

            ti_b = neighbor_join_def.neighbor_def.ti_b

            neighbor_join_def.join_defs.each do |join_def|

              at_a = join_def.at_a
              at_b = join_def.at_b

              fm_a = join_def.touching_def.face_manipulator
              fm_b = join_def.touching_def.neighbor_face_manipulator

              face_a = fm_a.face
              face_b = fm_b.face

              entities_a = face_a.parent.entities
              entities_b = face_b.parent.entities

              dti_a = (ti_a * fm_a.transformation).inverse
              dti_b = (ti_b * fm_b.transformation).inverse

              rot = join_def.reversed_y ? Geom::Transformation.rotation(ORIGIN, Z_AXIS, 180.degrees) : IDENTITY

              join_def.anchor_points_3d.each do |point|

                pt_a = point.transform(ti_a)
                pt_b = point.transform(ti_b)

                # -- A --
                if hardware_a.definition.is_a?(Sketchup::ComponentDefinition)
                  hardware_a_instance = entities_a.add_instance(hardware_a.definition, dti_a * Geom::Transformation.translation(pt_a) * at_a * rot)
                  hardware_a_instance.material = hardware_material
                  hardware_a.definition.behavior.is2d = true unless hardware_a.definition.behavior.is2d?
                  hardware_a_instance.glued_to = face_a
                end
                if machining_a.definition.is_a?(Sketchup::ComponentDefinition)
                  machining_a_instance = entities_a.add_instance(machining_a.definition, dti_a * Geom::Transformation.translation(pt_a) * at_a * rot)
                  machining_a_instance.material = machining_material
                  machining_a.definition.behavior.is2d = true unless machining_a.definition.behavior.is2d?
                  machining_a_instance.glued_to = face_a
                end

                # -- B --
                if hardware_b.definition.is_a?(Sketchup::ComponentDefinition)
                  hardware_b_instance = entities_b.add_instance(hardware_b.definition, dti_b * Geom::Transformation.translation(pt_b) * at_b * rot)
                  hardware_b_instance.material = hardware_material
                  hardware_b.definition.behavior.is2d = true unless hardware_b.definition.behavior.is2d?
                  hardware_b_instance.glued_to = face_b
                end
                if machining_b.definition.is_a?(Sketchup::ComponentDefinition)
                  machining_b_instance = entities_b.add_instance(machining_b.definition, dti_b * Geom::Transformation.translation(pt_b) * at_b * rot)
                  machining_b_instance.material = machining_material
                  machining_b.definition.behavior.is2d = true unless machining_b.definition.behavior.is2d?
                  machining_b_instance.glued_to = face_b
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

    def _fetch_option_height_distance
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT_DISTANCE)
    end

    def _fetch_option_height_centered?
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_HEIGHT, SmartJoinTool::ACTION_OPTION_HEIGHT_CENTERED)
    end

    def _fetch_option_make_unique?
      @tool.fetch_action_option_boolean(@action, SmartJoinTool::ACTION_OPTION_OPTIONS, SmartJoinTool::ACTION_OPTION_OPTIONS_MAKE_UNIQUE)
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

    def _get_add_joinery_def(neighborhood_def)
      return nil if @snap_face_manipulator.nil? || @snap_edge_manipulator.nil? || @snap_vertex_manipulator.nil?

      ti_a = neighborhood_def.ti_a

      start_offset = _fetch_option_start_offset
      end_offset = _fetch_option_end_offset
      min_spacing = _fetch_option_min_spacing
      max_spacing = _fetch_option_max_spacing
      height_distance = _fetch_option_height_distance
      height_centered = _fetch_option_height_centered?

      geometry_def = _get_geometries_def
      geometry_bounds = geometry_def.bounds

      neighbor_join_defs = []

      neighborhood_def.neighbor_defs.each do |neighbor_def|

        ti_b = neighbor_def.ti_b

        join_defs = []

        neighbor_def.touching_defs
                    .select { |touching_def|
                      touching_def.face_manipulator.face != @snap_face_manipulator.face &&
                      touching_def.face_manipulator.face.edges.any? { |edge| edge == @snap_edge_manipulator.edge }
                    }
                    .each do |touching_def|

          origin = @snap_vertex_manipulator.point
          x_axis = @snap_edge_manipulator.direction
          x_axis = x_axis.reverse if origin == @snap_edge_manipulator.end_point
          z_axis = touching_def.face_manipulator.normal
          y_axis = z_axis * x_axis
          at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          ati = at.inverse

          touching_def.touching_polys.each do |touching_poly|

            touching_poly_2d = touching_poly.map { |point| point.transform(ati) }
            touching_poly_bounds = Geom::BoundingBox.new.add(touching_poly_2d)
            touching_vy = ORIGIN.vector_to([
                                             touching_poly_bounds.min.project_to_line([ ORIGIN, Y_AXIS ]),
                                             touching_poly_bounds.max.project_to_line([ ORIGIN, Y_AXIS ])
                                           ].max { |p1, p2| ORIGIN.distance(p1) <=> ORIGIN.distance(p2) })

            touching_length = touching_poly_bounds.width

            if touching_length < geometry_bounds.width
              # Touching face is not large enough to contain at least one join
              coords = []
            else
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
            end

            ly = if height_centered
                   touching_vy.length - touching_poly_bounds.height * 0.5
                 else
                   height_distance
                 end

            anchor_points_2d = coords.map! { |lx| ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + lx).offset(touching_vy, ly) }
                                     .delete_if { |point| !Geom.point_in_polygon_2D(point, touching_poly_2d, true) }

            anchor_points_3d = anchor_points_2d.map { |point| point.transform(at) }
            start_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + (coords.size > 1 ? start_offset : 0)).offset!(touching_vy, ly).transform!(at)
            end_point_3d = ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + touching_poly_bounds.width - (coords.size > 1 ? end_offset : 0)).offset!(touching_vy, ly).transform!(at)

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

            join_defs << AddJoineryJoinDef.new(touching_poly,
                                               touching_def,
                                               anchor_points_3d,
                                               start_point_3d,
                                               end_point_3d,
                                               touching_vy.samedirection?(Y_AXIS),
                                               at_a,
                                               at_b
            )

          end

        end

        neighbor_join_defs << AddJoineryNeighborJoinDef.new(neighbor_def, join_defs) if join_defs.any?

      end

      AddJoineryDef.new(
        neighbor_join_defs
      )
    end

    def _get_geometries_def
      return @geometries_def if @geometries_def.is_a?(GeometriesDef) && @geometries_def.valid?

      model = Sketchup.active_model

      fn_get_definition = lambda do |ref|
        return nil if !ref.is_a?(String) || ref.strip.empty?
        if (extname = File.extname(ref)).downcase == '.skp'
          name = File.basename(ref, extname)
          definition = model.definitions[name]  # Try to get definition from DefinitionList first
          begin
            definition = model.definitions.load(ref.gsub('\\', '/')) if definition.nil?
          rescue Exception => e
            @tool.notify_errors([ [ 'tool.smart_join.error.failed_to_load_skp_file', { file: ref } ] ])
          end
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

      hardware_material = fn_get_material.call(_fetch_option_hardware_material_name, COLOR_DEFAULT_HARDWARE_MATERIAL, MaterialAttributes::TYPE_HARDWARE)
      machining_material = fn_get_material.call(_fetch_option_machining_material_name, COLOR_DEFAULT_MACHINING_MATERIAL, MaterialAttributes::TYPE_MACHINING)

      bounds = Geom::BoundingBox.new
      bounds.add(hardware_a_drawing_def.bounds) unless hardware_a_drawing_def.nil?
      bounds.add(hardware_b_drawing_def.bounds) unless hardware_b_drawing_def.nil?
      bounds.add(machining_a_drawing_def.bounds) unless machining_a_drawing_def.nil?
      bounds.add(machining_b_drawing_def.bounds) unless machining_b_drawing_def.nil?

      @geometries_def = GeometriesDef.new(
        GeometriesEntityDef.new(hardware_a_definition, hardware_a_drawing_def),
        GeometriesEntityDef.new(hardware_b_definition, hardware_b_drawing_def),
        GeometriesEntityDef.new(machining_a_definition, machining_a_drawing_def),
        GeometriesEntityDef.new(machining_b_definition, machining_b_drawing_def),
        hardware_material,
        machining_material,
        bounds,
      )
    end

    # Data Structs -----

    AddJoineryDef = Struct.new(:neighbor_join_defs)
    AddJoineryNeighborJoinDef = Struct.new(:neighbor_def, :join_defs)
    AddJoineryJoinDef = Struct.new(:touching_poly, :touching_def, :anchor_points_3d, :start_point_3d, :end_point_3d, :reversed_y, :at_a, :at_b)

    GeometriesDef = Struct.new(:hardware_a, :hardware_b, :machining_a, :machining_b, :hardware_material, :machining_material, :bounds) do
      def valid?
        hardware_a.valid? &&
        hardware_b.valid? &&
        machining_a.valid? &&
        machining_b.valid? &&
        (hardware_material.nil? || hardware_material.valid?) &&
        (machining_material.nil? || machining_material.valid?)
      end
    end
    GeometriesEntityDef = Struct.new(:definition, :drawing_def) do
      def valid?
        definition.nil? || definition.valid?
      end
    end

  end

  class SmartJointRemoveConnectorsActionHandler < SmartJoinConnectorsActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_REMOVE_CONNECTORS, tool, previous_action_handler)
    end

    # -----

    # -- STATE --

    def get_state_cursor(state)
      SmartCursorManager.cursor_select_join_minus
    end

    def get_state_status(state)
      super
    end

    # -----

    def onSelected
      _remove_connectors
      _restart
    end

    # -----

    protected

    # -----

    def _preview_join_context(neighborhood_def)
      super

      unless (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

        neighbor_join_defs = joinery_def.neighbor_join_defs
        neighbor_join_defs.each do |neighbor_join_def|

          neighbor_join_def.join_defs.each do |join_def|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(join_def.touching_poly)
            k_polyline.line_width = 2
            k_polyline.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
            k_polyline.color = Kuix::COLOR_DARK_GREY
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_JOIN_PREVIEW)

            join_def.glued_instances_a.each do |glued_instance_a|

              k_box = Kuix::BoxFillMotif3d.new
              k_box.bounds.copy!(glued_instance_a.definition.bounds)
              k_box.line_width = 2
              k_box.color = ColorUtils.color_translucent(Kuix::COLOR_RED, 0.3)
              k_box.on_top = true
              k_box.transformation = join_def.touching_def.face_manipulator.transformation * glued_instance_a.transformation
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

              k_box = Kuix::BoxMotif3d.new
              k_box.bounds.copy!(glued_instance_a.definition.bounds)
              k_box.line_width = 2
              k_box.color = Kuix::COLOR_RED
              k_box.on_top = true
              k_box.transformation = join_def.touching_def.face_manipulator.transformation * glued_instance_a.transformation
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

            end

            join_def.glued_instances_b.each do |glued_instance_b|

              k_box = Kuix::BoxFillMotif3d.new
              k_box.bounds.copy!(glued_instance_b.definition.bounds)
              k_box.line_width = 2
              k_box.color = ColorUtils.color_translucent(Kuix::COLOR_RED, 0.3)
              k_box.on_top = true
              k_box.transformation = join_def.touching_def.neighbor_face_manipulator.transformation * glued_instance_b.transformation
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

              k_box = Kuix::BoxMotif3d.new
              k_box.bounds.copy!(glued_instance_b.definition.bounds)
              k_box.line_width = 2
              k_box.color = Kuix::COLOR_RED
              k_box.on_top = true
              k_box.transformation = join_def.touching_def.neighbor_face_manipulator.transformation * glued_instance_b.transformation
              @tool.append_3d(k_box, LAYER_3D_JOIN_PREVIEW)

            end

          end

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
          k_mesh.background_color = COLOR_NEIGHBOR
          @tool.append_3d(k_mesh, LAYER_3D_JOIN_PREVIEW)

        end

      end

    end

    # -----

    def _remove_connectors
      return if (neighborhood_def = _get_neighborhood_def).nil?
      return if (joinery_def = _get_remove_joinery_def(neighborhood_def)).nil?

      model = Sketchup.active_model
      model.start_operation('OCL Remove Join', true)

        begin

          joinery_def.neighbor_join_defs.each do |neighbor_join_def|

            neighbor_join_def.join_defs.each do |join_def|

              join_def.glued_instances_a.each do |glued_instance_a|
                next if glued_instance_a.deleted?
                glued_instance_a.erase!
              end
              join_def.glued_instances_b.each do |glued_instance_b|
                next if glued_instance_b.deleted?
                glued_instance_b.erase!
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

    def _get_remove_joinery_def(neighborhood_def)
      return nil if @snap_face_manipulator.nil? || @snap_edge_manipulator.nil? || @snap_vertex_manipulator.nil?

      neighbor_join_defs = []

      fn_get_glued_instances = lambda do |fm, touching_poly|
        glued_instances = fm.face.get_glued_instances
        if glued_instances.any?

          fm_ti = fm.transformation.inverse
          poly_2d = touching_poly.map { |point| point.transform(fm_ti) }

          # Select only glued instances that intersect with the touching poly
          return glued_instances.select { |glued_instance| Geom.point_in_polygon_2D(ORIGIN.transform(glued_instance.transformation), poly_2d, true) }

        end
        glued_instances
      end

      neighborhood_def.neighbor_defs.each do |neighbor_def|

        join_defs = []

        neighbor_def.touching_defs
                    .select { |touching_def|
                      touching_def.face_manipulator.face != @snap_face_manipulator.face &&
                      touching_def.face_manipulator.face.edges.any? { |edge| edge == @snap_edge_manipulator.edge }
                    }
                    .each do |touching_def|

          touching_def.touching_polys.each do |touching_poly|

            fm_a = touching_def.face_manipulator
            fm_b = touching_def.neighbor_face_manipulator

            glued_instances_a = fn_get_glued_instances.call(fm_a, touching_poly)
            glued_instances_b = fn_get_glued_instances.call(fm_b, touching_poly)

            join_defs << RemoveJoineryJoinDef.new(touching_poly, touching_def, glued_instances_a, glued_instances_b)

          end

        end

        neighbor_join_defs << RemoveJoineryNeighborJoinDef.new(neighbor_def, join_defs) if join_defs.any?

      end

      RemoveJoineryDef.new(
        neighbor_join_defs
      )
    end

    # Data Structs -----

    RemoveJoineryDef = Struct.new(:neighbor_join_defs)
    RemoveJoineryNeighborJoinDef = Struct.new(:neighbor_def, :join_defs)
    RemoveJoineryJoinDef = Struct.new(:touching_poly, :touching_def, :glued_instances_a, :glued_instances_b)

  end

end