module Ladb::OpenCutList

  require 'digest'
  require_relative '../data_container'

  class GroupDef < DataContainer

    attr_accessor :material, :material_attributes, :part_count, :std_available, :std_dimension_stipped_name, :std_dimension, :std_dimension_real, :std_dimension_rounded, :std_width, :std_thickness, :max_number, :total_cutting_length, :total_cutting_area, :total_cutting_volume, :total_final_area, :invalid_final_area_part_count, :show_cutting_dimensions, :show_edges, :edge_decremented, :show_faces, :face_decremented
    attr_reader :id, :part_defs

    def initialize(id)
      @id = id
      @material = nil
      @material_attributes = nil
      @std_available = true
      @std_dimension_stipped_name = ''
      @std_dimension = ''
      @std_dimension_real = ''
      @std_dimension_rounded = false
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
      @show_faces = false
      @face_decremented = false
    end

    # -----

    def self.generate_group_id(material, material_attributes, std_info)
      Digest::MD5.hexdigest("#{material.nil? ? 0 : material_attributes.uuid}#{material_attributes.type > MaterialAttributes::TYPE_UNKNOWN ? '|' + DimensionUtils.to_ocl_precision_f(std_info[:width].to_l).to_s + 'x' + DimensionUtils.to_ocl_precision_f(std_info[:thickness].to_l).to_s : ''}")
    end

    def self.group_order(group_def_a, group_def_b, strategy)
      a_values = []
      b_values = []
      if strategy
        properties = strategy.split('>')
        properties.each { |property|
          next if property.length < 1
          asc = true
          if property.start_with?('-')
            asc = false
            property.slice!(0)
          end
          case property
          when 'material_type'
            a_value = [ MaterialAttributes.type_order(group_def_a.material_attributes.type) ]
            b_value = [ MaterialAttributes.type_order(group_def_b.material_attributes.type) ]
          when 'material_name'
            a_value = [ group_def_a.material_name.empty? ? '~' : group_def_a.material_name.downcase ]
            b_value = [ group_def_b.material_name.empty? ? '~' : group_def_b.material_name.downcase ]
          when 'std_width'
            a_value = [ group_def_a.std_width ]
            b_value = [ group_def_b.std_width ]
          when 'std_thickness'
            a_value = [ group_def_a.std_thickness ]
            b_value = [ group_def_b.std_thickness ]
          else
            next
          end
          if asc
            a_values.concat(a_value)
            b_values.concat(b_value)
          else
            a_values.concat(b_value)
            b_values.concat(a_value)
          end
        }
      end
      a_values <=> b_values
    end

    # -----

    def store_part_def(part_def)
      @part_defs.store(part_def.id, part_def)
    end

    def get_part_def(id)
      if @part_defs.has_key?(id)
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

    # -----

    def material_id
      return '' unless @material.is_a?(Sketchup::Material)
      @material.entityID
    end

    def material_name
      return '' unless @material.is_a?(Sketchup::Material)
      @material.name
    end

    def material_display_name
      return '' unless @material.is_a?(Sketchup::Material)
      @material.display_name
    end

    def material_color
      return nil unless @material.is_a?(Sketchup::Material)
      @material.color
    end

  end

end
