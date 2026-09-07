require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/worker/common/common_solid_find_cavities_worker'

# The hull envelope's RESTORE path, which puts a cavity's caps back where the
# panels really end after ENVELOPE_HULL_EROSION pulled them in, and the way a
# DETACHED part is told from one the enclosure needs.
#
# Everything here is plain array arithmetic - no entity - so the worker is
# built on an empty panel list and the methods are called directly. Lengths are
# in inches, SketchUp's internal unit, like the meshes they read.
class TC_Ladb_Worker_SolidFindCavities < TestUp::TestCase

  DELTA = 1e-9

  TOLERANCE = Ladb::OpenCutList::SolidMeshDef::TOLERANCE
  EROSION = Ladb::OpenCutList::CommonSolidFindCavitiesWorker::ENVELOPE_HULL_EROSION

  def setup
    @worker = Ladb::OpenCutList::CommonSolidFindCavitiesWorker.new([])
  end

  # -- Envelope restore planes --

  # One hull face must be registered ONCE, whatever the float noise between its
  # own triangles. A cap's eroded offset lands on a quantization boundary as
  # soon as it is the face the erosion ratio was set on - it then recedes by
  # exactly EROSION, a whole number of half tolerances - and passes through the
  # origin, which is simply where models are drawn. Below, that puts the two
  # triangles of one flat cap on either side of the boundary : a quantized key
  # registers the SAME plane twice, and the duplicate is not free downstream
  # (see #test_restore_envelope_vertices_ignores_a_parallel_correction).
  def test_envelope_restore_planes_deduplicates_a_plane_on_a_quantization_tie

    # z = EROSION exactly : d_eroded / TOLERANCE = -1.5, the tie. The relative
    # nudge is the float noise the erosion's own arithmetic leaves between two
    # triangles - orders of magnitude below the mesh tolerance, but enough to
    # round either way.
    z_low = EROSION * (1.0 - 1.0e-9)
    z_high = EROSION * (1.0 + 1.0e-9)

    assert_equal(-1, (-z_low / TOLERANCE).round, 'the first triangle must round one way')
    assert_equal(-2, (-z_high / TOLERANCE).round, 'the second triangle must round the other way')

    eroded_vertices = [
      0.0, 0.0, z_low,  0.0, 10.0, z_low,  10.0, 0.0, z_low,     # triangle, normal (0, 0, -1)
      0.0, 10.0, z_high, 10.0, 10.0, z_high, 10.0, 0.0, z_high   # its twin, same plane
    ]
    vertices = [
      0.0, 0.0, 0.0,  0.0, 10.0, 0.0,  10.0, 0.0, 0.0,
      0.0, 10.0, 0.0, 10.0, 10.0, 0.0, 10.0, 0.0, 0.0
    ]
    face_indices = [ 0, 1, 2, 3, 4, 5 ]

    planes = @worker.send(:_envelope_restore_planes, vertices, eroded_vertices, face_indices)

    assert_equal(1, planes.length)

    normal, d_eroded, d_original = planes.first
    assert_in_delta(0.0, normal[0], DELTA)
    assert_in_delta(0.0, normal[1], DELTA)
    assert_in_delta(-1.0, normal[2], DELTA)
    assert_in_delta(-EROSION, d_eroded, TOLERANCE * 0.1)
    assert_in_delta(0.0, d_original, DELTA)

  end

  # The counterpart : two faces sharing a normal but lying a real distance
  # apart - a cavity's near and far caps - are two planes and must stay two.
  def test_envelope_restore_planes_keeps_distinct_parallel_planes

    eroded_vertices = [
      0.0, 0.0, EROSION,  0.0, 10.0, EROSION,  10.0, 0.0, EROSION,
      0.0, 0.0, 20.0,     0.0, 10.0, 20.0,     10.0, 0.0, 20.0
    ]
    vertices = [
      0.0, 0.0, 0.0,  0.0, 10.0, 0.0,  10.0, 0.0, 0.0,
      0.0, 0.0, 20.0, 0.0, 10.0, 20.0, 10.0, 0.0, 20.0
    ]
    face_indices = [ 0, 1, 2, 3, 4, 5 ]

    planes = @worker.send(:_envelope_restore_planes, vertices, eroded_vertices, face_indices)

    assert_equal(2, planes.length)

  end

  # -- Envelope vertices restoration --

  # A vertex on the corner of two caps must come back onto BOTH restored
  # planes. A correction parallel to one already taken says nothing new, and
  # taking it anyway makes the system its twin normals form singular : the
  # singular fallback then keeps the LARGEST correction alone, so the cap it
  # duplicates loses its restoration entirely - the very failure a duplicated
  # plane produced (see
  # #test_envelope_restore_planes_deduplicates_a_plane_on_a_quantization_tie).
  def test_restore_envelope_vertices_ignores_a_parallel_correction

    # The far cap's erosion is proportional to ITS distance to the centroid,
    # so it is larger than the near one's : that is what makes it win the
    # singular fallback, and the near cap lose.
    far_erosion = EROSION * 20.0

    @worker.instance_variable_set(:@envelope_restore_planes, [
      [ [ 0.0, 0.0, -1.0 ], -EROSION, 0.0 ],
      [ [ 0.0, 0.0, -1.0 ], -EROSION, 0.0 ],   # the same plane twice
      [ [ -1.0, 0.0, 0.0 ], -far_erosion, 0.0 ]
    ])

    # One cap triangle (face id 0, so no wall holds the vertex), whose first
    # vertex sits on the corner the two caps make and the others well inside.
    fragment = {
      'vertices' => [ far_erosion, 1.0, EROSION,  5.0, 1.0, 5.0,  5.0, 2.0, 5.0 ],
      'face_indices' => [ 0, 1, 2 ],
      'face_ids' => [ 0 ]
    }

    @worker.send(:_restore_envelope_vertices, [ fragment ])

    assert_in_delta(0.0, fragment['vertices'][0], DELTA, 'the far cap must be restored')
    assert_in_delta(1.0, fragment['vertices'][1], DELTA)
    assert_in_delta(0.0, fragment['vertices'][2], DELTA, 'the near cap must be restored too')

    # The vertices off the caps are left alone
    assert_in_delta(5.0, fragment['vertices'][3], DELTA)
    assert_in_delta(5.0, fragment['vertices'][5], DELTA)

  end

  # -- Contour / internal panels --

  # Two panels : #0 a horizontal shelf (dominant normal Z, its two main faces
  # carrying ids 1 and 2), #1 a vertical side (dominant normal X, ids 3 and 4).
  PANEL_ID_RANGES = [ [ (1...3), 0 ], [ (3...5), 1 ] ]
  DOMINANT_NORMALS = [ [ 0.0, 0.0, 1.0 ], [ 1.0, 0.0, 0.0 ] ]

  # A panel a cavity bounds on BOTH sides is a divider, and the overall cavity
  # must not be bounded by it. A cavity face lies ON the panel, so its outward
  # normal points into it : the cavity ABOVE the shelf shows -Z there, the one
  # BELOW +Z.
  #
  # The side, meanwhile, exposes TWO parallel main planes to the cavity, both
  # facing the same way - an everyday rebate, for the back or a shoulder - and
  # that must NOT read as a divider.
  def test_internal_panel_indices_tells_a_divider_from_a_rebated_contour_panel

    fragment_def = _fragment([
      [ [ 0.0, 0.0, 0.0,  0.0, 1.0, 0.0,  1.0, 0.0, 0.0 ], 1 ],        # shelf, top face : normal -Z
      [ [ 0.0, 0.0, -1.0, 1.0, 0.0, -1.0, 0.0, 1.0, -1.0 ], 2 ],       # shelf, bottom face : normal +Z
      [ [ 2.0, 0.0, 0.0,  2.0, 1.0, 0.0,  2.0, 0.0, 1.0 ], 3 ],        # side, inner face : normal +X
      [ [ 2.5, 0.0, 0.0,  2.5, 1.0, 0.0,  2.5, 0.0, 1.0 ], 4 ]         # side, rebate bottom : +X again
    ])

    assert_equal([ 0 ], @worker.send(:_internal_panel_indices, [ fragment_def ], PANEL_ID_RANGES, DOMINANT_NORMALS))

  end

  # The second side must carry real area : the degenerate slivers a boolean
  # leaves where two faces are flush would otherwise turn every contour panel
  # into a divider - the very failure REDUCTION_MIN_AREA guards the reduction
  # planes against.
  def test_internal_panel_indices_ignores_a_sliver_on_the_second_side

    sliver = 0.01  # 5e-5 sq in, well below REDUCTION_MIN_AREA (1e-4)

    fragment_def = _fragment([
      [ [ 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0 ], 1 ],
      [ [ 0.0, 0.0, -1.0, sliver, 0.0, -1.0, 0.0, sliver, -1.0 ], 2 ]
    ])

    assert_equal([], @worker.send(:_internal_panel_indices, [ fragment_def ], PANEL_ID_RANGES, DOMINANT_NORMALS))

  end

  # An EDGE (chant) face says nothing about the sides of the board : a cabinet
  # side whose front chant bounds the cavity is a contour panel all the same.
  def test_internal_panel_indices_ignores_an_edge_face

    fragment_def = _fragment([
      [ [ 2.0, 0.0, 0.0, 2.0, 1.0, 0.0, 2.0, 0.0, 1.0 ], 3 ],     # inner main face : +X
      [ [ 0.0, 2.0, 0.0, 1.0, 2.0, 0.0, 0.0, 2.0, 1.0 ], 4 ]      # chant : -Y, perpendicular to the dominant normal
    ])

    assert_equal([], @worker.send(:_internal_panel_indices, [ fragment_def ], PANEL_ID_RANGES, DOMINANT_NORMALS))

  end

  # -- Panel components --

  # A door standing in FRONT of its case touches nothing : left in, it inflates
  # the hull over the gap and the cavity comes out flush with the door's back
  # rather than with the case's own front.
  def test_panel_components_splits_a_detached_door_from_its_case

    case_u = _case_mesh_defs
    door = _box_mesh_def(2.0, -3.0, 2.0, 8.0, -2.0, 8.0)

    assert_equal([ [ 0, 1, 2 ], [ 3 ] ], _components(case_u + [ door ]))

  end

  # Two boxes side by side, a world apart : two components.
  def test_panel_components_splits_two_disjoint_boxes

    assert_equal([ [ 0 ], [ 1 ] ], _components([
      _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0),
      _box_mesh_def(0.0, 20.0, 0.0, 10.0, 30.0, 1.0)
    ]))

  end

  # Panels abutting face to face are ONE part of the assembly.
  def test_panel_components_keeps_abutting_panels_together

    assert_equal([ [ 0, 1 ] ], _components([
      _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0),
      _box_mesh_def(0.0, 0.0, 1.0, 10.0, 10.0, 2.0)
    ]))

  end

  # A shelf on pins is a component of its own, which is what it geometrically
  # is - it is the hull test and the removal test that keep it, not this one.
  def test_panel_components_sees_a_floating_shelf_as_its_own

    floating = _box_mesh_def(2.0, 2.0, 4.0, 8.0, 8.0, 5.0)

    assert_equal([ [ 0, 1, 2 ], [ 3 ] ], _components(_case_mesh_defs + [ floating ]))

  end

  # Nothing to tell apart.
  def test_panel_components_returns_a_lone_panel_untouched

    assert_equal([ [ 0 ] ], _components([ _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0) ]))

  end

  # A case whose joints are modelled a half millimetre apart is welded nowhere
  # and is one case all the same : taking any of its walls away would leave a
  # cavity the hull closes back a hair smaller, exactly as a laid-on part does,
  # so the walls must never become candidates in the first place.
  def test_panel_components_absorbs_a_sloppy_joint

    sloppy = 0.5.mm.to_f  # over SolidMeshDef::TOLERANCE, under JOINT_MAX_GAP

    assert_equal([ [ 0, 1 ] ], _components([
      _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0),
      _box_mesh_def(0.0, 0.0, 1.0 + sloppy, 10.0, 10.0, 2.0)
    ]))

    apart = Ladb::OpenCutList::CommonSolidFindCavitiesWorker::JOINT_MAX_GAP * 2.0

    assert_equal([ [ 0 ], [ 1 ] ], _components([
      _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0),
      _box_mesh_def(0.0, 0.0, 1.0 + apart, 10.0, 10.0, 2.0)
    ]))

  end

  # -- Interior components --

  # The pre-test that keeps a shelf on pins, a drawer box, a partition with a
  # whisker of play from ever being tried : holding no vertex of the envelope,
  # it cannot shrink it. The margin is what tells "inside the hull" from "on
  # it" - a panel of the case itself must NOT read as interior.
  def test_points_within_planes_tells_an_interior_component_from_the_hull

    hull_planes = @worker.send(:_hull_planes, _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 10.0).vertices)
    interior = _box_mesh_def(2.0, 2.0, 4.0, 8.0, 8.0, 5.0).vertices
    on_the_hull = _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0).vertices
    outside = _box_mesh_def(2.0, -3.0, 2.0, 8.0, -2.0, 8.0).vertices

    assert_equal(true, @worker.send(:_points_within_planes?, interior, hull_planes, -TOLERANCE))
    assert_equal(false, @worker.send(:_points_within_planes?, on_the_hull, hull_planes, -TOLERANCE))
    assert_equal(false, @worker.send(:_points_within_planes?, outside, hull_planes, -TOLERANCE))

  end

  # -- Cavities kept --

  # Taking away a part that was merely inflating the envelope can do nothing
  # but SHRINK the cavity it was inflating - which is what earns its removal.
  def test_cavities_kept_accepts_a_cavity_that_only_shrank

    reference = [ _box_fragment(0.0, 0.0, 0.0, 10.0, 10.0, 10.0) ]
    shrunk = [ _box_fragment(0.0, 0.0, 0.0, 10.0, 10.0, 9.0) ]

    assert_equal(true, @worker.send(:_cavities_kept?, reference, shrunk))

  end

  # Taking away the shelf a zone rested on LOSES that zone.
  def test_cavities_kept_rejects_a_lost_cavity

    reference = [ _box_fragment(0.0, 0.0, 0.0, 10.0, 10.0, 10.0) ]
    elsewhere = [ _box_fragment(20.0, 20.0, 20.0, 30.0, 30.0, 30.0) ]

    assert_equal(false, @worker.send(:_cavities_kept?, reference, elsewhere))

  end

  # Taking away what SEPARATED two compartments merges them : the counterpart
  # is there, holding the inner point, but it is twice the cavity it stands
  # for - which no shrinking envelope could ever produce.
  def test_cavities_kept_rejects_two_compartments_merged_into_one

    reference = [
      _box_fragment(0.0, 0.0, 0.0, 10.0, 10.0, 10.0),
      _box_fragment(0.0, 0.0, 12.0, 10.0, 10.0, 22.0)
    ]
    merged = [ _box_fragment(0.0, 0.0, 0.0, 10.0, 10.0, 22.0) ]

    assert_equal(false, @worker.send(:_cavities_kept?, reference, merged))

  end

  # -----

  # #_panel_components on the given mesh defs.
  def _components(mesh_defs)
    @worker.send(:_panel_components, mesh_defs.each_with_index.map { |mesh_def, index| [ mesh_def, index ] })
  end

  # A U shaped case - a bottom carrying two sides - i.e. ONE part of the
  # assembly, whose hull encloses the space between the sides.
  def _case_mesh_defs
    [
      _box_mesh_def(0.0, 0.0, 0.0, 10.0, 10.0, 1.0),   # bottom
      _box_mesh_def(0.0, 0.0, 1.0, 1.0, 10.0, 10.0),   # left side
      _box_mesh_def(9.0, 0.0, 1.0, 10.0, 10.0, 10.0)   # right side
    ]
  end

  # A SolidMeshDef for an axis aligned box, filled in place : the methods above
  # only ever read #vertices of one, so no entity is needed to make it.
  def _box_mesh_def(x0, y0, z0, x1, y1, z1)
    mesh_def = Ladb::OpenCutList::SolidMeshDef.new
    mesh_def.vertices.concat(_box_vertices(x0, y0, z0, x1, y1, z1))
    mesh_def.face_indices.concat(BOX_FACE_INDICES)
    6.times do |face|
      mesh_def.face_ids.concat([ face, face ])
      mesh_def.face_info_defs << Ladb::OpenCutList::SolidFaceInfoDef.new(nil)
    end
    mesh_def
  end

  # A cavity fragment shaped like an axis aligned box - #volume, #centroid and
  # #contains_point? are all #_cavities_kept? reads of one.
  def _box_fragment(x0, y0, z0, x1, y1, z1)
    Ladb::OpenCutList::SolidCavityFragmentDef.new(_box_vertices(x0, y0, z0, x1, y1, z1), BOX_FACE_INDICES.dup, [], [])
  end

  def _box_vertices(x0, y0, z0, x1, y1, z1)
    [
      x0, y0, z0,  x1, y0, z0,  x1, y1, z0,  x0, y1, z0,
      x0, y0, z1,  x1, y0, z1,  x1, y1, z1,  x0, y1, z1
    ]
  end

  BOX_FACE_INDICES = [
    0, 2, 1,  0, 3, 2,
    4, 5, 6,  4, 6, 7,
    0, 1, 5,  0, 5, 4,
    2, 3, 7,  2, 7, 6,
    1, 2, 6,  1, 6, 5,
    3, 0, 4,  3, 4, 7
  ].freeze

  # -----

  # A cavity fragment made of the given   # A cavity fragment made of the given [ flat triangle coordinates, face id ]
  # triangles - all #_internal_panel_indices ever reads of one.
  def _fragment(triangles)
    vertices = []
    face_indices = []
    face_ids = []
    triangles.each do |coordinates, face_id|
      index = vertices.length / 3
      face_indices << index << index + 1 << index + 2
      vertices.concat(coordinates)
      face_ids << face_id
    end
    Ladb::OpenCutList::SolidCavityFragmentDef.new(vertices, face_indices, face_ids, [])
  end

end
