module Ladb::OpenCutList

  class OutlinerGetActiveWorker

    def initialize(outliner)

      @outliner = outliner

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outliner.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      active_path = Sketchup.active_model.active_path.nil? ? [] : Sketchup.active_model.active_path

      node_def = @outliner.def.get_node_def_by_id(AbstractOutlinerNodeDef.generate_node_id(active_path))
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def

      { :node_id => node_def.id }
    end

    # -----

  end

end