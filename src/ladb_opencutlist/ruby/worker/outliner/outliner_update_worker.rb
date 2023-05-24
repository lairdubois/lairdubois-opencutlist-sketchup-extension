module Ladb::OpenCutList

  class OutlinerUpdateWorker

    def initialize(node_data, outliner)

      @id = node_data.fetch('id')
      @name = node_data.fetch('name')

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

      if @name != entity.name
        entity.name = @name
      end

      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end