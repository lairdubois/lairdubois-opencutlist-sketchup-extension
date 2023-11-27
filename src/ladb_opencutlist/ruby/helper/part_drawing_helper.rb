module Ladb::OpenCutList

  require_relative '../model/cutlist/part'
  require_relative '../worker/common/common_drawing_decomposition_worker'
  require_relative '../worker/common/common_drawing_projection_worker'

  module PartDrawingHelper

    PART_DRAWING_TYPE_NONE = 0
    PART_DRAWING_TYPE_2D_TOP = 1
    PART_DRAWING_TYPE_2D_BOTTOM = 2
    PART_DRAWING_TYPE_3D = 3

    def _compute_part_drawing_def(part_drawing_type, part)
      return nil unless part.is_a?(Part)

      drawing_def = part.def.drawing_defs[part_drawing_type]
      return drawing_def unless drawing_def.nil?

      instance_info = part.def.get_one_instance_info
      return nil if instance_info.nil?

      local_x_axis = part.def.size.oriented_axis(X_AXIS)
      local_y_axis = part.def.size.oriented_axis(Y_AXIS)
      local_z_axis = part.def.size.oriented_axis(Z_AXIS)

      if part_drawing_type == PART_DRAWING_TYPE_2D_BOTTOM
        local_x_axis = local_x_axis.reverse
        local_z_axis = local_z_axis.reverse
      end

      drawing_def = CommonDrawingDecompositionWorker.new(instance_info.path, {
        'input_local_x_axis' => local_x_axis,
        'input_local_y_axis' => local_y_axis,
        'input_local_z_axis' => local_z_axis,
        'use_bounds_min_as_origin' => true,
        'ignore_edges' => true
      }).run
      if drawing_def.is_a?(DrawingDef)
        part.def.drawing_defs[part_drawing_type] = drawing_def
        return drawing_def
      end

      nil
    end

    def _compute_part_projection_def(part_drawing_type, part, settings = {}, projection_defs_cache = {})
      return nil unless part.is_a?(Part)

      projection_def = projection_defs_cache[part.id]
      return projection_def unless projection_def.nil?

      drawing_def = _compute_part_drawing_def(part_drawing_type, part)
      return nil unless drawing_def.is_a?(DrawingDef)

      projection_def = CommonDrawingProjectionWorker.new(drawing_def, settings).run
      if projection_def.is_a?(DrawingProjectionDef)
        projection_defs_cache[part.id] = projection_def
        return projection_def
      end

      nil
    end

  end

end
