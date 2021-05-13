module Ladb::OpenCutList

  require_relative 'model_utils'

  class PathUtils

    SEPARATOR = '>'.freeze

    # -- Serialization --

    def self.serialize_path(path)  # path is Array<ComponentInstance>
      return nil if path.nil?
      entity_ids = []
      path.each { |entity|
        entity_ids.push(entity.entityID)
      }
      entity_ids.join(SEPARATOR)
    end

    def self.unserialize_path(serialized_path)
      path = []
      entity_ids = serialized_path.split(SEPARATOR)
      entity_ids.each { |entity_id|
        entity = ModelUtils::find_entity_by_id(Sketchup.active_model, entity_id.to_i)
        if entity
          path.push(entity)
        else
          return nil
        end
      }
      path
    end

    # -- Named --

    def self.get_named_path(path, ignored_leaf_count = 1, separator = '.')  # path is Array<ComponentInstance>
      return nil if path.nil?
      path_names = []
      path.first(path.size - ignored_leaf_count).each { |entity|
        path_names.push(entity.name) unless entity.name.empty?  # ignore empty names
      }
      path_names.join(separator)
    end

    # -- Geom --

    def self.get_transformation(path)
      transformation = Geom::Transformation.new
      path.each { |entity|
        transformation *= entity.transformation
      }
      transformation
    end

  end

end

