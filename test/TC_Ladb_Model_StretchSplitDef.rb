require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/model/stretch/stretch_split_def'

# The pure computation half of a stretch : StretchSplitDef turns a grip move
# into a StretchDef - the move of each section, clamped - and StretchDef hands
# back the cutters to keep. Nothing here reads the model.
#
# The split defs are built by hand, the way CommonStretchSplitWorker lays them
# out : a content along the edit X axis, from x = 0 to x = width, cut in
# sections at the given ratios, each section owning the matter given as an
# [ xmin, xmax ] span. Lengths are in inches, SketchUp's internal unit ; the
# fixtures are written in mm.
class TC_Ladb_Model_StretchSplitDef < TestUp::TestCase

  DELTA = 1e-6

  StretchSplitDef = Ladb::OpenCutList::StretchSplitDef

  # Two sides of a 600 mm wide caisson, cut in the middle : one gap of 564 mm
  CAISSON = { width: 600, ratios: [ 0.5 ], matters: [ [ 0, 18 ], [ 582, 600 ] ] }

  # Same, with a divider in the middle section
  DIVIDED = { width: 600, ratios: [ 0.25, 0.75 ], matters: [ [ 0, 18 ], [ 291, 309 ], [ 582, 600 ] ] }

  # -- Plain stretch --

  # Pulling the grip moves the grip section by the whole move and leaves the
  # opposite one anchored : the shape is expanded by the move.
  def test_stretch_def_moves_the_grip_section_by_the_whole_move
    split_def = _split_def(**CAISSON)

    stretch_def = split_def.stretch_def(_p(600, 0, 0), _p(700, 0, 0))

    assert_equal(1.0, stretch_def.factor)
    assert_nil(stretch_def.t_coefs)
    assert(!stretch_def.emv.valid?, 'a plain stretch does not move the whole shape')
    _assert_vector([ 0, 0, 0 ], _edv(stretch_def, 0))
    _assert_vector([ 100, 0, 0 ], _edv(stretch_def, 1))
    assert_in_delta(100.mm, stretch_def.measure, DELTA)
    assert(!stretch_def.compressed?)
  end

  # The inner sections move in proportion to their index : the matter between
  # two cutters goes half way when there are two gaps.
  def test_stretch_def_moves_inner_sections_proportionally
    stretch_def = _split_def(**DIVIDED).stretch_def(_p(600, 0, 0), _p(700, 0, 0))

    _assert_vector([ 0, 0, 0 ], _edv(stretch_def, 0))
    _assert_vector([ 50, 0, 0 ], _edv(stretch_def, 1))
    _assert_vector([ 100, 0, 0 ], _edv(stretch_def, 2))
  end

  # A compression is capped so that the gaps keep 1 mm : here the single
  # 564 mm gap allows 563 mm, whatever the move asked.
  def test_stretch_def_clamps_a_compression_to_the_max_compression_distance
    split_def = _split_def(**CAISSON)
    assert_in_delta(563.mm, split_def.max_compression_distance, DELTA)

    stretch_def = split_def.stretch_def(_p(600, 0, 0), _p(-1400, 0, 0))

    assert(stretch_def.compressed?)
    assert_in_delta(563.mm, stretch_def.measure, DELTA)
    _assert_vector([ -563, 0, 0 ], _edv(stretch_def, 1))
  end

  # An expansion is never capped
  def test_stretch_def_does_not_clamp_an_expansion
    stretch_def = _split_def(**CAISSON).stretch_def(_p(600, 0, 0), _p(5600, 0, 0))

    assert_in_delta(5000.mm, stretch_def.measure, DELTA)
  end

  # Centered : both sides move by the grip move, the stretch vector is doubled
  # and the whole shape is moved back by one move.
  def test_stretch_def_centered_moves_both_sides
    stretch_def = _split_def(**CAISSON).stretch_def(_p(600, 0, 0), _p(700, 0, 0), centered: true)

    assert_equal(2.0, stretch_def.factor)
    _assert_vector([ -100, 0, 0 ], stretch_def.emv)
    _assert_vector([ 200, 0, 0 ], stretch_def.esv)
    _assert_vector([ 200, 0, 0 ], _edv(stretch_def, 1))
  end

  # A centered compression uses up the max compression distance twice as fast
  def test_stretch_def_centered_clamps_at_half_the_max_compression_distance
    stretch_def = _split_def(**CAISSON).stretch_def(_p(600, 0, 0), _p(0, 0, 0), centered: true)

    assert_in_delta(563.mm / 2, stretch_def.measure, DELTA)
    _assert_vector([ -563, 0, 0 ], stretch_def.esv)
  end

  # The "outside" measure line starts on the opposite face : it spans the
  # overall dimension, not the move.
  def test_stretch_def_measure_outside_starts_on_the_opposite_face
    split_def = _split_def(**CAISSON)

    stretch_def = split_def.stretch_def(_p(600, 0, 0), _p(700, 0, 0), measure_outside: true)
    _assert_point([ 0, 0, 0 ], stretch_def.lps)
    assert_in_delta(700.mm, stretch_def.measure, DELTA)

    stretch_def = split_def.stretch_def(_p(600, 0, 0), _p(700, 0, 0), measure_outside: true, centered: true)
    _assert_point([ -100, 0, 0 ], stretch_def.lps)
    assert_in_delta(800.mm, stretch_def.measure, DELTA)
  end

  # Pulling the MIN face : the anchored section is the max one, the section
  # holding x = 0 follows the grip. Moving the grip outward (-X) expands.
  def test_stretch_def_on_the_min_grip
    split_def = _split_def(grip: :min, **CAISSON)
    assert(split_def.reversed)

    stretch_def = split_def.stretch_def(_p(0, 0, 0), _p(-100, 0, 0))

    assert(!stretch_def.compressed?)
    _assert_vector([ 0, 0, 0 ], _edv_at(stretch_def, 590))
    _assert_vector([ -100, 0, 0 ], _edv_at(stretch_def, 10))

    assert(split_def.stretch_def(_p(0, 0, 0), _p(100, 0, 0)).compressed?)
  end

  # The programmatic shortcut pulls the grip face along its outward direction
  def test_stretch_def_by_distance
    split_def = _split_def(**CAISSON)

    stretch_def = split_def.stretch_def_by_distance(100.mm)
    _assert_vector([ 100, 0, 0 ], _edv(stretch_def, 1))
    assert(!stretch_def.compressed?)

    stretch_def = split_def.stretch_def_by_distance(-100.mm)
    _assert_vector([ -100, 0, 0 ], _edv(stretch_def, 1))
    assert(stretch_def.compressed?)

    stretch_def = _split_def(grip: :min, **CAISSON).stretch_def_by_distance(100.mm)
    _assert_vector([ -100, 0, 0 ], _edv_at(stretch_def, 10))
  end

  # Everything is computed in the edit space : with edit axes turned a quarter
  # around Z and moved away, the edit X axis is the global Y axis.
  def test_stretch_def_in_a_non_identity_edit_space
    et = Geom::Transformation.translation(Geom::Vector3d.new(1000.mm, 2000.mm, 0)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees)
    split_def = _split_def(et: et, **CAISSON)

    ps = split_def.end_point
    _assert_point([ 1000, 2600, 0 ], ps)

    stretch_def = split_def.stretch_def(ps, ps.offset(Y_AXIS, 100.mm))

    _assert_vector([ 100, 0, 0 ], _edv(stretch_def, 1))   # Edit space
    assert_in_delta(100.mm, stretch_def.measure, DELTA)
    assert(!stretch_def.compressed?)
  end

  # -- Interior handle --

  # Below the handle every gap takes +1/L of the move, above -1/U : the moved
  # section goes by the whole move, the ends stay.
  def test_interior_t_coefs
    split_def = _split_def(width: 600, ratios: [ 0.2, 0.4, 0.6 ], matters: [ [ 0, 18 ], [ 150, 168 ], [ 300, 318 ], [ 582, 600 ] ])

    _assert_array([ 0.0, 1.0, 0.5, 0.0 ], split_def.interior_t_coefs(1))
    _assert_array([ 0.0, 0.5, 1.0, 0.0 ], split_def.interior_t_coefs(2))

    assert_nil(split_def.interior_t_coefs(nil))
    assert_nil(split_def.interior_t_coefs(0), 'the first section is an anchor')
    assert_nil(split_def.interior_t_coefs(3), 'the last section is an anchor')
  end

  # Each gap that shrinks caps the move : here the divider has 273 mm on each
  # side, 1 mm is kept.
  def test_interior_max_distance
    split_def = _split_def(**DIVIDED)
    t_coefs = split_def.interior_t_coefs(1)

    assert_in_delta(272.mm, split_def.interior_max_distance(t_coefs, 1.0), DELTA)
    assert_in_delta(272.mm, split_def.interior_max_distance(t_coefs, -1.0), DELTA)
    assert_nil(split_def.interior_max_distance(nil, 1.0))
  end

  def test_stretch_def_interior_moves_the_handle_section_only
    split_def = _split_def(**DIVIDED)

    stretch_def = split_def.stretch_def(_p(300, 0, 0), _p(340, 0, 0), interior_index: 1)

    assert(stretch_def.interior?)
    _assert_array([ 0.0, 1.0, 0.0 ], stretch_def.t_coefs)
    _assert_vector([ 0, 0, 0 ], _edv(stretch_def, 0))
    _assert_vector([ 40, 0, 0 ], _edv(stretch_def, 1))
    _assert_vector([ 0, 0, 0 ], _edv(stretch_def, 2))
  end

  # The interior move is capped both ways, and the centered option has no
  # meaning there
  def test_stretch_def_interior_clamps_both_ways_and_ignores_centered
    split_def = _split_def(**DIVIDED)

    assert_in_delta(272.mm, split_def.stretch_def(_p(300, 0, 0), _p(1000, 0, 0), interior_index: 1).measure, DELTA)
    assert_in_delta(272.mm, split_def.stretch_def(_p(300, 0, 0), _p(-1000, 0, 0), interior_index: 1).measure, DELTA)

    stretch_def = split_def.stretch_def(_p(300, 0, 0), _p(340, 0, 0), interior_index: 1, centered: true, measure_outside: true)
    assert_equal(1.0, stretch_def.factor)
    _assert_point([ 300, 0, 0 ], stretch_def.lps)
  end

  # -- Measures --

  # "Outside" measures the overall dimension : 800 on a 600 wide content is a
  # 200 move.
  def test_measure_def_outside
    measure_def = _split_def(**CAISSON).measure_def(_p(600, 0, 0), 800.mm, _p(700, 0, 0), measure_outside: true)

    _assert_point([ 800, 0, 0 ], measure_def[:end_point])
    assert_in_delta(200.mm, measure_def[:compression_distance], DELTA)
    _assert_point([ 0, 0, 0 ], measure_def[:pmin])
    _assert_point([ 600, 0, 0 ], measure_def[:pmax])
  end

  # "Offset" measures the move ; its sign drives the way when the direction is
  # given. A compression beyond the max is reported, the caller refuses it.
  def test_measure_def_offset_reports_an_excessive_compression
    measure_def = _split_def(**CAISSON).measure_def(_p(600, 0, 0), -700.mm, _p(700, 0, 0), direction: X_AXIS)

    _assert_point([ -100, 0, 0 ], measure_def[:end_point])
    assert_in_delta(700.mm, measure_def[:compression_distance], DELTA)
    assert_in_delta(563.mm, measure_def[:max_compression_distance], DELTA)
  end

  # No direction and a reference point on the grip : the fallback direction
  # tells the way
  def test_measure_def_falls_back_on_the_given_direction
    split_def = _split_def(**CAISSON)

    measure_def = split_def.measure_def(_p(600, 0, 0), 100.mm, _p(600, 0, 0), fallback_direction: X_AXIS)
    _assert_point([ 700, 0, 0 ], measure_def[:end_point])

    assert_nil(split_def.measure_def(_p(600, 0, 0), 100.mm, _p(600, 0, 0)))
  end

  # -- Cutters --

  # The cutters to keep are the middles of the gaps, once stretched
  def test_cutter_ratios
    stretch_def = _split_def(**CAISSON).stretch_def(_p(600, 0, 0), _p(700, 0, 0))
    _assert_array([ 350.0 / 700 ], stretch_def.cutter_ratios)

    stretch_def = _split_def(**DIVIDED).stretch_def(_p(600, 0, 0), _p(700, 0, 0))
    _assert_array([ (18 + 341) / 2.0 / 700, (359 + 682) / 2.0 / 700 ], stretch_def.cutter_ratios)
  end

  # An interior stretch keeps the overall dimension : the ratios follow the
  # moved divider within the same bounds
  def test_cutter_ratios_interior
    stretch_def = _split_def(**DIVIDED).stretch_def(_p(300, 0, 0), _p(340, 0, 0), interior_index: 1)

    _assert_array([ (18 + 331) / 2.0 / 600, (349 + 582) / 2.0 / 600 ], stretch_def.cutter_ratios)
  end

  # -- Sections --

  # A curve is never deformed : it may make a section's matter spill over its
  # cutter, which the stretch must refuse
  def test_sections_valid
    split_def = _split_def(**CAISSON)
    assert(split_def.sections_valid?)

    split_def.section_defs.first.bounds.add(_p(350, 0, 0))
    assert(!split_def.sections_valid?)
  end

  # -- Uniqueness --

  # A mirrored twin sees the stretch axis reversed, and its sections swapped :
  # its deltas, anchored on the axis sign, are the same - the twins keep
  # sharing their definition.
  def test_compute_md5_unifies_a_mirrored_twin
    split_def = _split_def(**CAISSON)
    s0, s1 = split_def.section_defs
    definition = FakeDefinition.new(1)
    edge = FakeEntity.new(10)

    a = _child(definition, IDENTITY, s0, [ [ edge, s0, s1 ] ])
    b = _child(definition, Geom::Transformation.translation(Geom::Vector3d.new(600.mm, 0, 0)) * Geom::Transformation.scaling(-1, 1, 1), s1, [ [ edge, s1, s0 ] ])

    assert_equal(a.compute_md5(X_AXIS), b.compute_md5(X_AXIS))
  end

  # Two instances deformed in opposite ways must not share
  def test_compute_md5_separates_opposite_deformations
    split_def = _split_def(**CAISSON)
    s0, s1 = split_def.section_defs
    definition = FakeDefinition.new(1)
    edge = FakeEntity.new(10)

    a = _child(definition, IDENTITY, s0, [ [ edge, s0, s1 ] ])
    b = _child(definition, IDENTITY, s1, [ [ edge, s1, s0 ] ])

    assert(a.compute_md5(X_AXIS) != b.compute_md5(X_AXIS))
  end

  # The deltas are read on the section translation coefficients : across an
  # interior handle, two containers spanning a gap on each side of the moved
  # section have the same INDEX deltas but are deformed in opposite ways.
  def test_compute_md5_reads_interior_coefs_not_indices
    split_def = _split_def(**DIVIDED)
    s0, s1, s2 = split_def.section_defs
    t_coefs = split_def.interior_t_coefs(1)
    definition = FakeDefinition.new(1)
    edge = FakeEntity.new(10)

    fn_pair = lambda {
      [
        _child(definition, IDENTITY, s0, [ [ edge, s0, s1 ] ]),
        _child(definition, IDENTITY, s1, [ [ edge, s1, s2 ] ])
      ]
    }

    a, b = fn_pair.call
    assert_equal(a.compute_md5(X_AXIS), b.compute_md5(X_AXIS), 'plain stretch : both gaps grow alike')

    a, b = fn_pair.call   # compute_md5 is memoized
    assert(a.compute_md5(X_AXIS, t_coefs) != b.compute_md5(X_AXIS, t_coefs), 'interior stretch : one gap grows, the other shrinks')
  end

  private

  FakeDefinition = Struct.new(:persistent_id)
  FakeEntity = Struct.new(:persistent_id)
  FakeContainer = Struct.new(:definition, :transformation)

  def _p(x, y, z)
    Geom::Point3d.new(x.mm, y.mm, z.mm)
  end

  # A split def as CommonStretchSplitWorker lays it out (see the class comment)
  def _split_def(width:, ratios:, matters:, grip: :max, et: IDENTITY)
    reversed = grip == :min
    eps = reversed ? _p(width, 0, 0) : _p(0, 0, 0)
    epe = reversed ? _p(0, 0, 0) : _p(width, 0, 0)
    evpspe = eps.vector_to(epe)

    sorted = ratios.sort.uniq
    sorted = sorted.reverse.map { |ratio| 1 - ratio } if reversed
    limits = [ Float::INFINITY * (reversed ? 1 : -1) ] + sorted.map { |ratio| eps.x + ratio * evpspe.length * (reversed ? -1 : 1) } + [ Float::INFINITY * (reversed ? -1 : 1) ]
    section_defs = limits.each_cons(2).map.with_index { |min_max, index| StretchSplitDef::SectionDef.new(index, min_max.min, min_max.max, Geom::BoundingBox.new) }

    matters.each do |xmin, xmax|
      section_def = section_defs.find { |section_def| section_def.contains_point?(_p((xmin + xmax) / 2.0, 0, 0), :x) }
      section_def.bounds.add(_p(xmin, 0, 0), _p(xmax, 10, 10))
    end

    # Gaps between the sections that own matter, and the max compression, as the worker computes them
    vsd = (reversed ? section_defs.reverse : section_defs).select { |section_def| section_def.bounds.valid? }
    gap_defs = vsd.each_cons(2).map { |section_def0, section_def1| [ section_def0, section_def1, (section_def1.bounds.min.x - section_def0.bounds.max.x).abs ] }
    max_compression_distance = [ gap_defs.map(&:last).min * (vsd.size - 1) - 1.mm, 0 ].max

    eb = Geom::BoundingBox.new
    eb.add(_p(0, 0, 0), _p(width, 10, 10))

    StretchSplitDef.new(
      drawing_def: nil,
      axis: X_AXIS,
      et: et,
      det: IDENTITY,
      eb: eb,
      epmin: reversed ? epe : eps,
      epmax: reversed ? eps : epe,
      eps: eps,
      epe: epe,
      evpspe: evpspe,
      reversed: reversed,
      max_compression_distance: max_compression_distance,
      section_defs: section_defs,
      gap_defs: gap_defs,
      container_defs: []
    )
  end

  # A SPLIT child container of a root container, holding the given edges as
  # [ edge, start section, end section ]
  def _child(definition, transformation, section_def, edges)
    root = StretchSplitDef::ContainerDef.new(nil, IDENTITY, 0, nil, nil, StretchSplitDef::OPERATION_SPLIT)
    child = StretchSplitDef::ContainerDef.new(FakeContainer.new(definition, transformation), IDENTITY, 1, transformation, section_def, StretchSplitDef::OPERATION_SPLIT)
    child.parent = root
    edges.each do |edge, start_section_def, end_section_def|
      child.edge_defs << StretchSplitDef::EdgeDef.new(edge, IDENTITY, ORIGIN, start_section_def, end_section_def, StretchSplitDef::OPERATION_SPLIT)
    end
    child
  end

  def _edv(stretch_def, index)
    stretch_def.edvs[stretch_def.split_def.section_defs[index]]
  end

  # The move of the section holding the given x (mm)
  def _edv_at(stretch_def, x)
    stretch_def.edvs[stretch_def.split_def.section_defs.find { |section_def| section_def.contains_point?(_p(x, 0, 0), :x) }]
  end

  def _assert_vector(expected_mm, vector)
    expected_mm.each_with_index { |value, index| assert_in_delta(value.mm, vector.to_a[index].to_f, DELTA, "#{vector.to_a.inspect} (inches) != #{expected_mm.inspect} (mm)") }
  end
  alias_method :_assert_point, :_assert_vector

  def _assert_array(expected, actual)
    assert_equal(expected.length, actual.length, "#{actual.inspect} != #{expected.inspect}")
    expected.each_with_index { |value, index| assert_in_delta(value, actual[index], DELTA, "#{actual.inspect} != #{expected.inspect}") }
  end

end
