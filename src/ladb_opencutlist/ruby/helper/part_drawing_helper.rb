module Ladb::OpenCutList

  require_relative '../model/cutlist/part'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_drawing_projection_worker'

  module PartDrawingHelper

    PART_DRAWING_TYPE_NONE = 0
    PART_DRAWING_TYPE_2D_TOP = 1
    PART_DRAWING_TYPE_2D_BOTTOM = 2
    PART_DRAWING_TYPE_2D_LEFT = 3
    PART_DRAWING_TYPE_2D_RIGHT = 4
    PART_DRAWING_TYPE_2D_FRONT = 5
    PART_DRAWING_TYPE_2D_BACK = 6
    PART_DRAWING_TYPE_3D = 7

    def _compute_part_drawing_def(part_drawing_type, part,
                                  ignore_edges: true,
                                  origin_position: CommonDrawingDecompositionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
                                  use_cache: true
    )
      return nil unless part.is_a?(Part)
      return nil if part_drawing_type == PART_DRAWING_TYPE_NONE

      if use_cache
        drawing_def = part.def.drawing_defs[part_drawing_type]
        return drawing_def unless drawing_def.nil?
      end

      instance_info = part.def.get_one_instance_info
      return nil if instance_info.nil?

      local_x_axis = part.def.size.oriented_axis(X_AXIS)
      local_y_axis = part.def.size.oriented_axis(Y_AXIS)
      local_z_axis = part.def.size.oriented_axis(Z_AXIS)

      case part_drawing_type
      when PART_DRAWING_TYPE_2D_BOTTOM
        local_x_axis = local_x_axis.reverse
        local_z_axis = local_z_axis.reverse
      when PART_DRAWING_TYPE_2D_LEFT
        local_x_axis, local_y_axis, local_z_axis = local_y_axis.reverse, local_z_axis, local_x_axis.reverse
      when PART_DRAWING_TYPE_2D_RIGHT
        local_x_axis, local_y_axis, local_z_axis = local_y_axis, local_z_axis, local_x_axis
      when PART_DRAWING_TYPE_2D_FRONT
        local_y_axis, local_z_axis = local_z_axis, local_y_axis.reverse
      when PART_DRAWING_TYPE_2D_BACK
        local_x_axis, local_y_axis, local_z_axis = local_x_axis.reverse, local_z_axis, local_y_axis
      end

      drawing_def = CommonDrawingDecompositionWorker.new(instance_info.path,
        input_local_x_axis: local_x_axis,
        input_local_y_axis: local_y_axis,
        input_local_z_axis: local_z_axis,
        origin_position: origin_position,
        ignore_edges: ignore_edges,
        edge_validator: ignore_edges ? nil : CommonDrawingDecompositionWorker::EDGE_VALIDATOR_STRAY
      ).run
      if drawing_def.is_a?(DrawingDef)
        part.def.drawing_defs[part_drawing_type] = drawing_def
        return drawing_def
      end

      nil
    end

    def _compute_part_projection_def(part_drawing_type, part,
                                     projection_defs_cache: {},
                                     ignore_edges: true,
                                     merge_holes: false,
                                     merge_holes_overflow: 0,
                                     compute_shell: false,
                                     origin_position: CommonDrawingProjectionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
                                     use_cache: true
    )
      return nil unless part.is_a?(Part)

      if use_cache && projection_defs_cache.is_a?(Hash)
        projection_def = projection_defs_cache[part.id]
        return projection_def unless projection_def.nil?
      end

      drawing_def = _compute_part_drawing_def(part_drawing_type, part, ignore_edges: ignore_edges, origin_position: CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT, use_cache: use_cache)
      return nil unless drawing_def.is_a?(DrawingDef)

      projection_def = CommonDrawingProjectionWorker.new(drawing_def,
                                                         origin_position: origin_position,
                                                         merge_holes: merge_holes,
                                                         merge_holes_overflow: merge_holes_overflow,
                                                         compute_shell: compute_shell
      ).run
      if projection_def.is_a?(DrawingProjectionDef)
        projection_defs_cache[part.id] = projection_def if use_cache && projection_defs_cache.is_a?(Hash)
        return projection_def
      end

      nil
    end

  end

end
