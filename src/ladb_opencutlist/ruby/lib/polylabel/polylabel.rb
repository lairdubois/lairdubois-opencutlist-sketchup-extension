module Ladb::OpenCutList

  require 'matrix'

  module Polylabel

    class Poly

      attr_accessor :verqty, :vers

      def initialize
        @verqty = 0
        @vers = []
      end

    end

    def self.distance(pt1, pt2)
      Math.sqrt((pt1[0] - pt2[0])**2 + (pt1[1] - pt2[1])**2)
    end

    def self.dot(a, b)
      a[0]*b[0] + a[1]*b[1]
    end

    def self.subtract(a, b)
      [a[0] - b[0], a[1] - b[1]]
    end

    def self.add(a, b)
      [a[0] + b[0], a[1] + b[1]]
    end

    def self.scale(a, t)
      [a[0] * t, a[1] * t]
    end

    def self.closest_pt_on_segment(a, b, o)
      ab = subtract(b, a)
      ao = subtract(o, a)
      ab2 = dot(ab, ab)
      return [a, distance(o, a)] if ab2 == 0.0
      t = dot(ao, ab) / ab2
      t = [[t, 0.0].max, 1.0].min
      projection = scale(ab, t)
      result = add(a, projection)
      [result, distance(o, result)]
    end

    def self.find_closest_pt_on_boundary(vers, exterior)
      min_dist = Float::INFINITY
      closest = nil
      vers.each_cons(2) do |a, b|
        pt, dist = closest_pt_on_segment(a, b, exterior)
        if dist < min_dist
          min_dist = dist
          closest = pt
        end
      end
      closest
    end

    def self.orientation(p, q, r)
      val = (q[1] - p[1]) * (r[0] - q[0]) - (q[0] - p[0]) * (r[1] - q[1])
      return 0 if val == 0
      val > 0 ? 1 : 2
    end

    def self.on_segment(p, q, r)
      q[0].between?([p[0], r[0]].min, [p[0], r[0]].max) &&
        q[1].between?([p[1], r[1]].min, [p[1], r[1]].max)
    end

    def self.line_inter(p1, q1, p2, q2)
      a1 = q1[1] - p1[1]
      b1 = p1[0] - q1[0]
      c1 = a1 * p1[0] + b1 * p1[1]

      a2 = q2[1] - p2[1]
      b2 = p2[0] - q2[0]
      c2 = a2 * p2[0] + b2 * p2[1]

      det = a1 * b2 - a2 * b1
      return nil if det == 0

      x = (b2 * c1 - b1 * c2) / det
      y = (a1 * c2 - a2 * c1) / det
      [x, y]
    end

    def self.segments_intersect(p1, q1, p2, q2)
      o1 = orientation(p1, q1, p2)
      o2 = orientation(p1, q1, q2)
      o3 = orientation(p2, q2, p1)
      o4 = orientation(p2, q2, q1)

      if o1 != o2 && o3 != o4
        return line_inter(p1, q1, p2, q2)
      end

      [ [o1, p2], [o2, q2], [o3, p1], [o4, q1] ].each do |o, pt|
        return pt if o == 0 && on_segment(p1, pt, q1)
      end

      nil
    end

    def self.signed_distance(label, far, inter)
      v1 = subtract(far, label)
      v2 = subtract(inter, label)
      len = Math.sqrt(v1[0]**2 + v1[1]**2)
      v1n = [v1[0]/len, v1[1]/len]
      dot(v1n, v2)
    end

    def self.sort_and_reorder(interdists, inters)
      inters.zip(interdists).sort_by(&:last).map(&:first)
    end

    def self.polygon_centroid(vers)
      a = 0.0
      cx = 0.0
      cy = 0.0
      vers.each_cons(2) do |p1, p2|
        cross = p1[0]*p2[1] - p2[0]*p1[1]
        a += cross
        cx += (p1[0] + p2[0]) * cross
        cy += (p1[1] + p2[1]) * cross
      end
      a /= 2.0
      [cx / (6.0 * a), cy / (6.0 * a), a]
    end

    def self.find_label(polys)
      shift = [Float::INFINITY, Float::INFINITY]
      magnify = -Float::INFINITY

      polys.each do |poly|
        poly.vers.each do |v|
          shift[0] = [shift[0], v[0]].min
          shift[1] = [shift[1], v[1]].min
        end
      end

      polys.each do |poly|
        poly.vers.map! { |v| [v[0] - shift[0], v[1] - shift[1]] }
      end

      polys.each do |poly|
        poly.vers.each do |v|
          magnify = [magnify, v.max].max
        end
      end

      polys.each do |poly|
        poly.vers.map! { |v| [v[0] / magnify, v[1] / magnify] }
      end

      centroid = [0.0, 0.0]
      total_area = 0.0
      polys.each_with_index do |poly, i|
        cx, cy, area = polygon_centroid(poly.vers)
        area *= -1 if i > 0
        centroid[0] += area * cx
        centroid[1] += area * cy
        total_area += area
      end
      centroid = [centroid[0] / total_area, centroid[1] / total_area]

      closest = nil
      min_dist = Float::INFINITY
      polys.each do |poly|
        pt = find_closest_pt_on_boundary(poly.vers, centroid)
        d = distance(centroid, pt)
        if d < min_dist
          closest = pt
          min_dist = d
        end
      end

      far1 = [
        centroid[0] + (closest[0] - centroid[0]) / min_dist * 10,
        centroid[1] + (closest[1] - centroid[1]) / min_dist * 10
      ]
      far2 = [
        centroid[0] - (closest[0] - centroid[0]) / min_dist * 10,
        centroid[1] - (closest[1] - centroid[1]) / min_dist * 10
      ]

      inters = []
      polys.each do |poly|
        poly.vers.each_cons(2) do |a, b|
          inter = segments_intersect(a, b, far1, far2)
          inters << inter if inter && !inters.any? { |i| distance(i, inter) < 1e-6 }
        end
      end

      interdists = inters.map { |i| signed_distance(centroid, far1, i) }
      sorted_inters = inters.zip(interdists).sort_by(&:last).map(&:first)

      max_length = -Float::INFINITY
      label = nil
      (0...sorted_inters.size-1).step(2) do |i|
        l = distance(sorted_inters[i], sorted_inters[i+1])
        if l > max_length
          max_length = l
          label = scale(add(sorted_inters[i], sorted_inters[i+1]), 0.5)
        end
      end

      label = [label[0] * magnify + shift[0], label[1] * magnify + shift[1]]
      label
    end

  end

end

