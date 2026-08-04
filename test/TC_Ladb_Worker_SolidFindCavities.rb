require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/worker/common/common_solid_find_cavities_worker'

# The hull envelope's RESTORE path, which puts a cavity's caps back where the
# panels really end after ENVELOPE_HULL_EROSION pulled them in.
#
# Everything here is plain array arithmetic - no entity, no native lib - so the
# worker is built on an empty panel list and the methods are called directly.
# Lengths are in inches, SketchUp's internal unit, like the meshes they read.
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

  # -----

  # A cavity fragment made of the given [ flat triangle coordinates, face id ]
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
