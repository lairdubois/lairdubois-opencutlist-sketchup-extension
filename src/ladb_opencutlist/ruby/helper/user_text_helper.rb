module Ladb::OpenCutList

  require_relative '../utils/dimension_utils'
  require_relative '../utils/length_expression_utils'

  module UserTextHelper

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
    # Computed in model units : a bare number is a length as well as a factor.
    def _read_user_text_length(tool, text, targeted_length = 0)
      return targeted_length if text.nil? || text.empty?

      base_factor = targeted_length >= 0 ? 1 : -1
      targeted_length = targeted_length.abs
      targeted_length = DimensionUtils.value_to_model_unit_float(targeted_length.to_l)

      value, _ = LengthExpressionUtils.evaluate(
        text,
        read_literal: lambda { |literal|
          next [ LengthExpressionUtils.bare_number_value(literal), nil ] if LengthExpressionUtils.bare_number?(literal)
          [ DimensionUtils.length_to_model_unit_float(LengthExpressionUtils.literal_to_inches(literal).to_l), nil ]
        },
        read_variable: lambda { |name|
          raise LengthExpressionUtils::LengthExpressionError.new('syntax_error', { :error => "@#{name}" }, "@#{name}") unless name.empty?
          [ targeted_length, nil ]
        }
      )

      # Use base_factor to return the length with a sign corresponding to the base_length
      (DimensionUtils.model_unit_float_to_length(value.to_f) * base_factor).to_l

    rescue => e
      UI.beep
      errors = [ [ 'tool.default.error.invalid_length', { :value => text } ] ]
      if e.is_a?(LengthExpressionUtils::LengthExpressionError) && e.key == 'zero_division'
        errors << [ 'tool.default.error.zero_division' ]
      elsif e.is_a?(LengthExpressionUtils::LengthExpressionError) && e.key != 'syntax_error'
        errors << [ 'tool.default.error.syntax_error', { :error => PLUGIN.get_i18n_string("tool.default.error.#{e.key}") } ]
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
      values = text.split(Sketchup::RegionalSettings.list_separator, -1)
      values.map { |value|
        if (match = value.strip.match(/^([^=]+)(=+)$/))
          v, equals = match[1, 2]
          v = v.strip
          Array.new(equals.length + 1) { v }
        else
          value.strip
        end
      }.flatten(1)
    end

  end

end