module Ladb
  module Toolbox
    class OptionsProviderObserver < Sketchup::OptionsProviderObserver

      @plugin

      def initialize(plugin)
        @plugin = plugin
      end

      def onOptionsProviderChanged(provider, name)
        # puts "onOptionsProviderChanged: #{name}"
        @plugin.trigger_event('on_options_provider_changed', nil)
      end

    end
  end
end