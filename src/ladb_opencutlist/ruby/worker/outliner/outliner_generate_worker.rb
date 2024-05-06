module Ladb::OpenCutList

  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../model/outliner/outliner_def'
  require_relative '../../model/outliner/node_def'
  require_relative '../../model/outliner/layer_def'
  require_relative '../../model/attributes/instance_attributes'
  require_relative '../../utils/color_utils'

  class OutlinerGenerateWorker

    include BoundingBoxHelper
    include LayerVisibilityHelper

    # -----

    def run

      model = Sketchup.active_model

      filename = model && !model.path.empty? ? File.basename(model.path) : PLUGIN.get_i18n_string('default.empty_filename')
      model_name = model && model.name

      outliner_def = OutlinerDef.new(filename, model_name)

      # Errors
      unless model
        outliner_def.add_error('tab.outliner.error.no_model') unless model
        return outliner_def.create_outliner
      end
      if model.entities.length == 0
        outliner_def.add_error('tab.outliner.error.no_entities')
        return outliner_def.create_outliner
      end

      # Retrieve available layers
      model.layers.each do |layer|
        next if layer == cached_layer0
        outliner_def.add_layer_def(LayerDef.new(layer))
      end

      # Generate nodes
      outliner_def.root_node_def, = _fetch_node_defs(outliner_def, model)

      # Tips
      if outliner_def.root_node_def.children.length == 0
        outliner_def.add_tip('tab.outliner.tip.no_node')
      end

      outliner_def.create_outliner
    end

    # -----

    def _fetch_node_defs(outliner_def, entity, path = [], face_bounds_cache = {})
      return nil, 0, 0 if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
      node_def = nil
      face_count = 0
      part_count = 0
      if entity.is_a?(Sketchup::Model)

        dir, filename = File.split(entity.path)
        filename = PLUGIN.get_i18n_string('default.empty_filename') if filename.empty?

        children = []
        entity.entities.each { |child_entity|

          child_node_def, child_face_count, child_part_count = _fetch_node_defs(outliner_def, child_entity, path, face_bounds_cache)
          children << child_node_def unless child_node_def.nil?

          face_count += child_face_count
          part_count += child_part_count

        }

        node_def = NodeModelDef.new(path)
        node_def.default_name = filename
        node_def.expanded = true
        node_def.part_count = part_count
        node_def.children.concat(_sort_children(children))

      elsif entity.is_a?(Sketchup::Group)

        instance_attributes = InstanceAttributes.new(entity)

        path += [ entity ]

        children = []
        entity.entities.each { |child_entity|

          child_node_def, child_face_count, child_part_count = _fetch_node_defs(outliner_def, child_entity, path, face_bounds_cache)
          children << child_node_def unless child_node_def.nil?

          face_count += child_face_count
          part_count += child_part_count

        }

        node_def = NodeGroupDef.new(path)
        node_def.default_name = PLUGIN.get_i18n_string("tab.outliner.type_#{AbstractNodeDef::TYPE_GROUP}")
        node_def.layer_def = outliner_def.available_layer_defs[entity.layer]
        node_def.expanded = instance_attributes.outliner_expanded
        node_def.part_count = part_count
        node_def.children.concat(_sort_children(children))

      elsif entity.is_a?(Sketchup::ComponentInstance)

        instance_attributes = InstanceAttributes.new(entity)

        path += [ entity ]

        node_def = nil
        children = []
        unless entity.definition.behavior.always_face_camera?

          entity.definition.entities.each { |child_entity|

            child_node_def, child_face_count, child_part_count = _fetch_node_defs(outliner_def, child_entity, path, face_bounds_cache)
            children << child_node_def unless child_node_def.nil?

            face_count += child_face_count
            part_count += child_part_count

          }

          # Treat cuts_opening behavior component instances as simple component
          unless entity.definition.behavior.cuts_opening?

            if face_count > 0

              face_bounds_cache[entity.definition] = _compute_faces_bounds(entity.definition) unless face_bounds_cache.has_key?(entity.definition)
              bounds = face_bounds_cache[entity.definition]
              unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

                # It's a part

                node_def = NodePartDef.new(path)

                face_count = 0
                part_count += 1

              end

            end

          end

        end

        node_def = NodeComponentDef.new(path) if node_def.nil?
        node_def.default_name = "<#{entity.definition.name}>"
        node_def.definition_name = entity.definition.name
        node_def.layer_def = outliner_def.available_layer_defs[entity.layer]
        node_def.expanded = instance_attributes.outliner_expanded
        node_def.part_count = part_count
        node_def.children.concat(_sort_children(children)) unless children.nil?

      elsif entity.is_a?(Sketchup::Face)

        return nil, 1, 0

      end
      [ node_def, face_count, part_count ]
    end

    private

    def _sort_children(children)
      children.sort_by! do |node_def|
        [
            node_def.type,
            (node_def.entity.name.nil? || node_def.entity.name.empty?) ? 1 : 0,
            node_def.entity.name,
            node_def.default_name,
            node_def.layer_def.nil? ? '' : node_def.layer_def.layer.name
        ]
      end
    end

  end

end