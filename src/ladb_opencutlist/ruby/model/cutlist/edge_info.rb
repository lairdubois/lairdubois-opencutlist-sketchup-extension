module Ladb::OpenCutList

  class EdgeInfo

    attr_accessor :edge, :transformation, :data

    def initialize(edge, transformation)
      @edge = edge
      @transformation = transformation
      @data = {}
    end

  end

end