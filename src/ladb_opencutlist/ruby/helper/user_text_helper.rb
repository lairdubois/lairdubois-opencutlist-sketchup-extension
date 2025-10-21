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
    #  50       → 50mm
    #  +10      → 10mm
    #  -5       → -5mm
    #  @        → 'targeted_length'
    #  @+10     → 'targeted_length' + 10mm
    #  @-15     → 'targeted_length' - 15mm
    #  @*3      → 'targeted_length' * 3
    #  @/2      → 'targeted_length' / 2
    #  2m*(2+3) → 10m
    def _read_user_text_length(tool, text, targeted_length = 0)
      return targeted_length if text.nil? || text.empty?

      base_factor = targeted_length >= 0 ? 1 : -1
      targeted_length = targeted_length.abs

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
            tokens[index - 1] = nil
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
          raise PLUGIN.get_i18n_string('tool.default.error.unexpected_close_parenthesis') unless operator_stack.pop == "("
        else
          rpn_tokens << token
        end
      end

      # Pops all remaining operators into the output
      while operator_stack.any?
        # If we find an opening parenthesis here, it means that a closing parenthesis is missing.
        raise PLUGIN.get_i18n_string('tool.default.error.missing_close_parenthesis') if operator_stack.last == "("
        rpn_tokens << operator_stack.pop
      end

      # Step 3: Evaluate RPN tokens
      # ---------------------------

      stack = []

      rpn_tokens.each do |token|
        if OPERATOR_PRECEDENCE.key?(token) # It's an operator

          if token == "±"

            right = stack.pop

            raise PLUGIN.get_i18n_string('tool.default.error.missing_operand') unless right

            right = right.to_l unless right.is_a?(Length)
            result = -right

            stack << result
          else

            right = stack.pop
            left = stack.pop

            raise PLUGIN.get_i18n_string('tool.default.error.missing_operand') unless left && right

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
              raise ZeroDivisionError.new(PLUGIN.get_i18n_string('tool.default.error.zero_division')) if right == 0.0
              right = DimensionUtils.length_to_model_unit_float(right)
              result = DimensionUtils.model_unit_float_to_length(left / right)
            end

            stack << result
          end

        elsif token == '@'
          stack << targeted_length
        else
          stack << token
        end
      end

      # Stack should contain only one value
      raise "" unless stack.size == 1

      # Use base_factor to return the length with a sign corresponding to the base_length
      (stack.first.to_l * base_factor).to_l

    rescue => e
      UI.beep
      errors = [ [ 'tool.default.error.invalid_length', { :value => text } ] ]
      if e.is_a?(ZeroDivisionError)
        errors << [ "tool.default.error.zero_division" ]
      elsif !e.message.empty?
        errors << [ 'tool.default.error.syntax_error', { :error => e.message } ]
      end
      tool.notify_errors(errors)
      return nil
    end

    # Read point from 'text'
    # Returns nil if no point notation is detected
    # Accepts 3D coordinates:
    # - An absolute coordinate, such as [3',5',7'], returns a point relative to the current axes. Square brackets indicate an absolute coordinate.
    # - A relative coordinate, such as <1.5m, 4m, 2.75m>, returns a point relative to the 'relative_point'. Angle brackets indicate a relative coordinate.
    # https://help.sketchup.com/en/sketchup/introducing-drawing-basics-and-concepts
    def _read_user_text_point(tool, text, targeted_point = ORIGIN, relative_point = ORIGIN)

      # Check if it's an absolute point
      if (match = text.match(/^\[([^\[\]]+)\]$/))
        d1, d2, d3 = _split_user_text(match[1])
        origin = ORIGIN

      # Check if it's a relative point
      elsif (match = text.match(/^<([^<>]+)>$/))
        d1, d2, d3 = _split_user_text(match[1])
        origin = relative_point

      else
        return nil

      end

      if d1 || d2 || d3
        tx, ty, tz = (targeted_point - origin).to_a
        return Geom::Point3d.new(
          origin.x + _read_user_text_length(tool, d1, tx.abs),
          origin.y + _read_user_text_length(tool, d2, ty.abs),
          origin.z + _read_user_text_length(tool, d3, tz.abs)
        )
      end
      nil
    end

    # Split 'text' with regional list separator.
    # Allows '=' char to duplicate the current value.
    # Examples :
    #  50       → [ 50 ]
    #  ,50      → [ nil, 50 ]
    #  50=,-12  → [ 50, 50, -12 ]
    #  50==     → [ 50, 50, 50 ]
    def _split_user_text(text)
      values = text.split(Sketchup::RegionalSettings.list_separator)
      values.map { |value|
        if (match = value.strip.match(/^([^=]+)(=+)$/))
          v, equals = match[1, 2]
          Array.new(equals.length + 1) { v }
        else
          value
        end
      }.flatten(1)
    end

  end

end