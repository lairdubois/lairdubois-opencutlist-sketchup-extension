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

  def backup_options
    @length_unit = @units_options_provider['LengthUnit']
    @length_precision = @units_options_provider['LengthPrecision']
  end

  def restore_options
    @units_options_provider['LengthUnit'] = @length_unit
    @units_options_provider['LengthPrecision'] = @length_precision
  end

  def test_str_add_units

    backup_options

    fn = :str_add_units

    assert_equal_fn(fn, '-1m', '0')
    assert_equal_fn(fn, '-1.0m', '0')

    assert_equal_fn(fn, '1m', '1 m')
    assert_equal_fn(fn, '1cm', '1 cm')
    assert_equal_fn(fn, '1mm', '1 mm')
    assert_equal_fn(fn, '1"', '1"')
    assert_equal_fn(fn, '1\'', '1\'')
    assert_equal_fn(fn, '1 1/2"', '1 1/2"')
    assert_equal_fn(fn, '1.0"', '1' + @separator + '0"')
    assert_equal_fn(fn, '1.0\'', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1,0"', '1' + @separator + '0"')
    assert_equal_fn(fn, '1,0\'', '1' + @separator + '0\'')

    @units_options_provider['LengthUnit'] = Length::Meter
    @units_options_provider['LengthPrecision'] = 1
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1/2 m', '1/2 m')
    assert_equal_fn(fn, '1/2', '1/2 m')
    assert_equal_fn(fn, '', '0')  # It depends on model precision
    assert_equal_fn(fn, 'm', '0')

    @units_options_provider['LengthUnit'] = Length::Inches
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '1"')
    assert_equal_fn(fn, '1.0', '1' + @separator + '0"')
    assert_equal_fn(fn, '1,1', '1' + @separator + '1"')
    assert_equal_fn(fn, '1 1/2', '1 1/2"')
    assert_equal_fn(fn, '1\' 1 1/2 "', '1\' 1 1/2"')

    @units_options_provider['LengthUnit'] = Length::Feet
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '1\'')
    assert_equal_fn(fn, '1.0', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1,0', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1 1/2', '1 1/2\'')

    # ...

    restore_options

  end

  def test_str_to_ifloat

    backup_options

    fn = :str_to_ifloat

    @units_options_provider['LengthUnit'] = Length::Inches
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '3 /', '0')
    assert_equal_fn(fn, '2/0', '0')
    assert_equal_fn(fn, 'x', '0')
    assert_equal_fn(fn, '0m', '0')
    assert_equal_fn(fn, '-1', '0')
    assert_equal_fn(fn, '-1m', '0')
    assert_equal_fn(fn, '-1.0m', '0')
    assert_equal_fn(fn, '1', '1' + @separator + '0"')
    assert_equal_fn(fn, '--1', '1' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '1' + @separator + '5"')
    assert_equal_fn(fn, '3 / 2 ', '1' + @separator + '5"')
    assert_equal_fn(fn, '1 1/2', '1' + @separator + '5"')
    assert_equal_fn(fn, '1\' 1"', '13' + @separator + '0"')
    assert_equal_fn(fn, '1 \' 1 "', '13' + @separator + '0"')
    assert_equal_fn(fn, '1.25\' 1"', '16' + @separator + '0"')
    assert_equal_fn(fn, '1\' 3/4', '12' + @separator + '75"')
    assert_equal_fn(fn, '1\' 1.75 \"', '13' + @separator + '75"')
    assert_equal_fn(fn, '1\' 1 3/4', '13' + @separator + '75"')
    assert_equal_fn(fn, '1.5 m', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/4 yd', '27' + @separator + '0"')

    @units_options_provider['LengthUnit'] = Length::Yard
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '36' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '54' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '54' + @separator + '0"')
    assert_equal_fn(fn, '2 yd', '72' + @separator + '0"')
    assert_equal_fn(fn, '1m', '39' + @separator + '37007874015748"')

    @units_options_provider['LengthUnit'] = Length::Feet
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '12' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '18' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '18' + @separator + '0"')
    assert_equal_fn(fn, '2', '24' + @separator + '0"')

    @units_options_provider['LengthUnit'] = Length::Millimeter
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '0' + @separator + '03937007874015748"')
    assert_equal_fn(fn, '1.5', '0' + @separator + '05905511811023623"')
    assert_equal_fn(fn, '1.5 mm', '0' + @separator + '05905511811023623"')
    assert_equal_fn(fn, '1 1/2"', '1' + @separator + '5"')
    assert_equal_fn(fn, '1 1/2mm', '0' + @separator + '05905511811023623"')

    @units_options_provider['LengthUnit'] = Length::Centimeter
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '0' + @separator + '39370078740157477"')
    assert_equal_fn(fn, '1.5', '0' + @separator + '5905511811023622"')
    assert_equal_fn(fn, '1.5 m', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/2', '0' + @separator + '5905511811023622"')
    assert_equal_fn(fn, '3/2m', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/2 mm', '0' + @separator + '05905511811023623"')
    assert_equal_fn(fn, '1 "', '1' + @separator + '0"')

    @units_options_provider['LengthUnit'] = Length::Meter
    Ladb::OpenCutList::DimensionUtils.fetch_options
    assert_equal_fn(fn, '1', '39' + @separator + '37007874015748"')
    assert_equal_fn(fn, '1.5', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/2', '59' + @separator + '05511811023622"')

    # ...

    restore_options

  end

  private

  def assert_equal_fn(fn, input, expected)
    assert_equal(expected, Ladb::OpenCutList::DimensionUtils.send(fn, input))
  end

end
