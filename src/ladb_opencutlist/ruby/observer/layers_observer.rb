module Ladb::OpenCutList

  require 'singleton'

  class LayersObserver < Sketchup::SelectionObserver

    include Singleton

    ON_LAYER_CHANGED = 'on_layer_changed'.freeze
    ON_LAYER_REMOVED = 'on_layer_removed'.freeze
    ON_LAYERS_FOLDER_CHANGED = 'on_layers_folder_changed'.freeze
    ON_LAYERS_FOLDER_REMOVED = 'on_layers_folder_removed'.freeze
    ON_REMOVE_ALL_LAYERS = 'on_remove_all_layers'.freeze

    def onLayerChanged(layers, layer)
      # puts "onLayerChanged: #{layer.name}"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_LAYER_CHANGED, nil)

    end

    def onLayerRemoved(layers, layer)
      # puts "onLayerRemoved"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_LAYER_REMOVED, nil)

    end

    def onLayerFolderChanged(layers, layer_folder)
      # puts "onLayerFolderChanged: #{layer_folder.name}"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_LAYERS_FOLDER_CHANGED, nil)

    end

    def onLayerFolderRemoved(layers, layer_folder)
      # puts "onLayerFolderRemoved"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_LAYERS_FOLDER_REMOVED, nil)

    end

    def onRemoveAllLayers(layers)
      # puts "onRemoveAllLayers: #{layers}"

      # Trigger event to JS
      Plugin.instance.trigger_event(ON_REMOVE_ALL_LAYERS, nil)

    end

  end

end