module Ladb::OpenCutList::BinPacking2D

  require_relative 'packing2d'
  require_relative 'box'
  require_relative 'bin'
  require_relative 'cut'
  require_relative 'score'
  require_relative 'performance'
  require_relative 'packer'
  require_relative 'options'

  class PackEngine < Packing2D
  
    def initialize(options)
      @options = options
      @bins = []
      @boxes = []
    end

    def add_bin(length, width, type = BIN_TYPE_USER_DEFINED)
      @bins << Bin.new(length, width, 0, 0, 0, type)
    end
    
    def add_box(length, width, data = nil)
      @boxes << Box.new(length, width, data)
    end

    def run

      # Check bins definitions
      if (@options.base_bin_length == 0 or @options.base_bin_width == 0) and @bins.empty?
        return nil, ERROR_NO_BIN
      end
      
      # Compute index on each bin
      @bins.each_with_index { |bin, i| bin.index = i } unless @bins.nil?

      packings = []

      (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a.each do |score|
        (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a.each do |split|

          copy_boxes = []
          unless @boxes.nil?
            @boxes.each do |box|
              b = box.clone
              copy_boxes << b
            end
          end

          copy_bins = []
          unless @bins.nil?
            @bins.each do |bin|
              b = bin.clone
              copy_bins << b
            end
          end

          p = Packer.new(@options)
          p.pack(copy_bins, copy_boxes, score, split, @options)
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
        else
          valid_packings << p          
        end
      end
      
      return nil, error unless valid_packings.length > 0

      packings = valid_packings.sort_by { |p|
        [ p.unplaced_boxes.length, p.performance.nb_bins, 1 / (p.performance.largest_leftover_length + 0.01), 1 / (p.performance.largest_leftover_width + 0.01), p.performance.nb_leftovers ]
      }        
        
      return packings[0], ERROR_NONE
    end
    
  end
end
