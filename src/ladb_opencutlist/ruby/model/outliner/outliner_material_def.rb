module Ladb::OpenCutList

  require_relative 'outliner_material'

  class OutlinerMaterialDef

    attr_reader :material, :material_attributes

    def initialize(material)
      @material = material
      @material_attributes = MaterialAttributes.new(material)
    end

    # -----

    def create_hashable
      @hashable = OutlinerMaterial.new(self) if @hashable.nil?
      @hashable
    end

  end

end