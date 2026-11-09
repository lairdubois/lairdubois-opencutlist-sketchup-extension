module Ladb::OpenCutList

  require 'ripper'

  # Validates a user-authored formula before CommonEvalFormulaWorker evaluates it.
  #
  # The formula is parsed into a Ripper s-expression tree that is walked node by node against
  # WHITE LISTS : only the listed syntax nodes, method names, functions, constants and operators
  # are accepted, anything else raises a ForbiddenFormulaError. Nothing is evaluated here.
  #
  # Documentation: https://github.com/kddnewton/ripper-docs/tree/main
  #
  # Keep in mind that the s-expression shapes vary between Ruby versions (2.2 for SketchUp 2017
  # up to the latest one) : each node handler below accepts all the known shapes.
  class FormulaParser

    # -- Methods ---------------------------------------------------------------------------------

    # Method names that may be called on any receiver (`receiver.name`). The check is by name only,
    # whatever the receiver is : a name allowed here must be harmless on every object a formula can
    # reach (Ruby core values, formula wrappers, and the SketchUp entities behind them).
    WHITE_LIST_METHOD = %w[

      + - * / % ** == != < > <= >= <=> =~ !~ [] ! & | ^ << >> -@ +@ ~

      nil? empty? any? none? zero? positive? negative? even? odd? between? clamp
      eql? equal? respond_to? frozen? dup clone freeze itself

      to_s to_i to_f to_r to_a to_h to_l to_str to_ary
      round floor ceil abs divmod modulo remainder fdiv succ pred
      to_mm to_cm to_m to_km to_inch to_feet to_yard to_mile to_fbm

      length size count
      upcase downcase capitalize swapcase
      strip lstrip rstrip chomp chop squeeze
      sub gsub tr tr_s delete_prefix delete_suffix
      split lines chars bytes scan match match? captures named_captures pre_match post_match
      include? start_with? end_with? index rindex
      ljust rjust center
      slice reverse
      encode force_encoding unicode_normalize

      first last take drop
      join map collect flat_map select filter reject find detect find_index partition group_by
      each each_with_index each_with_object with_index each_slice each_cons
      sort sort_by min max min_by max_by minmax sum inject reduce tally
      uniq compact flatten zip product rotate sample shuffle
      keys values key? has_key? value? has_value? fetch dig
      all?

      today now year month day hour min sec wday yday strftime iso8601
      new
      sqrt cbrt sin cos tan asin acos atan atan2 sinh cosh tanh log log2 log10 exp hypot

      name description url type color red green blue alpha
      display_name
      std_dimension std_thickness std_width
      length_oversize width_oversize thickness_oversize
      grained?
      is_solid_wood? is_sheet_good? is_dimensional? is_hardware? is_edge? is_veneer?
      material_name material_color
      local_x local_y local_z world_x world_y world_z
      definition names position
      get_attribute get_dc_attribute
      guid persistent_id typename layer material hidden? visible? volume manifold?
      bounds width height depth center corner origin x y z
      zone column row model_key front? function_unit

    ].freeze

    # Functions that may be called without receiver (`name(...)`) : the FormulaData helpers and a few
    # Kernel conversions.
    WHITE_LIST_FUNCTION = %w[
      word_wrap
      format sprintf
      Integer Float Rational
    ].freeze

    # Constants a formula may reference.
    WHITE_LIST_CONST = %w[
      Math
      Date DateTime Time
    ].freeze

    # Constants allowed on the right side of `::`, after a white listed constant (ex : Math::PI).
    WHITE_LIST_CONST_PATH = %w[
      PI E
      MONTHNAMES ABBR_MONTHNAMES DAYNAMES ABBR_DAYNAMES
    ].freeze

    # Operators of the `binary` and `unary` nodes.
    WHITE_LIST_BINARY_OPERATOR = %w[
      + - * / % ** == != === < > <= >= <=> =~ !~ && || and or & | ^ << >>
    ].freeze
    WHITE_LIST_UNARY_OPERATOR = %w[
      -@ +@ ! not ~
    ].freeze

    # Keywords usable as values.
    WHITE_LIST_KEYWORD = %w[
      true false nil
    ].freeze

    # -- Syntax ----------------------------------------------------------------------------------

    # Nodes whose children are simply walked (the nodes that need a specific check have their own
    # handler in _check_node). Any node missing from both is rejected.
    WHITE_LIST_NODE = %i[
      program
      void_stmt paren
      string_literal string_content string_embexpr string_dvar string_concat
      regexp_literal
      array words_new words_add word_new word_add qwords_new qwords_add word
      hash assoclist_from_args assoc_new bare_assoc_hash
      dot2 dot3
      ifop if unless elsif else if_mod unless_mod
      case when
      break next
      aref
      args_new args_add args_add_block args_add_star arg_paren
      brace_block do_block block_var params rest_param excessed_comma mlhs_paren mlhs_add mlhs_new
      method_add_arg method_add_block
    ].freeze

    # Leaf tokens accepted anywhere they are walked to.
    WHITE_LIST_TOKEN = %i[
      @int @float @rational @imaginary @CHAR
      @tstring_content @label @regexp_end
      @backref
      @ident
    ].freeze

    # -- Runtime ---------------------------------------------------------------------------------

    # Not used by the static check above : these methods are removed at runtime from the formula
    # receivers (FormulaData, FormulaWrapper), as a defense in depth in case a forbidden call slips
    # through. None of them may ever enter the white lists (see TC_Ladb_Parser_FormulaParser).
    RUNTIME_FORBIDDEN_METHODS = %w[
      exec fork spawn system syscall
      abort exit exit! at_exit
      binding send __send__ public_send
      alias_method
      catch fail throw
      eval instance_eval class_eval module_eval instance_exec class_exec module_exec
      open sysopen load autoload
      require require_relative
      caller caller_locations
      sleep
      puts pp p print printf putc display warn
      gem
      method methods public_methods private_methods singleton_methods
      instance_variable_get instance_variable_set instance_variable_defined? remove_instance_variable
      define_singleton_method define_method remove_method undef_method
      const_get const_set const_defined? remove_const
      class_variable_get class_variable_set
      singleton_class extend
      class superclass ancestors included_modules constants
      instance_method instance_methods public_method public_instance_method public_instance_methods
      attr attr_accessor attr_reader attr_writer include prepend module_function private public protected
      to_proc to_sym intern call curry
      popen read write readlines readline gets foreach binread binwrite sysread syswrite
      glob mkdir rmdir unlink chmod chown symlink truncate test
      set_trace_func trace_var untrace_var
    ].freeze

    # Forbidden names that must stay defined on the formula receivers because the extension itself
    # relies on them (ex : `self.class.new` in the wrappers).
    RUNTIME_KEPT_METHODS = %w[
      binding
      class
    ].freeze

    # Collects the syntax error message, as Ripper.sexp only returns nil.
    class SexpBuilder < Ripper::SexpBuilderPP

      attr_reader :error

      def on_parse_error(message)
        @error ||= message
      end

      def compile_error(message)
        @error ||= message
      end

    end

    def initialize(formula, data)
      @formula = formula.to_s
      @data = data
    end

    def parse
      builder = SexpBuilder.new(@formula)
      sexp = builder.parse
      raise ForbiddenFormulaError.new("Syntax error : #{builder.error}") if sexp.nil? || builder.error
      _check(sexp)
      true
    end

    private

    # -- Walk

    def _check(item)
      return unless item.is_a?(Array)
      if item.first.is_a?(Symbol)
        _check_node(item)
      else
        item.each { |child| _check(child) }   # A list of nodes
      end
    end

    def _check_children(node)
      node[1..-1].each { |child| _check(child) }
    end

    def _check_node(node)
      type = node.first
      case type

      # -- Values

      when :var_ref
        _check_var_ref(node[1])

      when :var_field
        token = node[1]
        _forbid("assignment to #{_token_value(token)}") unless _token_type(token) == :@ident

      when :assign
        _check(node[1])
        _check(node[2])

      when :opassign
        _check(node[1])
        _check(node[3])

      when :symbol_literal
        _check_symbol(node[1])

      when :const_path_ref
        # [:const_path_ref, left, const] : `Math::PI`, never `<expression>::Const`
        const = node[2]
        name = _token_type(const) == :@const ? "#{_const_label(node[1])}::#{const[1]}" : _node_label(const)
        _forbid("const #{name}") unless _white_listed_const?(node[1]) && _token_type(const) == :@const && WHITE_LIST_CONST_PATH.include?(const[1])

      # -- Operators

      when :binary
        _forbid("operator #{node[2]}") unless WHITE_LIST_BINARY_OPERATOR.include?(node[2].to_s)
        _check(node[1])
        _check(node[3])

      when :unary
        _forbid("operator #{node[1]}") unless WHITE_LIST_UNARY_OPERATOR.include?(node[1].to_s)
        _check(node[2])

      # -- Calls

      when :call, :command_call
        # [:call, receiver, operator, name] / [:command_call, receiver, operator, name, args]
        _check(node[1])
        _check_call_operator(node[2])
        _check_method_name(node[3])
        _check(node[4]) if type == :command_call

      when :fcall, :vcall
        _check_function_name(node[1])

      when :command
        _check_function_name(node[1])
        _check(node[2])

      when :args_add_block
        # [:args_add_block, args, block] : the block argument is either false or `&:symbol`
        _check(node[1])
        block = node[2]
        if block
          _forbid('block argument') unless block.is_a?(Array) && block.first == :symbol_literal
          _check(block)
        end

      # -- Control

      when :while, :until, :while_mod, :until_mod
        # An empty loop body runs no traceable statement : the step limit guard of CommonEvalFormulaWorker
        # can't interrupt it
        _forbid('empty loop body') if _empty_body?(node[2])
        _check_children(node)

      when :begin
        _check(node[1])

      when :bodystmt
        # [:bodystmt, stmts, rescue, else, ensure] : a rescue could swallow the step limit error
        _forbid('rescue / ensure') if node[2] || node[3] || node[4]
        _check(node[1])

      else
        if type.to_s.start_with?('@')
          _forbid("token #{type}") unless WHITE_LIST_TOKEN.include?(type)
        elsif WHITE_LIST_NODE.include?(type)
          _check_children(node)
        else
          _forbid("syntax #{type}")
        end

      end
    end

    # -- Checks

    def _check_var_ref(token)
      case _token_type(token)
      when :@ident
        # A local variable
      when :@ivar
        _forbid_undefined_variable(token[1]) if @data.nil? || !@data.instance_variables.include?(token[1].to_sym)
      when :@const
        _check_const([ :var_ref, token ])
      when :@kw
        _forbid("keyword #{token[1]}") unless WHITE_LIST_KEYWORD.include?(token[1])
      when :@backref
        # $1, $2… after a match
      else
        _forbid(_token_value(token))
      end
    end

    def _check_const(node)
      _forbid("const #{_const_label(node)}") unless _white_listed_const?(node)
    end

    def _white_listed_const?(node)
      # Only a white listed constant, referenced directly (never a computed value followed by `::`)
      token = node.is_a?(Array) && node.first == :var_ref ? node[1] : nil
      _token_type(token) == :@const && WHITE_LIST_CONST.include?(token[1])
    end

    def _const_label(node)
      token = node.is_a?(Array) && node.first == :var_ref ? node[1] : nil
      _token_type(token) == :@const ? token[1] : '(expression)'
    end

    def _check_symbol(symbol)
      # [:symbol, token] (or the bare token on some Ruby versions). A symbol can name a method called
      # indirectly (`map(&:name)`, `inject(:+)`) : it must be a white listed method name.
      token = symbol.is_a?(Array) && symbol.first == :symbol ? symbol[1] : symbol
      name = _token_value(token)
      _forbid("symbol :#{name}") unless [ :@ident, :@op, :@const, :@kw ].include?(_token_type(token)) && WHITE_LIST_METHOD.include?(name)
    end

    def _check_call_operator(operator)
      value = operator.is_a?(Symbol) ? operator.to_s : _token_value(operator)
      _forbid("call operator #{value}") unless [ '.', '&.', '::' ].include?(value)
    end

    def _check_method_name(token)
      _forbid("method #{_node_label(token)}") unless [ :@ident, :@op, :@const, :@kw ].include?(_token_type(token))
      _forbid("method #{token[1]}") unless WHITE_LIST_METHOD.include?(token[1])
    end

    def _check_function_name(token)
      _forbid("method #{_node_label(token)}") unless [ :@ident, :@const ].include?(_token_type(token))
      _forbid("method #{token[1]}") unless WHITE_LIST_FUNCTION.include?(token[1])
    end

    # -- Utils

    def _empty_body?(body)
      return true if body.nil? || body == [ :void_stmt ] || body == [ [ :void_stmt ] ]
      return _empty_body?(body[1]) if body.is_a?(Array) && [ :begin, :bodystmt ].include?(body.first)   # `begin; end while true`
      false
    end

    def _token_type(token)
      token.is_a?(Array) && token.first.is_a?(Symbol) && token.first.to_s.start_with?('@') ? token.first : nil
    end

    def _token_value(token)
      _token_type(token) ? token[1].to_s : _node_label(token)
    end

    def _node_label(node)
      node.is_a?(Array) && node.first.is_a?(Symbol) ? node.first.to_s : node.to_s
    end

    def _forbid(what)
      raise ForbiddenFormulaError.new("Forbidden #{what}")
    end

    def _forbid_undefined_variable(name)
      raise ForbiddenFormulaError.new("Undefined variable : #{name}")
    end

  end

  class ForbiddenFormulaError < StandardError
  end

end
