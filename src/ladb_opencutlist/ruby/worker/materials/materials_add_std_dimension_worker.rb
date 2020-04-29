module Ladb::OpenCutList

  class MaterialsAddStdDimensionWorker

    def initialize(settings)
      @material_name = settings['material_name']
      @std_dimension = settings['std_dimension']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@material_name]

      if material

        material_attributes = MaterialAttributes.new(material)
        case material_attributes.type
        when MaterialAttributes::TYPE_SOLID_WOOD, MaterialAttributes::TYPE_SHEET_GOOD
          material_attributes.append_std_thickness(@std_dimension)
        when MaterialAttributes::TYPE_DIMENSIONAL
          material_attributes.append_std_section(@std_dimension)
        when MaterialAttributes::TYPE_EDGE
          material_attributes.append_std_width(@std_dimension)
        else
          return { :errors => [ 'tab.materials.error.no_type_material' ] }
        end
        material_attributes.write_to_attributes

        # Trigger change event on materials observer
        MaterialsObserver.instance.onMaterialChange(materials, material)

      end

      { :success => true }
    end

    # -----

  end

end