module Ladb::OpenCutList::BinPacking1D
  class Bar < Packing1D
    attr_accessor :type, :length, :parts,
                  :current_leftover, :efficiency, :cuts

    def initialize(type, length, trim_size, saw_kerf)
      @type = type                       # NEW, LEFTOVER, UNFIT

      @length = length                   # raw length of bar
      @trim_size = trim_size             # trimsize on both ends
      @saw_kerf = saw_kerf               # width of saw kerf
      @parts = []                        # lengths of placed parts

      @cuts = []
      @current_leftover = @length - @trim_size - @saw_kerf
      @current_position = @trim_size
      @cuts << @current_position if @current_position > 0 # first cut

      @net_length_parts = 0

      @efficiency = (@length - @current_leftover)/@length.to_f
    end

    def add(id, length)
      @parts << {:length => length, :id => id}
      @current_leftover = @current_leftover - length - @saw_kerf
      @current_position += length + @saw_kerf
      @cuts << @current_position if @current_position < @length
      @net_length_parts += length

      @efficiency = (@length - @current_leftover)/@length.to_f
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
