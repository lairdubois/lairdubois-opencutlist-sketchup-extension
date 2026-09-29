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
    _assert_error(_with(HINGE, 'components' => { 'c' => { 'hardware' => 'x.skp' } }), "unknown slot 'c'")
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
      'a' => { 'variants' => { 'select' => { 'by' => 'width', 'mode' => 'max_le', 'ratio' => 0.6 },
                                  'items' => { '96mm' => { 'hardware' => 'h96.skp' }, '128mm' => { 'hardware' => 'h128.skp' } } } }
    })
    assert_equal('96mm', _def(handle).resolve_component('a', 'width' => 200.mm).variant)   # 120 mm available
    assert_equal('128mm', _def(handle).resolve_component('a', 'width' => 300.mm).variant)  # 180 mm available
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
    assert_equal([ 'thickness_max' ], HardwareDescriptorDef.primitive_variables(machining))
    drillings = HardwareDescriptorDef.primitive_cylinders(machining, 'thickness' => 19 / 25.4)   # No thickness_max : through is thickness
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
    assert_in_delta(-17 / 25.4, HardwareDescriptorDef.primitive_cylinders(machining, 'thickness' => 19 / 25.4, 'thickness_max' => 17 / 25.4)[0].z_min, 1e-9)
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

  # A dowel between a panel lying flat - drilled in its face, no deeper than
  # its thickness - and one on edge : the dowel shifts toward the edge.
  DOWEL = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'dowel-1', 'type' => 'connector', 'name' => 'Dowel 8x40',
    'variables' => {
      'depth_a' => 'min(@thickness_a - 5mm; max(20mm; 40mm - (@thickness_b - 5mm)))',
      'depth_b' => '40mm - @depth_a',
    },
    'asserts' => [ '@depth_a <= @thickness_a - 5mm', '@depth_b <= @thickness_b - 5mm' ],
    'components' => {
      'a' => {
        'hardware' => { 'cylinders' => [ { 'diameter' => '8mm', 'from' => '-@depth_a', 'to' => '@depth_b' } ] },
        'machining' => { 'drillings' => [ { 'diameter' => '8mm', 'depth' => '@depth_a + 1mm' } ] }
      },
      'b' => { 'machining' => { 'drillings' => [ { 'diameter' => '8mm', 'depth' => '@depth_b + 1mm' } ] } }
    }
  }.freeze

  def test_measures
    assert_equal(%w[thickness thickness_min thickness_max height thickness_a thickness_b thickness_min_a thickness_min_b thickness_max_a thickness_max_b height_a height_b], _def(DOWEL).measures)
    assert_equal(%w[thickness thickness_min thickness_max height], _def(SLIDES).measures)
    assert_equal(%w[thickness_a thickness_b], _def(DOWEL).used_measures)
    assert_equal([], _def(HINGE).used_measures)
    through = _with(HINGE, 'components' => { 'a' => { 'machining' => { 'drillings' => [ { 'diameter' => 5, 'depth' => 'through' } ] } } })
    assert_equal(%w[thickness_max], _def(through).used_measures)
  end

  def test_variables_and_asserts
    descriptor = _def(DOWEL)
    assert(descriptor.valid?, descriptor.errors.inspect)
    mm = lambda { |v| v / 25.4 }
    {
      [ 300, 300 ] => [ 20, 20, [] ],     # Both on edge : centered
      [ 19, 300 ] => [ 14, 26, [] ],      # a flat
      [ 300, 19 ] => [ 26, 14, [] ],      # b flat
      [ 19, 19 ] => [ 14, 26, [ '@depth_b <= @thickness_b - 5mm' ] ],  # Both flat : no room
    }.each do |(ta, tb), (da, db, failed)|
      variables = descriptor.resolve_variables('thickness_a' => mm.call(ta), 'thickness_b' => mm.call(tb))
      assert_in_delta(mm.call(da), variables['depth_a'], 1e-9, "#{ta}/#{tb}")
      assert_in_delta(mm.call(db), variables['depth_b'], 1e-9, "#{ta}/#{tb}")
      assert_equal(failed, descriptor.failed_asserts(variables), "#{ta}/#{tb}")
      cylinder = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').hardware, variables).first
      assert_in_delta(mm.call(-da), cylinder.z_min, 1e-9)
      assert_in_delta(mm.call(db), cylinder.z_max, 1e-9)
      drilling = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('b').machining, variables).first
      assert_in_delta(mm.call(-db - 1), drilling.z_min, 1e-9)
    end
    # Measures missing : nothing resolves, every assert fails
    variables = descriptor.resolve_variables({})
    assert(!variables.key?('depth_a'))
    assert_equal(2, descriptor.failed_asserts(variables).length)
  end

  def test_asserts
    variables = { 'thickness' => 19 / 25.4 }
    assert_equal(true, HardwareDescriptorDef.assert?('@thickness <= 19mm', variables))
    assert_equal(false, HardwareDescriptorDef.assert?('@thickness < 19mm', variables))
    assert_equal(true, HardwareDescriptorDef.assert?('@thickness >= 1.9cm', variables))
    assert_equal(true, HardwareDescriptorDef.assert?('@thickness = 19mm', variables))
    assert_equal(true, HardwareDescriptorDef.assert?('@thickness > 18mm', variables))
    assert_equal(true, HardwareDescriptorDef.assert?('min(@thickness; 10mm) = 10mm', variables))
    assert_nil(HardwareDescriptorDef.assert?('@thickness', variables))
    assert_nil(HardwareDescriptorDef.assert?('@depth <= 2mm', variables))
    assert_nil(HardwareDescriptorDef.assert?('@thickness <= @thickness * @thickness', variables))
  end

  def test_invalid_variables_and_asserts
    _assert_error(_with(DOWEL, 'variables' => [ 'x' ]), 'variables is not an object')
    _assert_error(_with(DOWEL, 'variables' => { 'a b' => '2mm' }), "variable 'a b' is not a valid name")
    _assert_error(_with(DOWEL, 'variables' => { 'thickness_a' => '2mm' }), "variable 'thickness_a' is a measure")
    _assert_error(_with(DOWEL, 'variables' => { 'x' => true }), "variable 'x' is not a length")
    _assert_error(_with(DOWEL, 'variables' => { 'x' => '@thickness + 2' }), "variable 'x' is not a length")
    _assert_error(_with(DOWEL, 'variables' => { 'x' => '@y', 'y' => '2mm' }), "variable 'x' uses the unknown variable @y")
    _assert_error(_with(DOWEL, 'variables' => {}), "cylinder 1 from uses the unknown variable @depth_a")
    _assert_error(_with(DOWEL, 'asserts' => '@depth_a <= 2mm'), 'asserts is not a list')
    _assert_error(_with(DOWEL, 'asserts' => [ '@depth_a' ]), 'assert 1 is not a comparison')
    _assert_error(_with(DOWEL, 'asserts' => [ '2mm <= @nope' ]), 'assert 1 uses the unknown variable @nope')
    _assert_error(_with(DOWEL, 'asserts' => [ '@depth_a <= @depth_a * @depth_a' ]), 'assert 1 is not a comparison of lengths')
    _assert_error(_with(SLIDES, 'variables' => { 'x' => '@thickness_a' }), "variable 'x' uses the unknown variable @thickness_a")
  end

  def test_z_offset
    data = JSON.parse(JSON.generate(DOWEL))
    data['components']['a']['hardware'] = '$LIB/fluted_dowel.skp'
    data['components']['a']['z_offset'] = '(@depth_b - @depth_a) / 2'
    descriptor = _def(data)
    assert(descriptor.valid?, descriptor.errors.inspect)
    component = descriptor.resolve_component('a')
    assert_equal('(@depth_b - @depth_a) / 2', component.z_offset)
    assert_nil(descriptor.resolve_component('b').z_offset)
    variables = descriptor.resolve_variables('thickness_a' => 19 / 25.4, 'thickness_b' => 300 / 25.4)
    assert_in_delta(6 / 25.4, HardwareDescriptorDef.to_length(component.z_offset, true, variables), 1e-9)
    # Variant over the component holding the variants, and links follow
    variants = _with(HINGE, 'components' => {
      'a' => { 'z_offset' => '2mm', 'variants' => { 'select' => { 'by' => 'hinge_kind' }, 'items' => {
        'overlay' => { 'hardware' => '$LIB/h.skp' },
        'inset' => { 'hardware' => '$LIB/h.skp', 'z_offset' => -3 } } } },
      'b' => { 'mirror_of' => 'a' } })
    descriptor = _def(variants)
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal('2mm', descriptor.resolve_component('a', 'hinge_kind' => 'overlay').z_offset)
    assert_equal(-3, descriptor.resolve_component('a', 'hinge_kind' => 'inset').z_offset)
    assert_equal('2mm', descriptor.resolve_component('b', 'hinge_kind' => 'overlay').z_offset)
  end

  def test_invalid_z_offset
    fn = lambda { |z_offset| _with(DOWEL, 'components' => DOWEL['components'].merge('a' => DOWEL['components']['a'].merge('z_offset' => z_offset))) }
    _assert_error(fn.call(true), "component 'a' z_offset is not a length")
    _assert_error(fn.call('@depth_a * @depth_a'), "component 'a' z_offset is not a length")
    _assert_error(fn.call('@nope'), "component 'a' z_offset uses the unknown variable @nope")
    _assert_error(_with(DOWEL, 'components' => DOWEL['components'].merge('b' => { 'mirror_of' => 'a', 'z_offset' => '2mm' })), "component 'b' links to another slot and has z_offset")
  end

  def test_oblongs_and_mortises
    hardware = { 'oblongs' => [ { 'length' => '19mm', 'width' => '5mm', 'from' => '-15mm', 'to' => '15mm' } ] }
    machining = { 'mortises' => [ { 'x' => '2mm', 'length' => '19mm', 'width' => '5mm', 'depth' => 'through' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'hardware' => hardware, 'machining' => machining } }))
    assert(descriptor.valid?, descriptor.errors.inspect)
    oblong = HardwareDescriptorDef.primitive_cylinders(hardware).first
    assert(!oblong.round?)
    assert_in_delta(19 / 25.4, oblong.length, 1e-9)
    assert_in_delta(5 / 25.4, oblong.diameter, 1e-9)
    assert_in_delta(-15 / 25.4, oblong.z_min, 1e-9)
    mortise = HardwareDescriptorDef.primitive_cylinders(machining, 'thickness' => 19 / 25.4).first
    assert_in_delta(2 / 25.4, mortise.x, 1e-9)
    assert_in_delta(-19 / 25.4, mortise.z_min, 1e-9)
    assert_equal([ 'thickness_max' ], HardwareDescriptorDef.primitive_variables(machining))
    # As long as wide : a cylinder
    assert(HardwareDescriptorDef.primitive_cylinders({ 'oblongs' => [ { 'length' => 5, 'width' => 5, 'from' => 0, 'to' => 1 } ] }).first.round?)
  end

  def test_invalid_oblongs_and_mortises
    fn = lambda { |part, value| _with(HINGE, 'components' => { 'a' => { part => value } }) }
    _assert_error(fn.call('hardware', { 'mortises' => [] }), "hardware has an unknown primitive 'mortises'")
    _assert_error(fn.call('machining', { 'oblongs' => [] }), "machining has an unknown primitive 'oblongs'")
    _assert_error(fn.call('hardware', { 'oblongs' => [ { 'width' => 5, 'from' => 0, 'to' => 1 } ] }), 'oblong 1 length is not a positive length')
    _assert_error(fn.call('hardware', { 'oblongs' => [ { 'length' => 4, 'width' => 5, 'from' => 0, 'to' => 1 } ] }), 'oblong 1 length is below its width')
    _assert_error(fn.call('hardware', { 'oblongs' => [ { 'length' => 5, 'width' => 5, 'diameter' => 5, 'from' => 0, 'to' => 1 } ] }), "oblong 1 has an unknown key 'diameter'")
    _assert_error(fn.call('machining', { 'mortises' => [ { 'length' => 19, 'width' => 5 } ] }), 'mortise 1 depth is neither "through" nor a positive length')
  end

  # The bundled Dominos : depths on the steps of the machine - 12, 15, 20,
  # 25, 28 mm - the tenon shifted toward the deeper mortise.
  def test_heads
    mm = lambda { |v| v / 25.4 }
    fn_profile = lambda { |cylinder| cylinder.profile.map { |r, z| [ (r * 25.4).round(6), (z * 25.4).round(6) ] } }
    machining = { 'drillings' => [
      { 'diameter' => '4mm', 'depth' => 'through', 'countersink' => { 'diameter' => '8mm', 'face' => 'opposite' } },
      { 'diameter' => '4mm', 'depth' => '10mm', 'countersink' => { 'diameter' => '8mm', 'angle' => 90 } },
      { 'diameter' => '4mm', 'depth' => '10mm', 'counterbore' => { 'diameter' => '10mm', 'depth' => '3mm', 'face' => 'contact' } },
      { 'diameter' => '4mm', 'depth' => 'through', 'counterbore' => { 'diameter' => '10mm', 'depth' => '3mm', 'face' => 'opposite' } },
      { 'diameter' => '4mm', 'depth' => '1mm', 'countersink' => { 'diameter' => '8mm' } },   # Deeper than the drilling : left out
    ] }
    drillings = HardwareDescriptorDef.primitive_cylinders(machining, 'thickness_max' => mm.call(19))
    assert_equal(4, drillings.length)
    assert_equal([ [ 2, 0 ], [ 2, -17 ], [ 4, -19 ] ], fn_profile.call(drillings[0]))
    assert_equal([ [ 4, 0 ], [ 2, -2 ], [ 2, -10 ] ], fn_profile.call(drillings[1]))
    assert_equal([ [ 5, 0 ], [ 5, -3 ], [ 2, -3 ], [ 2, -10 ] ], fn_profile.call(drillings[2]))
    assert_equal([ [ 2, 0 ], [ 2, -16 ], [ 5, -16 ], [ 5, -19 ] ], fn_profile.call(drillings[3]))
    assert_in_delta(mm.call(5), drillings[3].radius, 1e-9)
    assert_in_delta(mm.call(2), HardwareDescriptorDef.primitive_cylinders({ 'drillings' => [ { 'diameter' => 4, 'depth' => 5 } ] }).first.radius, 1e-9)
    # A countersink of 60° is deeper
    sharp = HardwareDescriptorDef.primitive_cylinders({ 'drillings' => [ { 'diameter' => 4, 'depth' => 10, 'countersink' => { 'diameter' => 8, 'angle' => 60 } } ] }).first
    assert_in_delta(-mm.call(2 * Math.sqrt(3)), sharp.profile[1][1], 1e-9)
    # A countersunk screw, its head at the from end
    screw = HardwareDescriptorDef.primitive_cylinders({ 'cylinders' => [ { 'diameter' => 4, 'from' => -19, 'to' => 21, 'countersink' => { 'diameter' => 8, 'end' => 'from' } } ] }).first
    assert_equal([ [ 2, 21 ], [ 2, -17 ], [ 4, -19 ] ], fn_profile.call(screw))
    # Its variables
    assert_equal(%w[thickness_max head], HardwareDescriptorDef.primitive_variables({ 'drillings' => [ { 'diameter' => 4, 'depth' => 'through', 'counterbore' => { 'diameter' => '@head', 'depth' => 2 } } ] }))
  end

  # Along Y : from the face +Y leads to - @height away - toward -Y, placed
  # by x and z, given turned a quarter around X.
  def test_axis_y
    mm = lambda { |v| v / 25.4 }
    machining = { 'drillings' => [
      { 'axis' => 'y', 'x' => '3mm', 'z' => '-7mm', 'diameter' => '6mm', 'depth' => '@height + 2mm' },
      { 'axis' => 'z', 'diameter' => '4mm', 'depth' => '10mm' },
    ], 'mortises' => [ { 'axis' => 'y', 'z' => '-4mm', 'length' => '20mm', 'width' => '5mm', 'depth' => '8mm' } ] }
    descriptor = _def(_with(HINGE, 'components' => { 'a' => { 'machining' => machining } }))
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal(%w[height], descriptor.used_measures)
    assert_equal(%w[height], HardwareDescriptorDef.primitive_variables(machining))
    drilling, plain, mortise = HardwareDescriptorDef.primitive_cylinders(machining, 'height' => mm.call(10))
    assert_equal('y', drilling.axis)
    assert_in_delta(mm.call(3), drilling.x, 1e-9)
    assert_in_delta(mm.call(7), drilling.y, 1e-9)      # [ x, y, z ] -> [ x, z, -y ]
    assert_in_delta(mm.call(10), drilling.z_max, 1e-9)  # The face, @height away
    assert_in_delta(mm.call(-2), drilling.z_min, 1e-9)
    assert_nil(plain.axis)
    assert_in_delta(mm.call(-10), plain.z_min, 1e-9)
    assert_equal('y', mortise.axis)
    assert_in_delta(mm.call(20), mortise.length, 1e-9)
    assert_in_delta(mm.call(2), mortise.z_min, 1e-9)
    # No height measured : left out
    assert_equal(1, HardwareDescriptorDef.primitive_cylinders(machining).length)
    # A head on its face
    head = HardwareDescriptorDef.primitive_cylinders({ 'drillings' => [ { 'axis' => 'y', 'diameter' => 4, 'depth' => 12, 'countersink' => { 'diameter' => 8 } } ] }, 'height' => mm.call(10)).first
    assert_equal([ [ 4, 10 ], [ 2, 8 ], [ 2, -2 ] ], head.profile.map { |r, z| [ (r * 25.4).round(6), (z * 25.4).round(6) ] })
    # A mortise whose length goes along Z : [ x, y, z ] -> [ -y, z, -x ]
    recess = { 'mortises' => [ { 'axis' => 'y', 'length_axis' => 'z', 'x' => '2mm', 'z' => '-13mm', 'length' => '42.7mm', 'width' => '16.7mm', 'depth' => '0.8mm' } ] }
    assert(_def(_with(HINGE, 'components' => { 'a' => { 'machining' => recess } })).valid?)
    assert_equal(%w[height], HardwareDescriptorDef.primitive_variables(recess))
    mortise = HardwareDescriptorDef.primitive_cylinders(recess, 'height' => mm.call(5.8)).first
    assert_equal(HardwareDescriptorDef::AXIS_Y_LENGTH_Z, mortise.axis)
    assert_in_delta(mm.call(13), mortise.x, 1e-9)
    assert_in_delta(mm.call(-2), mortise.y, 1e-9)
    assert_in_delta(mm.call(42.7), mortise.length, 1e-9)
    assert_in_delta(mm.call(5), mortise.z_min, 1e-9)
    # Along X, as without it
    along_x = HardwareDescriptorDef.primitive_cylinders({ 'mortises' => [ recess['mortises'].first.merge('length_axis' => 'x') ] }, 'height' => mm.call(5.8)).first
    assert_equal('y', along_x.axis)
    assert_in_delta(mm.call(2), along_x.x, 1e-9)
    assert_in_delta(mm.call(13), along_x.y, 1e-9)
  end

  def test_invalid_axis_y
    fn = lambda { |part, value| _with(HINGE, 'components' => { 'a' => { part => value } }) }
    fn_drilling = lambda { |item| fn.call('machining', { 'drillings' => [ { 'diameter' => 6, 'depth' => 10 }.merge(item) ] }) }
    _assert_error(fn_drilling.call('axis' => 'x'), 'drilling 1 axis is neither "z" nor "y"')
    _assert_error(fn_drilling.call('axis' => 'y', 'y' => 2), 'drilling 1 is along Y and has a y - it is placed by x and z')
    _assert_error(fn_drilling.call('axis' => 'y', 'depth' => 'through'), 'drilling 1 is along Y and through')
    _assert_error(fn_drilling.call('z' => -7), "drilling 1 has a z but isn't along Y")
    _assert_error(fn_drilling.call('axis' => 'y', 'z' => 'deep'), 'drilling 1 z is not a length')
    _assert_error(fn.call('machining', { 'mortises' => [ { 'axis' => 'y', 'length' => 19, 'width' => 5, 'depth' => 'through' } ] }), 'mortise 1 is along Y and through')
    _assert_error(fn.call('hardware', { 'cylinders' => [ { 'axis' => 'y', 'diameter' => 4, 'from' => 0, 'to' => 30 } ] }), "cylinder 1 has an unknown key 'axis'")
    fn_mortise = lambda { |item| fn.call('machining', { 'mortises' => [ { 'length' => 19, 'width' => 5, 'depth' => 10 }.merge(item) ] }) }
    _assert_error(fn_mortise.call('axis' => 'y', 'length_axis' => 'y'), 'mortise 1 length_axis is neither "x" nor "z"')
    _assert_error(fn_mortise.call('length_axis' => 'z'), "mortise 1 has a length_axis but isn't along Y")
    _assert_error(fn_drilling.call('axis' => 'y', 'length_axis' => 'z'), "drilling 1 has an unknown key 'length_axis'")
  end

  def test_invalid_heads
    fn = lambda { |part, value| _with(HINGE, 'components' => { 'a' => { part => value } }) }
    fn_drilling = lambda { |head| fn.call('machining', { 'drillings' => [ { 'diameter' => 4, 'depth' => 10 }.merge(head) ] }) }
    _assert_error(fn_drilling.call('countersink' => 8), 'drilling 1 countersink is not an object')
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => 8 }, 'counterbore' => { 'diameter' => 8, 'depth' => 2 }), 'drilling 1 has both countersink and counterbore')
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => 3 }), 'drilling 1 countersink diameter is not above the one of the drilling')
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => 8, 'angle' => 180 }), 'drilling 1 countersink angle is not an angle between 0 and 180')
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => 8, 'depth' => 2 }), "drilling 1 countersink has an unknown key 'depth'")
    _assert_error(fn_drilling.call('counterbore' => { 'diameter' => 8 }), 'drilling 1 counterbore depth is not a positive length')
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => 8, 'face' => 'back' }), 'drilling 1 countersink face is neither "contact" nor "opposite"')
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => 8, 'face' => 'opposite' }), "drilling 1 countersink is on the opposite face of a drilling that isn't through")
    _assert_error(fn_drilling.call('countersink' => { 'diameter' => '@nope' }), 'drilling 1 countersink diameter uses the unknown variable @nope')
    _assert_error(fn.call('machining', { 'mortises' => [ { 'length' => 19, 'width' => 5, 'depth' => 10, 'countersink' => { 'diameter' => 8 } } ] }), "mortise 1 has an unknown key 'countersink'")
    fn_cylinder = lambda { |head| fn.call('hardware', { 'cylinders' => [ { 'diameter' => 4, 'from' => 0, 'to' => 30 }.merge(head) ] }) }
    _assert_error(fn_cylinder.call('countersink' => { 'diameter' => 8 }), 'cylinder 1 countersink has no end - "to" or "from"')
    _assert_error(fn_cylinder.call('countersink' => { 'diameter' => 8, 'face' => 'opposite' }), "cylinder 1 countersink has an unknown key 'face'")
    assert(_def(fn_cylinder.call('counterbore' => { 'diameter' => 8, 'depth' => 3, 'end' => 'to' })).valid?)
  end

  def test_bundled_screw
    descriptor = HardwareDescriptorDef.new(JSON.parse(File.read(File.expand_path('../src/ladb_opencutlist/library/connectors/generic/screw-4x40.json', __dir__))))
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal(%w[thickness_max thickness_b thickness_min_a thickness_max_a], descriptor.used_measures)   # through : the own thickness_max
    fn = lambda { |min_a, max_a, tb| descriptor.resolve_variables('thickness_max' => max_a / 25.4, 'thickness_min_a' => min_a / 25.4, 'thickness_max_a' => max_a / 25.4, 'thickness_b' => tb / 25.4) }
    variables = fn.call(19, 19, 300)   # Flat on an edge
    assert_equal([], descriptor.failed_asserts(variables))
    screw = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').hardware, variables).first
    hole = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').machining, variables).first
    assert_in_delta(-19 / 25.4, screw.z_min, 1e-9)                 # Its head on the other face
    assert_in_delta(21 / 25.4, screw.z_max, 1e-9)
    assert_in_delta(4 / 25.4, screw.profile.last.first, 1e-9)
    assert_in_delta(-19 / 25.4, hole.z_min, 1e-9)
    assert_in_delta(4.25 / 25.4, hole.profile.last.first, 1e-9)
    assert_equal([ '@thickness_max_a - @thickness_min_a <= 0.2mm' ], descriptor.failed_asserts(fn.call(17, 19, 300)))   # Faces not parallel
    assert(descriptor.failed_asserts(fn.call(19, 19, 19)).any?)     # Comes out of b
    assert(descriptor.failed_asserts(fn.call(30, 30, 300)).any?)    # Too short
  end

  def test_bundled_dominos
    dir = File.expand_path('../src/ladb_opencutlist/library/connectors/festool', __dir__)
    {
      'domino-5x30.json' => { [ 300, 300 ] => [ 15, 15 ], [ 19, 300 ] => [ 12, 20 ], [ 300, 19 ] => [ 20, 12 ], [ 19, 19 ] => nil, [ 15, 300 ] => nil },
      'domino-8x40.json' => { [ 300, 300 ] => [ 20, 20 ], [ 19, 300 ] => [ 12, 28 ], [ 300, 19 ] => [ 28, 12 ], [ 19, 19 ] => nil },
    }.each do |file, cases|
      descriptor = HardwareDescriptorDef.new(JSON.parse(File.read(File.join(dir, file))))
      assert(descriptor.valid?, "#{file} #{descriptor.errors.inspect}")
      length = file == 'domino-5x30.json' ? 30 : 40
      cases.each do |(ta, tb), depths|
        variables = descriptor.resolve_variables('thickness_a' => ta / 25.4, 'thickness_b' => tb / 25.4)
        if depths.nil?
          assert(descriptor.failed_asserts(variables).any?, "#{file} #{ta}/#{tb} should be refused")
          next
        end
        assert_equal([], descriptor.failed_asserts(variables), "#{file} #{ta}/#{tb}")
        assert_in_delta(depths[0] / 25.4, variables['depth_a'], 1e-9, "#{file} #{ta}/#{tb}")
        assert_in_delta(depths[1] / 25.4, variables['depth_b'], 1e-9, "#{file} #{ta}/#{tb}")
        tenon = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').hardware, variables).first
        assert_in_delta(length / 25.4, tenon.z_max - tenon.z_min, 1e-9)
        assert(-tenon.z_min <= variables['depth_a'] + 1e-9 && tenon.z_max <= variables['depth_b'] + 1e-9, "#{file} #{ta}/#{tb} tenon in its mortises")
      end
    end
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
