module Ladb::OpenCutList

  require_relative 'layer_visibility_helper'

  module InstancePathsHelper

    include LayerVisibilityHelper

    # Appends to 'instance_paths' the path of every visible occurrence of 'instances' found in
    # 'entities', each path starting with 'path'.
    def _instances_to_paths(instances, instance_paths, entities, path = [])
      entities.each do |entity|
        next unless entity.respond_to?(:definition)   # Minor Speed improvement
        next unless entity.visible? && _layer_visible?(entity.layer, path.empty?)
        path.push(entity)
        if entity.definition.group?
          _instances_to_paths(instances, instance_paths, entity.entities, path)
        else
          if instances.include?(entity)
            instance_paths << path.dup
          else
            _instances_to_paths(instances, instance_paths, entity.definition.entities, path)
          end
        end
        path.pop
      end
    end

  end

end
