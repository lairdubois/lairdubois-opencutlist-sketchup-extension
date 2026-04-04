module Ladb::OpenCutList

  class Bxf2Importer < Sketchup::Importer

    def description
      "OpenCutList BXF2 (*.bxf2)"
    end

    def file_extension
      "bxf2"
    end

    def id
      "fr.lairdubois.opencutlist.importers.bxf2"
    end

    def supports_options?
      false
    end

    def load_file(file_path, status)
      PLUGIN.execute_tabs_dialog_command_on_tab('importers_bxf2', 'load', { path: file_path }.to_json)
      Sketchup::Importer::ImportSuccess
    end

end

end
