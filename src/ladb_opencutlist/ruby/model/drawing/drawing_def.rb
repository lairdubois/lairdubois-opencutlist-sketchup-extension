module Ladb::OpenCutList

  class DrawingDef

    attr_reader :bounds, :face_manipulators, :surface_manipulators, :edge_manipulators
    attr_accessor :transformation, :input_face_manipulator, :input_edge_manipulator

    def initialize

      @transformation = Geom::Transformation.new

      @bounds = Geom::BoundingBox.new

      @face_manipulators = []
      @surface_manipulators = []
      @edge_manipulators = []

      @input_face_manipulator = nil
      @input_edge_manipulator = nil

    end

  end

end