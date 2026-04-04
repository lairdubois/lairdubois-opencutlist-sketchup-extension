module Ladb::OpenCutList

  class ImportersCsvOpenWorker

        def initialize(

                   path: nil

    )

      @path = path

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.importer.default.error.no_model' ] } unless model

      response = {
          :errors => [],
          :length_unit => DimensionUtils.length_unit,
      }

      # Ask for open file path
      path = @path.is_a?(String) ? @path : UI.openpanel(PLUGIN.get_i18n_string('tab.importer.csv.load.title'), '', "CSV|*.csv|TSV|*.tsv||")
      if path

        filename = File.basename(path)
        extname = File.extname(path)

        # Errors
        unless File.exist?(path)
          response[:errors] << [ 'tab.importer.default.error.file_not_found', { :filename => filename } ]
          return response
        end
        if extname.nil? || extname.downcase != '.csv' && extname.downcase != '.tsv'
          response[:errors] << [ 'tab.importer.default.error.bad_extension', { :filename => filename, :extensions => 'CSV, TSV' } ]
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