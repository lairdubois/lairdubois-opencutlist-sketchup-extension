module Ladb::OpenCutList

  module PriceUtils

    # Unit strippednames
    UNIT_STRIPPEDNAME = '$'

    # -----

    def self.currency_symbol
      fetch_currency_options if @currency_nil.nil?
      @currency_symbol
    end

    def self.currency_precision
      fetch_currency_options if @currency_precision.nil?
      @currency_precision
    end

    # -----

    def self.fetch_currency_options
      settings_model = PLUGIN.get_model_preset('settings_model')
      @currency_symbol = settings_model['currency_symbol']
      @currency_precision = settings_model['currency_precision'].to_i
    end

    # -----

    # Take a float containing a price
    # and convert it to a string representation according to the
    # local unit settings.
    def self.format_to_readable_price(f)
      UnitUtils.format_readable(f, UNIT_STRIPPEDNAME, currency_precision, [ 2, currency_precision ].max)
    end

  end

end
