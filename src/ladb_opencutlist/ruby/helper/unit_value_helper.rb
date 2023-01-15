module Ladb::OpenCutList

  require_relative '../utils/mass_utils'
  require_relative '../utils/dimension_utils'

  module UnitValueHelper

    def _uv_mass_to_model_unit(s_unit, f_value)

      case s_unit

      when MassUtils::UNIT_STRIPPEDNAME_KILOGRAM
        f_value = MassUtils.instance.kg_to_model_unit(f_value)
      when MassUtils::UNIT_STRIPPEDNAME_POUND
        f_value = MassUtils.instance.lb_to_model_unit(f_value)

      end

      f_value
    end

    def _uv_to_inch3(s_unit, f_value, inch_thickness = 0, inch_width = 0, inch_length = 0)

      return 0 if s_unit.nil?   # Invalid input

      unit_numerator, unit_denominator = s_unit.split('_')

      # Process mass if needed
      _uv_mass_to_model_unit(unit_numerator, f_value)

      # Process volume / area / length / instance or part
      case unit_denominator

      when DimensionUtils::UNIT_STRIPPEDNAME_METER_3
        f_value = DimensionUtils.instance.m3_to_inch3(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET_3
        f_value = DimensionUtils.instance.ft3_to_inch3(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_BOARD_FEET
        f_value = DimensionUtils.instance.fbm_to_inch3(f_value)

      when DimensionUtils::UNIT_STRIPPEDNAME_METER_2
        f_value = inch_thickness == 0 ? 0 : DimensionUtils.instance.m2_to_inch2(f_value) / inch_thickness
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET_2
        f_value = inch_thickness == 0 ? 0 : DimensionUtils.instance.ft2_to_inch2(f_value) / inch_thickness

      when DimensionUtils::UNIT_STRIPPEDNAME_METER
        f_value = inch_thickness * inch_width == 0 ? 0 : DimensionUtils.instance.m_to_inch(f_value) / inch_thickness / inch_width
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET
        f_value = inch_thickness * inch_width == 0 ? 0 : DimensionUtils.instance.ft_to_inch(f_value) / inch_thickness / inch_width

      when 'i', 'p'
        f_value = inch_thickness * inch_width * inch_length == 0 ? 0 : f_value / inch_thickness / inch_width / inch_length

      end

      f_value
    end

  end

end