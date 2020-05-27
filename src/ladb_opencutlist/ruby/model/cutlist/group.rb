module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class Group

    include HashableHelper

    attr_reader :id, :material_id, :material_name, :material_display_name, :material_type, :material_color, :material_grained, :part_count, :std_available, :std_dimension_stipped_name, :std_dimension, :std_width, :std_thickness, :total_cutting_length, :total_cutting_area, :total_cutting_volume, :total_final_area, :invalid_final_area_part_count, :show_cutting_dimensions, :show_edges, :edge_decremented, :parts

    def initialize(group_def, cutlist)
      @_def = group_def
      @_cutlist = cutlist

      @id = group_def.id
      @material_id = group_def.material_id
      @material_name = group_def.material_name
      @material_display_name = group_def.material_display_name
      @material_type = group_def.material_type
      @material_color = group_def.material_color.nil? ? nil : "#%02x%02x%02x" % [ group_def.material_color.red, group_def.material_color.green, group_def.material_color.blue ]
      @material_grained = group_def.material_grained
      @part_count = group_def.part_count
      @std_available = group_def.std_available
      @std_dimension_stipped_name = group_def.std_dimension_stipped_name
      @std_dimension = group_def.std_dimension
      @std_width = group_def.std_width.to_s
      @std_thickness = group_def.std_thickness.to_s
      @total_cutting_length = group_def.total_cutting_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(group_def.total_cutting_length)
      @total_cutting_area = group_def.total_cutting_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(group_def.total_cutting_area)
      @total_cutting_volume = group_def.total_cutting_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(group_def.total_cutting_volume)
      @total_final_area = group_def.total_final_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(group_def.total_final_area)
      @invalid_final_area_part_count = group_def.invalid_final_area_part_count
      @show_cutting_dimensions = group_def.show_cutting_dimensions
      @show_edges = group_def.show_edges
      @edge_decremented = group_def.edge_decremented

      @parts = []
    end

    # ---

    # Def

    def def
      @_def
    end

    # Cutlist

    def cutlist
      @_cutlist
    end

    # Parts

    def add_part(part)
      @parts.push(part)
    end

    def get_real_parts(ids = nil)
      parts = []
      @parts.each do |part|
        if part.is_a? FolderPart
          part.children.each do |child_part|
            parts << child_part unless ids && !ids.include?(child_part.id) && !ids.include?(part.id)
          end
        else
          parts << part unless ids && !ids.include?(part.id)
        end
      end
      parts
    end


  end

end