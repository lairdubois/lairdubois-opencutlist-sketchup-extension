module Ladb::OpenCutList

  require_relative 'smart_tool'
  require_relative 'smart_handle_tool'
  require_relative '../utils/color_utils'
  require_relative '../utils/path_utils'

  class SmartJoinTool < SmartTool

    ACTION_0 = 0

    ACTIONS = [
      {
        :action => ACTION_0,
        :options => {}
      }
    ].freeze

    # -----

    attr_reader :cursor_select, :cursor_select_part, :cursor_select_part_plus, :cursor_select_plus_minus, :cursor_select_rect

    def initialize(

      current_action: nil

    )

      super(
        current_action: current_action
      )

      # Create cursors
      @cursor_select = create_cursor('select', 0, 0)
      @cursor_select_part = create_cursor('select-part', 0, 0)
      @cursor_select_part_plus = create_cursor('select-part-plus', 0, 0)
      @cursor_select_plus_minus = create_cursor('select-plus-minus', 0, 0)
      @cursor_select_rect = create_cursor('select-rect', 0, 0)

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
        return @cursor_select
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

      refresh

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

  class SmartJoinActionHandler < SmartSelectActionHandler

    STATE_JOIN_START = 1
    STATE_JOIN = 2

    def initialize(action, tool, previous_action_handler = nil)
      super

    end

    # -----

    def onToolCancel(tool, reason, view)
      super

      case @state

      when STATE_JOIN
        set_state(STATE_JOIN_START)

      end

      _reset
      _refresh

      true
    end

    def onToolMouseMove(tool, flags, x, y, view)
      return true if super

      case @state

      when STATE_JOIN_START
        @tool.clear_3d(100)
        _preview_join_start(view)

      when STATE_JOIN
        _preview_join(view)

      end

      view.invalidate

      false
    end

    def onSelected
      super

      set_state(STATE_JOIN_START)
      _refresh

    end

    def onStateChanged(old_state, new_state)
      super

      puts "STATE CHANGED #{old_state} -> #{new_state}"

    end

    # -----

    def _preview_join_start(view)
    end

    def _preview_join(view)
    end

  end

  class SmartJoin0ActionHandler < SmartJoinActionHandler

    def initialize(tool, previous_action_handler = nil)
      super(SmartJoinTool::ACTION_0, tool, previous_action_handler)
    end

    # -----

    def start
      super

      puts "SmartJoin0ActionHandler START"

    end

    # -----

    def onStateChanged(old_state, new_state)
      super

      case new_state

      when STATE_JOIN_START
        @neighborhood_def = nil

      end

    end

    # -----

    protected

    def _preview_join_start(view)
      return if (neiborhood_def = _get_neighborhood_def(view)).nil?

      drawing_def, neighbor_defs = neiborhood_def.values_at(:drawing_def, :neighbor_defs)

      neighbor_defs.each do |neighbor_def|

        neighbor_def.touching_defs.each do |touching_def|

          k_polyline = Kuix::Polyline.new
          k_polyline.add_points(touching_def.face_manipulator.outer_loop_manipulator.points)
          k_polyline.line_width = 2
          k_polyline.color = Kuix::COLOR_MAGENTA
          k_polyline.transformation = drawing_def.transformation
          k_polyline.closed = true
          k_polyline.on_top = true
          @tool.append_3d(k_polyline, 100)

          # k_polyline = Kuix::Polyline.new
          # k_polyline.add_points(touching_def.neighbor_face_manipulator.outer_loop_manipulator.points)
          # k_polyline.line_width = 2
          # k_polyline.color = Kuix::COLOR_MAGENTA
          # k_polyline.transformation = neighbor_def.drawing_def.transformation
          # k_polyline.closed = true
          # k_polyline.on_top = true
          # @tool.append_3d(k_polyline, 100)

        end

        k_mesh = Kuix::Mesh.new
        k_mesh.add_triangles(neighbor_def.drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
        k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)
        k_mesh.transformation = neighbor_def.drawing_def.transformation
        @tool.append_3d(k_mesh, 100)

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
      }
    end

    # -----

    def _get_neighborhood_def(view, aperture = 1.mm)
      return @neighborhood_def unless @neighborhood_def.nil?

      return nil unless (drawing_def = _get_drawing_def).is_a?(DrawingDef)

      neighbor_defs = []

      kb = Kuix::Bounds3d.new
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

      # 1. Pick from bounding box

      num_picked = ph.boundingbox_pick(kb.to_b, Sketchup::PickHelper::PICK_CROSSING, drawing_def.transformation)
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
        #   @tool.append_3d(k_edge, 100)
        #
        # elsif path.last.is_a?(Sketchup::Face)
        #
        #   face_manipulator = FaceManipulator.new(path.last, ph.transformation_at(index))
        #
        #   k_mesh = Kuix::Mesh.new
        #   k_mesh.add_triangles(face_manipulator.triangles)
        #   k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_MAGENTA, 0.3)
        #   @tool.append_3d(k_mesh, 100)
        #
        # end

        picked_part_entity_path = _get_part_entity_path_from_path(path)
        if picked_part_entity_path != get_active_selection_path &&
           (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

          next unless picked_drawing_def.bounds.valid?

          neighbor_defs << NeighborDef.new(picked_part_entity_path, picked_drawing_def)

          # k_mesh = Kuix::Mesh.new
          # k_mesh.add_triangles(picked_drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
          # k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_GREEN, 0.3)
          # k_mesh.transformation = picked_drawing_def.transformation
          # @tool.append_3d(k_mesh, 100)

        end

      end

      # 2. Pick by 8 ray corners

      8.times do |corner|

        p0 = drawing_def.bounds.corner(corner).transform(drawing_def.transformation)
        p1 = kb.corner(corner).to_p.transform(drawing_def.transformation)

        v = p0.vector_to(p1)
        ray = [ p0.offset(v.reverse), v ]

        hit, path = view.model.raytest(ray)
        if hit

          next if p0.distance(hit) > p0.distance(p1)

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
          #   @tool.append_3d(k_edge, 100)
          #
          # elsif path.last.is_a?(Sketchup::Face)
          #
          #   face_manipulator = FaceManipulator.new(path.last, t)
          #
          #   k_mesh = Kuix::Mesh.new
          #   k_mesh.add_triangles(face_manipulator.triangles)
          #   k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_MAGENTA, 0.3)
          #   @tool.append_3d(k_mesh, 100)
          #
          # end

          picked_part_entity_path = _get_part_entity_path_from_path(path)
          if picked_part_entity_path != get_active_selection_path &&
             neighbor_defs.find { |neighbor_def| neighbor_def.path == picked_part_entity_path }.nil? &&
             (picked_drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new(picked_part_entity_path) ], **_get_drawing_def_parameters).run).is_a?(DrawingDef)

            next unless picked_drawing_def.bounds.valid?

            neighbor_defs << NeighborDef.new(picked_part_entity_path, picked_drawing_def)

            # k_mesh = Kuix::Mesh.new
            # k_mesh.add_triangles(picked_drawing_def.face_manipulators.flat_map { |face_manipulator| face_manipulator.triangles })
            # k_mesh.background_color = ColorUtils.color_translucent(Kuix::COLOR_YELLOW, 0.3)
            # k_mesh.transformation = picked_drawing_def.transformation
            # @tool.append_3d(k_mesh, 100)

          end

        end

      end

      # Restore instance visibility
      _unhide_instance

      # 3. Search touching faces

      neighbor_defs.each do |neighbor_def|

        # Iterate on neighbor faces
        neighbor_def.drawing_def.face_manipulators.each do |neighbor_face_manipulator|

          # Iterate on part faces
          drawing_def.face_manipulators.each do |face_manipulator|

            # Compare planes
            if face_manipulator.normal.transform(drawing_def.transformation).parallel?(neighbor_face_manipulator.normal.transform(neighbor_def.drawing_def.transformation)) &&
               !face_manipulator.normal.transform(drawing_def.transformation).samedirection?(neighbor_face_manipulator.normal.transform(neighbor_def.drawing_def.transformation)) &&
               face_manipulator.position.transform(drawing_def.transformation).distance_to_plane(
                 [
                   neighbor_face_manipulator.position.transform(neighbor_def.drawing_def.transformation),
                   neighbor_face_manipulator.normal.transform(neighbor_def.drawing_def.transformation)
                 ]) < 0.001

              # Touching !
              neighbor_def.touching_defs << NeighborTouchingDef.new(face_manipulator, neighbor_face_manipulator)

            end

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

    NeighborDef = Struct.new(:path, :drawing_def, :touching_defs) do
      def initialize(path, drawing_def, touching_defs = [])
        super(path, drawing_def, touching_defs)
      end
    end
    NeighborTouchingDef = Struct.new(:face_manipulator, :neighbor_face_manipulator)

  end

end