module Ladb::OpenCutList

  class MaterialsAddStdDimensionWorker

    def initialize(

                   material_name: ,
                   std_dimension:

    )

      @material_name = material_name
      @std_dimension = std_dimension

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Start a model modification operation
      model.start_operation('OCL Material Add Std Dimension', true, false, true)

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

        # Trigger change event on the materials observer
        PLUGIN.app_observer.materials_observer.onMaterialChange(materials, material)

      end

      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end