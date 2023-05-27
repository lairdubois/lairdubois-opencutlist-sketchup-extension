module Ladb::OpenCutList

  require_relative '../../model/attributes/instance_attributes'

  class OutlinerSetExpandedWorker

    def initialize(node_data, outliner)

      @id = node_data.fetch('id')
      @expanded = node_data.fetch('expanded', false)

      @outline = outliner

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outline
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outline.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node = @outline.get_node(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node

      # Start model modification operation
      model.start_operation('OCL Outliner Set Expanded', true, false, true)


      node.expanded = @expanded

      instance_attributes = InstanceAttributes.new(node.def.entity)
      instance_attributes.outliner_expanded = @expanded
      instance_attributes.write_to_attributes


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end