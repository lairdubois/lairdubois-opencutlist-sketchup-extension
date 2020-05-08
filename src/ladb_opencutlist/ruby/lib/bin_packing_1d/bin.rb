module Ladb::OpenCutList::BinPacking1D

  #
  # Implements the container of elements Box
  #
  class Bin < Packing1D
  
    # raw length of bin.
    attr_accessor :length 
    
    # type of bin from packing1d.
    attr_reader :type
    
    # list of boxes that have been placed into this bin.
    attr_reader :boxes
    
    # list of necessary cuts (starting a 0 of the raw board).
    attr_reader:cuts
    
    # current net length of the leftover.
    attr_reader :current_leftover
    
    # percentage [0,100] of used versus raw length.
    attr_reader :efficiency
    
    # number of cuts necessary, considers trimming cuts if applicable.
    attr_reader :cut_counts
    
    # TBD
    attr_reader :current_position
    
    #
    # initialize the bin, ensure that it has a length > 0.
    #
    def initialize(length, type, options = nil)
      super(options)

      @type = type
      # making sure it is a float
      @length = length*1.0
      if @length <= 0
        raise(Packing1DError, "Trying to initialize a bin with zero or negative length")
      end
      
      if @options.trimsize > 0
        @current_leftover = @length - 2*@options.trimsize
        @current_position = @options.trimsize*1.0
      else
        @current_leftover = @length
        @current_position = 0.0
      end
      
      @boxes = []
      @cuts = []

      @efficiency = 0.0
      @cut_counts = 0
    end

    # 
    # add a box to this bin and update the current position and leftover.
    #
    def add(box)
      dbg("   adding box #{box.length} after #{@current_position}")
      if @current_position + box.length > (@length - @options.trimsize) 
        raise(Packing1DError, "Trying to add a box larger than this bin's capacity, even with trimming")
      end
      @boxes << box

      @cuts << @current_position + box.length
      @current_position += box.length + @options.saw_kerf
      # the leftover is from current position to the end of the 
      # board, if trimsize is present, this may be negative.
      # we make it zero!
      @current_leftover = [(@length - @options.trimsize) - @current_position, 0].max 

      dbg("   new #{@current_position}")
      @efficiency = (@length - @current_leftover)/@length.to_f*100.0
      if @efficiency > 100
        raise(Packing1DError, "This should never happen, length=#{@length}, current leftover=#{@current_leftover}")
      end
    end
    
    # 
    # netlength returns the net (available) length of this bin.
    # Returned value is never smaller than 0.
    #
    def netlength
      return [@length - 2 * @options.trimsize, 0].max
    end

  end
end
