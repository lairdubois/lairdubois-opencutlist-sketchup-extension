module Ladb::OpenCutList

  class DefinitionsObserver < Sketchup::DefinitionsObserver

    def onComponentAdded(definitions, definition)
      # puts "onComponentAdded: #{definition.name}"
      Plugin.trigger_event('on_component_added', nil)
    end

  end

end