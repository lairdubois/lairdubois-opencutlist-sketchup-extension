module Ladb::OpenCutList::BinPacking2D

  require_relative 'packing2d'
  require_relative 'processor'
  require_relative 'box'
  require_relative 'superbox'
  require_relative 'bin'
  require_relative 'containerbin'
  require_relative 'packer'
  require_relative 'cut'
  require_relative 'score'
  require_relative 'performance'
  require_relative 'options'

  class PackEngine < Packing2D
  
    def initialize(options)
      @options = options
      @stacking = options.stacking
      @trimsize = options.trimsize
      
      @bins = []
      @boxes = []
      @oversized_boxes = []
      @processor = Processor.new(@options)
    end

    def add_bin(length, width, type = BIN_TYPE_USER_DEFINED)
      @bins << ContainerBin.new(length, width, @trimsize, 0, type)
    end
    
    def add_box(length, width, data = nil)
      @boxes << Box.new(length, width, data)
    end

    # Preprocess parts, like sorting and stacking.
    #
    def preprocess
      @boxes = @processor.sort_boxes(@boxes)
      @processor.max_size_bins(@bins)

      @boxes, @oversized_boxes = @processor.remove_oversized(@boxes, @bins)
      if @stacking == STACKING_LENGTH
        @boxes = @processor.make_sboxes_lengthwise(@boxes)
      elsif @stacking == STACKING_WIDTH
        @boxes = @processor.make_sboxes_widthwise(@boxes)
      end  
    end
    
    #
    #
    def run

      # Check bin definitions
      if (@options.base_bin_length == 0 or @options.base_bin_width == 0) and @bins.empty?
        return nil, ERROR_NO_BIN
      end
      
      preprocess()

      packings = []

     (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a.each do |score|
        (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a.each do |split|

          unless @boxes.nil?
           copy_boxes = []
            @boxes.each do |box|
              copy_boxes << box.copy
            end
          end
          copy_bins = []
          unless @bins.nil?
            @bins.each do |bin|
              copy_bins <<  bin.copy
            end
          end

          p = Packer.new(@options, @processor)
          p.pack(copy_bins, copy_boxes, score, split)
          packings << p
        end
      end

      valid_packings = []
      error = ERROR_NONE
      
      packings.each do |p|
        if p.performance.nil?
          error = ERROR_BAD_ERROR
        elsif p.performance.nb_boxes_packed == 0
          error = ERROR_NO_PLACEMENT_POSSIBLE
        elsif p.performance.nb_boxes_packed < @boxes.length
          error = ERROR_PLACEMENT_INCOMPLETE
          p.unplaced_boxes += @oversized_boxes
          valid_packings << p
        else
          p.unplaced_boxes += @oversized_boxes
          valid_packings << p
        end
      end
      
      return nil, error unless valid_packings.length > 0
      
      packings = valid_packings.sort_by { |p|
        [ p.unplaced_boxes.length, p.performance.nb_bins, 
        1 / (p.performance.largest_leftover_length + 0.01),  
        1 / (p.performance.largest_leftover_width + 0.01), 
        1 / (p.performance.largest_leftover_area + 0.01), 
        p.performance.nb_leftovers ]
      } 

      p_longest = packings[0]

      packings = valid_packings.sort_by { |p|
        [ p.unplaced_boxes.length, p.performance.nb_bins, 
        1 / (p.performance.largest_leftover_area + 0.01),
        1 / (p.performance.largest_leftover_length + 0.01),  
        1 / (p.performance.largest_leftover_width + 0.01), 
        p.performance.nb_leftovers ]
      } 
      
      p_area = packings[0]

      puts "p longest #{p_longest.score} #{p_longest.split} nnbins: #{p_longest.performance.nb_bins} unbins: #{p_longest.unplaced_boxes.length()}"
      puts "p area    #{p_area.score} #{p_area.score} nbbins: #{p_area.performance.nb_bins} unbins: #{p_area.unplaced_boxes.length()}"
      
=begin
if p_longest.score == p_area.score && p_longest.split == p_area.split
        return [p_longest], ERROR_NONE
      elsif p_longest.unplaced_boxes.length() == p_area.unplaced_boxes.length()
        return [p_longest, p_area], ERROR_NONE
      elsif p_longest.unplaced_boxes.length() < p_area.unplaced_boxes.length()
        return [p_longest], ERROR_NONE
      else 
        return [p_area], ERROR_NONE
      end
=end
      return p_longest, error
    end
    
  end
end
