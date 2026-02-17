module Ladb::OpenCutList

  require_relative '../model/attributes/material_attributes'

  module MaterialAttributesCachingHelper

    def _get_material_attributes(material)
      material = Sketchup.active_model.materials[material.to_s] unless material.is_a?(Sketchup::Material)
      key = material ? material.name : '$EMPTY$'
      @material_attributes_cache ||= {}
      @material_attributes_cache[key] ||= MaterialAttributes.new(material, true)
    end

  end

end