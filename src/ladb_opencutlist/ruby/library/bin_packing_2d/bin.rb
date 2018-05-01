module BinPacking2D
  class Bin < Packing2D
    attr_accessor :length, :width, :index, :x, :y, :boxes, :cuts, 
      :leftovers, :cleaned, :cleancut, :length_cuts, :strategy

    def initialize(length, width, x, y, index)
      @length = length
      @width = width
      @index = index
      @x = x
      @y = y
      @boxes = []
      @cuts = []
      @length_cuts = 0
      @leftovers = []
      @cleancut = 0
      @cleaned = false
      @strategy = ""
    end

    def clone
      b = Bin.new(@length, @width, @x, @y, @index)
      b.cleaned = @cleaned
      b.cleancut = @cleancut
      b.strategy = @strategy
      return b
    end
    
    def encloses?(box)
      return @length >= box.length && @width >= box.width
    end
    
    def larger?(bin, rotate)
      return (@length*@width) > (bin.length*bin.width)
    end
    
    def encloses_rotated?(box)
      return @length >= box.width && @width >= box.length
    end

    def efficiency
      boxes_area = 0
      @boxes.each { |box| boxes_area += box.area }
      boxes_area * 100 / area
    end

    def title
      l = 0
      @cuts.each do |cut|
        l += cut.length
      end
      length = cu(@length + 2 * @cleancut)
      width = cu(@width + 2 * @cleancut)
      l = cu(l)
      "Sheet id #{@index} " + @strategy + "<br>" + 
      "Size: #{length} x #{width}   " +
      "Efficiency: #{'%3.2f' % efficiency}%   " +
      "Length of Cuts: #{l}   " +
      "Cleaned: " + (@cleaned ? "#{@cleancut}" : "")
    end
    
    def area
      return @length * @width
    end

    def cleanup(cut)
      if cut != 0 then
        @cleancut = cut
        @length -= 2 * @cleancut
        @width -= 2 * @cleancut
        @x = @cleancut
        @y = @cleancut
        @cleaned = true
      end
    end

    def split_vertically(v, sawkerf)
      sl = self.clone
      sl.length = v
      sr = self.clone
      if @length > v
        sr.length -= v + sawkerf
        sr.x += v + sawkerf
        db "v #{v}"
      else
        sr.length = 0
        sr.width = 0
        sr.x += v + sawkerf
      end
      return sl, sr
    end

    def split_horizontally(h, sawkerf)
      st = self.dup
      st.width = h
      sb = self.clone
      if @width > h
        sb.width -= h + sawkerf
        sb.y += h + sawkerf
        db "h #{h}"
      else
        sb.length = 0
        sb.width = 0
        s.y += h + sawkerf
      end
      return st, sb
    end
    
    def split_horizontally_first?(box, heuristic)
      w = @width - box.width
      l = @length - box.length
      
      case heuristic
      when SPLIT_SHORTERLEFTOVER_AXIS
        decision = (w <= l)
      when SPLIT_LONGERLEFTOVER_AXIS
        decision = (w > l)
      when SPLIT_MINIMIZE_AREA
        decision = (l * box.width > box.length * w) 
      when SPLIT_MAXIMIZE_AREA
        decision = (l * box.width <= box.length * w)
      when SPLIT_SHORTER_AXIS
        decision = (@length <= @width)
      when SPLIT_LONGER_AXIS
        decision = (@length > @width)
      else
        decision = true
      end
      
      ab = box.length*w
      ar = l *box.width
      db "ab = #{'%7.0f' % ab}"
      db "ar = #{'%7.0f' % ar}"
      return decision
    end
    
    def print
      m = @cleaned? " c": ""
      db ("bin #{cu(@x)}  #{cu(@y)} #{cu(@length)} #{cu(@width)}" + m)
    end

    def print_without_position
      f = '%6.0f'
      m = @cleaned? " c": ""
      db "bin #{f % @length} #{f % @width}" + m
    end 
    
    def label
      length = cu(@length)
      width = cu(@width)
      return "#{length} x #{width}"
    end
    
  end
end
