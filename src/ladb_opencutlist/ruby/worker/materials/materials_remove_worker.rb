module Ladb::OpenCutList

  class MaterialsRemoveWorker

    def initialize(material_data)
      @name = material_data['name']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :errors => []
      }

      # Fetch material
      materials = model.materials
      material = materials[@name]

      if material

        begin
          materials.remove(material)
        rescue => e
          response[:errors] << [ 'tab.materials.error.failed_removing_material', { :error => e.message } ]
        end

      else
        response[:errors] << [ 'tab.materials.error.failed_removing_material', { :error => '' }]
      end

      response
    end

    # -----

  end

end