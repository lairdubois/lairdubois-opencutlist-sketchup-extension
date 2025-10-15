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
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def && node_def.valid?

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start a model modification operation
      model.start_operation('OCL Outliner Deep Make Unique', true, false, false)


      node_defs = node_def.get_valid_unlocked_selection_siblings

      d_is = {} # Definition => Instances
      fn_populate_di = lambda { |entity|
        next if entity.deleted?
        if entity.is_a?(Sketchup::Group)
          entity = entity.make_unique # Force Groups to be unique immediately
        else
          if entity.definition.count_used_instances > 1
            d_is[entity.definition] = [] unless d_is.has_key?(entity.definition)
            d_is[entity.definition] << entity
          end
        end
        if entity.respond_to?(:definition)
          entity.definition.entities.each do |child_entity|
            next unless child_entity.respond_to?(:definition)
            fn_populate_di.call(child_entity)
          end
        end
      }
      node_defs.each { |node_def| fn_populate_di.call(node_def.entity) }

      d_is.each do |definition, instances|

        next if instances.size == definition.count_used_instances   # All instances are there, move next

        # Make unique the first instance and retrieve the new definition
        new_definition = instances.shift.make_unique.definition

        # Change definition of all other instances
        instances.each do |instance|
          instance.definition = new_definition
        end

        # Retrieve old definition child instances
        old_d_cis = definition.entities.to_a
                  .select { |e| e.is_a?(Sketchup::ComponentInstance) }
                  .group_by { |i| i.definition }

        # Retrieve new definition child instances
        new_d_cis = new_definition.entities.to_a
                  .select { |e| e.is_a?(Sketchup::ComponentInstance) }
                  .group_by { |i| i.definition }

        # Replace old definition child instances by new definition child instances
        old_d_cis.each do |d, is|
          d_is[d].reject! { |i| is.include?(i) }.concat(new_d_cis[d])
        end

      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end