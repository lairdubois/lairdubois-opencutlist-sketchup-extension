module Ladb::OpenCutList

  require_relative '../../plugin'

  class LoadGlobalPresetsWorker

    def initialize
    end

    # -----

    def run

      # Open panel
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.settings.presets.import_global_presets'), '', 'OpenCutListPresets.json')
      if path

        begin

          # Read file
          file = File.read(path)

          # Parse JSON
          data = JSON.parse(file)

          # Check data integrity
          if data.is_a?(Hash) && data.has_key?('hexdigest') && data.has_key?('presets')

            if data['hexdigest'] == Digest::MD5.hexdigest(JSON.dump(data['presets']))

              # TODO cleanup obsolete dectionary ?

              return data['presets']
            else
              return { :errors => [ 'tab.settings.presets.error.failed_to_import_invalid_hexdigest' ] }
            end

          else
            return { :errors => [ 'tab.settings.presets.error.failed_to_import_bad_file_format' ] }
          end

        rescue => e
          return { :errors => [ [ 'tab.settings.presets.error.failed_to_import', { :error => e.class } ] ] }
        end

      end

      {
        :cancelled => true
      }
    end

  end

end