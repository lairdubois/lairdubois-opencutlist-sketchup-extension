module Ladb::OpenCutList

  class OutlinerSetActiveWorker

    def initialize(node_data, outliner)

      @id = node_data.fetch('id')

      @outline = outliner

    end

    # -----

    def run
      return { :errors => [ [ 'core.error.feature_unavailable', { :version => 2020 } ] ] } if Sketchup.version_number < 2000000000
      return { :errors => [ 'default.error' ] } unless @outline
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outline.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node = @outline.get_node(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node

      if model.respond_to?(:active_path)

        # Start model modification operation
        model.start_operation('OCL Outliner Set Active', true, false, true)

        model.active_path = node.def.path

        # Commit model modification operation
        model.commit_operation

      end

    end

    # -----

  end

end