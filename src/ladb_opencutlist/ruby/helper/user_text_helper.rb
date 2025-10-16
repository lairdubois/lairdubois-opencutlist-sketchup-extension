module Ladb::OpenCutList

  module UserTextHelper

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
      length = base_length

      if text.is_a?(String)
        if (match = /^@([x*\/])([-]{0,1})(\d+(?:[.,]\d+)*$)/.match(text))
          operator, sign, value = match[1, 3]
          factor = value.sub(',', '.').to_f
          factor *= -1 if sign == '-'
          if factor != 0 && base_length != 0
            case operator
            when 'x', '*'
              length = base_length * factor
            when '/'
              length = base_length / factor
            end
          else
            UI.beep
            tool.notify_errors([ [ "tool.default.error.invalid_#{operator == '/' ? 'divider' : 'multiplicator'}", { :value => value } ] ])
            return nil
          end
        elsif (match = /^@([+-])(.+)$/.match(text))
          operator, value = match[1, 2]
          begin
            length = value.to_l
            length *= -1 if base_length < 0
            case operator
            when '+'
              length = base_length + length
            when '-'
              length = base_length - length
            end
          rescue ArgumentError
            UI.beep
            tool.notify_errors([ [ 'tool.default.error.invalid_length', { :value => value } ] ])
            return nil
          end
        elsif (match = /^(-*)@$/.match(text))
          base_sign, _ = match[1, 1]
          factor = 1
          factor *= -1 if base_sign == '-'
          length = base_length * factor
        else
          text = text.delete('@+')   # Remove possible extra @ or + characters
          begin
            if text.empty? && !base_length.nil?
              length = base_length
            else
              length = text.to_l
              length *= -1 if base_length < 0
            end
          rescue ArgumentError
            UI.beep
            tool.notify_errors([ [ 'tool.default.error.invalid_length', { :value => text } ] ])
            return nil
          end
        end
      end

      length
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