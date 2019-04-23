module Ladb::OpenCutList

  class SettingsController < Controller

    def initialize()
      super('settings')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("settings_dialog_settings") do |settings|
        dialog_settings_command(settings)
      end

    end

    private

    # -- Commands --

    def dialog_settings_command(settings)

      # Check settings
      language = settings['language']
      width = settings['width']
      height = settings['height']
      top = settings['top']
      left = settings['left']

      Plugin.instance.set_language(language, true)
      Plugin.instance.dialog_set_size(width, height, true)
      Plugin.instance.dialog_set_position(left, top, true)

    end

  end

end