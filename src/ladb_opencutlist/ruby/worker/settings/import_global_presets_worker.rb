module Ladb::OpenCutList

  require_relative '../../plugin'

  class ImportGlobalPresetsWorker

    def initialize
    end

    # -----

    def run

      # Open panel
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.settings.presets.import_global_presets'))
      if path

        begin

          # Read file
          file = File.read(path)

          # Parse JSON
          data = JSON.parse(file)

          # Check data integrity
          if data.is_a?(Hash) && data.has_key?('hexdigest') && data.has_key?('presets')

            if data['hexdigest'] == Digest::MD5.hexdigest(JSON.dump(data['presets']))

              data['presets'].each do |dictionary, dh|
                if dh.is_a?(Hash)
                  dh.each do |section, sh|
                    if sh.is_a?(Hash)
                      sh.each do |name, values|
                        Plugin.instance.set_global_preset(dictionary, values, name, section)
                      end
                    end
                  end
                end
              end

              return {
                :success => true
              }
            else
              return {
                :errors => [ 'tab.settings.presets.error.failed_to_import_invalid_hexdigest' ]
              }
            end

          else
            return {
              :errors => [ 'tab.settings.presets.error.failed_to_import_bad_file_format' ]
            }
          end

        rescue => e
          return {
            :errors => [ [ 'tab.settings.presets.error.failed_to_import', { :error => e.class } ] ]
          }
        end

      end

      {
        :cancelled => true
      }
    end

  end

end