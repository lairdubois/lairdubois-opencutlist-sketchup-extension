module Ladb::OpenCutList::BinPacking1D

  require_relative 'packing1d'
  require_relative 'options'
  require_relative 'packer'
  require_relative 'box'
  require_relative 'bin'

  # PackEngine: setup and run bin packing in 1D
  class PackEngine < Packing1D
  
    attr_accessor :warnings
      
    def initialize(options)
      super(options)
      @leftovers = []
      @boxes = []
      @warnings = []
    end
    
    # add scrap bars to be used
    def add_bin(length)
      dbg("   . BIN length #{length}")
      newbin = Bin.new(length, BIN_TYPE_LO, @options)
      # sorting is not necessary, algorithm will pick largest available
      @leftovers.push(newbin).sort_by!(&:length)
    end
        
    # add boxes (for the 1D case, we will call these "parts")
    def add_box(length, data = nil)
      dbg("   . BOX length=#{length}, data=#{data}")
      @boxes << Box.new(length, data)
    end
    
    # run the packing, if successful, run also basic stats
    def run
      dbg("-- packengine run")
      return nil, ERROR_NO_PARTS if @boxes.empty?
      return nil, ERROR_NO_BIN if @options.base_bin_length < EPS && @leftovers.empty?
      
      @warnings << WARNING_SAW_KERF_SMALL if @options.saw_kerf < EPS
      @warnings << WARNING_TRIM_SIZE_LARGE if @options.trimsize > MAX_TRIMSIZE_FACTOR*@options.saw_kerf
      
      dbg("-> create packer with nb of leftovers=#{@leftovers.length}") 
      packer = Packer.new(@options)
      packer.leftovers = @leftovers
      packer.boxes = @boxes
      
      dbg("-> running packer")
      err = packer.run()
      
      packer = nil if err > ERROR_SUBOPT
      return packer, err 
    end
  end
end