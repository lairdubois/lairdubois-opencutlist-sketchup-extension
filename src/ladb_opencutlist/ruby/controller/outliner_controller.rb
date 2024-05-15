module Ladb::OpenCutList

  require 'set'
  require_relative 'controller'

  class OutlinerController < Controller

    attr_reader :outliner, :entities_observer, :entity_observer

    def initialize()
      super('materials')

      @entities_observer = OutlinerEntitiesObserver.new(self)

    end

    def setup_commands

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
                                  AppObserver::ON_OPEN_MODEL
                                ]) do |params|

        @entities_observer.add_entities_observers(Sketchup.active_model)

      end

      # PLUGIN.add_event_callback([
      #                             AppObserver::ON_NEW_MODEL,
      #                             AppObserver::ON_OPEN_MODEL,
      #                             AppObserver::ON_ACTIVATE_MODEL,
      #                             LayersObserver::ON_LAYER_CHANGED,
      #                             LayersObserver::ON_LAYER_REMOVED,
      #                             LayersObserver::ON_LAYERS_FOLDER_CHANGED,
      #                             LayersObserver::ON_LAYERS_FOLDER_REMOVED,
      #                             LayersObserver::ON_REMOVE_ALL_LAYERS,
      #                           ]) do |params|
      #
      #   # Invalidate Cutlist if exists
      #   @outliner.invalidate if @outliner
      #
      # end

      @entities_observer.add_entities_observers(Sketchup.active_model)

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
      require_relative '../worker/outliner/outliner_toggle_select_worker'

      # Setup worker
      worker = OutlinerToggleSelectWorker.new(@outliner, **node_data)

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

  class OutlinerEntitiesObserver < Sketchup::EntitiesObserver

    def initialize(controller)
      @controller = controller

      @event_stack = []
      @event_stack_timer = nil

      @observed_entity_ids = Set.new

    end

    def onElementAdded(entities, entity)
      return unless [ Sketchup::Face, Sketchup::Group, Sketchup::ComponentInstance, Sketchup::ComponentDefinition ].member?(entity.class)
      push_event("onElementAdded: #{entity.class} id=#{entity.entityID} in=#{get_entities_parents(entities)}")
      add_entities_observers(entity)
    end

    def onElementModified(entities, entity)
      return unless [ Sketchup::Face, Sketchup::Group, Sketchup::ComponentInstance, Sketchup::ComponentDefinition ].member?(entity.class)
      push_event("onElementModified: #{entity.class} id=#{entity.entityID} in=#{get_entities_parents(entities)}")
    end

    def onElementRemoved(entities, entity_id)
      push_event("onElementRemoved: id=#{entity_id} in=#{get_entities_parents(entities)}")
    end

    def get_entities_parents(entities)
      return [ entities.parent.class ] if entities.parent.is_a?(Sketchup::Model)
      return entities.parent.instances.map { |instance| instance.class } unless entities.parent.nil?
      []
    end

    # -----

    def push_event(event)
      @event_stack << event
      @event_stack_timer = UI.start_timer(0.1) { process_stack } if @event_stack_timer.nil?
    end

    def process_stack
      puts "--> Processing stack"
      UI.stop_timer(@event_stack_timer)
      @event_stack_timer = nil
      @event_stack.each do |event|
        puts event
      end
      @event_stack.clear

      # Trigger event to JS
      PLUGIN.trigger_event('on_boo', nil)

    end

    def add_entities_observers(entity)
      return if entity.is_a?(Sketchup::Entity) && entity.deleted?
      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::Model)
        entities = entity.entities
      elsif entity.is_a?(Sketchup::ComponentInstance)
        entities = entity.definition.entities
      else
        return
      end
      return if @observed_entity_ids.include?(entities.parent.entityID)
      entities.add_observer(self)
      @observed_entity_ids.add(entities.parent.entityID)
      entities.each { |child_entity| add_entities_observers(child_entity) }
    end

  end

end