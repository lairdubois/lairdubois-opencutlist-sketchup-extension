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
      Plugin.instance.register_command('settings_set_length_unit') do |params|
        set_length_unit_command(params)
      end
      Plugin.instance.register_command('settings_get_length_unit') do |params|
        get_length_unit_command
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
      zoom = settings['zoom']

      Plugin.instance.set_language(language, true)
      Plugin.instance.dialog_set_size(width, height, true)
      Plugin.instance.dialog_set_position(left, top, true)
      Plugin.instance.dialog_set_zoom(zoom, true)

    end

    def set_length_unit_command(params)
      length_unit = params['length_unit'].to_i

      model = Sketchup.active_model
      model.options['UnitsOptions']['LengthUnit'] = length_unit if model

    end

    def get_length_unit_command
      model = Sketchup.active_model
      {
          :length_unit => model ? model.options['UnitsOptions']['LengthUnit'] : INCHES
      }
    end

  end

end