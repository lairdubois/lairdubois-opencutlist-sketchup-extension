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
    attr_accessor :debug
    
    #
    # initialize a new Options object. Check for validity
    # of parameters. Raises an error on 
    # negative base_bin_length.
    #
    def initialize(base_bin_length, saw_kerf, trimsize, 
                   max_time=MAX_TIME, debug=false)
       
      @base_bin_length = base_bin_length
      @base_bin_length = 0 if @base_bin_length < 0
      
      # the following two options are tested by packengine.
      # make them positive.
      @saw_kerf = saw_kerf.abs
      @trimsize = trimsize.abs

      @max_time = max_time
      if @max_time < 0 or @max_time > MAX_TIME
        @max_time = MAX_TIME
      end      
      @debug = debug
    end
  end

end