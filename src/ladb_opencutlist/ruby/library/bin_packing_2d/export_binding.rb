module BinPacking2D
  class ExportBinding < Packing2D
    attr_reader :bins

    def initialize(bins, zoom)
      @bins = bins
      @zoom = zoom
    end

    def zoom(value)
      cmm(value * @zoom).round
    end

    def get_binding
      binding
    end
  end
end
