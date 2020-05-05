module Ladb::OpenCutList

  class MaterialsSetCurrentWorker

    def initialize(settings)
      @name = settings['name']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      # Set material as current
      materials.current = material

      # Send action
      success = Sketchup.send_action('selectPaintTool:')

      {
          :success => success,
      }
    end

    # -----

  end

end