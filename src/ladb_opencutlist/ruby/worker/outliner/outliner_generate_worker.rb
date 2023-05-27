module Ladb::OpenCutList

  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../model/outliner/outliner'
  require_relative '../../model/outliner/node_def'
  require_relative '../../model/outliner/layer_def'
  require_relative '../../model/attributes/instance_attributes'

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

    def _fetch_node_defs(entity, path = [])
      return nil, 0, 0 if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
      node_def = nil
      face_count = 0
      part_count = 0
      if entity.is_a?(Sketchup::Model)

        dir, filename = File.split(entity.path)
        filename = Plugin.instance.get_i18n_string('default.empty_filename') if filename.empty?

        children = []
        entity.entities.each { |child_entity|

          child_node_def, child_face_count, child_part_count = _fetch_node_defs(child_entity, path)
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

        path += [ entity]

        children = []
        entity.entities.each { |child_entity|

          child_node_def, child_face_count, child_part_count = _fetch_node_defs(child_entity, path)
          children << child_node_def unless child_node_def.nil?

          face_count += child_face_count
          part_count += child_part_count

        }

        node_def = NodeGroupDef.new(path)
        node_def.default_name = Plugin.instance.get_i18n_string("tab.outliner.type_#{AbstractNodeDef::TYPE_GROUP}")
        node_def.layer_def = _create_layer_def(entity.layer)
        node_def.expanded = instance_attributes.outliner_expanded
        node_def.part_count = part_count
        node_def.children.concat(_sort_children(children))

      elsif entity.is_a?(Sketchup::ComponentInstance)

        instance_attributes = InstanceAttributes.new(entity)

        path += [ entity ]

        children = []
        entity.definition.entities.each { |child_entity|

          child_node_def, child_face_count, child_part_count = _fetch_node_defs(child_entity, path)
          children << child_node_def unless child_node_def.nil?

          face_count += child_face_count
          part_count += child_part_count

        }

        node_def = nil
        if face_count > 0

          bounds = _compute_faces_bounds(entity.definition, nil)
          unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

            # It's a part

            node_def = NodePartDef.new(path)

            face_count = 0
            part_count += 1

          end

        end

        node_def = NodeComponentDef.new(path) if node_def.nil?
        node_def.default_name = "<#{entity.definition.name}>"
        node_def.definition_name = entity.definition.name
        node_def.layer_def = _create_layer_def(entity.layer)
        node_def.expanded = instance_attributes.outliner_expanded
        node_def.part_count = part_count
        node_def.children.concat(_sort_children(children))

      elsif entity.is_a?(Sketchup::Face)

        return nil, 1, 0

      end
      [ node_def, face_count, part_count ]
    end

    private

    def _create_layer_def(layer)
      return nil if layer == cached_layer0
      layer_def = layer.is_a?(Sketchup::Layer) ? LayerDef.new(layer) : LayerFolderDef.new(layer)
      layer_def.folder = _create_layer_def(layer.folder) if layer.respond_to?(:folder) && !layer.folder.nil?
      layer_def
    end

    def _sort_children(children)
      children.sort_by! do |node_def|
        [
            node_def.type == AbstractNodeDef::TYPE_PART ? 1 : 0,
            (node_def.entity.name.nil? || node_def.entity.name.empty?) ? 1 : 0,
            node_def.entity.name,
            node_def.default_name
        ]
      end
    end

  end

end