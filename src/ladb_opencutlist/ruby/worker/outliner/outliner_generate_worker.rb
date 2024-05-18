module Ladb::OpenCutList

  require 'benchmark'

  require_relative 'outliner_worker'
  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../model/outliner/outliner_def'
  require_relative '../../model/outliner/outliner_node_def'
  require_relative '../../model/outliner/outliner_material_def'
  require_relative '../../model/outliner/outliner_layer_def'
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

      w = OutlinerWorker.new(outliner_def)

      # Errors
      unless model
        outliner_def.add_error('tab.outliner.error.no_model') unless model
        return outliner_def
      end

      # Retrieve available materials and layers
      w.compute_available_materials
      w.compute_available_layers

      # Generate nodes
      puts Benchmark.measure {

        # outliner_def.root_node_def = _fetch_node_defs(outliner_def, model)

        outliner_def.root_node_def = w.run(:create_node_def, { entity: model })

        w.run(:compute_active_path)
        w.run(:compute_selection)

      }

      # Tips
      if outliner_def.root_node_def.children.length == 0
        outliner_def.add_tip('tab.outliner.tip.no_node')
      end

      outliner_def
    end

    # -----

    private

    def _fetch_node_defs(outliner_def, entity, path = [], face_bounds_cache = {})
      node_def = nil
      if entity.is_a?(Sketchup::Group)

        path += [ entity ]

        node_def = OutlinerNodeGroupDef.new(path)
        node_def.default_name = PLUGIN.get_i18n_string("tab.outliner.type_#{AbstractOutlinerNodeDef::TYPE_GROUP}")
        node_def.material_def = outliner_def.available_material_defs[entity.material]
        node_def.layer_def = outliner_def.available_layer_defs[entity.layer]

        outliner_def.add_node_def(node_def)

        children = []
        entity.entities.each { |child_entity|
          next unless child_entity.is_a?(Sketchup::Group) || child_entity.is_a?(Sketchup::ComponentInstance)

          child_node_def = _fetch_node_defs(outliner_def, child_entity, path, face_bounds_cache)
          unless child_node_def.nil?
            child_node_def.parent = node_def
            children << child_node_def
          end

        }
        node_def.children.concat(_sort_children(children))

      elsif entity.is_a?(Sketchup::ComponentInstance)

        path += [ entity ]

        # Treat cuts_opening and always_face_camera behavior component instances as simple component
        unless entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?

          face_bounds_cache[entity.definition] = _compute_faces_bounds(entity.definition) unless face_bounds_cache.has_key?(entity.definition)
          bounds = face_bounds_cache[entity.definition]
          unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

            # It's a part

            node_def = OutlinerNodePartDef.new(path)

          end

        end

        node_def = OutlinerNodeComponentDef.new(path) if node_def.nil?
        node_def.material_def = outliner_def.available_material_defs[entity.material]
        node_def.layer_def = outliner_def.available_layer_defs[entity.layer]

        outliner_def.add_node_def(node_def)

        children = []
        entity.definition.entities.each { |child_entity|
          next unless child_entity.is_a?(Sketchup::Group) || child_entity.is_a?(Sketchup::ComponentInstance)

          child_node_def = _fetch_node_defs(outliner_def, child_entity, path, face_bounds_cache)
          unless child_node_def.nil?
            child_node_def.parent = node_def
            children << child_node_def
          end

        }
        node_def.children.concat(_sort_children(children)) unless children.nil?

      elsif entity.is_a?(Sketchup::Model)

        dir, filename = File.split(entity.path)
        filename = PLUGIN.get_i18n_string('default.empty_filename') if filename.empty?

        node_def = OutlinerNodeModelDef.new(path)
        node_def.default_name = filename
        node_def.expanded = true

        outliner_def.add_node_def(node_def)

        children = []
        entity.entities.each { |child_entity|
          next unless child_entity.is_a?(Sketchup::Group) || child_entity.is_a?(Sketchup::ComponentInstance)

          child_node_def = _fetch_node_defs(outliner_def, child_entity, path, face_bounds_cache)
          unless child_node_def.nil?
            child_node_def.parent = node_def
            children << child_node_def
          end

        }
        node_def.children.concat(_sort_children(children))

      end

      node_def
    end

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