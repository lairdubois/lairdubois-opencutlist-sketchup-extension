module Ladb::OpenCutList

  require_relative '../lib/kuix/kuix'
  require_relative '../model/door/door_def'
  require_relative '../worker/common/common_drawing_decomposition_worker'

  # The SWING of a door (see DoorDef) drawn in a Smart tool preview : the axis
  # it turns around, the arcs its far corners sweep, and its outline where the
  # swing ends - what SmartJoinTool shows while laying hinges, and
  # SmartHandleTool while opening or closing a door.
  #
  # The including handler provides @tool (see SmartActionHandler).
  module SmartActionHandlerDoorHelper

    COLOR_DOOR_SWING_PREVIEW = Kuix::COLOR_MAGENTA
    DOOR_SWING_ARC_STEP = 5.0 # Degrees between two points of an arc

    protected

    # Draws on the given 3D layer the swing of the door the given drawing def
    # is the outline of (see #_get_door_drawing_def), from the given angle to
    # the other, in degrees, around the given axis - [ point, vector ] in the
    # door definition's space. The given transformation takes that space to
    # the world with the door CLOSED. Without the door, the axis and the arcs
    # only - one arc, halfway along the axis, when single_arc. Without the axis,
    # the arcs alone.
    def _preview_door_swing(transformation, axis_line, from_angle, to_angle, drawing_def, layer, with_door: true, with_axis: true, single_arc: false)
      return if drawing_def.nil?

      t = transformation
      pivot, axis = axis_line

      fn_rotation = lambda { |angle| Geom::Transformation.rotation(pivot, axis, angle.degrees) }

      # The corners of the door, along the axis and around it
      corners = (0..7).map { |i| drawing_def.bounds.corner(i) }
      positions = corners.map { |point| (point - pivot) % axis }

      # Axis

      if with_axis
        k_edge = Kuix::EdgeMotif3d.new
        k_edge.start.copy!(pivot.offset(axis, positions.min).transform(t))
        k_edge.end.copy!(pivot.offset(axis, positions.max).transform(t))
        k_edge.line_stipple = Kuix::LINE_STIPPLE_LONG_DASHES
        k_edge.line_width = 1.5
        k_edge.color = COLOR_DOOR_SWING_PREVIEW
        k_edge.on_top = true
        @tool.append_3d(k_edge, layer)
      end

      # Arcs swept by the farthest corner at each end of the axis - or by the
      # farthest edge halfway along it

      if single_arc
        farthest = corners.max_by { |point| point.distance_to_line([ pivot, axis ]) }
        arc_starts = [ farthest.offset(axis, (positions.min + positions.max) / 2 - (farthest - pivot) % axis) ]
      else
        arc_starts = [ positions.min, positions.max ].map { |position|
          corners.select.with_index { |_, i| (positions[i] - position).abs < 1.0.mm }
                 .max_by { |point| point.distance_to_line([ pivot, axis ]) }
        }.compact
      end

      sweep = to_angle - from_angle
      steps = [ (sweep.abs / DOOR_SWING_ARC_STEP).ceil, 1 ].max
      arc_starts.each do |corner|

        k_polyline = Kuix::Polyline.new
        k_polyline.add_points((0..steps).map { |i| corner.transform(fn_rotation.call(from_angle + sweep * i / steps)).transform(t) })
        k_polyline.line_stipple = Kuix::LINE_STIPPLE_DOTTED
        k_polyline.line_width = 1.5
        k_polyline.color = COLOR_DOOR_SWING_PREVIEW
        k_polyline.on_top = true
        @tool.append_3d(k_polyline, layer)

      end

      # The door where the swing ends

      return unless with_door

      k_segments = Kuix::Segments.new
      k_segments.add_segments(
        drawing_def.edge_manipulators.flat_map(&:segment) +
        drawing_def.curve_manipulators.flat_map(&:segments)
      )
      k_segments.color = COLOR_DOOR_SWING_PREVIEW
      k_segments.line_width = 1
      k_segments.line_stipple = Kuix::LINE_STIPPLE_SHORT_DASHES
      k_segments.transformation = t * fn_rotation.call(to_angle)
      k_segments.on_top = true
      @tool.append_3d(k_segments, layer)

    end

    # The outline of the door - the given definition - without the fittings
    # glued into it, in its own space. Memoized for the last definition asked.
    def _get_door_drawing_def(definition)
      return @door_drawing_def[1] if @door_drawing_def.is_a?(Array) && @door_drawing_def[0] == definition
      drawing_def = CommonDrawingDecompositionWorker.new([ Sketchup::InstancePath.new([ definition ]) ],
                                                         ignore_surfaces: true,
                                                         ignore_faces: true,
                                                         ignore_edges: false,
                                                         ignore_soft_edges: true,
                                                         container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_PART_WITHOUT_MACHININGS
      ).run
      drawing_def = nil unless drawing_def.is_a?(DrawingDef) && drawing_def.bounds.valid? && !drawing_def.bounds.empty?
      @door_drawing_def = [ definition, drawing_def ]
      drawing_def
    end

  end

end
