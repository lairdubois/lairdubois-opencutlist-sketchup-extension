module Ladb::OpenCutList

  require 'singleton'

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    include Singleton

    ON_OPTIONS_PROVIDER_CHANGED = 'on_options_provider_changed'.freeze

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"

      # Clear app default cache
      Plugin.instance.clear_app_defaults_cache if name == 'LengthUnit'

      # Fetch new length options
      DimensionUtils.instance.fetch_length_options if name == 'LengthUnit' || name == 'LengthPrecision' || name == 'LengthFormat'

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_OPTIONS_PROVIDER_CHANGED, { :name => name })

    end

  end

end