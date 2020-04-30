module Ladb::OpenCutList

  require 'singleton'

  class SelectionObserver < Sketchup::SelectionObserver

    include Singleton

    ON_SELECTION_BULK_CHANGE = 'on_selection_bulk_change'.freeze
    ON_SELECTION_CLEARED = 'on_selection_cleared'.freeze

    def onSelectionBulkChange(selection)
      # puts "onSelectionBulkChange: #{selection}"
      Plugin.instance.trigger_event(ON_SELECTION_BULK_CHANGE, nil)
    end

    def onSelectionCleared(selection)
      # puts "onSelectionCleared: #{selection}"
      Plugin.instance.trigger_event(ON_SELECTION_CLEARED, nil)
    end

  end

end