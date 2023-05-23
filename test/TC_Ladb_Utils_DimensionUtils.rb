require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/utils/dimension_utils'

class TC_Ladb_Utils_DimensionUtils < TestUp::TestCase

  def setup
    @dimutils = Ladb::OpenCutList::DimensionUtils.instance
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

    @dimutils.set_length_unit(Length::Meter)
    assert_equal_fn(fn, '1/2 m', '1/2m')
    assert_equal_fn(fn, '1/2', '1/2m')
    assert_equal_fn(fn, '', '0.0 m')
    assert_equal_fn(fn, 'm', 'm')

    @dimutils.set_length_unit(Length::Inches)
    assert_equal_fn(fn, '1', '1"')
    assert_equal_fn(fn, '1.0', '1.0"')
    assert_equal_fn(fn, '1,1', '1' + @separator + '1"')
    assert_equal_fn(fn, '1 1/2', '1 1/2"')
    assert_equal_fn(fn, '1\' 1 1/2 "', '1\' 1 1/2"')

    @dimutils.set_length_unit(Length::Feet)
    assert_equal_fn(fn, '1', '1\'')
    assert_equal_fn(fn, '1.0', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1,0', '1' + @separator + '0\'')
    assert_equal_fn(fn, '1 1/2', '1 1/2\'')

    # ...

  end

  def test_str_to_ifloat

    fn = :str_to_ifloat

    @dimutils.set_length_unit(Length::Inches)
    assert_equal_fn(fn, '1', '1' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '1' + @separator + '5"')
    assert_equal_fn(fn, '3 / 2 ', '1' + @separator + '5"')
    assert_equal_fn(fn, '3 /', '0' + @separator + '0"')
    assert_equal_fn(fn, '2/0', '0' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '1' + @separator + '5"')
    assert_equal_fn(fn, '1\' 1"', '13' + @separator + '0"')
    assert_equal_fn(fn, '1 \' 1 "', '13' + @separator + '0"')
    assert_equal_fn(fn, '1.25\' 1"', '16' + @separator + '0"')
    assert_equal_fn(fn, '1\' 3/4', '12' + @separator + '75"')
    assert_equal_fn(fn, '1\' 1.75 \"', '13' + @separator + '75"')
    assert_equal_fn(fn, '1.5 m', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/4 yd', '27' + @separator + '0"')

    @dimutils.set_length_unit(Length::Yard)
    assert_equal_fn(fn, '1', '36' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '54' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '54' + @separator + '0"')
    assert_equal_fn(fn, '2 yd', '72' + @separator + '0"')
    assert_equal_fn(fn, '1m', '39' + @separator + '37007874015748"')

    @dimutils.set_length_unit(Length::Feet)
    assert_equal_fn(fn, '1', '12' + @separator + '0"')
    assert_equal_fn(fn, '1.5', '18' + @separator + '0"')
    assert_equal_fn(fn, '1 1/2', '18' + @separator + '0"')
    assert_equal_fn(fn, '2', '24' + @separator + '0"')

    @dimutils.set_length_unit(Length::Millimeter)
    assert_equal_fn(fn, '1', '0' + @separator + '03937007874015748"')
    assert_equal_fn(fn, '1.5', '0' + @separator + '05905511811023623"')
    assert_equal_fn(fn, '1.5 mm', '0' + @separator + '05905511811023623"')
    assert_equal_fn(fn, '1 1/2"', '1' + @separator + '5"')

    @dimutils.set_length_unit(Length::Centimeter)
    assert_equal_fn(fn, '1', '0' + @separator + '39370078740157477"')
    assert_equal_fn(fn, '1.5', '0' + @separator + '5905511811023622"')
    assert_equal_fn(fn, '1.5 m', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/2', '0' + @separator + '5905511811023622"')
    assert_equal_fn(fn, '3/2m', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/2 mm', '0' + @separator + '05905511811023623"')
    assert_equal_fn(fn, '1 "', '1' + @separator + '0"')

    @dimutils.set_length_unit(Length::Meter)
    assert_equal_fn(fn, '1', '39' + @separator + '37007874015748"')
    assert_equal_fn(fn, '1.5', '59' + @separator + '05511811023622"')
    assert_equal_fn(fn, '3/2', '59' + @separator + '05511811023622"')

    # ...

  end

  private

  def assert_equal_fn(fn, input, expected)
    assert_equal(expected, Ladb::OpenCutList::DimensionUtils.instance.send(fn, input))
  end

end
