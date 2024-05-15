module Ladb::OpenCutList

  require 'singleton'
  require 'set'

  class EntitiesObserver < Sketchup::EntitiesObserver

    include Singleton

    def initialize

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
      UI.stop_timer(@event_stack_timer) unless @event_stack_timer.nil?
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