module Ladb::OpenCutList

  require 'digest'

  class GroupDef

    attr_accessor :material_id, :material_name, :material_type, :part_count, :std_dimension, :std_available, :std_availability_message, :std_width, :std_thickness, :max_number, :raw_length, :raw_area, :raw_volume, :show_raw_dimensions
    attr_reader :id, :part_defs

    def initialize(id)
      @id = id
      @material_id = ''
      @material_name = ''
      @material_type = MaterialAttributes::TYPE_UNKNOW
      @std_dimension = ''
      @std_available = true,
      @std_availability_message = ''
      @std_width = 0
      @std_thickness = 0
      @max_number = nil
      @part_count = 0
      @part_defs = {}
      @raw_length = 0
      @raw_area = 0
      @raw_volume = 0
      @show_raw_dimensions = false
    end

    # -----

    def self.generate_group_id(material, material_attributes, std_info)
      Digest::MD5.hexdigest("#{material.nil? ? 0 : material_attributes.uuid}#{material_attributes.type > MaterialAttributes::TYPE_UNKNOW ? '|' + std_info[:dimension] : ''}")
    end

    # -----

    def set_part_def(key, part_def)
      @part_defs.store(key, part_def)
    end

    def get_part_def(key)
      if @part_defs.has_key? key
        return @part_defs[key]
      end
      nil
    end

    def include_number?(number)
      @part_defs.each { |key, part_def|
        if part_def.number == number
          return true
        end
      }
      false
    end

    # -----

    def to_struct
      {
          :id => id,
          :material_id => material_id,
          :material_name => material_name,
          :material_type => material_type,
          :part_count => part_count,
          :std_dimension => std_dimension,
          :std_available => std_available,
          :std_availability_message => std_availability_message,
          :raw_length => raw_length == 0 ? nil : DimensionUtils.instance.format_length(raw_length),
          :raw_area => raw_area == 0 ? nil : DimensionUtils.instance.format_area(raw_area),
          :raw_volume => raw_volume == 0 ? nil : DimensionUtils.instance.format_volume(raw_volume),
          :show_raw_dimensions => show_raw_dimensions,
          :parts => []
      }
    end
  end

end