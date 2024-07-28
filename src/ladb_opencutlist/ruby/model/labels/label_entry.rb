module Ladb::OpenCutList

  require_relative '../../helper/hashable_helper'

  class LabelEntry

    include HashableHelper

    attr_accessor :entity_named_path, :entity_name, :thickness_layer, :position_in_batch, :bin, :custom_values
    attr_reader :part, :custom_values

    def initialize(part)
      @part = part
      @custom_values = []
    end

    # -----

    def self.entry_order(entry_a, entry_b, strategy)
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
      a_values <=> b_values
    end

  end

end