module Ladb::OpenCutList

  require 'singleton'

  class MassUtils

    # Units
    KILOGRAM = 0
    POUND = 1

    # Unit symbols
    UNIT_SYMBOL_KILOGRAM = 'kg'
    UNIT_SYMBOL_POUND = 'lb'

    # Unit strippednames
    UNIT_STRIPPEDNAME_KILOGRAM = 'kg'
    UNIT_STRIPPEDNAME_POUND = 'lb'

    include Singleton

    attr_accessor :decimal_separator

    # -----

    def initialize
      begin
        '1.0'.to_l
        @decimal_separator = '.'
      rescue
        @decimal_separator = ','
      end
      fetch_mass_options
    end

    def fetch_mass_options
      settings_model = Plugin.instance.get_model_preset('settings_model')
      @mass_unit = settings_model['mass_unit']
    end

    def get_symbol
      case @mass_unit
      when KILOGRAM
        return UNIT_SYMBOL_KILOGRAM
      when POUND
        return UNIT_SYMBOL_POUND
      else
        ''
      end
    end

    # -----

    def kg_to_model_unit(f)
      case @mass_unit
      when KILOGRAM
        return f
      when POUND
        return f * 2.20462262185
      else
        0
      end
    end

    def lb_to_model_unit(f)
      case @mass_unit
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
    def format_to_readable_mass(f)
      if f.nil?
        return nil
      end
      format_value(f, 1, f < 1 ? 3 : 0)
    end

    def format_value(f, multiplier, precision)
      value = f * multiplier
      rounded_value = value.round(precision)
      ("%.#{precision}f" % rounded_value).tr('.', @decimal_separator) + ' ' + get_symbol
    end

  end
end

