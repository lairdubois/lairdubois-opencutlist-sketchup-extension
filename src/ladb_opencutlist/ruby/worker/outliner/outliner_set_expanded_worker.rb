module Ladb::OpenCutList

  require_relative '../../model/attributes/instance_attributes'

  class OutlinerSetExpandedWorker

    def initialize(outliner,

                   id: nil,
                   expanded: false

    )

      @outliner = outliner

      @id = id
      @expanded = expanded

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
      model.start_operation('OCL Outliner Set Expanded', true, false, true)


      instance_attributes = InstanceAttributes.new(entity)
      instance_attributes.outliner_expanded = @expanded
      instance_attributes.write_to_attributes


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end