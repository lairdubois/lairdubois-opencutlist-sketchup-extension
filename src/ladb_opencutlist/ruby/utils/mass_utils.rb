module Ladb::OpenCutList

  module MassUtils

    # Units
    KILOGRAM = 0
    POUND = 1

    # Unit symbols
    UNIT_SYMBOL_KILOGRAM = 'kg'
    UNIT_SYMBOL_POUND = 'lb'

    # Unit strippednames
    UNIT_STRIPPEDNAME_KILOGRAM = 'kg'
    UNIT_STRIPPEDNAME_POUND = 'lb'

    # -----

    def self.mass_unit
      fetch_mass_options if @mass_unit.nil?
      @mass_unit
    end

    def self.mass_precision
      fetch_mass_options if @mass_precision.nil?
      @mass_precision
    end

    # -----

    def self.fetch_mass_options
      settings_model = PLUGIN.get_model_preset('settings_model')
      @mass_unit = settings_model['mass_unit'].to_i
      @mass_precision = settings_model['mass_precision'].to_i
    end

    # -----

    def self.get_symbol
      case mass_unit
      when KILOGRAM
        return UNIT_SYMBOL_KILOGRAM
      when POUND
        return UNIT_SYMBOL_POUND
      else
        ''
      end
    end

    def self.get_strippedname
      case mass_unit
      when KILOGRAM
        return UNIT_STRIPPEDNAME_KILOGRAM
      when POUND
        return UNIT_STRIPPEDNAME_POUND
      else
        ''
      end
    end

    # -----

    def self.kg_to_model_unit(f)
      case mass_unit
      when KILOGRAM
        return f
      when POUND
        return f * 2.20462262185
      else
        0
      end
    end

    def self.lb_to_model_unit(f)
      case mass_unit
      when KILOGRAM
        return f * 0.45359237
      when POUND
        return f
      else
        0
      end
    end

    # -----

    # Take a float containing a mass
    # and convert it to a string representation according to the
    # local unit settings.
    #
    def self.format_to_readable_mass(f)
      UnitUtils.format_readable(f, get_strippedname, mass_precision, [ 2, mass_precision ].max)
    end

  end

end

