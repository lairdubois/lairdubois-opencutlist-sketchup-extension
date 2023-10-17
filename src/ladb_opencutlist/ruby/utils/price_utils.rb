module Ladb::OpenCutList

  require 'singleton'

  class PriceUtils

    # Unit strippednames
    UNIT_STRIPPEDNAME = '$'

    include Singleton

    # -----

    def initialize
      fetch_currency_options
    end

    def fetch_currency_options
      settings_model = Plugin.instance.get_model_preset('settings_model')
      @currency_symbol = settings_model['currency_symbol']
      @currency_precision = settings_model['currency_precision'].to_i
    end

    def get_symbol
      @currency_symbol
    end

    # -----

    # Take a float containing a price
    # and convert it to a string representation according to the
    # local unit settings.
    def format_to_readable_price(f)
      UnitUtils.format_readable(f, UNIT_STRIPPEDNAME, @currency_precision, [ 2, @currency_precision ].max)
    end

  end
end
