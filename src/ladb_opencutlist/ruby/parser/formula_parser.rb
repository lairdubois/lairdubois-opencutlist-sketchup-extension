module Ladb::OpenCutList

  require "ripper"

  # Documentation: https://github.com/kddnewton/ripper-docs/tree/main

  class FormulaParser < Ripper

    BLACK_LIST_IDENT = %w[
      exec fork spawn system syscall
      abort exit exit! at_exit
      binding send
      catch fail throw
      eval instance_eval class_eval module_eval
      open sysopen load autoload require_relative require
      caller caller_locations
      sleep
    ]

    BLACK_LIST_RECEIVER = %w[
      File IO Dir GC Kernel
      Process RubyVM Signal Thread FileUtils FileTest
    ]

    BLACK_LIST_CONST = %w[
      ENV
    ]

    def initialize(formula, data)
      super(formula)

      @data = data

    end

    def tstring_content(value)
      value
    end

    def on_xstring_add(xstring, part)
      part
    end

    def on_ident(value)
      value
    end

    def on_kw(value)
      value
    end

    def on_ivar(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#ivar
      raise ForbiddenFormulaError.new("Undefined variable : #{value}") if @data.nil? || !@data.get_binding.receiver.instance_variables.include?(value.to_sym)
      value
    end

    def on_const(value)
      raise ForbiddenFormulaError.new("Forbidden const : #{value}") if BLACK_LIST_CONST.include?(value)
      value
    end

    def on_var_ref(contents)
      contents
    end

    def on_fcall(message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      raise ForbiddenFormulaError.new("Forbidden fcall : #{message}") if BLACK_LIST_IDENT.include?(message)
      message
    end

    def on_vcall(ident)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      raise ForbiddenFormulaError.new("Forbidden vcall : #{ident}") if BLACK_LIST_IDENT.include?(ident)
      ident
    end

    def on_call(receiver, operator, message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#call
      raise ForbiddenFormulaError.new("Forbidden receiver : #{receiver}") if BLACK_LIST_RECEIVER.include?(receiver)
      raise ForbiddenFormulaError.new("Forbidden call : #{message}") if BLACK_LIST_IDENT.include?(message)
      [ receiver, operator, message ]
    end

    def on_command(message, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      raise ForbiddenFormulaError.new("Forbidden command : #{message}") if BLACK_LIST_IDENT.include?(message)
      [ message, args ]
    end

    def on_undef(methods)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#undef
      raise ForbiddenFormulaError.new("Forbidden undef")
    end

    def on_class(const, superclass, bodystmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#class
      raise ForbiddenFormulaError.new("Forbidden class construct : #{const}")
    end

    def on_module(const, bodystmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#module
      raise ForbiddenFormulaError.new("Forbidden module construct : #{const}")
    end

    def on_def(ident, params, body)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#def
      raise ForbiddenFormulaError.new("Forbidden def ")
    end

    def on_defs(target, operator, ident, params, body)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#defs
      raise ForbiddenFormulaError.new("Forbidden defs")
    end

    def on_xstring_literal(xstring)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#xstring_literal
      raise ForbiddenFormulaError.new("Forbidden xstring : #{xstring}")
    end

    def on_backtick(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#backtick
      raise ForbiddenFormulaError.new("Forbidden backticks : #{value}")
    end

  end

  class ForbiddenFormulaError < StandardError
  end

end
