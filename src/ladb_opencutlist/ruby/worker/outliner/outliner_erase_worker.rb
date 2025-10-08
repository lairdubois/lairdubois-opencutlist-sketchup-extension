module Ladb::OpenCutList

  class OutlinerEraseWorker

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
      return { :errors => [ 'default.error' ] } unless entity.respond_to?(:explode)

      # Start a model modification operation
      model.start_operation('OCL Outliner Erease', true, false, false)


      if node_def.selected
        node_defs = node_def.parent.children.map { |child_node_def| child_node_def if child_node_def.selected }.compact
      else
        node_defs = [ node_def ]
      end

      model.selection.clear
      node_defs
        .map { |node_def| node_def.entity }
        .select { |e| !e.deleted? }
        .group_by { |e| e.parent }
        .each do |parent, entities|
        parent.entities.erase_entities(entities)
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end