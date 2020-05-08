module Ladb::OpenCutList::BinPacking1D

  #
  # Implements Options 
  #
  class Options < Packing1D
  
    # length of a standard bin that can be replicated 
    # any number of times.
    attr_reader :base_bin_length 
    
    # width of the kerf produced by the saw blade.
    attr_reader :saw_kerf
    
    # margin that will be removed on both sides of
    # the raw bin.
    attr_reader :trimsize
    
    # internal parameter [0, 1, 2] to control tuning.
    attr_reader :tuning_level
    
    # maximum time to spend in computation before raising
    # a TimeoutError.
    attr_reader :max_time
    
    # option to print debugging information, very verbose.
    attr_reader :debug
    
    #
    # initialize a new Options object. Check for validity
    # of parameters. Raises an error on 
    # negative base_bin_length.
    #
    def initialize(base_bin_length, saw_kerf, trimsize, 
                   tuning_level=DEFAULT_TUNING_LEVEL, 
                   max_time=MAX_TIME,
                   debug=false)
       
      @base_bin_length = base_bin_length
      if @base_bin_length < 0
        raise(Packing1DError, "Negative base_bin_length not a possible option")
      end
      
      # the following two options are tested by packengine.
      @saw_kerf = saw_kerf
      @trimsize = trimsize
      
      @tuning_level = tuning_level
      if @tuning_level < 0 or @tuning_level > DEFAULT_TUNING_LEVEL
        @tuning_level = DEFAULT_TUNING_LEVEL
      end
      @max_time = max_time
      if @max_time < 0 or @max_time > MAX_TIME
        @max_time = MAX_TIME
      end
      @debug = debug
    end
  end

end