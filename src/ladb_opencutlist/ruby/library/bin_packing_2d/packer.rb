module BinPacking2D
  class Packer < Packing2D
    attr_accessor :rotatable, :sawkerf, :cleanup, :original_bins, :unplaced_boxes, :cuts, :placed_boxes, 
      :score, :split, :performance

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
    
    def preprocess_supergroups(boxes, stack_horizontally)
      sboxes = []
      if stack_horizontally then
        maxlength = @b_l - 2*@cleanup
        width_groups = boxes.group_by { |b| [b.width, b.length] }
        width_groups.each do |k, v|
          db "start of sb"
          nb = BinPacking2D::Box.new(0, k[0], "supergroup")
          sboxes << nb
          v = v.sort_by  { |b| [b.length]}.reverse
          v.each do |box|
            db "box #{'%6.0f' % box.length} #{'%6.0f' % box.width}"
            if !nb.stack_length(box, @sawkerf, maxlength)
              added = false
              sboxes.each do |s|
                if !added && s.stack_length(box, @sawkerf, maxlength)
                  added = true
                end
              end
              if !added
                nb = BinPacking2D::Box.new(0, k[0], "supergroup")
                sboxes << nb
                nb.stack_length(box, @sawkerf, maxlength)
              end            
            end
          end
        end
      else
        maxwidth = @b_w - 2*@cleanup
        length_groups = boxes.group_by { |b| [b.length, b.width] }
        length_groups.each do |k, v|
          db "start of sb"
          nb = BinPacking2D::Box.new(k[0], 0, "supergroup")
          sboxes << nb
          v = v.sort_by  { |b| [b.width]}.reverse
          v.each do |box|
            db "box #{'%6.0f' % box.length} #{'%6.0f' % box.width}"
            if !nb.stack_width(box, @sawkerf, maxwidth)
              added = false
              sboxes.each do |s|
                if !added && s.stack_width(box, @sawkerf, maxwidth)
                  added = true
                end
              end
              if !added
                nb = BinPacking2D::Box.new(k[0], 0, "supergroup")
                sboxes << nb
                nb.stack_width(box, @sawkerf, maxwidth)
              end            
            end
          end
        end
      end
      db "end of sb"
      sboxes.each do |box|
        db "#{box.length} #{box.width}"
        box.sboxes.each do |b|
          db "   #{b.length} #{b.width}"
        end
      end
      return sboxes
    end
    
    def postprocess_supergroups(sboxes, stack_horizontally) 
      boxes = []
      cuts = []

      if stack_horizontally
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
              y = y + b.width + @sawkerf
              if cut_counts > 0
                cuts << BinPacking2D::Cut.new(b.x, b.y + b.width, b.length, true, b.index, false)
                cut_counts = cut_counts -1
              end
            else
              x = x + b.length + @sawkerf
              if cut_counts > 0
                cuts << BinPacking2D::Cut.new(b.x + b.length, b.y, b.width, false, b.index, false)
                cut_counts = cut_counts -1
              end
            end
            boxes << b
          end 
        end
      else
        sboxes.each do |sbox|
          x = sbox.x
          y = sbox.y
          db "sbox width : #{sbox.sboxes.length}"
          cut_counts = sbox.sboxes.length() -1
          sbox.sboxes.each do |b|
            b.x = x
            b.y = y
            b.index = sbox.index
            if sbox.rotated
              b.rotate
              y = y + b.length + @sawkerf
              if cut_counts > 0
                cuts << BinPacking2D::Cut.new(b.x + b.length, b.y, b.width, false, b.index, false)
                cut_counts = cut_counts -1
              end
            else
              y = y + b.width + @sawkerf
              if cut_counts > 0
                cuts << BinPacking2D::Cut.new(b.x, b.y + b.width, b.length, true, b.index, false)
                cut_counts = cut_counts -1
              end
            end
            boxes << b
          end 
        end
      end
      return boxes, cuts
    end
 
    def pack(bins, boxes, score, split, stacking, stack_horizontally)
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
      
      # preprocess too large items
      boxes.each_with_index do |box, i|
        if !bins[0].encloses?(box)
          @unplaced_boxes << box
          boxes.delete_at(i)
          db "too large deleted"
        end
      end

      # preprocess super groups
      boxes = preprocess_supergroups(boxes, stack_horizontally) if stacking
      # sort boxes width/length decreasing (heuristic)
      boxes = boxes.sort_by { |b| [b.width, b.length] }.reverse
      
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
      if stacking
        placed_boxes, add_cuts = postprocess_supergroups(placed_boxes, stack_horizontally)
        cuts.concat(add_cuts)
      end
      
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
      end
      @packed = true
      @performance = get_performance
    end
    
    def get_performance
      if @packed
        largest_bin = BinPacking2D::Bin.new(0, 0, 0, 0, 0)
        largest_area = 0
        
        p = BinPacking2D::Performance.new(@score, @split)
        @original_bins.each do |bin|
          if @cleanup > 0
            bin.cleaned = true
            bin.cleancut = @cleanup
          end
          
          max_x = 0
          max_y = 0
          bin.boxes.each do |box|
            p.h_length += box.length
            p.v_length += box.width
            if box.x + box.length > max_x
              max_x = box.x + box.length
            end
            if box.y + box.width > max_y
              max_y = box.y + box.width
            end
          end

          bin.cuts.each do |cut|
            if cut.horizontal && cut.x + cut.length > max_x
              cut.length = max_x - cut.x
            end
            if !cut.horizontal && cut.y + cut.length > max_y
              cut.length = max_y - cut.y
            end           
            p.cutlength += cut.length
            p.h_cutlength += cut.get_h_cutlength()
            p.v_cutlength += cut.get_v_cutlength()
          end
          if max_y < bin.width
            c = BinPacking2D::Cut.new(bin.x+bin.cleancut, max_y, bin.length-2*bin.cleancut, true, bin.index)
            hl = BinPacking2D::Bin.new(bin.length-2*bin.cleancut, bin.width-max_y-@sawkerf-bin.cleancut, 
              bin.x+bin.cleancut, max_y+@sawkerf, bin.index)
            bin.cuts.unshift(c)
          end 
          if max_x < bin.length
            c = BinPacking2D::Cut.new(max_x, bin.y+bin.cleancut, max_y - bin.cleancut, false, bin.index)
            vl = BinPacking2D::Bin.new(bin.length-max_x-bin.cleancut-@sawkerf, max_y-bin.cleancut, 
              max_x+@sawkerf, bin.y+bin.cleancut, bin.index)
            bin.cuts.unshift(c)
          end
          p.nb_leftovers += bin.leftovers.size
          leftovers = []
          bin.leftovers.each do |b|
            b.crop(max_x, max_y)
            if b.length > 0 && b.width > 0
              leftovers << b
            end
          end
          bin.leftovers = leftovers

          bin.leftovers << vl if !vl.nil? && vl.length > 0 && vl.width > 0
          bin.leftovers << hl if !hl.nil? && hl.length > 0 && hl.width > 0
  
          bin.leftovers.each do |b|
            a = b.area
            if a > largest_area
              largest_bin = b
              largest_area = a
            end
          end
        end

        p.largest_leftover = largest_bin
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

