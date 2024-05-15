module Ladb::OpenCutList

  require 'singleton'
  require_relative 'model_observer'
  require_relative 'options_provider_observer'
  require_relative 'materials_observer'
  require_relative 'selection_observer'
  require_relative 'pages_observer'
  require_relative 'layers_observer'

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
      add_model_observers(model)

      # Clear model presets cache
      PLUGIN.clear_model_presets_cache

      # Fetch new length options
      DimensionUtils.instance.fetch_options

      # Fetch new mass options
      MassUtils.instance.fetch_mass_options

      # Fetch new currency options
      PriceUtils.instance.fetch_currency_options

      # Trigger event to JS
      PLUGIN.trigger_event(ON_NEW_MODEL, nil)

    end

    def onOpenModel(model)
      # puts "onOpenModel: #{model}"
      add_model_observers(model)

      # Clear model presets cache
      PLUGIN.clear_model_presets_cache

      # Fetch new length options
      DimensionUtils.instance.fetch_options

      # Fetch new mass options
      MassUtils.instance.fetch_mass_options

      # Fetch new currency options
      PriceUtils.instance.fetch_currency_options

      # Trigger event to JS
      PLUGIN.trigger_event(ON_OPEN_MODEL, { :name => model.name })

    end

    def onActivateModel(model)
      # puts "onActivateModel: #{model}"

      # Clear model presets cache
      PLUGIN.clear_model_presets_cache

      # Fetch new length options
      DimensionUtils.instance.fetch_options

      # Fetch new mass options
      MassUtils.instance.fetch_mass_options

      # Fetch new currency options
      PriceUtils.instance.fetch_currency_options

      # Trigger event to JS
      PLUGIN.trigger_event(ON_ACTIVATE_MODEL, { :name => model.name })

    end

    # -----

    def add_model_observers(model)
      if model
        model.add_observer(ModelObserver.instance)
        model.options['UnitsOptions'].add_observer(OptionsProviderObserver.instance) if model.options['UnitsOptions']
        model.materials.add_observer(MaterialsObserver.instance) if model.materials
        model.selection.add_observer(SelectionObserver.instance) if model.selection
        model.pages.add_observer(PagesObserver.instance) if model.pages
        model.layers.add_observer(LayersObserver.instance) if model.layers
      end
    end

    def remove_model_observers(model)
      if model
        model.remove_observer(ModelObserver.instance)
        model.options['UnitsOptions'].remove_observer(OptionsProviderObserver.instance) if model.options['UnitsOptions']
        model.materials.remove_observer(MaterialsObserver.instance) if model.materials
        model.selection.remove_observer(SelectionObserver.instance) if model.selection
        model.pages.remove_observer(PagesObserver.instance) if model.pages
        model.layers.remove_observer(LayersObserver.instance) if model.layers
      end
    end

  end

end