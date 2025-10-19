module Ladb::OpenCutList

  require_relative '../utils/dimension_utils'

  module UserTextHelper

    # Operators and their precedence (larger = higher priority)
    OPERATOR_PRECEDENCE = {
      "+" => 1,
      "-" => 1,
      "*" => 2,
      "/" => 2,
      "±" => 3
    }.freeze

    # Read length from 'text'
    # Examples :
    #  50     → 50mm
    #  +10    → 10mm
    #  -5     → -5mm
    #  @      → 'base_length'
    #  @+10   → 'base_length' + 10mm
    #  @-15   → 'base_length' - 15mm
    #  @*3    → 'base_length' * 3
    #  @/2    → 'base_length' / 2
    def _read_user_text_length(tool, text, base_length = 0)
      return base_length if text.nil? || text.empty?

      begin

        base_factor = base_length >= 0 ? 1 : -1
        base_length = base_length.abs

        # Step 1: Tokenization
        # --------------------

        # 1. Add | around each token to make them easier to split it
        tokens_string = text.gsub(/(@|\d+'(?:\s*\d\s+)?(?:\d+\/)?\d+"*|\d+'*\s+(?:\d+\/)?\d+"*|\d+\/\d+"*|(?:\d+(?:[.,]\d+)*|[.,]\d+)(?:\s*(?:mm|cm|m|"|'))?)/, '|\1|')
                            .gsub(/([()])/, '|\1|')
                            .gsub(/(-)/, '|\1|')

        # 2. Split tokens by '|'
        tokens = tokens_string.split(/\|+/).map { |token| token.strip unless token.nil? || token.empty? }.compact

        # 3. Manage 'negative' operator
        tokens.each_with_index do |token, index|
          if token == '-'
            if index == 0 ||
               tokens[index - 1] == '(' ||
               tokens[index - 1] == '+' || tokens[index - 1] == '-' || tokens[index - 1] == '*' || tokens[index - 1] == '/'
              tokens[index] = '±'
            elsif tokens[index - 1] == '±'
              tokens[index -1] = nil
              tokens[index] = nil
            end
          end
        end
        tokens.compact!

        # Step 2 : Converting to RPN
        # --------------------------

        rpn_tokens = []
        operator_stack = []

        tokens.each do |token|
          if OPERATOR_PRECEDENCE.key?(token) # It's an operator
            # Pops operators of greater than or equal precedence
            while operator_stack.any? &&
                  OPERATOR_PRECEDENCE.key?(operator_stack.last) &&
                  OPERATOR_PRECEDENCE[operator_stack.last] >= OPERATOR_PRECEDENCE[token]
              rpn_tokens << operator_stack.pop
            end
            operator_stack << token
          elsif token == "("
            operator_stack << token
          elsif token == ")"
            # Pops all operators until the matching opening parenthesis is found
            while operator_stack.any? && operator_stack.last != "("
              rpn_tokens << operator_stack.pop
            end
            # If the stack is empty or the opening parenthesis was not found
            raise "Syntax error: unexpected close parenthesis" unless operator_stack.pop == "("
          else
            rpn_tokens << token
          end
        end

        # Pops all remaining operators into the output
        while operator_stack.any?
          # If we find an opening parenthesis here, it means that a closing parenthesis is missing.
          raise "Syntax error: missing close parenthesis" if operator_stack.last == "("
          rpn_tokens << operator_stack.pop
        end

        # Step 3: Evaluate RPN tokens
        # ---------------------------

        stack = []

        rpn_tokens.each do |token|
          if OPERATOR_PRECEDENCE.key?(token) # It's an operator

            if token == "±"

              right = stack.pop

              raise "Syntax error: missing operand" unless right

              right = right.to_l unless right.is_a?(Length)
              right = DimensionUtils.length_to_model_unit_float(right)
              result = DimensionUtils.model_unit_float_to_length(-1.0 * right)

              stack << result
            else

              right = stack.pop
              left = stack.pop

              raise "Syntax error: missing operand" unless left && right

              left = left.to_l unless left.is_a?(Length)
              right = right.to_l unless right.is_a?(Length)
              case token
              when "+"
                result = left + right
              when "-"
                result = left - right
              when "*"
                left = DimensionUtils.length_to_model_unit_float(left)
                right = DimensionUtils.length_to_model_unit_float(right)
                result = DimensionUtils.model_unit_float_to_length(left * right)
              when "/"
                left = DimensionUtils.length_to_model_unit_float(left)
                raise "Divide by zero" if right == 0.0
                right = DimensionUtils.length_to_model_unit_float(right)
                result = DimensionUtils.model_unit_float_to_length(left / right)
              else
                raise "Syntax error: unknown operator"
              end

              stack << result
            end

          elsif token == '@'
            stack << base_length
          else
            stack << token
          end
        end

        raise "Expression invalide" unless stack.size == 1
        length = (stack.first.to_l * base_factor).to_l

      rescue
        UI.beep
        tool.notify_errors([ [ 'tool.default.error.invalid_length', { :value => text } ] ])
        return nil
      end

      return length

      # if text.is_a?(String)
      #   if (match = /^@([x*\/])([-]{0,1})(\d+(?:[.,]\d+)*$)/.match(text))
      #     operator, sign, value = match[1, 3]
      #     factor = value.sub(',', '.').to_f
      #     factor *= -1 if sign == '-'
      #     if factor != 0 && base_length != 0
      #       case operator
      #       when 'x', '*'
      #         length = base_length * factor
      #       when '/'
      #         length = base_length / factor
      #       end
      #     else
      #       UI.beep
      #       tool.notify_errors([ [ "tool.default.error.invalid_#{operator == '/' ? 'divider' : 'multiplicator'}", { :value => value } ] ])
      #       return nil
      #     end
      #   elsif (match = /^@([+-])(.+)$/.match(text))
      #     operator, value = match[1, 2]
      #     begin
      #       length = value.to_l
      #       length *= -1 if base_length < 0
      #       case operator
      #       when '+'
      #         length = base_length + length
      #       when '-'
      #         length = base_length - length
      #       end
      #     rescue ArgumentError
      #       UI.beep
      #       tool.notify_errors([ [ 'tool.default.error.invalid_length', { :value => value } ] ])
      #       return nil
      #     end
      #   elsif (match = /^(-*)@$/.match(text))
      #     base_sign, _ = match[1, 1]
      #     factor = 1
      #     factor *= -1 if base_sign == '-'
      #     length = base_length * factor
      #   else
      #     text = text.delete('@+')   # Remove possible extra @ or + characters
      #     begin
      #       if text.empty? && !base_length.nil?
      #         length = base_length
      #       else
      #         length = text.to_l
      #         length *= -1 if base_length < 0
      #       end
      #     rescue ArgumentError
      #       UI.beep
      #       tool.notify_errors([ [ 'tool.default.error.invalid_length', { :value => text } ] ])
      #       return nil
      #     end
      #   end
      # end
      #
      # length

    end

    # Split 'text' with regional list separator.
    # Allows '=' char to duplicate current value.
    # Examples :
    #  50       → [ 50 ]
    #  ,50      → [ nil, 50 ]
    #  50=,-12  → [ 50, 50, -12 ]
    #  50==     → [ 50, 50, 50 ]
    def _split_user_text(text)
      values = text.split(Sketchup::RegionalSettings.list_separator)
      values.map { |value|
        if (match = value.match(/^([^=]+)(=+)$/))
          v, equals = match[1, 2]
          Array.new(equals.length + 1) { v }
        else
          value
        end
      }.flatten(1)
    end

  end

end