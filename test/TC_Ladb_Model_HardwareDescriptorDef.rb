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
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'machining' => { 'drillings' => [ { 'diameter' => '5mm', 'depth' => '12mm' } ] } } }))
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
    drillings = { 'drillings' => [ { 'x' => '0', 'y' => '0', 'diameter' => '5mm', 'depth' => 'through' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => 'h.skp', 'machining' => drillings } }))
    assert_equal(drillings, descriptor.resolve_component('a').machining)
  end

  # -- Machining primitives --

  def test_drillings
    machining = { 'drillings' => [
      { 'x' => '-64mm', 'y' => 0, 'diameter' => '5mm', 'depth' => 'through' },
      { 'x' => 64, 'diameter' => 8, 'depth' => '18mm' },
    ] }
    assert_equal([ 'thickness' ], HardwareDescriptorDef.primitive_variables(machining))
    drillings = HardwareDescriptorDef.primitive_cylinders(machining, 'thickness' => 19 / 25.4)
    assert_equal(2, drillings.length)
    assert_in_delta(-64 / 25.4, drillings[0].x, 1e-9)
    assert_in_delta(0.0, drillings[0].y, 1e-9)
    assert_in_delta(5 / 25.4, drillings[0].diameter, 1e-9)
    assert_in_delta(-19 / 25.4, drillings[0].z_min, 1e-9)
    assert_in_delta(0.0, drillings[0].z_max, 1e-9)
    assert_in_delta(64 / 25.4, drillings[1].x, 1e-9)
    assert_in_delta(8 / 25.4, drillings[1].diameter, 1e-9)
    assert_in_delta(-18 / 25.4, drillings[1].z_min, 1e-9)
    assert_equal(1, HardwareDescriptorDef.primitive_cylinders(machining).length)  # No thickness : the through one is left out
    assert_nil(HardwareDescriptorDef.primitive_cylinders('$LIB/cup.skp'))
    assert_nil(HardwareDescriptorDef.primitive_cylinders(nil))
  end

  # -- Length expressions --

  def test_length_expressions
    v = { 'thickness' => 19 / 25.4 }
    fn = lambda { |expression, negative_allowed = true| HardwareDescriptorDef.to_length(expression, negative_allowed, v) }
    assert_in_delta(19 / 25.4, fn.call('@thickness'), 1e-9)
    assert_in_delta(17 / 25.4, fn.call('@thickness - 2mm'), 1e-9)
    assert_in_delta(17 / 25.4, fn.call('@thickness-2mm'), 1e-9)
    assert_in_delta(9.5 / 25.4, fn.call('@thickness / 2'), 1e-9)
    assert_in_delta(9.5 / 25.4, fn.call('0.5 * @thickness'), 1e-9)
    assert_in_delta(9.5 / 25.4, fn.call('0,5*@thickness'), 1e-9)
    assert_in_delta(-19 / 25.4, fn.call('-@thickness'), 1e-9)
    assert_in_delta(-9 / 25.4, fn.call('-(@thickness - 1cm)'), 1e-9)
    assert_in_delta(19 / 25.4 + 1, fn.call('@thickness + 1"'), 1e-9)
    assert_nil(fn.call('@thickness + 1in'))        # SketchUp reads no 'in'
    assert_in_delta(19 / 25.4 + 18, fn.call("@thickness + 1' 6\""), 1e-9)
    assert_in_delta(19 / 25.4 + 0.75, fn.call('@thickness + 3/4"'), 1e-9)
    assert_in_delta(19 / 25.4 / 4 * 10, fn.call('@thickness * 10/4'), 1e-9)
    assert_in_delta(19 / 25.4 + 12, fn.call("@thickness + 1'"), 1e-9)
    assert_nil(fn.call('@thickness + 2'))          # A length plus a factor
    assert_nil(fn.call('@thickness * @thickness')) # An area
    assert_nil(fn.call('@thickness / 1mm'))        # A factor
    assert_nil(fn.call('@thickness / 0'))
    assert_nil(fn.call('@thickness - '))
    assert_nil(fn.call('(@thickness'))
    assert_nil(fn.call('@thickness; exit'))
    assert_nil(fn.call('@depth'))                  # Not given
    assert_nil(fn.call('2mm - @thickness', false)) # Negative
    assert_nil(HardwareDescriptorDef.to_length('@thickness'))  # No variables
  end

  def test_expressions_in_primitives
    hardware = { 'cylinders' => [ { 'diameter' => '@thickness / 2', 'from' => '-@thickness', 'to' => '5mm' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => hardware } }))
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal([ 'thickness' ], HardwareDescriptorDef.primitive_variables(hardware))
    cylinders = HardwareDescriptorDef.primitive_cylinders(hardware, 'thickness' => 20 / 25.4)
    assert_in_delta(10 / 25.4, cylinders[0].diameter, 1e-9)
    assert_in_delta(-20 / 25.4, cylinders[0].z_min, 1e-9)
    assert_in_delta(5 / 25.4, cylinders[0].z_max, 1e-9)
    fn = lambda { |cylinder| _with(HINGE, 'components' => { 'a' => { 'hardware' => { 'cylinders' => [ cylinder ] } } }) }
    _assert_error(fn.call({ 'diameter' => 8, 'from' => '-@depth', 'to' => 5 }), 'cylinder 1 from uses the unknown variable @depth')
    _assert_error(fn.call({ 'diameter' => 8, 'from' => '-@thickness +', 'to' => 5 }), 'cylinder 1 from is not a length')
    _assert_error(fn.call({ 'diameter' => '@thickness * 2 - 1m', 'from' => 0, 'to' => 5 }), 'cylinder 1 diameter is not a positive length')
    descriptor = _def(fn.call({ 'diameter' => 8, 'from' => '@thickness', 'to' => 5 }))
    assert(descriptor.valid?, descriptor.errors.inspect)  # Depends on where it is laid
  end

  def test_drillings_follow_links
    machining = { 'drillings' => [ { 'diameter' => '5mm', 'depth' => '12mm' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => 'h.skp', 'machining' => machining }, 'b' => { 'machining' => { 'same_as' => 'a' } } }))
    assert(descriptor.valid?, descriptor.errors.inspect)
    component = descriptor.resolve_component('b')
    assert_equal(machining, component.machining)
    assert_equal('a', component.part_slots['machining'])
  end

  def test_invalid_drillings
    fn = lambda { |machining| _with(HINGE, 'components' => { 'a' => { 'machining' => machining } }) }
    _assert_error(fn.call({ 'holes' => [] }), "machining has an unknown primitive 'holes'")
    _assert_error(fn.call({ 'cylinders' => [ { 'diameter' => '8mm', 'from' => 0, 'to' => 5 } ] }), "machining has an unknown primitive 'cylinders'")
    _assert_error(fn.call({ 'drillings' => [] }), 'machining drillings is not a list of drillings')
    _assert_error(fn.call({ 'drillings' => [ 'x' ] }), 'drilling 1 is not an object')
    _assert_error(fn.call({ 'drillings' => [ { 'depth' => '5mm' } ] }), 'drilling 1 diameter is not a positive length')
    _assert_error(fn.call({ 'drillings' => [ { 'diameter' => '-5mm', 'depth' => '5mm' } ] }), 'drilling 1 diameter is not a positive length')
    _assert_error(fn.call({ 'drillings' => [ { 'diameter' => '5mm' } ] }), 'drilling 1 depth is neither "through" nor a positive length')
    _assert_error(fn.call({ 'drillings' => [ { 'diameter' => '5mm', 'depth' => 'deep' } ] }), 'drilling 1 depth is neither')
    _assert_error(fn.call({ 'drillings' => [ { 'x' => [ 1 ], 'diameter' => '5mm', 'depth' => '5mm' } ] }), 'drilling 1 x is not a length')
    _assert_error(fn.call({ 'drillings' => [ { 'diameter' => '5mm', 'depth' => '5mm', 'angle' => 90 } ] }), "drilling 1 has an unknown key 'angle'")
    _assert_error(fn.call({ 'drillings' => [ { 'diameter' => '5mm', 'depth' => '5mm', 'segments' => 12 } ] }), "drilling 1 has an unknown key 'segments'")
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
    _assert_error(_with(CONVENTION, 'components' => { 'a' => { 'hardware' => { 'holes' => [] } } }), "hardware has an unknown primitive 'holes'")
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

  def test_cylinders
    hardware = { 'cylinders' => [ { 'diameter' => '8mm', 'from' => '-20mm', 'to' => 20 }, { 'x' => '10mm', 'y' => -5, 'diameter' => 4, 'from' => 0, 'to' => '3mm' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => hardware } }))
    assert(descriptor.valid?, descriptor.errors.inspect)
    component = descriptor.resolve_component('a')
    assert_equal(hardware, component.hardware)
    assert_equal('a', component.part_slots['hardware'])
    assert_equal([], HardwareDescriptorDef.primitive_variables(hardware))
    cylinders = HardwareDescriptorDef.primitive_cylinders(component.hardware)
    assert_equal(2, cylinders.length)
    assert_in_delta(0.0, cylinders[0].x, 1e-9)
    assert_in_delta(8 / 25.4, cylinders[0].diameter, 1e-9)
    assert_in_delta(-20 / 25.4, cylinders[0].z_min, 1e-9)
    assert_in_delta(20 / 25.4, cylinders[0].z_max, 1e-9)
    assert_in_delta(10 / 25.4, cylinders[1].x, 1e-9)
    assert_in_delta(-5 / 25.4, cylinders[1].y, 1e-9)
    assert_in_delta(0.0, cylinders[1].z_min, 1e-9)
    assert_nil(HardwareDescriptorDef.primitive_cylinders('$LIB/dowel.skp'))
  end

  def test_invalid_cylinders
    fn = lambda { |hardware| _with(HINGE, 'components' => { 'a' => { 'hardware' => hardware } }) }
    _assert_error(fn.call({}), "component 'a' hardware is neither true, a path nor a link")
    _assert_error(fn.call({ 'drillings' => [ { 'diameter' => '5mm', 'depth' => '5mm' } ] }), "hardware has an unknown primitive 'drillings'")
    _assert_error(fn.call({ 'cylinders' => [] }), 'hardware cylinders is not a list of cylinders')
    _assert_error(fn.call({ 'cylinders' => [ 1 ] }), 'cylinder 1 is not an object')
    _assert_error(fn.call({ 'cylinders' => [ { 'from' => 0, 'to' => 5 } ] }), 'cylinder 1 diameter is not a positive length')
    _assert_error(fn.call({ 'cylinders' => [ { 'diameter' => 8, 'to' => 5 } ] }), 'cylinder 1 from is not a length')
    _assert_error(fn.call({ 'cylinders' => [ { 'diameter' => 8, 'from' => 0 } ] }), 'cylinder 1 to is not a length')
    _assert_error(fn.call({ 'cylinders' => [ { 'diameter' => 8, 'from' => '5mm', 'to' => '5mm' } ] }), 'cylinder 1 to is not above from')
    _assert_error(fn.call({ 'cylinders' => [ { 'diameter' => 8, 'from' => 0, 'to' => 5, 'depth' => 3 } ] }), "cylinder 1 has an unknown key 'depth'")
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
