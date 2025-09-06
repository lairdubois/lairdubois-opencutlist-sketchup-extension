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
        cache_key = "#{part_drawing_type}|#{ignore_edges}|#{origin_position}"
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
        part.def.drawing_defs[cache_key] = drawing_def if use_cache
        return drawing_def
      end

      nil
    end

    def _compute_part_box(part_drawing_type, part, drawing_def)
      part_def = part.def
      group_def = part.group.def
      part_length_increase = part_def.length_increase
      part_width_increase = part_def.width_increase
      material_length_increase = group_def.material_attributes.l_length_increase
      material_width_increase = group_def.material_attributes.l_width_increase
      if (part_length_increase > 0 || part_width_increase > 0 ||
        material_length_increase > 0 || material_width_increase > 0) &&
         (part_drawing_type == PART_DRAWING_TYPE_2D_TOP || part_drawing_type == PART_DRAWING_TYPE_2D_BOTTOM)

         # Create a box (rectangle shape) corresponding to the dim oversize

         face_bounds = drawing_def.faces_bounds
         min = face_bounds.min
         max = face_bounds.max

         min.offset!(Geom::Vector3d.new(-material_length_increase / 2.0, -material_width_increase / 2.0))
         max.offset!(Geom::Vector3d.new(material_length_increase / 2.0 + part_length_increase, material_width_increase / 2.0 + part_width_increase))

         box_bounds = Geom::BoundingBox.new
         box_bounds.add(min, max)

         return [
           box_bounds.corner(0),
           box_bounds.corner(1),
           box_bounds.corner(3),
           box_bounds.corner(2)
         ]
      end
      nil
    end

    def _compute_part_mask(part_drawing_type, part, drawing_def)
      if (part_def = part.def).edge_decremented &&
         (part_drawing_type == PART_DRAWING_TYPE_2D_TOP || part_drawing_type == PART_DRAWING_TYPE_2D_BOTTOM)

        # Create a mask (rectangle shape) corresponding to the edge decrement

        face_bounds = drawing_def.faces_bounds
        min = face_bounds.min
        max = face_bounds.max

        unless (xmin_edge_decrement = part_def.edge_decrements[:xmin]).nil?
          min.offset!(Geom::Vector3d.new(xmin_edge_decrement, 0))
        end
        unless (xmax_edge_decrement = part_def.edge_decrements[:xmax]).nil?
          max.offset!(Geom::Vector3d.new(-xmax_edge_decrement, 0))
        end
        unless (ymin_edge_decrement = part_def.edge_decrements[:ymin]).nil?
          min.offset!(Geom::Vector3d.new(0, ymin_edge_decrement))
        end
        unless (ymax_edge_decrement = part_def.edge_decrements[:ymax]).nil?
          max.offset!(Geom::Vector3d.new(0, -ymax_edge_decrement))
        end

        mask_bounds = Geom::BoundingBox.new
        mask_bounds.add(min, max)

        return [
          mask_bounds.corner(0),
          mask_bounds.corner(1),
          mask_bounds.corner(3),
          mask_bounds.corner(2)
        ]
      end
      nil
    end

    def _compute_part_projection_def(part_drawing_type, part,
                                     ignore_edges: true,
                                     merge_holes: false,
                                     merge_holes_overflow: 0,
                                     compute_shell: false,
                                     origin_position: CommonDrawingProjectionWorker::ORIGIN_POSITION_FACES_BOUNDS_MIN,
                                     use_cache: true
    )
      return nil unless part.is_a?(Part)

      if use_cache
        cache_key = "#{part_drawing_type}|#{part.id}|#{ignore_edges}|#{merge_holes}|#{merge_holes_overflow}|#{compute_shell}|#{origin_position}"
        projection_def = part.def.projection_defs[cache_key]
        return projection_def unless projection_def.nil?
      end

      drawing_def = _compute_part_drawing_def(part_drawing_type, part, ignore_edges: ignore_edges, origin_position: CommonDrawingDecompositionWorker::ORIGIN_POSITION_DEFAULT, use_cache: use_cache)
      return nil unless drawing_def.is_a?(DrawingDef)

      projection_def = CommonDrawingProjectionWorker.new(drawing_def,
                                                         origin_position: origin_position,
                                                         merge_holes: merge_holes,
                                                         merge_holes_overflow: merge_holes_overflow,
                                                         compute_shell: compute_shell,
                                                         mask: _compute_part_mask(part_drawing_type, part, drawing_def)
      ).run
      if projection_def.is_a?(DrawingProjectionDef)
        part.def.projection_defs[cache_key] = projection_def if use_cache
        return projection_def
      end

      nil
    end


    def _get_part_edge_keys_by_drawing_type(part_drawing_type)
      case part_drawing_type
      when PART_DRAWING_TYPE_2D_BOTTOM
        return [ :xmax, :xmin, :ymin, :ymax ]
      end
      [ :xmin, :xmax, :ymin, :ymax ]
    end

  end

end
