module Ladb::OpenCutList

  require_relative '../worker/cutlist/cutlist_generate_worker'

  module PartHelper

    def _get_part_entity_path_from_path(path)
      part_index = path.rindex { |entity| entity.is_a?(Sketchup::ComponentInstance) && !(behavior = entity.definition.behavior).cuts_opening? && !behavior.always_face_camera? }
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
