module Ladb::OpenCutList

  require_relative '../../model/formula/formula_data'
  require_relative '../../model/formula/formula_wrapper'
  require_relative '../../parser/formula_parser'

  class CommonEvalFormulaWorker

    def initialize(

                  formula:,
                  data:

    )

      @formula = formula.to_s
      @data = data

    end

    # -----

    def run
      return { :error => 'default.error' } unless @data.is_a?(FormulaData)

      begin

        # This parser is designed to generate an error if the input formula contains a forbidden keyword, command, or const usage
        FormulaParser.new(@formula, @data).parse

      rescue ForbiddenFormulaError => e
        return { :error => _sanitize_error_message(e), error_type: 'forbidden' }
      end

      begin

        value = eval(@formula, @data.get_binding)  # Discussed here : https://forums.sketchup.com/t/how-to-secure-ruby-code-passed-to-eval/
        value = value.export if value.is_a?(FormulaWrapper)

      rescue Exception => e
        return { :error => _sanitize_error_message(e), error_type: 'exception' }
      end

      value.to_s
    end

    private

    def _sanitize_error_message(e)
      return e.class unless e.respond_to?(:message)
      message = e.message.split(/common_eval_formula_worker[.]rb:\d+:/).last  # Remove the path in the exception message
      message = message.gsub(/ for #{@data.class.name}:#{@data.class.name}/, '') unless message.nil?
      message = message.gsub(/#{@data.class.name}/, 'Data') unless message.nil?
      message.nil? ? '' : message
    end

  end

end