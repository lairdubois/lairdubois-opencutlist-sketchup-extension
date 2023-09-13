require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/utils/axis_utils'

class TC_Ladb_Utils_AxisUtils < TestUp::TestCase

  def setup
    @rot_x_45 = Geom::Transformation.rotation(ORIGIN, X_AXIS, 45.degrees)
    @rot_y_45 = Geom::Transformation.rotation(ORIGIN, Y_AXIS, 45.degrees)
    @rot_z_45 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, 45.degrees)
  end

  def test_flipped

    fn = :flipped?

    # Not flipped
    assert_equal_fn(fn, X_AXIS,         Y_AXIS,         Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS,         Y_AXIS.reverse, Z_AXIS.reverse, false)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS,         Z_AXIS.reverse, false)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS.reverse, Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS.transform(@rot_x_45), Y_AXIS.transform(@rot_x_45), Z_AXIS.transform(@rot_x_45), false)
    assert_equal_fn(fn, Geom::Vector3d.new(2, 0, 0), Geom::Vector3d.new(0, 3, 0), Geom::Vector3d.new(0, 0, 4), false)

    # Flipped
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS.reverse, Z_AXIS.reverse, true)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS,         Z_AXIS, true)
    assert_equal_fn(fn, X_AXIS,         Y_AXIS.reverse, Z_AXIS, true)
    assert_equal_fn(fn, X_AXIS,         Y_AXIS,         Z_AXIS.reverse, true)
    assert_equal_fn(fn, Z_AXIS, Y_AXIS.reverse, X_AXIS.reverse, true)

  end

  def test_skewed

    fn = :skewed?

    # Not skewed
    assert_equal_fn(fn, X_AXIS, Y_AXIS, Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS,         Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS,         Y_AXIS.reverse, Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS,         Y_AXIS,         Z_AXIS.reverse, false)
    assert_equal_fn(fn, X_AXIS,         Y_AXIS.reverse, Z_AXIS.reverse, false)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS,         Z_AXIS.reverse, false)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS.reverse, Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS.reverse, Y_AXIS.reverse, Z_AXIS.reverse, false)
    assert_equal_fn(fn, X_AXIS.transform(@rot_x_45),  Y_AXIS,                       Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS,                       Y_AXIS.transform(@rot_y_45),  Z_AXIS, false)
    assert_equal_fn(fn, X_AXIS,                       Y_AXIS,                       Z_AXIS.transform(@rot_z_45), false)

    # Skewed
    assert_equal_fn(fn, X_AXIS,                       Y_AXIS.transform(@rot_x_45),  Z_AXIS, true)
    assert_equal_fn(fn, X_AXIS,                       Y_AXIS,                       Z_AXIS.transform(@rot_x_45), true)
    assert_equal_fn(fn, X_AXIS.transform(@rot_y_45),  Y_AXIS,                       Z_AXIS, true)
    assert_equal_fn(fn, X_AXIS,                       Y_AXIS,                       Z_AXIS.transform(@rot_y_45), true)
    assert_equal_fn(fn, X_AXIS,                       Y_AXIS.transform(@rot_z_45),  Z_AXIS, true)
    assert_equal_fn(fn, X_AXIS.transform(@rot_z_45),  Y_AXIS,                       Z_AXIS, true)

  end

  private

  def assert_equal_fn(fn, x_axis, y_axis, z_axis, expected)
    assert_equal(expected, Ladb::OpenCutList::AxisUtils.send(fn, x_axis, y_axis, z_axis))
  end

end
