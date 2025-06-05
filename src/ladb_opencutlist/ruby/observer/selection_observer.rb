module Ladb::OpenCutList

  class SelectionObserver < Sketchup::SelectionObserver

    ON_SELECTION_BULK_CHANGE = 'on_selection_bulk_change'.freeze
    ON_SELECTION_CLEARED = 'on_selection_cleared'.freeze

    def onSelectionBulkChange(selection)
      # puts "onSelectionBulkChange: #{selection}"

      # Trigger event to JS
      PLUGIN.trigger_event(ON_SELECTION_BULK_CHANGE, nil)

    end

    def onSelectionCleared(selection)
      # puts "onSelectionCleared: #{selection}"

      # Trigger event to JS
      PLUGIN.trigger_event(ON_SELECTION_CLEARED, nil)

    end

  end

end