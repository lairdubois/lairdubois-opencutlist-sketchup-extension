module Ladb::OpenCutList

  # Evaluates length expressions : "2m*(2+3)", "@/2", "@thickness - 2mm",
  # "min(@thickness - 5mm; 20mm)", "floor(@thickness - 5mm; 12mm; 15mm; 20mm)".
  # Shared by the VCB - see UserTextHelper - and the hardware descriptors,
  # which only differ by how they read a bare number and a variable : the
  # caller gives both as lambdas, the arithmetic is here.
  #
  # Values are [ number, dimension ] : dimension is 1 for a length, 0 for a
  # factor, or nil when it isn't checked - the VCB computes in model units,
  # where a bare number is a length as well as a factor.
  module LengthExpressionUtils

    # An expression that can't be evaluated. key : the i18n key of the
    # reason under 'tool.default.error.', params : its parameters.
    class LengthExpressionError < StandardError
      attr_reader :key, :params
      def initialize(key, params = {}, message = nil)
        super(message || key)
        @key = key
        @params = params
      end
    end

    # The length units a literal can bear - a hardware descriptor's
    # "length_unit" is one of them - and how many inches each is : [
    # numerator, denominator ], 30mm is 30 / 25.4 exactly as SketchUp reads it.
    UNIT_INCHES = {
      'mm' => [ 1.0, 25.4 ],
      'cm' => [ 1.0, 2.54 ],
      'm' => [ 1.0, 0.0254 ],
      'in' => [ 1.0, 1.0 ],
      'ft' => [ 12.0, 1.0 ],
      'yd' => [ 36.0, 1.0 ],
    }.freeze
    LENGTH_UNITS = UNIT_INCHES.keys.freeze

    # Inches and feet are also written " and ', or ″ and ′ - in and ft spare
    # JSON the escaped ".
    INCH_MARK = %q{(?:in(?![a-z])|"|″)}.freeze
    FOOT_MARK = %q{(?:ft(?![a-z])|'|′)}.freeze
    UNIT_MARK = %Q{(?:(?:mm|cm|m|yd)(?![a-z])|#{INCH_MARK}|#{FOOT_MARK})}.freeze
    NUMBER = '(?:\\d+\\s+\\d+\\/\\d+|\\d+\\/\\d+|\\d+(?:[.,]\\d+)*|[.,]\\d+)'.freeze

    # A literal : feet and inches - 1' 6" - a number - a whole and a
    # fraction - 1 1/2 - a fraction - 3/4 - or a decimal - 2,5 - with an
    # optional unit - 2.5 cm, 3/4in. A number after feet is inches : 1'6 is
    # 18", whatever the model's unit.
    LITERAL_PATTERN = /\G(?:\d+\s*#{FOOT_MARK}\s*#{NUMBER}(?:\s*#{INCH_MARK})?|#{NUMBER}(?:\s*#{UNIT_MARK})?)/i
    LITERAL_PARTS_PATTERN = /\A(?:(\d+)\s*#{FOOT_MARK}\s*(?=\d|[.,]\d))?(#{NUMBER})\s*(#{UNIT_MARK})?\z/i
    VARIABLE_PATTERN = /\G@([A-Za-z_]\w*)?/
    OPERATOR_PATTERN = /\G[-+*\/();]/
    FUNCTION_PATTERN = /\G(min|max|floor|ceil)\s*(?=\()/i

    # The arguments of a function are separated by ';' - or by ',' right
    # after a unit, a variable or a parenthesis : "min(10mm, 20mm)". ',' is
    # also a decimal separator : "min(10,5; 20)", and "min(8,12)" is one
    # argument - an error that asks for ';'.
    ARGUMENT_SEPARATOR = ';'.freeze

    # A function of at least two values of the same dimension :
    #  - min, max : the smallest, the largest ;
    #  - floor, ceil : the largest of the values after the first that is not
    #    above it, the smallest that is not below it - the steps a machine is
    #    set to : "floor(@thickness - 5mm; 12mm; 15mm; 20mm)". None is an error.
    FunctionToken = Struct.new(:name)

    # How far a value may miss a step and still take it
    STEP_TOLERANCE = 1e-6

    # The [ number, dimension ] of the given expression.
    #  - read_literal : lambda(String) -> [ number, dimension ] of a literal ;
    #  - read_variable : lambda(String) -> [ number, dimension ] of a variable,
    #    its name - '' for a lone '@'.
    # Raises LengthExpressionError.
    def self.evaluate(text, read_literal:, read_variable:)
      tokens = _tokenize(text.to_s, read_literal, read_variable)
      raise LengthExpressionError.new('missing_operand') if tokens.empty?
      value, index = _parse_sum(tokens, 0)
      _check_end(tokens, index)
      value[0..1]
    end

    # Does the given expression use variables ?
    def self.variables?(text)
      text.is_a?(String) && text.include?('@')
    end

    # Does the given expression call a function ?
    def self.functions?(text)
      text.is_a?(String) && text =~ /\b(min|max|floor|ceil)\s*\(/i ? true : false
    end

    # The names of the variables the given expression uses.
    def self.variable_names(text)
      return [] unless text.is_a?(String)
      text.scan(/@([A-Za-z_]\w*)?/).map { |name| name.first.to_s }.uniq
    end

    # The given literal - with a unit - in inches, whatever the model's unit
    # and decimal separator. Raises ArgumentError.
    def self.literal_to_inches(literal)
      match = LITERAL_PARTS_PATTERN.match(literal.to_s.strip)
      raise ArgumentError, "invalid length #{literal.inspect}" if match.nil? || match[3].nil? && match[1].nil?
      feet, number, unit = match.captures
      unit = _unit_name(unit)
      raise ArgumentError, "invalid length #{literal.inspect}" unless feet.nil? || unit.nil? || unit == 'in'
      return feet.to_i * 12.0 + bare_number_value(number) unless feet.nil?
      numerator, denominator = UNIT_INCHES[unit]
      bare_number_value(number) * numerator / denominator
    end

    # Is the given literal a bare number - no unit - ?
    def self.bare_number?(literal)
      literal !~ /[a-z'"″′]/i
    end

    # The value of the given bare number - "1 1/2", "3/4", "2,5", "2.5" -
    # whatever the decimal separator. Raises ArgumentError.
    def self.bare_number_value(literal)
      literal.to_s.strip.split(/\s+/).map { |part|
        if part.include?('/')
          numerator, denominator = part.split('/')
          raise ArgumentError, "invalid number #{literal.inspect}" if denominator.to_i == 0
          numerator.to_f / denominator.to_i
        else
          decimal = part.tr(',', '.')
          raise ArgumentError, "invalid number #{literal.inspect}" unless decimal =~ /\A(\d+(\.\d+)?|\.\d+)\z/
          decimal.to_f
        end
      }.reduce(:+)
    end

    # The given expression with the given unit - one of LENGTH_UNITS - given
    # to each of its bare numbers that stands for a length - "@thickness - 2"
    # -> "@thickness - 2mm", "8" -> "8mm" - its factors left as they are -
    # "@length / 2". The expression is a length : a bare number is a length
    # as a term of it, of a sum or of a function, and in a product, unless
    # the other operand is a length - or the divisor. What a hardware
    # descriptor's "length_unit" means. Raises LengthExpressionError.
    def self.with_unit(text, unit)
      raise ArgumentError, "unknown unit #{unit.inspect}" unless LENGTH_UNITS.include?(unit)
      text = text.to_s
      spans = []
      tokens = _tokenize(text, lambda { |literal| [ 0.0, bare_number?(literal) ? nil : 1 ] }, lambda { |_| [ 0.0, 1 ] }, spans)
      raise LengthExpressionError.new('missing_operand') if tokens.empty?
      node, index = _node_sum(tokens, 0)
      _check_end(tokens, index)
      lengths = []
      _assign_dimension(node, 1, lengths)
      lengths.sort.reverse_each { |i| text = text[0...spans[i][1]] + unit + text[spans[i][1]..-1] }
      text
    end

    # -----

    # The tokens of the given text : literals and variables as [ number,
    # dimension ] - a literal's text after them - operators, '(', ')' and
    # ARGUMENT_SEPARATOR as strings, functions as FunctionTokens. spans :
    # filled with the [ start, end ] of each token in the text, if given.
    def self._tokenize(text, read_literal, read_variable, spans = nil)
      tokens = []
      position = 0
      while position < text.length
        start = position
        if text[position] =~ /\s/
          position += 1
          next
        elsif text[position] == ',' && (tokens.last.is_a?(Array) || tokens.last == ')')
          tokens << ARGUMENT_SEPARATOR
          position += 1
        elsif (match = LITERAL_PATTERN.match(text, position)) && !match[0].empty?
          literal = match[0].strip
          begin
            tokens << read_literal.call(literal)[0..1] + [ literal ]
          rescue LengthExpressionError
            raise
          rescue StandardError => e
            raise LengthExpressionError.new('syntax_error', { :error => e.message }, e.message)
          end
          position = match.end(0)
        elsif (match = VARIABLE_PATTERN.match(text, position))
          tokens << read_variable.call(match[1].to_s)
          position = match.end(0)
        elsif (match = FUNCTION_PATTERN.match(text, position))
          tokens << FunctionToken.new(match[1].downcase)
          position = match.end(0)
        elsif (match = OPERATOR_PATTERN.match(text, position))
          tokens << match[0]
          position = match.end(0)
        else
          raise LengthExpressionError.new('syntax_error', { :error => text[position..-1] }, text[position..-1])
        end
        spans << [ start, position ] unless spans.nil?
      end
      tokens
    end
    private_class_method :_tokenize

    # Raises unless the expression ends at the given index of its tokens.
    def self._check_end(tokens, index)
      return if index >= tokens.length
      raise LengthExpressionError.new('unexpected_close_parenthesis') if tokens[index] == ')'
      raise LengthExpressionError.new('missing_operand')
    end
    private_class_method :_check_end

    # The canonical name of the given unit mark - see UNIT_INCHES - nil for none.
    def self._unit_name(mark)
      return nil if mark.nil?
      mark = mark.downcase
      return 'in' if mark =~ /\A#{INCH_MARK}\z/
      return 'ft' if mark =~ /\A#{FOOT_MARK}\z/
      mark
    end
    private_class_method :_unit_name

    # sum = product (('+' | '-') product)*
    def self._parse_sum(tokens, index)
      value, index = _parse_product(tokens, index)
      while %w[+ -].include?(tokens[index])
        operator = tokens[index]
        other, index = _parse_product(tokens, index + 1)
        dimension = _dimension(value[1], other[1]) { |a, b| a == b ? a : nil }
        raise LengthExpressionError.new('invalid_dimension') if dimension == false
        value = [ operator == '+' ? value[0] + other[0] : value[0] - other[0], dimension ]
      end
      [ value, index ]
    end
    private_class_method :_parse_sum

    # product = factor (('*' | '/') factor)*
    def self._parse_product(tokens, index)
      value, index = _parse_factor(tokens, index)
      while %w[* /].include?(tokens[index])
        operator = tokens[index]
        other, index = _parse_factor(tokens, index + 1)
        if operator == '*'
          dimension = _dimension(value[1], other[1]) { |a, b| a + b <= 1 ? a + b : nil }
          number = value[0] * other[0]
        else
          raise LengthExpressionError.new('zero_division') if other[0] == 0
          dimension = _dimension(value[1], other[1]) { |a, b| a - b >= 0 ? a - b : nil }
          number = value[0] / other[0]
        end
        raise LengthExpressionError.new('invalid_dimension') if dimension == false
        value = [ number, dimension ]
      end
      [ value, index ]
    end
    private_class_method :_parse_product

    # factor = ('+' | '-') factor | '(' sum ')' | function '(' sum (';' sum)+ ')' | value
    def self._parse_factor(tokens, index)
      token = tokens[index]
      case token
      when nil, '*', '/', ')', ARGUMENT_SEPARATOR
        raise LengthExpressionError.new(token == ')' ? 'unexpected_close_parenthesis' : 'missing_operand')
      when '+', '-'
        value, index = _parse_factor(tokens, index + 1)
        [ [ token == '-' ? -value[0] : value[0], value[1] ], index ]
      when '('
        value, index = _parse_sum(tokens, index + 1)
        raise LengthExpressionError.new('missing_close_parenthesis') unless tokens[index] == ')'
        [ value, index + 1 ]
      when FunctionToken
        _parse_function(token, tokens, index + 1)
      else
        [ token, index + 1 ]
      end
    end
    private_class_method :_parse_factor

    # The call of the given function, its arguments from the '(' at index.
    def self._parse_function(function, tokens, index)
      start = index
      arguments = []
      loop do
        value, index = _parse_sum(tokens, index + 1)   # Past '(' or ';'
        arguments << value
        break unless tokens[index] == ARGUMENT_SEPARATOR
      end
      raise LengthExpressionError.new('missing_close_parenthesis') unless tokens[index] == ')'
      _check_argument_count(function, arguments, tokens[start...index])
      dimension = arguments.map { |argument| argument[1] }.reduce { |a, b| _dimension(a, b) { |x, y| x == y ? x : nil } }
      raise LengthExpressionError.new('invalid_dimension') if dimension == false
      numbers = arguments.map(&:first)
      case function.name
      when 'min'
        number = numbers.min
      when 'max'
        number = numbers.max
      when 'floor'
        number = numbers[1..-1].select { |step| step <= numbers[0] + STEP_TOLERANCE }.max
      else
        number = numbers[1..-1].select { |step| step >= numbers[0] - STEP_TOLERANCE }.min
      end
      raise LengthExpressionError.new('no_matching_value', { :function => function.name }) if number.nil?
      [ [ number, dimension ], index + 1 ]
    end
    private_class_method :_parse_function

    # Raises unless the given function has at least two arguments - asking
    # for ';' when a decimal comma took the place of a separator.
    def self._check_argument_count(function, arguments, tokens)
      return if arguments.length >= 2
      raise LengthExpressionError.new('comma_argument_separator', { :function => function.name }) if tokens.any? { |token| token.is_a?(Array) && token[2].to_s.include?(',') }
      raise LengthExpressionError.new('invalid_argument_count', { :function => function.name })
    end
    private_class_method :_check_argument_count

    # -- Nodes : the expression as a tree, to give its bare numbers a unit - see with_unit --
    #  - [ :bare, <token index> ] : a bare number ;
    #  - [ :fixed, <dimension> ] : a literal with a unit, a variable ;
    #  - [ :neg, <node> ], [ :mul, <node>, <node> ], [ :div, <node>, <node> ] ;
    #  - [ :sum, [ <node> ] ], [ :function, [ <node> ] ].

    def self._node_sum(tokens, index)
      node, index = _node_product(tokens, index)
      terms = [ node ]
      while %w[+ -].include?(tokens[index])
        node, index = _node_product(tokens, index + 1)
        terms << node
      end
      [ terms.length == 1 ? terms.first : [ :sum, terms ], index ]
    end
    private_class_method :_node_sum

    def self._node_product(tokens, index)
      node, index = _node_factor(tokens, index)
      while %w[* /].include?(tokens[index])
        operator = tokens[index]
        other, index = _node_factor(tokens, index + 1)
        node = [ operator == '*' ? :mul : :div, node, other ]
      end
      [ node, index ]
    end
    private_class_method :_node_product

    def self._node_factor(tokens, index)
      token = tokens[index]
      case token
      when nil, '*', '/', ')', ARGUMENT_SEPARATOR
        raise LengthExpressionError.new(token == ')' ? 'unexpected_close_parenthesis' : 'missing_operand')
      when '+', '-'
        node, index = _node_factor(tokens, index + 1)
        [ [ :neg, node ], index ]
      when '('
        node, index = _node_sum(tokens, index + 1)
        raise LengthExpressionError.new('missing_close_parenthesis') unless tokens[index] == ')'
        [ node, index + 1 ]
      when FunctionToken
        start = index + 1
        arguments = []
        index += 1
        loop do
          node, index = _node_sum(tokens, index + 1)   # Past '(' or ';'
          arguments << node
          break unless tokens[index] == ARGUMENT_SEPARATOR
        end
        raise LengthExpressionError.new('missing_close_parenthesis') unless tokens[index] == ')'
        _check_argument_count(token, arguments, tokens[start...index])
        [ [ :function, arguments ], index + 1 ]
      else
        [ token[1].nil? ? [ :bare, index ] : [ :fixed, token[1] ], index + 1 ]
      end
    end
    private_class_method :_node_factor

    # The dimension of the given node, nil when it depends on the one its
    # bare numbers are given.
    def self._node_dimension(node)
      case node[0]
      when :bare
        nil
      when :fixed
        node[1]
      when :neg
        _node_dimension(node[1])
      when :sum, :function
        node[1].map { |n| _node_dimension(n) }.compact.first
      else
        a = _node_dimension(node[1])
        b = _node_dimension(node[2])
        a.nil? || b.nil? ? nil : (node[0] == :mul ? a + b : a - b)
      end
    end
    private_class_method :_node_dimension

    # Gives the bare numbers of the given node the dimension that makes it
    # the given one : adds the token index of the lengths to the given list.
    def self._assign_dimension(node, dimension, lengths)
      case node[0]
      when :bare
        lengths << node[1] if dimension == 1
      when :neg
        _assign_dimension(node[1], dimension, lengths)
      when :sum, :function
        node[1].each { |n| _assign_dimension(n, dimension, lengths) }
      when :mul
        a = _node_dimension(node[1])
        b = _node_dimension(node[2])
        if !a.nil?
          _assign_dimension(node[1], a, lengths)
          _assign_dimension(node[2], dimension - a, lengths)
        elsif !b.nil?
          _assign_dimension(node[2], b, lengths)
          _assign_dimension(node[1], dimension - b, lengths)
        else
          _assign_dimension(node[1], dimension, lengths)
          _assign_dimension(node[2], 0, lengths)
        end
      when :div
        a = _node_dimension(node[1])
        b = _node_dimension(node[2])
        if !b.nil?
          _assign_dimension(node[2], b, lengths)
          _assign_dimension(node[1], dimension + b, lengths)
        elsif !a.nil?
          _assign_dimension(node[1], a, lengths)
          _assign_dimension(node[2], a - dimension, lengths)
        else
          _assign_dimension(node[1], dimension, lengths)
          _assign_dimension(node[2], 0, lengths)
        end
      end
    end
    private_class_method :_assign_dimension

    # The dimension of an operation on the given ones : nil when unchecked,
    # false when the block refuses them.
    def self._dimension(a, b)
      return nil if a.nil? || b.nil?
      dimension = yield(a, b)
      dimension.nil? ? false : dimension
    end
    private_class_method :_dimension

  end

end
