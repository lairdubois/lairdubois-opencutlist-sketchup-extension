module Ladb::OpenCutList

  require_relative 'material'

  class MaterialDef

    attr_reader :material, :material_attributes

    def initialize(material)
      @material = material
      @material_attributes = MaterialAttributes.new(material)
    end

    # -----

    def create_material
      Material.new(self)
    end

  end

end