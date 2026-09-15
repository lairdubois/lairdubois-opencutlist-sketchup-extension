require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/model/solid/solid_boolean_result_def'

# SolidFragmentDef#collapse_short_edges : the vertices a boolean leaves closer
# than SketchUp's weld tolerance, collapsed on the index mesh so that the shell
# SketchUp rebuilds stays closed.
#
# The two rails are REAL Meshy output : the top and bottom rails of a carcass
# whose right compartment already had its back let into a groove, cut again by
# the groove of the left compartment's back, which runs 1 mm on into the first
# one. The cut is imprinted where its end edge crosses the triangulation
# diagonal of the old groove bottom, 0.007 to 0.016 mm from the real corners,
# and SketchUp welded those into a non manifold rail. Lengths are in inches.
class TC_Ladb_Model_SolidFragmentDef < TestUp::TestCase

  TOLERANCE = Ladb::OpenCutList::SolidMeshDef::TOLERANCE

  TOP_RAIL_VERTICES = [
    35.75955195789719, 16.460602158525603, 44.62672986204339,
    35.75955195789719, 16.460602158525603, 45.37476135810638,
    35.75955195789719, 29.310841246711487, 44.62672986204339,
    35.75955195789719, 29.625801876632746, 44.62672986204339,
    35.75955195789719, 30.01950266403432, 44.62672986204339,
    54.74366002, 29.310841246711487, 44.62672986204339,
    54.74366002, 29.625801876632746, 44.62672986204339,
    35.75955195789719, 29.310841246711487, 45.02043065,
    35.75955195789719, 29.625801876632746, 45.02043065,
    35.75955195789719, 30.01950266403432, 45.37476135810638,
    54.74366002, 29.310841246711487, 45.02043065,
    54.74366002, 29.31108616196056, 45.02043065,
    54.70428994, 29.62516196810166, 45.02043065,
    54.74366002, 29.625801876632746, 45.02043065,
    105.3341516730521, 16.460602158525603, 44.62672986204339,
    105.3341516730521, 16.460602158525603, 45.37476135810638,
    105.3341516730521, 29.310841246711487, 44.62672986204339,
    105.3341516730521, 29.625801876632746, 44.62672986204339,
    105.3341516730521, 30.01950266403432, 44.62672986204339,
    105.3341516730521, 29.310841246711487, 45.02043065,
    105.3341516730521, 29.625801876632746, 45.02043065,
    105.3341516730521, 30.01950266403432, 45.37476135810638,
  ]

  TOP_RAIL_FACE_INDICES = [
    0, 5, 14,
    0, 1, 9,
    0, 15, 1,
    1, 15, 9,
    0, 2, 5,
    0, 7, 2,
    4, 3, 8,
    4, 18, 3,
    18, 6, 3,
    4, 9, 18,
    0, 9, 7,
    4, 8, 9,
    9, 8, 7,
    13, 11, 12,
    0, 14, 15,
    14, 16, 15,
    16, 5, 10,
    20, 13, 6,
    14, 5, 16,
    17, 6, 18,
    17, 20, 6,
    17, 18, 20,
    16, 10, 19,
    9, 15, 21,
    19, 10, 11,
    20, 11, 13,
    9, 21, 18,
    15, 16, 19,
    15, 19, 21,
    19, 11, 20,
    18, 21, 20,
    19, 20, 21,
    2, 7, 5,
    6, 13, 3,
    8, 3, 13,
    5, 7, 10,
    7, 8, 12,
    11, 10, 7,
    11, 7, 12,
    13, 12, 8,
  ]

  TOP_RAIL_FACE_IDS = [8, 9, 4, 7, 8, 9, 9, 8, 8, 3, 9, 9, 9, 0, 4, 5, 2, 1, 8, 8, 1, 5, 2, 7, 0, 0, 3, 5, 5, 0, 5, 5, 36, 37, 37, 36, 38, 38, 38, 38]

  BOTTOM_RAIL_VERTICES = [
    35.75955195789719, 16.460602158525603, 0.0,
    35.75955195789719, 16.460602158525603, 0.7480314960629926,
    35.75955195789719, 30.01950266403432, 0.0,
    35.75955195789719, 29.310841246711487, 0.35433071,
    35.75955195789719, 29.625801876632746, 0.35433071,
    54.74366002, 29.31108616196056, 0.35433071,
    54.73276255864615, 29.311018370519403, 0.35433071,
    54.74366002, 29.310841246711487, 0.35433071,
    54.74366002, 29.625801876632746, 0.35433071,
    35.75955195789719, 29.310841246711487, 0.7480314960629926,
    35.75955195789719, 29.625801876632746, 0.7480314960629926,
    35.75955195789719, 30.01950266403432, 0.7480314960629926,
    54.74366002, 29.310841246711487, 0.7480314960629926,
    54.74366002, 29.625801876632746, 0.7480314960629926,
    105.3341516730521, 16.460602158525603, 0.0,
    105.3341516730521, 16.460602158525603, 0.7480314960629926,
    105.3341516730521, 30.01950266403432, 0.0,
    105.3341516730521, 29.310841246711487, 0.35433071,
    105.3341516730521, 29.625801876632746, 0.35433071,
    105.3341516730521, 29.310841246711487, 0.7480314960629926,
    105.3341516730521, 29.625801876632746, 0.7480314960629926,
    105.3341516730521, 30.01950266403432, 0.7480314960629926,
  ]

  BOTTOM_RAIL_FACE_INDICES = [
    0, 1, 2,
    0, 14, 1,
    0, 2, 14,
    1, 15, 9,
    1, 3, 2,
    2, 3, 4,
    2, 4, 11,
    5, 6, 7,
    1, 9, 3,
    11, 4, 10,
    11, 10, 13,
    15, 12, 9,
    2, 11, 21,
    11, 13, 21,
    1, 14, 15,
    14, 19, 15,
    2, 16, 14,
    17, 5, 7,
    18, 8, 5,
    2, 21, 16,
    14, 16, 17,
    14, 17, 19,
    17, 18, 5,
    16, 18, 17,
    16, 21, 18,
    17, 7, 12,
    20, 13, 8,
    19, 12, 15,
    18, 20, 8,
    17, 12, 19,
    20, 21, 13,
    18, 21, 20,
    3, 6, 4,
    3, 7, 6,
    4, 6, 8,
    5, 8, 6,
    3, 9, 7,
    13, 4, 8,
    10, 4, 13,
    9, 12, 7,
  ]

  BOTTOM_RAIL_FACE_IDS = [15, 14, 16, 17, 15, 15, 15, 11, 15, 15, 17, 17, 18, 17, 14, 19, 16, 11, 11, 18, 19, 19, 11, 19, 19, 12, 13, 17, 13, 12, 17, 19, 40, 40, 40, 40, 36, 37, 37, 36]

  # -- Collapse --

  def test_collapse_short_edges_closes_the_top_rail
    _assert_collapsed(TOP_RAIL_VERTICES, TOP_RAIL_FACE_INDICES, TOP_RAIL_FACE_IDS, [ [ 1390.489, 744.502 ] ])
  end

  def test_collapse_short_edges_closes_the_bottom_rail
    _assert_collapsed(BOTTOM_RAIL_VERTICES, BOTTOM_RAIL_FACE_INDICES, BOTTOM_RAIL_FACE_IDS, [ [ 1390.489, 744.502 ] ])
  end

  # Nothing to collapse, nothing rebuilt : the very same fragment comes back.
  def test_collapse_short_edges_leaves_a_sound_fragment_alone
    vertices = [ 0, 0, 0,  1, 0, 0,  1, 1, 0,  0, 1, 0,  0, 0, 1,  1, 0, 1,  1, 1, 1,  0, 1, 1 ].map(&:to_f)
    face_indices = [ 0, 2, 1,  0, 3, 2,  4, 5, 6,  4, 6, 7,  0, 1, 5,  0, 5, 4,  1, 2, 6,  1, 6, 5,  2, 3, 7,  2, 7, 6,  3, 0, 4,  3, 4, 7 ]
    fragment_def = Ladb::OpenCutList::SolidFragmentDef.new(vertices, face_indices, [ 0 ] * 12, [])
    assert(fragment_def.collapse_short_edges(TOLERANCE).equal?(fragment_def))
  end

  private

  # The collapsed rail : closed and consistently wound, no two indexed
  # vertices closer than the tolerance, the imprints gone rather than the
  # corners they stood by (a NEEDLE apex, far from any vertex, is not an
  # imprint of that kind : see CommonSolidBooleanApplyWorker#_merge_sliver_triangles), the volume unchanged but for what the tolerance
  # can move, and a face id still on every triangle.
  def _assert_collapsed(vertices, face_indices, face_ids, imprints_mm)
    fragment_def = Ladb::OpenCutList::SolidFragmentDef.new(vertices, face_indices, face_ids, [])
    collapsed_def = fragment_def.collapse_short_edges(TOLERANCE)

    assert(!collapsed_def.equal?(fragment_def), 'nothing collapsed')
    assert(collapsed_def.triangle_count < fragment_def.triangle_count)
    assert_equal(collapsed_def.triangle_count, collapsed_def.face_ids.length)

    directed = Hash.new(0)
    collapsed_def.face_indices.each_slice(3) { |a, b, c| [ [ a, b ], [ b, c ], [ c, a ] ].each { |edge| directed[edge] += 1 } }
    assert(directed.all? { |(a, b), count| count == 1 && directed[[ b, a ]] == 1 }, 'not closed')

    indexed = collapsed_def.face_indices.uniq
    indexed.combination(2).each do |a, b|
      distance2 = (0..2).inject(0.0) { |sum, axis| sum + (vertices[a * 3 + axis] - vertices[b * 3 + axis])**2 }
      assert(distance2 >= TOLERANCE * TOLERANCE, "vertices #{a} and #{b} still closer than the tolerance")
    end

    imprints_mm.each do |x, y|
      assert(indexed.none? { |index| (vertices[index * 3] * 25.4 - x).abs < 0.001 && (vertices[index * 3 + 1] * 25.4 - y).abs < 0.001 }, "imprint #{[ x, y ].inspect} kept")
    end

    assert_in_delta(fragment_def.volume, collapsed_def.volume, 1e-3)
  end

end
