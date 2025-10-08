module Ladb::OpenCutList

  require_relative '../worker/cutlist/cutlist_generate_worker'

  module PartHelper

    def _get_part_entity_path_from_path(path)
      part_path = path
      path.reverse_each { |entity|
        return part_path if entity.is_a?(Sketchup::ComponentInstance) && !entity.definition.behavior.cuts_opening? && !entity.definition.behavior.always_face_camera?
        part_path = part_path[0...-1]
      }
    end

    def _generate_part_from_path(path)
      return nil unless path.is_a?(Array)

      entity = path.last
      return nil unless entity.is_a?(Sketchup::Drawingelement)

      worker = CutlistGenerateWorker.new(**HashUtils.symbolize_keys(PLUGIN.get_model_preset('cutlist_options')).merge({ active_entity: entity, active_path: path[0...-1] }))
      cutlist = worker.run

      part = nil
      cutlist.groups.each { |group|
        group.parts.each { |p|
          if p.def.definition_id == entity.definition.name
            part = p
            break
          end
        }
        break unless part.nil?
      }

      part
    end

  end

end
