module Ladb::OpenCutList

  require 'set'

  module Polylabel

    # Utility functions

    def self.orientation(p, q, r)
      val = (q[1] - p[1]) * (r[0] - q[0]) - (q[0] - p[0]) * (r[1] - q[1])
      val == 0 ? 0 : (val > 0 ? 1 : 2)
    end

    def self.on_segment(p, q, r)
      q[0] <= [p[0], r[0]].max && q[0] >= [p[0], r[0]].min && q[1] <= [p[1], r[1]].max && q[1] >= [p[1], r[1]].min
    end

    def self.line_inter(p1, q1, p2, q2)
      a1 = q1[1] - p1[1]
      b1 = p1[0] - q1[0]
      c1 = a1 * p1[0] + b1 * p1[1]

      a2 = q2[1] - p2[1]
      b2 = p2[0] - q2[0]
      c2 = a2 * p2[0] + b2 * p2[1]

      det = a1 * b2 - a2 * b1

      return false if det == 0

      inter = [(b2 * c1 - b1 * c2) / det, (a1 * c2 - a2 * c1) / det]
      inter
    end

    def self.segments_intersect(p1, q1, p2, q2)
      o1 = orientation(p1, q1, p2)
      o2 = orientation(p1, q1, q2)
      o3 = orientation(p2, q2, p1)
      o4 = orientation(p2, q2, q1)

      if o1 != o2 && o3 != o4
        return line_inter(p1, q1, p2, q2)
      end

      if o1 == 0 && on_segment(p1, p2, q1)
        return p2
      end

      if o2 == 0 && on_segment(p1, q2, q1)
        return q2
      end

      if o3 == 0 && on_segment(p2, p1, q2)
        return p1
      end

      if o4 == 0 && on_segment(p2, q1, q2)
        return q1
      end

      false
    end

    def self.signed_distance(label, far, inter)
      vector_label_far = [far[0] - label[0], far[1] - label[1]]
      vector_label_inter = [inter[0] - label[0], inter[1] - label[1]]
      length_label_far = Math.sqrt(vector_label_far[0]**2 + vector_label_far[1]**2)
      normalized_vector_label_far = vector_label_far.map { |x| x / length_label_far }
      vector_label_inter[0] * normalized_vector_label_far[0] + vector_label_inter[1] * normalized_vector_label_far[1]
    end

    def self.sort_and_reorder(array1, array2)
      (1...array1.length).each do |i|
        key_dist = array1[i]
        key_inter = array2[i]
        j = i - 1
        while j >= 0 && array1[j] > key_dist
          array1[j + 1] = array1[j]
          array2[j + 1] = array2[j]
          j -= 1
        end
        array1[j + 1] = key_dist
        array2[j + 1] = key_inter
      end
    end

    def self.distance(pt1, pt2)
      dx = pt2[0] - pt1[0]
      dy = pt2[1] - pt1[1]
      Math.sqrt(dx**2 + dy**2)
    end

    def self.dot(a, b)
      a[0] * b[0] + a[1] * b[1]
    end

    def self.subtract(a, b)
      [a[0] - b[0], a[1] - b[1]]
    end

    def self.copy(a)
      a.dup
    end

    def self.scale(a, t)
      [a[0] * t, a[1] * t]
    end

    def self.add(a, b)
      [a[0] + b[0], a[1] + b[1]]
    end

    def self.closest_pt_on_segment(a, b, o)
      ab = subtract(b, a)
      ao = subtract(o, a)

      ab2 = dot(ab, ab)
      if ab2 == 0.0
        return [a, distance(o, a)]
      end

      t = dot(ao, ab) / ab2
      t = 0.0 if t < 0.0
      t = 1.0 if t > 1.0

      projection = scale(ab, t)
      result = add(a, projection)
      [result, distance(o, result)]
    end

    def self.find_closest_pt_on_boundary(vers, exterior)
      min_dist = Float::INFINITY
      closest = nil

      vers.each_cons(2) do |v1, v2|
        test, dist = closest_pt_on_segment(v1, v2, exterior)
        if dist < min_dist
          min_dist = dist
          closest = test
        end
      end

      closest
    end

    def self.polygon_centroid(vers)
      a = 0.0
      sum_cx = 0.0
      sum_cy = 0.0

      vers.each_cons(2) do |v1, v2|
        cross_product = v1[0] * v2[1] - v2[0] * v1[1]
        a += cross_product
        sum_cx += (v1[0] + v2[0]) * cross_product
        sum_cy += (v1[1] + v2[1]) * cross_product
      end

      a /= 2.0
      [sum_cx / (6.0 * a), sum_cy / (6.0 * a)]
    end

    # Main program

    def self.find_label(vers)
      shift = [Float::INFINITY, Float::INFINITY]
      magnify = -Float::INFINITY

      # Copy first vertex at the end if not already looped
      vers << vers[0] unless vers[0] == vers[-1]

      # Shifting and scaling down everything to the unit square for convenience
      vers.each do |v|
        shift = [v[0], v[1]].zip(shift).map { |a, b| [a, b].min }
      end

      vers.map! { |v| v.zip(shift).map { |a, b| a - b } }

      vers.each do |v|
        magnify = [v[0], v[1], magnify].max
      end

      vers.map! { |v| v.map { |x| x / magnify } }

      # Computing exact centroid using Green's theorem
      centroid = polygon_centroid(vers)

      # Looking for closest point on the boundary
      closest = find_closest_pt_on_boundary(vers, centroid)
      dist = distance(centroid, closest)

      # Drawing the line (centroid, closest) and looking for intersections
      far1 = centroid.zip(closest).map { |c, cl| c + (cl - c) / dist * 10 }
      far2 = centroid.zip(closest).map { |c, cl| c - (cl - c) / dist * 10 }

      inters = []
      vers.each_cons(2) do |v1, v2|
        inter = segments_intersect(v1, v2, far1, far2)
        next unless inter

        inters << inter unless inters.any? { |i| distance(i, inter) < 1e-6 }
      end

      interdists = inters.map { |inter| signed_distance(centroid, far1, inter) }
      sort_and_reorder(interdists, inters)

      # Picking the largest inner segment and setting label position as its center
      max_length = -Float::INFINITY
      id = -1
      lengths = []
      (0...inters.length - 1).step(2) do |i|
        lengths[i] = distance(inters[i], inters[i + 1])
        if lengths[i] > max_length
          max_length = lengths[i]
          id = i
        end
      end

      label = scale(add(inters[id], inters[id + 1]), 0.5)

      # Exiting cleanly
      label = label.zip(shift).map { |l, s| l * magnify + s }
      vers.map! { |v| v.zip(shift).map { |vi, s| vi * magnify + s } }

      label
    end

  end

end

