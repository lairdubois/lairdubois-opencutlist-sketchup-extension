module Ladb::OpenCutList

  class MaterialsImportFromSkmWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :errors => []
      }

      # Fetch material
      materials = model.materials

      dir, filename = File.split(model.path)
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.materials.import_from_skm.title'), dir, "Material Files|*.skm;||")
      if path

        begin
          material = materials.load(path)
        rescue => e
          response[:errors] << [ 'tab.materials.error.failed_import_skm_file', { :error => e.message } ]
        end

      end

      response
    end

    # -----

  end

end