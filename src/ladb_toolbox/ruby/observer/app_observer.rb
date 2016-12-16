require_relative 'definitions_observer'
require_relative 'materials_observer'

module Ladb
  module Toolbox
    class AppObserver < Sketchup::AppObserver

      @plugin
      @active_model
      @definitions_observer
      @materials_observer

      def initialize(plugin)
        @plugin = plugin
        @active_model = Sketchup.active_model
        @definitions_observer = DefinitionsObserver.new(plugin)
        @materials_observer = MaterialsObserver.new(plugin)
        add_model_observers
      end

      # -----

      def onNewModel(model)
        puts "onNewModel: #{model}"
        remove_model_observers
        @active_model = model
        add_model_observers
      end

      def onOpenModel(model)
        puts "onOpenModel: #{model}"
        remove_model_observers
        @active_model = model
        add_model_observers
      end

      def onActivateModel(model)
        puts "onActivateModel: #{model}"
        remove_model_observers
        @active_model = model
        add_model_observers
      end

      # -----

      def remove_model_observers
        if @active_model
          @active_model.definitions.remove_observer(@definitions_observer)
          @active_model.materials.remove_observer(@materials_observer)
        end
      end

      def add_model_observers
        if @active_model
          @active_model.definitions.add_observer(@definitions_observer)
          @active_model.materials.add_observer(@materials_observer)
        end
      end

    end
  end
end