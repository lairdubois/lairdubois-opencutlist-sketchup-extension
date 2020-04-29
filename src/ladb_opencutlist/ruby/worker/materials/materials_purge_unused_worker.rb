module Ladb::OpenCutList

  class MaterialsPurgeUnusedWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      materials = model.materials
      materials.purge_unused

    end

    # -----

  end

end