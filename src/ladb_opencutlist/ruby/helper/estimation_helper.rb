module Ladb::OpenCutList

  require_relative '../utils/mass_utils'
  require_relative '../utils/dimension_utils'

  module EstimationHelper

    def _get_std_volumic_mass(dim, material_attributes)

      h_std_volumic_masses = material_attributes.h_std_volumic_masses
      unless dim.nil?
        h_std_volumic_masses.each do |std_volumic_masses|
          return std_volumic_masses if std_volumic_masses[:dim] == dim
        end
      end

      h_std_volumic_masses.first
    end

    def _get_std_price(dim, material_attributes)

      h_std_prices = material_attributes.h_std_prices
      unless dim.nil?

        # Try full dim
        h_std_prices.each do |std_price|
          return std_price if std_price[:dim] == dim
        end

        # Try with only the first value of dim is possible
        if dim.is_a?(Array) && dim.length > 1
          dim = [ dim.first ]
          h_std_prices.each do |std_price|
            return std_price if std_price[:dim] == dim
          end
        end

      end

      # Use default price
      h_std_prices.first
    end

    def _get_std_cut_price(dim, material_attributes)

      h_std_cut_prices = material_attributes.h_std_cut_prices
      unless dim.nil?

        # Try full dim
        h_std_cut_prices.each do |std_price|
          return std_price if std_price[:dim] == dim
        end

        # Try with only the first value of dim is possible
        if dim.is_a?(Array) && dim.length > 1
          dim = [ dim.first ]
          h_std_cut_prices.each do |std_price|
            return std_price if std_price[:dim] == dim
          end
        end

      end

      # Use default price
      h_std_cut_prices.first
    end

    def _uv_mass_to_model_unit(s_unit, f_value)

      case s_unit

      when MassUtils::UNIT_STRIPPEDNAME_KILOGRAM
        f_value = MassUtils.kg_to_model_unit(f_value)
      when MassUtils::UNIT_STRIPPEDNAME_POUND
        f_value = MassUtils.lb_to_model_unit(f_value)

      end

      f_value
    end

    def _uv_to_inch3(s_unit, f_value, inch_thickness = 0, inch_width = 0, inch_length = 0)

      return 0 if s_unit.nil?   # Invalid input

      unit_numerator, unit_denominator = s_unit.split('_')

      # Process mass if needed
      f_value = _uv_mass_to_model_unit(unit_numerator, f_value)

      # Process volume / area / length / instance or part
      case unit_denominator

      when DimensionUtils::UNIT_STRIPPEDNAME_METER_3
        f_value = DimensionUtils.m3_to_inch3(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET_3
        f_value = DimensionUtils.ft3_to_inch3(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_BOARD_FEET
        f_value = DimensionUtils.fbm_to_inch3(f_value)

      when DimensionUtils::UNIT_STRIPPEDNAME_METER_2
        f_value = inch_thickness == 0 ? 0 : DimensionUtils.m2_to_inch2(f_value) / inch_thickness
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET_2
        f_value = inch_thickness == 0 ? 0 : DimensionUtils.ft2_to_inch2(f_value) / inch_thickness

      when DimensionUtils::UNIT_STRIPPEDNAME_METER
        f_value = inch_thickness * inch_width == 0 ? 0 : DimensionUtils.m_to_inch(f_value) / inch_thickness / inch_width
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET
        f_value = inch_thickness * inch_width == 0 ? 0 : DimensionUtils.ft_to_inch(f_value) / inch_thickness / inch_width

      when 'i', 'p'
        f_value = inch_thickness * inch_width * inch_length == 0 ? 0 : f_value / inch_thickness / inch_width / inch_length

      end

      f_value
    end

    def _uv_to_inch(s_unit, f_value, inch_length = 0)

      return 0 if s_unit.nil?   # Invalid input

      unit_numerator, unit_denominator = s_unit.split('_')

      # Process volume / area / length / instance or part
      case unit_denominator

      when DimensionUtils::UNIT_STRIPPEDNAME_METER
        return DimensionUtils.m_to_inch(f_value)
      when DimensionUtils::UNIT_STRIPPEDNAME_FEET
        return DimensionUtils.ft_to_inch(f_value)

      when 'i', 'p', 'c'
        return inch_length == 0 ? 0 : f_value / inch_length

      end

      0
    end

  end

end