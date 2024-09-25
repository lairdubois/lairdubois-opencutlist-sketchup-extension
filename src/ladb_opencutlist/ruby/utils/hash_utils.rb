module Ladb::OpenCutList

  module HashUtils

    def self.symbolize_keys(hash)
      return hash.transform_keys { |k| k.to_sym } if hash.respond_to?(:transform_keys)
      # Workaround for Ruby prior to 2.5
      h = {}
      hash.each_pair { |key, value| h[key.to_sym] = value }
      h
    end

  end

end

