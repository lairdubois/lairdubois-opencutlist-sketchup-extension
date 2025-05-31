module Ladb::OpenCutList

  require "ripper"

  # Documentation: https://github.com/kddnewton/ripper-docs/tree/main

  class FormulaParser < Ripper

    BLACK_LIST_KW = %w[
      alias
    ]

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
      Process RubyVM Signal Thread FileUtils FileTest Dir
      $stdin $stdout $stderr STDIN STDOUT STDERR
    ]

    BLACK_LIST_CONST = %w[
      ENV
    ]

    def initialize(formula, data)
      super(formula)

      @data = data

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
      value
    end

    def on_const(value)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#const
      # puts "on_const : #{value}"
      raise ForbiddenFormulaError.new("Forbidden const : #{value}") if BLACK_LIST_CONST.include?(value)
      value
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
      contents
    end

    def on_const_path_ref(left, const)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#const_path_ref
      # puts "on_const_path_ref : #{left} #{const}"
      raise ForbiddenFormulaError.new("Forbidden receiver : #{left}") if BLACK_LIST_RECEIVER.include?(left)
      [ left, const ]
    end

    def on_xstring_add(xstring, part)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#xstring_add
      # puts "on_xstring_add : #{part}"
      part
    end

    def on_fcall(message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      # puts "on_fcall : #{message}"
      raise ForbiddenFormulaError.new("Forbidden fcall : #{message}") if BLACK_LIST_IDENT.include?(message)
      message
    end

    def on_vcall(ident)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
      # puts "on_vcall : #{ident}"
      raise ForbiddenFormulaError.new("Forbidden vcall : #{ident}") if BLACK_LIST_IDENT.include?(ident)
      ident
    end

    def on_call(receiver, operator, message)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#call
      # puts "on_call : #{receiver} #{operator} #{message}"
      raise ForbiddenFormulaError.new("Forbidden receiver : #{receiver}") if BLACK_LIST_RECEIVER.include?(receiver)
      raise ForbiddenFormulaError.new("Forbidden call : #{message}") if BLACK_LIST_IDENT.include?(message)
      [ receiver, operator, message ]
    end

    def on_command_call(receiver, operator, method, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      # puts "on_command_call : #{receiver} #{operator} #{method} #{args}"
      raise ForbiddenFormulaError.new("Forbidden receiver : #{receiver}") if BLACK_LIST_RECEIVER.include?(receiver)
      raise ForbiddenFormulaError.new("Forbidden method : #{method}") if BLACK_LIST_IDENT.include?(method)
      [ receiver, operator, method, args ]
    end

    def on_command(message, args)
      # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
      # puts "on_command : #{message} #{args}"
      raise ForbiddenFormulaError.new("Forbidden command : #{message}") if BLACK_LIST_IDENT.include?(message)
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

  end

  class ForbiddenFormulaError < StandardError
  end

end
