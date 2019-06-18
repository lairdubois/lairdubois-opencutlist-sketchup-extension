module Ladb::OpenCutList

  require 'singleton'

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    include Singleton

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"
      Plugin.instance.trigger_event('on_options_provider_changed', nil)
      DimensionUtils.instance.fetch_length_options
    end

  end

end