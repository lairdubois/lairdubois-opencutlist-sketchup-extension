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

      total = area_by_plane.values.inject(0.0) { |sum, area| sum + area }
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

    # Minimum dot an escape direction must keep against EVERY wall to count
    # as one (see #_walls_leave_no_escape?) : the wall normals are unit
    # vectors, so this is the sine of the angle by which the direction clears
    # the walls, about 0.06°. Anything below is a direction that merely
    # grazes them — the tube axis of a prismatic cavity, which must NOT read
    # as a way out.
    ESCAPE_DIRECTION_MIN_DOT = 1.0e-3

    # Whether the cavity is ENCLOSED by its panel walls (face id != 0), each
    # carrying at least WALL_PLANE_MIN_AREA_SHARE of the wall area.
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
    # pocket).
    #
    # Two pieces of evidence, either of which is enough :
    #
    # - a FACING WALL PAIR (#_facing_wall_pair?), the historical test : some
    #   pair of walls the cavity lies between ;
    # - NO ESCAPE DIRECTION (#_walls_leave_no_escape?), its generalization to
    #   walls that enclose without any of them being opposite — a TRIANGULAR
    #   section (a tent shaped caisson : a bottom and two sides meeting at
    #   the apex) is walled all around yet has no facing pair at all, its
    #   widest angle being 133° where the pair test asks for 135°. No
    #   threshold on the pair test can fix that family : the more acute the
    #   apex, the further its walls are from facing each other.
    #
    # Memoized.
    def enclosed_by_walls?
      return @enclosed_by_walls if defined?(@enclosed_by_walls)

      normals = _wall_normals
      @enclosed_by_walls = _facing_wall_pair?(normals) || _walls_leave_no_escape?(normals)
    end

    private

    # Outward unit normals of the cavity's walls — its panel planes (face id
    # != 0) carrying at least WALL_PLANE_MIN_AREA_SHARE of the wall area.
    # Being area filtered, there are at most 20 of them.
    def _wall_normals
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

      total = area_by_plane.values.inject(0.0) { |sum, area| sum + area }
      return [] unless total > 0
      area_by_plane.select { |_plane_index, area| area >= total * WALL_PLANE_MIN_AREA_SHARE }
                   .keys.map { |plane_index| normal_by_plane[plane_index] }
    end

    # Whether some pair of walls FACES each other (FACING_WALL_MAX_DOT — the
    # normals point out of the cavity, so two walls it lies BETWEEN point away
    # from one another).
    def _facing_wall_pair?(normals)
      normals.combination(2).any? { |first, second|
        first[0] * second[0] + first[1] * second[1] + first[2] * second[2] <= FACING_WALL_MAX_DOT
      }
    end

    # Whether the walls leave NO WAY OUT : whether no direction leads away
    # from every one of them at once (no d with n·d > 0 for all walls n).
    # Such a direction is exactly how a pocket differs from a compartment —
    # it wraps a corner, so stepping along the bisector of its two walls
    # leaves it, while a bottom and two sides leaning over it hem the volume
    # in whichever way it is left open (the open ends of the tube only GRAZE
    # the walls, hence the strictness of ESCAPE_DIRECTION_MIN_DOT).
    #
    # By LP duality the best direction scores dist(0, conv(normals)), reached
    # at p/|p| for p the point of conv(normals) closest to the origin. That
    # point lies on a face of the hull spanned by at most 3 of the normals
    # (dimension 3), and is then the point of THAT face's affine hull closest
    # to the origin — so trying every such point over all subsets of 1, 2 and
    # 3 walls is exact, and cheap at the size #_wall_normals bounds them to.
    # Candidates are not screened : a subset whose closest point is not on the
    # hull simply scores worse than the optimum, and the origin lying inside
    # the hull (no way out) leaves every candidate scoring 0 or less.
    def _walls_leave_no_escape?(normals)
      return false if normals.size < 3  # A single wall, or two, always leave a way out unless antiparallel — a facing pair

      candidates = normals.dup
      normals.combination(2) { |first, second|
        point = _closest_point_on_line(first, second)
        candidates << point unless point.nil?
      }
      normals.combination(3) { |first, second, third|
        point = _closest_point_on_plane(first, second, third)
        candidates << point unless point.nil?
      }

      candidates.none? { |point|
        norm = Math.sqrt(point[0] * point[0] + point[1] * point[1] + point[2] * point[2])
        next false if norm < ESCAPE_DIRECTION_MIN_DOT
        normals.map { |normal|
          (normal[0] * point[0] + normal[1] * point[1] + normal[2] * point[2]) / norm
        }.min > ESCAPE_DIRECTION_MIN_DOT
      }
    end

    # Point of the line through the two given points closest to the origin,
    # or nil when they are the same point.
    def _closest_point_on_line(first, second)
      ux = second[0] - first[0] ; uy = second[1] - first[1] ; uz = second[2] - first[2]
      uu = ux * ux + uy * uy + uz * uz
      return nil if uu < ESCAPE_DIRECTION_MIN_DOT * ESCAPE_DIRECTION_MIN_DOT
      t = -(first[0] * ux + first[1] * uy + first[2] * uz) / uu.to_f
      [ first[0] + t * ux, first[1] + t * uy, first[2] + t * uz ]
    end

    # Point of the plane through the three given points closest to the origin,
    # or nil when they are aligned.
    def _closest_point_on_plane(first, second, third)
      ux = second[0] - first[0] ; uy = second[1] - first[1] ; uz = second[2] - first[2]
      vx = third[0] - first[0] ; vy = third[1] - first[1] ; vz = third[2] - first[2]
      mx = uy * vz - uz * vy
      my = uz * vx - ux * vz
      mz = ux * vy - uy * vx
      mm = mx * mx + my * my + mz * mz
      return nil if mm < ESCAPE_DIRECTION_MIN_DOT * ESCAPE_DIRECTION_MIN_DOT
      s = (first[0] * mx + first[1] * my + first[2] * mz) / mm.to_f
      [ s * mx, s * my, s * mz ]
    end

  end

end
