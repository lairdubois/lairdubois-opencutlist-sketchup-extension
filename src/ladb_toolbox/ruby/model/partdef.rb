require 'securerandom'

module Ladb
  module Toolbox
    class PartDef

      attr_accessor :name, :count, :raw_size, :size, :material_name, :material_origins
      attr_reader :id, :definition_id, :component_ids

      def initialize(definition_id)
        @id = SecureRandom.uuid
        @definition_id = definition_id
        @name = ''
        @count = 0
        @raw_size = Size.new
        @size = Size.new
        @material_name = ''
        @material_origins = []
        @component_ids = []
      end

      # -----

      def self.part_order(part_def_a, part_def_b, strategy)
        a_values = []
        b_values = []
        if strategy
          properties = strategy.split('>')
          properties.each { |property|
            if property.length < 1
              next
            end
            asc = true
            if property.start_with?('-')
              asc = false
              property.slice!(0)
            end
            case property
              when 'length'
                a_value = part_def_a.size.length
                b_value = part_def_b.size.length
              when 'width'
                a_value = part_def_a.size.width
                b_value = part_def_b.size.width
              when 'thickness'
                a_value = part_def_a.size.thickness
                b_value = part_def_b.size.thickness
              when 'name'
                a_value = part_def_a.name.downcase
                b_value = part_def_b.name.downcase
              when 'count'
                a_value = part_def_a.count
                b_value = part_def_b.count
              else
                next
            end
            if asc
              a_values.push(a_value)
              b_values.push(b_value)
            else
              a_values.push(b_value)
              b_values.push(a_value)
            end
          }
        end
        a_values <=> b_values
      end

      # -----

      def add_component_id(component_id)
        @component_ids.push(component_id)
      end

    end
  end
end