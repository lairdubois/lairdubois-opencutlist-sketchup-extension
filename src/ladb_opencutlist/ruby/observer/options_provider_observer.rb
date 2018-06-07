module Ladb::OpenCutList

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"
      Plugin.instance.trigger_event('on_options_provider_changed', nil)
      DimensionUtils.instance.fetch_length_options
    end

  end

end