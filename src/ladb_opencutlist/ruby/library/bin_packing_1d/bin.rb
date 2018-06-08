module BinPacking1D
  class Bin < Packing1D
    attr_accessor :length, :x, :index, :boxes, :leftovers, :cleaned, :cleancut, :cuts

    def initialize(length, x, index)
      @length = length
      @index = index
      @x = x
      @boxes = []
      @leftovers = []
      @cuts = []
      @cleancut = 0
      @cleaned = false
    end
    
    def encloses?(box)
      return @length >= box.length
    end
    
    def clone
      b = Bin.new(@length, @x, @index)
      b.cleaned = @cleaned
      b.cleancut = @cleancut
      return b
    end
    
    def cleanup(cut)
      if cut != 0 then
        @cleancut = cut
        @length -= 2 * @cleancut
        @x = @cleancut
        @cleaned = true
      end
    end
    
    def cut(length, saw_kerf)
      cs = self.dup
      if @length > length + saw_kerf
        cs.length -= length + saw_kerf
        cs.x += length + saw_kerf
      else
        cs.length = 0
        cs.x = 0
      end
      return cs
    end

=begin
def print
      f = '%6.0f'
      db "bin #{f % @x} #{f % @length} #{f % @index}"
    end
    
    def title
      return "Dimensional id #{@index}" 
    end
    
    def label
      return "#{'%6.0f' % @length}" 
    end
=end

  end
end
