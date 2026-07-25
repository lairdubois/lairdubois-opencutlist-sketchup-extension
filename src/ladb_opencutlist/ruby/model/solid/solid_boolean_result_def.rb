module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'solid_mesh_def'

  # Result of a boolean operation : fragments on success, i18n error tuples otherwise.
  class SolidBooleanResultDef < DataContainer

    attr_reader :errors,            # Array of i18n tuples [ key, vars ] ; empty on success
                :fragment_defs,     # Array<SolidFragmentDef>
                :curve_info_defs,   # Array<SolidCurveInfoDef> collected from all operands
                :created_entities   # Entities holding the result, filled by the apply phase

    def initialize
      @errors = []
      @fragment_defs = []
      @curve_info_defs = []
      @created_entities = []
    end

    def success?
      @errors.empty?
    end

    # Fragments bounded by the given ORIGINAL source face, addressed by its
    # full occurrence path (Array of instances, model root first, face last -
    # as returned by a SketchUp pick). The path's prefix is compared to the
    # container_def's own occurrence path : only a root DrawingDef carries one
    # (drawing_def.rb#container_path), which is exactly the container_def of
    # any real panel face - the only nested containers are glued machining
    # ones (virtual), which never match. Two instances of the same component
    # share the same face persistent_id, so it alone cannot tell them apart.
    # A face separating two fragments (e.g. a divider between two cavities)
    # bounds both, hence an Array.
    def fragment_defs_for_face(face_path)
      return [] if face_path.nil? || face_path.empty?
      face = face_path.last
      return [] unless face.is_a?(Sketchup::Face)

      persistent_id = face.persistent_id
      container_path = face_path[0...-1]
      fragment_defs.select do |fragment_def|
        next false if fragment_def.face_ids.nil?
        fragment_def.face_ids.uniq.any? do |id|
          face_info_def = fragment_def.face_info_defs[id]
          face_info_def && face_info_def.face_id == persistent_id &&
            face_info_def.container_def.respond_to?(:container_path) && face_info_def.container_def.container_path == container_path
        end
      end
    end

    # Fragments that include the given point (WORLD coordinates), inside
    # their volume or within +tolerance+ of their surface - see
    # SolidFragmentDef#contains_point?.
    def fragment_defs_for_point(point, tolerance: SolidMeshDef::TOLERANCE)
      fragment_defs.select { |fragment_def| fragment_def.contains_point?(point, tolerance: tolerance) }
    end

  end

  # One resulting solid body, in WORLD coordinates.
  # Manifold may output several disjoint bodies (e.g. a subtraction that splits
  # the source in two) : one SolidFragmentDef each.
  class SolidFragmentDef < DataContainer

    attr_reader :vertices,        # Array<Float> flat [ x, y, z, ... ]
                :face_indices,    # Array<Integer> flat, 3 per triangle
                :face_ids,        # Array<Integer> 1 per triangle -> index in @face_info_defs, or nil if no provenance
                :face_info_defs,  # Array<SolidFaceInfoDef> shared registry of the operation
                :src_indices      # Array<Integer> indices (in the operation src list) of the sources this fragment comes from ; empty if unknown

    # Two triangles lie on the SAME plane when their unit normals differ by
    # less than this (dot >= 1 - PLANE_NORMAL_TOLERANCE, i.e. ~0.08°) and
    # their signed offsets by less than SolidMeshDef::TOLERANCE - see
    # #_each_triangle_plane. Coplanar triangles of a Manifold output agree far
    # closer than that (their normals match to the last float digits), so this
    # stays clear of merging planes that are genuinely distinct.
    PLANE_NORMAL_TOLERANCE = 1e-6

    # Bucketing quantum of the plane normal components : plane candidates are
    # indexed by their coarsely rounded normal so the matching above stays
    # local on a fragment carrying many distinct planes - see
    # #_triangle_plane_index.
    PLANE_BUCKET_QUANTUM = 0.01

    def initialize(vertices, face_indices, face_ids, face_info_defs, src_indices: [])
      @vertices = vertices
      @face_indices = face_indices
      @face_ids = face_ids.is_a?(Array) && face_ids.length == face_indices.length / 3 ? face_ids : nil
      @face_info_defs = face_info_defs
      @src_indices = src_indices
    end

    # -----

    def empty?
      @face_indices.nil? || @face_indices.empty?
    end

    def triangle_count
      @face_indices.length / 3
    end

    def vertex_count
      @vertices.length / 3
    end

    def points
      @points ||= @vertices.each_slice(3).map { |coords| Geom::Point3d.new(coords) }
    end

    # Enclosed volume in cubic inches, by the divergence theorem over the
    # triangles. Meaningful on a closed, consistently wound fragment (always
    # true of Manifold output).
    def volume
      @volume ||= @face_indices.each_slice(3).sum { |a, b, c|
        ax, ay, az = @vertices[a * 3], @vertices[a * 3 + 1], @vertices[a * 3 + 2]
        bx, by, bz = @vertices[b * 3], @vertices[b * 3 + 1], @vertices[b * 3 + 2]
        cx, cy, cz = @vertices[c * 3], @vertices[c * 3 + 1], @vertices[c * 3 + 2]
        (ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)) / 6.0
      }.abs
    end

    # Volume-weighted centroid (WORLD coordinates), by the divergence theorem
    # over the triangles : independent of the tessellation density, unlike the
    # vertex average. Same closedness requirement as #volume. nil when the
    # enclosed volume is degenerate.
    def centroid
      return @centroid if defined?(@centroid)
      det_sum = 0.0
      x_sum = y_sum = z_sum = 0.0
      @face_indices.each_slice(3) do |a, b, c|
        ax, ay, az = @vertices[a * 3], @vertices[a * 3 + 1], @vertices[a * 3 + 2]
        bx, by, bz = @vertices[b * 3], @vertices[b * 3 + 1], @vertices[b * 3 + 2]
        cx, cy, cz = @vertices[c * 3], @vertices[c * 3 + 1], @vertices[c * 3 + 2]
        det = ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)
        det_sum += det
        x_sum += det * (ax + bx + cx)
        y_sum += det * (ay + by + cy)
        z_sum += det * (az + bz + cz)
      end
      @centroid = det_sum == 0 ? nil : Geom::Point3d.new(x_sum / (4.0 * det_sum), y_sum / (4.0 * det_sum), z_sum / (4.0 * det_sum))
    end

    # True when the given point (WORLD coordinates) lies within +tolerance+
    # of the fragment's surface (touching) or strictly inside its volume.
    # Touch test : point-to-triangle distance (Ericson, "Real-Time Collision
    # Detection", closest point on triangle), the exact counterpart of the
    # tolerance a Manifold boolean itself snaps to (SolidMeshDef::TOLERANCE).
    # Inside test : generalized winding number (Jacobson et al.) - robust on
    # this closed, consistently wound mesh (see #volume) without needing a
    # ray direction and its degenerate grazing cases.
    def contains_point?(point, tolerance: SolidMeshDef::TOLERANCE)
      p = point.is_a?(Geom::Point3d) ? point.to_a : point
      tolerance_sq = tolerance * tolerance

      winding = 0.0
      @face_indices.each_slice(3) do |ia, ib, ic|
        a = [ @vertices[ia * 3], @vertices[ia * 3 + 1], @vertices[ia * 3 + 2] ]
        b = [ @vertices[ib * 3], @vertices[ib * 3 + 1], @vertices[ib * 3 + 2] ]
        c = [ @vertices[ic * 3], @vertices[ic * 3 + 1], @vertices[ic * 3 + 2] ]

        return true if _sq_dist_point_triangle(p, a, b, c) <= tolerance_sq

        winding += _triangle_solid_angle(p, a, b, c)
      end

      (winding / (4.0 * Math::PI)).abs > 0.5
    end

    # Net boundary segments of the fragment, coplanar triangles merged : an
    # edge shared by two triangles lying on the same plane (matched with
    # tolerance, see #_each_triangle_plane)
    # is interior (traversed once in each direction, it cancels out), the
    # surviving edges draw the face contours. An edge between two planes is
    # kept by each of them, as the two adjacent face contours overlap there,
    # so it appears TWICE (once per plane, endpoints in reverse order) : fine
    # for a solid wireframe, but see #unique_boundary_segments for a dashed
    # one. Returns a flat Array<Geom::Point3d> of segment point pairs, ready
    # for Kuix::Segments#add_segments. Memoized.
    def boundary_segments
      @boundary_segments ||= _flatten_edge_counts_by_plane(unique: false)
    end

    # Same net boundary as #boundary_segments, with each physical edge kept
    # only once regardless of how many planes it borders between : the
    # duplicate #boundary_segments keeps for an edge between two planes (same
    # segment, endpoints reversed) makes a dash pattern restart from each end,
    # which reads as a doubled or broken stipple. Returns a flat
    # Array<Geom::Point3d> of segment point pairs, ready for
    # Kuix::Segments#add_segments. Memoized.
    def unique_boundary_segments
      @unique_boundary_segments ||= _flatten_edge_counts_by_plane(unique: true)
    end

    private

    # Signed solid angle (steradians) subtended by triangle a-b-c as seen
    # from p, via Van Oosterom & Strackee's formula. Summed over a closed,
    # consistently wound mesh, this totals ±4π when p is inside, ~0 outside -
    # see #contains_point?.
    def _triangle_solid_angle(p, a, b, c)
      ax, ay, az = a[0] - p[0], a[1] - p[1], a[2] - p[2]
      bx, by, bz = b[0] - p[0], b[1] - p[1], b[2] - p[2]
      cx, cy, cz = c[0] - p[0], c[1] - p[1], c[2] - p[2]

      la = Math.sqrt(ax * ax + ay * ay + az * az)
      lb = Math.sqrt(bx * bx + by * by + bz * bz)
      lc = Math.sqrt(cx * cx + cy * cy + cz * cz)
      return 0.0 if la == 0 || lb == 0 || lc == 0 # p coincides with a vertex : covered by the touch test

      numerator = ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx) # a . (b x c)
      denominator = la * lb * lc + (ax * bx + ay * by + az * bz) * lc + (bx * cx + by * cy + bz * cz) * la + (cx * ax + cy * ay + cz * az) * lb
      2.0 * Math.atan2(numerator, denominator)
    end

    # Squared distance from p to its closest point on triangle a-b-c
    # (Ericson, "Real-Time Collision Detection", closest point on triangle by
    # Voronoi region of the barycentric coordinates).
    def _sq_dist_point_triangle(p, a, b, c)
      ab = [ b[0] - a[0], b[1] - a[1], b[2] - a[2] ]
      ac = [ c[0] - a[0], c[1] - a[1], c[2] - a[2] ]
      ap = [ p[0] - a[0], p[1] - a[1], p[2] - a[2] ]
      d1 = _dot3(ab, ap)
      d2 = _dot3(ac, ap)
      return _sq_dist3(p, a) if d1 <= 0 && d2 <= 0 # Vertex region a

      bp = [ p[0] - b[0], p[1] - b[1], p[2] - b[2] ]
      d3 = _dot3(ab, bp)
      d4 = _dot3(ac, bp)
      return _sq_dist3(p, b) if d3 >= 0 && d4 <= d3 # Vertex region b

      vc = d1 * d4 - d3 * d2
      if vc <= 0 && d1 >= 0 && d3 <= 0 # Edge region ab
        v = d1 / (d1 - d3)
        return _sq_dist3(p, [ a[0] + v * ab[0], a[1] + v * ab[1], a[2] + v * ab[2] ])
      end

      cp = [ p[0] - c[0], p[1] - c[1], p[2] - c[2] ]
      d5 = _dot3(ab, cp)
      d6 = _dot3(ac, cp)
      return _sq_dist3(p, c) if d6 >= 0 && d5 <= d6 # Vertex region c

      vb = d5 * d2 - d1 * d6
      if vb <= 0 && d2 >= 0 && d6 <= 0 # Edge region ac
        w = d2 / (d2 - d6)
        return _sq_dist3(p, [ a[0] + w * ac[0], a[1] + w * ac[1], a[2] + w * ac[2] ])
      end

      va = d3 * d6 - d5 * d4
      if va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0 # Edge region bc
        w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return _sq_dist3(p, [ b[0] + w * (c[0] - b[0]), b[1] + w * (c[1] - b[1]), b[2] + w * (c[2] - b[2]) ])
      end

      # Face region : orthogonal projection onto the triangle plane
      denom = 1.0 / (va + vb + vc)
      v = vb * denom
      w = vc * denom
      _sq_dist3(p, [ a[0] + ab[0] * v + ac[0] * w, a[1] + ab[1] * v + ac[1] * w, a[2] + ab[2] * v + ac[2] * w ])
    end

    def _dot3(u, v)
      u[0] * v[0] + u[1] * v[1] + u[2] * v[2]
    end

    def _sq_dist3(p, q)
      dx = p[0] - q[0] ; dy = p[1] - q[1] ; dz = p[2] - q[2]
      dx * dx + dy * dy + dz * dz
    end

    # Yields [ plane index, triangle index, a, b, c, doubled area ] for each
    # non degenerate triangle of the fragment, the plane index identifying
    # the plane it lies on among the fragment's planes, discovered as they
    # come. Two triangles share a plane index when their SIGNED plane matches
    # within PLANE_NORMAL_TOLERANCE / SolidMeshDef::TOLERANCE - signed, so
    # that two opposite coplanar faces (e.g. the two sides of a zero
    # thickness membrane) stay distinct planes, as their contours are
    # traversed in opposite directions.
    #
    # Matching within a tolerance, and not by an exact key : quantizing the
    # vertices to the mesh tolerance and keying on the resulting exact
    # integer normal only holds for a plane aligned with that grid. An
    # OBLIQUE plane - anything in a rotated assembly - sees its rounded
    # vertices leave the plane, every one of its triangles ends up on a plane
    # of its own, and whatever the grouping serves (edge cancellation,
    # per-plane area) breaks down : the tessellation shows through the
    # merged contours (#boundary_segments) and one flat opening counts as
    # many (SolidCavityFragmentDef#opening_plane_count).
    def _each_triangle_plane
      min_area2 = SolidMeshDef::TOLERANCE * SolidMeshDef::TOLERANCE

      planes = []                   # [ [ normal, d ], ... ], index = plane index
      plane_indices_by_bucket = {}  # coarse normal key -> Array of plane indices

      @face_indices.each_slice(3).with_index do |(a, b, c), triangle_index|
        ax, ay, az = @vertices[a * 3], @vertices[a * 3 + 1], @vertices[a * 3 + 2]
        bx, by, bz = @vertices[b * 3], @vertices[b * 3 + 1], @vertices[b * 3 + 2]
        cx, cy, cz = @vertices[c * 3], @vertices[c * 3 + 1], @vertices[c * 3 + 2]
        ux = bx - ax ; uy = by - ay ; uz = bz - az
        vx = cx - ax ; vy = cy - ay ; vz = cz - az
        nx = uy * vz - uz * vy
        ny = uz * vx - ux * vz
        nz = ux * vy - uy * vx
        area2 = Math.sqrt(nx * nx + ny * ny + nz * nz)
        # A triangle thinner than the tolerance has no plane of its own worth
        # trusting (its normal is pure numerical noise) : skipped
        next if area2 <= min_area2
        nx /= area2 ; ny /= area2 ; nz /= area2
        d = nx * ax + ny * ay + nz * az

        yield _triangle_plane_index(planes, plane_indices_by_bucket, nx, ny, nz, d), triangle_index, a, b, c, area2
      end
    end

    # Index of the plane matching the given unit normal and signed offset in
    # the given registry, appended to it (and indexed in its normal bucket)
    # on first sight. The 26 neighbor buckets are probed too : two matching
    # normals may well round to either side of a bucket boundary.
    def _triangle_plane_index(planes, plane_indices_by_bucket, nx, ny, nz, d)
      qx = (nx / PLANE_BUCKET_QUANTUM).round
      qy = (ny / PLANE_BUCKET_QUANTUM).round
      qz = (nz / PLANE_BUCKET_QUANTUM).round

      min_dot = 1.0 - PLANE_NORMAL_TOLERANCE
      tolerance = SolidMeshDef::TOLERANCE
      (-1..1).each do |ox|
        (-1..1).each do |oy|
          (-1..1).each do |oz|
            plane_indices = plane_indices_by_bucket[[ qx + ox, qy + oy, qz + oz ]]
            next if plane_indices.nil?
            plane_indices.each do |plane_index|
              normal, plane_d = planes[plane_index]
              next if normal[0] * nx + normal[1] * ny + normal[2] * nz < min_dot
              next if (plane_d - d).abs > tolerance
              return plane_index
            end
          end
        end
      end

      planes << [ [ nx, ny, nz ], d ]
      plane_index = planes.length - 1
      (plane_indices_by_bucket[[ qx, qy, qz ]] ||= []) << plane_index
      plane_index
    end

    # Net boundary edges of the fragment, grouped by plane : for each plane,
    # an edge traversed once in each direction by two of its triangles is
    # interior and cancels out, the surviving edges draw that plane's face
    # contour. Memoized.
    def _edge_counts_by_plane
      @edge_counts_by_plane ||= begin

        edge_counts_by_plane = {}
        _each_triangle_plane do |plane_index, _triangle_index, a, b, c, _area2|
          edge_counts = (edge_counts_by_plane[plane_index] ||= Hash.new(0))
          [ [ a, b ], [ b, c ], [ c, a ] ].each do |index_a, index_b|
            if edge_counts[[ index_b, index_a ]] > 0
              edge_counts[[ index_b, index_a ]] -= 1
            else
              edge_counts[[ index_a, index_b ]] += 1
            end
          end
        end

        edge_counts_by_plane
      end
    end

    # Turns #_edge_counts_by_plane into a flat Array<Geom::Point3d> of segment
    # point pairs. unique: true keeps a single segment per unordered vertex
    # pair, dropping the reversed duplicate an edge between two planes would
    # otherwise contribute from its second plane.
    def _flatten_edge_counts_by_plane(unique:)
      pts = points
      segments = []
      seen = unique ? {} : nil
      _edge_counts_by_plane.each_value do |edge_counts|
        edge_counts.each do |(index_a, index_b), count|
          next if count == 0
          if unique
            key = index_a < index_b ? [ index_a, index_b ] : [ index_b, index_a ]
            next if seen[key]
            seen[key] = true
            segments << pts[index_a] << pts[index_b]
          else
            count.times { segments << pts[index_a] << pts[index_b] }
          end
        end
      end
      segments
    end

    public

    # Yields [ SolidFaceInfoDef or nil, Array of triangles (Array<Geom::Point3d>) ],
    # one batch per original face. Triangles without provenance are batched under nil.
    def each_triangle_batch
      pts = points
      batches = {}
      @face_indices.each_slice(3).with_index do |indices, triangle_index|
        face_info_def = @face_ids.nil? ? nil : @face_info_defs[@face_ids[triangle_index]]
        (batches[face_info_def] ||= []) << indices.map { |index| pts[index] }
      end
      batches.each { |face_info_def, triangles| yield face_info_def, triangles }
    end

  end

end
