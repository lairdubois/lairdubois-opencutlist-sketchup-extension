module Ladb::OpenCutList

  class MaterialsImportFromSkmWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials

      # Try to use SU Materials dir
      materials_dir = Sketchup.find_support_file('Materials')
      if File.directory?(materials_dir)

        # Join with OpenCutList subdir and create it if it dosen't exist
        dir = File.join(materials_dir, 'OpenCutList')
        unless File.directory?(dir)
          FileUtils.mkdir_p(dir)
        end

      else
        dir = File.dirname(model.path)
      end

      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.materials.import_from_skm.title'), URI::escape(dir), "Material Files|*.skm;||")
      if path
        begin
          material = materials.load(path)
          return { :material_id => material.entityID }
        rescue => e
          return { :error => [ 'tab.materials.error.failed_import_skm_file', { :error => e.message } ] }
        end
      end

      {
          :cancelled => true
      }
    end

    # -----

  end

end