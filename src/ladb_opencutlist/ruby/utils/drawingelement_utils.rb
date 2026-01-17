module Ladb::OpenCutList

  module DrawingelementUtils

    def self.get_drawingelement_path(entity)
      return nil unless entity.is_a?(Sketchup::Drawingelement)
      return nil if entity.deleted?
      return nil if (model = Sketchup.active_model).nil?

      active_path = model.active_path.to_a

      return active_path + [ entity ] if model.active_entities.find { |_e| _e.entityID == entity.entityID }

      path = []

      fn = proc do |e|
        path.unshift(e)
        if (parent_definition = e.parent).is_a?(Sketchup::ComponentDefinition)
          parent_instance = parent_definition.instances.find { |instance| instance.definition.entities.find { |_e| _e.entityID == e.entityID } }
          fn.call(parent_instance) unless parent_instance.nil?
        end
      end
      fn.call(entity)

      path
    end

  end

end