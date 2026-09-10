require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/model/solid/solid_cavity_fragment_def'

# The OPENINGS of a cavity : the contours SolidCavityFragmentDef#opening_defs
# reads off the envelope caps, which is what a door, a drawer front or a glass
# pane is fitted to.
#
# The fragments are built by hand, cap triangles only unless a test needs more :
# an opening is read from the face id 0 triangles alone, so nothing else has to
# be there for the contours to be exact. Lengths are in inches, SketchUp's
# internal unit.
class TC_Ladb_Model_SolidCavityOpening < TestUp::TestCase

  DELTA = 1e-9

  # -- Contours --

  # The cap is a triangle soup ; the mouth is its outline. Every edge two cap
  # triangles share cancels, so a square split around a center vertex - the
  # shape a hull cap comes out as - must read as ONE loop of FOUR points, not
  # as its four triangles.
  def test_opening_defs_merges_a_tessellated_cap_into_one_contour

    # Square 120 x 120 on z = 0, wound counterclockwise seen from +Z (the cap
    # of a cavity lying below it), fanned around its center
    corners = [ [ 0.0, 0.0 ], [ 120.0, 0.0 ], [ 120.0, 120.0 ], [ 0.0, 120.0 ] ]
    vertices = corners.flat_map { |x, y| [ x, y, 0.0 ] } + [ 60.0, 60.0, 0.0 ]
    face_indices = [ 0, 1, 4,  1, 2, 4,  2, 3, 4,  3, 0, 4 ]

    opening_defs = _fragment(vertices, face_indices, [ 0 ] * 4).opening_defs

    assert_equal(1, opening_defs.length)

    opening_def = opening_defs.first
    assert_equal(1, opening_def.loops.length, 'the four triangles must merge into a single contour')
    assert_equal(4, opening_def.outer_loop.length, 'the contour must be the square, not its tessellation')
    assert_in_delta(120.0 * 120.0, opening_def.area, DELTA)

    assert_in_delta(0.0, opening_def.normal.x, DELTA)
    assert_in_delta(0.0, opening_def.normal.y, DELTA)
    assert_in_delta(1.0, opening_def.normal.z, DELTA)

    assert(opening_def.outer_loop.all? { |point| point.z.to_f.abs < DELTA }, 'the contour must lie on the opening plane')
  end

  # A through cavity (a tube open at both ends) has two openings, and each
  # carries its own outward normal - that is what tells a door which way it
  # faces.
  def test_opening_defs_reads_both_ends_of_a_through_cavity

    # Two parallel caps 200 apart, each wound outward : +Z on top, -Z below
    vertices = [
      0.0, 0.0, 200.0,  120.0, 0.0, 200.0,  120.0, 120.0, 200.0,  0.0, 120.0, 200.0,
      0.0, 0.0, 0.0,    120.0, 0.0, 0.0,    120.0, 120.0, 0.0,    0.0, 120.0, 0.0
    ]
    face_indices = [
      0, 1, 2,  0, 2, 3,   # top, counterclockwise seen from +Z
      4, 6, 5,  4, 7, 6    # bottom, counterclockwise seen from -Z
    ]

    opening_defs = _fragment(vertices, face_indices, [ 0 ] * 4).opening_defs

    assert_equal(2, opening_defs.length)
    assert(opening_defs.all? { |opening_def| opening_def.loops.length == 1 && opening_def.outer_loop.length == 4 })
    opening_defs.each { |opening_def| assert_in_delta(120.0 * 120.0, opening_def.area, DELTA) }

    normals = opening_defs.map { |opening_def| opening_def.normal.z.round(6) }.sort
    assert_equal([ -1.0, 1.0 ], normals, 'each end must point out of the cavity, its own way')

    origins = opening_defs.map { |opening_def| opening_def.origin.z.to_f.round(6) }.sort
    assert_equal([ 0.0, 200.0 ], origins)
  end

  # An opening is not always simply connected : a post standing in the middle
  # of it leaves an island. The island's contour is wound the other way, so it
  # SUBTRACTS from the area - the door to cut is the outer contour, and the
  # area says how much of it is really open.
  def test_opening_defs_subtracts_an_island_from_the_opening

    outer = [ [ 0.0, 0.0 ], [ 120.0, 0.0 ], [ 120.0, 120.0 ], [ 0.0, 120.0 ] ]
    inner = [ [ 40.0, 40.0 ], [ 80.0, 40.0 ], [ 80.0, 80.0 ], [ 40.0, 80.0 ] ]
    vertices = (outer + inner).flat_map { |x, y| [ x, y, 0.0 ] }

    # The ring, as four counterclockwise quads split in two triangles each
    face_indices = (0..3).flat_map { |index|
      o0 = index ; o1 = (index + 1) % 4 ; i0 = 4 + index ; i1 = 4 + (index + 1) % 4
      [ o0, o1, i1,  o0, i1, i0 ]
    }

    opening_defs = _fragment(vertices, face_indices, [ 0 ] * 8).opening_defs

    assert_equal(1, opening_defs.length)

    opening_def = opening_defs.first
    assert_equal(2, opening_def.loops.length, 'the island must come out as a contour of its own')
    assert_in_delta(120.0 * 120.0 - 40.0 * 40.0, opening_def.area, DELTA)

    assert_equal(4, opening_def.outer_loop.length)
    assert_in_delta(120.0 * 120.0, opening_def.signed_area(opening_def.outer_loop), DELTA, 'the outer contour must be the positively wound one')

    island = (opening_def.loops - [ opening_def.outer_loop ]).first
    assert_in_delta(-40.0 * 40.0, opening_def.signed_area(island), DELTA, 'the island must be wound the other way')
  end

  # A panel face flush with the mouth is NOT part of it : the contour is the
  # net boundary of the CAPS, and reading the plane as a whole would weld the
  # opening to whatever the panel draws there.
  def test_opening_defs_ignores_a_panel_face_coplanar_with_the_mouth

    # The mouth, 120 x 120 on z = 0, and a panel face of its own extending it
    # to x = 240 on the very same plane
    vertices = [
      0.0, 0.0, 0.0,  120.0, 0.0, 0.0,  120.0, 120.0, 0.0,  0.0, 120.0, 0.0,
      240.0, 0.0, 0.0, 240.0, 120.0, 0.0
    ]
    face_indices = [
      0, 1, 2,  0, 2, 3,   # cap
      1, 4, 5,  1, 5, 2    # panel face, coplanar
    ]

    opening_defs = _fragment(vertices, face_indices, [ 0, 0, 1, 1 ]).opening_defs

    assert_equal(1, opening_defs.length)
    assert_in_delta(120.0 * 120.0, opening_defs.first.area, DELTA, 'the panel face must not widen the mouth')
    assert_equal(4, opening_defs.first.outer_loop.length)
  end

  # -- Openings and their count --

  # The openings ARE the planes #opening_plane_count counts : a rim too small
  # to be an opening of its own must not come out as one either.
  def test_opening_defs_and_opening_plane_count_agree_on_a_non_flush_rim

    # The mouth, 120 x 120 on z = 0, and the 1 x 120 strip a side rising above
    # it leaves on x = 0 - 0.8 % of the cap area, well under
    # OPENING_PLANE_MIN_AREA_SHARE
    vertices = [
      0.0, 0.0, 0.0,  120.0, 0.0, 0.0,  120.0, 120.0, 0.0,  0.0, 120.0, 0.0,
      0.0, 0.0, 1.0,  0.0, 120.0, 1.0
    ]
    face_indices = [
      0, 1, 2,  0, 2, 3,   # the mouth
      0, 3, 5,  0, 5, 4    # the rim, on x = 0
    ]

    fragment_def = _fragment(vertices, face_indices, [ 0 ] * 4)

    assert_equal(1, fragment_def.opening_plane_count)
    assert_equal(1, fragment_def.opening_defs.length)
    assert_in_delta(120.0 * 120.0, fragment_def.opening_defs.first.area, DELTA)
  end

  # A hermetic cavity has no cap at all, hence no opening - and nothing to
  # chain.
  def test_opening_defs_of_a_closed_cavity_is_empty

    vertices = [ 0.0, 0.0, 0.0,  120.0, 0.0, 0.0,  120.0, 120.0, 0.0 ]
    face_indices = [ 0, 1, 2 ]

    fragment_def = _fragment(vertices, face_indices, [ 1 ])

    assert_equal(0, fragment_def.opening_plane_count)
    assert_equal([], fragment_def.opening_defs)
  end

  # -- Wall loops, for a neighbour closed on the plane a front panel is cut on --

  # A wall reads the same way a cap does : the net boundary of the plane's
  # triangles, provided they carry a real face id rather than 0.
  def test_wall_loops_on_plane_reads_a_walled_plane

    vertices = [ 0.0, 0.0, 0.0,  120.0, 0.0, 0.0,  120.0, 120.0, 0.0,  0.0, 120.0, 0.0 ]
    face_indices = [ 0, 1, 2,  0, 2, 3 ]

    fragment_def = _fragment(vertices, face_indices, [ 7, 7 ])

    loops = fragment_def.wall_loops_on_plane(_up, _at(0.0))

    assert_equal(1, loops.length)
    assert_equal(4, loops.first.length)
    assert_equal([], fragment_def.opening_defs, 'a walled plane is not an opening')
  end

  # SmartDrawFrontPanelActionHandler#_get_sibling_mouth_points falls back to this
  # for a neighbour CLOSED by a real panel : that panel sits one thickness
  # short of where the neighbour's hull cap would have been had it been open
  # instead, so an exact plane match would find nothing at all.
  def test_wall_loops_on_plane_reads_a_wall_set_back_by_its_own_panel

    vertices = [ 0.0, 0.0, -0.75,  120.0, 0.0, -0.75,  120.0, 120.0, -0.75,  0.0, 120.0, -0.75 ]
    face_indices = [ 0, 1, 2,  0, 2, 3 ]

    fragment_def = _fragment(vertices, face_indices, [ 7, 7 ])

    loops = fragment_def.wall_loops_on_plane(_up, _at(0.0))

    assert_equal(1, loops.length, 'a wall one panel thickness behind the plane still closes it')
    assert(loops.first.all? { |point| point.z.to_f.round(6) == -0.75 }, 'the loop must keep the wall\'s own depth, not the plane asked for')
  end

  # Bounded, though : a whole COMPARTMENT behind - the far side of a two depth
  # carcass, a sealed void - is walled facing this way too, and is no
  # neighbour of this plane. Read as one it robs the front panel of everything past
  # the bisector it has no business drawing.
  def test_wall_loops_on_plane_ignores_a_wall_a_compartment_away

    depth = -Ladb::OpenCutList::SolidCavityFragmentDef::WALL_PLANE_MAX_SETBACK - 1.0
    vertices = [ 0.0, 0.0, depth,  120.0, 0.0, depth,  120.0, 120.0, depth,  0.0, 120.0, depth ]
    face_indices = [ 0, 1, 2,  0, 2, 3 ]

    fragment_def = _fragment(vertices, face_indices, [ 7, 7 ])

    assert_equal([], fragment_def.wall_loops_on_plane(_up, _at(0.0)))
  end

  # The setback is read on the WALL, not on the cavity : one reaching right up
  # to the plane by its side, while the only wall facing it stands a
  # compartment behind, closes nothing there either. (The bounds say yes here
  # - it is the triangles that answer.)
  def test_wall_loops_on_plane_ignores_a_far_wall_of_a_cavity_reaching_the_plane

    depth = -Ladb::OpenCutList::SolidCavityFragmentDef::WALL_PLANE_MAX_SETBACK - 6.0
    vertices = [
      0.0, 0.0, depth,  120.0, 0.0, depth,  120.0, 120.0, depth,  0.0, 120.0, depth,   # facing +Z, far below
      120.0, 0.0, depth, 120.0, 120.0, depth, 120.0, 120.0, 0.0,  120.0, 0.0, 0.0      # facing +X, reaching z = 0
    ]
    face_indices = [ 0, 1, 2,  0, 2, 3,   4, 5, 6,  4, 6, 7 ]

    fragment_def = _fragment(vertices, face_indices, [ 7, 7, 8, 8 ])

    assert_equal([], fragment_def.wall_loops_on_plane(_up, _at(0.0)))
  end

  # A wall standing IN FRONT of the plane closes nothing of it either : it
  # belongs to whatever lies on the other side of the front panel.
  def test_wall_loops_on_plane_ignores_a_wall_in_front_of_the_plane

    vertices = [ 0.0, 0.0, 10.0,  120.0, 0.0, 10.0,  120.0, 120.0, 10.0,  0.0, 120.0, 10.0 ]
    face_indices = [ 0, 1, 2,  0, 2, 3 ]

    fragment_def = _fragment(vertices, face_indices, [ 7, 7 ])

    assert_equal([], fragment_def.wall_loops_on_plane(_up, _at(0.0)))
  end

  # The match is by SIGNED normal : a wall facing the other way belongs to
  # whatever lies on ITS side, not to a cavity asking after the opposite
  # direction.
  def test_wall_loops_on_plane_ignores_a_wall_facing_the_other_way

    vertices = [ 0.0, 0.0, 0.0,  0.0, 120.0, 0.0,  120.0, 0.0, 0.0 ] # wound for normal (0, 0, -1)
    face_indices = [ 0, 1, 2 ]

    fragment_def = _fragment(vertices, face_indices, [ 7 ])

    assert_equal([], fragment_def.wall_loops_on_plane(_up, _at(0.0)))
  end

  # A plane that is OPEN (its triangles are caps, face id 0) has no wall to
  # read at all - #opening_defs is where that plane is found instead.
  def test_wall_loops_on_plane_is_empty_for_an_open_plane

    vertices = [ 0.0, 0.0, 0.0,  120.0, 0.0, 0.0,  120.0, 120.0, 0.0,  0.0, 120.0, 0.0 ]
    face_indices = [ 0, 1, 2,  0, 2, 3 ]

    fragment_def = _fragment(vertices, face_indices, [ 0, 0 ])

    assert_equal([], fragment_def.wall_loops_on_plane(_up, _at(0.0)))
  end

  private

  def _fragment(vertices, face_indices, face_ids)
    Ladb::OpenCutList::SolidCavityFragmentDef.new(vertices, face_indices, face_ids, [])
  end

  # The plane the wall tests ask after : z = +z_offset, looking up.
  def _up
    Geom::Vector3d.new(0.0, 0.0, 1.0)
  end

  def _at(z_offset)
    Geom::Point3d.new(0.0, 0.0, z_offset)
  end

end
