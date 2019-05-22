module Ladb::OpenCutList

  require 'digest'

  class PartDef

    attr_accessor :definition_id, :number, :saved_number, :name, :count, :scale, :raw_size, :size, :material_name, :material_origins, :cumulable, :orientation_locked_on_axis, :labels, :auto_oriented, :aligned_on_axes, :real_area
    attr_reader :id, :entity_ids, :entity_serialized_paths, :entity_names, :contains_blank_entity_names

    def initialize(id)
      @id = id
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
      @labels = ''
      @entity_ids = []                    # All unique entity ids (array count could be smaller than @count)
      @entity_serialized_paths = []       # All Serialized path to each entity (array count should be egals to @count)
      @entity_names = {}                  # All non empty entity instance names (key = name, value = count)
      @contains_blank_entity_names = false
      @auto_oriented = false
      @aligned_on_axes = false
      @real_area = nil
    end

    # -----

    def self.generate_part_id(group_id, definition, size)
      # Include size into part_id to separate instances with the same definition, but different scale
      Digest::MD5.hexdigest("#{group_id}|#{definition.entityID}|#{size.length.to_s}|#{size.width.to_s}|#{size.thickness.to_s}")
    end

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

    # def id
    #   Digest::SHA1.hexdigest(@entity_ids.join(','))   # ParfDef ID is generated according to its entity list
    # end

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
        if @entity_names.has_key? entity_name
          @entity_names[entity_name] += 1
        else
          @entity_names[entity_name] = 1
        end
      end
    end

  end

end