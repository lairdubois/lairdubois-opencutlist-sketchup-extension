module Ladb::OpenCutList

  class OutlinerToggleVisibleWorker

    def initialize(outliner_def,

                   ids:

    )

      @outliner_def = outliner_def

      @ids = ids

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_defs = @ids.map { |id| @outliner_def.get_node_def_by_id(id) }.compact
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } if node_defs.empty?

      # Start model modification operation
      model.start_operation('OCL Outliner Toggle Visible', true, false, false)


      node_defs.each do |node_def|

        node_def.entity.visible = !node_def.entity.visible?

      end


      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end