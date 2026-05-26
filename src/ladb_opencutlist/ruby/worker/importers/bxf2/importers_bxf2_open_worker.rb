module Ladb::OpenCutList

  class ImportersBxf2OpenWorker

        def initialize(

                   path: nil

    )

      @path = path

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.importers.default.error.no_model' ] } unless model

      response = {
          :errors => [],
          :length_unit => DimensionUtils.length_unit,
      }

      # Ask for open file path
      path = @path.is_a?(String) ? @path : UI.openpanel(PLUGIN.get_i18n_string('tab.importers.bxf2.load.title'), '', "BXF2|*.bxf2||")
      if path

        filename = File.basename(path)
        extname = File.extname(path)

        # Errors
        unless File.exist?(path)
          response[:errors] << [ 'tab.importers.default.error.file_not_found', { :filename => filename } ]
          return response
        end
        if extname.nil? || (extname.downcase != '.bxf2' && extname.downcase != '.zip')
          response[:errors] << [ 'tab.importers.default.error.bad_extension', { :filename => filename, :extensions => 'BXF2' } ]
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