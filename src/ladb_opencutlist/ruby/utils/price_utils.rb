module Ladb::OpenCutList

  require 'singleton'

  class PriceUtils

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
      fetch_currency_options
    end

    def fetch_currency_options
      settings_model = Plugin.instance.get_model_preset('settings_model')
      @currency_symbol = settings_model['currency_symbol']
    end

    def get_symbol
      @currency_symbol
    end

    # -----

    # Take a float containing a price
    # and convert it to a string representation according to the
    # local unit settings.
    #
    def format_to_readable_price(f)
      if f.nil?
        return nil
      end
      format_value(f, 1, f < 1 ? 2 : 0)
    end

    def format_value(f, multiplier, precision)
      value = f * multiplier
      rounded_value = value.round(precision)
      ("%.#{precision}f" % rounded_value).tr('.', @decimal_separator) + ' ' + get_symbol
    end

  end
end
