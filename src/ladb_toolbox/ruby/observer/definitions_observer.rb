module Ladb
  module Toolbox
    class DefinitionsObserver < Sketchup::DefinitionsObserver

      @plugin

      def initialize(plugin)
        @plugin = plugin
      end

      def onComponentAdded(definitions, definition)
        # puts "onComponentAdded: #{definition.name}"
        @plugin.trigger_event('on_component_added', nil)
      end

    end
  end
end