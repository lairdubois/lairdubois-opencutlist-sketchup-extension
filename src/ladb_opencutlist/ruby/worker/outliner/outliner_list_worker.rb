module Ladb::OpenCutList

  require_relative '../../helper/bounding_box_helper'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../model/outliner/node'

  class OutlinerListWorker

    include BoundingBoxHelper
    include LayerVisibilityHelper

    def initialize(settings)

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model
      return { :errors => [ 'tab.outliner.error.no_entities' ] } if model.entities.length == 0

      root_node, = _fetch_nodes(model, nil)

      response = {
        :errors => [],
        :warnings => [],
        :filename => !model.path.empty? ? File.basename(model.path) : Plugin.instance.get_i18n_string('default.empty_filename'),
        :model_name => model.name,
        :length_unit_strippedname => DimensionUtils.instance.model_unit_is_metric ? DimensionUtils::UNIT_STRIPPEDNAME_METER : DimensionUtils::UNIT_STRIPPEDNAME_FEET,
        :mass_unit_strippedname => MassUtils.instance.get_symbol,
        :currency_symbol => PriceUtils.instance.get_symbol,
        :root_node => root_node.to_hash
      }

      response
    end

    # -----

    def _fetch_nodes(entity, parent, path = [])
      return nil, 0, 0 if entity.is_a?(Sketchup::Edge)   # Minor Speed improvement when there's a lot of edges
      node = nil
      face_count = 0
      part_count = 0
      if entity.is_a?(Sketchup::Model)

        node = Node.new(Node.generate_node_id(entity, path))
        node.name = entity.name

        child_path = path + [ entity ]
        entity.entities.each { |child_entity|
          child_node, child_face_count, child_part_count = _fetch_nodes(child_entity, node, child_path)
          face_count += child_face_count
          part_count += child_part_count
        }

        _sort_nodes(node)
        node.part_count = part_count

        elsif entity.is_a?(Sketchup::Group)

        node = Node.new(Node.generate_node_id(entity, path))
        node.name = entity.name
        node.visible = entity.visible? && _layer_visible?(entity.layer, parent.nil?)

        child_path = path + [ entity ]
        entity.entities.each { |child_entity|
          child_node, child_face_count, child_part_count = _fetch_nodes(child_entity, node, child_path)
          face_count += child_face_count
          part_count += child_part_count
        }

        _sort_nodes(node)
        node.part_count = part_count

        parent.nodes << node unless parent.nil?

      elsif entity.is_a?(Sketchup::ComponentInstance)

        node = Node.new(Node.generate_node_id(entity, path))
        node.name = entity.name
        node.definition_name = entity.definition.name
        node.visible = entity.visible? && _layer_visible?(entity.layer, parent.nil?)

        child_path = path + [ entity]
        entity.definition.entities.each { |child_entity|
          child_node, child_face_count, child_part_count = _fetch_nodes(child_entity, node, child_path)
          face_count += child_face_count
          part_count += child_part_count
        }

        if face_count > 0

          bounds = _compute_faces_bounds(entity.definition, nil)
          unless bounds.empty? || [ bounds.width, bounds.height, bounds.depth ].min == 0    # Exclude empty or flat bounds

            # It's a part
            return node, 0, part_count + 1

          end

        end

        _sort_nodes(node)
        node.part_count = part_count

        parent.nodes << node

      elsif entity.is_a?(Sketchup::Face)

        return nil, 1, 0

      end
      [ node, face_count, part_count ]
    end

    def _sort_nodes(node)
      node.nodes.sort_by! { |node| [ node.name.nil? || node.name.empty? ? '1' : '0', node.name ] }
    end

  end

end