module Ladb::OpenCutList

  require_relative '../../plugin'

  class ExportGlobalPresetsWorker

    def initialize(settings)

      @paths_filter = settings.fetch('paths_filter')

    end

    # -----

    def run

      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.settings.presets.export_global_presets'), '', 'OpenCutListPresets.json')
      if path

        # Force "json" file extension
        unless path.end_with?('.json')
          path = path + '.json'
        end

        # Filter global presets
        filtred_presets = {}
        global_presets = Plugin.instance.get_global_presets
        global_presets.each do |dictionary, dh|
          dh.each do |section, sh|
            sh.each do |name, values|
              if @paths_filter.include?("#{dictionary}|#{section}|#{name}")
                filtred_presets[dictionary] = {} unless filtred_presets[dictionary]
                filtred_presets[dictionary][section] = {} unless filtred_presets[dictionary][section]
                filtred_presets[dictionary][section][name] = values
              end
            end
          end
        end

        # Write json file and wrap data with hexdigest for integrity control
        File.write(path, JSON.dump({
                                     :hexdigest => Digest::MD5.hexdigest(JSON.dump(filtred_presets)),
                                     :presets => filtred_presets
                                   }))

        return {
          :success => true
        }
      end

      {
        :cancelled => true
      }
    end

  end

end