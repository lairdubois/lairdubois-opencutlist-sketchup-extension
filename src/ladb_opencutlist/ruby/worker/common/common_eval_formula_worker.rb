module Ladb::OpenCutList

  require_relative '../../model/formula/formula_data'
  require_relative '../../model/formula/formula_wrapper'
  require_relative '../../parser/formula_parser'

  class CommonEvalFormulaWorker

    # Maximum number of Ruby-level events (line/call) a single formula may execute. Guards against
    # runaway loops or heavy recursion hanging SketchUp, since eval() itself has no such limit.
    MAX_EVAL_STEPS = 200_000

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

        value = _eval_with_step_limit(@formula, @data.get_binding)  # Discussed here : https://forums.sketchup.com/t/how-to-secure-ruby-code-passed-to-eval/
        value = value.export if value.is_a?(FormulaWrapper)

      rescue Exception => e
        return { :error => _sanitize_error_message(e), error_type: 'exception' }
      end

      value.to_s
    end

    private

    def _eval_with_step_limit(formula, binding)
      steps = 0
      calling_thread = Thread.current

      trace = TracePoint.new(:line, :call, :c_call, :b_call) do |tp|
        next unless Thread.current.equal?(calling_thread)
        steps += 1
        raise FormulaTooComplexError.new('Formula exceeded the maximum number of evaluation steps') if steps > MAX_EVAL_STEPS
      end

      trace.enable do
        eval(formula, binding)
      end
    end

    def _sanitize_error_message(e)
      return e.class unless e.respond_to?(:message)
      message = e.message.split(/common_eval_formula_worker[.]rb:\d+:/).last  # Remove the path in the exception message
      message = message.gsub(/ for #{@data.class.name}:#{@data.class.name}/, '') unless message.nil?
      message = message.gsub(/#{@data.class.name}/, 'Data') unless message.nil?
      message.nil? ? '' : message
    end

  end

  class FormulaTooComplexError < StandardError
  end

end