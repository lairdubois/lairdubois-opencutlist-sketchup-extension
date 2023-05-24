module Ladb::OpenCutList

  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../model/outliner/outliner'
  require_relative '../../model/outliner/node_def'

  class OutlinerGenerateWorker

    include BoundingBoxHelper
    include LayerVisibilityHelper

    def initialize(settings)

    end

    # -----

    def run

      model = Sketchup.active_model

      filename = model && !model.path.empty? ? File.basename(model.path) : Plugin.instance.get_i18n_string('default.empty_filename')
      model_name = model && model.name

      outliner = Outliner.new(filename, model_name)

      # Errors
      unless model
        outliner.add_error('tab.outliner.error.no_model') unless model
        return outliner
      end
      if model.entities.length == 0
        outliner.add_error('tab.outliner.error.no_model')
        return outliner
      end

      # Generate outline
      root_node_def, = _fetch_node_defs(model)
      if root_node_def
        outliner.root_node = root_node_def.create_node
      end

      # Tips
      if root_node_def.children.length == 0
        outliner.add_tip('tab.outliner.tip.no_node')
      end

      outliner
    end

    # -----

    def _fetch_node_defs(entity, parent_node_def = nil, path = [])
      return nil, 0, 0 if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
      node_def = nil
      face_count = 0
      part_count = 0
      if entity.is_a?(Sketchup::Model)

        dir, filename = File.split(entity.path)
        filename = Plugin.instance.get_i18n_string('default.empty_filename') if filename.empty?

        node_def = NodeDef.new(NodeDef.generate_node_id(entity, path))
        node_def.type = NodeDef::TYPE_MODEL
        node_def.name = entity.name
        node_def.definition_name = filename

        entity.entities.each { |child_entity|
          child_node_def, child_face_count, child_part_count = _fetch_node_defs(child_entity, node_def, path)
          face_count += child_face_count
          part_count += child_part_count
        }

        _sort_children(node_def)
        node_def.part_count = part_count

      elsif entity.is_a?(Sketchup::Group)

        path += [ entity]

        node_def = NodeDef.new(NodeDef.generate_node_id(entity, path), path)
        node_def.type = NodeDef::TYPE_GROUP
        node_def.name = entity.name
        node_def.definition_name = Plugin.instance.get_i18n_string("tab.outliner.type_#{NodeDef::TYPE_GROUP}")
        node_def.visible = entity.visible? && _layer_visible?(entity.layer, parent_node_def.nil?)

        entity.entities.each { |child_entity|
          child_node_def, child_face_count, child_part_count = _fetch_node_defs(child_entity, node_def, path)
          face_count += child_face_count
          part_count += child_part_count
        }

        _sort_children(node_def)
        node_def.part_count = part_count

        parent_node_def.children << node_def unless parent_node_def.nil?

      elsif entity.is_a?(Sketchup::ComponentInstance)

        path += [ entity]

        node_def = NodeDef.new(NodeDef.generate_node_id(entity, path), path)
        node_def.type = NodeDef::TYPE_COMPONENT
        node_def.name = entity.name
        node_def.definition_name = entity.definition.name
        node_def.visible = entity.visible? && _layer_visible?(entity.layer, parent_node_def.nil?)

        entity.definition.entities.each { |child_entity|
          child_node_def, child_face_count, child_part_count = _fetch_node_defs(child_entity, node_def, path)
          face_count += child_face_count
          part_count += child_part_count
        }

        if face_count > 0

          bounds = _compute_faces_bounds(entity.definition, nil)
          unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

            # It's a part

            node_def.type = NodeDef::TYPE_PART

            face_count = 0
            part_count += 1

          end

        end

        _sort_children(node_def)
        node_def.part_count = part_count

        parent_node_def.children << node_def

      elsif entity.is_a?(Sketchup::Face)

        return nil, 1, 0

      end
      [ node_def, face_count, part_count ]
    end

    def _sort_children(node_def)
      node_def.children.sort_by! { |node_def| [node_def.name.nil? || node_def.name.empty? ? '1' : '0', node_def.name ] }
    end

  end

end