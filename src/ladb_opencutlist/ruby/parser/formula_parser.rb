module Ladb::OpenCutList

  require "ripper"

  # Documentation: https://github.com/kddnewton/ripper-docs/tree/main

  class FormulaParser < Ripper

    BLACK_LIST_KW = %w[
      alias self
    ]

    BLACK_LIST_METHOD = %w[
      exec fork spawn system syscall
      abort exit exit! at_exit
      binding send
      catch fail throw
      eval instance_eval class_eval module_eval
      open sysopen load autoload require_relative require
      caller caller_locations
      sleep
    ]

    WHITE_LIST_CONST = %w[
      Math
    ]

    TYPE_IDENT = 0
    TYPE_CONST = 1

    Thing = Struct.new(:value, :type) do
      def is_ident?
        type == TYPE_IDENT
      end
      def is_const?
        type == TYPE_CONST
      end
      def to_s
        value
      end
    end

    def initialize(formula, data)
      super(formula)

      @data = data

      # puts Ripper.sexp(formula)

    end

    # -- EVENTS

    def on_kw(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#kw
      # puts "on_kw : #{value}"
      raise ForbiddenFormulaError.new("Forbidden keyword : #{value}") if BLACK_LIST_KW.include?(value)
      value
    end

    def on_ident(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#ident
      # puts "on_ident : #{value}"
      Thing.new(value, TYPE_IDENT)
    end

    def on_const(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#const
      # puts "on_const : #{value}"
      Thing.new(value, TYPE_CONST)
    end

    def on_gvar(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#gvar
      # puts "on_gvar : #{value}"
      raise ForbiddenFormulaError.new("Forbidden global variable : #{value}")
    end

    def on_ivar(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#ivar
      # puts "on_ivar : #{value}"
      raise ForbiddenFormulaError.new("Undefined variable : #{value}") if @data.nil? || !@data.get_binding.receiver.instance_variables.include?(value.to_sym)
      value
    end

    def on_var_ref(contents)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#var_ref
      # puts "on_var_ref : #{contents}"
      _assert_authorized_const(contents)
      contents
    end

    def on_const_path_ref(left, const)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#const_path_ref
      # puts "on_const_path_ref : #{left} #{const}"
      _assert_authorized_const(left)
      [ left, const ]
    end

    def on_fcall(message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      # puts "on_fcall : #{message}"
      _assert_authorized_method(message)
      message
    end

    def on_vcall(ident)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      # puts "on_vcall : #{ident}"
      _assert_authorized_method(ident)
      ident
    end

    def on_call(receiver, operator, message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#call
      # puts "on_call : #{receiver} #{operator} #{message}"
      _assert_authorized_const(receiver)
      _assert_authorized_method(message)
      [ receiver, operator, message ]
    end

    def on_command_call(receiver, operator, method, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      # puts "on_command_call : #{receiver} #{operator} #{method} #{args}"
      _assert_authorized_const(receiver)
      _assert_authorized_method(method)
      [ receiver, operator, method, args ]
    end

    def on_command(message, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      # puts "on_command : #{message} #{args}"
      _assert_authorized_method(message)
      [ message, args ]
    end

    def on_undef(methods)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#undef
      # puts "on_undef : #{methods}"
      raise ForbiddenFormulaError.new("Forbidden undef")
    end

    def on_def(ident, params, body)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#def
      # puts "on_def : #{ident} #{params} #{body}"
      raise ForbiddenFormulaError.new("Forbidden def")
    end

    def on_defs(target, operator, ident, params, body)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#defs
      # puts "on_defs : #{target} #{operator} #{ident} #{params} #{body}"
      raise ForbiddenFormulaError.new("Forbidden defs")
    end

    def on_class(const, superclass, bodystmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#class
      # puts "on_class : #{const} #{superclass} #{bodystmt}"
      raise ForbiddenFormulaError.new("Forbidden class construct : #{const}")
    end

    def on_module(const, bodystmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#module
      # puts "on_module : #{const} #{bodystmt}"
      raise ForbiddenFormulaError.new("Forbidden module construct : #{const}")
    end

    def on_xstring_add(xstring, part)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#xstring_add
      # puts "on_xstring_add : #{part}"
      part
    end

    def on_xstring_literal(xstring)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#xstring_literal
      # puts "on_xstring_literal : #{xstring}"
      raise ForbiddenFormulaError.new("Forbidden xstring : #{xstring}")
    end

    def on_backtick(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#backtick
      # puts "on_backtick : #{value}"
      raise ForbiddenFormulaError.new("Forbidden backticks : #{value}")
    end

    def on_program(stmts_add)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#program
      # puts "on_program : #{stmts_add}"
      true
    end

    private

    def _assert_authorized_const(thing)
      raise ForbiddenFormulaError.new("Forbidden const : #{thing.value}") if thing.is_a?(Thing) && thing.is_const? && !WHITE_LIST_CONST.include?(thing.value)
    end

    def _assert_authorized_method(thing)
      raise ForbiddenFormulaError.new("Forbidden method : #{thing.value}") if thing.is_a?(Thing) && thing.is_ident? && BLACK_LIST_METHOD.include?(thing.value)
    end

  end

  class ForbiddenFormulaError < StandardError
  end

end
