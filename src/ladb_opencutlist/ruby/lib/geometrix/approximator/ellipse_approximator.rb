module Ladb::OpenCutList::Geometrix

  require_relative '../finder/ellipse_finder'
  require_relative '../finder/circle_finder'

  class EllipseApproximator

    # This function try to approximate an 'EllipseDef' to a list of circular arcs.
    # Result is CCW.
    #
    # @param [EllipseDef] ellipse_def
    # @param [Float] from_angle
    # @param [Float] to_angle
    # @param [Float|nil] epsilon
    #
    # @return [ApproximatedEllipseDef|nil]
    #
    def self.approximate_ellipse_def(ellipse_def, from_angle = 0, to_angle = TWO_PI, epsilon = 1e-3)
      return nil unless ellipse_def.is_a?(EllipseDef)
      return nil if from_angle == to_angle

      angle_precision = 12  # Force angle precision. Better for comparisons.

      # 0 - Sanitize angles

      safe_from_angle = (from_angle % TWO_PI)
      safe_to_angle = to_angle < 0 ? to_angle % TWO_PI : to_angle % FOUR_PI
      safe_to_angle += TWO_PI if safe_to_angle <= safe_from_angle # Force 'to_angle' to be greater then 'from_angle'

      safe_from_angle = safe_from_angle.round(angle_precision)
      safe_to_angle = safe_to_angle.round(angle_precision)

      # 1 - Create a set of sample points

      sample_count = 90
      sample_angle = HALF_PI / sample_count

      sample_points = []
      (0..sample_count).each do |i|
        sample_point = EllipseFinder.ellipse_point_at_angle(ellipse_def, HALF_PI - sample_angle * i)
        sample_points << sample_point
      end

      # 2 - Compute 0 to PI/4 quarter portions

      quarter_portions = []
      end_angle = HALF_PI
      max_index = sample_points.length - 1
      i = 0
      while i <= max_index

        circle_def = CircleFinder.find_circle_def_by_3_points(sample_points[i, 3])
        if circle_def.is_a?(CircleDef)

          i = i + 2

          # Try same circle with next points
          while i < max_index && CircleFinder.circle_include_point?(circle_def, sample_points[i + 1], epsilon)
            i = i + 1
          end

        else

          # Three points strategy failed, compute oscultating circle
          circle_def = CircleFinder.find_oscultating_circle_def_by_ellipse_def_at_point(ellipse_def, sample_points[i])

        end

        # Create the portion
        start_angle = EllipseFinder.ellipse_angle_at_point(ellipse_def, sample_points[i])
        quarter_portions.unshift(ApproximateEllipsePortionDef.new(ellipse_def, start_angle, end_angle, circle_def))

        end_angle = start_angle

        i = i + 1

      end

      # 3 - Transform quarter portions to cover 2 or 4 PI

      toi = Geom::Transformation.rotation(ORIGIN, Z_AXIS, -ellipse_def.angle) * Geom::Transformation.translation(Geom::Vector3d.new(ellipse_def.center.to_a).reverse)
      to = toi.inverse

      portions = []
      portions += quarter_portions.each { |portion|
        portion.start_angle = portion.start_angle.round(angle_precision)
        portion.end_angle = portion.end_angle.round(angle_precision)
      }
      if safe_from_angle > HALF_PI || safe_to_angle > HALF_PI
        t = to * Geom::Transformation.scaling(-1, 1, 1) * toi
        portions += quarter_portions.reverse.map { |portion|
          ApproximateEllipsePortionDef.new(ellipse_def, (ONE_PI - portion.end_angle).round(angle_precision), (ONE_PI - portion.start_angle).round(angle_precision), CircleDef.new(portion.circle_def.center.transform(t), portion.circle_def.radius))
        }
        if safe_from_angle > ONE_PI || safe_to_angle > ONE_PI
          t = Geom::Transformation.rotation(ellipse_def.center, Z_AXIS, ONE_PI)
          portions += quarter_portions.map { |portion|
            ApproximateEllipsePortionDef.new(ellipse_def, (ONE_PI + portion.start_angle).round(angle_precision), (ONE_PI + portion.end_angle).round(angle_precision), CircleDef.new(portion.circle_def.center.transform(t), portion.circle_def.radius))
          }
          if safe_from_angle > THREE_QUARTER_PI || safe_to_angle > THREE_QUARTER_PI
            t = to * Geom::Transformation.scaling(1, -1, 1) * toi
            portions += quarter_portions.reverse.map { |portion|
              ApproximateEllipsePortionDef.new(ellipse_def, (TWO_PI - portion.end_angle).round(angle_precision), (TWO_PI - portion.start_angle).round(angle_precision), CircleDef.new(portion.circle_def.center.transform(t), portion.circle_def.radius))
            }
            if safe_to_angle > TWO_PI
              portions = portions + portions.map { |portion|
                ApproximateEllipsePortionDef.new(ellipse_def, (portion.start_angle + TWO_PI).round(angle_precision), (portion.end_angle + TWO_PI).round(angle_precision), portion.circle_def)
              }
            end
          end
        end
      end

      # 4 - Extract portions covered from 'from_angle' to 'to_angle'

      from_index = portions.find_index { |portion| portion.start_angle <= safe_from_angle && safe_from_angle < portion.end_angle }
      to_index = portions.find_index { |portion| portion.start_angle < safe_to_angle && safe_to_angle <= portion.end_angle }

      # 5 - Create the ouput object and populate it

      approximated_ellipse_def = ApproximatedEllipseDef.new(ellipse_def)

      approximated_ellipse_def.portions.concat(portions[from_index..to_index])
      start_portion = approximated_ellipse_def.portions.first
      end_portion = approximated_ellipse_def.portions.last
      start_portion.start_angle = safe_from_angle
      end_portion.end_angle = safe_to_angle

      approximated_ellipse_def
    end

  end

  # -----

  class ApproximatedEllipseDef

    attr_reader :ellipse_def, :portions

    def initialize(ellipse_def)
      @ellipse_def = ellipse_def
      @portions = []
    end

  end

  class ApproximateEllipsePortionDef

    attr_accessor :start_angle, :end_angle, :circle_def

    def initialize(ellipse_def, start_angle, end_angle, circle_def)
      @ellipse_def = ellipse_def
      @start_angle = start_angle
      @end_angle = end_angle
      @circle_def = circle_def
    end

    def start_point
      EllipseFinder.ellipse_point_at_angle(@ellipse_def, @start_angle)
    end

    def end_point
      EllipseFinder.ellipse_point_at_angle(@ellipse_def, @end_angle)
    end

  end

end