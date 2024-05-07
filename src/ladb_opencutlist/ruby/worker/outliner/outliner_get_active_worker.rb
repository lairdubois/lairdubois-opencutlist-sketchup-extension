module Ladb::OpenCutList

  class OutlinerGetActiveWorker

    def initialize(outliner)

      @outline = outliner

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outline
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outline.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      active_path = Sketchup.active_model.active_path.nil? ? [] : Sketchup.active_model.active_path

      node = @outline.get_node_by_path(active_path)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node

      { :node => node.to_hash }
    end

    # -----

  end

end