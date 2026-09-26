module Ladb::OpenCutList

  require 'json'
  require_relative '../../utils/unit_utils'

  class DefinitionAttributes

    CUMULABLE_NONE = 0
    CUMULABLE_LENGTH = 1
    CUMULABLE_WIDTH = 2

    # -- ROLE --
    #
    # What a part IS FOR, where nothing in its geometry says so - see
    # CommonSolidFindCavitiesWorker, APPLIED PANELS : a front panel laid on its
    # carcass and a back laid on the same way are shaped exactly alike, and
    # only what the part is FOR tells the two apart.
    #
    # It is borne by the DEFINITION : the part itself, which is what the
    # cutlist counts. What makes a part a front - its hinges, their
    # machinings - is drawn into the definition, and every occurrence of it
    # is that same front. SketchUp copies the attributes of a definition onto
    # the new one when an occurrence is made unique (explicitly, or by
    # editing a copied group), and DefinitionList#load keeps them on the
    # definitions of a module loaded from another SKP file - where it drops
    # those of the TAGS it brings in. The tag the panels are put on is only
    # there to show or hide them at once.
    #
    # Stored as a plain String under 'role'.

    ROLE_FRONT_PANEL = 'front_panel'.freeze
    ROLE_BACK_PANEL = 'back_panel'.freeze

    ROLES = [ ROLE_FRONT_PANEL, ROLE_BACK_PANEL ].freeze

    # The roles of a panel LAID ON its container rather than part of it - what
    # the cavity detection has to leave out of the carcass. A separate role
    # each rather than one "applied panel" role for both, because what the two
    # are FOR is exactly what has to be told apart : a handler draws its own
    # role, and must not offer to draw a second one where one already stands -
    # while the OTHER role is the most natural wall in the world to lean a pick
    # on (see SmartBuildMouthPanelActionHandler#_picked_on_existing_panel?).
    ROLES_APPLIED_PANEL = [ ROLE_FRONT_PANEL, ROLE_BACK_PANEL ].freeze

    attr_accessor :uuid,
                  :url, :tags,
                  :cumulable, :instance_count_by_part,
                  :mass, :price,
                  :length_increase, :width_increase, :thickness_increase,
                  :symmetrical, :ignore_grain_direction, :follow_grain_direction, :orientation_locked_on_axis, :thickness_layer_count,
                  :role
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

    def self.valid_role(role)
      ROLES.include?(role) ? role : nil
    end

    # Whether the given role marks a panel LAID ON its container - see
    # ROLES_APPLIED_PANEL.
    def self.applied_panel_role?(role)
      ROLES_APPLIED_PANEL.include?(role)
    end

    # The role of the given entity - a definition, or an instance read
    # through its definition - nil when it has none : what an entity of an
    # untouched model, or any entity that is neither, answers.
    def self.role_of(entity)
      entity = entity.definition if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      return nil unless entity.is_a?(Sketchup::ComponentDefinition)
      valid_role(entity.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role'))
    end

    def self.write_role(definition, role)
      definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role', role)
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

    def has_all_tags?(tags)
      return true if tags.empty?
      (tags & @tags).size == tags.size
    end

    def has_any_tags?(tags)
      (tags & @tags).any?
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

    def l_length_increase
      DimensionUtils.d_to_ifloats(length_increase).to_l
    end

    def l_width_increase
      DimensionUtils.d_to_ifloats(width_increase).to_l
    end

    def l_thickness_increase
      DimensionUtils.d_to_ifloats(thickness_increase).to_l
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
        @url = @definition.get_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Url', '')
        @tags = DefinitionAttributes.valid_tags(@definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'tags', @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'labels', []))) # BC for "labels" key
        @cumulable = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'cumulable', CUMULABLE_NONE)
        @instance_count_by_part = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'instance_count_by_part', 1)
        @mass = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'mass', '')
        @price = DefinitionAttributes.valid_price(@definition.get_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, Plugin::SU_PRICE_ATTRIBUTE_KEY, ''))
        @length_increase = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', '0')
        @width_increase = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', '0')
        @thickness_increase = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', '0')
        @symmetrical = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'symmetrical', false)
        @ignore_grain_direction = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'ignore_grain_direction', false)
        @follow_grain_direction = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'follow_grain_direction', false)
        @orientation_locked_on_axis = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', false)
        @thickness_layer_count = @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_layer_count', 1)
        @role = DefinitionAttributes.role_of(@definition)
      end
    end

    def write_to_attributes
      if @definition

        unless @uuid.nil?
          @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'uuid', @uuid)
          DefinitionAttributes.delete_cached_uuid(@definition)
        end

        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'numbers', @numbers.to_json)
        @definition.set_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Url', @url)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'tags', @tags)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'cumulable', @cumulable)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'instance_count_by_part', @instance_count_by_part)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'mass', @mass)
        @definition.set_attribute(Plugin::SU_ATTRIBUTE_DICTIONARY, 'Price', @price)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'length_increase', DimensionUtils.str_add_units(@length_increase))
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'width_increase', DimensionUtils.str_add_units(@width_increase))
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_increase', DimensionUtils.str_add_units(@thickness_increase))
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'symmetrical', @symmetrical)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'ignore_grain_direction', @ignore_grain_direction)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'follow_grain_direction', @follow_grain_direction)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'orientation_locked_on_axis', @orientation_locked_on_axis)
        @definition.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'thickness_layer_count', @thickness_layer_count)
        if @role.nil?
          @definition.delete_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role') unless @definition.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role').nil?
        else
          DefinitionAttributes.write_role(@definition, @role)
        end
      end
    end

  end

end