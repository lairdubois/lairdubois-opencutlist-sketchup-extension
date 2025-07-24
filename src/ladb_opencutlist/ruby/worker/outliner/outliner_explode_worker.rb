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
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?
      return { :errors => [ 'default.error' ] } unless entity.respond_to?(:explode)

      # Start model modification operation
      model.start_operation('OCL Outliner Explode', true, false, false)


      entities_to_explode = []
      if node_def.selected
        entities_to_explode.concat(model.selection.to_a.select { |e| e.respond_to?(:explode) })
      else
        entities_to_explode.push(entity)
      end
      model.selection.clear

      entities_to_explode.each do |entity_to_explode|
        unless (exploded_entities = entity_to_explode.explode)
          return { :errors => [ 'default.error' ] }
        end
        model.selection.add(exploded_entities.select { |e| e.is_a?(Sketchup::Drawingelement) })
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end