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

end
