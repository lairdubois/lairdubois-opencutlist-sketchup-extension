module Ladb::OpenCutList

  class CutlistPartExportToSkpWorker

    def initialize(settings)
      @definition_id = settings['definition_id']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Fetch definition
      definitions = model.definitions
      definition = definitions[@definition_id]

      return { :errors => [ 'tab.cutlist.error.definition_not_found' ] } unless definition

      # Try to use SU Components dir
      components_dir = Sketchup.find_support_file('Components')
      if File.directory?(components_dir)

        # Join with OpenCutList subdir and create it if it dosen't exist
        dir = File.join(components_dir, 'OpenCutList')
        unless File.directory?(dir)
          FileUtils.mkdir_p(dir)
        end

      else
        dir = File.dirname(model.path)
      end

      # Open save panel
      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.cutlist.export_to_skp.title'), URI::escape(dir), @definition_id + '.skp')
      if path

        # Force "skm" file extension
        unless path.end_with?('.skp')
          path = path + '.skp'
        end

        begin
          success = definition.save_as(path)
          return { :errors => [ 'tab.cutlist.error.failed_export_skp_file', { :error => '' } ] } unless success
          return { :export_path => path }
        rescue => e
          return { :errors => [ 'tab.cutlist.error.failed_export_skp_file', { :error => e.message } ] }
        end
      end

      {
          :cancelled => true
      }
    end

    # -----

  end

end