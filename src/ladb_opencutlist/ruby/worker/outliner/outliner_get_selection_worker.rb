module Ladb::OpenCutList

  class OutlinerGetSelectionWorker

    def initialize(outliner)

      @outline = outliner

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outline
      return { :errors => [ 'tab.outliner.error.obsolete_outliner' ] } if @outline.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      { :nodes => model.selection
                       .select { |entity| entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance) }
                       .map { |entity| @outline.get_node_by_entity(entity) }
                       .compact
                       .map { |node| node.to_hash } }
    end

    # -----

  end

end