require 'testup/testcase'
require 'json'
require 'tmpdir'
require 'fileutils'

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
    _assert_error(_with(HINGE, 'components' => { 'a' => {}, 'b' => nil }), 'no component')
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

  def test_empty_object_slot_is_an_empty_slot
    data = _with(HINGE, 'components' => HINGE['components'].merge('b' => {}))
    assert_equal([], _def(data).errors)
    assert_nil(_def(data).resolve_component('b'))
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
    data['components']['a']['attributes'] = { 'role' => 'hinge', 'hinge_max_angle' => 110, 'hinge_pivot' => [ '0mm', '0mm' ] }
    data['components']['a']['variants']['items']['inset']['attributes'] = { 'hinge_pivot' => [ '-4mm', '-26mm' ] }
    descriptor = _def(data)
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal({ 'role' => 'hinge', 'hinge_max_angle' => 110, 'hinge_pivot' => [ '-4mm', '-26mm' ] }, descriptor.resolve_component('a', 'hinge_kind' => 'inset').attributes)
    assert_equal({ 'role' => 'hinge', 'hinge_max_angle' => 110, 'hinge_pivot' => [ '0mm', '0mm' ] }, descriptor.resolve_component('a', 'hinge_kind' => 'overlay').attributes)
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

  # A variable given as an object is a setting : it reads as its value.
  def test_settings
    data = _with(DOWEL, 'variables' => {
      'diameter' => { 'value' => '8mm', 'label' => 'Diamètre', 'steps' => [ '6mm', '8mm', '10mm' ] },
      'length' => { 'value' => '40mm', 'min' => '20mm', 'max' => '60mm' },
      'depth_a' => 'min(@thickness_a - 5mm; max(20mm; @length - (@thickness_b - 5mm)))',
      'depth_b' => '@length - @depth_a',
    })
    data['components'] = { 'a' => { 'hardware' => { 'cylinders' => [ { 'diameter' => '@diameter', 'from' => '-@depth_a', 'to' => '@depth_b' } ] } } }
    descriptor = _def(data)
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal(%w[diameter length], descriptor.settings.keys)
    assert_equal('Diamètre', descriptor.settings['diameter']['label'])
    assert_equal('8mm', descriptor.variables['diameter'])
    variables = descriptor.resolve_variables('thickness_a' => 19 / 25.4, 'thickness_b' => 300 / 25.4)
    assert_in_delta(8 / 25.4, variables['diameter'], 1e-9)
    assert_in_delta(26 / 25.4, variables['depth_b'], 1e-9)
    cylinder = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').hardware, variables).first
    assert_in_delta(8 / 25.4, cylinder.diameter, 1e-9)
  end

  def test_invalid_settings
    fn_with = lambda { |setting| _with(DOWEL, 'variables' => DOWEL['variables'].merge('x' => setting)) }
    _assert_error(fn_with.call({ 'label' => 'X' }), "variable 'x' has no value")
    _assert_error(fn_with.call({ 'value' => '@thickness_a' }), "variable 'x' value is not a plain length")
    _assert_error(fn_with.call({ 'value' => 'min(2mm; 3mm)' }), "variable 'x' value is not a plain length")
    _assert_error(fn_with.call({ 'value' => '2mm', 'label' => 3 }), "variable 'x' label is not a string")
    _assert_error(fn_with.call({ 'value' => '2mm', 'steps' => [ '2mm' ], 'min' => '1mm' }), "variable 'x' has both steps and min / max")
    _assert_error(fn_with.call({ 'value' => '2mm', 'steps' => [] }), "variable 'x' steps are not a list of plain lengths")
    _assert_error(fn_with.call({ 'value' => '2mm', 'steps' => [ '@thickness_a' ] }), "variable 'x' steps are not a list of plain lengths")
    _assert_error(fn_with.call({ 'value' => '2mm', 'steps' => [ '3mm', '4mm' ] }), "variable 'x' value is not one of its steps")
    _assert_error(fn_with.call({ 'value' => '2mm', 'min' => 'abc' }), "variable 'x' min is not a plain length")
    _assert_error(fn_with.call({ 'value' => '2mm', 'min' => '5mm', 'max' => '3mm' }), "variable 'x' min is above max")
    _assert_error(fn_with.call({ 'value' => '2mm', 'min' => '3mm', 'max' => '5mm' }), "variable 'x' value is out of min / max")
    assert(_def(fn_with.call({ 'value' => 0, 'min' => '-2mm', 'max' => '2mm' })).valid?)   # Numbers are millimeters, 0 and negatives allowed
    assert(_def(fn_with.call({ 'value' => '0mm', 'min' => '-2mm', 'max' => '0' })).valid?)   # Zeros written as strings
  end

  def test_length_error
    variables = { 'thickness' => 19 / 25.4 }
    assert_nil(HardwareDescriptorDef.length_error('@thickness - 2mm', false, variables))
    assert_equal([ 'unresolved_variable', { :name => 'depth' } ], HardwareDescriptorDef.length_error('@depth + 2mm', false, variables))
    assert_equal('no_matching_value', HardwareDescriptorDef.length_error('floor(@thickness; 20mm; 25mm)', false, variables).first)
    assert_equal('invalid_dimension', HardwareDescriptorDef.length_error('@thickness * @thickness', false, variables).first)
    assert_equal('invalid_dimension', HardwareDescriptorDef.length_error('@thickness + 2', false, variables).first)
    assert_equal('not_a_length', HardwareDescriptorDef.length_error('@thickness - 30mm', false, variables).first)   # Negative
    assert_equal('not_a_length', HardwareDescriptorDef.length_error(true).first)
  end

  def test_assert_sides
    left, operator, right = HardwareDescriptorDef.assert_sides('@thickness - 4mm >= 2cm', 'thickness' => 19 / 25.4)
    assert_in_delta(15 / 25.4, left, 1e-9)
    assert_equal('>=', operator)
    assert_in_delta(20 / 25.4, right, 1e-9)
    left, operator, right = HardwareDescriptorDef.assert_sides('@depth <= 2mm', {})
    assert_nil(left)
    assert_equal('<=', operator)
    assert_in_delta(2 / 25.4, right, 1e-9)
    assert_nil(HardwareDescriptorDef.assert_sides('@depth', {}))
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
    _assert_error(_with(DOWEL, 'variables' => { 'x' => '@y' }), "variable 'x' uses the unknown variable @y")
    _assert_error(_with(DOWEL, 'variables' => { 'x' => '@y', 'y' => '@x' }), "variables 'x', 'y' depend on each other")
    _assert_error(_with(DOWEL, 'variables' => { 'x' => '@x + 1mm' }), "variable 'x' depends on itself")
    _assert_error(_with(DOWEL, 'variables' => { 'super' => '2mm' }), "variable 'super' is a reserved name")
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
    descriptor = HardwareDescriptorDef.new(JSON.parse(File.read(File.expand_path('../src/ladb_opencutlist/library/connectors/generic/screws/screw-4x50.json', __dir__))))
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert_equal(%w[thickness_max thickness_a thickness_min_b thickness_max_b], descriptor.used_measures)   # through : the own thickness_max
    fn = lambda { |min_b, max_b, ta| descriptor.resolve_variables('thickness_max' => max_b / 25.4, 'thickness_a' => ta / 25.4, 'thickness_min_b' => min_b / 25.4, 'thickness_max_b' => max_b / 25.4) }
    variables = fn.call(19, 19, 300)   # Flat on an edge
    assert_equal([], descriptor.failed_asserts(variables))
    screw = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').hardware, variables).first
    hole = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').machining, variables).first
    clearance = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('b').machining, variables).first
    assert_in_delta(-31 / 25.4, screw.z_min, 1e-9)                 # 50mm - 19mm embedded in a
    assert_in_delta(19 / 25.4, screw.z_max, 1e-9)                  # Its head on the other face of b
    assert_in_delta(4 / 25.4, screw.profile.first.first, 1e-9)     # Countersink radius
    assert_in_delta(-31 / 25.4, hole.z_min, 1e-9)
    assert_in_delta(3 / 25.4, hole.diameter, 1e-9)
    assert_in_delta(4 / 25.4, clearance.diameter, 1e-9)
    assert_equal([ '@thickness_max_b - @thickness_min_b <= 0.2mm' ], descriptor.failed_asserts(fn.call(17, 19, 300)))   # Faces not parallel
    assert_equal([ '@embed <= @thickness_a - 3mm' ], descriptor.failed_asserts(fn.call(19, 19, 19)))   # Comes out of a
    assert_equal([ '@embed >= 15mm' ], descriptor.failed_asserts(fn.call(40, 40, 300)))                # Too short
  end

  # The kinematics of a hinge : optional, but checked when given - a pivot
  # of length strings only, a number having no unit.
  def test_hinge_kinematics
    fn = lambda { |attributes| _with(HINGE, 'components' => HINGE['components'].merge('a' => HINGE['components']['a'].merge('attributes' => attributes))) }
    descriptor = _def(fn.call('hinge_max_angle' => 110, 'hinge_pivot' => [ '17mm', '-29mm' ], 'hinge_pivot_approximate' => true))
    assert(descriptor.valid?, descriptor.errors.inspect)
    assert(_def(fn.call('hinge_pivot' => [ '0', '-1.5cm' ])).valid?)
    _assert_error(fn.call('hinge_max_angle' => 0), "attribute 'hinge_max_angle' is not an angle in degrees")
    _assert_error(fn.call('hinge_max_angle' => 270), "attribute 'hinge_max_angle' is not an angle in degrees")
    _assert_error(fn.call('hinge_max_angle' => '110'), "attribute 'hinge_max_angle' is not an angle in degrees")
    _assert_error(fn.call('hinge_pivot' => [ 17, -29 ]), "attribute 'hinge_pivot' is not two lengths")
    _assert_error(fn.call('hinge_pivot' => [ '17mm' ]), "attribute 'hinge_pivot' is not two lengths")
    _assert_error(fn.call('hinge_pivot' => [ '17mm', 'abc' ]), "attribute 'hinge_pivot' is not two lengths")
    _assert_error(fn.call('hinge_pivot' => [ '@thickness_a', '0mm' ]), "attribute 'hinge_pivot' is not two lengths")
    _assert_error(fn.call('hinge_pivot_approximate' => 'yes'), "attribute 'hinge_pivot_approximate' is not true or false")
    # On a variant too, labelled by its path
    variants = _with(HINGE, 'components' => HINGE['components'].merge('a' => HINGE['components']['a'].merge('variants' => HINGE['components']['a']['variants'].merge(
      'items' => { 'overlay' => { 'hardware' => '$LIB/h.skp', 'attributes' => { 'hinge_pivot' => [ 1, 2 ] } } }))))
    _assert_error(variants, "component 'a/overlay' attribute 'hinge_pivot' is not two lengths")
  end

  def test_hinge_pivot
    pivot = HardwareDescriptorDef.hinge_pivot([ '17mm', '-2.9cm' ])
    assert_in_delta(17 / 25.4, pivot[0], 1e-9)
    assert_in_delta(-29 / 25.4, pivot[1], 1e-9)
    assert_equal([ 0.0, 0.0 ], HardwareDescriptorDef.hinge_pivot([ '0mm', '0' ]))
    assert_nil(HardwareDescriptorDef.hinge_pivot([ 17, -29 ]))
    assert_nil(HardwareDescriptorDef.hinge_pivot('17mm'))
    assert_nil(HardwareDescriptorDef.hinge_pivot(nil))
  end

  def test_bundled_hinges
    dir = File.expand_path('../src/ladb_opencutlist/library/hinges', __dir__)
    Dir.glob(File.join(dir, '**', '*.json')).each do |path|
      descriptor = HardwareDescriptorDef.new(JSON.parse(File.read(path)))
      assert(descriptor.valid?, "#{path} #{descriptor.errors.inspect}")
      %w[overlay half_overlay inset].each do |kind|
        attributes = descriptor.resolve_component('a', 'hinge_kind' => kind).attributes
        assert(HardwareDescriptorDef.hinge_max_angle?(attributes['hinge_max_angle']), "#{path} #{kind} hinge_max_angle")
        assert(!HardwareDescriptorDef.hinge_pivot(attributes['hinge_pivot']).nil?, "#{path} #{kind} hinge_pivot")
      end
    end
  end

  def test_bundled_dominos
    {
      'domino-5x30.json' => { [ 300, 300 ] => [ 15, 15 ], [ 19, 300 ] => [ 12, 20 ], [ 300, 19 ] => [ 20, 12 ], [ 19, 19 ] => nil, [ 15, 300 ] => nil },
      'domino-8x40.json' => { [ 300, 300 ] => [ 20, 20 ], [ 19, 300 ] => [ 12, 28 ], [ 300, 19 ] => [ 28, 12 ], [ 19, 19 ] => nil },
    }.each do |file, cases|
      descriptor = _bundled("connectors/festool/#{file}")
      assert(descriptor.valid?, "#{file} #{descriptor.errors.inspect}")
      assert_equal([ '$OCL/connectors/festool/domino.json' ], descriptor.parent_refs)
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

  def test_bundled_dowels
    assert(_bundled('connectors/generic/dowels/dowel.json').abstract?)
    { 'dowel-8x40.json' => 8, 'dowel-10x40.json' => 10 }.each do |file, diameter|
      descriptor = _bundled("connectors/generic/dowels/#{file}")
      assert(descriptor.valid?, "#{file} #{descriptor.errors.inspect}")
      assert_equal('connector', descriptor.type)
      variables = descriptor.resolve_variables('thickness_a' => 19 / 25.4, 'thickness_b' => 300 / 25.4)
      assert_in_delta(14 / 25.4, variables['depth_a'], 1e-9)
      assert_in_delta(26 / 25.4, variables['depth_b'], 1e-9)
      cylinder = HardwareDescriptorDef.primitive_cylinders(descriptor.resolve_component('a').hardware, variables).first
      assert_in_delta(diameter / 25.4, cylinder.diameter, 1e-9)
      assert(descriptor.failed_asserts(descriptor.resolve_variables('thickness_a' => 19 / 25.4, 'thickness_b' => 19 / 25.4)).any?)
    end
  end

  # -- Inheritance --

  # A dowel whose size is set : the one its children extend
  DOWEL_BASE = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'dowel-base', 'type' => 'connector', 'name' => 'Dowel',
    'variables' => {
      'diameter' => { 'value' => '8mm', 'label' => 'Diameter', 'steps' => [ '6mm', '8mm', '10mm' ] },
      'length' => { 'value' => '40mm', 'label' => 'Length' },
      'depth_a' => 'min(@thickness_a - 5mm; max(@length / 2; @length - (@thickness_b - 5mm)))',
      'depth_b' => '@length - @depth_a',
    },
    'asserts' => [ '@depth_a <= @thickness_a - 5mm', '@depth_b <= @thickness_b - 5mm' ],
    'components' => {
      'a' => {
        'name' => 'Dowel', 'price' => 0.1,
        'hardware' => { 'cylinders' => [ { 'diameter' => '@diameter', 'from' => '-@depth_a', 'to' => '@depth_b' } ] },
        'machining' => { 'drillings' => [ { 'diameter' => '@diameter', 'depth' => '@depth_a + 1mm' } ] }
      },
      'b' => { 'machining' => { 'drillings' => [ { 'diameter' => '@diameter', 'depth' => '@depth_b + 1mm' } ] } }
    },
    'options' => { 'start_offset' => '37mm', 'end_offset' => '37mm' }
  }.freeze

  def test_extends_merges_the_parent
    _with_library('dowels/dowel.json' => DOWEL_BASE) do
      child = _child('dowels/dowel.json', 'name' => 'Dowel 10x40', 'variables' => { 'diameter' => { 'value' => '10mm' } }, 'options' => { 'end_offset' => '50mm' })
      descriptor = _def(child, nil, '$LIB/dowels/dowel-10x40.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      assert_equal([ '$LIB/dowels/dowel.json' ], descriptor.parent_refs)
      assert_equal('child-1', descriptor.id)
      assert_equal('Dowel 10x40', descriptor.name)
      assert_equal('connector', descriptor.type)   # Inherited
      assert_equal({ 'value' => '10mm', 'label' => 'Diameter', 'steps' => [ '6mm', '8mm', '10mm' ] }, descriptor.settings['diameter'])
      assert_equal({ 'start_offset' => '37mm', 'end_offset' => '50mm' }, descriptor.options)
      assert_equal(child, descriptor.own_data)
      variables = descriptor.resolve_variables('thickness_a' => 19 / 25.4, 'thickness_b' => 300 / 25.4)
      assert_in_delta(10 / 25.4, variables['diameter'], 1e-9)
      assert_in_delta(14 / 25.4, variables['depth_a'], 1e-9)
      assert_equal(0.1, descriptor.resolve_component('a').price)
    end
  end

  def test_extends_never_inherits_its_identity
    _with_library('dowel.json' => DOWEL_BASE.merge('abstract' => true, 'supplier' => 'Wood')) do
      descriptor = _def(_child('dowel.json').reject { |k, _| k == 'name' }, nil, '$LIB/child.json')
      assert(descriptor.errors.include?('missing name'), descriptor.errors.inspect)
      assert(!descriptor.abstract?)
      assert(!descriptor.data.key?('abstract'))
      assert_equal('Wood', descriptor.supplier)
    end
  end

  def test_extends_null_removes_but_a_null_variant_stays_unsupported
    _with_library('hinge.json' => HINGE) do
      child = _child('hinge.json', 'type' => 'hinge', 'options' => nil,
                     'components' => { 'a' => { 'description' => nil, 'variants' => { 'items' => { 'inset' => nil } } }, 'b' => { 'machining' => nil } })
      descriptor = _def(child, nil, '$LIB/child.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      assert_equal({}, descriptor.options)
      assert_nil(descriptor.resolve_component('a', 'hinge_kind' => 'inset'))   # Unsupported, no fallback
      assert_nil(descriptor.resolve_component('a', 'hinge_kind' => 'overlay').description)
      assert_nil(descriptor.resolve_component('b').machining)
      assert(!descriptor.resolve_component('b').hardware.nil?)
    end
  end

  def test_extends_super
    _with_library('dowel.json' => DOWEL_BASE) do
      child = _child('dowel.json', 'variables' => { 'depth_b' => '@super + 0mm', 'wall' => '5mm', 'depth_a' => 'min(@super; @thickness_a - @wall)' },
                     'asserts' => [ '@depth_a >= 10mm', '@super' ])
      descriptor = _def(child, nil, '$LIB/child.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      assert_equal('(@length - @depth_a) + 0mm', descriptor.variables['depth_b'])
      assert_equal([ '@depth_a >= 10mm' ] + DOWEL_BASE['asserts'], descriptor.asserts)
      # depth_a uses wall, written after it : evaluated in the order of their dependencies
      variables = descriptor.resolve_variables('thickness_a' => 19 / 25.4, 'thickness_b' => 300 / 25.4)
      assert_in_delta(14 / 25.4, variables['depth_a'], 1e-9)
      assert_in_delta(26 / 25.4, variables['depth_b'], 1e-9)

      assert_equal([ 'x' ], _def(_child('dowel.json', 'asserts' => [ 'x' ]), nil, '$LIB/c.json').asserts)   # Replaced
      _assert_errors(_child('dowel.json', 'asserts' => [ '@super', '@super' ]), 'asserts has @super more than once')
      _assert_errors(_child('dowel.json', 'variables' => { 'nope' => '@super + 1mm' }), "variable 'nope' uses @super but its parent has no such variable")
      _assert_errors(_child('dowel.json', 'variables' => { 'super' => '1mm' }), "variable 'super' is a reserved name")
    end
  end

  def test_extends_parts_stay_the_ones_of_their_descriptor
    parent = _with(CONVENTION, 'components' => {
      'a' => CONVENTION['components']['a'],
      'b' => { 'hardware' => true, 'machining' => 'hinges/blum/cup-35.skp' }
    })
    _with_library('$OCL/hinges/blum/clip-top.json' => parent) do
      child = _child('$OCL/hinges/blum/clip-top.json', 'type' => 'hinge', 'components' => { 'a' => { 'variants' => { 'items' => { 'inset' => { 'hardware' => true } } } } })
      descriptor = _def(child, nil, '$LIB/hinges/mine.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      assert_equal('$OCL/components/hinges/blum/clip-top/b.skp', descriptor.resolve_component('b').hardware)
      assert_equal('$OCL/components/hinges/blum/cup-35.skp', descriptor.resolve_component('b').machining)
      assert_equal('$LIB/components/hinges/mine/a.inset.skp', descriptor.resolve_component('a', 'hinge_kind' => 'inset').hardware)   # Redeclared
      assert_equal('$OCL/components/hinges/blum/clip-top/a.inset.machining.skp', descriptor.resolve_component('a', 'hinge_kind' => 'inset').machining)
    end
  end

  def test_extends_errors
    _with_library('dowel.json' => DOWEL_BASE, 'loop_a.json' => _child('loop_b.json'), 'loop_b.json' => _child('loop_a.json'), '$LIB/user.json' => DOWEL_BASE) do
      _assert_errors(_child('nowhere.json'), 'extends $LIB/nowhere.json : parent not found')
      _assert_errors(_child('../dowel.json'), 'extends "../dowel.json" is not a descriptor path')
      _assert_errors(_child('dowel.json', 'type' => 'hinge'), 'type "hinge" differs from its parent\'s "connector"')
      _assert_errors(_child('loop_a.json'), 'extends $LIB/loop_a.json : inheritance cycle')
      errors = _def(_child('$LIB/user.json'), nil, '$OCL/bundled.json').errors
      assert(errors.include?('extends $LIB/user.json : the OCL library can\'t extend the user\'s one'), errors.inspect)
      _assert_errors(_child('dowel.json').merge('extends' => 12), 'extends is not a string')
    end
    levels = Hash[(1..9).map { |i| [ "l#{i}.json", i == 9 ? DOWEL_BASE : _child("l#{i + 1}.json") ] }]
    _with_library(levels) do
      _assert_errors(_child('l1.json'), 'more than 8 levels')
      assert(_def(_child('l2.json'), nil, '$LIB/c.json').valid?)   # 8 levels
    end
  end

  def test_abstract
    base = _with(DOWEL_BASE, 'abstract' => true, 'variables' => DOWEL_BASE['variables'].merge('diameter' => { 'label' => 'Diameter' }))
    assert(_def(base).abstract?)
    assert(_def(base).valid?, _def(base).errors.inspect)   # Only validated merged into a child
    _with_library('base.json' => base) do
      assert(!_def(_child('base.json'), nil, '$LIB/c.json').valid?)   # No diameter
      descriptor = _def(_child('base.json', 'variables' => { 'diameter' => { 'value' => '6mm' } }), nil, '$LIB/c.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      assert(!descriptor.abstract?)
    end
  end

  def test_extends_load_and_stale
    _with_library('dowel.json' => DOWEL_BASE, 'dowel-10.json' => _child('dowel.json')) do |dir|
      descriptor = HardwareDescriptorDef.load('$LIB/dowel-10.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      assert(!descriptor.stale?)
      File.utime(Time.now + 10, Time.now + 10, File.join(dir, 'lib', 'dowel.json'))
      assert(descriptor.stale?)   # Its parent changed
    end
  end

  def test_extends_helpers
    assert_equal('$LIB/a/b.json', HardwareDescriptorDef.parent_ref('a/b.json', '$LIB/x/y.json'))
    assert_equal('$OCL/a/b.json', HardwareDescriptorDef.parent_ref('a/b.json', '$OCL/x/y.json'))
    assert_equal('$OCL/a/b.json', HardwareDescriptorDef.parent_ref('$OCL/a/b.json', '$LIB/x/y.json'))
    assert_equal('$LIB/a/b.json', HardwareDescriptorDef.parent_ref('a/b.json', nil))   # A new one is written in the user's library
    assert_nil(HardwareDescriptorDef.parent_ref('/abs/b.json', nil))
    assert_equal('a/b.json', HardwareDescriptorDef.extends_value('$LIB/a/b.json', '$LIB/x.json'))
    assert_equal('$OCL/a/b.json', HardwareDescriptorDef.extends_value('$OCL/a/b.json', '$LIB/x.json'))
    assert_equal(%({ "id": "x",\n  "extends": "new/p.json", "name": "a" }), HardwareDescriptorDef.replace_extends(%({ "id": "x",\n  "extends": "old/\\"p.json", "name": "a" }), 'new/p.json'))
    assert_equal('{ "id": "x" }', HardwareDescriptorDef.replace_extends('{ "id": "x" }', 'p.json'))
    _with_library('d/dowel.json' => DOWEL_BASE, 'd/c1.json' => _child('d/dowel.json'), 'c2.json' => _child('$LIB/d/dowel.json'), 'c3.json' => _child('c1.json')) do |dir|
      assert_equal(%w[$LIB/c2.json $LIB/d/c1.json], HardwareDescriptorDef.children_refs('$LIB/d/dowel.json', File.join(dir, 'lib'), '$LIB/'))
    end
  end

  def test_uses_helpers
    components = {
      'a' => { 'hardware' => { 'body' => { 'skp' => true }, 'screws' => { 'use' => 's.json' } } },
      'b' => { 'variants' => { 'items' => { 'overlay' => { 'hardware' => { 'pins' => { 'use' => '$OCL/p.json' } } } } } },
      'c' => { 'hardware' => { 'cylinders' => [] } }
    }
    articles = []
    HardwareDescriptorDef.each_article(components) { |slot, variant, key, _| articles << [ slot, variant, key ] }
    assert_equal([ [ 'a', nil, 'body' ], [ 'a', nil, 'screws' ], [ 'b', 'overlay', 'pins' ] ], articles)
    assert_equal(%({ "use": "new.json", "host": "a", "use" : "$OCL/p.json" }), HardwareDescriptorDef.replace_uses(%({ "use": "s.json", "host": "a", "use" : "$OCL/p.json" })) { |value| value == 's.json' ? 'new.json' : nil })
    fn_user = lambda { |use| _bracket({}, {}).tap { |data| data['components']['a']['hardware']['screws']['use'] = use; data['components']['b']['hardware']['screws']['use'] = use } }
    _with_library('connectors/screw.json' => SCREW, 'f/u1.json' => fn_user.call('connectors/screw.json'), 'u2.json' => fn_user.call('$LIB/connectors/screw.json'), 'u3.json' => fn_user.call('$OCL/connectors/screw.json'), 'c.json' => _child('connectors/screw.json')) do |dir|
      assert_equal(%w[$LIB/f/u1.json $LIB/u2.json], HardwareDescriptorDef.users_refs('$LIB/connectors/screw.json', File.join(dir, 'lib'), '$LIB/'))
      assert_equal([], HardwareDescriptorDef.users_refs('$LIB/connectors/other.json', File.join(dir, 'lib'), '$LIB/'))
    end
  end

  # -- Articles --

  # A screw driven into a, through b : what an angle bracket uses.
  SCREW = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'screw-1', 'type' => 'connector', 'name' => 'Screw 4x20',
    'variables' => {
      'diameter' => { 'value' => '4mm', 'label' => 'Diameter' },
      'length' => { 'value' => '20mm', 'label' => 'Length', 'min' => '10mm', 'max' => '100mm' },
      'embed_min' => { 'value' => '15mm', 'label' => 'Embed min' },
      'embed' => '@length - @thickness_max_b'
    },
    'asserts' => [ '@embed >= @embed_min', '@embed <= @thickness_a - 3mm' ],
    'components' => {
      'a' => {
        'name' => 'Screw 4x20', 'price' => 0.02,
        'hardware' => { 'cylinders' => [ { 'diameter' => '@diameter', 'from' => '-@embed', 'to' => '@thickness_max_b', 'countersink' => { 'diameter' => '@diameter * 2', 'end' => 'to' } } ] },
        'machining' => { 'drillings' => [ { 'diameter' => '@diameter - 1mm', 'depth' => '@embed' } ] }
      },
      'b' => { 'machining' => { 'drillings' => [ { 'diameter' => '@diameter', 'depth' => 'through' } ] } }
    }
  }.freeze

  def _bracket(a_changes = {}, root_changes = {})
    screws = { 'use' => 'connectors/screw.json', 'host' => 'a', 'measures' => { 'thickness_b' => '@bracket_thickness' },
               'at' => [ { 'x' => -8, 'y' => '-@hole_distance' }, { 'x' => 8, 'y' => '-@hole_distance' } ] }
    {
      'format' => 'ocl-hardware', 'version' => 1, 'id' => 'bracket-1', 'type' => 'fitting', 'name' => 'Angle bracket 40x40',
      'variables' => { 'bracket_thickness' => { 'value' => '2mm', 'label' => 'Bracket thickness' }, 'hole_distance' => { 'value' => '25mm' } },
      'components' => {
        'a' => { 'hardware' => { 'body' => { 'name' => 'Angle bracket 40x40', 'price' => 0.3, 'skp' => true }, 'screws' => screws }.merge(a_changes) },
        'b' => { 'hardware' => { 'screws' => screws.merge('at' => [ { 'y' => '@hole_distance' } ]) } }
      }
    }.merge(root_changes)
  end

  def test_articles_resolve
    _with_library('connectors/screw.json' => SCREW) do
      descriptor = _def(_bracket, nil, '$LIB/fittings/bracket.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      component = descriptor.resolve_component('a')
      assert_nil(component.hardware)
      assert_equal('a', component.part_slots['hardware'])
      assert_equal(%w[body screws], component.articles.map(&:key))
      body, screws = component.articles
      assert(!body.use?)
      assert_equal('$LIB/components/fittings/bracket/a.body.skp', body.hardware)
      assert_equal([ [ 0, 0 ] ], body.positions)   # One at the origin
      assert_equal(0.3, body.price)
      assert(screws.use?)
      assert_equal('$LIB/connectors/screw.json', screws.use)
      assert_equal('Screw 4x20', screws.descriptor.name)
      assert_equal('b', screws.other_slot)

      # At a placement : 19 mm panel, 2 mm virtual wing
      variables = descriptor.resolve_variables('thickness' => 19 / 25.4)
      positions = screws.positions(variables)
      assert_in_delta(-8 / 25.4, positions[0][0], 1e-9)
      assert_in_delta(-25 / 25.4, positions[0][1], 1e-9)
      joint = screws.joint_measures({ 'thickness' => 19 / 25.4, 'thickness_min' => 19 / 25.4, 'thickness_max' => 19 / 25.4 }, variables)
      assert_in_delta(19 / 25.4, joint['thickness_a'], 1e-9)
      assert_in_delta(2 / 25.4, joint['thickness_max_b'], 1e-9)
      used_variables = screws.descriptor.resolve_variables(screws.side_measures(joint, 'a'))
      assert_in_delta(18 / 25.4, used_variables['embed'], 1e-9)
      assert_in_delta(19 / 25.4, used_variables['thickness'], 1e-9)   # Unsuffixed : side a's
      assert_equal([ '@embed <= @thickness_a - 3mm' ], screws.descriptor.failed_asserts(used_variables))   # 18 > 16

      b = descriptor.resolve_component('b').articles.first
      assert_in_delta(25 / 25.4, b.positions(variables)[0][1], 1e-9)
      assert_equal(0, b.positions(variables)[0][0])
    end
  end

  def test_articles_override_setting_values
    _with_library('connectors/screw.json' => SCREW) do
      data = _bracket('screws' => { 'use' => 'connectors/screw.json', 'host' => 'a', 'measures' => { 'thickness_b' => '@bracket_thickness' }, 'variables' => { 'length' => { 'value' => '18mm' } } })
      descriptor = _def(data, nil, '$LIB/fittings/bracket.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      used = descriptor.resolve_component('a').articles.last.descriptor
      assert_equal({ 'value' => '18mm', 'label' => 'Length', 'min' => '10mm', 'max' => '100mm' }, used.settings['length'])
      assert_equal('Screw 4x20', used.name)
      assert_equal('screw-1', used.id)
      joint = { 'thickness_a' => 19 / 25.4, 'thickness_b' => 2 / 25.4, 'thickness_min_b' => 2 / 25.4, 'thickness_max_b' => 2 / 25.4 }
      assert_equal([], used.failed_asserts(used.resolve_variables(joint)))   # 16 <= 16
      # Its part declared by the parent stays the parent's
      assert(used.resolve_component('a').hardware.is_a?(Hash))
    end
  end

  def test_articles_errors
    with_screw = lambda { |screws| _bracket('screws' => { 'use' => 'connectors/screw.json', 'host' => 'a', 'measures' => { 'thickness_b' => '2mm' } }.merge(screws)) }
    _with_library('connectors/screw.json' => SCREW, 'fittings/other.json' => _bracket, 'connectors/files.json' => _with(SCREW, 'components' => { 'a' => { 'hardware' => true, 'machining' => true } })) do
      _assert_errors(_bracket('Body' => { 'skp' => true }), "article 'Body' key is not made of lowercase letters")
      _assert_errors(_bracket('x' => { 'name' => 'X' }), "article 'x' has no geometry")
      _assert_errors(_bracket('x' => { 'skp' => true, 'cylinders' => [ { 'diameter' => 4, 'from' => 0, 'to' => 1 } ] }), "article 'x' has more than one geometry")
      _assert_errors(_bracket('x' => { 'skp' => 12 }), "article 'x' skp is neither true nor a path")
      _assert_errors(_bracket('x' => { 'skp' => true, 'host' => 'a' }), "article 'x' has 'host' but uses no connector")
      _assert_errors(_bracket('x' => { 'skp' => true, 'at' => [] }), "article 'x' at is not a list of positions")
      _assert_errors(_bracket('x' => { 'skp' => true, 'at' => [ { 'x' => '@nope', 'z' => 1 } ] }), "position 1 x uses the unknown variable @nope")
      _assert_errors(_bracket('x' => { 'skp' => true, 'at' => [ { 'z' => 1 } ] }), "position 1 has an unknown key 'z'")
      _assert_errors(_bracket('x' => { 'cylinders' => [ { 'diameter' => -4, 'from' => 0, 'to' => 1 } ] }), "component 'a/x' cylinder 1 diameter is not a positive length")
      _assert_errors(with_screw.call('use' => 'connectors/nope.json'), 'uses $LIB/connectors/nope.json : not found')
      _assert_errors(with_screw.call('use' => 'fittings/other.json'), 'a fitting, not a connector')
      _assert_errors(with_screw.call('use' => 'connectors/files.json'), "the machining of side a of Screw 4x20 is a file, it can't be merged")
      _assert_errors(with_screw.call('host' => 'c'), 'host is neither "a" nor "b"')
      _assert_errors(with_screw.call('measures' => { 'thickness_a' => '2mm' }), 'measures has no thickness_b')
      _assert_errors(with_screw.call('measures' => { 'thickness_b' => '2mm', 'height_b' => '1mm' }), "measures has the unknown measure 'height_b'")
      _assert_errors(with_screw.call('measures' => { 'thickness_b' => '-2mm' }), 'thickness_b is not a positive length')
      _assert_errors(with_screw.call('variables' => { 'embed' => { 'value' => '1mm' } }), "variable 'embed' is not a setting of Screw 4x20")
      _assert_errors(with_screw.call('variables' => { 'length' => { 'value' => '18mm', 'label' => 'L' } }), "variable 'length' overrides more than its value")
      _assert_errors(with_screw.call('variables' => { 'length' => { 'value' => '200mm' } }), "variable 'length' value is out of min / max")
      _assert_errors(_with(SCREW, 'components' => { 'a' => { 'hardware' => { 'x' => { 'use' => 'connectors/screw.json', 'host' => 'a', 'measures' => { 'thickness_b' => '2mm' } } } } }), "a connector can't use another hardware")
      errors = _def(with_screw.call('use' => '$LIB/connectors/screw.json'), nil, '$OCL/fittings/bracket.json').errors
      assert(errors.any? { |error| error.include?("the OCL library can't use the user's one") }, errors.inspect)
    end
    # An object with an article field is a single article - primitives here
    _assert_error(_with(SCREW, 'components' => { 'a' => { 'hardware' => { 'name' => 'X', 'cylinders' => [] } } }), "has an unknown primitive 'name'")
  end

  def test_articles_inherited
    parent = _bracket.merge('abstract' => false)
    _with_library('$OCL/fittings/bracket.json' => parent, '$OCL/connectors/screw.json' => SCREW, '$LIB/connectors/screw-long.json' => _with(SCREW, 'name' => 'Screw long')) do
      child = _child('$OCL/fittings/bracket.json', 'components' => { 'a' => { 'hardware' => { 'screws' => { 'use' => 'connectors/screw-long.json' }, 'nut' => { 'cylinders' => [ { 'diameter' => 8, 'from' => 0, 'to' => 3 } ] } } } })
      descriptor = _def(child, nil, '$LIB/fittings/mine.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      body, screws, nut = descriptor.resolve_component('a').articles
      assert_equal('$OCL/components/fittings/bracket/a.body.skp', body.hardware)   # Stays the parent's
      assert_equal('$LIB/connectors/screw-long.json', screws.use)                  # Merged by key : the rest is the parent's
      assert_equal('Screw long', screws.descriptor.name)
      assert_equal(2, screws.at.length)
      assert_equal('nut', nut.key)
      assert(nut.hardware.is_a?(Hash))
      assert_equal('$OCL/connectors/screw.json', descriptor.resolve_component('b').articles.first.use)   # The parent's, made a ref of its library

      removed = _def(_child('$OCL/fittings/bracket.json', 'components' => { 'a' => { 'hardware' => { 'body' => nil } } }), nil, '$LIB/fittings/mine.json')
      assert_equal(%w[screws], removed.resolve_component('a').articles.map(&:key))
    end
  end

  def test_articles_linked
    _with_library('connectors/screw.json' => SCREW) do
      data = _bracket
      data['components']['b'] = { 'hardware' => { 'same_as' => 'a' } }
      descriptor = _def(data, nil, '$LIB/fittings/bracket.json')
      assert(descriptor.valid?, descriptor.errors.inspect)
      component = descriptor.resolve_component('b')
      assert_equal(%w[body screws], component.articles.map(&:key))
      assert_equal('a', component.part_slots['hardware'])
      assert_equal('a.body.skp', HardwareDescriptorDef.article_file_name('a', nil, 'body'))
      assert_equal('a.overlay.body.skp', HardwareDescriptorDef.article_file_name('a', 'overlay', 'body'))
    end
  end

  # -----

  private

  # The descriptor of the OCL library at the given path, read as the plugin does.
  def _bundled(relative)
    dir = File.expand_path('../src/ladb_opencutlist/library', __dir__)
    HardwareDescriptorDef.library_resolver = lambda { |ref| ref.start_with?('$OCL/') ? File.join(dir, ref[5..-1]) : ref }
    HardwareDescriptorDef.load('$OCL/' + relative)
  ensure
    HardwareDescriptorDef.library_resolver = nil
  end

  # A descriptor extending the given parent - its ref, or a path in its library.
  def _child(extends, changes = {})
    { 'format' => 'ocl-hardware', 'version' => 1, 'id' => 'child-1', 'name' => 'Child', 'extends' => extends }.merge(changes)
  end

  # Runs the given block with the given files - { path in the user's library
  # or '$OCL/…' ref => data } - as the libraries descriptors are read from.
  def _with_library(files)
    Dir.mktmpdir do |dir|
      roots = { '$LIB/' => File.join(dir, 'lib'), '$OCL/' => File.join(dir, 'ocl') }
      fn_path = lambda { |ref|
        prefix = roots.keys.find { |p| ref.start_with?(p) }
        prefix.nil? ? ref : File.join(roots[prefix], ref[prefix.length..-1])
      }
      files.each do |ref, data|
        path = fn_path.call(roots.keys.any? { |p| ref.start_with?(p) } ? ref : '$LIB/' + ref)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.generate(data))
      end
      HardwareDescriptorDef.library_resolver = fn_path
      begin
        yield(dir)
      ensure
        HardwareDescriptorDef.library_resolver = nil
      end
    end
  end

  def _assert_errors(data, message, ref = '$LIB/child.json')
    errors = _def(data, nil, ref).errors
    assert(errors.any? { |error| error.include?(message) }, "expected '#{message}' in #{errors.inspect}")
  end

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
