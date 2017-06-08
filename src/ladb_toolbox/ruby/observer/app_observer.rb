require_relative 'definitions_observer'
require_relative 'materials_observer'
require_relative 'selection_observer'

module Ladb
  module Toolbox
    class AppObserver < Sketchup::AppObserver

      @plugin
      @definitions_observer
      @materials_observer

      def initialize(plugin)
        @plugin = plugin
        @definitions_observer = DefinitionsObserver.new(plugin)
        @materials_observer = MaterialsObserver.new(plugin)
        @selection_observer = SelectionObserver.new(plugin)
        add_model_observers(Sketchup.active_model)
      end

      # -----

      def onNewModel(model)
        # puts "onNewModel: #{model}"
        @plugin.trigger_event('on_new_model', nil)
        add_model_observers(model)
      end

      def onOpenModel(model)
        # puts "onOpenModel: #{model}"
        @plugin.trigger_event('on_open_model', { :name => model.name })
        add_model_observers(model)
      end

      def onActivateModel(model)
        # puts "onActivateModel: #{model}"
        @plugin.trigger_event('on_activate_model', { :name => model.name })
      end

      # -----

      def remove_model_observers(model)
        if model
          # if model.definitions
          #   model.definitions.remove_observer(@definitions_observer)
          # end
          if model.materials
            model.materials.remove_observer(@materials_observer)
          end
          if model.selection
            model.selection.remove_observer(@selection_observer)
          end
        end
      end

      def add_model_observers(model)
        if model
          # if model.definitions
          #   model.definitions.add_observer(@definitions_observer)
          # end
          if model.materials
            model.materials.add_observer(@materials_observer)
          end
          if model.selection
            model.selection.add_observer(@selection_observer)
          end
        end
      end

    end
  end
end