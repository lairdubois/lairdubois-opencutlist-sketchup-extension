module BinPacking2D

  require_relative 'packing2d'
  require_relative 'box'
  require_relative 'bin'
  require_relative 'cut'
  require_relative 'score'
  require_relative 'performance'
  require_relative 'packer'
  
  class PackEngine < Packing2D
  
    def initialize(bins, boxes)
      @bins = bins
      @boxes = boxes
    end

    def check_basic_preconditions (options)
    
      if !options.key?(:base_sheet_length) || options[:base_sheet_length] == 0
        return NO_BASE_PANEL
      elsif options[:base_sheet_length] < 2*options[:trimming]
        return TRIMMING_TOO_LARGE
      end
      if !options.key?(:base_sheet_width) || options[:base_sheet_width] == 0
        return NO_BASE_PANEL
      elsif options[:base_sheet_width] < 2*options[:trimming]
        return TRIMMING_TOO_LARGE
      end
      return NO_ERROR
    end
    
    def run(options)
    
      err = check_basic_preconditions(options)
      if err != NO_ERROR
        return nil, err     
      end
      
      # index the bins in the order they were put added here
      # the base panel may or may not be index = 0
      if !@bins.nil?
        @bins.each_with_index { |bin, i| bin.index = i}
      end

      packings = []

      (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a.each do |score|
        (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a.each do |split|
          copy_boxes = []
          if !@boxes.nil? 
            @boxes.each do |box|
              b = box.clone
              copy_boxes << b
            end
          end

          copy_bins = []
          if !@bins.nil?
            @bins.each do |bin|
              b = bin.clone
              copy_bins << b
            end
          end
          p = BinPacking2D::Packer.new(options)
          p.pack(copy_bins, copy_boxes, score, split, options)
          packings << p
        end
      end

      if packings.empty?
        return nil, GENERAL_ERROR
      else
        packings.each do |p|
          if p.performance.nil?
            puts "no performance"
          end
        end
        packings = packings.sort_by { |p|
          [p.performance.nb_bins, 1/p.performance.largest_leftover.length, 1/p.performance.largest_leftover.area(),
           p.performance.v_cutlength]
        }
        return packings[0], NO_ERROR
      end
    end
    
  end
end
