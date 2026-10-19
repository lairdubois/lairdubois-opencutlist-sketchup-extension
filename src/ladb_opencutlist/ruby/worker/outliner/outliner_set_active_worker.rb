module Ladb::OpenCutList

  require_relative '../../utils/view_utils'

  class OutlinerSetActiveWorker

    def initialize(outliner_def,

                   id:

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
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def || node_def.entity.deleted?

      # Start a model modification operation
      model.start_operation('OCL Outliner Set Active', true, false, true)


      begin

        model.active_path = node_def.path

        # Zoom on active entities
        ViewUtils.zoom_active_entities(model.active_view)

      rescue
        return { :errors => [ 'default.error' ] }
      end


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end