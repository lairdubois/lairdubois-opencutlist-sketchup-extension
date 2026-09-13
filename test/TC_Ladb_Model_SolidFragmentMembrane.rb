require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/model/solid/solid_cavity_fragment_def'

# The MEMBRANE a fragment may carry : SolidFragmentDef#carries_membrane?, the
# signature CommonSolidFindCavitiesWorker reads to tell a cavity Meshy welded
# two compartments into from a sound one — see that worker's #_find_cavities,
# MEMBRANE BACKSTOP.
#
# The fragments are built by hand : the detector reads nothing but the triangle
# planes, so a box and a sheet are enough to say what it must and must not
# answer. Lengths are in inches, SketchUp's internal unit.
class TC_Ladb_Model_SolidFragmentMembrane < TestUp::TestCase

  TOLERANCE = Ladb::OpenCutList::SolidMeshDef::TOLERANCE

  # -- Sound fragments --

  # The base case a whole model is made of, and the one that says why the
  # reading has to be SIGNED : a closed box is nothing but three pairs of
  # planes with opposite normals — its bottom looking down and its top looking
  # up, and so on for the four sides. What separates them from a membrane's two
  # sides is their OFFSETS, which stand 30 (resp. 20, 10) apart instead of
  # cancelling. Read unsigned, every box there is would be flagged.
  def test_a_plain_box_carries_no_membrane
    refute(_box(0.0, 0.0, 0.0, 20.0, 10.0, 30.0).carries_membrane?,
           'a box must not read as a membrane, however many opposed faces it has')
  end

  # A cavity bounded by two boards a hair apart — the 0.01 mm joint play of a
  # real drawing — is sound : the two faces are opposite, but they stand clear
  # of each other. Only a distance UNDER the boolean tolerance is a membrane.
  def test_two_faces_just_clear_of_each_other_are_not_a_membrane
    refute(_facing_sheets(TOLERANCE * 10.0).carries_membrane?,
           'faces further apart than the tolerance bound a real gap, thin as it is')
  end

  # -- Membranes --

  # The defect itself : a sheet of zero thickness, both of its sides on one
  # plane. This is what the shelf's end face and the side's inner face come out
  # as when the nudging leaves their flush contact tiled twice over.
  def test_a_zero_thickness_sheet_carries_a_membrane
    assert(_facing_sheets(0.0).carries_membrane?)
  end

  # The two sides of a membrane are the same plane seen twice, so they agree
  # closely — but not always to the last digit, the nudging having moved them.
  # Anything within the boolean tolerance is the same plane.
  def test_a_sheet_thinner_than_the_tolerance_carries_a_membrane
    assert(_facing_sheets(TOLERANCE / 2.0).carries_membrane?)
  end

  # -- Slivers --

  # A boolean leaves degenerate triangles wherever two faces are flush, and
  # their normals are pure numerical noise : they pair up with anything. A
  # membrane is a real face — square inches — and the area gate is what keeps
  # such a sliver from sending the backstop off on every model.
  def test_a_sliver_pair_is_not_a_membrane
    refute(_facing_sheets(0.0, size: 0.005).carries_membrane?,
           'a sliver below MEMBRANE_MIN_AREA says nothing about the fragment')
  end

  private

  # Two square sheets of +size+ on z = 0 and z = +gap+, facing each other :
  # the lower one looks UP (+Z), the upper one DOWN (-Z), which is how the two
  # sides of one membrane are wound. gap = 0 puts them on the very same plane.
  def _facing_sheets(gap, size: 10.0)
    vertices = [
      0.0, 0.0, 0.0,   size, 0.0, 0.0,   size, size, 0.0,   0.0, size, 0.0,
      0.0, 0.0, gap,   size, 0.0, gap,   size, size, gap,   0.0, size, gap
    ]
    face_indices = [
      0, 1, 2,  0, 2, 3,   # z = 0, wound counterclockwise seen from +Z
      4, 6, 5,  4, 7, 6    # z = gap, wound counterclockwise seen from -Z
    ]
    _fragment(vertices, face_indices, [ 0 ] * 4)
  end

  def _box(x0, y0, z0, x1, y1, z1)
    vertices = [
      x0, y0, z0,  x1, y0, z0,  x1, y1, z0,  x0, y1, z0,
      x0, y0, z1,  x1, y0, z1,  x1, y1, z1,  x0, y1, z1
    ]
    face_indices = [
      0, 2, 1,  0, 3, 2,   # bottom, outward = -Z
      4, 5, 6,  4, 6, 7,   # top, outward = +Z
      0, 1, 5,  0, 5, 4,   # y = y0, outward = -Y
      3, 7, 6,  3, 6, 2,   # y = y1, outward = +Y
      0, 4, 7,  0, 7, 3,   # x = x0, outward = -X
      1, 2, 6,  1, 6, 5    # x = x1, outward = +X
    ]
    _fragment(vertices, face_indices, [ 0 ] * 12)
  end

  def _fragment(vertices, face_indices, face_ids)
    Ladb::OpenCutList::SolidCavityFragmentDef.new(vertices, face_indices, face_ids, [])
  end

end
