module Ladb::OpenCutList

  require 'json'

  class DefinitionAttributes

    CUMULABLE_NONE = 0
    CUMULABLE_LENGTH = 1
    CUMULABLE_WIDTH = 2

    attr_accessor :uuid, :cumulable, :orientation_locked_on_axis, :labels, :length_increase, :width_increase, :thickness_increase
    attr_reader :definition

    @@cached_uuids = {}
    @@used_uuids = []

    def initialize(definition, force_unique_uuid =false)
      @definition = definition
      read_from_attributes(force_unique_uuid)
    end

    # -----

    def self.store_cached_uuid(definition, uuid)
      @@cached_uuids.store("#{definition.model.guid}|#{definition.entityID}", uuid)
    end

    def self.fetch_cached_uuid(definition)
      @@cached_uuids.fetch("#{definition.model.guid}|#{definition.entityID}", nil)
    end

    def self.delete_cached_uuid(definition)
      @@cached_uuids.delete("#{definition.model.guid}|#{definition.entityID}")
    end

    def self.reset_used_uuids
      @@used_uuids.clear
    end

    def self.valid_cumulable(cumulable)
      if cumulable
        i_cumulable = cumulable.to_i
        if i_cumulable < CUMULABLE_NONE or i_cumulable > CUMULABLE_WIDTH
          CUMULABLE_NONE
        end
        i_cumulable
      else
        CUMULABLE_NONE
      end
    end

    def self.valid_labels(labels)
      if labels
        if labels.is_a? Array and !labels.empty?
          return labels.map(&:strip).reject { |label| label.empty? }.uniq.sort
        elsif labels.is_a? String
          return labels.split(';').map(&:strip).reject { |label| label.empty? }.uniq.sort
        end
      end
      return []
    end

    # -----

    def store_number(part_id, number)
      if number.nil?
        @numbers.delete(part_id)
      else
        @numbers.store(part_id, number)
      end
    end

    def fetch_number(part_id)
      @numbers.fetch(part_id, nil)
    end

    # -----

    def has_labels(labels)
      (labels - @labels).empty?
    end

    # -----

    def uuid
      if @uuid.nil?

        if Sketchup.version_number >= 2010000000

          # Running on > SU20.1.0 Use Material#persistent_id
          @uuid = @definition.persistent_id

        else

          # Generate a new UUID
          @uuid = SecureRandom.uuid

        end

        # Cache generated UUID
        DefinitionAttributes.store_cached_uuid(@definition, @uuid)

      end
      @uuid
    end

    def l_length_increase
      DimensionUtils.instance.d_to_ifloats(length_increase).to_l
    end

    def l_width_increase
      DimensionUtils.instance.d_to_ifloats(width_increase).to_l
    end

    def l_thickness_increase
      DimensionUtils.instance.d_to_ifloats(thickness_increase).to_l
    end

    # -----

    def read_from_attributes(force_unique_uuid = false)
      if @definition

        # Try to retrieve uuid from cached UUIDs
        @uuid = DefinitionAttributes.fetch_cached_uuid(@definition)

        if @uuid.nil?
          # Try to retrieve uuid from definition's attributes
          @uuid = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', nil) if @definition
        end

        unless @uuid.nil?
          if force_unique_uuid && @@used_uuids.include?(@uuid)
            @uuid = nil
          else
            @@used_uuids.push(@uuid)
          end
        end

        begin
          @numbers = JSON.parse(@definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'numbers', '{}'))
        rescue JSON::ParserError
          @numbers = {}
        end
        @cumulable = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'cumulable', CUMULABLE_NONE)
        @orientation_locked_on_axis = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', false)
        @labels = DefinitionAttributes.valid_labels(@definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'labels', []))
        @length_increase = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', '0')
        @width_increase = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', '0')
        @thickness_increase = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', '0')
      end
    end

    def write_to_attributes
      if @definition

        unless @uuid.nil?
          @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', @uuid)
          DefinitionAttributes.delete_cached_uuid(@definition)
        end

        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'numbers', @numbers.to_json)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'cumulable', @cumulable)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', @orientation_locked_on_axis)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'labels', @labels)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', DimensionUtils.instance.str_add_units(@length_increase))
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', DimensionUtils.instance.str_add_units(@width_increase))
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', DimensionUtils.instance.str_add_units(@thickness_increase))
      end
    end

  end

end