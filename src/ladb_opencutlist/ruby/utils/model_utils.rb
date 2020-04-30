module Ladb::OpenCutList

  class ModelUtils

    def self.find_entity_by_id(model, entity_id)
      if Sketchup.version_number >= 15000000
        return model.find_entity_by_id(entity_id)
      else
        model.active_entities.each { |entity|
          if entity.entityID == entity_id
            return entity
          elsif entity.is_a? Sketchup::Group
            e = find_entity_into_by_id(entity, entity_id)
            return e unless e.nil?
          elsif entity.is_a? Sketchup::ComponentInstance
            e = find_entity_into_by_id(entity.definition, entity_id)
            return e unless e.nil?
          end
        }
      end
      nil
    end

    def self.find_entity_into_by_id(definition_or_group, entity_id)
      definition_or_group.entities.each { |entity|
        if entity.entityID == entity_id
          return entity
        elsif entity.is_a? Sketchup::Group
          e = find_entity_into_by_id(entity, entity_id)
          return e unless e.nil?
        elsif entity.is_a? Sketchup::ComponentInstance
          e = find_entity_into_by_id(entity.definition, entity_id)
          return e unless e.nil?
        end
      }
      nil
    end

  end

end

