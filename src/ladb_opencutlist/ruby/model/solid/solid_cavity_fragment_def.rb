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
    # are told apart by the same tolerant matching as #boundary_segments
    # (SolidFragmentDef#_each_triangle_plane) : an exact key would count one
    # oblique opening as many planes and drop the cavity. Memoized.
    def opening_plane_count
      return @opening_plane_count if defined?(@opening_plane_count)

      area_by_plane = Hash.new(0.0)
      unless @face_ids.nil?

        _each_triangle_plane do |plane_index, triangle_index, _a, _b, _c, area2|
          next unless @face_ids[triangle_index] == 0
          # Doubled triangle area : the factor cancels out in the relative
          # area comparison below
          area_by_plane[plane_index] += area2
        end

      end

      total = area_by_plane.values.sum
      @opening_plane_count = total > 0 ? area_by_plane.values.count { |area| area >= total * OPENING_PLANE_MIN_AREA_SHARE } : 0
    end

    # Minimum share of the total WALL area a panel plane must carry to be
    # weighed as a wall of the cavity — same doctrine, and same value, as
    # OPENING_PLANE_MIN_AREA_SHARE : below this it is an incidental strip (a
    # panel's chant crossing the volume, a boolean sliver), and a pair of
    # those is no evidence of anything.
    WALL_PLANE_MIN_AREA_SHARE = 0.05

    # Maximum dot product between two wall normals for them to count as
    # FACING each other : antiparallel within about 45°, so a cavity between
    # two panels still qualifies when one of them is tilted (a lectern's
    # slanted top over its bottom).
    FACING_WALL_MAX_DOT = -0.7

    # Whether the cavity is WALLED ON TWO OPPOSING SIDES : whether some pair
    # of its panel planes (face id != 0), each carrying at least
    # WALL_PLANE_MIN_AREA_SHARE of the wall area, faces each other
    # (FACING_WALL_MAX_DOT — the plane normals point out of the cavity, so two
    # walls it lies BETWEEN point away from one another).
    #
    # This is what tells a compartment from the concavity POCKET a non-convex
    # assembly leaves between itself and its hull. A compartment is enclosed :
    # whatever else it opens onto, some panel is on one side of it and another
    # panel opposite — two shelves with the volume sandwiched between them
    # already qualify, and that is the thinnest enclosure the separator tool
    # is asked to work in. A pocket merely WRAPS a corner of the assembly :
    # its walls are the outer faces meeting at that corner, mutually
    # perpendicular, and everything else about it is hull. Neither #openness
    # nor #opening_plane_count separates the two — the L-shaped cavity of a
    # notched cabinet and the pocket its notch leaves outside score the same
    # on both (openness 0.52, and an opening count that follows how many
    # sides happen to be open, 4 for a pair of bare shelves as much as for a
    # pocket). Memoized.
    def walled_on_facing_planes?
      return @walled_on_facing_planes if defined?(@walled_on_facing_planes)

      area_by_plane = Hash.new(0.0)
      normal_by_plane = {}
      unless @face_ids.nil?

        _each_triangle_plane do |plane_index, triangle_index, _a, _b, _c, area2, nx, ny, nz|
          next if @face_ids[triangle_index] == 0  # Envelope cap, not a wall
          # Doubled triangle area : the factor cancels out in the relative
          # area comparison below
          area_by_plane[plane_index] += area2
          normal_by_plane[plane_index] ||= [ nx, ny, nz ]
        end

      end

      total = area_by_plane.values.sum
      normals = total > 0 ? area_by_plane.select { |_plane_index, area| area >= total * WALL_PLANE_MIN_AREA_SHARE }
                                        .keys.map { |plane_index| normal_by_plane[plane_index] } : []
      @walled_on_facing_planes = normals.combination(2).any? { |first, second|
        first[0] * second[0] + first[1] * second[1] + first[2] * second[2] <= FACING_WALL_MAX_DOT
      }
    end

  end

end
