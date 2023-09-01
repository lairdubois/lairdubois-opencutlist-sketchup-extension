module Ladb::OpenCutList

  class DrawingDef

    attr_reader :bounds, :face_infos, :edge_infos
    attr_accessor :transformation, :active_face_info, :active_edge_info

    def initialize

      @bounds = Geom::BoundingBox.new
      @face_infos = []
      @edge_infos = []

      @transformation = Geom::Transformation.new

      @active_face_info = nil
      @active_edge_info = nil

    end

  end

end