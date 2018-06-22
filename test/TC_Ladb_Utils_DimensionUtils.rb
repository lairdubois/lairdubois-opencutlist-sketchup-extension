require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/utils/dimension_utils'

class TC_Ladb_Utils_DimensionUtils < TestUp::TestCase

  def setup
    @units_options_provider = Sketchup.active_model.options['UnitsOptions']
    begin
      '1.0'.to_l
      @separator = '.'
    rescue
      @separator = ','
    end
  end

  def test_str_add_units

    fn = :str_add_units

    assert_equal_fn(fn, '1m', '1m')
    assert_equal_fn(fn, '1cm', '1cm')
    assert_equal_fn(fn, '1mm', '1mm')
    assert_equal_fn(fn, '1"', '1"')
    assert_equal_fn(fn, '1\'', '1\'')

    @units_options_provider['LengthUnit'] = Length::Inches
    assert_equal_fn(fn, '1', '1"')
    assert_equal_fn(fn, '1.0', '1' + @separator + '0"')
    assert_equal_fn(fn, '1,0', '1' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '1 1/2"')

    @units_options_provider['LengthUnit'] = Length::Feet
    assert_equal_fn(fn, '1', '1\'')
    assert_equal_fn(fn, '1.0', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1,0', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1 1/2', '1 1/2"')

    # ...

  end

  def test_str_to_ifloat

    fn = :str_to_ifloat

    @units_options_provider['LengthUnit'] = Length::Inches
    assert_equal_fn(fn, '1', '1' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '1' + @separator + '5"')
    assert_equal_fn(fn, '1 1/2', '1' + @separator + '5"')
    assert_equal_fn(fn, '2', '2' + @separator + '0"')

    @units_options_provider['LengthUnit'] = Length::Feet
    assert_equal_fn(fn, '1', '12' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '18' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '18' + @separator + '0"')  # FAIL !
    assert_equal_fn(fn, '2', '24' + @separator + '0"')

    @units_options_provider['LengthUnit'] = Length::Millimeter
    assert_equal_fn(fn, '1', '0' + @separator + '03937007874015748"')
    assert_equal_fn(fn, '1.5', '0' + @separator + '05905511811023623"')

    @units_options_provider['LengthUnit'] = Length::Centimeter
    assert_equal_fn(fn, '1', '0' + @separator + '39370078740157477"')
    assert_equal_fn(fn, '1.5', '0' + @separator + '5905511811023622"')

    @units_options_provider['LengthUnit'] = Length::Meter
    assert_equal_fn(fn, '1', '39' + @separator + '37007874015748"')
    assert_equal_fn(fn, '1.5', '59' + @separator + '05511811023622"')

    # ...

  end

  private

  def assert_equal_fn(fn, input, expected)
    assert_equal(Ladb::OpenCutList::DimensionUtils.instance.send(fn, input), expected)
  end

end