require 'testup/testcase'
require 'json'
require 'tmpdir'

require_relative '../src/ladb_opencutlist/ruby/model/hardware/hardware_descriptor_def'

# The hardware descriptor of the asset library : validation, and the
# resolution of a role's component - links, variants, './' refs - for the
# measures a tool took. Nothing here reads the model.
class TC_Ladb_Model_HardwareDescriptorDef < TestUp::TestCase

  HardwareDescriptorDef = Ladb::OpenCutList::HardwareDescriptorDef

  HINGE = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'hinge-1', 'type' => 'hinge', 'category' => 'hinge',
    'name' => 'Clip Top 110',
    'meta' => {
      'items' => [
        { 'component' => 'a', 'name' => 'Hinge', 'quantity' => 1, 'unit_price' => 4.5 },
        { 'component' => 'a', 'name' => 'Screw', 'quantity' => 2, 'unit_price' => 0.1 },
        { 'component' => 'b', 'name' => 'Plate', 'quantity' => 1, 'unit_price' => 1.2 },
      ]
    },
    'components' => {
      'a' => {
        'variants' => {
          'select' => { 'by' => 'hinge_kind' },
          'fallback' => 'overlay',
          'items' => {
            'overlay' => { 'hardware' => '$LIB/hinge_0.skp', 'machining' => '$LIB/cup.skp' },
            'inset' => { 'hardware' => '$LIB/hinge_18.skp', 'machining' => '$LIB/cup.skp' },
            'half_overlay' => nil,
          }
        }
      },
      'b' => { 'hardware' => './plate.skp', 'machining' => './plate_holes.skp' }
    },
    'options' => { 'start_offset' => '100mm', 'end_offset' => '100mm' }
  }.freeze

  SLIDES = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'slides-1', 'type' => 'span', 'name' => 'Slides',
    'components' => {
      'a' => {
        'variants' => {
          'select' => { 'by' => 'depth', 'mode' => 'max_le' },
          'items' => {
            '300mm' => { 'hardware' => '$LIB/slide_300.skp' },
            '350mm' => { 'hardware' => '$LIB/slide_350.skp' },
            '400mm' => { 'hardware' => '$LIB/slide_400.skp' },
          }
        }
      },
      'b' => { 'mirror_of' => 'a' },
      'span' => nil
    }
  }.freeze

  # -- Validation --

  def test_valid_descriptors
    assert(_def(HINGE).valid?, _def(HINGE).errors.inspect)
    assert(_def(SLIDES).valid?, _def(SLIDES).errors.inspect)
  end

  def test_not_a_descriptor
    assert(!HardwareDescriptorDef.descriptor?({ 'format' => 'other' }))
    assert(!HardwareDescriptorDef.new({}).valid?)
  end

  def test_invalid_descriptors
    _assert_error(_with(HINGE, 'type' => 'drawer'), 'unknown type')
    _assert_error(_with(HINGE, 'version' => 2), 'unsupported version')
    _assert_error(_with(HINGE, 'id' => nil), 'missing id')
    _assert_error(_with(HINGE, 'components' => { 'main' => { 'hardware' => 'x.skp' } }), "unknown role 'main'")
    _assert_error(_with(HINGE, 'components' => { 'a' => { 'same_as' => 'a' } }), 'links to itself')
    _assert_error(_with(HINGE, 'components' => { 'a' => { 'hardware' => '' } }), 'neither hardware nor machining')
    _assert_error(_with(HINGE, 'components' => { 'a' => nil, 'b' => nil }), 'no component')
    _assert_error(_with(HINGE, 'options' => { 'height' => [ 1 ] }), 'is not a scalar')
  end

  def test_machining_only_component_is_valid
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'machining' => { 'holes' => [] } } }))
    assert(descriptor.valid?, descriptor.errors.inspect)
  end

  # -- Variants selected by key --

  def test_exact_variant
    component = _def(HINGE).resolve_component(:a, hinge_kind: 'inset')
    assert_equal('$LIB/hinge_18.skp', component.hardware)
    assert_equal('inset', component.variant)
    assert_equal('a', component.role)
  end

  def test_missing_variant_falls_back
    component = _def(HINGE).resolve_component('a', 'hinge_kind' => 'unknown')
    assert_equal('$LIB/hinge_0.skp', component.hardware)
    assert_equal('overlay', component.variant)
  end

  def test_no_measure_falls_back
    assert_equal('overlay', _def(HINGE).resolve_component('a').variant)
  end

  def test_null_variant_is_unsupported
    assert_nil(_def(HINGE).resolve_component('a', 'hinge_kind' => 'half_overlay'))
  end

  # -- Variants selected by length --

  def test_max_le_picks_the_largest_that_fits
    descriptor = _def(SLIDES)
    assert_equal('350mm', descriptor.resolve_component('a', 'depth' => 380.mm).variant)
    assert_equal('400mm', descriptor.resolve_component('a', 'depth' => 400.mm).variant)
    assert_equal('400mm', descriptor.resolve_component('a', 'depth' => 1000.mm).variant)
  end

  def test_max_le_none_fits
    assert_nil(_def(SLIDES).resolve_component('a', 'depth' => 250.mm))
  end

  def test_max_le_ratio
    handle = _with(SLIDES, 'type' => 'face', 'components' => {
      'main' => { 'variants' => { 'select' => { 'by' => 'width', 'mode' => 'max_le', 'ratio' => 0.6 },
                                  'items' => { '96mm' => { 'hardware' => 'h96.skp' }, '128mm' => { 'hardware' => 'h128.skp' } } } }
    })
    assert_equal('96mm', _def(handle).resolve_component('main', 'width' => 200.mm).variant)   # 120 mm available
    assert_equal('128mm', _def(handle).resolve_component('main', 'width' => 300.mm).variant)  # 180 mm available
  end

  # -- Links --

  def test_mirror_of
    component = _def(SLIDES).resolve_component('b', 'depth' => 360.mm)
    assert_equal('$LIB/slide_350.skp', component.hardware)
    assert_equal('b', component.role)
    assert(component.mirror)
  end

  def test_same_as_keeps_mirror_off
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => 'dowel.skp' }, 'b' => { 'same_as' => 'a' } }))
    component = descriptor.resolve_component('b')
    assert_equal('dowel.skp', component.hardware)
    assert(!component.mirror)
  end

  def test_link_cycle
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'same_as' => 'b' }, 'b' => { 'mirror_of' => 'a' } }))
    assert_nil(descriptor.resolve_component('a'))
  end

  def test_empty_role
    assert_nil(_def(SLIDES).resolve_component('span'))
  end

  # -- Refs --

  def test_relative_refs_follow_the_descriptor
    component = _def(HINGE, '/lib/hardware/blum/cliptop.json').resolve_component('b')
    assert_equal('/lib/hardware/blum/plate.skp', component.hardware)
    assert_equal('/lib/hardware/blum/plate_holes.skp', component.machining)
  end

  def test_primitive_machining_is_kept
    holes = { 'holes' => [ { 'x' => '0', 'y' => '0', 'diameter' => '5mm', 'depth' => 'through' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => 'h.skp', 'machining' => holes } }))
    assert_equal(holes, descriptor.resolve_component('a').machining)
  end

  def test_load
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'hinge.json')
      File.write(path, JSON.generate(HINGE))
      descriptor = HardwareDescriptorDef.load(path)
      assert(descriptor.valid?)
      assert_equal(File.join(dir, 'plate.skp'), descriptor.resolve_component('b').hardware)

      File.write(path, '{ not json')
      assert_nil(HardwareDescriptorDef.load(path))
      File.write(path, '{ "format": "other" }')
      assert_nil(HardwareDescriptorDef.load(path))
    end
    assert_nil(HardwareDescriptorDef.load('/nowhere.json'))
  end

  # -- Data --

  def test_unit_price_per_component
    descriptor = _def(HINGE)
    assert_in_delta(4.7, descriptor.unit_price('a'), 1e-9)
    assert_in_delta(1.2, descriptor.unit_price(:b), 1e-9)
    assert_nil(_def(SLIDES).unit_price('a'))
  end

  def test_options
    descriptor = _def(HINGE)
    assert_equal('100mm', descriptor.option('start_offset'))
    assert_nil(descriptor.option('height'))
    assert_equal({}, _def(SLIDES).options)
  end

  # -----

  private

  def _def(data, path = nil)
    HardwareDescriptorDef.new(JSON.parse(JSON.generate(data)), path)
  end

  def _with(data, changes)
    data.merge(changes)
  end

  def _assert_error(data, message)
    errors = _def(data).errors
    assert(errors.any? { |error| error.include?(message) }, "expected '#{message}' in #{errors.inspect}")
  end

end
