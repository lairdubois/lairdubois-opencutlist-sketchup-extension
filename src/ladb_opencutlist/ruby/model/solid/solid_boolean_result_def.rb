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

    # Net boundary segments of the fragment, coplanar triangles merged : an
    # edge shared by two triangles lying on the same signed quantized plane
    # is interior (traversed once in each direction, it cancels out), the
    # surviving edges draw the face contours. An edge between two planes is
    # kept by each of them, as the two adjacent face contours overlap there.
    # Returns a flat Array<Geom::Point3d> of segment point pairs, ready for
    # Kuix::Segments#add_segments. Memoized.
    def boundary_segments
      @boundary_segments ||= begin

        tolerance = SolidMeshDef::TOLERANCE
        quantized = @vertices.each_slice(3).map { |coordinates| coordinates.map { |v| (v / tolerance).round } }

        edge_counts_by_plane = {}
        @face_indices.each_slice(3) do |a, b, c|
          qa, qb, qc = quantized[a], quantized[b], quantized[c]
          ux = qb[0] - qa[0] ; uy = qb[1] - qa[1] ; uz = qb[2] - qa[2]
          vx = qc[0] - qa[0] ; vy = qc[1] - qa[1] ; vz = qc[2] - qa[2]
          nx = uy * vz - uz * vy
          ny = uz * vx - ux * vz
          nz = ux * vy - uy * vx
          # A triangle thinner than the tolerance has no drawable contour of
          # its own : skipped (its neighbors' overlapping edges cover it)
          next if nx == 0 && ny == 0 && nz == 0
          gcd = nx.gcd(ny).gcd(nz)
          plane_key = [ nx / gcd, ny / gcd, nz / gcd, (nx * qa[0] + ny * qa[1] + nz * qa[2]) / gcd ]
          edge_counts = (edge_counts_by_plane[plane_key] ||= Hash.new(0))
          [ [ a, b ], [ b, c ], [ c, a ] ].each do |index_a, index_b|
            if edge_counts[[ index_b, index_a ]] > 0
              edge_counts[[ index_b, index_a ]] -= 1
            else
              edge_counts[[ index_a, index_b ]] += 1
            end
          end
        end

        pts = points
        segments = []
        edge_counts_by_plane.each_value do |edge_counts|
          edge_counts.each do |(index_a, index_b), count|
            count.times { segments << pts[index_a] << pts[index_b] }
          end
        end

        segments
      end
    end

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
