module Ladb::OpenCutList

  class OutlinerToggleSelectAllWorker

    def initialize(outliner_def)

      @outliner_def = outliner_def

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      # Start model modification operation
      model.start_operation('OCL Outliner Select All', true, false, false)


      begin

        if model.selection.empty?
          model.selection.add(model.active_entities.to_a)
        else
          model.selection.clear
        end

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