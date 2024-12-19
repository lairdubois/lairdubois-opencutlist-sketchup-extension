module Ladb::OpenCutList

  class MaterialsExportToSkmWorker

    def initialize(

                   name: ,
                   display_name:

    )

      @name = name
      @display_name = display_name

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      last_dir = PLUGIN.read_default(Plugin::SETTINGS_KEY_MATERIALS_LAST_DIR, nil)
      if last_dir && File.directory?(last_dir) && File.exist?(last_dir)
        dir = last_dir
      else

        # Try to use SU Materials dir
        materials_dir = Sketchup.find_support_file('Materials', '')
        if File.directory?(materials_dir)

          # Join with OpenCutList subdir and create it if it dosen't exist
          dir = File.join(materials_dir, 'OpenCutList')
          unless File.directory?(dir)
            FileUtils.mkdir_p(dir)
          end

        else
          dir = File.dirname(model.path)
        end

      end

      dir = dir.gsub(/ /, '%20') if PLUGIN.platform_is_mac?

      # Open save panel
      path = UI.savepanel(PLUGIN.get_i18n_string('tab.materials.export_to_skm.title'), dir, @display_name + '.skm')
      if path

        # Save last dir
        PLUGIN.write_default(Plugin::SETTINGS_KEY_MATERIALS_LAST_DIR, File.dirname(path))

        # Force "skm" file extension
        path = path + '.skm' unless path.end_with?('.skm')

        begin
          success = material.save_as(path)
          return { :errors => [ [ 'tab.materials.error.failed_export_skm_file', { :error => '' } ] ] } unless success
          return { :export_path => path }
        rescue => e
          return { :errors => [ [ 'tab.materials.error.failed_export_skm_file', { :error => e.message } ] ] }
        end
      end

      {
          :cancelled => true
      }
    end

    # -----

  end

end