# frozen_string_literal: true

module Ladb::OpenCutList::BinPacking1D
  #
  # Implements Options
  #
  class Options < Packing1D
    # Length of a standard bin that can be replicated
    # any number of times.
    attr_reader :base_bin_length

    # Width of the kerf produced by the saw blade.
    attr_reader :saw_kerf

    # Margin that will be removed on both sides of
    # the raw bin.
    attr_reader :trimsize

    # Maximum time to spend in computation before raising
    # a TimeoutError.
    attr_reader :max_time

    # Enable debugging information, very verbose.
    attr_reader :debug

    #
    # initialize a new Options object. Check for validity
    # of parameters. Raises an error on
    # negative base_bin_length.
    #
    def initialize(base_bin_length, saw_kerf, trimsize,
                   max_time = MAX_TIME, debug = false)
      super(nil)
      @base_bin_length = base_bin_length
      @base_bin_length = 0.0 if @base_bin_length.nil? || @base_bin_length < 0.0

      # The following two options are tested by packengine.
      # make them positive.
      @saw_kerf = saw_kerf.abs
      @trimsize = trimsize.abs

      @max_time = max_time
      @max_time = MAX_TIME if @max_time < 0 || @max_time > MAX_TIME

      @debug = debug
    end

    #
    # Sets debug mode to on/off.
    #
    def set_debug(debug)
      @debug = debug
    end

    #
    # Debugging!
    #
    def to_str
      s = "  options:\n  saw_kerf         = #{@saw_kerf}\n"
      s << "  trimsize         = #{@trimsize}\n"
      s << "  base_bin_length  = #{@base_bin_length}\n"
      s
    end
  end
end
