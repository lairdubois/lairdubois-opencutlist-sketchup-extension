require 'testup/testcase'
require 'json'
require 'tmpdir'

require_relative '../src/ladb_opencutlist/ruby/model/hardware/hardware_descriptor_def'

# The hardware descriptor of the asset library : validation, and the
# resolution of a slot's component - links, variants, parts, refs - for the
# measures a tool took. Nothing here reads the model.
class TC_Ladb_Model_HardwareDescriptorDef < TestUp::TestCase

  HardwareDescriptorDef = Ladb::OpenCutList::HardwareDescriptorDef

  HINGE = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'hinge-1', 'type' => 'hinge',
    'name' => 'Clip Top 110',
    'supplier' => 'Blum', 'url' => 'https://www.blum.com',
    'components' => {
      'a' => {
        'name' => 'Hinge', 'description' => 'Blum 71B3550', 'price' => 4.5,
        'variants' => {
          'select' => { 'by' => 'hinge_kind' },
          'fallback' => 'overlay',
          'items' => {
            'overlay' => { 'hardware' => '$LIB/hinge_0.skp', 'machining' => '$LIB/cup.skp' },
            'inset' => { 'name' => 'Inset hinge', 'price' => 4.9, 'hardware' => '$LIB/hinge_18.skp', 'machining' => '$LIB/cup.skp' },
            'half_overlay' => nil,
          }
        }
      },
      'b' => { 'name' => 'Plate', 'hardware' => './plate.skp', 'machining' => './plate_holes.skp' }
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

  CONVENTION = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'hinge-2', 'type' => 'hinge', 'name' => 'Clip Top',
    'components' => {
      'a' => {
        'variants' => {
          'select' => { 'by' => 'hinge_kind' },
          'fallback' => 'overlay',
          'items' => {
            'overlay' => { 'hardware' => true, 'machining' => true },
            'inset' => { 'hardware' => true, 'machining' => true },
          }
        }
      },
      'b' => { 'hardware' => true, 'machining' => false }
    }
  }.freeze

  # -- Validation --

  def test_valid_descriptors
    assert(_def(HINGE).valid?, _def(HINGE).errors.inspect)
    assert(_def(SLIDES).valid?, _def(SLIDES).errors.inspect)
    assert(_def(CONVENTION).valid?, _def(CONVENTION).errors.inspect)
  end

  def test_not_a_descriptor
    assert(!HardwareDescriptorDef.descriptor?({ 'format' => 'other' }))
    assert(!HardwareDescriptorDef.new({}).valid?)
  end

  def test_invalid_descriptors
    _assert_error(_with(HINGE, 'type' => 'drawer'), 'unknown type')
    _assert_error(_with(HINGE, 'version' => 2), 'unsupported version')
    _assert_error(_with(HINGE, 'id' => nil), 'missing id')
    _assert_error(_with(HINGE, 'components' => { 'main' => { 'hardware' => 'x.skp' } }), "unknown slot 'main'")
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
    assert_equal('a', component.slot)
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
    assert_equal('b', component.slot)
    assert_equal('a', component.source_slot)
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

  def test_empty_slot
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

  # -- Parts --

  def test_true_parts_follow_the_naming_convention_in_the_library
    descriptor = _def(CONVENTION, nil, '$OCL/hinges/blum/clip-top.json')
    assert_equal('$OCL/components/hinges/blum/clip-top', descriptor.components_dir_ref)
    component = descriptor.resolve_component('a', 'hinge_kind' => 'inset')
    assert_equal('$OCL/components/hinges/blum/clip-top/a.inset.skp', component.hardware)
    assert_equal('$OCL/components/hinges/blum/clip-top/a.inset.machining.skp', component.machining)
    assert_equal('$OCL/components/hinges/blum/clip-top/b.skp', descriptor.resolve_component('b').hardware)
    assert_nil(descriptor.resolve_component('b').machining)   # false
  end

  def test_true_parts_out_of_a_library
    descriptor = _def(CONVENTION, '/somewhere/clip-top.json')
    assert_equal('/somewhere/clip-top/b.skp', descriptor.resolve_component('b').hardware)
    assert_nil(_def(CONVENTION).resolve_component('b').hardware)   # No file, no folder
  end

  def test_shared_part_is_relative_to_the_components_folder
    data = _with(CONVENTION, 'components' => { 'a' => { 'hardware' => true, 'machining' => 'hinges/blum/cup-35.skp' } })
    assert_equal('$LIB/components/hinges/blum/cup-35.skp', _def(data, nil, '$LIB/hinges/blum/mine.json').resolve_component('a').machining)
    assert_equal('/somewhere/hinges/blum/cup-35.skp', _def(data, '/somewhere/mine.json').resolve_component('a').machining)
  end

  def test_part_same_as_takes_the_other_slot_part
    data = _with(CONVENTION, 'type' => 'connector', 'components' => {
      'a' => { 'name' => 'Domino', 'hardware' => true, 'machining' => true },
      'b' => { 'machining' => { 'same_as' => 'a' } }
    })
    descriptor = _def(data, nil, '$OCL/connectors/festool/domino-5x30.json')
    assert(descriptor.valid?, descriptor.errors.inspect)
    component = descriptor.resolve_component('b')
    assert_nil(component.hardware)
    assert_equal('$OCL/components/connectors/festool/domino-5x30/a.machining.skp', component.machining)
    assert_equal('b', component.source_slot)
    assert_equal({ 'hardware' => nil, 'machining' => 'a' }, component.part_slots)
    assert_nil(component.name)
  end

  def test_invalid_parts
    _assert_error(_with(CONVENTION, 'components' => { 'a' => { 'hardware' => false } }), 'neither hardware nor machining')
    _assert_error(_with(CONVENTION, 'components' => { 'a' => { 'hardware' => 3 } }), 'hardware is neither true, a path nor a link')
    _assert_error(_with(CONVENTION, 'components' => { 'a' => { 'hardware' => { 'holes' => [] } } }), 'hardware is neither true, a path nor a link')
    _assert_error(_with(CONVENTION, 'components' => { 'a' => { 'machining' => { 'same_as' => 'a' } } }), 'machining links to itself')
    _assert_error(_with(CONVENTION, 'components' => { 'a' => { 'machining' => { 'same_as' => 'z' } } }), 'machining links to unknown slot')
  end

  # -- Data --

  def test_root_data
    descriptor = _def(HINGE)
    assert_equal('Blum', descriptor.supplier)
    assert_equal('https://www.blum.com', descriptor.url)
    assert_equal(%w[a b], descriptor.slots)
  end

  def test_variant_data_over_component_data
    descriptor = _def(HINGE)
    overlay = descriptor.resolve_component('a', 'hinge_kind' => 'overlay')
    assert_equal('Hinge', overlay.name)
    assert_nil(overlay.variant_name)
    assert_equal('Blum 71B3550', overlay.description)
    assert_equal(4.5, overlay.price)
    inset = descriptor.resolve_component('a', 'hinge_kind' => 'inset')
    assert_equal('Hinge', inset.name)
    assert_equal('Inset hinge', inset.variant_name)
    assert_equal('Blum 71B3550', inset.description)
    assert_equal(4.9, inset.price)
    assert_equal('Plate', descriptor.resolve_component('b').name)
  end

  def test_data_follows_links
    data = JSON.parse(JSON.generate(SLIDES))
    data['components']['a']['name'] = 'Slide'
    data['components']['a']['mass'] = 0.4
    component = _def(data).resolve_component('b', 'depth' => 400.mm)
    assert_equal('Slide', component.name)
    assert_equal(0.4, component.mass)
  end

  def test_invalid_data
    _assert_error(_with(HINGE, 'supplier' => 3), 'supplier is not a string')
    data = JSON.parse(JSON.generate(HINGE))
    data['components']['b']['price'] = [ 1 ]
    _assert_error(data, "component 'b' price is neither a number nor a string")
    data['components']['b']['name'] = 1
    _assert_error(data, "component 'b' name is not a string")
    data = JSON.parse(JSON.generate(SLIDES))
    data['components']['b']['name'] = 'Left slide'
    _assert_error(data, "component 'b' links to another slot and has name")
  end

  def test_options
    descriptor = _def(HINGE)
    assert_equal('100mm', descriptor.option('start_offset'))
    assert_nil(descriptor.option('height'))
    assert_equal({}, _def(SLIDES).options)
  end

  def test_attributes_merge_variant_over_component
    data = JSON.parse(JSON.generate(HINGE))
    data['components']['a']['attributes'] = { 'role' => 'hinge', 'hinge_max_angle' => 110, 'hinge_pivot' => [ 0, 0 ] }
    data['components']['a']['variants']['items']['inset']['attributes'] = { 'hinge_pivot' => [ -4, -26 ] }
    descriptor = _def(data)
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal({ 'role' => 'hinge', 'hinge_max_angle' => 110, 'hinge_pivot' => [ -4, -26 ] }, descriptor.resolve_component('a', 'hinge_kind' => 'inset').attributes)
    assert_equal({ 'role' => 'hinge', 'hinge_max_angle' => 110, 'hinge_pivot' => [ 0, 0 ] }, descriptor.resolve_component('a', 'hinge_kind' => 'overlay').attributes)
    assert_equal({}, descriptor.resolve_component('b').attributes)
  end

  def test_attributes_follow_links
    data = JSON.parse(JSON.generate(SLIDES))
    data['components']['a']['attributes'] = { 'role' => 'slide' }
    assert_equal({ 'role' => 'slide' }, _def(data).resolve_component('b', 'depth' => 400.0 / 25.4).attributes)
  end

  def test_invalid_attributes
    data = JSON.parse(JSON.generate(HINGE))
    data['components']['b']['attributes'] = [ 'role' ]
    _assert_error(data, "component 'b' attributes is not an object")
    data['components']['b']['attributes'] = { 'hinge_pivot' => [ [ 1, 2 ] ], 'more' => { 'a' => 1 } }
    _assert_error(data, "attribute 'hinge_pivot' is neither")
    _assert_error(data, "attribute 'more' is neither")
    data = JSON.parse(JSON.generate(SLIDES))
    data['components']['b']['attributes'] = { 'role' => 'slide' }
    _assert_error(data, "component 'b' links to another slot and has attributes")
  end

  # -----

  private

  def _def(data, path = nil, ref = nil)
    HardwareDescriptorDef.new(JSON.parse(JSON.generate(data)), path, ref)
  end

  def _with(data, changes)
    data.merge(changes)
  end

  def _assert_error(data, message)
    errors = _def(data).errors
    assert(errors.any? { |error| error.include?(message) }, "expected '#{message}' in #{errors.inspect}")
  end

end
