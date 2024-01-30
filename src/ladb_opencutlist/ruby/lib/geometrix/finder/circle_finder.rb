module Ladb::OpenCutList::Geometrix

  class CircleFinder

    # Use first 3 points to find circle 2D definition or nil if it doesn't match a cirlce.
    #  Input points are only considered as 2D points.
    # ref = https://cral-perso.univ-lyon1.fr/labo/fc/Ateliers_archives/ateliers_2005-06/cercle_3pts.pdf
    #
    # @param [Array<Geom::Point3d>|nil] points
    #
    # @return [CircleDef|nil]
    #
    def self.find_circle_def_by_3_points(points)
      return nil unless points.is_a?(Array)
      return nil unless points.length >= 3

      p1 = points[0]
      p2 = points[1]
      p3 = points[2]

      # Points must not be aligned
      return nil if (p2 - p1).parallel?(p2 - p3)

      cx = -((p3.x**2 - p2.x**2 + p3.y**2 - p2.y**2) / (2 * (p3.y - p2.y)) - (p2.x**2 - p1.x**2 + p2.y**2 - p1.y**2) / (2 * (p2.y - p1.y))) / ((p2.x - p1.x) / (p2.y - p1.y) - (p3.x - p2.x) / (p3.y - p2.y))
      cy = -(p2.x - p1.x) / (p2.y - p1.y) * cx + (p2.x**2 - p1.x**2 + p2.y**2 - p1.y**2) / (2 * (p2.y - p1.y))
      center = Geom::Point3d.new(cx, cy, p2.z)

      radius = (p1 - center).length

      CircleDef.new(center, radius)
    end

    # @param [EllipseDef] ellipse_def
    # @param [Float] angle polar angle in radians
    #
    # @return [CircleDef|nil]
    #
    def self.find_oscultating_circle_def_by_ellipse_def_at_angle(ellipse_def, angle)
      return nil unless ellipse_def.is_a?(EllipseDef)

      p = EllipseFinder.ellipse_point_at_angle(ellipse_def, angle)
      center = EllipseFinder.ellipse_oscultating_circle_center_at_angle(ellipse_def, angle)

      radius = (p - center).length

      CircleDef.new(center, radius)
    end

    # @param [EllipseDef] ellipse_def
    # @param [Float] angle polar angle in radians
    #
    # @return [CircleDef|nil]
    #
    def self.find_oscultating_circle_def_by_ellipse_def_at_point(ellipse_def, point)
      return nil unless ellipse_def.is_a?(EllipseDef)

      angle = EllipseFinder.ellipse_angle_at_point(ellipse_def, point)

      self.find_oscultating_circle_def_by_ellipse_def_at_angle(ellipse_def, angle)
    end

    # Checks if the given ellipse includes the given point
    #
    # @param [CircleDef] circle_def
    # @param [Geom::Point3d] point
    # @param [Float] epsilon Minimal distance to ellipse edge
    #
    # @return [Boolean]
    #
    def self.circle_include_point?(circle_def, point, epsilon = 1e-4)
      # Check distance between point and circle edge
      circle_point_at_angle(circle_def, circle_angle_at_point(circle_def, point)).distance(point).to_f <= epsilon
    end

    # Get circle CCW angle at point
    #
    # @param [CircleDef] circle_def
    # @param [Geom::Point3d] point
    #
    # @return [Float] angle in radians
    #
    def self.circle_angle_at_point(circle_def, point)

      # Translation to (0,0)
      px = (point.x - circle_def.center.x)
      py = (point.y - circle_def.center.y)

      # Angle adapted to radius
      Math.atan2(py / circle_def.radius, px / circle_def.radius)

    end

    # Get circle point at angle
    #
    # @param [CircleDef] circle_def
    # @param [Float] angle polar angle in radians
    #
    # @return [Geom::Point3d]
    #
    def self.circle_point_at_angle(circle_def, angle)

      Geom::Point3d.new(
        circle_def.center.x + circle_def.radius * Math.cos(angle),
        circle_def.center.y + circle_def.radius * Math.sin(angle),
        circle_def.center.z
      )

    end

  end

  # -----

  class CircleDef

    attr_reader :center, :radius

    def initialize(center, radius)
      @center = center
      @radius = radius
    end

  end

end