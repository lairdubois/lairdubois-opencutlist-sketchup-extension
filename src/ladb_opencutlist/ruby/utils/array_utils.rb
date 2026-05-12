module Ladb::OpenCutList

  module ArrayUtils

    # Finds the common prefix elements across multiple arrays.
    # Returns an array containing only the elements that are identical at the same position
    # across all input arrays, stopping at the first position where arrays differ.
    # Returns an empty array if no arrays are provided.
    #
    # Example:
    #   common_prefix([1, 2, 3, 4], [1, 2, 5, 6], [1, 2, 3, 7])
    #   => [1, 2]
    def self.common_prefix(*arrays)
      return [] if arrays.empty?
      arrays[0].zip(*arrays[1..]).take_while { |group| group.uniq.length == 1 }.map(&:first)
    end

  end

end