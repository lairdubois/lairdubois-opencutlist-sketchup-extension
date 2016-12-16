module Ladb
  module Toolbox
    class DefinitionsObserver < Sketchup::DefinitionsObserver

      @plugin

      def initialize(plugin)
        @plugin = plugin
      end

      def onComponentAdded(definitions, definition)
        puts "onComponentAdded: #{definition.name}"
      end

    end
  end
end