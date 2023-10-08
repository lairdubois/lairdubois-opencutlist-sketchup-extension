module Ladb::OpenCutList::Geometrix

  require_relative 'ellipse_finder'

  class LoopFinder

    MIN_DELTA_ANGLE = 0.25 * Math::PI

    # @param [Array<Geom::Point3d>] points
    #
    # @return [LoopDef|nil]
    #
    def self.find_loop_def(points)
      return nil unless points.is_a?(Array)
      return nil unless points.length >= 3

      loop_def = LoopDef.new(points)

      twice_points = points + points

      index = 0
      while index < points.length

        if points.length > 5

          ellipse_def = EllipseFinder.find_ellipse_def(twice_points[index, 5])
          if ellipse_def

            ellipse_start_index = index
            ellipse_edge_count = 0

            a = EllipseFinder.ellipse_angle_at_point(ellipse_def, twice_points[index])
            va = ellipse_def.xaxis.transform(Geom::Transformation.rotation(ellipse_def.center, Z_AXIS, a))
            while true

              i = index + ellipse_edge_count + 1

              # Break if end reached
              break unless i <= points.length + 5

              p = twice_points[i]

              # Break if point not included in ellipse
              break unless EllipseFinder.ellipse_include_point?(ellipse_def, p)

              aa = EllipseFinder.ellipse_angle_at_point(ellipse_def, p)
              vaa = ellipse_def.xaxis.transform(Geom::Transformation.rotation(ellipse_def.center, Z_AXIS, aa))

              # Break if angle between previous point > MIN_DELTA_ANGLE
              break if va.angle_between(vaa) > MIN_DELTA_ANGLE

              a = aa
              va = vaa

              ellipse_edge_count += 1
            end

            if ellipse_edge_count >= 6

              # Append Arc portion
              loop_def.portions << ArcLoopPortionDef.new(loop_def, ellipse_start_index, ellipse_edge_count, ellipse_def)

              index = ellipse_start_index + ellipse_edge_count
              next
            end

          end

        end

        # Append Edge portion
        loop_def.portions << EdgeLoopPortionDef.new(loop_def, index)

        index += 1

      end

      # Check overlap
      last_portion = loop_def.portions.last
      if last_portion.is_a?(ArcLoopPortionDef)

        overlap = last_portion.end_index - points.length

        if last_portion == loop_def.portions.first

          # Only one arc : just subtract overlap
          last_portion.edge_count -= overlap

        else

          max_overlap_index = last_portion.end_index % points.length

          overlap_portions = loop_def.portions.select { |potion| potion.start_index < max_overlap_index }
          overlap_portions.each do |portion|

            if portion.is_a?(ArcLoopPortionDef) && portion.ellipse_def == last_portion.ellipse_def

              # Combine first ellipse to last
              last_portion.edge_count = last_portion.edge_count + portion.edge_count - overlap

            end

          end

          # Remove overlap portions
          loop_def.portions -= overlap_portions

        end

      end

      loop_def
    end

  end

  # -----

  class LoopDef

    attr_reader :points
    attr_accessor :portions

    def initialize(points)
      @points = points
      @portions = []
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
      @portions.length == 1 && @portions.first.is_a?(ArcLoopPortionDef)
    end

    def circle?
      ellipse? && @portions.first.ellipse_def.circular?
    end

  end

  class LoopPortionDef

    attr_accessor :loop_def, :start_index, :edge_count

    def initialize(loop_def, start_index, edge_count)
      @loop_def = loop_def
      @start_index = start_index
      @edge_count = edge_count
    end

    def end_index
      start_index + edge_count
    end

    def start_point
      @loop_def.point_at_index(start_index)
    end

    def end_point
      @loop_def.point_at_index(end_index)
    end

    def segments
      @loop_def.points_between_indices(@start_index, end_index).each_cons(2).to_a.flatten
    end

  end

  class EdgeLoopPortionDef < LoopPortionDef

    def initialize(loop_def, start_index)
      super(loop_def, start_index, 1)
    end

  end

  class ArcLoopPortionDef < LoopPortionDef

    attr_reader :ellipse_def

    def initialize(loop_def, start_index, edge_count, ellipse_def)
      super(loop_def, start_index, edge_count)
      @ellipse_def = ellipse_def
    end

    def normal
      @ellipse_def.xaxis.cross(@ellipse_def.yaxis).normalize
    end

    def start_angle
      EllipseFinder.ellipse_angle_at_point(@ellipse_def, start_point)
    end

    def end_angle
      EllipseFinder.ellipse_angle_at_point(@ellipse_def, end_point)
    end

  end

end
