module Ladb::OpenCutList

  class ImporterOpenWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.importer.error.no_model' ] } unless model

      response = {
          :errors => [],
          :length_unit => DimensionUtils.instance.length_unit,
      }

      # Ask for open file path
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.importer.load.title'), '', "CSV|*.csv|TSV|*.tsv||")
      if path

        filename = File.basename(path)
        extname = File.extname(path)

        # Errors
        unless File.exist?(path)
          response[:errors] << [ 'tab.importer.error.file_not_found', { :filename => filename } ]
          return response
        end
        if extname.nil? || extname.downcase != '.csv' && extname.downcase != '.tsv'
          response[:errors] << [ 'tab.importer.error.bad_extension', { :filename => filename } ]
          return response
        end

        # Add file infos to response
        response[:path] = path.tr("\\", '/')  # Standardize path by replacing \ by /
        response[:filename] = filename

      end

      response
    end

    # -----

  end

end