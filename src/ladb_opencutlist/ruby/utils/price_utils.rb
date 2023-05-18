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
    end

    def get_symbol
      @currency_symbol
    end

    # -----

    # Take a float containing a price
    # and convert it to a string representation according to the
    # local unit settings.
    def format_to_readable_price(f, precision = 0)
      UnitUtils.format_readable(f, UNIT_STRIPPEDNAME, [ 2, precision ].min, 2)
    end

  end
end
