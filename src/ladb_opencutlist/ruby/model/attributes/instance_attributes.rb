module Ladb::OpenCutList

  class InstanceAttributes

    # -- ROLE --
    #
    # What an instance IS FOR, where nothing in its geometry says so - see
    # CommonSolidFindCavitiesWorker, APPLIED PANELS : a front panel laid on its
    # carcass and a back laid on the same way are shaped exactly alike, and
    # only what the part is FOR tells the two apart.
    #
    # It is borne by the INSTANCE : the occurrence laid there, which is what
    # the role is about - a definition may well be shared with parts of
    # another kind, and it is what a module loaded from another SKP file
    # keeps. Not a TAG : DefinitionList#load and Model#import both drop the
    # attribute dictionaries of the layers they bring in, where those of the
    # instances come through intact. The tag the panels are put on is only
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

    attr_accessor :is_grain_group, :role

    def initialize(instance)
      @instance = instance
      read_from_attributes
    end

    # -----

    def self.valid_role(role)
      ROLES.include?(role) ? role : nil
    end

    # Whether the given role marks a panel LAID ON its container - see
    # ROLES_APPLIED_PANEL.
    def self.applied_panel_role?(role)
      ROLES_APPLIED_PANEL.include?(role)
    end

    # The role of the given entity, nil when it has none - which is what an
    # entity of an untouched model, or any entity that is not an instance,
    # answers.
    def self.role_of(entity)
      return nil unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      valid_role(entity.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role'))
    end

    def self.write_role(instance, role)
      instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role', role)
    end

    # -----

    def read_from_attributes
      if @instance
        @is_grain_group = PLUGIN.get_attribute(@instance, 'is_grain_group', false)
        @role = InstanceAttributes.role_of(@instance)
      else
        @is_grain_group = false
        @role = nil
      end
    end

    def write_to_attributes
      if @instance
        @instance.set_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'is_grain_group', @is_grain_group)
        if @role.nil?
          @instance.delete_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role') unless @instance.get_attribute(Plugin::ATTRIBUTE_DICTIONARY, 'role').nil?
        else
          InstanceAttributes.write_role(@instance, @role)
        end
      end
    end

  end

end
