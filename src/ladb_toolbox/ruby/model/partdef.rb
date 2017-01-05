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

      def self.part_order(part_def, strategy)
        block = []
        if strategy
          properties = strategy.split('>')
          properties.each { |property|
            if property.length < 1
              next
            end
            order = 1
            if property.start_with?('-') && property.length == 2
              order = -1
              property.slice!(0)
            end
            case property
              when 'length'
                block.push(part_def.size.length * order)
              when 'width'
                block.push(part_def.size.width * order)
              when 'thickness'
                block.push(part_def.size.thickness * order)
              when 'name'
                block.push(part_def.name.downcase * order)
              else
                next
            end
          }
        end
        block
      end

      # -----

      def add_component_id(component_id)
        @component_ids.push(component_id)
      end

    end
  end
end