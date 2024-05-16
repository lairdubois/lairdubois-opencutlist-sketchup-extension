module Ladb::OpenCutList

  class OutlinerToggleSelectWorker

    def initialize(outliner,

                   id: nil

    )

      @outliner = outliner

      @id = id

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outliner.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner.def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      entity = node_def.entity
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