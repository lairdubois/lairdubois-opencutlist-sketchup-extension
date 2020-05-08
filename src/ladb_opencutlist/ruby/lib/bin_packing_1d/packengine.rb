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
  
    # list of warnings.
    attr_reader :warnings
      
    #
    # initialize a new PackEngine with options.
    #
    def initialize(options)
      super(options)
      @leftovers = []
      @boxes = []
      @warnings = []
    end
    
    # 
    # add scrap bins.
    #
    def add_bin(length)
      dbg("   . BIN length #{length}")
      newbin = Bin.new(length, BIN_TYPE_LO, @options)
      
      @warnings << WARNING_ILLEGAL_SIZED_BIN if length <= 0
      # sorting is not necessary, algorithm will pick largest available
      @leftovers.push(newbin).sort_by!(&:length)
    end
        
    # 
    # add boxes to be packed into bins.
    #
    def add_box(length, data = nil)
      dbg("   . BOX length=#{length}, data=#{data}")

      @warnings << WARNING_ILLEGAL_SIZED_BOX if length <= 0
      @boxes << Box.new(length, data)
    end
    
    # 
    # checks for consistency, creates a Packer and runs it.
    #
    def run
      dbg("-- packengine run")
      
      return nil, ERROR_NO_PARTS if @boxes.empty?
      return nil, ERROR_NO_BIN if @options.base_bin_length < EPS && @leftovers.empty?
      return nil, ERROR_PARAMETERS if @options.saw_kerf < 0
      return nil, ERROR_PARAMETERS if @options.trimsize < 0

      @warnings << WARNING_SAW_KERF_SMALL if @options.saw_kerf < EPS
      @warnings << WARNING_TRIM_SIZE_LARGE if @options.trimsize > MAX_TRIMSIZE_FACTOR*@options.saw_kerf

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
      packer = nil if err > ERROR_SUBOPT
      return packer, err 
    end
  end
end