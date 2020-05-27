module Ladb::OpenCutList

  require 'digest'

  class GroupDef

    attr_accessor :material_id, :material_name, :material_display_name, :material_type, :material_color, :material_grained, :part_count, :std_available, :std_dimension_stipped_name, :std_dimension, :std_width, :std_thickness, :max_number, :total_cutting_length, :total_cutting_area, :total_cutting_volume, :total_final_area, :invalid_final_area_part_count, :show_cutting_dimensions, :show_edges, :edge_decremented
    attr_reader :id, :part_defs

    def initialize(id)
      @id = id
      @material_id = ''
      @material_name = ''
      @material_display_name = ''
      @material_type = MaterialAttributes::TYPE_UNKNOW
      @material_color = nil
      @material_grained = false
      @std_available = true
      @std_dimension_stipped_name = ''
      @std_dimension = ''
      @std_width = 0
      @std_thickness = 0
      @max_number = nil
      @part_count = 0
      @part_defs = {}
      @total_cutting_length = 0
      @total_cutting_area = 0
      @total_cutting_volume = 0
      @total_final_area = 0
      @invalid_final_area_part_count = 0
      @show_cutting_dimensions = false
      @show_edges = false
      @edge_decremented = false
    end

    # -----

    def self.generate_group_id(material, material_attributes, std_info)
      Digest::MD5.hexdigest("#{material.nil? ? 0 : material_attributes.uuid}#{material_attributes.type > MaterialAttributes::TYPE_UNKNOW ? '|' + std_info[:dimension] : ''}")
    end

    # -----

    def store_part_def(part_def)
      @part_defs.store(part_def.id, part_def)
    end

    def get_part_def(id)
      if @part_defs.has_key? id
        return @part_defs[id]
      end
      nil
    end

    def include_number?(number)
      @part_defs.each { |id, part_def|
        if part_def.number == number
          return true
        end
      }
      false
    end

  end

end