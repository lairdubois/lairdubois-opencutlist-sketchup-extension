require 'testup/testcase'
require 'json'
require 'tmpdir'
require 'fileutils'

require_relative '../src/ladb_opencutlist/ruby/model/hardware/hardware_options_def'

# The options of a SmartJoin action read through its picked hardware : the
# user's override for it, its value, the action's own - and the level a
# change is written to. Nothing here reads the model.
class TC_Ladb_Model_HardwareOptionsDef < TestUp::TestCase

  HardwareDescriptorDef = Ladb::OpenCutList::HardwareDescriptorDef
  HardwareOptionsDef = Ladb::OpenCutList::HardwareOptionsDef

  HINGE = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'hinge-1', 'type' => 'hinge', 'name' => 'Clip Top',
    'components' => { 'a' => { 'name' => 'Hinge', 'hardware' => '$LIB/hinge.skp' }, 'b' => { 'name' => 'Plate', 'hardware' => '$LIB/plate.skp' } },
    'options' => { 'start_offset' => '60mm', 'end_offset' => '60mm', 'hardware_layer_name' => 'Hinges', 'opposite' => true }
  }.freeze

  DOWEL = {
    'format' => 'ocl-hardware', 'version' => 1,
    'id' => 'dowel-1', 'type' => 'connector', 'name' => 'Dowel',
    'components' => { 'a' => { 'name' => 'Dowel', 'hardware' => '$LIB/dowel.skp' }, 'b' => { 'same_as' => 'a' } },
    'options' => { 'height' => '/2', 'start_offset' => '37mm' }
  }.freeze

  BASE = {
    'height' => '/3', 'start_offset' => '10mm', 'end_offset' => '20mm', 'max_spacing' => '300mm',
    'hardware_layer_name' => 'Hardware', 'make_unique' => true
  }.freeze

  def test_no_hardware_reads_the_base
    _with_library do
      options_def = _options_def(nil)
      assert_nil(options_def.descriptor)
      assert_equal('10mm', options_def.value('start_offset'))
      assert_equal(HardwareOptionsDef::SOURCE_BASE, options_def.source('start_offset'))
      assert_equal({}, options_def.hardware_values)
    end
  end

  def test_hardware_values_before_the_base
    _with_library do
      options_def = _options_def('$LIB/hinge.json')
      assert_equal('60mm', options_def.value('start_offset'))
      assert_equal(HardwareOptionsDef::SOURCE_HARDWARE, options_def.source('start_offset'))
      assert_equal('Hinges', options_def.value('hardware_layer_name'))
      assert_equal('300mm', options_def.value('max_spacing'))   # Not defined : the base
      assert_equal(HardwareOptionsDef::SOURCE_BASE, options_def.source('max_spacing'))
      assert(!options_def.hardware_values.key?('opposite'))   # Not one of its options
    end
  end

  def test_switching_hardware_leaves_nothing
    _with_library do
      assert_equal('/2', _options_def('$LIB/dowel.json').value('height'))
      assert_equal('37mm', _options_def('$LIB/dowel.json').value('start_offset'))
      options_def = _options_def('$LIB/hinge.json')
      assert_equal('/3', options_def.value('height'))   # The dowel's is gone
      assert_equal('20mm', _options_def('$LIB/dowel.json').value('end_offset'))
    end
  end

  def test_override_before_the_hardware
    _with_library do
      options_def = _options_def('$LIB/hinge.json', 'hardware_options' => { 'hinge-1' => { 'start_offset' => '80mm' }, 'dowel-1' => { 'end_offset' => '5mm' } })
      assert_equal('80mm', options_def.value('start_offset'))
      assert_equal(HardwareOptionsDef::SOURCE_OVERRIDE, options_def.source('start_offset'))
      assert_equal('60mm', options_def.value('end_offset'))   # Another hardware's override
    end
  end

  def test_override_of_an_option_it_no_longer_defines_is_ignored
    _with_library do
      options_def = _options_def('$LIB/hinge.json', 'hardware_options' => { 'hinge-1' => { 'max_spacing' => '800mm' } })
      assert_equal('300mm', options_def.value('max_spacing'))
      assert_equal({}, options_def.overrides)
    end
  end

  def test_store_defined_option_is_an_override
    _with_library do
      preset = _options_def('$LIB/hinge.json').store('start_offset' => '80mm')
      assert_equal({ 'hinge-1' => { 'start_offset' => '80mm' } }, preset['hardware_options'])
      assert_equal('10mm', preset['start_offset'])   # The base stays
      assert_equal('80mm', _options_def('$LIB/hinge.json', preset).value('start_offset'))
    end
  end

  def test_store_hardware_value_drops_the_override
    _with_library do
      preset = _options_def('$LIB/hinge.json', 'hardware_options' => { 'hinge-1' => { 'start_offset' => '80mm' } }).store('start_offset' => '60mm')
      assert_equal({}, preset['hardware_options'])
      preset = _options_def('$LIB/hinge.json', 'hardware_options' => { 'hinge-1' => { 'start_offset' => '80mm' } }).store('start_offset' => '')
      assert_equal({}, preset['hardware_options'])   # Empty : back to the hardware's
    end
  end

  def test_store_undefined_option_is_the_base
    _with_library do
      preset = _options_def('$LIB/hinge.json').store('max_spacing' => '400mm', 'machining_layer_name' => 'Machining')
      assert_equal('400mm', preset['max_spacing'])
      assert_equal('Machining', preset['machining_layer_name'])
      assert(!preset.key?('hardware_options'))
    end
  end

  def test_store_unchanged_is_nil
    _with_library do
      assert_nil(_options_def('$LIB/hinge.json').store('start_offset' => '60mm', 'max_spacing' => '300mm'))
    end
  end

  def test_store_keeps_the_given_preset
    _with_library do
      overrides = { 'hinge-1' => { 'start_offset' => '80mm' } }
      _options_def('$LIB/hinge.json', 'hardware_options' => overrides).store('end_offset' => '90mm')
      assert_equal({ 'hinge-1' => { 'start_offset' => '80mm' } }, overrides)   # Copied, not changed
    end
  end

  def test_unusable_descriptor_reads_the_base
    _with_library do
      assert_equal('10mm', _options_def('$LIB/abstract.json').value('start_offset'))
      assert_equal('10mm', _options_def('$LIB/missing.json').value('start_offset'))
    end
  end

  def test_forget
    preset = { 'hardware' => nil, 'hardware_options' => { 'hinge-1' => { 'start_offset' => '80mm' }, 'dowel-1' => { 'height' => '/4' } } }
    assert_equal({ 'dowel-1' => { 'height' => '/4' } }, HardwareOptionsDef.forget(preset, 'hinge-1')['hardware_options'])
    assert_nil(HardwareOptionsDef.forget(preset, 'other'))
    assert_equal(2, preset['hardware_options'].length)
  end

  private

  def _options_def(ref, changes = {})
    HardwareOptionsDef.new('action_4', BASE.merge('hardware' => ref).merge(changes))
  end

  def _with_library
    Dir.mktmpdir do |dir|
      files = { 'hinge.json' => HINGE, 'dowel.json' => DOWEL, 'abstract.json' => HINGE.merge('id' => 'abstract-1', 'abstract' => true) }
      files.each { |name, data| File.write(File.join(dir, name), JSON.generate(data)) }
      HardwareDescriptorDef.library_resolver = lambda { |ref| ref.start_with?('$LIB/') ? File.join(dir, ref[5..-1]) : ref }
      begin
        yield(dir)
      ensure
        HardwareDescriptorDef.library_resolver = nil
      end
    end
  end

end
