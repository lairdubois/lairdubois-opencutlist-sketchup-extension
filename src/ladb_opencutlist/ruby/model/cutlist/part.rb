module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class AbstractPart

    include HashableHelper

    attr_reader :id, :number, :saved_number, :name, :length, :width, :thickness, :count, :cutting_length, :cutting_width, :cutting_thickness, :material_name, :labels, :edge_count, :edge_pattern, :edge_material_names, :edge_std_dimensions, :edge_decrements, :final_area

    def initialize(part_def, group)
      @_def = part_def
      @_group = group

      @id = part_def.id
      @number = part_def.number
      @saved_number = part_def.saved_number
      @name = part_def.name
      @length = part_def.size.length.to_s
      @width = part_def.size.width.to_s
      @thickness = part_def.size.thickness.to_s
      @count = part_def.count
      @cutting_length = [part_def.cutting_size.length - part_def.edge_length_decrement, 0].max.to_l.to_s
      @cutting_width = [part_def.cutting_size.width - part_def.edge_width_decrement].max.to_l.to_s
      @cutting_thickness = part_def.cutting_size.thickness.to_s
      @material_name = part_def.material_name
      @labels = part_def.labels
      @edge_count = part_def.edge_count
      @edge_pattern = part_def.edge_pattern
      @edge_material_names = part_def.edge_material_names
      @edge_std_dimensions = part_def.edge_std_dimensions
      @edge_decrements = { :length => part_def.edge_length_decrement > 0 ? part_def.edge_length_decrement.to_s : nil, :width => part_def.edge_width_decrement > 0 ? part_def.edge_width_decrement.to_s : nil }
      @final_area = part_def.final_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(part_def.final_area)

    end

    # -----

    def def
      @_def
    end

    def group
      @_group
    end

  end

  class FolderPart < AbstractPart

    attr_reader :children

    def initialize(part_def, group)
      super(part_def, group)

      @children_warning_count = part_def.children_warning_count
      @children_length_increased_count = part_def.children_length_increased_count
      @children_width_increased_count = part_def.children_width_increased_count
      @children_thickness_increased_count = part_def.children_thickness_increased_count
      @children = []

      # ---

      # Children

      def add_child(child_part)

        # Folder part takes first child number
        if @children.empty?
          @name = child_part.name + ', ...'
          @number = child_part.number + '+'
          @saved_number = child_part.saved_number + '+' if child_part.saved_number
        end

        @children.push(child_part)
      end

    end

  end

  class Part < AbstractPart

    attr_reader :definition_id, :is_dynamic_attributes_name, :resized, :flipped, :cumulative_cutting_length, :cumulative_cutting_width, :material_origins, :cumulable, :length_increase, :width_increase, :thickness_increase, :orientation_locked_on_axis, :entity_ids, :entity_serialized_paths, :entity_names, :contains_blank_entity_names, :length_increased, :width_increased, :thickness_increased, :auto_oriented, :not_aligned_on_axes, :layers, :multiple_layers, :edge_entity_ids, :normals_to_values, :normals_to_dimensions, :dimensions_to_normals, :l_ratio, :w_ratio

    def initialize(part_def, group, part_number)
      super(part_def, group)

      @definition_id = part_def.definition_id
      @number = part_def.number ? part_def.number : part_number
      @is_dynamic_attributes_name = part_def.is_dynamic_attributes_name
      @resized = !part_def.scale.identity?
      @flipped = part_def.flipped
      @cumulative_cutting_length = part_def.cumulative_cutting_length.to_s
      @cumulative_cutting_width = part_def.cumulative_cutting_width.to_s
      @material_origins = part_def.material_origins
      @cumulable = part_def.cumulable
      @length_increase = part_def.length_increase
      @width_increase = part_def.width_increase
      @thickness_increase = part_def.thickness_increase
      @orientation_locked_on_axis = part_def.orientation_locked_on_axis
      @entity_ids = part_def.entity_ids
      @entity_serialized_paths = part_def.entity_serialized_paths
      @entity_names = part_def.entity_names.sort
      @contains_blank_entity_names = part_def.contains_blank_entity_names
      @length_increased = part_def.length_increased
      @width_increased = part_def.width_increased
      @thickness_increased = part_def.thickness_increased
      @auto_oriented = part_def.auto_oriented
      @not_aligned_on_axes = part_def.not_aligned_on_axes
      @layers = part_def.layers.map(&:name)
      @multiple_layers = part_def.multiple_layers
      @edge_entity_ids = part_def.edge_entity_ids
      @normals_to_values = part_def.size.normals_to_values
      @normals_to_dimensions = part_def.size.normals_to_dimensions
      @dimensions_to_normals = part_def.size.dimensions_to_normals
      @l_ratio = part_def.size.length / [part_def.size.length, part_def.size.width].max
      @w_ratio = part_def.size.width / [part_def.size.length, part_def.size.width].max
    end

    # -----

    def contains_path(path)
      return true if @_def.get_instance_info(PathUtils::serialize_path(path))
      false
    end

  end

  class ChildPart < Part

    def initialize(part_def, group, part_number, folder_part)
      super(part_def, group, part_number)

      @_folder_part = folder_part

    end

    # -----

    # FolderPart

    def folder_part
      @_folder_part
    end

  end

end