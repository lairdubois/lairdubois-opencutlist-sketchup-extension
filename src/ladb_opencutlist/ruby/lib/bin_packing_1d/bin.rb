module Ladb::OpenCutList::BinPacking1D

  #
  # Implements the container of elements Box.
  #
  class Bin < Packing1D
  
    # raw length of bin.
    attr_accessor :length 
    
    # Type of bin from Packing1d.
    attr_reader :type
    
    # List of boxes that have been placed into this bin.
    attr_reader :boxes
    
    # List of necessary cuts (starting a 0 of the raw board).
    attr_reader :cuts
    
    # Current net length of the leftover.
    attr_reader :current_leftover
    
    # Percentage [0,100] of used versus raw length.
    attr_reader :efficiency
    
    # Net used length (length of boxes + saw kerf).
    attr_reader :net_used
    
    # Number of cuts necessary, considers trimming cuts if applicable.
    attr_reader :cut_counts
    
    # Current position after adding boxes (considers trimming and saw kerf).
    # This position can theoretically be outside of the bin because it
    # is the position of the right side of the saw kerf (assuming
    # waste is on the right side).
    attr_reader :current_position
    
    #
    # Initialize a new Bin, ensure that it has a length > 0.
    #
    def initialize(length, type, options = nil)
      super(options)

      @type = type
      # making sure it is a float
      @length = length
      if @length <= 0
        raise(Packing1DError, "Trying to initialize a bin with zero or negative length")
      end
      
      @current_position = @options.trimsize 
      @current_leftover = @length - 2*@options.trimsize
      @boxes = []
      @cuts = []

      @efficiency = 0.0
      @cut_counts = 0
    end

    # 
    # Add a box to this bin and update the current position and leftover.
    #
    def add(box)
      dbg("   adding box #{box.length} after #{@current_position} in bin #{length}")
      @current_position += box.length + @options.saw_kerf
      #@current_position += @options.trimsize if @boxes.empty?
      @boxes << box
      # current leftover cannot be negative
      @current_leftover = [(@length - @options.trimsize) - @current_position, 0].max
    end
    
    #
    # Sorts the boxes in descending order, run at the
    # end of packing.
    #
    def sort_boxes()
      dbg("   sorting boxes")
      @boxes.sort!{|a, b| -a.length <=> -b.length}
      @cuts = []
      @current_position = @options.trimsize
      @boxes.each do |box|
        box.x = @current_position
        @current_position += box.length
        @cuts << @current_position
        @current_position += @options.saw_kerf
      end
      #
      # the last cut may not be necessary. this is the case when
      # the last part exactly fits into the leftover without cutting
      #
      @current_leftover = [(@length - @options.trimsize) - @current_position, 0].max
      # current position should not be out of the board for drawing purposes
      @current_position = [@current_position, @length].min
      
      @net_used = @length - @current_leftover
      @efficiency = @net_used/@length.to_f*100.0
      if @efficiency > 100 + EPS
        #@efficiency = 100
        raise(Packing1DError, "Bin.sort_boxes: float precision error, length=#{@length}, current leftover=#{@current_leftover}")
      end
    end
    
    # 
    # Returns the net (available) length of this bin.
    # Returned value is never smaller than 0.
    #
    def netlength
      return [@length - 2 * @options.trimsize, 0].max
    end

  end
end
