module Ladb::OpenCutList

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    ON_OPTIONS_PROVIDER_CHANGED = 'on_options_provider_changed'.freeze

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"

      # Clear app default cache
      PLUGIN.clear_app_defaults_cache if name == 'LengthUnit'

      # Fetch new length, area, volume options
      DimensionUtils.fetch_options if name == 'LengthUnit' || name == 'LengthPrecision' || name == 'LengthFormat' || name == 'AreaUnit' || name == 'AreaPrecision' || name == 'VolumeUnit' || name == 'VolumePrecision'

      # Trigger event to JS
      PLUGIN.trigger_event(ON_OPTIONS_PROVIDER_CHANGED, { :name => name })

    end

  end

end