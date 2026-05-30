module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/path_utils'
  require_relative '../lib/fiddle/clippy/clippy'

  class SmartJoinTool < SmartTool

    ACTION_0 = 0

    ACTIONS = [
      {
        :action => ACTION_0,
        :options => {}
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
      super
    end

    def get_action_option_btn_child(action, option_group, option)
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

    def start
      super

      puts "SmartJoin0ActionHandler START"

    end

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
      _preview_join(view)
    end

    def onActivePartChanged(part_entity_path, part, highlighted = nil)
      super
      @neighborhood_def = nil
    end

    # -----

    protected

    def _start_with_model_selection?
      false
    end

    def _clear_selection_on_start?
      true
    end

    # -----

    def _preview_join(view)

      @tool.clear_3d(LAYER_3D_ACTION_PREVIEW)

      return if (neighborhood_def = _get_neighborhood_def(view)).nil?

      face_manipulator = @picker.picked_plane_manipulator
      if face_manipulator.is_a?(FaceManipulator)

        # Offset transformation to force arrow and mesh to be on top of part preview
        ov = Geom::Vector3d.new(face_manipulator.normal)
        ov.length = 0.01
        ot = Geom::Transformation.translation(ov)

        # Highlight picked face
        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(face_manipulator.triangles)
        k_mesh.background_color = Sketchup::Color.new(255, 0, 255, 0.2).blend(COLOR_PART, 0.5).freeze
        k_mesh.transformation = ot
        @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

      else
        return
      end

      neighbor_defs = neighborhood_def[:neighbor_defs]

      pt = @picker.picked_point

      edge_manipulator = face_manipulator.loop_manipulators
                                         .flat_map { |lm| lm.edge_manipulators }
                                         .select { |em| neighbor_defs.any? { |nd| nd.touching_defs.any? { |td| td.face_manipulator.face != face_manipulator.face && td.face_manipulator.face.edges.include?(em.edge) } } }
                                         .min { |em1, em2| em1.distance_to_edge(pt) <=> em2.distance_to_edge(pt) }

      if edge_manipulator.is_a?(EdgeManipulator)

        # Highlight picked segment
        # k_segments = Kuix::Segments.new
        # k_segments.add_segments(edge_manipulator.segment)
        # k_segments.color = Kuix::COLOR_MAGENTA
        # k_segments.line_width = 2
        # k_segments.on_top = true
        # @tool.append_3d(k_segments, LAYER_3D_ACTION_PREVIEW)

        vertex_manipulator = edge_manipulator.vertex_manipulators.min { |vm1, vm2| pt.distance(vm1.point) <=> pt.distance(vm2.point) }

        if vertex_manipulator.is_a?(VertexManipulator)

          k_points = _create_floating_points(
            points: vertex_manipulator.point,
            style: Kuix::POINT_STYLE_SQUARE,
          )
          @tool.append_3d(k_points, LAYER_3D_ACTION_PREVIEW)

        end

      else
        return
      end

      neighbor_defs.each do |neighbor_def|

        neighbor_def.touching_defs
                    .select { |touching_def|
                        touching_def.touching_polys.any? &&
                        touching_def.face_manipulator.face != face_manipulator.face &&
                        touching_def.face_manipulator.face.edges.any? { |edge| edge == edge_manipulator.edge }
                    }
                    .each do |touching_def|

          origin = vertex_manipulator.point
          x_axis = edge_manipulator.direction
          z_axis = touching_def.face_manipulator.normal
          y_axis = z_axis * x_axis
          at = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
          ati = at.inverse

          # k_axes = Kuix::AxesHelper.new
          # k_axes.transformation = at
          # @tool.append_3d(k_axes, LAYER_3D_ACTION_PREVIEW)

          touching_def.touching_polys.each do |touching_poly|

            k_polyline = Kuix::Polyline.new
            k_polyline.add_points(touching_poly)
            k_polyline.line_width = 2
            k_polyline.color = Kuix::COLOR_MAGENTA
            k_polyline.closed = true
            k_polyline.on_top = true
            @tool.append_3d(k_polyline, LAYER_3D_ACTION_PREVIEW)

            touching_poly_2d = touching_poly.map { |point| point.transform(ati) }
            touching_poly_bounds = Geom::BoundingBox.new.add(touching_poly_2d)
            touching_poly_vx = touching_poly_bounds.min.project_to_line([ ORIGIN, X_AXIS ]).vector_to(touching_poly_bounds.max.project_to_line([ ORIGIN, X_AXIS ]))
            touching_poly_vy = touching_poly_bounds.min.project_to_line([ ORIGIN, Y_AXIS ]).vector_to(touching_poly_bounds.max.project_to_line([ ORIGIN, Y_AXIS ]))
            touching_poly_pts_2d = [ 1/3.0, 2/3.0 ].map! { |f| touching_poly_bounds.min.offset(touching_poly_vx, touching_poly_bounds.width * f).offset(touching_poly_vy, touching_poly_bounds.height * 0.5) }

            # k_polyline = Kuix::Polyline.new
            # k_polyline.add_points(touching_poly_2d)
            # k_polyline.line_width = 2
            # k_polyline.color = Kuix::COLOR_BLACK
            # k_polyline.closed = true
            # @tool.append_3d(k_polyline, LAYER_3D_ACTION_PREVIEW)
            #
            # k_points = _create_floating_points(
            #   points: touching_poly_pts_2d,
            #   style: Kuix::POINT_STYLE_PLUS,
            # )
            # @tool.append_3d(k_points, LAYER_3D_ACTION_PREVIEW)

            touching_poly_pts_3d = touching_poly_pts_2d.map { |pt| pt.transform(at) }

            k_points = _create_floating_points(
              points: touching_poly_pts_3d,
              style: Kuix::POINT_STYLE_PLUS,
              stroke_color: Kuix::COLOR_MAGENTA
              )
            @tool.append_3d(k_points, LAYER_3D_ACTION_PREVIEW)

          end

          k_mesh = Kuix::Mesh.new
          k_mesh.add_triangles(neighbor_def.drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
          k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)
          k_mesh.transformation = neighbor_def.drawing_def.transformation
          @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

        end

      end

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
                         .inflate_all!(-aperture / 2.0)
      kbi = Kuix::Bounds3d.new
                         .copy!(drawing_def.bounds)
                         .inflate_all!(aperture)

      # k_box = Kuix::BoxMotif3d.new
      # k_box.bounds.copy!(kb)
      # k_box.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
      # k_box.line_width = 1.5
      # k_box.color = Kuix::COLOR_RED
      # k_box.transformation = drawing_def.transformation
      # @tool.append_3d(k_box, 200)

      # Hide instance
      _hide_instance

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

        hit, path = view.model.raytest(ray)
        if hit

          next if p0.distance(hit) > dmax

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

      # Restore instance visibility
      _unhide_instance

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
      return nil if picked_part_entity_path.nil?
      return nil if h_neighbor_defs.has_key?(picked_part_entity_path)
      # TODO find a cleanest way to exclude part out of active path
      if picked_part_entity_path != get_active_selection_path &&
         (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

        # Transform the drawing def to the 'World' space
        picked_drawing_def.transform!(picked_drawing_def.transformation.inverse)

        # Exclude invalid drawing defs
        return unless picked_drawing_def.bounds.valid?

        # Store the new neighbor def
        h_neighbor_defs[picked_part_entity_path] = NeighborDef.new(picked_part_entity_path, picked_drawing_def)

        # k_mesh = Kuix::Mesh.new
        # k_mesh.add_triangles(picked_drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
        # k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)
        # k_mesh.transformation = picked_drawing_def.transformation
        # @tool.append_3d(k_mesh, LAYER_3D_ACTION_PREVIEW)

      end
    end

    # Data Structs -----

    NeighborDef = Struct.new(:path, :drawing_def, :touching_defs) do
      def initialize(path, drawing_def, touching_defs = [])
        super(path, drawing_def, touching_defs)
      end
    end
    NeighborTouchingDef = Struct.new(:face_manipulator, :neighbor_face_manipulator, :touching_polys)

  end

end