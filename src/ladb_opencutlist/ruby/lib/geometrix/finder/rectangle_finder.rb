module Ladb::OpenCutList::Geometrix

  class RectangleFinder

    # Use first 5 points to find ellipse 2D definition or nil if it doesn't match an ellipse.
    # Input points are only considered as 2D points.
    #
    # @param [Array<Geom::Point3d>|nil] points
    #
    # @return [RectangleDef|nil]
    #
    def self.find_rectangle_def(points)
      return nil unless points.is_a?(Array)
      return nil unless points.length >= 4

      vectors = points[0..3].each_cons(2).map { |p1, p2| Geom::Vector3d.new(p2.x - p1.x, p2.y - p1.y) }

      vectors.sort_by! { |v| v.length }
      length_vector, width_vector = vectors[0], vectors[2]

      length = length_vector.length
      width = width_vector.length
      rotation = X_AXIS.angle_between(length_vector)

      RectangleDef.new(length, width, rotation)
    end

  end

  # -----

  class RectangleDef

    attr_reader :length, :width, :rotation

    def initialize(length, width, rotation)
      @length = length
      @width = width
      @rotation = rotation
    end

  end

end