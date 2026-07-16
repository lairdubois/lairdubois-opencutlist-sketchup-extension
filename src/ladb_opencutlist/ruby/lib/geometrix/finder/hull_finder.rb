module Ladb::OpenCutList::Geometrix

  module HullFinder

    # Finds the 3D convex hull of the given points (quickhull).
    #
    # @param [Array<Geom::Point3d>] points
    #
    # @return [Array<Array<Integer>>|nil] triangles as triples of indices in
    #   the given points array, wound outward ; nil when the input is
    #   degenerate (less than 4 points, or all coincident / collinear /
    #   coplanar).
    #
    def self.find_convex_hull_triangle_indices(points)
      return nil unless points.is_a?(Array)
      return nil if points.length < 4

      pts = points.map { |point| [ point.x.to_f, point.y.to_f, point.z.to_f ] }

      # Scale relative epsilon : points closer than this to a face plane are
      # considered on it (never "outside"), which guarantees termination on
      # coplanar clusters.
      mins = [ Float::INFINITY ] * 3
      maxs = [ -Float::INFINITY ] * 3
      pts.each do |p|
        3.times do |i|
          mins[i] = p[i] if p[i] < mins[i]
          maxs[i] = p[i] if p[i] > maxs[i]
        end
      end
      extent = 3.times.map { |i| maxs[i] - mins[i] }.max
      return nil if extent <= 0
      epsilon = extent * 1e-9

      fn_sub = lambda { |a, b| [ a[0] - b[0], a[1] - b[1], a[2] - b[2] ] }
      fn_cross = lambda { |a, b| [ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] ] }
      fn_dot = lambda { |a, b| a[0] * b[0] + a[1] * b[1] + a[2] * b[2] }

      # -- Initial tetrahedron

      # Extreme points on each axis, then the farthest pair among them
      extreme_indices = []
      3.times do |i|
        extreme_indices << (0...pts.length).min_by { |index| pts[index][i] }
        extreme_indices << (0...pts.length).max_by { |index| pts[index][i] }
      end
      extreme_indices.uniq!
      i0 = i1 = nil
      best = -1.0
      extreme_indices.each_with_index do |index_a, k|
        extreme_indices[(k + 1)..-1].each do |index_b|
          d = fn_dot.call(fn_sub.call(pts[index_a], pts[index_b]), fn_sub.call(pts[index_a], pts[index_b]))
          if d > best
            best = d
            i0 = index_a
            i1 = index_b
          end
        end
      end
      return nil if i0.nil? || Math.sqrt(best) <= epsilon

      # Farthest point from the line (i0, i1)
      line_dir = fn_sub.call(pts[i1], pts[i0])
      i2 = (0...pts.length).max_by { |index|
        v = fn_sub.call(pts[index], pts[i0])
        c = fn_cross.call(line_dir, v)
        fn_dot.call(c, c)
      }
      c = fn_cross.call(line_dir, fn_sub.call(pts[i2], pts[i0]))
      return nil if Math.sqrt(fn_dot.call(c, c)) / Math.sqrt(fn_dot.call(line_dir, line_dir)) <= epsilon

      # Farthest point from the plane (i0, i1, i2)
      plane_normal = fn_cross.call(fn_sub.call(pts[i1], pts[i0]), fn_sub.call(pts[i2], pts[i0]))
      plane_normal_length = Math.sqrt(fn_dot.call(plane_normal, plane_normal))
      i3 = (0...pts.length).max_by { |index| fn_dot.call(plane_normal, fn_sub.call(pts[index], pts[i0])).abs }
      return nil if fn_dot.call(plane_normal, fn_sub.call(pts[i3], pts[i0])).abs / plane_normal_length <= epsilon

      # Interior reference point : orients every face outward
      interior = 3.times.map { |i| (pts[i0][i] + pts[i1][i] + pts[i2][i] + pts[i3][i]) / 4.0 }

      # Face = { :indices => [ a, b, c ], :normal, :d, :outside => [ point indices ],
      #          :far_index, :far_distance, :alive }
      fn_new_face = lambda { |a, b, c|
        normal = fn_cross.call(fn_sub.call(pts[b], pts[a]), fn_sub.call(pts[c], pts[a]))
        length = Math.sqrt(fn_dot.call(normal, normal))
        normal = length > 0 ? normal.map { |v| v / length } : [ 0.0, 0.0, 0.0 ]
        if fn_dot.call(normal, interior) - fn_dot.call(normal, pts[a]) > 0
          b, c = c, b
          normal = normal.map { |v| -v }
        end
        {
          :indices => [ a, b, c ],
          :normal => normal,
          :d => -fn_dot.call(normal, pts[a]),
          :outside => [],
          :far_index => nil,
          :far_distance => epsilon,
          :alive => true
        }
      }
      fn_distance = lambda { |face, index| fn_dot.call(face[:normal], pts[index]) + face[:d] }
      fn_assign = lambda { |face, indices|
        indices.each do |index|
          distance = fn_distance.call(face, index)
          next if distance <= epsilon
          face[:outside] << index
          if distance > face[:far_distance]
            face[:far_distance] = distance
            face[:far_index] = index
          end
        end
      }

      faces = [
        fn_new_face.call(i0, i1, i2),
        fn_new_face.call(i0, i1, i3),
        fn_new_face.call(i0, i2, i3),
        fn_new_face.call(i1, i2, i3)
      ]
      remaining = (0...pts.length).to_a - [ i0, i1, i2, i3 ]
      faces.each do |face|
        fn_assign.call(face, remaining)
        remaining -= face[:outside]
      end

      # -- Iterations

      queue = faces.select { |face| !face[:far_index].nil? }
      until queue.empty?
        face = queue.pop
        next unless face[:alive] && !face[:far_index].nil?
        apex = face[:far_index]

        visible_faces = faces.select { |candidate| candidate[:alive] && fn_distance.call(candidate, apex) > epsilon }

        # Horizon : directed edges of the visible region whose reverse edge is
        # not in the region
        edge_set = {}
        visible_faces.each do |visible_face|
          a, b, c = visible_face[:indices]
          edge_set[[ a, b ]] = edge_set[[ b, c ]] = edge_set[[ c, a ]] = true
        end
        horizon_edges = edge_set.keys.reject { |a, b| edge_set.key?([ b, a ]) }

        orphans = []
        visible_faces.each do |visible_face|
          visible_face[:alive] = false
          orphans.concat(visible_face[:outside])
        end
        orphans.uniq!
        orphans.delete(apex)

        horizon_edges.each do |a, b|
          new_face = fn_new_face.call(a, b, apex)
          fn_assign.call(new_face, orphans)
          faces << new_face
          queue << new_face unless new_face[:far_index].nil?
        end
        faces.reject! { |candidate| !candidate[:alive] }
      end

      faces.map { |face| face[:indices] }
    end

  end

end
