module BinPacking2D

  require_relative 'packing2d'
  require_relative 'box'
  require_relative 'bin'
  require_relative 'cut'
  require_relative 'score'
  require_relative 'performance'
  require_relative 'packer'

  require_relative 'export_binding'
  require_relative 'export'
  require 'erb'

  class PackEngine < Packing2D
  
    def initialize(bins, boxes)
      @bins = bins
      @boxes = boxes
    end

    def run(options)
      if @bins.empty?
        @bins << BinPacking2D::Bin.new(options[:base_sheet_length], options[:base_sheet_width], 0, 0, 0)
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
        [p.performance.nb_bins, 1 / p.performance.largest_leftover.area(),
         p.performance.v_cutlength]
      }

      # just for debugging - start
      if !options[:stacking]
        puts "stacking: #{options[:stacking]}"
      else
        puts "stacking: #{options[:stacking]}, horizontally: #{options[:stacking_horizontally]}"
      end
      min_nb_bins = packings[0].performance.nb_bins
      packings.each do |p|
        if p.performance.nb_bins == min_nb_bins
          p.performance.print
        end
      end
      return BinPacking2D::Export.new(packings[0].original_bins).to_html(options)
    end
  end
end
