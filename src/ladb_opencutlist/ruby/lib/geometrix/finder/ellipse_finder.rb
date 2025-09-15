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

      begin

        # Create a matrix A and a vector B to solve the system of equations
        m_a = []
        v_b = []

        points = points[0, 5]

        # Compute a positive translation along X to translate points to be sure we don't check 0,0
        tx = points.map { |point| point.x < 0 ? -point.x : 0 }.min + 1

        # Fill
        # - matrix A with x^2, xy, y^2, x, y for 5 first points
        # - matrix B with -1
        points.each do |point|
          px = point.x + tx
          py = point.y
          m_a << [ px**2, px * py, py**2, px, py ]
          v_b << [ -1 ]
        end

        matrix_a = Matrix[*m_a]
        vector_b = Matrix[*v_b]

        # Check if matrix is inversible
        return nil if matrix_a.det.abs < Float::EPSILON  # TODO check if this "zero" value is not too low.

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
          (b * e - 2.0 * c * d) / discr - tx,
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

        if rmax.round(6) == rmin.round(6)

          # It's a circle
          angle = 0.0

        else

          qaqc = q * a - q * c
          qb = q * b

          if qaqc.abs < Float::EPSILON
            if qb.abs < Float::EPSILON
              angle = 0.0
            elsif qb > 0
              angle = QUARTER_PI
            else
              angle = THREE_QUARTER_PI
            end
          elsif qaqc > 0
            # if qb >= 0
              angle = 0.5 * Math.atan(b / (a - c))
            # else
            #   angle = 0.5 * Math.atan(b / (a - c)) + ONE_PI
            # end
          else
            angle = 0.5 * (Math.atan(b / (a - c)) + ONE_PI)
          end

        end

        # Axes

        v1 = points[0] - center
        v2 = points[1] - center
        normal = v1.cross(v2)

        xaxis = X_AXIS.transform(Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle))
        return nil unless xaxis.valid?
        xaxis.length = rmax

        yaxis = normal.cross(xaxis)
        return nil unless yaxis.valid?
        yaxis.length = rmin

      rescue ExceptionForMatrix::ErrNotRegular => e
        return nil
      rescue Exception => e
        puts "[#{File.basename(__FILE__)}:#{__LINE__}] : #{e.message}"
        return nil
      end

      EllipseDef.new(
        center,
        xaxis,
        yaxis,
        angle,
      )
    end

    # Checks if the given ellipse includes the given point
    #
    # @param [EllipseDef] ellipse_def
    # @param [Geom::Point3d] point
    # @param [Float] epsilon Minimal distance to ellipse edge
    #
    # @return [Boolean]
    #
    def self.ellipse_include_point?(ellipse_def, point, epsilon = 1e-3)
      # Check distance between point and ellipse edge
      ellipse_point_at_angle(ellipse_def, ellipse_angle_at_point(ellipse_def, point)).distance(point).to_f <= epsilon
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
    # @param [Float] angle polar angle in radians
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

    # Get ellipse oscultating circle center at angle
    #
    # @param [EllipseDef] ellipse_def
    # @param [Float] angle polar angle in radians
    #
    # @return [Geom::Point3d]
    #
    def self.ellipse_oscultating_circle_center_at_angle(ellipse_def, angle)

      sina = Math.sin(angle)
      cosa = Math.cos(angle)

      # Calculate the coordinates of the point on the ellipse
      x = ellipse_def.xradius * cosa
      y = ellipse_def.yradius * sina

      # Calculate the first derivative and second derivative of the ellipse
      dx = -ellipse_def.xradius * sina
      dy = ellipse_def.yradius * cosa
      ddx = -ellipse_def.xradius * cosa
      ddy = -ellipse_def.yradius * sina

      # Calculate the numerator and denominator of the center of curvature formula
      num = dx**2 + dy**2
      den = dx * ddy - dy * ddx

      Geom::Point3d.new(
        x - dy * num / den,
        y + dx * num / den
      )
        .transform(Geom::Transformation.translation(Geom::Vector3d.new(ellipse_def.center.to_a)))
        .transform(Geom::Transformation.rotation(ORIGIN, Z_AXIS, ellipse_def.angle))
    end

  end

  # -----

  class EllipseDef

    attr_reader :center, :xaxis, :yaxis, :angle

    def initialize(center, xaxis, yaxis, angle)
      @center = center
      @xaxis = xaxis
      @yaxis = yaxis
      @angle = angle
    end

    def circular?
      xradius == yradius
    end

    def xradius
      @xaxis.length
    end

    def yradius
      @yaxis.length
    end

  end

end

