module Ladb::OpenCutList

  require_relative '../model/attributes/material_attributes'

  module MaterialAttributesCachingHelper

    def _get_material_attributes(material)
      material = Sketchup.active_model.materials[material.to_s] unless material.is_a?(Sketchup::Material)
      key = material ? material.name : '$EMPTY$'
      @material_attributes_cache = {} unless @material_attributes_cache.is_a?(Hash)
      @material_attributes_cache[key] = MaterialAttributes.new(material, true) unless @material_attributes_cache.has_key?(key)
      @material_attributes_cache[key]
    end

  end

end