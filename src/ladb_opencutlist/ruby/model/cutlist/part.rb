module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class AbstractPart < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :id, :virtual, :number, :saved_number,
                :name, :name_source,
                :description, :url,
                :length, :width, :thickness,
                :cutting_length, :cutting_width, :cutting_thickness, :edge_cutting_length, :edge_cutting_width,
                :count,
                :material_name,
                :tags,
                :cumulable, :cumulative_cutting_length, :cumulative_cutting_width,
                :instance_count_by_part, :unused_instance_count,
                :mass, :price, :thickness_layer_count, :ignore_grain_direction, :follow_grain_direction,
                :length_increase, :length_increased, :width_increase, :width_increased, :height_increase, :height_increased,
                :edge_count, :edge_pattern, :edge_material_names, :edge_material_colors, :edge_std_dimensions, :edge_decrements,
                :face_count, :face_pattern, :face_material_names, :face_material_colors, :face_texture_angles, :face_std_dimensions, :face_decrements,
                :entity_names, :final_area, :l_ratio, :w_ratio

    def initialize(_def, _group)
      @_def = _def
      @_group = _group

      @id = _def.id
      @virtual = _def.virtual
      @number = _def.number
      @saved_number = _def.saved_number

      @name = _def.name
      @name_source = _def.name_source

      @description = _def.description
      @url = _def.url

      @length = _def.size.length.to_s
      @width = _def.size.width.to_s
      @thickness = _def.size.thickness.to_s
      @cutting_length = _def.cutting_length.to_s
      @cutting_width = _def.cutting_width.to_s
      @cutting_thickness = _def.cutting_size.thickness.to_s
      @edge_cutting_length = _def.edge_cutting_length.to_s
      @edge_cutting_width = _def.edge_cutting_width.to_s

      @count = _def.count

      @material_name = _def.material_name

      @tags = _def.tags

      @cumulable = _def.cumulable
      @cumulative_cutting_length = _def.cumulative_cutting_length.to_s
      @cumulative_cutting_width = _def.cumulative_cutting_width.to_s

      @instance_count_by_part = _def.instance_count_by_part
      @unused_instance_count = _def.unused_instance_count

      @mass = _def.mass
      @price = _def.price
      @thickness_layer_count = _def.thickness_layer_count
      @ignore_grain_direction = _def.ignore_grain_direction
      @follow_grain_direction = _def.follow_grain_direction

      @length_increase = _def.length_increase.to_s
      @length_increased = _def.length_increased
      @width_increase = _def.width_increase.to_s
      @width_increased = _def.width_increased
      @thickness_increase = _def.thickness_increase.to_s
      @thickness_increased = _def.thickness_increased

      @edge_count = _def.edge_count
      @edge_pattern = _def.edge_pattern
      @edge_material_names = _def.edge_material_names
      @edge_material_colors = _def.edge_material_colors.map { |k, v| [ k, ColorUtils.color_to_hex(ColorUtils.color_visible_over_white(v)) ] }.to_h
      @edge_std_dimensions = _def.edge_std_dimensions
      @edge_decrements = { :length => _def.edge_length_decrement > 0 ? DimensionUtils.str_add_units(_def.edge_length_decrement.to_s) : nil, :width => _def.edge_width_decrement > 0 ? DimensionUtils.str_add_units(_def.edge_width_decrement.to_s) : nil }

      @face_count = _def.face_count
      @face_pattern = _def.face_pattern
      @face_material_names = _def.face_material_names
      @face_material_colors = _def.face_material_colors.map { |k, v| [ k, ColorUtils.color_to_hex(ColorUtils.color_visible_over_white(v)) ] }.to_h
      @face_texture_angles = _def.face_texture_angles.each { |k, v| _def.face_texture_angles[k] = v.radians.round }
      @face_std_dimensions = _def.face_std_dimensions
      @face_decrements = { :thickness => _def.face_thickness_decrement > 0 ? _def.face_thickness_decrement.to_s : nil }

      @entity_names = _def.entity_names.sort_by { |k, v| [ k ] }
      @final_area = _def.final_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.final_area)
      @l_ratio = _def.size.length / [ _def.size.length, _def.size.width ].max
      @l_ratio = 1 if @l_ratio.nan?
      @w_ratio = _def.size.width / [ _def.size.length, _def.size.width ].max
      @w_ratio = 1 if @w_ratio.nan?

    end

    # -----

    def group
      @_group
    end

  end

  class FolderPart < AbstractPart

    attr_reader :children

    def initialize(part_def, group)
      super(part_def, group)

      # @cumulative_cutting_length = nil  # Overrided
      # @cumulative_cutting_width = nil   # Overrided

      @children_warning_count = part_def.children_warning_count
      @children = []

      @is_folder = true

    end

    # ---

    # Children

    def add_child(child_part)

      # Folder part takes first child number
      if @children.empty?
        @name = child_part.name + ', ...' if @name_source == InstanceInfo::NAME_SOURCE_DEFINITION
        @number = child_part.number.to_s + '+'
        @saved_number = child_part.saved_number.to_s + '+' if child_part.saved_number
      end

      @children.push(child_part)
    end

  end

  class Part < AbstractPart

    attr_reader :definition_id,
                :is_dynamic_attributes_name, :is_instance_name,
                :resized, :flipped, :axes_flipped,
                :material_origins, :orientation_locked_on_axis,
                :symmetrical,
                :entity_ids, :entity_serialized_paths,
                :auto_oriented, :not_aligned_on_axes, :content_layers, :multiple_content_layers, :edge_entity_ids, :face_entity_ids, :axes_to_values, :axes_to_dimensions, :dimensions_to_axes

    def initialize(_def, _group, part_number)
      super(_def, _group)

      @definition_id = _def.definition_id
      @number = _def.number ? _def.number : part_number

      @is_dynamic_attributes_name = _def.is_dynamic_attributes_name
      @is_instance_name = _def.is_instance_name

      @resized = !_def.scale.identity?
      @flipped = _def.flipped
      @axes_flipped = _def.size.axes_flipped?

      @material_origins = _def.material_origins

      @orientation_locked_on_axis = _def.orientation_locked_on_axis
      @symmetrical = _def.symmetrical

      @entity_ids = _def.entity_ids
      @entity_serialized_paths = _def.entity_serialized_paths

      @auto_oriented = _def.auto_oriented
      @not_aligned_on_axes = _def.not_aligned_on_axes
      @content_layers = _def.content_layers.map { |v| Sketchup.version_number >= 2000000000 ? v.display_name : v.name }.sort
      @multiple_content_layers = _def.multiple_content_layers
      @edge_entity_ids = _def.edge_entity_ids
      @face_entity_ids = _def.face_entity_ids
      @axes_to_values = _def.size.axes_to_values
      @axes_to_dimensions = _def.size.axes_to_dimensions
      @dimensions_to_axes = _def.size.dimensions_to_axes

    end

    # -----

    def contains_path(path)
      return true if @_def.get_instance_info(PathUtils::serialize_path(path))
      false
    end

  end

  class ChildPart < Part

    def initialize(_def, _group, part_number, folder_part)
      super(_def, _group, part_number)

      @_folder_part = folder_part

      @is_child = true

    end

    # -----

    # FolderPart

    def folder_part
      @_folder_part
    end

  end

end