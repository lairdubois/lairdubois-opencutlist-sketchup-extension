module BinPacking2D

  require_relative "packing2d"
  require_relative "box"
  require_relative "bin"
  require_relative "cut"
  require_relative "score"
  require_relative "performance"
  require_relative "packer"

  require_relative "export_binding"
  require_relative "export"
  require "erb"

  class PackEngine < Packing2D
    attr_accessor
    
    def initialize(bins, boxes)
      @bins = bins
      @boxes = boxes
    end
    
    def run(options)
    
      if @bins.empty?
        @bins << BinPacking2D::Bin.new(options[:base_sheet_length], options[:base_sheet_width], 0, 0, 0)
      end
      
      packings = []
      use_supergroups = true
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
          p = BinPacking2D::Packer.new(options[:rotatable], options[:kerf], options[:trimming], options[:debugging])
          p.pack(copy_bins, copy_boxes, score, split, options[:stacking], options[:stacking_horizontally])
          packings << p
        end
      end
      packings = packings.sort_by { |p| [p.performance.nb_bins, 1/p.performance.largest_leftover.area(), p.performance.v_cutlength ] }
      
      # just for debugging - start
      if !options[:stacking]
        puts "stacking: #{options[:stacking]}"
      else
        puts "stacking: #{options[:stacking]}, horizontally: #{options[:stacking_horizontally]}"
      end
      min_nb_bins = packings[0].performance.nb_bins
      cut_length_ref = 0
      packings.each do |p|
        if p.performance.nb_bins == min_nb_bins && p.performance.cutlength != cut_length_ref
          cut_length_ref = p.performance.cutlength
          p.performance.print
          #html = BinPacking2D::Export.new(p.original_bins).to_html(zoom: 0.4)
          #File.write("results/sheet" + p.score.to_s + p.split.to_s + ".html", html)
        end
      end  
      puts "here"
      # just for debugging - end
      return BinPacking2D::Export.new(packings[0].original_bins).to_html(zoom: 0.4)
    end
    
  end
end
