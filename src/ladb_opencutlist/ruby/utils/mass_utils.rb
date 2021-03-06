module Ladb::OpenCutList

  require 'singleton'

  class MassUtils

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
      @unit_symbol = settings_model['mass_unit_symbol']
    end

    # -----

    def kg_to_model_unit(f)
      case @unit_symbol
      when UNIT_STRIPPEDNAME_KILOGRAM
        return f
      when UNIT_STRIPPEDNAME_POUND
        return f * 2.20462262185
      else
        0
      end
    end

    def lb_to_model_unit(f)
      case @unit_symbol
      when UNIT_STRIPPEDNAME_KILOGRAM
        return f * 0.45359237
      when UNIT_STRIPPEDNAME_POUND
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
      ("%.#{precision}f" % rounded_value).tr('.', @decimal_separator) + ' ' + @unit_symbol
    end

  end
end

