module Ladb::OpenCutList

  require_relative '../../helper/layer0_caching_helper'
  require_relative '../../model/attributes/definition_attributes'

  class OutlinerUpdateWorker

    include Layer0CachingHelper

    def initialize(outliner,

                   id: nil,
                   name: nil,
                   material_name: nil,
                   definition_name: nil,
                   layer_name: nil,
                   description: nil,
                   url: nil,
                   tags: nil

    )

      @outline = outliner

      @id = id
      @name = name.is_a?(String) ? name.strip : name
      @material_name = material_name.is_a?(String) ? material_name.strip : material_name
      @definition_name = definition_name.is_a?(String) ? definition_name.strip : definition_name
      @layer_name = layer_name.is_a?(String) ? layer_name.strip : layer_name
      @description = description.is_a?(String) ? description.strip : description
      @url = url.is_a?(String) ? url.strip : url
      @tags = DefinitionAttributes.valid_tags(tags)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outline
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outline.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node = @outline.get_node(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node

      entity = node.def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) && !entity.is_a?(Sketchup::Model) || entity.is_a?(Sketchup::Entity) && entity.deleted?

      # Start model modification operation
      model.start_operation('OCL Outliner Update', true, false, true)

      if @name.is_a?(String) && @name != entity.name
        entity.name = @name
      end

      if @material_name.is_a?(String) && (@material_name.nil? || @material_name.empty? || (material = model.materials[@material_name]))
        if @material_name.nil? || @material_name.empty?
          entity.material = nil
        else
          if entity.material != material
            entity.material = material
          end
        end
      end

      if entity.is_a?(Sketchup::ComponentInstance) && @definition_name.is_a?(String) && @definition_name != entity.definition.name
        entity.definition.name = @definition_name
      end

      if entity.is_a?(Sketchup::Model) && @description.is_a?(String) && @description != entity.description
        entity.description = @description
      end
      if entity.is_a?(Sketchup::ComponentInstance) && @description.is_a?(String) && @description != entity.definition.description
        entity.definition.description = @description
      end

      if entity.is_a?(Sketchup::ComponentInstance) && (@url.is_a?(String) || @tags.is_a?(Array))
        definition_attributes = DefinitionAttributes.new(entity.definition)
        if @url != definition_attributes.url ||
           @tags != definition_attributes.tags
          definition_attributes.url = @url
          definition_attributes.tags = @tags
          definition_attributes.write_to_attributes
        end
      end

      if entity.is_a?(Sketchup::Drawingelement) && @layer_name.is_a?(String) && @layer_name != entity.layer.name
        @layer_name.strip!
        if @layer_name.empty?
          entity.layer = cached_layer0
        else
          layer = model.layers[@layer_name]
          if layer.nil?
            layer = model.layers.add(@layer_name)
          end
          entity.layer = layer
        end
      end


      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end