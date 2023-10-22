module Ladb::OpenCutList

  class SurfaceManipulator < TransformationManipulator

    attr_reader :faces

    def initialize(transformation = Geom::Transformation.new)
      super(transformation)
      @faces = []
    end

    # -----

    def reset_cache
      super
    end

    # -----

    def include?(face)
      @faces.include?(face)
    end

    # -----

    def z_max
      @faces.map { |face| face.outer_loop.vertices.map { |vertex| vertex.position.transform(@transformation).z }.max }.max
    end

    # -----

    def to_s
      [
        "SURFACE",
        "- #{@faces.count} faces",
      ].join("\n")
    end

  end

end
