module Ladb::OpenCutList

  class OutlinerToggleSelectWorker

    def initialize(outliner_def,

                   id:

    )

      @outliner_def = outliner_def

      @id = id

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start model modification operation
      model.start_operation('OCL Outliner Select', true, false, false)


      begin

        # As native behavior, change active path to parent of selected element (SU 2020+)
        if model.respond_to?(:active_path=) && node_def.parent && !node_def.parent.active
          model.active_path = node_def.parent.path
        end

        model.selection.toggle(entity)

      rescue
        return { :errors => [ 'default.error' ] }
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end