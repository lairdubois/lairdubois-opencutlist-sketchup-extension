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

      # Start model modification operation
      model.start_operation('OCL Outliner Deep Make Unique', true, false, false)


      if node_def.selected
        node_defs = node_def.parent.children.map { |child_node_def| child_node_def if child_node_def.selected }.compact
      else
        node_defs = [ node_def ]
      end

      di = {} # Definition => Instances
      fn_populate_di = lambda { |node_def|
        next if node_def.entity.deleted?
        node_def.entity.make_unique if node_def.entity.is_a?(Sketchup::Group) # Force Groups to be unique
        if node_def.entity.definition.count_instances > 1
          di[node_def.entity.definition] = [] unless di.has_key?(node_def.entity.definition)
          di[node_def.entity.definition] << node_def.entity
        end
        node_def.children.each do |child_node_def|
          fn_populate_di.call(child_node_def)
        end
      }
      node_defs.each { |node_def| fn_populate_di.call(node_def) }

      di.each do |definition, instances|
        next if instances.size == definition.count_instances   # All instances are there
        instances.uniq!
        new_definition = instances.shift.make_unique.definition
        instances.each do |instance|
          instance.definition = new_definition
        end
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end