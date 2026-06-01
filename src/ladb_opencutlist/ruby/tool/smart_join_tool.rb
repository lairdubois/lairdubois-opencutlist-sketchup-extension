module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/path_utils'
  require_relative '../lib/fiddle/clippy/clippy'

  class SmartJoinTool < SmartTool

    ACTION_0 = 0

    ACTION_OPTION_MEASURES = 'measures'

    ACTION_OPTION_MEASURES_START_OFFSET = 'start_offset'
    ACTION_OPTION_MEASURES_END_OFFSET = 'end_offset'
    ACTION_OPTION_MEASURES_MIN_SPACING = 'min_spacing'
    ACTION_OPTION_MEASURES_MAX_SPACING = 'max_spacing'
    ACTION_OPTION_MEASURES_DEPTH = 'depth'

    ACTIONS = [
      {
        :action => ACTION_0,
        :options => {
          ACTION_OPTION_MEASURES => [ ACTION_OPTION_MEASURES_START_OFFSET, ACTION_OPTION_MEASURES_END_OFFSET, ACTION_OPTION_MEASURES_MIN_SPACING, ACTION_OPTION_MEASURES_MAX_SPACING, ACTION_OPTION_MEASURES_DEPTH ],
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
      false
    end

    def get_action_option_toggle?(action, option_group, option)

      case option_group
      when ACTION_OPTION_MEASURES
        case option
        when ACTION_OPTION_MEASURES_START_OFFSET, ACTION_OPTION_MEASURES_END_OFFSET,
             ACTION_OPTION_MEASURES_MIN_SPACING, ACTION_OPTION_MEASURES_MAX_SPACING,
             ACTION_OPTION_MEASURES_DEPTH
          return false
        end
      end

      super
    end

    def get_action_option_btn_child(action, option_group, option)

      case option_group

      when ACTION_OPTION_MEASURES
        case option
        when ACTION_OPTION_MEASURES_START_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        when ACTION_OPTION_MEASURES_END_OFFSET
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        when ACTION_OPTION_MEASURES_MIN_SPACING
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        when ACTION_OPTION_MEASURES_MAX_SPACING
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
        when ACTION_OPTION_MEASURES_DEPTH
          return Kuix::Label.new(fetch_action_option_value(action, option_group, option).to_s)
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

    # -----

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

      joinery_def[:neighbor_join_defs].each do |neighbor_join_def|

        neighbor_join_def.join_defs.each do |join_def|

          k_polyline = Kuix::Polyline.new
          k_polyline.add_points(join_def.touching_poly)
          k_polyline.line_width = 2
          k_polyline.color = Kuix::COLOR_MAGENTA
          k_polyline.closed = true
          k_polyline.on_top = true
          @tool.append_3d(k_polyline, LAYER_3D_ACTION_PREVIEW)

          k_points = _create_floating_points(
            points: join_def.touching_poly_pts_3d,
            style: Kuix::POINT_STYLE_PLUS,
            stroke_color: Kuix::COLOR_MAGENTA
          )
          @tool.append_3d(k_points, LAYER_3D_ACTION_PREVIEW)

        end

        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(neighbor_join_def.neighbor_def.drawing_def.face_manipulators.flat_map(&:triangles))
        k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)
        @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

      end

    end

    def _do_join(view)
      return if (neighborhood_def = _get_neighborhood_def(view)).nil?
      return if (joinery_def = _get_joinery_def(neighborhood_def)).nil?

      instance = _get_active_part_entity
      instance_entities = instance.definition.entities
      ti = (PathUtils.get_transformation(get_active_selection_path, IDENTITY) * instance.transformation).inverse

      model = Sketchup.active_model
      model.start_operation('Join', true)

        begin

          joinery_def[:neighbor_join_defs].each do |neighbor_join_def|

            x_axis = neighbor_join_def.x_axis.transform(ti)
            y_axis = neighbor_join_def.y_axis.transform(ti)
            z_axis = neighbor_join_def.z_axis.transform(ti)

            at = Geom::Transformation.axes(ORIGIN, x_axis, y_axis, z_axis)

            neighbor_join_def.join_defs.each do |join_def|

              join_def.touching_poly_pts_3d.each do |point|

                pt = point.transform(ti)

                hardware_definition = Sketchup.active_model.definitions['cube']
                instance_entities.add_instance(hardware_definition, Geom::Transformation.translation(pt) * at)

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
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_MEASURES, SmartJoinTool::ACTION_OPTION_MEASURES_START_OFFSET)
    end

    def _fetch_option_end_offset
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_MEASURES, SmartJoinTool::ACTION_OPTION_MEASURES_END_OFFSET)
    end

    def _fetch_option_min_spacing
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_MEASURES, SmartJoinTool::ACTION_OPTION_MEASURES_MIN_SPACING)
    end

    def _fetch_option_max_spacing
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_MEASURES, SmartJoinTool::ACTION_OPTION_MEASURES_MAX_SPACING)
    end

    def _fetch_option_depth
      @tool.fetch_action_option_length(@action, SmartJoinTool::ACTION_OPTION_MEASURES, SmartJoinTool::ACTION_OPTION_MEASURES_DEPTH)
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

      neighbor_join_defs = []

      neighborhood_def[:neighbor_defs].each do |neighbor_def|

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

          touching_def.touching_polys.each do |touching_poly|

            touching_poly_2d = touching_poly.map { |point| point.transform(ati) }

            touching_poly_bounds = Geom::BoundingBox.new.add(touching_poly_2d)
            touching_vy = ORIGIN.vector_to([
                                             touching_poly_bounds.min.project_to_line([ ORIGIN, Y_AXIS ]),
                                             touching_poly_bounds.max.project_to_line([ ORIGIN, Y_AXIS ])
                                           ].max { |point| point.distance(ORIGIN) })

            touching_length = touching_poly_bounds.width

            start_offset = _fetch_option_start_offset
            end_offset = _fetch_option_end_offset
            min_spacing = _fetch_option_min_spacing
            max_spacing = _fetch_option_max_spacing
            depth = _fetch_option_depth

            if touching_length > start_offset + min_spacing + end_offset
              middle_length = touching_poly_bounds.width - start_offset - end_offset
              spacing_count = max_spacing <= 0 ? 1 : (middle_length / max_spacing).ceil
              spacing = middle_length / spacing_count
              if spacing < min_spacing
                spacing_count -= 1
                spacing = middle_length / spacing_count
              end
              coords = (0...spacing_count + 1).map { |i| start_offset + spacing * i }
            elsif touching_length > min_spacing
              coords = [ touching_poly_bounds.width / 2 ]
            else
              coords = []
            end

            next if coords.empty?

            ly = depth == 0 ? touching_poly_bounds.height * 0.5 : depth

            touching_poly_pts_2d = coords.map! { |lx| ORIGIN.offset(X_AXIS, touching_poly_bounds.min.x + lx).offset(touching_vy, ly) }
            touching_poly_pts_3d = touching_poly_pts_2d.map { |point| point.transform(at) }

            join_defs << JoinDef.new(touching_def, touching_poly, touching_poly_pts_3d)

          end

          neighbor_join_defs << NeighborJoinDef.new(neighbor_def, join_defs, x_axis, y_axis, z_axis) if join_defs.any?

        end

      end

      {
        neighbor_join_defs: neighbor_join_defs
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

    NeighborJoinDef = Struct.new(:neighbor_def, :join_defs, :x_axis, :y_axis, :z_axis)
    JoinDef = Struct.new(:touching_def, :touching_poly, :touching_poly_pts_3d)


  end

end