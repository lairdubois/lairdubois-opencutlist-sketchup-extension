module Ladb::OpenCutList

  class OutlinerToggleSelectWorker

    def initialize(outliner,

                   id: nil

    )

      @outline = outliner

      @id = id

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
      model.start_operation('OCL Outliner Select', true, false, false)


      if model.selection.contains?(entity)
        model.selection.remove(entity)
      else
        model.selection.add(entity)
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end