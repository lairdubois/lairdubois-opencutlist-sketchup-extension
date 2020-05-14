module Ladb::OpenCutList

  class MaterialsGetAttributeWorker

    def initialize(material_data)
      @name = material_data['name']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :errors => [],
          :thickness => '',
          :length_increase => '',
          :width_increase => '',
          :thickness_increase => '',
          :std_lengths => [],
          :std_widths => [],
          :std_thicknesses => [],
          :std_sections => [],
          :std_sizes => [],
          :grained => false,
      }

      # Fetch material
      materials = model.materials
      material = materials[@name]

      if material

        material_attributes = MaterialAttributes.new(material)

        response[:thickness] = material_attributes.thickness
        response[:length_increase] = material_attributes.length_increase
        response[:width_increase] = material_attributes.width_increase
        response[:thickness_increase] = material_attributes.thickness_increase
        response[:std_lengths] = material_attributes.std_lengths
        response[:std_widths] = material_attributes.std_widths
        response[:std_thicknesses] = material_attributes.std_thicknesses
        response[:std_section] = material_attributes.std_sections
        response[:std_sizes] = material_attributes.std_sizes
        response[:grained] = material_attributes.grained
        response[:edge_decremented] = material_attributes.edge_decremented

      end

      response
    end

    # -----

  end

end