module Ladb::OpenCutList

  module HashUtils

    # Converts all keys of a given hash to symbols.
    #
    # Uses `transform_keys` when available (Ruby >= 2.5), otherwise falls back
    # to a manual iteration for compatibility with older Ruby versions.
    #
    # @param hash [Hash] the hash whose keys should be symbolized
    # @return [Hash] a new hash with all keys converted to symbols
    #
    # @example
    #   symbolize_keys({ "name" => "Alice", "age" => 30 })
    #   #=> { name: "Alice", age: 30 }
    def self.symbolize_keys(hash)
      return hash.transform_keys { |k| k.to_sym } if hash.respond_to?(:transform_keys)
      # Workaround for Ruby prior to 2.5
      hash.each_with_object({}) { |(key, value), h| h[key.to_sym] = value }
    end

  end

end

