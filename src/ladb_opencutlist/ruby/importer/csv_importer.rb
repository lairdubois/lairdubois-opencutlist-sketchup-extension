module Ladb::OpenCutList

  require_relative '../plugin'

  class CsvImporter < Sketchup::Importer

    def description
      "OpenCutList CSV (*.csv)"
    end

    def file_extension
      "csv"
    end

    def id
      "fr.lairdubois.opencutlist.importers.csv"
    end

    def supports_options?
      false
    end

    def load_file(file_path, status)
      PLUGIN.execute_tabs_dialog_command_on_tab('importer', 'load', { path: file_path }.to_json)
      Sketchup::Importer::ImportSuccess
    end

  end

end
