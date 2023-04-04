# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking1D
  #
  # Implements an element to pack into a Bin.
  #
  class Box < Packing1D
    # Position of the Box inside the enclosing Bin.
    attr_accessor :x_pos

    # Length of this Box.
    attr_reader :length

    # Reference to an external object. This value is kept during optimization.
    attr_reader :data

    # Component ID. Unique sortable key per items sharing the same definition.
    attr_reader :cid

    #
    # Initialize a new Box, ensure that it has a length > 0.
    #
    def initialize(length = 0, cid = 1, data = nil)
      super(nil)
      @x_pos = 0.0
      @length = length * 1.0
      raise(Packing1DError, 'Trying to initialize a box with zero or negative length!') if @length <= 0

      @data = data
      # Component id (cid) is used to keep boxes together
      # that have identical dimensions, but different definitions.
      @cid = if cid.nil?
               1
             else
               cid
             end
    end
  end
end
