module Ladb::OpenCutList

  class OutlinerToggleVisibleWorker

    def initialize(outliner_def,

                   id:

    )

      @outliner_def = outliner_def

      @id = id

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      node_def = @outliner_def.get_node_def_by_id(@id)
      return { :errors => [ 'tab.outliner.error.node_not_found' ] } unless node_def && node_def.valid?

      entity = node_def.entity
      return { :errors => [ 'tab.outliner.error.entity_not_found' ] } if !entity.is_a?(Sketchup::Entity) || entity.deleted?

      # Start a model modification operation
      model.start_operation('OCL Outliner Toggle Visible', true, false, false)


      begin

        visible = !entity.visible?

        if node_def.selected
          node_defs = node_def.parent.children.map { |child_node_def| child_node_def if child_node_def.selected && child_node_def.valid? }.compact
        else
          node_defs = [ node_def ]
        end
        node_defs.each do |node_def|
          node_def.entity.visible = visible
        end

      rescue => e
        return { :errors => [ 'default.error' ] }
      end


      # Commit model modification operation
      model.commit_operation

    end

    # -----

  end

end