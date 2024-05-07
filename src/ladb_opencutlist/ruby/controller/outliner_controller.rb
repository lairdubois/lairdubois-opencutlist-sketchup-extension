module Ladb::OpenCutList

  require_relative 'controller'

  class OutlinerController < Controller

    def initialize()
      super('materials')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      PLUGIN.register_command("outliner_generate") do
        generate_command
      end
      PLUGIN.register_command("outliner_get_selection") do
        get_selection_command
      end
      PLUGIN.register_command("outliner_update") do |node_data|
        update_command(node_data)
      end
      PLUGIN.register_command("outliner_set_active") do |node_data|
        set_active_command(node_data)
      end
      PLUGIN.register_command("outliner_get_active") do
        get_active_command
      end
      PLUGIN.register_command("outliner_set_expanded") do |node_data|
        set_expanded_command(node_data)
      end
      PLUGIN.register_command("outliner_set_visible") do |node_data|
        set_visible_command(node_data)
      end
      PLUGIN.register_command("outliner_select") do |node_data|
        select_command(node_data)
      end
      PLUGIN.register_command("outliner_explode") do |node_data|
        explode_command(node_data)
      end

    end

    def setup_event_callbacks

      PLUGIN.add_event_callback([
                                  AppObserver::ON_NEW_MODEL,
                                  AppObserver::ON_OPEN_MODEL,
                                  AppObserver::ON_ACTIVATE_MODEL,
                                  LayersObserver::ON_LAYER_CHANGED,
                                  LayersObserver::ON_LAYER_REMOVED,
                                  LayersObserver::ON_LAYERS_FOLDER_CHANGED,
                                  LayersObserver::ON_LAYERS_FOLDER_REMOVED,
                                  LayersObserver::ON_REMOVE_ALL_LAYERS,
                                ]) do |params|

        # Invalidate Cutlist if exists
        @outliner.invalidate if @outliner

      end

    end

    private

    # -- Commands --

    def generate_command
      require_relative '../worker/outliner/outliner_generate_worker'

      # Invalidate Outliner if it exists
      @outliner.invalidate if @outliner

      # Setup worker
      worker = OutlinerGenerateWorker.new

      # Run !
      @outliner = worker.run

      @outliner.to_hash
    end

    def get_selection_command
      require_relative '../worker/outliner/outliner_get_selection_worker'

      # Setup worker
      worker = OutlinerGetSelectionWorker.new(@outliner)

      # Run !
      worker.run
    end

    def update_command(node_data)
      require_relative '../worker/outliner/outliner_update_worker'

      # Setup worker
      worker = OutlinerUpdateWorker.new(@outliner, **node_data)

      # Run !
      worker.run
    end

    def set_active_command(node_data)
      require_relative '../worker/outliner/outliner_set_active_worker'

      # Setup worker
      worker = OutlinerSetActiveWorker.new(@outliner, **node_data)

      # Run !
      worker.run
    end

    def get_active_command
      require_relative '../worker/outliner/outliner_get_active_worker'

      # Setup worker
      worker = OutlinerGetActiveWorker.new(@outliner)

      # Run !
      worker.run
    end

    def set_expanded_command(node_data)
      require_relative '../worker/outliner/outliner_set_expanded_worker'

      # Setup worker
      worker = OutlinerSetExpandedWorker.new(@outliner, **node_data)

      # Run !
      worker.run
    end

    def set_visible_command(node_data)
      require_relative '../worker/outliner/outliner_set_visible_worker'

      # Setup worker
      worker = OutlinerSetVisibleWorker.new(@outliner, **node_data)

      # Run !
      worker.run
    end

    def select_command(node_data)
      require_relative '../worker/outliner/outliner_select_worker'

      # Setup worker
      worker = OutlinerSelectWorker.new(@outliner, **node_data)

      # Run !
      worker.run
    end

    def explode_command(node_data)
      require_relative '../worker/outliner/outliner_explode_worker'

      # Setup worker
      worker = OutlinerExplodeWorker.new(@outliner, **node_data)

      # Run !
      worker.run
    end

  end

end