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
      Plugin.instance.register_command('settings_set_length_settings') do |params|
        set_length_settings_command(params)
      end
      Plugin.instance.register_command('settings_get_length_settings') do |params|
        get_length_settings_command
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

    def set_length_settings_command(params)
      length_unit = params['length_unit']
      length_format = params['length_format']
      length_precision = params['length_precision']
      suppress_units_display = params['suppress_units_display']

      model = Sketchup.active_model
      if model
        model.options['UnitsOptions']['LengthUnit'] = length_unit unless length_unit.nil?
        model.options['UnitsOptions']['LengthFormat'] = length_format unless length_format.nil?
        model.options['UnitsOptions']['LengthPrecision'] = length_precision unless length_precision.nil?
        model.options['UnitsOptions']['SuppressUnitsDisplay'] = suppress_units_display unless suppress_units_display.nil?
      end

    end

    def get_length_settings_command
      model = Sketchup.active_model
      {
          :length_unit => model ? model.options['UnitsOptions']['LengthUnit'] : INCHES,
          :length_format => model ? model.options['UnitsOptions']['LengthFormat'] : Length::DECIMAL,
          :length_precision => model ? model.options['UnitsOptions']['LengthPrecision'] : 0,
          :suppress_units_display => model ? model.options['UnitsOptions']['SuppressUnitsDisplay'] : false,
      }
    end

  end

end