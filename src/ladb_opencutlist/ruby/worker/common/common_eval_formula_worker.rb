module Ladb::OpenCutList

  require_relative '../../model/export/export_data'
  require_relative '../../model/export/export_wrapper'

  class CommonEvalFormulaWorker

    def initialize(

                  formula:,
                  data:

    )

      @formula = formula
      @data = data

    end

    # -----

    def run
      return { :error => 'default.error' } unless @data.is_a?(ExportData)

      begin
        value = eval(@formula, @data.get_binding)
        value = value.export if value.is_a?(ExportWrapper)
      rescue Exception => e
        value = { :error => e.message.split(/common_eval_formula_worker[.]rb:\d+:/).last } # Remove the path in the exception message
      end

      value
    end

    # -----

  end

end