module Ladb::OpenCutList

  class OptionsProviderObserver < Sketchup::OptionsProviderObserver

    def onOptionsProviderChanged(provider, name)
      # puts "onOptionsProviderChanged: #{name}"
      Plugin.trigger_event('on_options_provider_changed', nil)
    end

  end

end