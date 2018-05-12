module BinPacking2D
  class ExportBinding < Packing2D

    attr_reader :bins, :options

    def initialize(bins, options)
      @bins = bins
      @options = options
      @zoom = options[:zoom] || 1
    end

    def zoom(value)
      cmm(value * @zoom).to_i
    end

    def get_binding
      binding
    end
  end
end
