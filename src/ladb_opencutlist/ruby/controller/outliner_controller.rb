module Ladb::OpenCutList

  require_relative 'controller'

  class OutlinerController < Controller

    def initialize()
      super('materials')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.instance.register_command("outliner_generate") do |settings|
        generate_command(settings)
      end
      Plugin.instance.register_command("outliner_update") do |node_data|
        update_command(node_data)
      end
      Plugin.instance.register_command("outliner_set_active") do |node_data|
        set_active_command(node_data)
      end
      Plugin.instance.register_command("outliner_set_expanded") do |node_data|
        set_expanded_command(node_data)
      end
      Plugin.instance.register_command("outliner_toggle_visible") do |node_data|
        toggle_visible_command(node_data)
      end
      Plugin.instance.register_command("outliner_explode") do |node_data|
        explode_command(node_data)
      end

    end

    def setup_event_callbacks

      Plugin.instance.add_event_callback([
                                             AppObserver::ON_NEW_MODEL,
                                             AppObserver::ON_OPEN_MODEL,
                                             AppObserver::ON_ACTIVATE_MODEL,
                                             LayersObserver::ON_LAYER_CHANGED,
                                             LayersObserver::ON_LAYER_REMOVED,
                                             LayersObserver::ON_LAYERS_FOLDER_CHANGED,
                                             LayersObserver::ON_LAYERS_FOLDER_REMOVED,
                                             LayersObserver::ON_REMOVE_ALL_LAYERS,
                                             SelectionObserver::ON_SELECTION_BULK_CHANGE,
                                         ]) do |params|

        # Invalidate Cutlist if exists
        @outliner.invalidate if @outliner

      end

    end

    private

    # -- Commands --

    def generate_command(settings)
      require_relative '../worker/outliner/outliner_generate_worker'

      # Invalidate Outliner if it exists
      @outliner.invalidate if @outliner

      # Setup worker
      worker = OutlinerGenerateWorker.new(settings)

      # Run !
      @outliner = worker.run

      @outliner.to_hash
    end

    def update_command(node_data)
      require_relative '../worker/outliner/outliner_update_worker'

      # Setup worker
      worker = OutlinerUpdateWorker.new(node_data, @outliner)

      # Run !
      worker.run
    end

    def set_active_command(node_data)
      require_relative '../worker/outliner/outliner_set_active_worker'

      # Setup worker
      worker = OutlinerSetActiveWorker.new(node_data, @outliner)

      # Run !
      worker.run
    end

    def set_expanded_command(node_data)
      require_relative '../worker/outliner/outliner_set_expanded_worker'

      # Setup worker
      worker = OutlinerSetExpandedWorker.new(node_data, @outliner)

      # Run !
      worker.run
    end

    def toggle_visible_command(node_data)
      require_relative '../worker/outliner/outliner_toggle_visible_worker'

      # Setup worker
      worker = OutlinerToggleVisibleWorker.new(node_data, @outliner)

      # Run !
      worker.run
    end

    def explode_command(node_data)
      require_relative '../worker/outliner/outliner_explode_worker'

      # Setup worker
      worker = OutlinerExplodeWorker.new(node_data, @outliner)

      # Run !
      worker.run
    end

  end

end