module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/dimension_utils'
  require_relative '../../utils/mass_utils'
  require_relative '../../utils/price_utils'
  require_relative '../../utils/color_utils'

  class Group < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :id,
                :material_id, :material_name, :material_display_name, :material_color, :material_type, :material_type_strippedname, :material_description, :material_url, :material_grained, :material_length_increase, :material_length_increased, :material_width_increase, :material_width_increased, :material_thickness_increase, :material_thickness_increased, :material_is_1d, :material_is_2d, :material_is_virtual,
                :part_count,
                :std_available, :std_dimension_stipped_name, :std_dimension, :std_dimension_real, :std_dimension_rounded, :std_width, :std_thickness,
                :total_cutting_length, :total_cutting_area, :total_cutting_volume, :total_final_area,
                :invalid_final_area_part_count,
                :show_cutting_dimensions,
                :show_edges, :edge_decremented,
                :show_faces, :face_decremented,
                :parts

    def initialize(_def, _cutlist)
      @_def = _def
      @_cutlist = _cutlist

      @id = _def.id

      @material_id = _def.material_id
      @material_name = _def.material_name
      @material_display_name = _def.material_display_name
      @material_color = ColorUtils.color_to_hex(_def.material_color)
      @material_type = _def.material_attributes.type
      @material_type_strippedname = MaterialAttributes.type_strippedname(_def.material_attributes.type)
      @material_description = _def.material_attributes.description
      @material_url = _def.material_attributes.url
      @material_grained = _def.material_attributes.grained
      @material_length_increase = _def.material_attributes.length_increase
      @material_length_increased = _def.material_attributes.l_length_increase > 0
      @material_width_increase = _def.material_attributes.width_increase
      @material_width_increased = _def.material_attributes.l_width_increase > 0
      @material_thickness_increase = _def.material_attributes.thickness_increase
      @material_thickness_increased = _def.material_attributes.l_thickness_increase > 0
      @material_is_1d = MaterialAttributes.is_1d?(_def.material_attributes)
      @material_is_2d = MaterialAttributes.is_2d?(_def.material_attributes)
      @material_is_virtual = MaterialAttributes.is_virtual?(_def.material_attributes)

      @part_count = _def.part_count

      @std_available = _def.std_available
      @std_dimension_stipped_name = _def.std_dimension_stipped_name
      @std_dimension = _def.std_dimension
      @std_dimension_real = _def.std_dimension_real
      @std_dimension_rounded = _def.std_dimension_rounded
      @std_width = _def.std_width.to_s.gsub(/~ /, '') # Remove ~ if it exists
      @std_thickness = _def.std_thickness.to_s.gsub(/~ /, '') # Remove ~ if it exists

      @total_cutting_length = _def.total_cutting_length == 0 ? nil : DimensionUtils.format_to_readable_length(_def.total_cutting_length)
      @total_cutting_area = _def.total_cutting_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.total_cutting_area)
      @total_cutting_volume = _def.total_cutting_volume == 0 ? nil : DimensionUtils.format_to_readable_volume(_def.total_cutting_volume, _def.material_attributes.type)
      @total_final_area = _def.total_final_area == 0 ? nil : DimensionUtils.format_to_readable_area(_def.total_final_area)

      @invalid_final_area_part_count = _def.invalid_final_area_part_count

      @show_cutting_dimensions = _def.show_cutting_dimensions

      @show_edges = _def.show_edges
      @edge_decremented = _def.edge_decremented

      @show_faces = _def.show_faces
      @face_decremented = _def.face_decremented

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

    def get_parts(ids = nil, real: true)
      parts = []
      @parts.each do |part|
        if real && part.is_a?(FolderPart)
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
