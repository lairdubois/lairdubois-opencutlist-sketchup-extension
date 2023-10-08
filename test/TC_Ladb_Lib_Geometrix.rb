require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/lib/geometrix/geometrix'

class TC_Ladb_Lib_Geometrix < TestUp::TestCase

  EPSI = 1e-6

  def setup

    # Code to use in console to retrieve points from selected loop in SketchUp
    # Sketchup.active_model.selection.first.curve.vertices.map { |vertex| "Geom::Point3d.new(#{vertex.position.to_a.join(', ')})" }.join(',')

    # Circle
    # - center = 0,0
    # - radius = 10
    @circle_x0_y0_r10 = [
      Geom::Point3d.new(10.0, 0.0, 0.0),Geom::Point3d.new(9.659258262890683, 2.5881904510252074, 0.0),Geom::Point3d.new(8.660254037844387, 4.999999999999999, 0.0),Geom::Point3d.new(7.0710678118654755, 7.071067811865475, 0.0),Geom::Point3d.new(5.000000000000001, 8.660254037844386, 0.0),Geom::Point3d.new(2.5881904510252096, 9.659258262890681, 0.0),Geom::Point3d.new(6.123233995736766e-16, 10.0, 0.0),Geom::Point3d.new(-2.5881904510252065, 9.659258262890683, 0.0),Geom::Point3d.new(-4.999999999999998, 8.660254037844387, 0.0),Geom::Point3d.new(-7.071067811865475, 7.0710678118654755, 0.0),Geom::Point3d.new(-8.660254037844386, 5.0000000000000036, 0.0),Geom::Point3d.new(-9.659258262890681, 2.58819045102521, 0.0),Geom::Point3d.new(-10.0, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-9.659258262890685, -2.5881904510252034, 0.0),Geom::Point3d.new(-8.660254037844389, -4.999999999999998, 0.0),Geom::Point3d.new(-7.071067811865479, -7.071067811865471, 0.0),Geom::Point3d.new(-5.000000000000004, -8.660254037844384, 0.0),Geom::Point3d.new(-2.5881904510252154, -9.659258262890681, 0.0),Geom::Point3d.new(-1.8369701987210296e-15, -10.0, 0.0),Geom::Point3d.new(2.588190451025203, -9.659258262890685, 0.0),Geom::Point3d.new(4.999999999999993, -8.66025403784439, 0.0),Geom::Point3d.new(7.071067811865474, -7.071067811865477, 0.0),Geom::Point3d.new(8.660254037844384, -5.000000000000004, 0.0),Geom::Point3d.new(9.659258262890681, -2.588190451025216, 0.0),Geom::Point3d.new(10.0, 0.0, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 0°
    @ellipse_x0_y0_xr20_yr20_a0 = [
      Geom::Point3d.new(19.99999999999998, 1.3322676295501878e-15, 0.0),Geom::Point3d.new(19.318516525781344, 2.5881904510252056, 0.0),Geom::Point3d.new(17.320508075688753, 4.999999999999993, 0.0),Geom::Point3d.new(14.14213562373095, 7.071067811865472, 0.0),Geom::Point3d.new(9.99999999999999, 8.66025403784438, 0.0),Geom::Point3d.new(5.176380902050412, 9.659258262890669, 0.0),Geom::Point3d.new(-3.552713678800501e-15, 9.999999999999982, 0.0),Geom::Point3d.new(-5.176380902050405, 9.659258262890669, 0.0),Geom::Point3d.new(-9.999999999999988, 8.660254037844386, 0.0),Geom::Point3d.new(-14.142135623730953, 7.07106781186547, 0.0),Geom::Point3d.new(-17.320508075688753, 4.999999999999993, 0.0),Geom::Point3d.new(-19.31851652578134, 2.5881904510252083, 0.0),Geom::Point3d.new(-19.99999999999998, 2.220446049250313e-15, 0.0),Geom::Point3d.new(-19.318516525781348, -2.588190451025197, 0.0),Geom::Point3d.new(-17.320508075688753, -4.999999999999991, 0.0),Geom::Point3d.new(-14.142135623730962, -7.071067811865463, 0.0),Geom::Point3d.new(-9.999999999999995, -8.660254037844366, 0.0),Geom::Point3d.new(-5.176380902050426, -9.659258262890656, 0.0),Geom::Point3d.new(-1.7763568394002505e-15, -9.999999999999973, 0.0),Geom::Point3d.new(5.176380902050402, -9.659258262890656, 0.0),Geom::Point3d.new(9.999999999999973, -8.66025403784437, 0.0),Geom::Point3d.new(14.142135623730953, -7.071067811865472, 0.0),Geom::Point3d.new(17.320508075688753, -4.9999999999999964, 0.0),Geom::Point3d.new(19.31851652578134, -2.5881904510252114, 0.0),Geom::Point3d.new(19.99999999999998, 1.3322676295501878e-15, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 45°
    @ellipse_x0_y0_xr20_yr20_a45 = [
      Geom::Point3d.new(7.071067811865474, -7.071067811865477, 0.0),Geom::Point3d.new(10.490381056766577, -3.1698729810778095, 0.0),Geom::Point3d.new(13.194792168823419, 0.9473434549075241, 0.0),Geom::Point3d.new(14.999999999999995, 4.999999999999994, 0.0),Geom::Point3d.new(15.782982619848624, 8.711914807983145, 0.0),Geom::Point3d.new(15.490381056766577, 11.830127018922184, 0.0),Geom::Point3d.new(14.142135623730944, 14.142135623730942, 0.0),Geom::Point3d.new(11.830127018922191, 15.49038105676657, 0.0),Geom::Point3d.new(8.711914807983154, 15.782982619848624, 0.0),Geom::Point3d.new(4.999999999999998, 14.999999999999993, 0.0),Geom::Point3d.new(0.9473434549075357, 13.194792168823422, 0.0),Geom::Point3d.new(-3.169872981077801, 10.49038105676658, 0.0),Geom::Point3d.new(-7.071067811865473, 7.071067811865478, 0.0),Geom::Point3d.new(-10.490381056766573, 3.1698729810778175, 0.0),Geom::Point3d.new(-13.19479216882342, -0.9473434549075233, 0.0),Geom::Point3d.new(-14.999999999999993, -4.999999999999985, 0.0),Geom::Point3d.new(-15.78298261984862, -8.711914807983135, 0.0),Geom::Point3d.new(-15.490381056766577, -11.830127018922173, 0.0),Geom::Point3d.new(-14.142135623730947, -14.142135623730942, 0.0),Geom::Point3d.new(-11.830127018922191, -15.490381056766564, 0.0),Geom::Point3d.new(-8.711914807983153, -15.782982619848612, 0.0),Geom::Point3d.new(-5.0000000000000036, -14.999999999999998, 0.0),Geom::Point3d.new(-0.9473434549075401, -13.194792168823424, 0.0),Geom::Point3d.new(3.169872981077793, -10.490381056766587, 0.0),Geom::Point3d.new(7.071067811865474, -7.071067811865477, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 90°
    @ellipse_x0_y0_xr20_yr20_a90 = [
      Geom::Point3d.new(10.0, -8.881784197001252e-16, 0.0),Geom::Point3d.new(9.659258262890683, 5.176380902050413, 0.0),Geom::Point3d.new(8.660254037844387, 9.999999999999996, 0.0),Geom::Point3d.new(7.0710678118654755, 14.142135623730944, 0.0),Geom::Point3d.new(5.000000000000001, 17.320508075688767, 0.0),Geom::Point3d.new(2.5881904510252096, 19.31851652578136, 0.0),Geom::Point3d.new(6.123233995736766e-16, 19.99999999999999, 0.0),Geom::Point3d.new(-2.5881904510252065, 19.318516525781362, 0.0),Geom::Point3d.new(-4.999999999999998, 17.32050807568877, 0.0),Geom::Point3d.new(-7.071067811865475, 14.142135623730944, 0.0),Geom::Point3d.new(-8.660254037844386, 10.000000000000004, 0.0),Geom::Point3d.new(-9.659258262890681, 5.176380902050418, 0.0),Geom::Point3d.new(-10.0, 2.4424906541753444e-15, 0.0),Geom::Point3d.new(-9.659258262890685, -5.176380902050404, 0.0),Geom::Point3d.new(-8.660254037844389, -9.999999999999996, 0.0),Geom::Point3d.new(-7.071067811865479, -14.142135623730937, 0.0),Geom::Point3d.new(-5.000000000000004, -17.320508075688757, 0.0),Geom::Point3d.new(-2.5881904510252154, -19.31851652578135, 0.0),Geom::Point3d.new(-1.8369701987210296e-15, -19.999999999999993, 0.0),Geom::Point3d.new(2.588190451025203, -19.31851652578136, 0.0),Geom::Point3d.new(4.999999999999993, -17.320508075688767, 0.0),Geom::Point3d.new(7.071067811865474, -14.142135623730953, 0.0),Geom::Point3d.new(8.660254037844384, -10.000000000000009, 0.0),Geom::Point3d.new(9.659258262890681, -5.176380902050429, 0.0),Geom::Point3d.new(10.0, -8.881784197001252e-16, 0.0)
    ]

  end

  def test_ellipse_finder

    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@circle_x0_y0_r10)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(10, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_equal(true, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @circle_x0_y0_r10, 'angles (circle_x0_y0_r10)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20_yr20_a0)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(0.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20_yr20_a0, 'angles (ellipse_x0_y0_xr20_yr20_a0)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20_yr20_a45)

    angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, Geom::Point3d.new(-1, 1, 0))
    assert_in_delta(90.degrees, angle_at_point, EPSI, 'S0 (ellipse_x0_y0_xr20_yr20_a45)')

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(45.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20_yr20_a45, 'angles (ellipse_x0_y0_xr20_yr20_a45)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20_yr20_a90)

    angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, Geom::Point3d.new(0, 20, 0))
    assert_in_delta(0, angle_at_point, EPSI, 'S0 (ellipse_x0_y0_xr20_yr20_a90)')
    angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, Geom::Point3d.new(-10, 0, 0))
    assert_in_delta(90.degrees, angle_at_point, EPSI, 'S1 (ellipse_x0_y0_xr20_yr20_a90)')
    angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, Geom::Point3d.new(0, -20, 0))
    assert_in_delta(180.degrees, angle_at_point, EPSI, 'S2 (ellipse_x0_y0_xr20_yr20_a90)')
    angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, Geom::Point3d.new(10, 0, 0))
    assert_in_delta(270.degrees, angle_at_point, EPSI, 'S3 (ellipse_x0_y0_xr20_yr20_a90)')

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(90.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20_yr20_a90, 'angles (ellipse_x0_y0_xr20_yr20_a90)')


  end

  private

  def assert_angles(ellipse_def, points, msg = nil)
    points.each_with_index do |point, index|
      angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, point)
      point_at_angle = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_point_at_angle(ellipse_def, angle_at_point, true)
      assert_equal(point, point_at_angle, msg + " index=#{index} angle=#{angle_at_point.radians.round(6)}°")
    end
  end

end
