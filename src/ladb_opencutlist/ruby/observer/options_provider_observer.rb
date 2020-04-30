module Ladb::OpenCutList

  require 'singleton'

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    include Singleton

    ON_OPTIONS_PROVIDER_CHANGED = 'on_options_provider_changed'.freeze

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"
      Plugin.instance.trigger_event(ON_OPTIONS_PROVIDER_CHANGED, nil)
      DimensionUtils.instance.fetch_length_options
    end

  end

end