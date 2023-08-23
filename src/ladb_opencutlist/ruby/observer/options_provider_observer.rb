module Ladb::OpenCutList

  require 'singleton'

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    include Singleton

    ON_OPTIONS_PROVIDER_CHANGED = 'on_options_provider_changed'.freeze

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"

      # Clear app default cache
      Plugin.instance.clear_app_defaults_cache if name == 'LengthUnit'

      # Fetch new length, area, volume options
      DimensionUtils.instance.fetch_options if name == 'LengthUnit' || name == 'LengthPrecision' || name == 'LengthFormat' || name == 'AreaUnit' || name == 'AreaPrecision' || name == 'VolumeUnit' || name == 'VolumePrecision'

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_OPTIONS_PROVIDER_CHANGED, { :name => name })

    end

  end

end