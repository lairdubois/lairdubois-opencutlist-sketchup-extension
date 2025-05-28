module Ladb::OpenCutList

  require 'Ripper'
  require_relative '../../model/export/export_data'
  require_relative '../../model/export/export_wrapper'

  class CommonEvalFormulaWorker

    CONST_BLACK_LIST = [
      'Kernel',
      'File',
      'Sketchup',
      'Layout',
      'UI'
    ]

    IDENT_BLACK_LIST = [
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
    ]

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

      puts "Run ---"

      begin
        tokens = Ripper.lex(@formula)
        tokens.each do |token|
          pos, type, text, state = token

          puts "#{pos} #{type} #{text} #{state}"

          case type

          when :on_backtick
            throw "Forbidden backtick"

          when :on_const
            throw "Forbidden Const : #{text}" if CONST_BLACK_LIST.include?(text)

          when :on_ident
            throw "Forbidden Identifier : #{text}" if IDENT_BLACK_LIST.include?(text)

          when :on_ivar
            throw "Undefined Variable : #{text}" unless @data.get_binding.receiver.instance_variables.include?(text.to_sym)

          end

        end
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