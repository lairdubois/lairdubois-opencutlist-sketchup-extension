module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'
  require_relative '../../utils/color_utils'

  class Group

    include DefHelper
    include HashableHelper

    attr_reader :id, :material_id, :material_name, :material_display_name, :material_color, :material_type, :material_description, :material_url, :material_grained, :material_length_increased, :material_width_increased, :material_thickness_increased, :part_count, :std_available, :std_dimension_stipped_name, :std_dimension, :std_dimension_real, :std_dimension_rounded, :std_width, :std_thickness, :total_cutting_length, :total_cutting_area, :total_cutting_volume, :total_final_area, :invalid_final_area_part_count, :show_cutting_dimensions, :show_edges, :edge_decremented, :show_faces, :face_decremented, :parts

    def initialize(group_def, cutlist)
      @_def = group_def
      @_cutlist = cutlist

      @id = group_def.id
      @material_id = group_def.material_id
      @material_name = group_def.material_name
      @material_display_name = group_def.material_display_name
      @material_color = ColorUtils.color_to_hex(group_def.material_color)
      @material_type = group_def.material_attributes.type
      @material_description = group_def.material_attributes.description
      @material_url = group_def.material_attributes.url
      @material_grained = group_def.material_attributes.grained
      @material_length_increased = group_def.material_attributes.l_length_increase > 0
      @material_width_increased = group_def.material_attributes.l_width_increase > 0
      @material_thickness_increased = group_def.material_attributes.l_thickness_increase > 0
      @part_count = group_def.part_count
      @std_available = group_def.std_available
      @std_dimension_stipped_name = group_def.std_dimension_stipped_name
      @std_dimension = group_def.std_dimension
      @std_dimension_real = group_def.std_dimension_real
      @std_dimension_rounded = group_def.std_dimension_rounded
      @std_width = group_def.std_width.to_s.gsub(/~ /, ''), # Remove ~ if it exists
      @std_thickness = group_def.std_thickness.to_s.gsub(/~ /, ''), # Remove ~ if it exists
      @total_cutting_length = group_def.total_cutting_length == 0 ? nil : DimensionUtils.instance.format_to_readable_length(group_def.total_cutting_length)
      @total_cutting_area = group_def.total_cutting_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(group_def.total_cutting_area)
      @total_cutting_volume = group_def.total_cutting_volume == 0 ? nil : DimensionUtils.instance.format_to_readable_volume(group_def.total_cutting_volume, group_def.material_attributes.type)
      @total_final_area = group_def.total_final_area == 0 ? nil : DimensionUtils.instance.format_to_readable_area(group_def.total_final_area)
      @invalid_final_area_part_count = group_def.invalid_final_area_part_count
      @show_cutting_dimensions = group_def.show_cutting_dimensions
      @show_edges = group_def.show_edges
      @edge_decremented = group_def.edge_decremented
      @show_faces = group_def.show_faces
      @face_decremented = group_def.face_decremented

      @parts = []
    end

    # ---

    # Cutlist

    def cutlist
      @_cutlist
    end

    # Parts

    def add_part(part)
      @parts.push(part)
    end

    def get_parts(ids = nil)
      parts = []
      @parts.each do |part|
        parts << part unless ids && !ids.include?(part.id)
      end
      parts
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
