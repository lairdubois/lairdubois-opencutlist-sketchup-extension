module Ladb::OpenCutList

  module ComponentUtils

    # The dictionaries stored on the definition of a loaded SKP file : metadata
    # of the file's model (and a 'temp' scratch one), meaningless on a group.
    SKP_FILE_DICTIONARY_NAMES = %w[ TempShadowInfo SU_DefinitionSet GSU_ContributorsInfo GeoReference temp ].freeze

    # The keys, in any dictionary, that hold the file's model settings - the
    # presets of OpenCutList (Plugin::PRESETS_KEY) and of the extensions that
    # share its storage.
    SKP_FILE_ATTRIBUTE_KEYS = %w[ core.presets ].freeze

    # Replaces a component instance by a group holding the exploded content of
    # its definition, at the same place. The instance properties, and the
    # definition attributes and behavior are carried over to the group.
    # The definition itself is left untouched - even without any instance.
    # Must run inside an operation.
    #
    # @param instance [Sketchup::ComponentInstance]
    #
    # @return [Sketchup::Group]
    def self.component_to_group(instance)
      definition = instance.definition

      group = instance.parent.entities.add_group
      group.entities.add_instance(definition, IDENTITY).explode
      group.transformation = instance.transformation

      group.name = instance.name
      group.layer = instance.layer
      group.material = instance.material
      group.casts_shadows = instance.casts_shadows?
      group.receives_shadows = instance.receives_shadows?
      group.visible = instance.visible?
      copy_attributes(instance, group)

      copy_attributes(definition, group.definition, SKP_FILE_DICTIONARY_NAMES, SKP_FILE_ATTRIBUTE_KEYS)
      copy_behavior(definition.behavior, group.definition.behavior)

      group.locked = instance.locked?
      instance.erase!

      group
    end

    # SketchUp's internal dictionaries (GSU_ContributorsInfo…) are read-only :
    # they are skipped.
    #
    # @param src [Sketchup::Entity]
    # @param dst [Sketchup::Entity]
    # @param excluded_names [Array<String>] the dictionaries not to copy
    # @param excluded_keys [Array<String>] the keys not to copy, in any dictionary
    def self.copy_attributes(src, dst, excluded_names = [], excluded_keys = [])
      return if src.attribute_dictionaries.nil?
      src.attribute_dictionaries.each do |attribute_dictionary|
        next if excluded_names.include?(attribute_dictionary.name)
        begin
          attribute_dictionary.each do |key, value|
            next if excluded_keys.include?(key)
            dst.set_attribute(attribute_dictionary.name, key, value)
          end
        rescue ArgumentError  # "Cannot modify internal attribute dictionaries."
          next
        end
      end
    end

    # @param src [Sketchup::Behavior]
    # @param dst [Sketchup::Behavior]
    def self.copy_behavior(src, dst)
      dst.is2d = src.is2d?  # Before snapto and cuts_opening that depend on it
      dst.snapto = src.snapto
      dst.cuts_opening = src.cuts_opening?
      dst.always_face_camera = src.always_face_camera?
      dst.shadows_face_sun = src.shadows_face_sun?
      dst.no_scale_mask = src.no_scale_mask?
    end

  end

end
