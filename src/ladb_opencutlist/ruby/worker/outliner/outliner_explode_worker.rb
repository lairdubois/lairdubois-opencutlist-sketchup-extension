module Ladb::OpenCutList

  class OutlinerExplodeWorker

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
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def && node_def.valid?

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?
      return { :errors => [ 'default.error' ] } unless entity.respond_to?(:explode)

      # Start a model modification operation
      model.start_operation('OCL Outliner Explode', true, false, false)


      begin
        model.active_path = node_def.parent.path
        no_selection = false
      rescue
        model.selection.clear
        no_selection = true
      end

      node_defs = node_def.get_valid_selection_siblings

      model.selection.clear
      node_defs
        .map { |node_def| node_def.entity }
        .select { |e| !e.deleted? }
        .each do |entity|
        unless (exploded_entities = entity.explode)
          return { :errors => [ 'default.error' ] }
        end
        model.selection.add(exploded_entities.select { |e| e.is_a?(Sketchup::Drawingelement) }) unless no_selection
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end