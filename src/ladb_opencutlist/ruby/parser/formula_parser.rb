module Ladb::OpenCutList

  require "ripper"

  # Documentation: https://github.com/kddnewton/ripper-docs/tree/main

  class FormulaParser < Ripper

    BLACK_LIST_KW = %w[
      alias
      self
    ]

    BLACK_LIST_COMMAND = %w[
      exec fork spawn system syscall
      abort exit exit! at_exit
      binding send __send__ public_send
      alias_method
      catch fail throw
      eval instance_eval class_eval module_eval instance_exec
      open sysopen load autoload
      require require_relative
      caller caller_locations
      sleep
      puts pp
      gem
      method methods public_methods private_methods singleton_methods
      instance_variable_get instance_variable_set instance_variable_defined? remove_instance_variable
      define_singleton_method define_method remove_method undef_method
      const_get const_set const_defined?
      class_variable_get class_variable_set
      singleton_class extend
    ]

    WHITE_LIST_CONST = %w[
      Math
      Date DateTime Time
    ]

    VOID_STMT = Object.new

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
      _assert_authorized_command(message)
      message
    end

    def on_vcall(ident)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      # puts "on_vcall : #{ident}"
      _assert_authorized_command(ident)
      ident
    end

    def on_call(receiver, operator, message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#call
      # puts "on_call : #{receiver} #{operator} #{message}"
      _assert_authorized_const(receiver)
      _assert_authorized_command(message)
      [ receiver, operator, message ]
    end

    def on_command_call(receiver, operator, method, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      # puts "on_command_call : #{receiver} #{operator} #{method} #{args}"
      _assert_authorized_const(receiver)
      _assert_authorized_command(method)
      [ receiver, operator, method, args ]
    end

    def on_command(message, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      # puts "on_command : #{message} #{args}"
      _assert_authorized_command(message)
      [ message, args ]
    end

    def on_void_stmt
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#void_stmt
      VOID_STMT
    end

    def on_stmts_new
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#stmts_new
      []
    end

    def on_stmts_add(stmts, stmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#stmts_add
      stmts + [ stmt ]
    end

    def on_while(cond, stmts)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#while
      # A "while true; end" style empty-bodied loop never executes any traceable statement, so it
      # can't be interrupted by the instruction-budget guard in CommonEvalFormulaWorker : reject it here.
      raise ForbiddenFormulaError.new("Forbidden empty loop body") if stmts == [ VOID_STMT ]
      [ cond, stmts ]
    end

    def on_until(cond, stmts)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#until
      raise ForbiddenFormulaError.new("Forbidden empty loop body") if stmts == [ VOID_STMT ]
      [ cond, stmts ]
    end

    def on_bodystmt(stmts, rescue_stmt, else_stmt, ensure_stmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#bodystmt
      stmts
    end

    def on_begin(bodystmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#begin
      bodystmt
    end

    def on_while_mod(cond, stmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#while_mod
      raise ForbiddenFormulaError.new("Forbidden empty loop body") if stmt == VOID_STMT || stmt == [ VOID_STMT ]
      [ cond, stmt ]
    end

    def on_until_mod(cond, stmt)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#until_mod
      raise ForbiddenFormulaError.new("Forbidden empty loop body") if stmt == VOID_STMT || stmt == [ VOID_STMT ]
      [ cond, stmt ]
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

    def _assert_authorized_command(thing)
      raise ForbiddenFormulaError.new("Forbidden command : #{thing.value}") if thing.is_a?(Thing) && thing.is_ident? && BLACK_LIST_COMMAND.include?(thing.value)
    end

  end

  class ForbiddenFormulaError < StandardError
  end

end
