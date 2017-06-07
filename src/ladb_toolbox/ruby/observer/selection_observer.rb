module Ladb
  module Toolbox
    class SelectionObserver < Sketchup::SelectionObserver

      @plugin

      def initialize(plugin)
        @plugin = plugin
      end

      def onSelectionBulkChange(selection)
        # puts "onSelectionBulkChange: #{selection}"
        @plugin.trigger_event('on_selection_bulk_change', nil)
      end

      def onSelectionCleared(selection)
        # puts "onSelectionCleared: #{selection}"
        @plugin.trigger_event('on_selection_cleared', nil)
      end

    end
  end
end