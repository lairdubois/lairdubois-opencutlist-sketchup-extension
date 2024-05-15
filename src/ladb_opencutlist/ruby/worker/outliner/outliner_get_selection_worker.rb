module Ladb::OpenCutList

  class OutlinerGetSelectionWorker

    def initialize(outliner)

      @outliner = outliner

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outliner.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      { :node_ids => model.selection
                       .select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
                       .flat_map { |entity| @outliner.def.get_node_defs_by_entity(entity) }
                       .compact
                       .map { |node_def| node_def.id } }
    end

    # -----

  end

end