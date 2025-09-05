module Ladb::OpenCutList

  require_relative '../plugin'

  class SettingsController < Controller

    def initialize()
      super('settings')
    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("settings_dialog_settings") do |settings|
        dialog_settings_command(**settings)
      end
      PLUGIN.register_command("settings_dialog_inc_size") do |params|
        dialog_inc_size_command(**params)
      end
      PLUGIN.register_command("settings_dialog_reset_position") do |params|
        dialog_reset_position_command
      end
      PLUGIN.register_command("settings_dialog_inc_position") do |params|
        dialog_inc_position_command(**params)
      end
      PLUGIN.register_command('settings_set_length_settings') do |params|
        set_length_settings_command(**params)
      end
      PLUGIN.register_command('settings_get_length_settings') do |params|
        get_length_settings_command
      end
      PLUGIN.register_command('settings_dump_global_presets') do |params|
        dump_global_presets_command
      end
      PLUGIN.register_command('settings_dump_model_presets') do |params|
        dump_model_presets_command
      end
      PLUGIN.register_command('settings_reset_global_presets') do |params|
        reset_global_presets_command
      end
      PLUGIN.register_command('settings_reset_model_presets') do |params|
        reset_model_presets_command
      end
      PLUGIN.register_command('settings_get_global_presets') do |params|
        get_global_presets_command
      end
      PLUGIN.register_command('settings_export_global_presets_to_json') do |settings|
        export_global_presets_to_json_command(settings)
      end
      PLUGIN.register_command('settings_load_global_presets_from_json') do |params|
        load_global_presets_from_json_command
      end

    end

    private

    # -- Commands --

    def dialog_settings_command(language: nil, zoom: , print_margin: Plugin::TABS_DIALOG_DEFAULT_PRINT_MARGIN, table_row_size: Plugin::TABS_DIALOG_DEFAULT_TABLE_ROW_SIZE)
      PLUGIN.set_language(language, true)
      PLUGIN.tabs_dialog_set_zoom(zoom, true)
      PLUGIN.tabs_dialog_set_print_margin(print_margin, true)
      PLUGIN.tabs_dialog_set_table_row_size(table_row_size, true)
    end

    def dialog_inc_size_command(inc_width: 0, inc_height: 0)
      PLUGIN.tabs_dialog_inc_maximized_size(inc_width, inc_height)
    end

    def dialog_inc_position_command(inc_left: 0, inc_top: 0)
      PLUGIN.tabs_dialog_inc_position(inc_left, inc_top)
    end

    def dialog_reset_position_command
      PLUGIN.tabs_dialog_reset_position
    end

    def set_length_settings_command(length_unit: nil, length_format: nil, length_precision: nil, suppress_units_display: nil)
      unless length_format.nil?
        case length_format
        when DimensionUtils::FRACTIONAL, DimensionUtils::ARCHITECTURAL
          length_unit = DimensionUtils::INCHES
        when DimensionUtils::ENGINEERING
          length_unit = DimensionUtils::FEET
        end
      end

      model = Sketchup.active_model
      if model
        model.options['UnitsOptions']['LengthUnit'] = length_unit unless length_unit.nil?
        model.options['UnitsOptions']['LengthFormat'] = length_format unless length_format.nil?
        model.options['UnitsOptions']['LengthPrecision'] = length_precision unless length_precision.nil?
        model.options['UnitsOptions']['SuppressUnitsDisplay'] = suppress_units_display unless suppress_units_display.nil?
      end

      get_length_settings_command
    end

    def get_length_settings_command
      model = Sketchup.active_model

      return { :errors => [ 'default.error' ] } unless model

      length_format = model.options['UnitsOptions']['LengthFormat']
      {
          :length_unit => model.options['UnitsOptions']['LengthUnit'],
          :length_unit_disabled => length_format == DimensionUtils::FRACTIONAL || length_format == DimensionUtils::ARCHITECTURAL || length_format == DimensionUtils::ENGINEERING,
          :length_format => model.options['UnitsOptions']['LengthFormat'],
          :length_precision => model.options['UnitsOptions']['LengthPrecision'],
          :suppress_units_display => model.options['UnitsOptions']['SuppressUnitsDisplay'],
          :suppress_units_display_disabled => length_format == DimensionUtils::ARCHITECTURAL || length_format == DimensionUtils::ENGINEERING,
      }
    end

    def dump_global_presets_command
      SKETCHUP_CONSOLE.show
      PLUGIN.dump_global_presets
    end

    def dump_model_presets_command
      SKETCHUP_CONSOLE.show
      PLUGIN.dump_model_presets
    end

    def reset_global_presets_command
      PLUGIN.reset_global_presets
    end

    def reset_model_presets_command
      PLUGIN.reset_model_presets
    end

    def get_global_presets_command
      PLUGIN.get_global_presets
    end

    def export_global_presets_to_json_command(settings)
      require_relative '../worker/settings/export_global_presets_worker'

      # Setup worker
      worker = ExportGlobalPresetsWorker.new(**settings)

      # Run !
      worker.run
    end

    def load_global_presets_from_json_command
      require_relative '../worker/settings/load_global_presets_worker'

      # Setup worker
      worker = LoadGlobalPresetsWorker.new

      # Run !
      worker.run
    end

  end

end
