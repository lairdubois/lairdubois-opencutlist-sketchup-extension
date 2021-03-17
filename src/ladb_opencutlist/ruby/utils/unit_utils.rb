module Ladb::OpenCutList

  class UnitUtils

    # Separators
    UV_SEPARATOR = ' '.freeze
    U_SEPARATOR = '_'.freeze

    def self.split_unit_and_value(str)
      return nil, 0.0 unless str.is_a?(String)
      unit = nil
      val = str
      unless str.nil?
        a = str.split(UV_SEPARATOR)
        if a.length > 1
          unit = a.last
          val = a.slice(0, a.length - 1).join(UV_SEPARATOR)
        end
      end
      val = [ 0.0, val.tr(',', '.').to_f ].max  # 0 if value < 0
      return unit, val
    end

    def self.split_unit(str)
      return [] unless str.is_a?(String)
      str.split(U_SEPARATOR)
    end

    # -----

    # Convert strippedname unit string to readable unit representation
    # Input format : kg_m3
    # Output format : kg / m³
    def self.format_readable_unit(s_unit)
      return '' unless s_unit.is_a?(String)
      split_unit(s_unit).map { |unit_strippedname|

        case unit_strippedname

        # Mass
        when MassUtils::UNIT_STRIPPEDNAME_KILOGRAM
          MassUtils::UNIT_SYMBOL_KILOGRAM
        when MassUtils::UNIT_STRIPPEDNAME_POUND
          MassUtils::UNIT_SYMBOL_POUND

        # Price
        when PriceUtils::UNIT_STRIPPEDNAME
          PriceUtils.instance.get_symbol

        # Length
        when DimensionUtils::UNIT_STRIPPEDNAME_INCHES
          DimensionUtils::UNIT_SYMBOL_INCHES
        when DimensionUtils::UNIT_STRIPPEDNAME_FEET
          DimensionUtils::UNIT_SYMBOL_FEET
        when DimensionUtils::UNIT_STRIPPEDNAME_MILLIMETER
          DimensionUtils::UNIT_SYMBOL_MILLIMETER
        when DimensionUtils::UNIT_STRIPPEDNAME_CENTIMETER
          DimensionUtils::UNIT_SYMBOL_CENTIMETER
        when DimensionUtils::UNIT_STRIPPEDNAME_METER
          DimensionUtils::UNIT_SYMBOL_METER

        # Area
        when DimensionUtils::UNIT_STRIPPEDNAME_FEET_2
          DimensionUtils::UNIT_SYMBOL_FEET_2
        when DimensionUtils::UNIT_STRIPPEDNAME_METER_2
          DimensionUtils::UNIT_SYMBOL_METER_2

        # Volume
        when DimensionUtils::UNIT_STRIPPEDNAME_BOARD_FEET
          DimensionUtils::UNIT_SYMBOL_BOARD_FEET
        when DimensionUtils::UNIT_STRIPPEDNAME_FEET_3
          DimensionUtils::UNIT_SYMBOL_FEET_3
        when DimensionUtils::UNIT_STRIPPEDNAME_METER_3
          DimensionUtils::UNIT_SYMBOL_METER_3

        when 'i'
          Plugin.instance.get_i18n_string('default.instance_single')
        when 'p'
          Plugin.instance.get_i18n_string('default.part_single')

        else
          unit_strippedname
        end

      }.join(' / ')
    end

    def self.format_readable_value(f_value, precision = 0, show_rounded_sign = false)
      return nil if f_value.nil?
      rounded_value = f_value.round(precision)
      (show_rounded_sign && (f_value - rounded_value).abs > 0.0001 ? '~ ' : '') + ("%.#{precision}f" % rounded_value).tr('.', DimensionUtils.instance.decimal_separator)
    end

    def self.format_readable(f_value, s_unit, precision = 0, precision_small = 3, show_rounded_sign = false)
      "#{format_readable_value(f_value, f_value.abs < 1 ? precision_small : precision, show_rounded_sign)} #{format_readable_unit(s_unit)}"
    end

  end

end

