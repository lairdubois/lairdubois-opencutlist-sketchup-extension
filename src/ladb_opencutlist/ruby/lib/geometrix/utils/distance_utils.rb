module Ladb::OpenCutList::Geometrix

  module DistanceUtils

    # Signed distance from a point to the nearest boundary segment of all loops:
    # positive if the point is inside the shape (even-odd rule), negative otherwise.
    #
    # @param [Array<Array<Geom::Point3d>>] loops
    # @param [Float] x
    # @param [Float] y
    #
    # @return [Float]
    #
    def self.signed_distance_to_boundary(loops, x, y)
      inside = false
      min_dist_sq = Float::INFINITY

      loops.each do |loop_points|
        j = loop_points.length - 1
        loop_points.each_with_index do |a, i|
          b = loop_points[j]

          # Even-odd ray casting: toggles for each edge crossed by the +x ray.
          inside = !inside if (a.y > y) != (b.y > y) && (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x)

          dist_sq = distance_square_to_segment(x, y, a, b)
          min_dist_sq = dist_sq if dist_sq < min_dist_sq

          j = i
        end
      end

      (inside ? 1 : -1) * Math.sqrt(min_dist_sq)
    end

    # Squared distance from a point to a line segment.
    #
    # @param [Float] px
    # @param [Float] py
    # @param [Geom::Point3d] a the first endpoint of the segment
    # @param [Geom::Point3d] b the second endpoint of the segment
    #
    # @return [Float]
    #
    def self.distance_square_to_segment(px, py, a, b)
      x = a.x
      y = a.y
      dx = b.x - x
      dy = b.y - y

      if dx != 0 || dy != 0
        t = ((px - x) * dx + (py - y) * dy) / (dx * dx + dy * dy)
        if t > 1
          x = b.x
          y = b.y
        elsif t > 0
          x += dx * t
          y += dy * t
        end
      end

      dx = px - x
      dy = py - y
      dx * dx + dy * dy
    end

  end

end