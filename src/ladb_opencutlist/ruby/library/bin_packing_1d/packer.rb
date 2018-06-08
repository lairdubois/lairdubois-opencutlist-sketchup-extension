module BinPacking1D

  class Packer < Packing1D
    attr_accessor :unplaced_boxes, :original_bins

    def initialize(saw_kerf, cleanup=5, debugging=false)
      @saw_kerf = saw_kerf
      @original_bins = []
      @unplaced_boxes = []
      @cleanup = cleanup
      @packed = false
      @@debugging = debugging
    end
    
    def pack(bins, boxes)
      s = BinPacking1D::Score.new
      cuts = []
      placed_boxes = []
      
      # remember original length of first bin, aka reference bin
      bin_index = bins.length
      @b_l = bins[0].length
      @b_x = bins[0].x
      
      # keep a copy of original bins for drawing at the end
      bins.each do |bin|
        @original_bins << bin.clone
      end
      # clean up bins if option set
      bins.each do |bin|
        bin.cleanup(@cleanup)
      end
            
      # sort boxes length decreasing (heuristic)
      boxes = boxes.sort_by {|b| [b.length]}.reverse

      until boxes.empty?
        db "- start placing box ->"
        
        # get next box to place
        box = boxes.shift
        
        # find best position for box in collection of bins
        i = s.find_position_for_box(box, bins)
        if i == -1
          # check if box is larger than available standard bin
          if box.length >= @b_l
            @unplaced_boxes << box
            next
          end
          cs = BinPacking1D::Bin.new(@b_l, @b_x, bin_index)
          @original_bins << cs.clone
          cs.cleanup(@cleanup)
          bin_index += 1
        else
          cs = bins[i]
          bins.delete_at(i)
        end
        box.x = cs.x
        box.index = cs.index
        placed_boxes << box
    
        r = cs.cut(box.length, @saw_kerf)
        cuts << BinPacking1D::Cut.new(cs.x + box.length, cs.index)
        # leftover returns to bins
        bins << r
      end
      
      # collect stuff into a single object for reporting     
      @original_bins.each_with_index do |bin, index|
        placed_boxes.each do |box|
          if box.index == index
            bin.boxes << box
          end
        end
        bins.each do |b|
          if b.index == index
             bin.leftovers << b
           end
        end
        cuts.each do |cut|
          if cut.index == index
            bin.cuts << cut
          end
        end
      end
      @packed = true
    end
    
    def print_result
      return if !@packed
      if @unplaced_boxes.length != 0
        @unplaced_boxes.each do |box|
          pstr "unplaced item #{'%10s' % cu(box.length)} (#{'%3s' % box.number} ) "
        end
      end
      @original_bins.each do |bin|
        s = "dim #{'%3d' % bin.index.to_s} #{cu(bin.length)}/#{cu(@saw_kerf)}/#{cu(@cleanup)} : "
        bin.boxes = bin.boxes.sort_by { |b| [b.length] }.reverse
        l = bin.boxes.inject(0){|sum, x| sum + x.length}
        s += " tot = #{'%4d' % bin.boxes.length}, #{'%10s' % cu(l)} ->"
        groups = bin.boxes.group_by { |b| b.length }
        groups.each do |l, a|
          s += "#{'%10s' % cu(l)} x #{a.length} (#{'%3s' % a[0].number} ) |"
        end
        bin.leftovers = bin.leftovers.sort_by { |b| b.length }.reverse
        bin.leftovers.each do |b|
          s += "#{'%10s' % cu(b.length)} ."
        end
        pstr s
      end
    end

  end
end
