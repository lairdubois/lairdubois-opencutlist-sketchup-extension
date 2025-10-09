module Ladb::OpenCutList

  class OutlinerCreateContainerWorker

    def initialize(outliner_def,

                   id:,

                   name: nil,
                   component: false

    )

      @outliner_def = outliner_def

      @id = id

      @name = name
      @component = component

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def && node_def.valid?

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start a model modification operation
      model.start_operation('OCL Outliner Create Container', true, false, false)


      node_defs = node_def.get_valid_selection_siblings

      entities = node_defs.map { |node_def| node_def.entity }
      instance = group = entity.parent.entities.add_group(entities)

      group.name = group.definition.name = @name unless @name.nil?
      instance = group.to_component if @component

      model.selection.clear
      model.selection.add(instance)


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end