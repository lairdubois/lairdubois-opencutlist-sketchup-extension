module Ladb::OpenCutList::BinPacking1D

  require_relative 'packing1d'
  require_relative 'options'
  require_relative 'packer'
  require_relative 'box'
  require_relative 'bin'

  #
  # Setup and run bin packing in 1D.
  #
  class PackEngine < Packing1D
  
    # List of warnings.
    attr_reader :warnings
      
    #
    # Initialize a new PackEngine with options.
    #
    def initialize(options)
      super(options)
      @leftovers = []
      @boxes = []
      @warnings = []
      @smallest_bin = MAX_INT*1.0
      @largest_bin = 0.0
    end
    
    # 
    # Add scrap bins.
    #
    def add_bin(length)
      dbg("   . BIN length #{length}")
      if length <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BIN
      else
        newbin = Bin.new(length, BIN_TYPE_LO, @options)
        # sorting is not necessary, algorithm will pick largest available
        @leftovers.push(newbin).sort_by!(&:length)
      end
    end
        
    # 
    # Add a box to be packed into bins.
    #
    def add_box(length, data = nil)
      dbg("   . BOX length=#{length}, data=#{data}")
      if length <= 0
        @warnings << WARNING_ILLEGAL_SIZED_BOX if length <= 0
      else
        @boxes << Box.new(length, data)
      end
    end
    
    #
    # Find and update the min/max leftover and base bin length.
    #
    def update_min_max_bin ()
      if @options.base_bin_length > EPS
        @smallest_bin = @options.base_bin_length
        @largest_bin = @options.base_bin_length
      end
      @leftovers.each do |leftover|
        @largest_bin = leftover.length if leftover.length > @largest_bin
        @smallest_bin = leftover.length if leftover.length < @smallest_bin
      end
    end

    #
    # Returns true if saw_kerf has a reasonnable length.
    # May be large, but must be smaller than the largest bin.
    #
    def valid_saw_kerf()
      return (@options.saw_kerf < [@options.base_bin_length, @largest_bin].max)
    end
    
    #
    # Returns true if trimsize has a reasonnable length.
    # May be large, but must be smaller than the largest bin.
    #
    def valid_trimsize()
      return (@options.trimsize*2.0 < [@options.base_bin_length, @largest_bin].max)
    end
    
    # 
    # checks for consistency, creates a Packer and runs it.
    #
    def run

      dbg("-- packengine run")
      
      update_min_max_bin()

      # check for boxes and bins
      return nil, ERROR_NO_BOX if @boxes.empty?

      return nil, ERROR_NO_BIN if @options.base_bin_length < EPS and @leftovers.empty?
      # check parameters
      return nil, ERROR_PARAMETERS if !valid_trimsize()
      @warnings << WARNING_TRIM_SIZE_LARGE if @options.trimsize > SIZE_WARNING_FACTOR*@largest_bin
      
      return nil, ERROR_PARAMETERS if !valid_saw_kerf()
      @warnings << WARNING_SAW_KERF_LARGE if @options.saw_kerf > EPS \
        and @options.saw_kerf > SIZE_WARNING_FACTOR*@largest_bin
      
      dbg("-> create packer with nb of leftovers=#{@leftovers.length}") 
      begin
        packer = Packer.new(@options)
        packer.add_leftovers(@leftovers)
        packer.add_boxes(@boxes)
        dbg("-> running packer")
        err = packer.run()
      rescue Packing1DError => err
        puts ("Rescued in PackEngine: #{err.inspect}")
        return nil, ERROR_BAD_ERROR
      end
      @warnings << WARNING_ALGORITHM_FFD if packer.algorithm == ALG_FFD
      packer = nil if err > ERROR_SUBOPT
      return packer, err 
    end
  end
end