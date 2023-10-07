module Ladb::OpenCutList::Geometrix

  class EllipseFinder

    ZERO = 1e-10

    # Use first 5 points to find ellipse definition or nil if it doesn't match an ellipse.
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
      return nil if matrix_a.det.abs < ZERO

      # Solve the system of equations to find the coefficients of the ellipse
      sol = matrix_a.inverse * vector_b

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
        (b * d - 2.0 * a * e) / discr
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

      if qaqc.abs < ZERO
        if qb.abs < ZERO
          angle = 0.0
        elsif qb > 0
          angle = 0.25 * Math::PI
        else
          angle = 0.75 * Math::PI
        end
      elsif qaqc > 0
        if qb >= 0
          angle = 0.5 * Math.atan(b / (a - c))
        else
          angle = 0.5 * Math.atan(b / (a - c)) + Math::PI
        end
      else
        angle = 0.5 * (Math.atan(b / (a - c)) + Math::PI)
      end

      # Axes

      xaxis = X_AXIS.transform(Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle))
      xaxis.length = rmax

      yaxis = Z_AXIS.cross(xaxis)
      yaxis.length = rmin

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
      # ax^2 + bxy + cy^2 + dx + ey + f = 0
      (ellipse_def.a * point.x**2 + ellipse_def.b * point.x * point.y + ellipse_def.c * point.y**2 + ellipse_def.d * point.x + ellipse_def.e * point.y + ellipse_def.f).abs < 1e-8
    end

    # Get ellipse angle at point
    #
    # @param [EllipseDef] ellipse_def
    # @param [Geom::Point3d] point
    #
    # @return [Float] angle in radians
    #
    def self.ellipse_angle_at_point(ellipse_def, point)
      angle = ellipse_def.angle + Math.atan2(ellipse_def.center.x - point.x, ellipse_def.center.y - point.y) + Math::PI * 0.5
      angle = 2.0 * Math::PI + angle if angle < 0
      angle
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
      (rmax - rmin).abs < 1e-10
    end

    def rmax
      @xaxis.length
    end

    def rmin
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

