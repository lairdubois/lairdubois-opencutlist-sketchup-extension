module Ladb::OpenCutList::BinPacking1D

  require_relative 'packing1d'
  require_relative 'options'
  require_relative 'packer'
  require_relative 'bar'
  require_relative 'result'

  # PackEngine: setup and run bin packing in 1D
  class PackEngine < Packing1D
  
    attr_accessor :warnings
      
    def initialize(options)
      @options = options
      @leftovers = []
      @parts = []
      
      @warnings = []
    end
    
    # add scrap bars to be used
    def add_bin(length)
      @leftovers << length
    end
    
    # add boxes (for the 1D case, we will call these "parts")
    def add_box(length, id)
      @parts << {:length => length, :id => id}
    end
    
    # run the packing, if successful, run also basic stats
    def run
    
      return nil, ERROR_NO_PARTS if @parts.empty?
      return nil, ERROR_NO_BINS if @options.std_length < EPS && @leftovers.empty?
      return nil, ERROR_NOT_IMPLEMENTED if !@leftovers.empty?
      
      @warnings << WARNING_SAW_KERF_SMALL if @options.saw_kerf < EPS
      @warnings << WARNING_TRIM_SIZE_LARGE if @options.trim_size > 5*@options.saw_kerf
      
      packer = Packer.new(@options)
      packer.leftovers = @leftovers
      packer.parts = @parts
      
      err = packer.run()
      
      if err == ERROR_NONE or err == ERROR_SUBOPT 
        packer.prep_results
      else
        packer = nil
      end
      return packer, err 
    end
  end
end