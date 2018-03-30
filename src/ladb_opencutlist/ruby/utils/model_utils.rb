module Ladb::OpenCutList

  class ModelUtils

    def self.find_entity_by_id(model, entity_id)
      if Sketchup.version_number >= 15000000
        return model.find_entity_by_id(entity_id)
      else
        model.entities.each { |entity|
          if entity.entityID == entity_id
            return entity
          end
        }
      end
      nil
    end

  end

end

