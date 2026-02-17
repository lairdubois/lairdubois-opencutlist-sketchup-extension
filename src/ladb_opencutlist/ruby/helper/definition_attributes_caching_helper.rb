module Ladb::OpenCutList

  require_relative '../model/attributes/definition_attributes'

  module DefinitionAttributesCachingHelper

    def _get_definition_attributes(definition)
      definition = Sketchup.active_model.definitions[definition.to_s] unless definition.is_a?(Sketchup::ComponentDefinition)
      key = definition ? definition.name : '$EMPTY$'
      @definition_attributes_cache ||= {}
      @definition_attributes_cache[key] ||= DefinitionAttributes.new(definition, true)
    end

  end

end