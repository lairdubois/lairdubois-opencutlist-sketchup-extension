module BinPacking2D
  class ExportBinding < Packing2D

    attr_reader :bins, :kerf

    def initialize(bins, zoom, kerf)
      @bins = bins
      @zoom = zoom
      @kerf = kerf
    end

    def zoom(value)
      cmm(value * @zoom).round
    end

    def get_binding
      binding
    end
  end
end
