module Ladb::OpenCutList

  # Utility methods for working with arrays.
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

    # Checks if the array starts with the given prefix array.
    #
    # Compares each element of the prefix with the corresponding element in the array.
    # Returns false if the prefix is longer than the array or if any element differs.
    #
    # @param array [Array] the array to check
    # @param prefix [Array] the array prefix to check for
    # @return [Boolean] true if the array starts with the prefix, false otherwise
    #
    # @example
    #   [1, 2, 3, 4].start_with?([1, 2])    #=> true
    #   [1, 2, 3, 4].start_with?([1, 3])    #=> false
    #   [1, 2].start_with?([1, 2, 3])       #=> false
    #   [].start_with?([1])                 #=> false
    def self.start_with?(array, prefix)
      return false if prefix.length > array.length
      prefix.each_with_index do |elem, i|
        return false if array[i] != elem
      end
      true
    end

  end

end