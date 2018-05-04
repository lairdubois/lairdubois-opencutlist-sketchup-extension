module BinPacking1D

  require_relative "packing1d"
  require_relative "packer"
  require_relative "box"
  require_relative "bin"
  require_relative "score"
  require_relative "cut"

  class PackEngine < Packing1D
    attr_accessor
    
    def initialize(bins, boxes)
      @bins = bins
      @boxes = boxes
    end
    
    def run(options)
    
      if @bins.empty?
        @bins << BinPacking1D::Bin.new(options[:base_sheet_length], 0, 0)
      end
      p = BinPacking1D::Packer.new(options[:kerf], options[:trimming])
      p.pack(@bins, @boxes)
      p.print_result
    end
    
  end
end
