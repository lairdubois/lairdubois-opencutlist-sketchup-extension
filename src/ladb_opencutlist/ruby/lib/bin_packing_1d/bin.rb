module Ladb::OpenCutList::BinPacking1D
  class Bin < Packing1D
    attr_accessor :type, :length, :x,  :boxes,
                  :current_leftover, :current_position, :efficiency,
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
      @current_position = @trimsize + @saw_kerf
      @cuts << @current_position if @current_position > 0 # first cut
      
      @net_length_parts = 0
      @efficiency = 3.1415
      @total_length_cuts = 0
    end

    def add (box)
      @boxes << box
      @current_leftover = @current_leftover - box.length - @saw_kerf
      @current_position += box.length + @saw_kerf
      @cuts << @current_position if @current_position < @length
      @net_length_parts += box.length
      @efficiency = (@length - @current_leftover)/@length.to_f
    end
    
    def print()
      @boxes.each do |b|
        dbg("   box length = #{b.length}")
      end
    end
    
    def netlength
      return @length - 2 * @options.trimsize
    end
    
    def leftover
      @current_leftover
    end
    
    def nb_of_cuts
      return @cuts.length
    end

    def all_lengths
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
    
    #def compute_efficiency
    #  @efficiency = (@length - @current_leftover)/@length.to_f
    #end

  end
end
