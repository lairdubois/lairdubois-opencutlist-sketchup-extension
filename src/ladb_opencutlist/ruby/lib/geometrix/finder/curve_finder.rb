module Ladb::OpenCutList::Geometrix

  require_relative 'ellipse_finder'

  class CurveFinder

    MIN_ARC_DELTA_ANGLE = QUARTER_PI.round(2)
    MIN_ARC_POINT_COUNT = 5

    # This function try to split an array of ordered points to line or arc portions
    #
    # @param [Array<Geom::Point3d>] points (the last must not be equal to the first)
    # @param [Boolean] closed
    #
    # @return [CurveDef|nil]
    #
    def self.find_curve_def(points, closed = false)
      return nil unless points.is_a?(Array)

      # Closed curve cannot have equal “start” and “end” points. Removing the "end" point.
      points = points[0...-1] if closed && points.last == points.first

      return nil unless points.length > 1

      # Create output def
      curve_def = CurveDef.new(points, closed)

      # Glue 2 sets of points if closed
      twice_points = closed ? points + points : points

      index = 0
      max_index = points.length - 1
      max_search_index = closed ? points.length + MIN_ARC_POINT_COUNT : max_index
      arcs_detectable = points.length > MIN_ARC_POINT_COUNT
      while index <= max_index

        if arcs_detectable

          ellipse_def = EllipseFinder.find_ellipse_def(twice_points[index, MIN_ARC_POINT_COUNT])
          if ellipse_def

            ellipse_start_index = index
            ellipse_edge_count = 0

            va = ellipse_def.xaxis.transform(Geom::Transformation.rotation(ellipse_def.center, Z_AXIS, EllipseFinder.ellipse_angle_at_point(ellipse_def, twice_points[index])))
            while true

              i = index + ellipse_edge_count + 1

              # Break if end reached
              break unless i <= max_search_index

              p = twice_points[i]

              # Break if point not included in ellipse
              break unless EllipseFinder.ellipse_include_point?(ellipse_def, p)

              vaa = ellipse_def.xaxis.transform(Geom::Transformation.rotation(ellipse_def.center, Z_AXIS, EllipseFinder.ellipse_angle_at_point(ellipse_def, p)))

              # Break if angle between previous point > MIN_DELTA_ANGLE
              break if va.angle_between(vaa).round(2) > MIN_ARC_DELTA_ANGLE

              va = vaa

              ellipse_edge_count += 1

            end

            if ellipse_edge_count >= MIN_ARC_POINT_COUNT

              # Append Arc portion
              curve_def.portions << ArcCurvePortionDef.new(curve_def, ellipse_start_index, ellipse_edge_count, ellipse_def)

              index = ellipse_start_index + ellipse_edge_count

              next
            end

          end

        end

        break if index == max_index && !closed

        # Append Edge portion
        curve_def.portions << LineCurvePortionDef.new(curve_def, index)

        index += 1

      end

      if closed

        # Check overlap
        last_portion = curve_def.portions.last
        if last_portion.is_a?(ArcCurvePortionDef)

          overlap = last_portion.end_index - points.length

          if last_portion == curve_def.portions.first

            # Only one arc : just subtract overlap
            last_portion.edge_count -= overlap

          else

            max_overlap_index = last_portion.end_index % points.length
            overlap_portions = curve_def.portions.select { |portion| portion.start_index < max_overlap_index }
            last_overlap_portion = overlap_portions.last
            if last_portion == last_overlap_portion

              # Only one arc : just subtract overlap
              last_portion.edge_count = points.length

              # Keep portion
              overlap_portions.delete(last_overlap_portion)

            elsif last_overlap_portion.is_a?(ArcCurvePortionDef)

              # Check ellipses similarity by checking if last arc includes last overlap arc end point
              if EllipseFinder.ellipse_include_point?(last_portion.ellipse_def, last_overlap_portion.end_point)

                # Combine first ellipse to last
                last_portion.edge_count = last_portion.edge_count + overlap_portions.map(&:edge_count).inject(0, :+) - overlap  # .map(&:edge_count).inject(0, :+) == .sum { |portion| portion.edge_count } compatible with ruby < 2.4

              else

                last_overlap_portion.edge_count -= max_overlap_index - last_overlap_portion.start_index
                last_overlap_portion.start_index = max_overlap_index
                overlap_portions.delete(last_overlap_portion)

              end

            end

            # Remove overlap portions
            curve_def.portions -= overlap_portions

          end

        end

      end

      curve_def
    end

  end

  # -----

  class CurveDef

    attr_reader :points
    attr_accessor :portions

    def initialize(points, closed = false)
      @points = points
      @closed = closed
      @portions = []
    end

    def closed?
      @closed
    end

    def length
      @points.length
    end

    def point_at_index(index)
      @points[index % @points.length]
    end

    def points_between_indices(start_index, end_index)
      start_index = start_index % (@points.length * 2)
      end_index = end_index % (@points.length * 2)
      end_index = [ start_index + @points.length + 1, [ start_index + 1, end_index ].max ].min
      (@points + @points)[start_index..end_index]
    end

    def ellipse?
      closed? && @portions.length == 1 && @portions.first.is_a?(ArcCurvePortionDef)
    end

    def circle?
      closed? && ellipse? && @portions.first.ellipse_def.circular?
    end

  end

  class CurvePortionDef

    attr_accessor :curve_def, :start_index, :edge_count

    def initialize(curve_def, start_index, edge_count)
      @curve_def = curve_def
      @start_index = start_index
      @edge_count = edge_count
    end

    def end_index
      start_index + edge_count
    end

    def start_point
      @curve_def.point_at_index(start_index)
    end

    def end_point
      @curve_def.point_at_index(end_index)
    end

    def points
      @curve_def.points_between_indices(@start_index, end_index)
    end

    def segments
      points.each_cons(2).to_a.flatten(1)
    end

  end

  class LineCurvePortionDef < CurvePortionDef

    def initialize(curve_def, start_index)
      super(curve_def, start_index, 1)
    end

  end

  class ArcCurvePortionDef < CurvePortionDef

    attr_reader :ellipse_def

    def initialize(curve_def, start_index, edge_count, ellipse_def)
      super(curve_def, start_index, edge_count)
      @ellipse_def = ellipse_def
    end

    def normal
      @ellipse_def.xaxis.cross(@ellipse_def.yaxis).normalize
    end

    def ccw?
      Z_AXIS.samedirection?(normal)
    end

    def start_angle
      EllipseFinder.ellipse_angle_at_point(@ellipse_def, start_point)
    end

    def end_angle
      EllipseFinder.ellipse_angle_at_point(@ellipse_def, end_point)
    end

    def mid_angle

      as = start_angle
      ae = end_angle
      n = normal

      diff = ae - as
      if diff == 0
        diff = TWO_PI
      elsif diff < 0 && n.samedirection?(Z_AXIS) || diff > 0 && !n.samedirection?(Z_AXIS)
        diff = diff - TWO_PI
      end

      as + (diff / 2.0)
    end

    def mid_point
      EllipseFinder.ellipse_point_at_angle(@ellipse_def, mid_angle)
    end

  end

end
