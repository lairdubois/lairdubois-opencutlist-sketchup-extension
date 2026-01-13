module Ladb::OpenCutList

  require_relative '../../helper/layer0_caching_helper'
  require_relative '../../model/attributes/definition_attributes'

  class OutlinerUpdateWorker

    include Layer0CachingHelper

    NodeData = Struct.new(
      :id,
      :name,
      :layer_name,
      :material_name,
      :definition_name,
      :description,
      :url,
      :tags,
      :is2d,
      :snapto,
      :cuts_opening,
      :always_face_camera,
      :shadows_face_sun,
      :no_scale_mask,
    )

    def initialize(outliner_def,

                   nodes_data: nil

    )

      @outliner_def = outliner_def

      fn_sanitize_string = lambda { |str| str.is_a?(String) ? str.strip : str }

      @nodes_data = nodes_data.map { |node_data|
        NodeData.new(
          node_data.fetch('id'),
          fn_sanitize_string.call(node_data.fetch('name')),
          fn_sanitize_string.call(node_data.fetch('layer_name', nil)),
          fn_sanitize_string.call(node_data.fetch('material_name', nil)),
          fn_sanitize_string.call(node_data.fetch('definition_name', nil)),
          fn_sanitize_string.call(node_data.fetch('description', nil)),
          fn_sanitize_string.call(node_data.fetch('url', nil)),
          DefinitionAttributes.valid_tags(node_data.fetch('tags', nil)),
          node_data.fetch('is2d', nil),
          node_data.fetch('snapto', nil).to_i,
          node_data.fetch('cuts_opening', false),
          node_data.fetch('always_face_camera', false),
          node_data.fetch('shadows_face_sun', false),
          node_data.fetch('no_scale_mask', []).each_with_index.map { |v, i| v ? (1 << i) : 0 }.reduce(0, :+), # .reduce(0, :+) == .sum for Ruby < 2.4
        )
      }

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      # Start a model modification operation
      model.start_operation('OCL Outliner Update', true, false, true)


      @nodes_data.each do |node_data|

        node_def = @outliner_def.get_node_def_by_id(node_data.id)
        return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

        entity = node_def.entity
        return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) && !entity.is_a?(Sketchup::Model) || entity.is_a?(Sketchup::Entity) && entity.deleted?

        if node_data.name.is_a?(String) && node_data.name != entity.name
          entity.name = node_data.name
        end

        if node_data.material_name.is_a?(String) && (node_data.material_name.nil? || node_data.material_name.empty? || (material = model.materials[node_data.material_name]))
          if node_data.material_name.nil? || node_data.material_name.empty?
            entity.material = nil
          else
            if entity.material != material
              entity.material = material
            end
          end
        end

        if entity.is_a?(Sketchup::ComponentInstance) && node_data.definition_name.is_a?(String) && node_data.definition_name != entity.definition.name
          entity.definition.name = node_data.definition_name
        end

        if entity.is_a?(Sketchup::Model) && node_data.description.is_a?(String) && node_data.description != entity.description
          entity.description = node_data.description
        end
        if entity.is_a?(Sketchup::ComponentInstance) && node_data.description.is_a?(String) && node_data.description != entity.definition.description
          entity.definition.description = node_data.description
        end

        if entity.is_a?(Sketchup::ComponentInstance) && (node_data.url.is_a?(String) || node_data.tags.is_a?(Array))
          definition_attributes = DefinitionAttributes.new(entity.definition)
          if node_data.url != definition_attributes.url ||
             node_data.tags != definition_attributes.tags
            definition_attributes.url = node_data.url
            definition_attributes.tags = node_data.tags
            definition_attributes.write_to_attributes
          end
        end

        if entity.is_a?(Sketchup::Drawingelement) && node_data.layer_name.is_a?(String) && node_data.layer_name != entity.layer.name
          node_data.layer_name.strip!
          unless node_data.layer_name.empty? && entity.layer == cached_layer0
            if node_data.layer_name.empty?
              entity.layer = cached_layer0
            else
              layer = model.layers[node_data.layer_name]
              if layer.nil?
                layer = model.layers.add(node_data.layer_name)
              end
              entity.layer = layer
            end
          end
        end

        if entity.respond_to?(:definition) &&
           (
             node_data.is2d != entity.definition.behavior.is2d? ||
             node_data.snapto != entity.definition.behavior.snapto ||
             node_data.cuts_opening != entity.definition.behavior.cuts_opening? ||
             node_data.always_face_camera != entity.definition.behavior.always_face_camera? ||
             node_data.shadows_face_sun != entity.definition.behavior.shadows_face_sun?
           )
          entity.definition.behavior.is2d = node_data.is2d
          entity.definition.behavior.snapto = node_data.snapto
          entity.definition.behavior.cuts_opening = node_data.cuts_opening
          entity.definition.behavior.always_face_camera = node_data.always_face_camera
          entity.definition.behavior.shadows_face_sun = node_data.shadows_face_sun
        end

        if entity.respond_to?(:definition) &&
           (
             node_data.no_scale_mask != entity.definition.behavior.no_scale_mask?
           )

          # Workaround for triggering the behavior modified event
          entity.definition.behavior.is2d = !entity.definition.behavior.is2d?
          entity.definition.behavior.is2d = !entity.definition.behavior.is2d?
          # Workaround for triggering the behavior modified event

          entity.definition.behavior.no_scale_mask = node_data.no_scale_mask
        end

      end


      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end