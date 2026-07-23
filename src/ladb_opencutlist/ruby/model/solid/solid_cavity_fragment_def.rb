module Ladb::OpenCutList

  require_relative 'solid_boolean_result_def'

  # Fragment produced by CommonFindCavitiesWorker : one cavity, carrying its
  # openness — the fraction of its surface area lying on the envelope caps
  # (face id 0) rather than on panel faces. 0.0 for a hermetically closed
  # cavity, the opening ratio for an open compartment (whose caps close the
  # openings flush with the panel edges).
  class SolidCavityFragmentDef < SolidFragmentDef

    attr_reader :openness

    def initialize(vertices, face_indices, face_ids, face_info_defs, src_indices: [], openness: 0.0)
      super(vertices, face_indices, face_ids, face_info_defs, src_indices: src_indices)
      @openness = openness
    end

    # -----

    def closed?
      @openness == 0.0
    end

    # Minimum share of the total opening area a plane must carry to count as
    # an opening of its own. Below this, it is noise from a non-flush rim
    # (e.g. sides rising slightly above an open top) : bounded by panel
    # THICKNESS in one dimension, its area is orders of magnitude below a
    # real opening's full 2D extent, so it stays comfortably under this
    # share in practice — while even a small real opening (e.g. the one open
    # side of a "C" shaped assembly, dwarfed by its two much bigger open
    # ends) clears it.
    OPENING_PLANE_MIN_AREA_SHARE = 0.05

    # Number of distinct planes carrying at least OPENING_PLANE_MIN_AREA_SHARE
    # of the envelope (face id 0) area : how many flat openings the cavity
    # has. A real compartment opens on few of them — 0 when hermetic, 1 for
    # an open front, 2 for a through tube, 3 for a "C" shaped assembly open on
    # one side — while the outside world and the concavity pockets of a
    # non-convex assembly face the envelope on many comparable planes. Planes
    # are told apart by the same signed quantized key as #boundary_segments.
    # Memoized.
    def opening_plane_count
      return @opening_plane_count if defined?(@opening_plane_count)

      area_by_plane = Hash.new(0.0)
      unless @face_ids.nil?

        tolerance = SolidMeshDef::TOLERANCE
        quantized = @vertices.each_slice(3).map { |coordinates| coordinates.map { |v| (v / tolerance).round } }
        @face_indices.each_slice(3)
                     .with_index do |(a, b, c), triangle_index|
          next unless @face_ids[triangle_index] == 0

          qa, qb, qc = quantized[a], quantized[b], quantized[c]
          ux = qb[0] - qa[0] ; uy = qb[1] - qa[1] ; uz = qb[2] - qa[2]
          vx = qc[0] - qa[0] ; vy = qc[1] - qa[1] ; vz = qc[2] - qa[2]
          nx = uy * vz - uz * vy
          ny = uz * vx - ux * vz
          nz = ux * vy - uy * vx
          next if nx == 0 && ny == 0 && nz == 0
          gcd = nx.gcd(ny).gcd(nz)
          plane_key = [ nx / gcd, ny / gcd, nz / gcd, (nx * qa[0] + ny * qa[1] + nz * qa[2]) / gcd ]
          # Quantized cross product magnitude = twice the triangle area, in
          # tolerance² units : exact enough for relative area comparison
          area_by_plane[plane_key] += Math.sqrt(nx * nx + ny * ny + nz * nz)

        end

      end

      total = area_by_plane.values.sum
      @opening_plane_count = total > 0 ? area_by_plane.values.count { |area| area >= total * OPENING_PLANE_MIN_AREA_SHARE } : 0
    end

  end

end
