module Ladb::OpenCutList::BinPacking2D

  class Processor < Packing2D

    def initialize(options)
      @saw_kerf = options.saw_kerf
      @presort = options.presort
      @has_grain = options.has_grain
      @trimsize = options.trimsize
      @stacking = options.stacking
      
      @base_panel_trimmed_length = [options.base_bin_length - 2*@trimsize, 0].max
      @base_panel_trimmed_width = [options.base_bin_width - 2*@trimsize, 0].max
      
      @panel_trimmed_length = @base_panel_trimmed_length
      @panel_trimmed_width = @base_panel_trimmed_width
    end
    
    # Sort boxes according to presort option set
    #
    def sort_boxes(boxes, order=@presort)
      case order
      when PRESORT_WIDTH_DECR
        boxes = boxes.sort_by { |b| [b.width, b.length] }.reverse
      when PRESORT_LENGTH_DECR
        boxes = boxes.sort_by { |b| [b.length, b.width] }.reverse
      when PRESORT_AREA_DECR
        boxes = boxes.sort_by { |b| [b.width * b.length] }.reverse
      when PRESORT_PERIMETER_DECR
        boxes = boxes.sort_by { |b| [b.length + b.width] }.reverse
      when PRESORT_INPUT_ORDER
        # do nothing
      else
        boxes = boxes.sort_by { |b| [b.width, b.length] }.reverse
      end 
      return boxes
    end
    
    def max_size_bins(bins)
      max_length = 0
      max_width = 0
      bins.each do |bin|
        max_length = bin.length if bin.length >= max_length
        max_width = bin.width if bin.width >= max_width
      end
      max_length -= 2*@trimsize
      max_width -= 2*@trimsize
      @panel_trimmed_length = max_length if max_length >= @panel_trimmed_length
      @panel_trimmed_width = max_width if max_width >= @panel_trimmed_width
    end
    
    # Split boxes into ones that will fit and ones that are too
    # large to fit into a standard panel or a scrap piece
    #
    def remove_oversized(boxes, bins)
      # do nothing if there is no base panel, scraps may be enough
      
      fitting_boxes = []
      oversized_boxes = []
      
      boxes.each do |box|
        if box.length <= @base_panel_trimmed_length && box.width <= @base_panel_trimmed_width
          fitting_boxes << box
        elsif !@has_grain && box.length <= @base_panel_trimmed_width && box.width <= @base_panel_trimmed_length
          fitting_boxes << box
        else
          enclosed = false
          bins.each do |bin|
            if box.length <= bin.length - 2*@trimsize && box.width <= bin.width - 2*@trimsize
              fitting_boxes << box
              enclosed = true
              break
            elsif !@has_grain && box.length <= bin.width - 2*@trimsize && box.width <= bin.length - 2*@trimsize
              enclosed = true
              fitting_boxes << box
              break
            end
          end
          oversized_boxes << box if !enclosed
        end
      end
      return fitting_boxes, oversized_boxes
    end    

    # Make superboxes
    # precondition: boxes will fit the trimmed base panel
    # postcondition: boxes are stacked and sorted according to option
    #
    def make_sboxes_lengthwise(boxes)
      sboxes = []
      boxes = sort_boxes(boxes, PRESORT_WIDTH_DECR)
      until boxes.empty?
        box = boxes.shift
        stacked = false
        sboxes.each do |sbox|
          if box.width == sbox.width && sbox.length + @saw_kerf + box.length <= @panel_trimmed_length
            sbox.stack_length(box)
            stacked = true
            break
          elsif !@has_grain && box.length == sbox.width && sbox.length + @saw_kerf + box.width <= @panel_trimmed_length
            sbox.stack_length(box.rotate)
            stacked = true
            break
          end
        end
        if !stacked
          if box.length >= box.width || @has_grain
            sbox = SuperBox.new(0, box.width, @saw_kerf)
            sbox.stack_length(box)
          else
            sbox = SuperBox.new(0, box.length, @saw_kerf)
            sbox.stack_length(box.rotate)
          end
          sboxes << sbox
        end
      end
      sboxes = sort_boxes(sboxes)
      return sboxes
    end
    
    def make_sboxes_widthwise(boxes)
      sboxes = []
      boxes = sort_boxes(boxes, PRESORT_LENGTH_DECR)
      until boxes.empty?
        box = boxes.shift
        stacked = false
        sboxes.each do |sbox|
          if box.length == sbox.length && sbox.width + @saw_kerf + box.width <= @panel_trimmed_width
            sbox.stack_width(box)
            stacked = true
            break
          elsif !@has_grain && box.width == sbox.length && sbox.width + @saw_kerf + box.length <= @panel_trimmed_width
            sbox.stack_width(box.rotate)
            stacked = true
            break
          end
        end
        if !stacked
          if box.length >= box.width || @has_grain
            sbox = SuperBox.new(0, box.width, @saw_kerf)
            sbox.stack_length(box)
          else
            sbox = SuperBox.new(0, box.length, @saw_kerf)
            sbox.stack_length(box.rotate)
          end

          sboxes << sbox
        end
      end
      sboxes = sort_boxes(sboxes)
      return sboxes
    end
    
    # Postprocess supergroups by extracting the original boxes from the
    # superboxes and adding the necessary cuts.
    #
    # This function will change the instance variables
    # @cuts and @boxes from each bin in bins
    #
    def explode_sboxes_lengthwise(bins)
      bins.each do |bin|
        new_boxes = []
        bin.boxes.each do |sbox|
          if sbox.is_a?(SuperBox)
            x = sbox.x
            y = sbox.y
            cut_counts = sbox.boxes.length() - 1
            sbox.boxes.each do |b|
              b.set_position(x, y)
              if sbox.is_rotated?
                y += b.width + @saw_kerf
                if cut_counts > 0
                  bin.add_cut(Cut.new(b.x, b.y + b.width, b.length, true, false))
                  cut_counts = cut_counts - 1
                end
              else
                x += b.length + @saw_kerf
                if cut_counts > 0
                  bin.add_cut(Cut.new(b.x + b.length, b.y, b.width, false, false))
                  cut_counts = cut_counts - 1
                end
              end
              new_boxes << b
            end
          else
            new_boxes << sbox
          end
        end
        bin.boxes = new_boxes
      end
    end
    
    def explode_sboxes_widthwise(bins)
      bins.each do |bin|
        new_boxes = []
        bin.boxes.each do |sbox|
          if sbox.is_a?(SuperBox)
            x = sbox.x
            y = sbox.y
            cut_counts = sbox.boxes.length() - 1
            sbox.boxes.each do |b|
              b.set_position(x, y)
              if sbox.is_rotated? 
                x += b.length + @saw_kerf
                if cut_counts > 0
                  bin.add_cut(Cut.new(b.x + b.length, b.y, b.width, false, false))
                  cut_counts = cut_counts - 1
                end
              else
                y += b.width + @saw_kerf
                if cut_counts > 0
                  bin.add_cut(Cut.new(b.x, b.y + b.width, b.length, true, false))
                  cut_counts = cut_counts - 1
                end
              end
              new_boxes << b
            end
          else
            new_boxes << sbox
          end
        end
        bin.boxes = new_boxes
      end
    end
    
  end
end
