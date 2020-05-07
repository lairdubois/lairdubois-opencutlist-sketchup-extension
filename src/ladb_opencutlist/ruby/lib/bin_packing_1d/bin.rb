module Ladb::OpenCutList::BinPacking1D
  class Bin < Packing1D
    attr_accessor :type, :x, :length, :boxes, :trimsize, :saw_kerf,
                  :efficiency, :current_position, :current_leftover,
                  :cuts, :total_length_cuts
                      
    def initialize(length, type, options = nil)
      super(options)

      @type = type                       # NEW, LEFTOVER, UNFIT
      @length = length                   # raw length of bar
      @trimsize = options.trimsize       # trimsize on both ends
      @saw_kerf = options.saw_kerf       # width of saw kerf
      @boxes = []                        # placed boxes
      @cuts = []
      @current_leftover = @length - @trimsize - @saw_kerf
      if @trimsize > 0
        @cuts << @trimsize
        @current_position = @trimsize
      else
        @current_position = @trimsize + @saw_kerf
      end
      @net_length_parts = 0
      @efficiency = 3.1415
      @total_length_cuts = 0             # does not really make sense here!
    end

    def add (box)
      # add a box to this bin and update position and leftover
      dbg("   adding box #{box.length} after #{@current_position}")
      if @current_position + box.length > @length
        dbg("BIG BIG PROBLEM")
        exit
      end
      @boxes << box
      # if start is left
      #   . first cut is on the left sider of this mark (waste side)
      #   . next cuts are on the right side of this mark (waste side)
      @cuts << @current_position + box.length
      @current_position += box.length + @saw_kerf
      @current_leftover = @length - @trimsize - @current_position
      dbg("   new #{@current_position}")
      @net_length_parts += box.length
      @efficiency = (@length - @current_leftover)/@length.to_f
    end
    
    def print()
      # debugging only 
      @boxes.each do |b|
        dbg("   box length = #{b.length}")
      end
    end
    
    def netlength()
      # return the net (available) length of this bin
      # cannot be smaller than 0
      return [@length - 2 * @options.trimsize, 0].max
    end
    
    def leftover
      # MUST be removed, access over instance variable
      @current_leftover
    end
    
    def nb_of_cuts
      # MUST be removed, access over instance variable
      return @cuts.length
    end

    def all_lengths
      # funky code, REVIEW!
      if @type == BAR_TYPE_UNFIT
        @length
      else
        net = 0
        raw = 0
        raw = @trim_size + @saw_kerf if @trim_size > 0
        @parts.each do |p|
          net += p[:length]
        end
        raw += (@parts.length) * @saw_kerf + net
        if raw > @length
          print('DANGER _ ERROR!\n')
          raw = @length
        end
        leftover = @length - raw - @saw_kerf
        [raw, net, leftover]
      end
    end
    
  end
end
