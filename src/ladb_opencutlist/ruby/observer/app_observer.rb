module Ladb::OpenCutList

  require_relative 'model_observer'
  require_relative 'options_provider_observer'
  require_relative 'materials_observer'
  require_relative 'selection_observer'
  require_relative 'pages_observer'

  class AppObserver < Sketchup::AppObserver

    ON_NEW_MODEL = 'on_new_model'.freeze
    ON_OPEN_MODEL = 'on_open_model'.freeze
    ON_ACTIVATE_MODEL = 'on_activate_model'.freeze
    ON_QUIT = 'on_quit'.freeze

    def initialize
      unless (model = Sketchup.active_model).nil?
        add_model_observers(model)
        onActivateModel(model)
      end
    end

    def model_observer
      @model_observer ||= ModelObserver.new
    end

    def options_provider_observer
      @options_provider_observer ||= OptionsProviderObserver.new
    end

    def materials_observer
      @materials_observer ||= MaterialsObserver.new
    end

    def selection_observer
      @selection_observer ||= SelectionObserver.new
    end

    def pages_observer
      @pages_observer ||= PagesObserver.new
    end

    # -----

    def onNewModel(model)
      # puts "onNewModel: #{model}"
      add_model_observers(model)

      # Clear model presets cache
      PLUGIN.clear_model_presets_cache

      # Fetch new length options
      DimensionUtils.fetch_options

      # Fetch new mass options
      MassUtils.fetch_mass_options

      # Fetch new currency options
      PriceUtils.fetch_currency_options

      # Trigger event to JS
      PLUGIN.trigger_event(ON_NEW_MODEL, nil)

    end

    def onOpenModel(model)
      # puts "onOpenModel: #{model}"
      add_model_observers(model)

      # Clear model presets cache
      PLUGIN.clear_model_presets_cache

      # Fetch new length options
      DimensionUtils.fetch_options

      # Fetch new mass options
      MassUtils.fetch_mass_options

      # Fetch new currency options
      PriceUtils.fetch_currency_options

      # Trigger event to JS
      PLUGIN.trigger_event(ON_OPEN_MODEL, { :name => model.name })

    end

    def onActivateModel(model)
      # puts "onActivateModel: #{model}"

      # Clear model presets cache
      PLUGIN.clear_model_presets_cache

      # Fetch new length options
      DimensionUtils.fetch_options

      # Fetch new mass options
      MassUtils.fetch_mass_options

      # Fetch new currency options
      PriceUtils.fetch_currency_options

      # Trigger event to JS
      PLUGIN.trigger_event(ON_ACTIVATE_MODEL, { :name => model.name })

    end

    def onQuit

      # Trigger event to JS
      PLUGIN.trigger_event(ON_QUIT)

    end

    # -----

    def add_model_observers(model)
      if model
        model.add_observer(model_observer)
        model.options['UnitsOptions'].add_observer(options_provider_observer) if model.options['UnitsOptions']
        model.materials.add_observer(materials_observer) if model.materials
        model.selection.add_observer(selection_observer) if model.selection
        model.pages.add_observer(pages_observer) if model.pages
      end
    end

    def remove_model_observers(model)
      if model
        model.remove_observer(model_observer)
        model.options['UnitsOptions'].remove_observer(options_provider_observer) if model.options['UnitsOptions']
        model.materials.remove_observer(materials_observer) if model.materials
        model.selection.remove_observer(selection_observer) if model.selection
        model.pages.remove_observer(pages_observer) if model.pages
      end
    end

  end

end