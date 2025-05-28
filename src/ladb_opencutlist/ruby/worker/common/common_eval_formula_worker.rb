module Ladb::OpenCutList

  require 'Ripper'
  require_relative '../../model/export/export_data'
  require_relative '../../model/export/export_wrapper'

  class CommonEvalFormulaWorker

    BLACK_LIST = {
      :var_ref => [
        'Kernel',
        'File',
        'Sketchup',
        'Layout',
        'UI',
        'Ladb'
      ],
      :fcall => [
        'eval',
        'exec',
        'system',
        'syscall',
        'exit',
        'exit!',
        'binding',
        'send',
        'fail'
      ],
      :call => [
        'eval',
        'instance_eval',
        'class_eval',
        'module_eval',
        'exec',
        'system',
        'syscall',
        'exit',
        'exit!',
        'binding',
        'fail'
      ],
      :vcall => [
        'eval',
        'exec',
        'system',
        'syscall',
        'exit',
        'exit!',
        'binding',
        'send',
        'fail'
      ],
    }

    def initialize(

                  formula:,
                  data:

    )

      @formula = formula.to_s
      @data = data

    end

    # -----

    def run
      return { :error => 'default.error' } unless @data.is_a?(ExportData)

      begin

        sexp = Ripper.sexp(@formula)
        puts sexp.inspect
        _check(sexp)

        value = eval(@formula, @data.get_binding)
        value = value.export if value.is_a?(ExportWrapper)

      rescue Exception => e
        value = { :error => e.message.split(/common_eval_formula_worker[.]rb:\d+:/).last } # Remove the path in the exception message
      end

      value
    end

    # -----

    def _check(sexp, prev_symbol = nil)
      if sexp.is_a?(Array)
        if sexp[0].is_a?(Symbol)
          symbol, text = sexp
          case symbol

          when :xstring_literal
            # xstring_literal
            raise "Forbidden Backtick"

          when :@const
            # var_ref
            raise "Forbidden Const : #{text}" if BLACK_LIST[prev_symbol] && BLACK_LIST[prev_symbol].include?(text)

          when :@ident
            # fcall | call | vcall
            raise "Forbidden Call : #{text}" if BLACK_LIST[prev_symbol] && BLACK_LIST[prev_symbol].include?(text)

          when :@ivar
            # var_ref
            raise "Undefined variable : #{text}" unless prev_symbol == :var_ref && @data.get_binding.receiver.instance_variables.include?(text)

          end
          prev_symbol = symbol
          sexp = sexp[1..-1]
        end
        sexp.each do |exp|
          _check(exp, prev_symbol)
        end
      end
    end

  end

end