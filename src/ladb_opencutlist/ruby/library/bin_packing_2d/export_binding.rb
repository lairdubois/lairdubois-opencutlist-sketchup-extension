module BinPacking2D
  class ExportBinding < Packing2D

    attr_reader :bins, :options, :unplaced_boxes, :group

    def initialize(bins, unplaced_boxes, group, options)
      @bins = bins
      @unplaced_boxes = unplaced_boxes
      @options = options
      @group = group
      @zoom = options[:zoom] || 1
    end

    def zoom(value)
      cmm(value * @zoom)
    end
    
    def dim(value)
      str = cu(value)
      str.sub(/\"/, '\\"')
    end

    def get_binding
      binding
    end
  end
end
