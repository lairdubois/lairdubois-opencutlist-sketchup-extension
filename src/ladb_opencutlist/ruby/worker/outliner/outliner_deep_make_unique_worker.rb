module Ladb::OpenCutList

  class OutlinerDeepMakeUniqueWorker

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
      model.start_operation('OCL Outliner Deep Make Unique', true, false, false)


        root_entities = []
        if node_def.selected
          root_entities.concat(model.selection.to_a)
        else
          root_entities.push(entity)
        end

        di = {}
        fn_populate_di = lambda { |entity|
          entity.make_unique if entity.is_a?(Sketchup::Group) # Force Groups to be unique
          if entity.respond_to?(:definition)
            if entity.definition.count_instances > 1
              di[entity.definition] = [] unless di.has_key?(entity.definition)
              di[entity.definition] << entity
            end
            entity.definition.entities.each do |e|
              fn_populate_di.call(e)
            end
          end
        }
        root_entities.each do |e|
          fn_populate_di.call(e)
        end

        di.each do |definition, entities|
          next if entities.size == definition.count_instances   # All instances are there
          entities.uniq!
          new_definition = entities.shift.make_unique.definition
          entities.each do |e|
            e.definition = new_definition
          end
        end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end