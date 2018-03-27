require 'digest'

module Ladb
  module Toolbox
    class PartDef

      attr_accessor :definition_id, :number, :saved_number, :name, :count, :scale, :raw_size, :size, :material_name, :material_origins, :cumulable, :orientation_locked_on_axis
      attr_reader :entity_ids, :entity_serialized_paths, :entity_names, :contains_blank_entity_names

      def initialize()
        @definition_id = ''
        @number = nil
        @saved_number = nil
        @name = ''
        @count = 0
        @raw_size = Size3d.new
        @size = Size3d.new
        @scale = Scale3d.new
        @material_name = ''
        @material_origins = []
        @cumulable = DefinitionAttributes::CUMULABLE_NONE
        @orientation_locked_on_axis = false
        @entity_ids = []                    # All unique entity ids (array count could be smaller than @count)
        @entity_serialized_paths = []       # All Serialized path to each entity (array count should be egals to @count)
        @entity_names = []                  # All non empty entity instance names (array count could be smaller than @count)
        @contains_blank_entity_names = false
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
                a_value = part_def_a.cumulative_raw_length
                b_value = part_def_b.cumulative_raw_length
              when 'width'
                a_value = part_def_a.cumulative_raw_width
                b_value = part_def_b.cumulative_raw_width
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

      def id
        Digest::SHA1.hexdigest(@entity_ids.join(','))   # ParfDef ID is generated according to its entity list
      end

      def cumulative_raw_length
        if @count > 1 && @cumulable == DefinitionAttributes::CUMULABLE_LENGTH
          (@raw_size.length.to_f * @count).to_l
        else
          @raw_size.length
        end
      end

      def cumulative_raw_width
        if @count > 1 && @cumulable == DefinitionAttributes::CUMULABLE_WIDTH
          (@raw_size.width.to_f * @count).to_l
        else
          @raw_size.width
        end
      end

      def add_material_origin(material_origin)
        unless @material_origins.include? material_origin
          @material_origins.push(material_origin)
        end
      end

      def add_entity_id(entity_id)
        unless @entity_ids.include? entity_id   # Because of groups and components, multiple entity can have the same ID
          @entity_ids.push(entity_id)
        end
      end

      def add_entity_serialized_path(entity_serialized_path)
        @entity_serialized_paths.push(entity_serialized_path)
      end

      def add_entity_name(entity_name)
        if entity_name.empty?
          @contains_blank_entity_names = true
        else
          unless @entity_names.include? entity_name   # Because instance name could be defined several times
            @entity_names.push(entity_name)
          end
        end
      end

    end
  end
end