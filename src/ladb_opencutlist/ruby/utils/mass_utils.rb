module Ladb::OpenCutList

  require 'singleton'

  # Unit signs
  UNIT_SIGN_KILOGRAM = 'kg'

  class MassUtils

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
    end

    # -----

    # Take a float containing a length in inch
    # and convert it to a string representation according to the
    # local unit settings.
    #
    def format_to_readable_mass(f)
      if f.nil?
        return nil
      end
      format_value(f, 1, 0, UNIT_SIGN_KILOGRAM)
    end

    def format_value(f, multiplier, precision, unit_sign)
      value = f * multiplier
      rounded_value = value.round(precision)
      ("%.#{precision}f" % rounded_value).tr('.', @decimal_separator) + ' ' + unit_sign
    end

  end
end

