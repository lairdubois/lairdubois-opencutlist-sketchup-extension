require 'testup/testcase'
require 'json'

require_relative '../src/ladb_opencutlist/ruby/worker/hardware/hardware_bench_compute_worker'

# What the hardware editor shows of a descriptor on its test bench :
# variables, asserts, solids and SKP files, in the bench frame. Nothing here
# reads the model.
class TC_Ladb_Worker_HardwareBenchCompute < TestUp::TestCase

  HardwareBenchComputeWorker = Ladb::OpenCutList::HardwareBenchComputeWorker

  MM = 1 / 25.4

  LIBRARY_DIR = File.expand_path('../src/ladb_opencutlist/library', __dir__)

  DOWEL = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'dowel-1', 'type' => 'connector', 'name' => 'Dowel',
    'variables' => {
      'diameter' => { 'value' => '8mm', 'label' => 'Diamètre', 'steps' => [ '6mm', '8mm', '10mm' ] },
      'length' => { 'value' => '40mm', 'min' => '20mm', 'max' => '60mm' },
      'embed_a' => 'min(@length / 2; @thickness_a - 4mm)',
      'embed_b' => '@length - @embed_a',
    },
    'asserts' => [ '@embed_a >= 10mm', '@embed_b <= @thickness_b - 3mm' ],
    'components' => {
      'a' => {
        'hardware' => { 'cylinders' => [ { 'diameter' => '@diameter', 'from' => '-@embed_a', 'to' => '@embed_b' } ] },
        'machining' => { 'drillings' => [ { 'diameter' => '@diameter', 'depth' => '@embed_a + 1mm' } ] }
      },
      'b' => { 'machining' => { 'drillings' => [ { 'diameter' => '@diameter', 'depth' => '@embed_b + 1mm' } ] } }
    }
  }.freeze

  def test_dowel_on_a_t_joint
    response = _run(DOWEL, topology: 'flat_edge', swapped: true, thickness_a: 19, thickness_b: 19)
    assert_equal([], response[:errors])
    assert(response[:supported])
    assert(response[:accepted])
    assert_equal('flat_edge', response[:topology])
    assert_equal(%w[corner flat_edge edge_edge flat_flat], response[:topologies])
    assert_equal(2, response[:panels].length)

    # Settings, as the editor shows them
    diameter = response[:settings].find { |setting| setting[:name] == 'diameter' }
    assert_equal('Diamètre', diameter[:label])
    assert_in_delta(8 * MM, diameter[:value][:value], 1e-9)
    assert_equal(3, diameter[:steps].length)
    length = response[:settings].find { |setting| setting[:name] == 'length' }
    assert_in_delta(60 * MM, length[:max][:value], 1e-9)

    # Variables : the same for both slots - one group
    embed_a = _variable(response, 'embed_a')
    assert_equal(1, embed_a[:results].length)
    assert_equal(%w[a b], embed_a[:results].first[:slots])
    assert_in_delta(15 * MM, embed_a[:results].first[:value], 1e-9)
    assert(!embed_a[:setting])
    assert(_variable(response, 'diameter')[:setting])

    # Solids : the dowel and the drilling in a, the drilling in b - Z reversed
    assert_equal(3, response[:solids].length)
    dowel = response[:solids].find { |solid| solid[:part] == 'hardware' }
    assert_in_delta(-15 * MM, dowel[:z_min], 1e-9)
    assert_in_delta(25 * MM, dowel[:z_max], 1e-9)
    assert_in_delta(8 * MM, dowel[:diameter], 1e-9)
    # What the viewer tells of it when hovered
    assert_equal('cylinders', dowel[:kind])
    assert(dowel[:texts][:depth] =~ /\A40\D*\z/, dowel[:texts][:depth])   # Not 40,000 : its trailing zeros dropped
    assert_nil(dowel[:texts][:length])
    drilling_b = response[:solids].find { |solid| solid[:slot] == 'b' }
    assert_in_delta(-26 * MM, drilling_b[:z_min], 1e-9)
    assert_equal([ 0, 0, -1 ], drilling_b[:transformation][8..10])
    assert_equal(0, response[:slots]['a'][:component][:hardware_unresolved])
    assert_equal([], response[:skps])
  end

  # Each primitive alone, as the editor lists them : its lengths resolved -
  # or why not - and its solid known by its key and index.
  def test_primitive_fields
    descriptor = JSON.parse(JSON.generate(DOWEL))
    descriptor['components']['a']['machining'] = { 'drillings' => [
      { 'x' => -32, 'diameter' => '@diameter', 'depth' => 'through', 'countersink' => { 'diameter' => '12mm' } },
      { 'x' => '@nope', 'diameter' => '5mm', 'depth' => '10mm' },
    ] }
    response = _run(descriptor, topology: 'flat_edge', swapped: true, thickness_a: 19, thickness_b: 19)
    drillings = response[:slots]['a'][:component][:primitives]['machining']['drillings']
    assert_equal(2, drillings.length)

    first = drillings[0]
    assert(first[:resolved])
    assert(first[:fields]['x'][:text] =~ /\A-32\D*\z/, first[:fields]['x'][:text])
    assert(first[:fields]['depth'][:text] =~ /\A19\D*\z/, first[:fields]['depth'][:text])   # Through : the thickness
    assert(first[:fields]['head_diameter'][:text] =~ /\A12\D*\z/, first[:fields]['head_diameter'][:text])
    assert_nil(first[:fields]['y'])   # Not written

    second = drillings[1]
    assert(!second[:resolved])
    assert_equal('unresolved_variable', second[:fields]['x'][:error][:key])
    assert_equal('nope', second[:fields]['x'][:error][:params][:name])

    solids = response[:solids].select { |solid| solid[:slot] == 'a' && solid[:part] == 'machining' }
    assert_equal([ [ 'drillings', 0 ] ], solids.map { |solid| [ solid[:key], solid[:index] ] })
    hardware = response[:solids].find { |solid| solid[:slot] == 'a' && solid[:part] == 'hardware' }
    assert_equal([ 'cylinders', 0 ], [ hardware[:key], hardware[:index] ])

    # What their lengths can use
    names = response[:slots]['a'][:names].map { |name| name[:name] }
    assert_includes(names, 'thickness')
    assert_includes(names, 'embed_a')
    refute_includes(names, 'thickness_a')   # Its own : unsuffixed
    assert_includes(names, 'thickness_b')
  end

  def test_refused_joint_gives_both_sides
    response = _run(DOWEL, topology: 'flat_flat', thickness_a: 19, thickness_b: 19)
    assert(!response[:accepted])
    result = response[:asserts][1][:results].first
    assert(!result[:ok])
    assert_equal('<=', result[:operator])
    assert_in_delta(25 * MM, result[:left], 1e-9)
    assert_in_delta(16 * MM, result[:right], 1e-9)
    assert(response[:asserts][0][:results].first[:ok])
  end

  # An unsuffixed measure differs from slot to slot : one result per slot.
  def test_unsuffixed_measure_is_per_slot
    data = JSON.parse(JSON.generate(DOWEL))
    data['variables']['own'] = '@thickness - 1mm'
    response = _run(data, topology: 'flat_edge', swapped: true, thickness_a: 19, thickness_b: 19)
    results = _variable(response, 'own')[:results]
    assert_equal([ %w[a], %w[b] ], results.map { |result| result[:slots] })
    assert_in_delta(18 * MM, results[0][:value], 1e-9)
    assert_in_delta(99 * MM, results[1][:value], 1e-9)
  end

  # A descriptor that extends another : its parents, its merged data, and
  # what it only inherits - greyed by the editor.
  def test_inheritance
    Ladb::OpenCutList::HardwareDescriptorDef.library_resolver = lambda { |ref| ref.start_with?('$OCL/') ? File.join(LIBRARY_DIR, ref[5..-1]) : ref }
    begin
      child = {
        'format' => 'ocl-hardware', 'version' => 1, 'id' => 'mine', 'name' => 'Mine',
        'extends' => '$OCL/connectors/generic/dowels/dowel-8x40.json',
        'variables' => { 'clearance' => { 'value' => '2mm' } },
        'asserts' => [ '@super', '@depth_a >= 10mm' ]
      }
      response = _run(child, ref: '$LIB/connectors/mine.json', topology: 'flat_edge', thickness_a: 19, thickness_b: 19)
      assert_equal([ '$OCL/connectors/generic/dowels/dowel-8x40.json', '$OCL/connectors/generic/dowels/dowel.json' ], response[:inheritance][:parents])
      assert_equal('10mm', response[:inheritance][:data]['options']['start_offset'])
      settings = Hash[response[:settings].map { |setting| [ setting[:name], setting[:inherited] ] }]
      assert_equal({ 'diameter' => true, 'length' => true, 'min_wall' => true, 'clearance' => false }, settings)
      assert_nil(_run(DOWEL, topology: 'flat_edge')[:inheritance])
      assert_equal(false, response[:abstract])
      assert_equal(true, _run(File.read(File.join(LIBRARY_DIR, 'connectors/generic/dowels/dowel.json')), ref: '$OCL/connectors/generic/dowels/dowel.json', topology: 'flat_edge')[:abstract])
    ensure
      Ladb::OpenCutList::HardwareDescriptorDef.library_resolver = nil
    end
  end

  # An angle bracket whose screws use a connector : evaluated with the
  # screw's variables, at each of their positions, its asserts refusing the
  # bench where the panel is too thin.
  def test_articles
    Ladb::OpenCutList::HardwareDescriptorDef.library_resolver = lambda { |ref| ref.start_with?('$OCL/') ? File.join(LIBRARY_DIR, ref[5..-1]) : ref }
    begin
      text = File.read(File.join(LIBRARY_DIR, 'fittings/generic/angle-bracket-40x40.json'))
      response = _run(text, ref: '$OCL/fittings/generic/angle-bracket-40x40.json', topology: 'corner', thickness_a: 19, thickness_b: 19)
      assert_equal([], response[:errors])
      assert(response[:accepted])
      article = response[:slots]['a'][:component][:articles].first
      assert_equal('screws', article[:key])
      assert_equal('use', article[:kind])
      assert_equal('Screw 4x16', article[:used_name])
      assert_equal('a', article[:host])
      assert_equal('thickness_b', article[:virtual][:measure])
      assert_in_delta(2 * MM, article[:virtual][:value], 1e-9)
      assert_in_delta(-25 * MM, article[:positions].first[:y][:value], 1e-9)
      assert(article[:asserts].all? { |assert| assert[:ok] }, article[:asserts].inspect)
      assert_in_delta(14 * MM, article[:variables].find { |v| v[:name] == 'embed' }[:value], 1e-9)
      embed_min = article[:settings].find { |setting| setting[:name] == 'embed_min' }
      assert(embed_min[:overridden])
      assert_in_delta(10 * MM, embed_min[:value][:value], 1e-9)
      assert_in_delta(15 * MM, embed_min[:default][:value], 1e-9)   # screw.json's
      length = article[:settings].find { |setting| setting[:name] == 'length' }
      assert(!length[:overridden])
      assert_in_delta(16 * MM, length[:default][:value], 1e-9)
      solids = response[:solids].select { |solid| solid[:slot] == 'a' && solid[:article] == 'screws' }
      screw = solids.find { |solid| solid[:part] == 'hardware' }
      pilot = solids.find { |solid| solid[:part] == 'machining' }
      assert_in_delta(-14 * MM, screw[:z_min], 1e-9)
      assert_in_delta(2 * MM, screw[:z_max], 1e-9)   # Through the 2 mm wing
      assert_in_delta(-25 * MM, screw[:transformation][13], 1e-9)
      assert_in_delta(3 * MM, pilot[:diameter], 1e-9)
      assert_in_delta(14 * MM, pilot[:z_max] - pilot[:z_min], 1e-9)
      # b's in its own frame : y along the bench's Z
      b_screw = response[:solids].find { |solid| solid[:slot] == 'b' && solid[:article] == 'screws' && solid[:part] == 'hardware' }
      assert_in_delta(25 * MM, b_screw[:transformation][14], 1e-9)

      thin = _run(text, ref: '$OCL/fittings/generic/angle-bracket-40x40.json', topology: 'corner', thickness_a: 12, thickness_b: 19)
      assert(!thin[:accepted])
      assert_equal(false, thin[:slots]['a'][:component][:articles].first[:ok])
      assert_equal(true, thin[:slots]['b'][:component][:articles].first[:ok])
    ensure
      Ladb::OpenCutList::HardwareDescriptorDef.library_resolver = nil
    end
  end

  # A step no value matches : the variable says why, those using it too.
  def test_variable_errors
    Ladb::OpenCutList::HardwareDescriptorDef.library_resolver = lambda { |ref| ref.start_with?('$OCL/') ? File.join(LIBRARY_DIR, ref[5..-1]) : ref }   # Its parent
    begin
      response = _run(File.read(File.join(LIBRARY_DIR, 'connectors/festool/domino-5x30.json')), ref: '$OCL/connectors/festool/domino-5x30.json', topology: 'flat_edge', swapped: true, thickness_a: 12, thickness_b: 19)
    ensure
      Ladb::OpenCutList::HardwareDescriptorDef.library_resolver = nil
    end
    assert(!response[:accepted])
    cap_a = _variable(response, 'cap_a')[:results].first
    assert_equal('no_matching_value', cap_a[:error][:key])
    depth_b = _variable(response, 'depth_b')[:results].first
    assert_equal('unresolved_variable', depth_b[:error][:key])
    assert_equal('cap_a', depth_b[:error][:params][:name])
    # The primitives using them aren't laid
    assert(response[:slots]['a'][:component][:hardware_unresolved] > 0)
  end

  # A hinge : the kind selects the variant, parts declared true are SKP files
  # of the descriptor's components folder.
  def test_hinge_skps_and_variants
    text = File.read(File.join(LIBRARY_DIR, 'hinges/blum/clip-top.json'))
    response = _run(text, ref: '$OCL/hinges/blum/clip-top.json', topology: 'inset', thickness_a: 19, thickness_b: 19)
    assert_equal([], response[:errors])
    assert_equal('inset', response[:topology])
    assert_equal('inset', response[:slots]['a'][:component][:variant])
    refs = response[:skps].map { |skp| [ skp[:slot], skp[:part], skp[:ref] ] }
    assert_equal([
      [ 'a', 'hardware', '$OCL/components/hinges/blum/clip-top/a.inset.skp' ],
      [ 'b', 'hardware', '$OCL/components/hinges/blum/clip-top/b.skp' ],
    ], refs)
    assert_equal(3, response[:solids].count { |solid| solid[:slot] == 'a' })
    assert_equal(2, response[:solids].count { |solid| solid[:slot] == 'b' })
    # b's drillings : in the side's frame, its Y along the bench's Z
    drilling_b = response[:solids].find { |solid| solid[:slot] == 'b' }
    assert_equal([ 0, 0, 1 ], drilling_b[:transformation][4..6])
    assert_in_delta(37 * MM, drilling_b[:y], 1e-9)
    # No ref : a new descriptor, nowhere to find its files
    assert_equal([], _run(text, topology: 'inset')[:skps])
  end

  # A hinge's axis : its pivot in the frame of its hardware - the variant's
  # over the component's - along X, the hardware shifted by its z_offset.
  def test_hinge_axis
    data = JSON.parse(File.read(File.join(LIBRARY_DIR, 'hinges/blum/clip-top.json')))
    hinge = _run(data, topology: 'overlay')[:hinge]
    assert_equal(110.0, hinge[:max_angle])
    assert(hinge[:approximate])
    assert_equal([ 1.0, 0.0, 0.0 ], hinge[:axis])
    [ 0, 17, -29 ].each_with_index { |v, i| assert_in_delta(v * MM, hinge[:origin][i], 1e-9) }
    [ 0, 17, 0 ].each_with_index { |v, i| assert_in_delta(v * MM, hinge[:cotes][:y][i], 1e-9) }
    hinge = _run(data, topology: 'inset')[:hinge]
    [ 0, -4, -26 ].each_with_index { |v, i| assert_in_delta(v * MM, hinge[:origin][i], 1e-9) }
    # Shifted with its hardware
    data['components']['a']['z_offset'] = '2mm'
    assert_in_delta(-24 * MM, _run(data, topology: 'inset')[:hinge][:origin][2], 1e-9)
    # Incomplete : none
    data['components']['a'].delete('attributes')
    assert_nil(_run(data, topology: 'inset')[:hinge])
    # Not a hinge : none
    assert_nil(_run(DOWEL)[:hinge])
  end

  # Its height option : a's reference face 5 mm from the anchor, as the tool
  # lays it - the drillings along Y start there.
  def test_height_option
    response = _run(File.read(File.join(LIBRARY_DIR, 'connectors/lamello/cabineo/cabineo-8.json')), topology: 'corner', thickness_a: 19, thickness_b: 19)
    panel_a = response[:panels].find { |panel| panel[:slot] == 'a' }
    assert_in_delta(5 * MM, panel_a[:max][1], 1e-9)
    drilling = response[:solids].find { |solid| solid[:slot] == 'a' && solid[:part] == 'machining' }
    assert_in_delta(5 * MM, drilling[:z_max], 1e-9)
    # 0 : on a's reference face, as the tool - not half the joint
    data = JSON.parse(JSON.generate(DOWEL)).merge('options' => { 'height' => '0' })
    panel_a = _run(data, topology: 'corner', thickness_a: 19, thickness_b: 19)[:panels].find { |panel| panel[:slot] == 'a' }
    assert_in_delta(0, panel_a[:max][1], 1e-9)
  end

  # Its position cotes : its x, y, z as the descriptor gives them, in the
  # frame of its part - not the one turned along Y it is drawn in.
  def test_cotes_of_a_primitive_along_y
    response = _run(File.read(File.join(LIBRARY_DIR, 'connectors/lamello/cabineo/cabineo-8-flush.json')), topology: 'corner', thickness_a: 19, thickness_b: 19)
    mortise = response[:solids].find { |solid| solid[:kind] == 'mortises' }
    assert(mortise[:texts][:z] =~ /\A-13\D*\z/, mortise[:texts][:z])
    assert(mortise[:texts][:x] =~ /\A0\D*\z/, mortise[:texts][:x])
    assert_equal('y', mortise[:axis])   # As the descriptor gives it - not its length axis
    # The editor's row tells the same
    assert_equal(mortise[:texts], response[:slots]['a'][:component][:primitives][mortise[:part]]['mortises'][mortise[:index]][:texts])
    assert_in_delta(-13 * MM, mortise[:cotes][:position][2], 1e-9)
    # On its nearest end : a's reference face, 0,8 mm deep
    assert_in_delta(5 * MM, mortise[:cotes][:origin][1], 1e-9)
    assert_in_delta(5 * MM, mortise[:cotes][:position][1], 1e-9)
  end

  def test_axis_y_primitive_frame
    data = JSON.parse(JSON.generate(DOWEL))
    data['components']['b'] = { 'machining' => { 'drillings' => [ { 'axis' => 'y', 'z' => '-7mm', 'diameter' => '6mm', 'depth' => '5mm' } ] } }
    response = _run(data, topology: 'flat_edge', swapped: true, thickness_a: 19, thickness_b: 19)
    drilling = response[:solids].find { |solid| solid[:slot] == 'b' }
    # Slot b (Z reversed) then the frame along Y : [ x, y, z ] -> [ x, z, -y ]
    assert_equal([ 0, 0, 1 ], drilling[:transformation][4..6])
    assert_equal([ 0, 1, 0 ], drilling[:transformation][8..10])
  end

  def test_mirror_and_z_offset
    data = JSON.parse(JSON.generate(DOWEL))
    data['components']['a']['z_offset'] = '2mm'
    data['components']['b'] = { 'mirror_of' => 'a' }
    response = _run(data, topology: 'edge_edge', thickness_a: 19, thickness_b: 19)
    dowel_a = response[:solids].find { |solid| solid[:slot] == 'a' && solid[:part] == 'hardware' }
    dowel_b = response[:solids].find { |solid| solid[:slot] == 'b' && solid[:part] == 'hardware' }
    assert_in_delta(2 * MM, dowel_a[:transformation][14], 1e-9)
    assert(response[:slots]['b'][:component][:mirror])
    assert_equal(-1, dowel_b[:transformation][0])
    assert_in_delta(-2 * MM, dowel_b[:transformation][14], 1e-9)   # Z reversed
  end

  def test_invalid_input
    response = _run('{ "format": ')
    assert(!response[:supported])
    assert(response[:errors].first.start_with?('json:'))
    assert(!_run({ 'format' => 'other' })[:supported])
    span = _run(DOWEL.merge('type' => 'span'))
    assert(!span[:supported])
    assert_equal('span', span[:type])
    # An invalid descriptor is still shown : its errors with it
    response = _run(DOWEL.merge('id' => nil))
    assert(response[:supported])
    assert(response[:errors].any? { |error| error.include?('missing id') })
  end

  # A fitting sits in the inner corner : b's frame is a hinge's, Z out of
  # its face - toward the bench's -Y.
  def test_fitting
    response = _run(DOWEL.merge('type' => 'fitting'))
    assert(response[:supported])
    assert_equal('corner', response[:topology])
    assert_equal(%w[corner flat_edge], response[:topologies])
    assert(response[:swappable])
    b = response[:slots]['b'][:transformation]
    assert_equal([ 0, -1, 0 ], b[8..10])
  end

  def test_unknown_topology_falls_back
    assert_equal('corner', _run(DOWEL, topology: 'inset')[:topology])
  end

  # -----

  private

  def _run(descriptor, **params)
    HardwareBenchComputeWorker.new(descriptor: descriptor.is_a?(Hash) ? JSON.parse(JSON.generate(descriptor)) : descriptor, **params).run
  end

  def _variable(response, name)
    response[:variables].find { |variable| variable[:name] == name }
  end

end
