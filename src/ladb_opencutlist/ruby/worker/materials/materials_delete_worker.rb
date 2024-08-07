module Ladb::OpenCutList

  class MaterialsDeleteWorker

    def initialize(

                   name:

    )

      @name = name

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      begin
        success = materials.remove(material)
      rescue => e
        return { :errors => [ [ 'tab.materials.error.failed_deleting_material', { :error => e.message } ] ] }
      end

      {
          :success => success
      }
    end

    # -----

  end

end