module Ladb::OpenCutList

  class SelectionObserver < Sketchup::SelectionObserver

    def onSelectionBulkChange(selection)
      # puts "onSelectionBulkChange: #{selection}"
      Plugin.trigger_event('on_selection_bulk_change', nil)
    end

    def onSelectionCleared(selection)
      # puts "onSelectionCleared: #{selection}"
      Plugin.trigger_event('on_selection_cleared', nil)
    end

  end

end