module Ladb::OpenCutList

  require_relative '../../plugin'

  class ExportGlobalPresetsWorker

    def initialize
    end

    # -----

    def run

      path = UI.savepanel(Plugin.instance.get_i18n_string('tab.settings.presets.export_global_presets'), '', 'OpenCutListPresets.json')
      if path

        # Force "json" file extension
        unless path.end_with?('.json')
          path = path + '.json'
        end

        global_presets = Plugin.instance.get_global_presets

        # Write json file and wrap data with hexdigest for integrity control
        File.write(path, JSON.dump({
                                     :hexdigest => Digest::MD5.hexdigest(JSON.dump(global_presets)),
                                     :presets => global_presets
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