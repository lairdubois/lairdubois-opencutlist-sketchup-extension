module Ladb::OpenCutList

  require 'set'
  require_relative 'controller'

  class OutlinerController < Controller

    attr_reader :outliner

    def initialize()
      super('materials')

      @observed_model_guids = Set.new
      @observed_entities_guids = Set.new

      start_observing_model(Sketchup.active_model)

    end

    def setup_event_callbacks

      PLUGIN.add_event_callback([
                                  AppObserver::ON_NEW_MODEL,
                                  AppObserver::ON_OPEN_MODEL
                                ]) do |params|

        start_observing_model(Sketchup.active_model)

      end

      PLUGIN.add_event_callback([
                                  LayersObserver::ON_LAYER_ADDED,
                                  LayersObserver::ON_LAYER_REMOVED,
                                  LayersObserver::ON_LAYER_CHANGED,
                                  LayersObserver::ON_LAYERS_FOLDER_ADDED,
                                  LayersObserver::ON_LAYERS_FOLDER_CHANGED,
                                  LayersObserver::ON_LAYERS_FOLDER_REMOVED,
                                  LayersObserver::ON_REMOVE_ALL_LAYERS
                                ]) do |params|

        puts 'LAYER EVENT !'

        @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_available_layers)

        trigger_boo

      end

      PLUGIN.add_event_callback([
                                  MaterialsObserver::ON_MATERIAL_ADD,
                                  MaterialsObserver::ON_MATERIAL_REMOVE,
                                  MaterialsObserver::ON_MATERIAL_CHANGE
                                ]) do |params|

        @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_available_materials)

        trigger_boo

      end

    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("outliner_generate") do
        generate_command
      end
      PLUGIN.register_command("outliner_refresh") do
        refresh_command
      end
      PLUGIN.register_command("outliner_set_active") do |node_data|
        set_active_command(node_data)
      end
      PLUGIN.register_command("outliner_toggle_expanded") do |node_data|
        toggle_expanded_command(node_data)
      end
      PLUGIN.register_command("outliner_toggle_visible") do |node_data|
        toggle_visible_command(node_data)
      end
      PLUGIN.register_command("outliner_toggle_select") do |node_data|
        toggle_select_command(node_data)
      end
      PLUGIN.register_command("outliner_update") do |node_data|
        update_command(node_data)
      end
      PLUGIN.register_command("outliner_explode") do |node_data|
        explode_command(node_data)
      end

    end

    # -- Events --

    # Model Observer

    def onActivePathChanged(model)
      puts "onActivePathChanged: #{model}"

      @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_active_path)

      trigger_boo

    end

    # Selection Observer

    def onSelectionAdded(selection, entity)
      puts "onSelectionAdded: #{entity}"

      @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_selection)

      trigger_boo

    end

    def onSelectionRemoved(selection, entity)
      puts "onSelectionRemoved: #{entity}"

      @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_selection)

      trigger_boo

    end

    alias_method :onSelectedRemoved, :onSelectionRemoved

    def onSelectionBulkChange(selection)
      puts "onSelectionBulkChange: #{selection} - #{selection.model}"

      @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_selection)

      trigger_boo

    end

    def onSelectionCleared(selection)
      puts "onSelectionCleared: #{selection} - #{selection.model}"

      return if @outliner_def.selected_node_defs.empty?

      @outliner_def = OutlinerWorker.new(@outliner_def).run(:compute_selection)

      trigger_boo

    end

    # Entities Observer

    def onElementAdded(entities, entity)
      puts "onElementAdded: #{entity} - #{entities.model}"
      start_observing_entities(entity)
    end

    def onElementModified(entities, entity)
      puts "onElementModified: #{entity} - #{entities.model}"

      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Model)

        @outliner_def.get_node_defs_by_entity(entity).each { |node_def| node_def.clear_hashable }

        trigger_boo

      elsif entity.is_a?(Sketchup::ComponentDefinition)

        entity.instances.each do |instance|
          node_defs = @outliner_def.get_node_defs_by_entity(instance)
          node_defs.each { |node_def|
            node_def.clear_hashable
          }
        end

        trigger_boo

      end

    end

    def onElementRemoved(entities, entity_id)
      puts "onElementRemoved: #{entity_id} - #{entities.model}"

      trigger = false

      parent = entities.parent
      if entities.parent.is_a?(Sketchup::ComponentDefinition)
        parent_entities = parent.instances
      else
        parent_entities = [ parent ]
      end
      puts "### parent_entities = #{parent_entities}"
      parent_entities.each do |entity|
        node_defs = @outliner_def.get_node_defs_by_entity(entity)
        if node_defs
          trigger = true
          node_defs.each do |node_def|
            node_def.children.delete_if { |child_node_def| child_node_def.entity_id == entity_id }
            node_def.clear_hashable
          end
        end
      end

      trigger_boo if trigger

    end

    def trigger_boo
      puts "-- BOO --"
      PLUGIN.trigger_event('on_boo', nil)
    end

    private

    def start_observing_model(model)
      return if model.nil?
      return if @observed_model_guids.include?(model.guid)
      model.add_observer(self)
      model.selection.add_observer(self)
      @observed_model_guids.add(model.guid)
      start_observing_entities(model)
    end

    def stop_observing_model(model)
      return if model.nil?
      return unless @observed_model_guids.include?(model.guid)
      model.remove_observer(self)
      model.selection.remove_observer(self)
      @observed_model_guids.delete(model.guid)
      stop_observing_entities(model)
    end

    def start_observing_entities(parent)
      return if parent.is_a?(Sketchup::Entity) && parent.deleted?
      if parent.is_a?(Sketchup::Group) || parent.is_a?(Sketchup::Model)
        entities = parent.entities
      elsif parent.is_a?(Sketchup::ComponentInstance)
        entities = parent.definition.entities
      else
        return
      end
      return if @observed_entities_guids.include?(entities.parent.guid)
      entities.add_observer(self)
      @observed_entities_guids.add(entities.parent.guid)
      entities.each { |child_entity| start_observing_entities(child_entity) }
    end

    def stop_observing_entities(parent)
      return if parent.is_a?(Sketchup::Entity) && parent.deleted?
      if parent.is_a?(Sketchup::Group) || parent.is_a?(Sketchup::Model)
        entities = parent.entities
      elsif parent.is_a?(Sketchup::ComponentInstance)
        entities = parent.definition.entities
      else
        return
      end
      return unless @observed_entities_guids.include?(entities.parent.guid)
      entities.remove_observer(self)
      @observed_entities_guids.delete(entities.parent.guid)
      entities.each { |child_entity| stop_observing_entities(child_entity) }
    end

    # -- Commands --

    def generate_command
      require_relative '../worker/outliner/outliner_generate_worker'

      # Setup worker
      worker = OutlinerGenerateWorker.new

      # Run !
      @outliner_def = worker.run

      @outliner_def.create_hashable.to_hash
    end

    def refresh_command
      @outliner_def.create_hashable.to_hash
    end

    def set_active_command(node_data)
      require_relative '../worker/outliner/outliner_set_active_worker'

      # Setup worker
      worker = OutlinerSetActiveWorker.new(@outliner_def, **node_data)

      # Run !
      worker.run
    end

    def toggle_expanded_command(node_data)

      @outliner_def = OutlinerWorker.new(@outliner_def).run(:toggle_expanded, node_data)

      trigger_boo

    end

    def toggle_visible_command(node_data)
      require_relative '../worker/outliner/outliner_toggle_visible_worker'

      # Setup worker
      worker = OutlinerToggleVisibleWorker.new(@outliner_def, **node_data)

      # Run !
      worker.run
    end

    def toggle_select_command(node_data)
      require_relative '../worker/outliner/outliner_toggle_select_worker'

      # Setup worker
      worker = OutlinerToggleSelectWorker.new(@outliner_def, **node_data)

      # Run !
      worker.run
    end

    def update_command(node_data)
      require_relative '../worker/outliner/outliner_update_worker'

      # Setup worker
      worker = OutlinerUpdateWorker.new(@outliner_def, **node_data)

      # Run !
      worker.run
    end

    def explode_command(node_data)
      require_relative '../worker/outliner/outliner_explode_worker'

      # Setup worker
      worker = OutlinerExplodeWorker.new(@outliner_def, **node_data)

      # Run !
      worker.run
    end

  end

end