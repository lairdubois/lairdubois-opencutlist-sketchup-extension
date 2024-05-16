module Ladb::OpenCutList

  class OutlinerSetActiveWorker

    def initialize(outliner_def,

                   id: nil

    )

      @outliner_def = outliner_def

      @id = id

    end

    # -----

    def run
      return { :errors => [ [ 'core.error.feature_unavailable', { :version => 2020 } ] ] } if Sketchup.version_number < 2000000000
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      # Start model modification operation
      model.start_operation('OCL Outliner Set Active', true, false, true)

      model.active_path = node_def.path

      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end