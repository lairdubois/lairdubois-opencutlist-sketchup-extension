module Ladb::OpenCutList

  class OutlinerSetVisibleWorker

    def initialize(outliner,

                   id: nil,
                   visible: true

    )

      @outline = outliner

      @id = id
      @visible = visible

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
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start model modification operation
      model.start_operation('OCL Outliner Toggle Visible', true, false, false)


      entity.visible = @visible


      # Commit model modification operation
      model.commit_operation

      { :visible => entity.visible? }
    end

    # -----

  end

end