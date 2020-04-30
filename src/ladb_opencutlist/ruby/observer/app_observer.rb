module Ladb::OpenCutList

  require 'singleton'
  require_relative 'options_provider_observer'
  require_relative 'materials_observer'
  require_relative 'selection_observer'

  class AppObserver < Sketchup::AppObserver

    include Singleton

    ON_NEW_MODEL = 'on_new_model'.freeze
    ON_OPEN_MODEL = 'on_open_model'.freeze
    ON_ACTIVATE_MODEL = 'on_activate_model'.freeze

    def initialize()
      add_model_observers(Sketchup.active_model)
    end

    # -----

    def onNewModel(model)
      # puts "onNewModel: #{model}"
      Plugin.instance.trigger_event(ON_NEW_MODEL, nil)
      DimensionUtils.instance.fetch_length_options
      add_model_observers(model)
    end

    def onOpenModel(model)
      # puts "onOpenModel: #{model}"
      Plugin.instance.trigger_event(ON_OPEN_MODEL, { :name => model.name })
      DimensionUtils.instance.fetch_length_options
      add_model_observers(model)
    end

    def onActivateModel(model)
      # puts "onActivateModel: #{model}"
      Plugin.instance.trigger_event(ON_ACTIVATE_MODEL, { :name => model.name })
      DimensionUtils.instance.fetch_length_options
    end

    # -----

    def add_model_observers(model)
      if model
        # if model.definitions
        #   model.definitions.add_observer(@definitions_observer)
        # end
        if model.options['UnitsOptions']
          model.options['UnitsOptions'].add_observer(OptionsProviderObserver.instance)
        end
        if model.materials
          model.materials.add_observer(MaterialsObserver.instance)
        end
        if model.selection
          model.selection.add_observer(SelectionObserver.instance)
        end
      end
    end

    def remove_model_observers(model)
      if model
        # if model.definitions
        #   model.definitions.remove_observer(@definitions_observer)
        # end
        if model.options['UnitsOptions']
          model.options['UnitsOptions'].remove_observer(OptionsProviderObserver.instance)
        end
        if model.materials
          model.materials.remove_observer(MaterialsObserver.instance)
        end
        if model.selection
          model.selection.remove_observer(SelectionObserver.instance)
        end
      end
    end

  end

end