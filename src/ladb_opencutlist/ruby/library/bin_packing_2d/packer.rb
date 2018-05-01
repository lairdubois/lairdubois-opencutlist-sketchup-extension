module BinPacking2D
  
  require_relative "packing2d"
  require_relative "box"
  require_relative "bin"
  require_relative "cut"
  require_relative "score"
  require_relative "performance"
  
  # used just for html output
  require_relative "export_binding"
  require_relative "export"
  require "erb"
    
  class Packer < Packing2D
    attr_accessor :rotatable, :sawkerf, :cleanup, :original_bins, :unplaced_boxes, :cuts, :placed_boxes, :score, :split, :performance

    def initialize(rotatable, sawkerf, cleanup=5, debugging=false)
      @sawkerf = sawkerf
      @original_bins = []
      @cleanup = cleanup
      @rotatable = rotatable
      @placed_boxes = []
      @unplaced_boxes = []
      @cuts = []
      @bins = []
      @boxes = []
      @packed = false
      @b_x = 0
      @b_y = 0
      @b_w = 0
      @b_l = 0
      @performance = nil
      @score = -1
      @split = -1
      @@debugging = debugging
    end

    # if box is rotatable, then rotate it so that it's longer than wide
    def preprocess_rotatable(boxes)
      tmp_boxes = []
      boxes.map! { |box|
        if box.width > box.length && box.length < @b_w && box.width < @b_l then
          tmp_boxes << box.rotate
          db "box rotated #{box.length} #{box.width}"
        else
          tmp_boxes << box
        end
      }
      return tmp_boxes
    end
    
    def preprocess_supergroups_length(boxes)
      maxlength = @b_l - 2*@cleanup
      sboxes = []
      groups = boxes.group_by { |b| b.width }
      groups.each do |k, v|
        db "start of sb"
        db "common width = #{'%6.0f' % k}"
        nb = BinPacking2D::Box.new(0, k, "supergroup")
        sboxes << nb
        v = v.sort_by  { |b| [b.length]}.reverse
        v.each do |box|
          db "box #{'%6.0f' % box.length} #{'%6.0f' % box.width}"
          if !nb.add(box, @sawkerf, maxlength)
            nb = BinPacking2D::Box.new(0, k, "supergroup")
            sboxes << nb
            nb.add(box, @sawkerf, maxlength)
          end
        end
      end
      db "end of sb"
      return sboxes
    end

    def postprocess_supergroups(sboxes) 
      boxes = []
      cuts = []
      sboxes.each do |sbox|
        x = sbox.x
        y = sbox.y
        db "sbox length : #{sbox.sboxes.length}"
        cut_counts = sbox.sboxes.length() -1
        sbox.sboxes.each do |b|
          b.x = x
          b.y = y
          b.index = sbox.index
          if sbox.rotated
            b.rotate
          end
          x = x + b.length + @sawkerf
          boxes << b
          if cut_counts > 0
            cuts << BinPacking2D::Cut.new(b.x + b.length, b.y, b.width, false, b.index, false)
            cut_counts = cut_counts -1
          end
        end 
      end
      return boxes, cuts
    end
 
    def pack(bins, boxes, score, split)
      s = BinPacking2D::Score.new
      @score = score
      @split = split
      cuts = []
      placed_boxes = []
      db "start -->"

      # print bins & boxes for debugging
      bins.each do |bin|
        bin.print_without_position
      end
      
      boxes.each do |box|
        box.print_without_position
      end
      
      bin_index = bins.length
      # remember original length/width of first bin, aka reference bin
      @b_l = bins[0].length
      @b_w = bins[0].width
      @b_x = bins[0].x
      @b_y = bins[0].y
      
      # keep a copy of original bins for drawing at the end
      bins.each do |bin|
        @original_bins << bin.clone
      end
      # clean up bins if option set
      bins.each do |bin|
        bin.cleanup(@cleanup)
      end
      # preprocess (rotate) if rotatable
      if @rotatable then
        boxes = preprocess_rotatable(boxes)
      end
      # sort boxes width/length decreasing (heuristic)
      boxes = boxes.sort_by { |b| [b.width, b.length] }.reverse
      
      # preprocess too large items
      boxes.each_with_index do |box, i|
        if !bins[0].encloses?(box)
          @unplaced_boxes << box
          boxes.delete_at(i)
          db "too large deleted"
        end
      end

      # preprocess super groups
      boxes = preprocess_supergroups_length(boxes)

      until boxes.empty?
        db "- start placing box ->"
        
        # get next box to place
        box = boxes.shift
        
        # find best position for box in collection of bins
        i, using_rotated = s.find_position_for_box(box, bins, @rotatable, @score)
        if i == -1 
          # check if box is larger than available standard bin, SHOULD NEVER HAPPEN!
          if box.too_large?(@b_l, @b_w, rotatable)
            @unplaced_boxes << box
            next
          end
          cs = BinPacking2D::Bin.new(@b_l, @b_w, @b_x, @b_y, bin_index)
          @original_bins << cs.clone
          cs.cleanup(@cleanup)
          bin_index += 1
        else
          if using_rotated
            box.print
            box.rotate
            db "rotated box"
            box.print
          end
          cs = bins[i]
          bins.delete_at(i)
        end

        # the box will be placed at the top/left corner
        box.x = cs.x
        box.y = cs.y
        box.index = cs.index
        placed_boxes << box

        cs.print
        box.print
        # split horizontally first
        if cs.split_horizontally_first?(box, @split)
          if box.width < cs.width # top, bottom
            cs, sb = cs.split_horizontally(box.width, sawkerf)
            cuts << BinPacking2D::Cut.new(cs.x, cs.y + box.width, cs.length, true, cs.index)
            # leftover returns to bins
            bins << sb
          end
          if box.length < cs.length # left, right
              cs, sr = cs.split_vertically(box.length, sawkerf)
              cuts << BinPacking2D::Cut.new(cs.x + box.length, cs.y, cs.width, false, cs.index)
              bins << sr
          end
        else
          if box.length < cs.length # left, right
            cs, sr = cs.split_vertically(box.length, sawkerf)
            cuts << BinPacking2D::Cut.new(cs.x + box.length, cs.y, cs.width, false, cs.index)
            bins << sr
          end
          if box.width < cs.width # top, bottom
            cs, sb = cs.split_horizontally(box.width, sawkerf)
            cuts << BinPacking2D::Cut.new(cs.x, cs.y + box.width, cs.length, true, cs.index)
            bins << sb
          end
        end
        db "- end placing box ->"
      end

      # postprocess supergroups
      placed_boxes, add_cuts = postprocess_supergroups(placed_boxes)
      cuts.concat(add_cuts)
      
      # collect stuff into a single object for reporting
      @original_bins.each_with_index do |bin, index|
        bin.strategy = get_strategy_str(@score, @split)
        placed_boxes.each do |box|
          if box.index == index 
            bin.boxes << box
          end
        end
        cuts.each do |cut|
          if cut.index == index 
            bin.cuts << cut
          end
        end
        bins.each do |b|
          if b.index == index && b.width >= sawkerf && b.length >= sawkerf
            bin.leftovers << b
          end
        end
      end # do
      @packed = true
      @performance = get_performance
    end
    
    def get_performance
      if @packed
        largest_bin = BinPacking2D::Bin.new(0, 0, 0, 0, 0)
        cut_length = 0
           
        p = BinPacking2D::Performance.new(@score, @split)
        @original_bins.each do |bin|
          p.nb_leftovers += bin.leftovers.size
          bin.leftovers.each do |b|
            if b.larger?(largest_bin, @rotatable) 
              largest_bin = b
            end
          end
          bin.cuts.each do |cut|
            cut_length += cut.length
          end
        end
        p.largest_leftover = largest_bin
        p.cut_length = cut_length
        p.nb_bins = @original_bins.length
        return p
      else
        return nil
      end
    end

    def print_result

      return if !@packed 
      # results from here on
      db "-results->"
      db "-unplaced boxes->"
      if @unplaced_boxes.length != 0 then
        @unplaced_boxes.each do |box|
          box.print
        end
      end
      @original_bins.each do |bin|
        db "-placement-> id:" + bin.index.to_s
        bin.print
        db "-boxes-> " + bin.boxes.length.to_s
        bin.boxes = bin.boxes.sort_by { |b| [b.width, b.length] }.reverse
        bin.boxes.each do |box|
          box.print
        end
        db "-cuts-> nb:" + bin.cuts.length.to_s
        length = 0
        bin.cuts.each do |cut|
          length += cut.length
          cut.print
        end
        db "-cuts-> length:" + "#{ '%8.0f' % length}"
        db "-leftovers"
        bin.leftovers = bin.leftovers.sort_by { |b| [b.width, b.length] }.reverse
        bin.leftovers.each do |b|
          b.print
        end
        db "-e->"
      end
      db "-cutlist--> in: sheet(_r).html"
    end
  end
end

# eof
