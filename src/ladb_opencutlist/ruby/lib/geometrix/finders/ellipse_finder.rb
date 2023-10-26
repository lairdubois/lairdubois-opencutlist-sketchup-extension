require 'matrix'

module Ladb::OpenCutList::Geometrix

  class EllipseFinder

    # Use first 5 points to find ellipse 2D definition or nil if it doesn't match an ellipse.
    # Input points are only considered as 2D points.
    #
    # @param [Array<Geom::Point3d>|nil] points
    #
    # @return [EllipseDef|nil]
    #
    def self.find_ellipse_def(points)
      return nil unless points.is_a?(Array)
      return nil unless points.length >= 5

      # Create a matrix A and a vector B to solve the system of equations
      m_a = []
      v_b = []

      # Fill
      # - matrix A with x^2, xy, y^2, x, y for 5 first points
      # - matrix B with -1
      points[0, 5].each do |point|
        m_a << [ point.x**2, point.x * point.y, point.y**2, point.x, point.y ]
        v_b << [ -1 ]
      end

      matrix_a = Matrix[*m_a]
      vector_b = Matrix[*v_b]

      # Check if matrix is inversible
      return nil if matrix_a.det.abs < Float::EPSILON  # TODO check if this "zero" value is not too low.

      # Solve the system of equations to find the coefficients of the ellipse
      begin
        sol = matrix_a.inverse * vector_b
      rescue Exception => e
        puts "EllipseFinder.find_ellipse_def : #{e.message}"
        return nil
      end

      # Extract the coefficients from the ellipse
      # ax^2 + bxy + cy^2 + dx + ey + f = 0
      a, b, c, d, e = sol.to_a.flatten
      f = 1.0

      # Compute the discriminant
      discr = 4.0 * a * c - b**2

      # Check if it's an ellipse
      return nil unless discr > 0

      # Center

      center = Geom::Point3d.new(
        (b * e - 2.0 * c * d) / discr,
        (b * d - 2.0 * a * e) / discr,
        points[0].z # Suppose that all points are in the same Z plane
      )

      # Radius
      # https://math.stackexchange.com/questions/616645/determining-the-major-minor-axes-of-an-ellipse-from-general-form

      q = 64.0 * (f * discr - a * e**2 + b * d * e - c * d**2) / discr**2
      s = 0.25 * Math.sqrt(q.abs * Math.sqrt(b**2 + (a - c)**2))

      rmax = 0.125 * Math.sqrt(2 * q.abs * Math.sqrt(b**2 + (a - c)**2) - 2 * q * (a + c))
      rmin = Math.sqrt(rmax**2 - s**2)

      # Angle

      qaqc = q * a - q * c
      qb = q * b

      if qaqc.abs < Float::EPSILON
        if qb.abs < Float::EPSILON
          angle = 0.0
        elsif qb > 0
          angle = 0.25 * Math::PI
        else
          angle = 0.75 * Math::PI
        end
      elsif qaqc > 0
        # if qb >= 0
          angle = 0.5 * Math.atan(b / (a - c))
        # else
        #   angle = 0.5 * Math.atan(b / (a - c)) + Math::PI
        # end
      else
        angle = 0.5 * (Math.atan(b / (a - c)) + Math::PI)
      end

      # Axes

      v1 = points[0] - center
      v2 = points[1] - center
      normal = v1.cross(v2)

      xaxis = X_AXIS.transform(Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle))
      xaxis.length = rmax

      yaxis = normal.cross(xaxis)
      begin
        yaxis.length = rmin
      rescue Exception => e
        puts "EllipseFinder.find_ellipse_def : #{e.message}"
      end

      EllipseDef.new(
        center,
        angle,
        xaxis,
        yaxis,
        a,
        b,
        c,
        d,
        e,
        f
      )
    end

    # Checks if the given ellipse includes the given point
    #
    # @param [EllipseDef] ellipse_def
    # @param [Geom::Point3d] point
    #
    # @return [Boolean]
    #
    def self.ellipse_include_point?(ellipse_def, point)
      # (x - cx)^2 / xradius^2 + (y - cy)^2 / yradius^2 = 1
      ((point.x - ellipse_def.center.x)**2 / ellipse_def.xradius**2 + (point.y - ellipse_def.center.y)**2 / ellipse_def.yradius**2 - 1).abs < 1e-8
    end

    # Get ellipse CCW angle at point
    #
    # @param [EllipseDef] ellipse_def
    # @param [Geom::Point3d] point
    #
    # @return [Float] angle in radians
    #
    def self.ellipse_angle_at_point(ellipse_def, point)

      # Translation to (0,0)
      px = (point.x - ellipse_def.center.x)
      py = (point.y - ellipse_def.center.y)

      # Rotation of -ellipse_def.angle
      tx = Math.cos(ellipse_def.angle) * px + Math.sin(ellipse_def.angle) * py
      ty = -Math.sin(ellipse_def.angle) * px + Math.cos(ellipse_def.angle) * py

      # Angle adapted to radius
      Math.atan2(ty / ellipse_def.yradius, tx / ellipse_def.xradius)

    end

    # Get ellipse point at angle
    #
    # @param [EllipseDef] ellipse_def
    # @param [Float] angle in radians
    # @param [Boolean] absolute
    #
    # @return [Geom::Point3d]
    #
    def self.ellipse_point_at_angle(ellipse_def, angle)

      Geom::Point3d.new(
        ellipse_def.center.x + ellipse_def.xradius * Math.cos(ellipse_def.angle) * Math.cos(angle) - ellipse_def.yradius * Math.sin(ellipse_def.angle) * Math.sin(angle),
        ellipse_def.center.y + ellipse_def.xradius * Math.sin(ellipse_def.angle) * Math.cos(angle) + ellipse_def.yradius * Math.cos(ellipse_def.angle) * Math.sin(angle),
        ellipse_def.center.z
      )

    end

  end

  # -----

  class EllipseDef

    attr_reader :center, :angle, :xaxis, :yaxis, :a, :b, :c, :d, :e, :f

    def initialize(center, angle, xaxis, yaxis, a, b, c, d, e, f)
      @center = center
      @angle = angle
      @xaxis = xaxis
      @yaxis = yaxis
      @a = a
      @b = b
      @c = c
      @d = d
      @e = e
      @f = f
    end

    def circular?
      (xradius - yradius).abs < 1e-12
    end

    def xradius
      @xaxis.length
    end

    def yradius
      @yaxis.length
    end

    def ==(other)
      @a - other.a +
      @b - other.b +
      @c - other.c +
      @d - other.d +
      @e - other.e +
      @f - other.f < 1e-10
    end

  end

end

