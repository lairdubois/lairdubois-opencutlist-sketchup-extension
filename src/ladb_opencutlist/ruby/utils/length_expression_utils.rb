module Ladb::OpenCutList

  require_relative 'dimension_utils'

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

    # A literal : feet and inches - 1' 6" -, a whole and a fraction - 1 1/2" -,
    # a fraction - 3/4" -, or a number with an optional unit - 2.5 cm.
    LITERAL_PATTERN = /\G(?:\d+'(?:\s*\d\s+)?(?:\d+\/)?\d+"*|\d+'*\s+(?:\d+\/)?\d+"*|\d+\/\d+"*|(?:\d+(?:[.,]\d+)*|[.,]\d+)(?:\s*(?:mm|cm|m|yd|"|'))?)/i
    VARIABLE_PATTERN = /\G@([A-Za-z_]\w*)?/
    OPERATOR_PATTERN = /\G[-+*\/();]/
    FUNCTION_PATTERN = /\G(min|max|floor|ceil)\s*(?=\()/i

    # The arguments of a function are separated by ';' - or by ',' right
    # after an argument : "min(10mm, 20mm)", but "min(10,5; 20)" as ',' is
    # also a decimal separator.
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
      if index < tokens.length
        raise LengthExpressionError.new('unexpected_close_parenthesis') if tokens[index] == ')'
        raise LengthExpressionError.new('missing_operand')
      end
      value
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

    # A literal as SketchUp reads it - its decimal separator made the
    # model's - in inches. Raises ArgumentError.
    def self.literal_to_inches(literal)
      literal.gsub(/[,.]/, DimensionUtils.decimal_separator).gsub(/\s*(mm|cm|m|yd|'|")\s*/i, '\1').to_l.to_f
    end

    # Is the given literal a bare number - no unit - ?
    def self.bare_number?(literal)
      literal !~ /[a-z'"]/i
    end

    # -----

    def self._tokenize(text, read_literal, read_variable)
      tokens = []
      position = 0
      while position < text.length
        if text[position] =~ /\s/
          position += 1
        elsif text[position] == ',' && (tokens.last.is_a?(Array) || tokens.last == ')')
          tokens << ARGUMENT_SEPARATOR
          position += 1
        elsif (match = LITERAL_PATTERN.match(text, position)) && !match[0].empty?
          begin
            tokens << read_literal.call(match[0].strip)
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
      end
      tokens
    end
    private_class_method :_tokenize

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
      arguments = []
      loop do
        value, index = _parse_sum(tokens, index + 1)   # Past '(' or ';'
        arguments << value
        break unless tokens[index] == ARGUMENT_SEPARATOR
      end
      raise LengthExpressionError.new('missing_close_parenthesis') unless tokens[index] == ')'
      raise LengthExpressionError.new('invalid_argument_count', { :function => function.name }) if arguments.length < 2
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
