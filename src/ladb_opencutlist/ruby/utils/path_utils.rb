module Ladb::OpenCutList

  class PathUtils

    SEPARATOR = '>'.freeze

    # -- Serialization --

    def self.serialize_path(path)  # path is Array<ComponentInstance>
      return nil unless path.is_a?(Array)
      entity_ids = []
      path.each { |entity|
        entity_ids.push(entity.entityID)
      }
      entity_ids.join(SEPARATOR)
    end

    def self.unserialize_path(serialized_path)
      return nil unless serialized_path.is_a?(String)
      path = []
      entity_ids = serialized_path.split(SEPARATOR)
      entity_ids.each { |entity_id|
        entity = Sketchup.active_model.find_entity_by_id(entity_id.to_i)
        if entity
          path.push(entity)
        else
          return nil
        end
      }
      path
    end

    # -- Named --

    def self.get_named_path(path, ignore_empty_names = true, ignored_leaf_count = 1)  # path is Array<ComponentInstance>
      return nil if path.nil?
      path_names = []
      path.first(path.size - ignored_leaf_count).each { |entity|
        if ignore_empty_names
          path_names.push(entity.name) unless entity.name.empty?  # ignore empty names
        else
          path_names.push(entity.name.empty? ? "##{entity.entityID}#{entity.is_a?(Sketchup::ComponentInstance) ? " <#{entity.definition.name}>" : ''}" : entity.name)
        end
      }
      path_names  # Array<String>
    end

    # -- Geom --

    def self.get_transformation(path, default_transformation = nil)
      return default_transformation if path.nil? || path.empty?
      transformation = Geom::Transformation.new
      path.each { |entity|
        transformation *= entity.transformation if entity.respond_to?(:transformation)
      }
      transformation
    end

  end

end

