module Ladb::OpenCutList

  require_relative '../model/attributes/definition_attributes'

  module DefinitionAttributesCachingHelper

    def _get_definition_attributes(definition)
      definition = Sketchup.active_model.definitions[definition.to_s] unless definition.is_a?(Sketchup::ComponentDefinition)
      key = definition ? definition.name : '$EMPTY$'
      @definition_attributes_cache = {} unless @definition_attributes_cache.is_a?(Hash)
      @definition_attributes_cache[key] = DefinitionAttributes.new(definition, true) unless @definition_attributes_cache.has_key?(key)
      @definition_attributes_cache[key]
    end

  end

end