module Ladb::OpenCutList

  require 'set'
  require_relative 'controller'
  require_relative '../worker/outliner/outliner_worker'

  class OutlinerController < Controller

    def initialize
      super('materials')

      @observed_model_ids = Set.new
      @observed_entities_ids = Set.new

      @observing = false

      @overlay = nil

    end

    def setup_event_callbacks

      PLUGIN.add_event_callback([
                                  AppObserver::ON_NEW_MODEL,
                                  AppObserver::ON_OPEN_MODEL,
                                  AppObserver::ON_ACTIVATE_MODEL
                                ]) do |params|

        start_observing_model(Sketchup.active_model) if @observing

      end

      PLUGIN.add_event_callback([
                                  'on_tabs_dialog_close'
                                ]) do |params|

        stop_observing_command if @observing

      end

    end

    def setup_commands

      # Setup opencutlist dialog actions
      PLUGIN.register_command("outliner_start_observing") do
        start_observing_command
      end
      PLUGIN.register_command("outliner_stop_observing") do
        stop_observing_command
      end
      PLUGIN.register_command("outliner_generate") do |params|
        generate_command(params)
      end
      PLUGIN.register_command("outliner_refresh") do
        refresh_command
      end
      PLUGIN.register_command("outliner_set_active") do |params|
        set_active_command(params)
      end
      PLUGIN.register_command("outliner_toggle_expanded") do |params|
        toggle_expanded_command(params)
      end
      PLUGIN.register_command("outliner_toggle_visible") do |params|
        toggle_visible_command(params)
      end
      PLUGIN.register_command("outliner_toggle_select") do |params|
        toggle_select_command(params)
      end
      PLUGIN.register_command("outliner_toggle_select_all") do
        toggle_select_all_command
      end
      PLUGIN.register_command("outliner_invert_select") do
        invert_select_command
      end
      PLUGIN.register_command("outliner_edit") do |params|
        edit_command(params)
      end
      PLUGIN.register_command("outliner_update") do |params|
        update_command(params)
      end
      PLUGIN.register_command("outliner_explode") do |params|
        explode_command(params)
      end
      PLUGIN.register_command("outliner_highlight") do |params|
        highlight_command(params)
      end

    end

    # -- Events --

    # Model Observer

    def onActivePathChanged(model)
      # puts "onActivePathChanged: #{model}"

      return unless @worker

      # Remove previously added overlay
      model.overlays.remove(@overlay) if @overlay && @overlay.valid?

      @worker.run(:compute_active_path)

      trigger_boo

    end

    # Selection Observer

    def onSelectionAdded(selection, entity)
      # puts "onSelectionAdded: #{entity}"

      return unless @worker

      @worker.run(:compute_selection)

      trigger_boo

    end

    def onSelectionRemoved(selection, entity)
      # puts "onSelectionRemoved: #{entity}"

      return unless @worker

      @worker.run(:compute_selection)

      trigger_boo

    end

    alias_method :onSelectedRemoved, :onSelectionRemoved

    def onSelectionAdded(selection, entity)
      # puts "onSelectionAdded: #{selection}, #{entity}"

      return unless @worker

      @worker.run(:compute_selection)

      trigger_boo

    end

    def onSelectionRemoved(selection, entity)
      # puts "onSelectionRemoved: #{selection}, #{entity}"

      return unless @worker

      @worker.run(:compute_selection)

      trigger_boo

    end

    def onSelectionBulkChange(selection)
      # puts "onSelectionBulkChange: #{selection}"

      return unless @worker

      @worker.run(:compute_selection)

      trigger_boo

    end

    def onSelectionCleared(selection)
      # puts "onSelectionCleared: #{selection}"

      return unless @worker
      return if @outliner_def.selected_node_defs.empty?

      @worker.run(:compute_selection)

      trigger_boo

    end

    # Materials Observer

    def onMaterialAdd(materials, material)
      # puts "onMaterialAdd: #{material}"

      return unless @worker

      @worker.run(:compute_available_materials)

      trigger_boo

    end

    def onMaterialChange(materials, material)
      # puts "onMaterialChange: #{material}"

      return unless @worker

      material_def = @outliner_def.get_material_def(material)
      if material_def

        material_def.fill
        material_def.invalidate
        material_def.each_used_by { |node_def| node_def.invalidate }

        trigger_boo

      end

    end

    def onMaterialRemove(materials, material)
      # puts "onMaterialRemove: #{material}"

      return unless @worker

      @worker.run(:compute_available_materials)

      trigger_boo

    end

    # Layers Observer

    def onLayerAdded(layers, layer)
      # puts "onLayerAdded #{layer.name}"

      return unless @worker

      @worker.run(:compute_available_layers)

      trigger_boo

    end

    def onLayerChanged(layers, layer)
      # puts "onLayerChanged: #{layer.name}"

      return unless @worker

      layer_def = @outliner_def.get_layer_def(layer)
      if layer_def

        layer_def.fill
        layer_def.invalidate
        layer_def.each_used_by do |node_def|

          propagation = OutlinerNodeDef::PROPAGATION_SELF | OutlinerNodeDef::PROPAGATION_PARENT
          if !node_def.invalidated? && node_def.get_hashable.computed_visible != node_def.computed_visible?
            propagation |= OutlinerNodeDef::PROPAGATION_CHILDREN
          end
          node_def.invalidate(propagation)

        end

        trigger_boo

      end

    end

    def onLayerRemoved(layers, layer)
      # puts "onLayerRemoved"

      return unless @worker

      @worker.run(:compute_available_layers)

      trigger_boo

    end

    def onLayerFolderAdded(layers, layer_folder)
      # puts "onLayerFolderAdded: #{layer_folder.name}"

      return unless @worker

      @worker.run(:compute_available_layers)

      trigger_boo

    end

    def onLayerFolderChanged(layers, layer_folder)
      # puts "onLayerFolderChanged: #{layer_folder.name}"

      return unless @worker

      @worker.run(:compute_available_layers)

      trigger_boo

    end

    def onLayerFolderRemoved(layers, layer_folder)
      # puts "onLayerFolderRemoved"

      return unless @worker

      @worker.run(:compute_available_layers)

      trigger_boo

    end

    def onRemoveAllLayers(layers)
      # puts "onRemoveAllLayers: #{layers}"

      return unless @worker

      @worker.run(:compute_available_layers)

      trigger_boo

    end

    # Definitions Observer

    def onComponentAdded(definitions, definition)
      # puts "onComponentAdded: #{definition} (#{definition.object_id})"

      # Refresh internally created groups definition
      if definition.group? && definition.count_used_instances > 0

        definition.instances.each do |instance|

          face_bounds_cache = {}

          node_defs = @outliner_def.get_node_defs_by_entity_id(instance.entityID)
          if node_defs

            node_defs.each do |node_def|

              parent_node_def = node_def.parent
              expanded = node_def.expanded

              @worker.run(:destroy_node_def, { node_def: node_def })

              node_def = @worker.run(:create_node_def, { entity: instance, path: parent_node_def.path, face_bounds_cache: face_bounds_cache })
              node_def.expanded = expanded

              parent_node_def.add_child(node_def)
              parent_node_def.invalidate

            end

          end

        end

        start_observing_entities(definition)

      end

    end

    # Entities Observer

    def onElementAdded(entities, entity)
      # puts "onElementAdded: #{entity} (#{entity.object_id}) in (#{entity.definition.object_id if entity.respond_to?(:definition)})"

      return unless @worker

      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

        face_bounds_cache = {}

        parent = entity.parent
        parent_instances = parent.is_a?(Sketchup::ComponentDefinition) ? parent.instances : [ parent ]
        parent_instances.each do |instance|

          entity_id = instance.is_a?(Sketchup::Entity) ? instance.entityID : 'model'
          node_defs = @outliner_def.get_node_defs_by_entity_id(entity_id)
          if node_defs
            node_defs.each do |node_def|

              child_node_def = @worker.run(:create_node_def, { entity: entity, path: node_def.path, face_bounds_cache: face_bounds_cache })
              if child_node_def

                node_def.add_child(child_node_def)
                node_def.invalidate
                @worker.run(:sort_children_node_defs, { children: node_def.children })

                child_node_def.expanded = child_node_def.expandable?

              end

            end
          end
        end

        trigger_boo

        start_observing_entities(entity)

      end

    end

    def onElementModified(entities, entity)
      # puts "onElementModified: #{entity} (#{entity.object_id})"

      return unless @worker

      if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Model)

        node_defs = @outliner_def.get_node_defs_by_entity_id(entity.entityID)
        if node_defs
          node_defs.each do |node_def|

            node_def.material_def = @outliner_def.available_material_defs[entity.material]
            node_def.layer_def = @outliner_def.available_layer_defs[entity.layer]

            propagation = OutlinerNodeDef::PROPAGATION_SELF | OutlinerNodeDef::PROPAGATION_PARENT
            if node_def.invalidated? || !node_def.invalidated? && (node_def.get_hashable.computed_visible != node_def.computed_visible? || node_def.get_hashable.computed_locked != node_def.computed_locked?)
              propagation |= OutlinerNodeDef::PROPAGATION_CHILDREN
            end
            node_def.invalidate(propagation)

            @worker.run(:sort_children_node_defs, { children: node_def.parent.children }) if node_def.parent

          end
        end

      elsif entity.is_a?(Sketchup::ComponentDefinition)

        entity.instances.each do |instance|
          node_defs = @outliner_def.get_node_defs_by_entity_id(instance.entityID)
          if node_defs
            node_defs.each do |node_def|
              node_def.invalidate
              @worker.run(:sort_children_node_defs, { children: node_def.parent.children }) if node_def.parent
            end
          end
        end

      elsif entity.is_a?(Sketchup::AttributeDictionary)

        if (entity.name == Plugin::ATTRIBUTE_DICTIONARY || entity.name == Plugin::SU_ATTRIBUTE_DICTIONARY) && entity.parent.parent.is_a?(Sketchup::ComponentDefinition)

          entity.parent.parent.instances.each do |instance|
            node_defs = @outliner_def.get_node_defs_by_entity_id(instance.entityID)
            if node_defs
              node_defs.each do |node_def|
                node_def.invalidate
              end
            end
          end

        end

      end

      trigger_boo if @outliner_def.invalidated?

    end

    def onElementRemoved(entities, entity_id)
      # puts "onElementRemoved: #{entity_id}"

      return unless @worker

      node_defs = @outliner_def.get_node_defs_by_entity_id(entity_id)
      if node_defs

        node_defs.each do |node_def|
          @worker.run(:destroy_node_def, { node_def: node_def })
        end

        trigger_boo

      end

    end


    def trigger_boo
      @event_stack_timer = UI.start_timer(0.1) {

        UI.stop_timer(@event_stack_timer) unless @event_stack_timer.nil?
        @event_stack_timer = nil

        # puts "-- BOO --"
        PLUGIN.trigger_event('on_boo', nil)

      } if @event_stack_timer.nil?
    end

    private

    def start_observing_model(model)
      return if model.nil?
      return if @observed_model_ids.include?(model.object_id)
      model.add_observer(self)
      model.selection.add_observer(self)
      model.materials.add_observer(self)
      model.layers.add_observer(self)
      model.definitions.add_observer(self)
      @observed_model_ids.add(model.object_id)

      # puts "start_observing_model (#{model.object_id})"

      start_observing_entities(model)
    end

    def stop_observing_model(model)
      return if model.nil?
      return unless @observed_model_ids.include?(model.object_id)
      model.remove_observer(self)
      model.selection.remove_observer(self)
      model.materials.remove_observer(self)
      model.layers.remove_observer(self)
      model.definitions.remove_observer(self)
      @observed_model_ids.delete(model.object_id)

      # puts 'stop_observing_model'

      stop_observing_entities(model)
    end

    def start_observing_entities(parent)
      return if parent.is_a?(Sketchup::Entity) && parent.deleted?
      if parent.is_a?(Sketchup::Group) || parent.is_a?(Sketchup::ComponentInstance)
        entities = parent.definition.entities
      elsif parent.is_a?(Sketchup::Model) || parent.is_a?(Sketchup::ComponentDefinition)
        entities = parent.entities
      else
        return
      end
      return if @observed_entities_ids.include?(entities.object_id)
      entities.add_observer(self)
      @observed_entities_ids.add(entities.object_id)
      entities.each { |child_entity| start_observing_entities(child_entity) }
    end

    def stop_observing_entities(parent)
      return if parent.is_a?(Sketchup::Entity) && parent.deleted?
      if parent.is_a?(Sketchup::Group) || parent.is_a?(Sketchup::ComponentInstance)
        entities = parent.definition.entities
      elsif parent.is_a?(Sketchup::Model) || parent.is_a?(Sketchup::ComponentDefinition)
        entities = parent.entities
      else
        return
      end
      return unless @observed_entities_ids.include?(entities.object_id)
      entities.remove_observer(self)
      @observed_entities_ids.delete(entities.object_id)
      entities.each { |child_entity| stop_observing_entities(child_entity) }
    end

    # -- Commands --

    def start_observing_command
      start_observing_model(Sketchup.active_model)
      @observing = true
    end

    def stop_observing_command
      stop_observing_model(Sketchup.active_model)
      @observing = false
    end

    def generate_command(params)
      require_relative '../worker/outliner/outliner_generate_worker'

      # Setup worker
      worker = OutlinerGenerateWorker.new(**params)

      # Run !
      @outliner_def = worker.run

      @worker = OutlinerWorker.new(@outliner_def)

      @outliner_def.get_hashable.to_hash
    end

    def refresh_command
      return generate_command unless @outliner_def
      @outliner_def.get_hashable.to_hash
    end

    def set_active_command(params)
      require_relative '../worker/outliner/outliner_set_active_worker'

      # Setup worker
      worker = OutlinerSetActiveWorker.new(@outliner_def, **params)

      # Run !
      worker.run
    end

    def toggle_expanded_command(params)

      return unless @worker

      trigger_boo if @worker.run(:toggle_expanded, params)

    end

    def toggle_visible_command(params)
      require_relative '../worker/outliner/outliner_toggle_visible_worker'

      # Setup worker
      worker = OutlinerToggleVisibleWorker.new(@outliner_def, **params)

      # Run !
      worker.run
    end

    def toggle_select_command(params)
      require_relative '../worker/outliner/outliner_toggle_select_worker'

      # Setup worker
      worker = OutlinerToggleSelectWorker.new(@outliner_def, **params)

      # Run !
      worker.run
    end

    def toggle_select_all_command
      require_relative '../worker/outliner/outliner_toggle_select_all_worker'

      # Setup worker
      worker = OutlinerToggleSelectAllWorker.new(@outliner_def)

      # Run !
      worker.run
    end

    def invert_select_command
      require_relative '../worker/outliner/outliner_invert_select_worker'

      # Setup worker
      worker = OutlinerInvertSelectWorker.new(@outliner_def)

      # Run !
      worker.run
    end

    def edit_command(params)
      require_relative '../worker/outliner/outliner_edit_worker'

      # Setup worker
      worker = OutlinerEditWorker.new(@outliner_def, **params)

      # Run !
      worker.run
    end

    def update_command(params)
      require_relative '../worker/outliner/outliner_update_worker'

      # Setup worker
      worker = OutlinerUpdateWorker.new(@outliner_def, **params)

      # Run !
      worker.run
    end

    def explode_command(params)
      require_relative '../worker/outliner/outliner_explode_worker'

      # Setup worker
      worker = OutlinerExplodeWorker.new(@outliner_def, **params)

      # Run !
      worker.run
    end

    def highlight_command(params)
      require_relative '../overlay/highlight_overlay'

      ids = params[:ids]
      highlighted = params[:highlighted]
      model = Sketchup.active_model

      return if model.nil?

      model.overlays.remove(@overlay) if @overlay && @overlay.valid?

      if highlighted

        highlight_defs = []
        ids.each do |id|

          node_def = @outliner_def.get_node_def_by_id(id)
          if node_def && !node_def.is_a?(OutlinerNodeModelDef)

            name = [ node_def.name, node_def.respond_to?(:definition_name) ? "<#{node_def.definition_name}>" : nil ].compact.join(' ')
            color = node_def.computed_visible? ? Kuix::COLOR_RED : Kuix::COLOR_DARK_GREY

            highlight_defs << HighlightOverlay::HighlightDef.new(node_def.path, name, color)

          end

        end

        unless highlight_defs.empty?

          @overlay = HighlightOverlay.new(highlight_defs)
          model.overlays.add(@overlay)
          @overlay.enabled = true

        end

      end

    end

  end

end