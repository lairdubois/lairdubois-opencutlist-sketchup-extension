require "ripper"

# documentation: https://github.com/kddnewton/ripper-docs/tree/main

class FormulaParser < Ripper

  # not part of the list
  # raise
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

  WHITE_LIST_CONST = %w[
    Math
  ]

  def initialize(formula, data)
    super(formula)

    @data = data

  end

  def tstring_content(value)
    return value
  end

  def on_xstring_add(xstring, part)
    return part
  end

  def on_ident(value)
    return value
  end

  def on_kw(value)
    return value
  end

  def on_ivar(value)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#ivar
    raise InvalidFormulaError.new("Undefined variable : #{value}") if @data.nil? || !@data.get_binding.receiver.instance_variables.include?(value.to_sym)
    return value
  end

  def on_const(value)
    raise InvalidFormulaError.new("Forbidden const : #{value}") unless WHITE_LIST_CONST.include?(value)
    return value
  end

  def on_var_ref(contents)
    return contents
  end

  #def on_method_add_arg(method, args)
  #  puts "method_add_args #{method} #{args}"
  #end

  def on_fcall(message)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
    raise InvalidFormulaError.new("Forbidden fcall : #{message}") if BLACK_LIST_IDENT.include?(message)
  end

  def on_vcall(ident)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#fcall
    raise InvalidFormulaError.new("Forbidden vcall : #{ident}") if BLACK_LIST_IDENT.include?(ident)
  end

  def on_call(receiver, operator, message)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#call
    if BLACK_LIST_RECEIVER.include?(receiver)
      raise InvalidFormulaError.new("Forbidden receiver : #{receiver}")
    else
      puts "allowed call -#{receiver}/#{operator}/#{message}-"
    end
    return [ receiver, operator, message ]
  end

  def on_command(message, args)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#command
    raise InvalidFormulaError.new("Forbidden command : #{message}") if BLACK_LIST_IDENT.include?(message)
  end

  def on_undef(methods)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#undef
    raise InvalidFormulaError.new("Forbidden undef")
  end

  def on_class(const, superclass, bodystmt)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#class
    raise InvalidFormulaError.new("Forbidden class construct : #{const}")
  end

  def on_module(const, bodystmt)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#module
    raise InvalidFormulaError.new("Forbidden module construct : #{const}")
  end

  def on_def(ident, params, body)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#def
    raise InvalidFormulaError.new("Forbidden def : #{ident}") if BLACK_LIST_IDENT.include?(ident)
  end

  def on_xstring_literal(xstring)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#xstring_literal
    raise InvalidFormulaError.new("Forbidden xstring : #{xstring}")
  end

  def on_backtick(value)
    # https://github.com/kddnewton/ripper-docs/blob/main/events.md#backtick
    raise InvalidFormulaError.new("Forbidden backticks : #{value}")
  end

end

class InvalidFormulaError < StandardError
end
