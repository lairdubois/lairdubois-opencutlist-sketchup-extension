require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/model/hardware/hardware_bench_def'

# The test bench of the hardware editor : its panels, the frames of the
# slots, and the measures computed from the dimensions of the panels.
class TC_Ladb_Model_HardwareBenchDef < TestUp::TestCase

  HardwareBenchDef = Ladb::OpenCutList::HardwareBenchDef

  MM = 1 / 25.4

  def test_supported_types
    assert(HardwareBenchDef.supported?('connector'))
    assert(HardwareBenchDef.supported?('hinge'))
    assert(HardwareBenchDef.supported?('fitting'))
    assert(!HardwareBenchDef.supported?('span'))
  end

  def test_default_and_invalid_topology
    assert_equal('corner', HardwareBenchDef.new('connector', nil, 19 * MM, 19 * MM).topology)
    assert_equal('overlay', HardwareBenchDef.new('hinge', nil, 19 * MM, 19 * MM).topology)
    assert_equal('corner', HardwareBenchDef.new('fitting', nil, 19 * MM, 19 * MM).topology)
    assert(!HardwareBenchDef.new('fitting', 'edge_edge', 19 * MM, 19 * MM).valid?)
    assert(!HardwareBenchDef.new('connector', 'inset', 19 * MM, 19 * MM).valid?)
    assert(!HardwareBenchDef.new('connector', 'flat_edge', 0, 19 * MM).valid?)
    assert(!HardwareBenchDef.new('span', nil, 19 * MM, 19 * MM).valid?)
  end

  # A panel on edge is measured across its width, a flat one across its thickness.
  def test_connector_measures
    {
      'flat_edge' => [ 100, 22 ],
      'edge_edge' => [ 100, 100 ],
      'flat_flat' => [ 19, 22 ],
    }.each do |topology, (ta, tb)|
      measures = HardwareBenchDef.new('connector', topology, 19 * MM, 22 * MM).measures
      assert_in_delta(ta * MM, measures['thickness_a'], 1e-9, topology)
      assert_in_delta(tb * MM, measures['thickness_b'], 1e-9, topology)
      assert_in_delta(ta * MM, measures['thickness_max_a'], 1e-9, topology)
      assert_in_delta(tb * MM, measures['thickness_min_b'], 1e-9, topology)
    end
    # Height : to the far side of a panel on edge - its thickness / 2 - or of a flat one
    measures = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 22 * MM).measures
    assert_in_delta(9.5 * MM, measures['height_a'], 1e-9)
    assert_in_delta(HardwareBenchDef::PANEL_DEPTH / 2, measures['height_b'], 1e-9)
  end

  def test_slot_measures_add_the_unsuffixed_ones
    bench_def = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 22 * MM)
    assert_in_delta(100 * MM, bench_def.slot_measures('a')['thickness'], 1e-9)
    assert_in_delta(22 * MM, bench_def.slot_measures('b')['thickness'], 1e-9)
    assert_in_delta(100 * MM, bench_def.slot_measures('b')['thickness_a'], 1e-9)
  end

  def test_connector_frames
    bench_def = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 19 * MM)
    assert_equal([ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ], bench_def.slot_transformation('a'))
    # b : a's, Z reversed - indirect
    b = bench_def.slot_transformation('b')
    assert_equal([ 0, 0, -1 ], b[8..10])
    assert_equal(-1, _determinant(b))
  end

  # b flat on a's edge : a goes toward -Z by its width, b toward +Z by its thickness
  def test_connector_panels
    a, b = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 22 * MM).panels
    assert_equal('a', a.slot)
    assert_in_delta(-100 * MM, a.min[2], 1e-9)
    assert_in_delta(0, a.max[2], 1e-9)
    assert_in_delta(9.5 * MM, a.max[1], 1e-9)
    assert_in_delta(0, b.min[2], 1e-9)
    assert_in_delta(22 * MM, b.max[2], 1e-9)
    assert_in_delta(HardwareBenchDef::PANEL_DEPTH / 2, b.max[1], 1e-9)
    # a's reference face : toward +Y of its laying frame, b has none
    assert_equal([ 1, 'max' ], a.reference)
    assert_nil(b.reference)
  end

  # In L : b stops flush with a's outer face - its height is a's half thickness
  def test_connector_corner
    bench_def = HardwareBenchDef.new('connector', 'corner', 19 * MM, 22 * MM)
    assert(bench_def.valid?)
    a, b = bench_def.panels
    assert_in_delta(9.5 * MM, a.max[1], 1e-9)
    assert_in_delta(9.5 * MM, b.max[1], 1e-9)
    assert_in_delta(9.5 * MM - HardwareBenchDef::PANEL_DEPTH, b.min[1], 1e-9)
    measures = bench_def.measures
    assert_in_delta(100 * MM, measures['thickness_a'], 1e-9)
    assert_in_delta(22 * MM, measures['thickness_b'], 1e-9)
    assert_in_delta(9.5 * MM, measures['height_a'], 1e-9)
    assert_in_delta(9.5 * MM, measures['height_b'], 1e-9)
  end

  # Swapped : a flat, b on edge - only where they play different parts
  def test_connector_swapped
    bench_def = HardwareBenchDef.new('connector', 'corner', 19 * MM, 22 * MM, true)
    assert(bench_def.swapped)
    a, b = bench_def.panels
    assert_in_delta(-19 * MM, a.min[2], 1e-9)
    assert_in_delta(11 * MM, a.max[1], 1e-9)
    assert_in_delta(11 * MM - HardwareBenchDef::PANEL_DEPTH, a.min[1], 1e-9)
    assert_in_delta(100 * MM, b.max[2], 1e-9)
    measures = bench_def.measures
    assert_in_delta(19 * MM, measures['thickness_a'], 1e-9)
    assert_in_delta(100 * MM, measures['thickness_b'], 1e-9)
    assert_in_delta(11 * MM, measures['height_a'], 1e-9)
    assert(!HardwareBenchDef.new('connector', 'flat_flat', 19 * MM, 22 * MM, true).swapped)
    assert(!HardwareBenchDef.new('hinge', 'overlay', 19 * MM, 22 * MM, true).swapped)
  end

  # The anchor where the tool lays it : the height option away from a's
  # reference face - both panels move along Y, the measures with them.
  def test_connector_height_option
    # A length
    a, b = HardwareBenchDef.new('connector', 'corner', 19 * MM, 22 * MM, false, 5 * MM).panels
    assert_in_delta(5 * MM, a.max[1], 1e-9)
    assert_in_delta(-14 * MM, a.min[1], 1e-9)
    assert_in_delta(5 * MM, b.max[1], 1e-9)
    measures = HardwareBenchDef.new('connector', 'corner', 19 * MM, 22 * MM, false, 5 * MM).measures
    assert_in_delta(5 * MM, measures['height_a'], 1e-9)
    assert_in_delta(5 * MM, measures['height_b'], 1e-9)
    # A factor of the joint's height - where the panels overlap
    a, b = HardwareBenchDef.new('connector', 'edge_edge', 30 * MM, 18 * MM, false, '/3').panels
    assert_in_delta(6 * MM, a.max[1], 1e-9)          # 18 / 3
    assert_in_delta(0, b.max[1], 1e-9)               # b 6 mm short of a's face
    a, _ = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 22 * MM, false, '*0,25').panels
    assert_in_delta(4.75 * MM, a.max[1], 1e-9)
    # Off the joint - a flat, far from b on edge - : from the joint's +Y side
    _, b = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 22 * MM, true, 5 * MM).panels
    assert_in_delta(5 * MM, b.max[1], 1e-9)
    # None : half of it, centered
    a, _ = HardwareBenchDef.new('connector', 'flat_edge', 19 * MM, 22 * MM).panels
    assert_in_delta(9.5 * MM, a.max[1], 1e-9)
  end

  # Shown with the bench Y up : panels on edge lie horizontal
  def test_connector_view_transformation
    identity = [ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ]
    assert_equal(identity, HardwareBenchDef.new('connector', 'flat_flat', 19 * MM, 19 * MM).view_transformation)
    assert_equal(identity, HardwareBenchDef.new('hinge', 'overlay', 19 * MM, 19 * MM).view_transformation)
    view = HardwareBenchDef.new('connector', 'corner', 19 * MM, 19 * MM).view_transformation
    assert_equal([ 0, 0, 1 ], view[4..6])
    assert_equal([ 0, -1, 0 ], view[8..10])
    assert_equal(1, _determinant(view))
  end

  # Both direct, X along the joint line, Z out of each face, Y = Z × X : the
  # side's Y goes back into the cabinet, toward the door's +Z.
  def test_hinge_frames
    bench_def = HardwareBenchDef.new('hinge', 'overlay', 19 * MM, 19 * MM)
    b = bench_def.slot_transformation('b')
    assert_equal([ 1, 0, 0 ], b[0..2])
    assert_equal([ 0, 0, 1 ], b[4..6])
    assert_equal([ 0, -1, 0 ], b[8..10])
    assert_equal(1, _determinant(b))
    assert_equal({ 'hinge_kind' => 'overlay' }, bench_def.context)
  end

  def test_hinge_panels_and_measures
    {
      'overlay' => [ 17, 0 ],       # The door covers the side, 2 mm short of its outer face
      'half_overlay' => [ 8.5, 0 ], # Half of it
      'inset' => [ -2, -19 ],       # Between the sides, the side flush with the door's outer face
    }.each do |kind, (edge, side_front)|
      bench_def = HardwareBenchDef.new('hinge', kind, 19 * MM, 19 * MM)
      door, side = bench_def.panels
      assert_equal([ 2, 'max' ], door.reference, kind)   # The door's back
      assert_equal([ 1, 'min' ], side.reference, kind)   # The side's inner face
      assert_in_delta(edge * MM, door.max[1], 1e-9, kind)
      assert_in_delta(side_front * MM, side.min[2], 1e-9, kind)
      measures = bench_def.measures
      assert_in_delta(19 * MM, measures['thickness_a'], 1e-9, kind)
      # b's from the joint line to the side's front, toward -Y of its frame
      assert_in_delta(-side_front * MM, measures['height_b'], 1e-9, kind)
      assert_in_delta(side_front * MM, bench_def.measure_cotes['height_b'][1][2], 1e-9, kind)
      if edge > 0
        assert_in_delta(edge * MM, measures['height_a'], 1e-9, kind)
      else
        assert(!measures.key?('height_a'), "#{kind} : the door doesn't reach the joint line")
      end
    end
  end

  # The frames of a hinge : a fitting sits in the inner corner the same way.
  def test_fitting_frames
    bench_def = HardwareBenchDef.new('fitting', 'corner', 19 * MM, 22 * MM)
    assert_equal([ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ], bench_def.slot_transformation('a'))
    assert_equal(HardwareBenchDef.new('hinge', 'overlay', 19 * MM, 22 * MM).slot_transformation('b'), bench_def.slot_transformation('b'))
    assert_equal(1, _determinant(bench_def.slot_transformation('b')))
    assert_equal([ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 ], bench_def.view_transformation)
    assert_equal({}, bench_def.context)
  end

  # The panel on edge ends on the other's face, the flat one goes past it :
  # to the outer face of the other in a corner, beyond in a T. Each is
  # measured across its thickness - a fitting is laid on faces.
  def test_fitting_panels_and_measures
    {
      [ 'corner', false ] => [ 0, -19, 0 ],
      [ 'flat_edge', false ] => [ 0, -19 - 60, 0 ],
      [ 'corner', true ] => [ 22, -19, 22 ],
      [ 'flat_edge', true ] => [ 22 + 60, -19, 22 + 60 ],
    }.each do |(topology, swapped), (a_max_y, b_min_z, height_a)|
      label = "#{topology}#{swapped ? ' swapped' : ''}"
      bench_def = HardwareBenchDef.new('fitting', topology, 19 * MM, 22 * MM, swapped)
      assert_equal(swapped, bench_def.swapped, label)
      a, b = bench_def.panels
      assert_equal([ 2, 'max' ], a.reference, label)
      assert_equal([ 1, 'min' ], b.reference, label)
      assert_in_delta(0, a.max[2], 1e-9, label)   # a's face on the joint line
      assert_in_delta(0, b.min[1], 1e-9, label)   # b's face on the joint line
      assert_in_delta(a_max_y * MM, a.max[1], 1e-9, label)
      assert_in_delta(swapped ? 0 : b_min_z * MM, b.min[2], 1e-9, label)
      measures = bench_def.measures
      assert_in_delta(19 * MM, measures['thickness_a'], 1e-9, label)
      assert_in_delta(22 * MM, measures['thickness_b'], 1e-9, label)
      # b's from the joint line to its edge, toward -Y of its frame
      assert_in_delta(swapped ? 0 : -b_min_z * MM, measures['height_b'], 1e-9, label)
      # 0 when a ends on b's face : laid on the face itself
      assert_in_delta(height_a * MM, measures['height_a'], 1e-9, label)
      # Plain boxes : no void between the nearest and the farthest
      %w[a b].each do |slot|
        assert_equal(measures["height_#{slot}"], measures["height_min_#{slot}"], label)
        assert_equal(measures["height_#{slot}"], measures["height_max_#{slot}"], label)
      end
    end
  end

  # Each measure has its cote, as long as it is, on the end of its panel.
  def test_measure_cotes
    { 'connector' => %w[corner flat_edge edge_edge flat_flat], 'hinge' => %w[overlay half_overlay inset], 'fitting' => %w[corner flat_edge] }.each do |type, topologies|
      topologies.each do |topology|
        bench_def = HardwareBenchDef.new(type, topology, 19 * MM, 22 * MM)
        measures = bench_def.measures
        cotes = bench_def.measure_cotes
        assert_equal(measures.keys.sort, cotes.keys.sort, topology)
        cotes.each do |name, (from, to)|
          length = Math.sqrt((0..2).map { |i| (to[i] - from[i])**2 }.inject(:+))
          assert_in_delta(measures[name], length, 1e-9, "#{topology} #{name}")
          assert_in_delta(-HardwareBenchDef::PANEL_LENGTH / 2, from[0], 1e-9, "#{topology} #{name}")
        end
      end
    end
  end

  # -----

  private

  # Of the 3x3 part of the given column-major 4x4 matrix
  def _determinant(m)
    a, b, c = m[0..2], m[4..6], m[8..10]
    a[0] * (b[1] * c[2] - b[2] * c[1]) - b[0] * (a[1] * c[2] - a[2] * c[1]) + c[0] * (a[1] * b[2] - a[2] * b[1])
  end

end
