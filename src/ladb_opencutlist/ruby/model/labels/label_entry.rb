module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/hashable_helper'

  class LabelEntry < DataContainer

    include HashableHelper

    attr_accessor :entity_named_path, :entity_name, :thickness_layer, :position_in_batch, :bin
    attr_reader :part, :group_id, :custom_values

    def initialize(part)
      @part = part
      @group_id = part.group.id
      @custom_values = []
    end

    # -----

    def self.entry_order(entry_a, entry_b, strategy)
      a_group_def = entry_a.part.group.def
      b_group_def = entry_b.part.group.def
      a_values = [ MaterialAttributes.type_order(a_group_def.material_attributes.type), a_group_def.material_name.empty? ? '~' : a_group_def.material_name.downcase, -a_group_def.std_width, -a_group_def.std_thickness ]
      b_values = [ MaterialAttributes.type_order(b_group_def.material_attributes.type), b_group_def.material_name.empty? ? '~' : b_group_def.material_name.downcase, -b_group_def.std_width, -b_group_def.std_thickness ]
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
          when 'entity_named_path'
            a_value = [ entry_a.entity_named_path ]
            b_value = [ entry_b.entity_named_path ]
          when 'entity_name'
            a_value = [ entry_a.entity_name ]
            b_value = [ entry_b.entity_name ]
          when 'bin'
            a_value = [ entry_a.bin ]
            b_value = [ entry_b.bin ]
          when 'number'
            a_value = [ entry_a.part.number.is_a?(String) ? entry_a.part.number.rjust(3, ' ') : entry_a.part.number ] # Pad part number with ' ' to be sure that 'AA' is greater than 'Z' -> " AA" > "  Z"
            b_value = [ entry_b.part.number.is_a?(String) ? entry_b.part.number.rjust(3, ' ') : entry_b.part.number ]
          when 'name'
            a_value = [ entry_a.part.name ]
            b_value = [ entry_b.part.name ]
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
      result = a_values <=> b_values
      if result == 0

        # In the case of equality, add an extra compare on position in batch
        a_values << entry_a.position_in_batch
        b_values << entry_b.position_in_batch
        result = a_values <=> b_values

      end
      return result
    end

  end

end