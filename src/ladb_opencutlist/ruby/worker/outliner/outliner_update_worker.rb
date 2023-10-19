module Ladb::OpenCutList

  require_relative '../../helper/layer0_caching_helper'

  class OutlinerUpdateWorker

    include Layer0CachingHelper

    def initialize(node_data, outliner)

      @id = node_data.fetch('id')
      @name = node_data.fetch('name', nil)
      @definition_name = node_data.fetch('definition_name', nil)
      @layer_name = node_data.fetch('layer_name', nil)
      @description = node_data.fetch('description', nil)
      @url = node_data.fetch('url', nil)

      @outline = outliner

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
        entity.name = @name.strip
      end

      if entity.is_a?(Sketchup::ComponentInstance) && @definition_name.is_a?(String) && @definition_name != entity.definition.name
        entity.definition.name = @definition_name.strip
      end

      if entity.is_a?(Sketchup::Model) && @description.is_a?(String) && @description != entity.description
        entity.description = @description.strip
      end
      if entity.is_a?(Sketchup::ComponentInstance) && @description.is_a?(String) && @description != entity.definition.description
        entity.definition.description = @description.strip
      end
      if entity.is_a?(Sketchup::ComponentInstance) && @url.is_a?(String)
        definition_attributes = DefinitionAttributes.new(entity.definition)
        if @url != definition_attributes.url
          definition_attributes.url = @url.strip
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