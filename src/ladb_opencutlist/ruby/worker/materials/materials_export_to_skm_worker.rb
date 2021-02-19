module Ladb::OpenCutList

  class MaterialsExportToSkmWorker

    def initialize(material_data)
      @name = material_data['name']
      @display_name = material_data['display_name']
      @display_name = material_data['display_name']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials
      material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless material

      # Retrieve SU Materials dir
      materials_dir = Sketchup.find_support_file('Materials')

      # Join with OpenCutList subdir and create it if it dosen't exist
      dir = File.join(materials_dir, 'OpenCutList')
      unless File.directory?(dir)
        FileUtils.mkdir_p(dir)
      end

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.materials.export_to_skm.title'), URI::escape(dir), @display_name + '.skm')
      if path
        begin
          success = material.save_as(path)
          return { :errors => [ 'tab.materials.error.failed_export_skm_file', { :error => '' } ] } unless success
          return { :export_path => path }
        rescue => e
          return { :errors => [ 'tab.materials.error.failed_export_skm_file', { :error => e.message } ] }
        end
      end

      {
          :cancelled => true
      }
    end

    # -----

  end

end