module BinPacking2D

  require_relative 'packing2d'
  require_relative 'box'
  require_relative 'bin'
  require_relative 'cut'
  require_relative 'score'
  require_relative 'performance'
  require_relative 'packer'

  class PackEngine < Packing2D
  
    def initialize(bins, boxes, group)
      @bins = bins
      @boxes = boxes
      #@group = group
    end

    def run(options)
      if options[:base_sheet_length] > options[:trimming]  && options[:base_sheet_width] > options[:trimming]
        @bins.each_with_index { |bin, i| bin.index = i}
      else
        return nil, "trimming size larger than panel in at least one dimension."
      end

      packings = []

      (SCORE_BESTAREA_FIT..SCORE_WORSTLONGSIDE_FIT).to_a.each do |score|
        (SPLIT_SHORTERLEFTOVER_AXIS..SPLIT_LONGER_AXIS).to_a.each do |split|
          copy_boxes = []
          @boxes.each do |box|
            b = box.clone
            copy_boxes << b
          end

          copy_bins = []
          @bins.each do |bin|
            b = bin.clone
            copy_bins << b
          end
          p = BinPacking2D::Packer.new(options)
          p.pack(copy_bins, copy_boxes, score, split, options)
          packings << p
        end
      end

      packings = packings.sort_by { |p|
        [p.performance.nb_bins, 1/p.performance.largest_leftover.length, 1/p.performance.largest_leftover.area(),
         p.performance.v_cutlength]
      }

      return packings[0], "no error"
    end
    
  end
end
