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
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start model modification operation
      model.start_operation('OCL Outliner Create Container', true, false, false)


      if node_def.selected
        node_defs = node_def.parent.children.map { |child_node_def| child_node_def if child_node_def.selected }.compact
      else
        node_defs = [ node_def ]
      end

      entities = node_defs.map { |node_def| node_def.entity }
      group = entity.parent.entities.add_group(entities)

      group.name = group.definition.name = @name unless @name.nil?
      group.to_component if @component


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end