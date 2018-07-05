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
      width = settings['width']
      height = settings['height']
      top = settings['top']
      left = settings['left']

      Plugin.instance.dialog_set_size([ width, 300 ].max, [ height, 300 ].max, true)
      Plugin.instance.dialog_set_position([ left, 0 ].max, [ top, 0 ].max, true)

    end

  end

end