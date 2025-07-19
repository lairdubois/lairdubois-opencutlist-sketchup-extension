module Ladb::OpenCutList

  class OutlinerInvertSelectWorker

    def initialize(outliner_def)

      @outliner_def = outliner_def

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @outliner_def

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model

      # Start model modification operation
      model.start_operation('OCL Outliner Invert Select', true, false, false)


      model.selection.invert


      # Commit model modification operation
      model.commit_operation

      { :success => true }
    end

    # -----

  end

end