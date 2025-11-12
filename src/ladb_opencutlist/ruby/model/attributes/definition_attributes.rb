module Ladb::OpenCutList

  require 'json'
  require_relative '../../utils/unit_utils'

  class DefinitionAttributes

    CUMULABLE_NONE = 0
    CUMULABLE_LENGTH = 1
    CUMULABLE_WIDTH = 2

    attr_accessor :uuid, :cumulable, :instance_count_by_part, :mass, :price, :url, :symmetrical, :ignore_grain_direction, :tags, :orientation_locked_on_axis, :thickness_layer_count
    attr_reader :definition

    @@cached_uuids = {}
    @@used_uuids = []

    def initialize(definition, force_unique_uuid = false)
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
        if i_cumulable < CUMULABLE_NONE || i_cumulable > CUMULABLE_WIDTH
          CUMULABLE_NONE
        end
        i_cumulable
      else
        CUMULABLE_NONE
      end
    end

    def self.valid_price(price)
      return '' unless price.is_a?(String)
      return price if price.empty?
      price.scan(/\d*(?:[.,]?\d+)?/).select { |p| !p.empty? }.first
    end

    def self.valid_tags(tags)
      if tags
        if tags.is_a?(Array) && !tags.empty?
          return tags.map(&:strip).reject { |tag| tag.empty? }.uniq.sort
        elsif tags.is_a?(String)
          return tags.split(';').map(&:strip).reject { |tag| tag.empty? }.uniq.sort
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

    def has_tags(tags)
      return false if tags.empty?
      (tags - @tags).empty?
    end

    # -----

    def uuid
      if @uuid.nil?

        # Generate a new UUID
        @uuid = SecureRandom.uuid

        # Cache generated UUID
        # DefinitionAttributes.store_cached_uuid(@definition, @uuid)

        # Store UUID in definition's attributes
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', @uuid)

      end
      @uuid
    end

    def h_mass
      unit, val = UnitUtils.split_unit_and_value(mass)
      { :unit => unit, :val => val }
    end

    def h_price
      unit, val = UnitUtils.split_unit_and_value(price)
      { :unit => '$_p', :val => val }
    end

    # -----

    def read_from_attributes(force_unique_uuid = false)
      if @definition

        # Try to retrieve uuid from cached UUIDs
        # @uuid = DefinitionAttributes.fetch_cached_uuid(@definition)

        # Try to retrieve uuid from definition's attributes
        @uuid = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', nil)# if @uuid.nil?

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
        @instance_count_by_part = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'instance_count_by_part', 1)
        @mass = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'mass', '')
        @price = DefinitionAttributes.valid_price(@definition.get_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Price', ''))
        @url = @definition.get_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Url', '')
        @symmetrical = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'symmetrical', false)
        @ignore_grain_direction = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'ignore_grain_direction', false)
        @tags = DefinitionAttributes.valid_tags(@definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'tags', @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'labels', []))) # BC for "labels" key
        @orientation_locked_on_axis = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', false)
        @thickness_layer_count = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_layer_count', 1)
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
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'instance_count_by_part', @instance_count_by_part)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'mass', @mass)
        @definition.set_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Price', @price)
        @definition.set_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Url', @url)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'symmetrical', @symmetrical)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'ignore_grain_direction', @ignore_grain_direction)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'tags', @tags)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', @orientation_locked_on_axis)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_layer_count', @thickness_layer_count)
      end
    end

  end

end