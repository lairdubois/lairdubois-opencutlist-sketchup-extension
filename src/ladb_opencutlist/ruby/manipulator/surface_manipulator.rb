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
      @outer_loop_points = nil
      @z_max = nil
    end

    # -----

    def include?(face)
      @faces.include?(face)
    end

    # -----

    def outer_loop_points
      if @outer_loop_points.nil?
        @outer_loop_points = @faces.map { |face| face.outer_loop.vertices.map { |vertex| vertex.position.transform(@transformation) } }.flatten
        @outer_loop_points.reverse! if flipped?
      end
      @outer_loop_points
    end

    def z_max
      if @z_max.nil?
        @z_max = outer_loop_points.max { |p1, p2| p1.z <=> p2.z }.z
      end
      @z_max
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
