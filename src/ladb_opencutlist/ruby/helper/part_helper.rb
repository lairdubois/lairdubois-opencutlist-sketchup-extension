module Ladb::OpenCutList

  require_relative '../helper/material_attributes_caching_helper'
  require_relative '../worker/cutlist/cutlist_generate_worker'

  module PartHelper

    include MaterialAttributesCachingHelper

    def _get_part_entity_path_from_path(path)
      part_index = path.rindex { |entity|
        entity.is_a?(Sketchup::ComponentInstance) && !(behavior = entity.definition.behavior).cuts_opening? && !behavior.always_face_camera? ||
          _get_material_attributes(entity.material).type == MaterialAttributes::TYPE_HARDWARE && !entity.name.strip.empty?
      }
      return path[0..part_index] unless part_index.nil?
      path
    end

    def _generate_part_from_path(path)
      return nil unless path.is_a?(Array)

      entity = path.last
      return nil unless entity.is_a?(Sketchup::Drawingelement)

      worker = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_options')).merge({ active_entity: entity, active_path: path[0...-1] }))
      cutlist = worker.run

      part = nil
      cutlist.groups.each do |group|
        group.parts.each do |p|
          if p.def.definition_id == entity.definition.name
            part = p
            break
          end
          end
        break unless part.nil?
        end

      part
    end

  end

end
