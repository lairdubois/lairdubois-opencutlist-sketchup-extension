module Ladb::OpenCutList

  module ArrayUtils

    # Returns the longest common prefix shared across multiple arrays.
    #
    # Compares elements position by position and stops as soon as a position
    # is found where not all arrays have the same value.
    #
    # @param arrays [Array<Array>] a list of arrays to compare
    # @return [Array] the longest common prefix, or an empty array if none exists
    #   or if no arrays are provided
    #
    # @example
    #   common_prefix([1, 2, 3], [1, 2, 4])   #=> [1, 2]
    #   common_prefix([1, 2, 3], [4, 5, 6])   #=> []
    #   common_prefix([1, 2], [1, 2, 3])      #=> [1, 2]
    #   common_prefix()                       #=> []
    def self.common_prefix(*arrays)
      return [] if arrays.empty?
      arrays[0].zip(*arrays[1..-1]).take_while { |group| group.uniq.length == 1 }.map(&:first)
    end

  end

end