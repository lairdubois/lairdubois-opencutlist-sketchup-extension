module Ladb::OpenCutList

  module MaterialPriceHelper

    def _get_std_price(dim, material_attributes)

      h_std_prices = material_attributes.h_std_prices
      unless  dim.nil?
        h_std_prices.each do |std_price|
          if std_price[:dim] == dim
            return std_price
          end
        end
      end

      h_std_prices[0]
    end

  end

end