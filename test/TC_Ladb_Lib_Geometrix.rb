require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/lib/geometrix/geometrix'

class TC_Ladb_Lib_Geometrix < TestUp::TestCase

  EPSI = 1e-6

  def setup

    # Code to use in console to retrieve points from selected loop in SketchUp
    # Sketchup.active_model.selection.first.curve.vertices.map { |vertex| "Geom::Point3d.new(#{vertex.position.to_a.join(', ')})" }.join(',')

    @tx10_ty_5 = Geom::Transformation.translation(Geom::Vector3d.new(10, 5))

    # Circle
    # - center = 0,0
    # - radius = 10
    @circle_x0_y0_r10 = [
      Geom::Point3d.new(10.0, 0.0, 0.0),Geom::Point3d.new(9.659258262890683, 2.5881904510252074, 0.0),Geom::Point3d.new(8.660254037844387, 4.999999999999999, 0.0),Geom::Point3d.new(7.0710678118654755, 7.071067811865475, 0.0),Geom::Point3d.new(5.000000000000001, 8.660254037844386, 0.0),Geom::Point3d.new(2.5881904510252096, 9.659258262890681, 0.0),Geom::Point3d.new(6.123233995736766e-16, 10.0, 0.0),Geom::Point3d.new(-2.5881904510252065, 9.659258262890683, 0.0),Geom::Point3d.new(-4.999999999999998, 8.660254037844387, 0.0),Geom::Point3d.new(-7.071067811865475, 7.0710678118654755, 0.0),Geom::Point3d.new(-8.660254037844386, 5.0000000000000036, 0.0),Geom::Point3d.new(-9.659258262890681, 2.58819045102521, 0.0),Geom::Point3d.new(-10.0, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-9.659258262890685, -2.5881904510252034, 0.0),Geom::Point3d.new(-8.660254037844389, -4.999999999999998, 0.0),Geom::Point3d.new(-7.071067811865479, -7.071067811865471, 0.0),Geom::Point3d.new(-5.000000000000004, -8.660254037844384, 0.0),Geom::Point3d.new(-2.5881904510252154, -9.659258262890681, 0.0),Geom::Point3d.new(-1.8369701987210296e-15, -10.0, 0.0),Geom::Point3d.new(2.588190451025203, -9.659258262890685, 0.0),Geom::Point3d.new(4.999999999999993, -8.66025403784439, 0.0),Geom::Point3d.new(7.071067811865474, -7.071067811865477, 0.0),Geom::Point3d.new(8.660254037844384, -5.000000000000004, 0.0),Geom::Point3d.new(9.659258262890681, -2.588190451025216, 0.0),Geom::Point3d.new(10.0, 0.0, 0.0)
    ]
    @circle_x10_y5_r10 = @circle_x0_y0_r10.map { |point| point.transform(@tx10_ty_5) }

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 0°
    @ellipse_x0_y0_xr20_yr20_a0 = [
      Geom::Point3d.new(19.99999999999998, 0.0, 0.0),Geom::Point3d.new(19.318516525781355, 2.5881904510252074, 0.0),Geom::Point3d.new(17.320508075688757, 4.999999999999999, 0.0),Geom::Point3d.new(14.142135623730937, 7.071067811865475, 0.0),Geom::Point3d.new(9.999999999999996, 8.660254037844386, 0.0),Geom::Point3d.new(5.176380902050416, 9.659258262890681, 0.0),Geom::Point3d.new(-8.881784197001252e-16, 10.0, 0.0),Geom::Point3d.new(-5.176380902050413, 9.659258262890683, 0.0),Geom::Point3d.new(-9.999999999999993, 8.660254037844387, 0.0),Geom::Point3d.new(-14.142135623730944, 7.0710678118654755, 0.0),Geom::Point3d.new(-17.320508075688764, 5.0000000000000036, 0.0),Geom::Point3d.new(-19.318516525781362, 2.58819045102521, 0.0),Geom::Point3d.new(-19.99999999999999, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-19.318516525781366, -2.5881904510252034, 0.0),Geom::Point3d.new(-17.320508075688767, -4.999999999999998, 0.0),Geom::Point3d.new(-14.142135623730951, -7.071067811865471, 0.0),Geom::Point3d.new(-10.000000000000004, -8.660254037844384, 0.0),Geom::Point3d.new(-5.176380902050431, -9.659258262890681, 0.0),Geom::Point3d.new(-5.329070518200751e-15, -10.0, 0.0),Geom::Point3d.new(5.1763809020504015, -9.659258262890685, 0.0),Geom::Point3d.new(9.999999999999979, -8.66025403784439, 0.0),Geom::Point3d.new(14.142135623730937, -7.071067811865477, 0.0),Geom::Point3d.new(17.320508075688753, -5.000000000000004, 0.0),Geom::Point3d.new(19.31851652578135, -2.588190451025216, 0.0),Geom::Point3d.new(19.99999999999998, 0.0, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 45°
    @ellipse_x0_y0_xr20_yr20_a45 = [
      Geom::Point3d.new(14.142135623730933, 14.142135623730937, 0.0),Geom::Point3d.new(11.830127018922186, 15.490381056766577, 0.0),Geom::Point3d.new(8.711914807983142, 15.782982619848617, 0.0),Geom::Point3d.new(4.9999999999999885, 14.999999999999993, 0.0),Geom::Point3d.new(0.9473434549075259, 13.194792168823417, 0.0),Geom::Point3d.new(-3.1698729810778064, 10.490381056766578, 0.0),Geom::Point3d.new(-7.071067811865477, 7.071067811865474, 0.0),Geom::Point3d.new(-10.49038105676658, 3.1698729810778064, 0.0),Geom::Point3d.new(-13.194792168823417, -0.9473434549075259, 0.0),Geom::Point3d.new(-14.999999999999995, -4.9999999999999964, 0.0),Geom::Point3d.new(-15.782982619848626, -8.711914807983147, 0.0),Geom::Point3d.new(-15.490381056766577, -11.830127018922191, 0.0),Geom::Point3d.new(-14.142135623730944, -14.142135623730944, 0.0),Geom::Point3d.new(-11.830127018922195, -15.490381056766578, 0.0),Geom::Point3d.new(-8.711914807983149, -15.782982619848626, 0.0),Geom::Point3d.new(-5.000000000000001, -15.0, 0.0),Geom::Point3d.new(-0.947343454907533, -13.194792168823422, 0.0),Geom::Point3d.new(3.1698729810777957, -10.490381056766589, 0.0),Geom::Point3d.new(7.071067811865472, -7.071067811865479, 0.0),Geom::Point3d.new(10.490381056766571, -3.169872981077816, 0.0),Geom::Point3d.new(13.19479216882341, 0.9473434549075135, 0.0),Geom::Point3d.new(14.999999999999991, 4.999999999999991, 0.0),Geom::Point3d.new(15.78298261984862, 8.711914807983138, 0.0),Geom::Point3d.new(15.490381056766575, 11.83012701892218, 0.0),Geom::Point3d.new(14.142135623730933, 14.142135623730937, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 90°
    @ellipse_x0_y0_xr20_yr20_a90 = [
      Geom::Point3d.new(-7.105427357601002e-15, 19.999999999999982, 0.0),Geom::Point3d.new(-2.5881904510252145, 19.31851652578136, 0.0),Geom::Point3d.new(-5.000000000000005, 17.320508075688753, 0.0),Geom::Point3d.new(-7.071067811865482, 14.142135623730937, 0.0),Geom::Point3d.new(-8.66025403784439, 9.999999999999993, 0.0),Geom::Point3d.new(-9.659258262890685, 5.176380902050413, 0.0),Geom::Point3d.new(-10.0, -5.329070518200751e-15, 0.0),Geom::Point3d.new(-9.659258262890681, -5.176380902050417, 0.0),Geom::Point3d.new(-8.660254037844386, -9.999999999999998, 0.0),Geom::Point3d.new(-7.071067811865471, -14.14213562373095, 0.0),Geom::Point3d.new(-4.9999999999999964, -17.320508075688764, 0.0),Geom::Point3d.new(-2.588190451025203, -19.318516525781366, 0.0),Geom::Point3d.new(7.105427357601002e-15, -19.999999999999993, 0.0),Geom::Point3d.new(2.5881904510252127, -19.318516525781366, 0.0),Geom::Point3d.new(5.000000000000005, -17.320508075688767, 0.0),Geom::Point3d.new(7.071067811865476, -14.142135623730951, 0.0),Geom::Point3d.new(8.660254037844387, -10.0, 0.0),Geom::Point3d.new(9.659258262890683, -5.176380902050427, 0.0),Geom::Point3d.new(10.000000000000002, -1.7763568394002505e-15, 0.0),Geom::Point3d.new(9.659258262890685, 5.176380902050408, 0.0),Geom::Point3d.new(8.660254037844387, 9.999999999999982, 0.0),Geom::Point3d.new(7.071067811865473, 14.14213562373094, 0.0),Geom::Point3d.new(5.0, 17.32050807568876, 0.0),Geom::Point3d.new(2.5881904510252083, 19.318516525781355, 0.0),Geom::Point3d.new(-7.105427357601002e-15, 19.999999999999982, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20mm
    # - yradius = 10mm
    # - angle = 45°
    @ellipse_x0_y0_xr20mm_yr20mm_a45 = [
      Geom::Point3d.new(0.5567769930602741, 0.5567769930602743, 0.0),Geom::Point3d.new(0.4657530322410317, 0.6098575219199448, 0.0),Geom::Point3d.new(0.3429887719678407, 0.6213772684979774, 0.0),Geom::Point3d.new(0.19685039370078738, 0.5905511811023623, 0.0),Geom::Point3d.new(0.03729698641368287, 0.5194800066465914, 0.0),Geom::Point3d.new(-0.12479814886133055, 0.4130071282191567, 0.0),Geom::Point3d.new(-0.27838849653013653, 0.2783884965301365, 0.0),Geom::Point3d.new(-0.4130071282191565, 0.12479814886133059, 0.0),Geom::Point3d.new(-0.5194800066465913, -0.03729698641368294, 0.0),Geom::Point3d.new(-0.5905511811023619, -0.19685039370078752, 0.0),Geom::Point3d.new(-0.6213772684979773, -0.3429887719678407, 0.0),Geom::Point3d.new(-0.6098575219199446, -0.46575303224103193, 0.0),Geom::Point3d.new(-0.5567769930602742, -0.5567769930602743, 0.0),Geom::Point3d.new(-0.4657530322410319, -0.6098575219199447, 0.0),Geom::Point3d.new(-0.3429887719678407, -0.6213772684979775, 0.0),Geom::Point3d.new(-0.19685039370078775, -0.590551181102362, 0.0),Geom::Point3d.new(-0.037296986413683036, -0.5194800066465917, 0.0),Geom::Point3d.new(0.12479814886133006, -0.41300712821915686, 0.0),Geom::Point3d.new(0.2783884965301364, -0.27838849653013653, 0.0),Geom::Point3d.new(0.41300712821915625, -0.12479814886133071, 0.0),Geom::Point3d.new(0.5194800066465911, 0.03729698641368251, 0.0),Geom::Point3d.new(0.5905511811023618, 0.1968503937007875, 0.0),Geom::Point3d.new(0.6213772684979771, 0.3429887719678405, 0.0),Geom::Point3d.new(0.6098575219199447, 0.46575303224103176, 0.0),Geom::Point3d.new(0.5567769930602741, 0.5567769930602743, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 10.5
    # - yradius = 10
    # - angle = 0
    @ellipse_x0_y0_xr10_5_yr10_a0 = [
      Geom::Point3d.new(10.500000000000002, 0.0, 0.0),Geom::Point3d.new(10.142221176035218, 2.5881904510252074, 0.0),Geom::Point3d.new(9.093266739736611, 4.999999999999997, 0.0),Geom::Point3d.new(7.424621202458746, 7.0710678118654755, 0.0),Geom::Point3d.new(5.250000000000003, 8.660254037844382, 0.0),Geom::Point3d.new(2.717599973576471, 9.659258262890678, 0.0),Geom::Point3d.new(6.429395695523606e-16, 9.999999999999996, 0.0),Geom::Point3d.new(-2.7175999735764673, 9.65925826289068, 0.0),Geom::Point3d.new(-5.249999999999998, 8.660254037844384, 0.0),Geom::Point3d.new(-7.424621202458745, 7.071067811865476, 0.0),Geom::Point3d.new(-9.09326673973661, 5.0000000000000036, 0.0),Geom::Point3d.new(-10.142221176035218, 2.58819045102521, 0.0),Geom::Point3d.new(-10.500000000000002, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-10.14222117603522, -2.5881904510252034, 0.0),Geom::Point3d.new(-9.093266739736613, -4.9999999999999964, 0.0),Geom::Point3d.new(-7.424621202458751, -7.071067811865472, 0.0),Geom::Point3d.new(-5.250000000000006, -8.66025403784438, 0.0),Geom::Point3d.new(-2.7175999735764766, -9.659258262890678, 0.0),Geom::Point3d.new(-1.928818708657082e-15, -9.999999999999996, 0.0),Geom::Point3d.new(2.7175999735764638, -9.659258262890681, 0.0),Geom::Point3d.new(5.249999999999994, -8.660254037844387, 0.0),Geom::Point3d.new(7.424621202458745, -7.071067811865478, 0.0),Geom::Point3d.new(9.093266739736606, -5.000000000000004, 0.0),Geom::Point3d.new(10.142221176035218, -2.588190451025216, 0.0),Geom::Point3d.new(10.500000000000002, 0.0, 0.0)
    ]

    # -----

    @loop_a = [
      Geom::Point3d.new(0.5391629164487989, 0.2002185585142479, 0.0),Geom::Point3d.new(0.5905511811023626, 0.19685039370078744, 0.0),Geom::Point3d.new(0.5905511811023625, 0.5905511811023625, 0.0),Geom::Point3d.new(0.1968503937007875, 0.5905511811023625, 0.0),Geom::Point3d.new(0.20021855851424797, 0.5391629164487989, 0.0),Geom::Point3d.new(0.21026542272083937, 0.4886539192509763, 0.0),Geom::Point3d.new(0.22681908168846993, 0.43988841245468924, 0.0),Geom::Point3d.new(0.24959629772266206, 0.393700787401575, 0.0),Geom::Point3d.new(0.2782073463420335, 0.3508813271619212, 0.0),Geom::Point3d.new(0.3121626845722255, 0.3121626845722255, 0.0),Geom::Point3d.new(0.3508813271619211, 0.27820734634203353, 0.0),Geom::Point3d.new(0.39370078740157494, 0.24959629772266206, 0.0),Geom::Point3d.new(0.43988841245468924, 0.22681908168846987, 0.0),Geom::Point3d.new(0.48865391925097634, 0.2102654227208393, 0.0)
    ]

    @loop_b = [
      Geom::Point3d.new(0.5391629164, 0.2002185585, 0.0),Geom::Point3d.new(0.4886539192, 0.2102654227, 0.0),Geom::Point3d.new(0.4398884124, 0.2268190816, 0.0),Geom::Point3d.new(0.3937007874, 0.2495962977, 0.0),Geom::Point3d.new(0.3508813271, 0.2782073463, 0.0),Geom::Point3d.new(0.3121626845, 0.3121626845, 0.0),Geom::Point3d.new(0.2782073463, 0.3508813271, 0.0),Geom::Point3d.new(0.2495962977, 0.3937007874, 0.0),Geom::Point3d.new(0.2268190816, 0.4398884124, 0.0),Geom::Point3d.new(0.2102654227, 0.4886539192, 0.0),Geom::Point3d.new(0.2002185585, 0.5391629164, 0.0),Geom::Point3d.new(0.1968503937, 0.5905511811, 0.0),Geom::Point3d.new(0.5905511811, 0.5905511811, 0.0),Geom::Point3d.new(0.5905511811, 0.1968503937, 0.0)
    ]

  end

  def test_ellipse_finder

    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@circle_x0_y0_r10)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(10, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(0.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(true, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @circle_x0_y0_r10, 'angles (circle_x0_y0_r10)')
    assert_ellipse_include_points(ellipse_def, @circle_x0_y0_r10, 'ellipse_include_point (circle_x0_y0_r10)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@circle_x10_y5_r10)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(10, ellipse_def.center.x, EPSI, 'center.x')
    assert_in_epsilon(5, ellipse_def.center.y, EPSI, 'center.y')
    assert_in_epsilon(10, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(0.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(true, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @circle_x10_y5_r10, 'angles (circle_x10_y5_r10)')
    assert_ellipse_include_points(ellipse_def, @circle_x10_y5_r10, 'ellipse_include_point (circle_x10_y5_r10)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20_yr20_a0)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(0.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20_yr20_a0, 'angles (ellipse_x0_y0_xr20_yr20_a0)')
    assert_ellipse_include_points(ellipse_def, @ellipse_x0_y0_xr20_yr20_a0, 'ellipse_include_point (ellipse_x0_y0_xr20_yr20_a0)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20_yr20_a45)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(45.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20_yr20_a45, 'angles (ellipse_x0_y0_xr20_yr20_a45)')
    assert_ellipse_include_points(ellipse_def, @ellipse_x0_y0_xr20_yr20_a45, 'ellipse_include_point (ellipse_x0_y0_xr20_yr20_a45)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20_yr20_a90)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(90.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20_yr20_a90, 'angles (ellipse_x0_y0_xr20_yr20_a90)')
    assert_ellipse_include_points(ellipse_def, @ellipse_x0_y0_xr20_yr20_a90, 'ellipse_include_point (ellipse_x0_y0_xr20_yr20_a90)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr20mm_yr20mm_a45)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(20.mm, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10.mm, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(45.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr20mm_yr20mm_a45, 'angles (ellipse_x0_y0_xr20mm_yr20mm_a45)')
    assert_ellipse_include_points(ellipse_def, @ellipse_x0_y0_xr20mm_yr20mm_a45, 'ellipse_include_point (ellipse_x0_y0_xr20mm_yr20mm_a45)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr10_5_yr10_a0)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(10.5, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(0.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr10_5_yr10_a0, 'angles (ellipse_x0_y0_xr10_5_yr10_a0)')
    assert_ellipse_include_points(ellipse_def, @ellipse_x0_y0_xr10_5_yr10_a0, 'ellipse_include_point (ellipse_x0_y0_xr10_5_yr10_a0)')


    ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(@ellipse_x0_y0_xr10_5_yr10_a0)

    assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)
    assert_in_epsilon(10.5, ellipse_def.xradius, EPSI, 'xradius')
    assert_in_epsilon(10, ellipse_def.yradius, EPSI, 'yradius')
    assert_in_delta(0.degrees, ellipse_def.angle, EPSI, 'angle')
    assert_equal(false, ellipse_def.circular?, 'circular?')
    assert_angles(ellipse_def, @ellipse_x0_y0_xr10_5_yr10_a0, 'angles (ellipse_x0_y0_xr10_5_yr10_a0)')
    assert_ellipse_include_points(ellipse_def, @ellipse_x0_y0_xr10_5_yr10_a0, 'ellipse_include_point (ellipse_x0_y0_xr10_5_yr10_a0)')

  end

  def test_loop_finder

    loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(@circle_x0_y0_r10)

    assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)
    assert_equal(1, loop_def.portions.count)
    assert_equal(true, loop_def.ellipse?, 'ellipse?')
    assert_equal(true, loop_def.circle?, 'circle?')


    loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(@ellipse_x0_y0_xr20mm_yr20mm_a45)

    assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)
    assert_equal(1, loop_def.portions.count)
    assert_equal(true, loop_def.ellipse?, 'ellipse?')
    assert_equal(false, loop_def.circle?, 'circle?')


    loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(@loop_a)

    assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)
    assert_equal(3, loop_def.portions.count)
    assert_equal(false, loop_def.ellipse?, 'ellipse?')
    assert_equal(false, loop_def.circle?, 'circle?')


    loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(@loop_a.reverse)

    assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)
    assert_equal(3, loop_def.portions.count)
    assert_equal(false, loop_def.ellipse?, 'ellipse?')
    assert_equal(false, loop_def.circle?, 'circle?')


    loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(@loop_b)

    assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)
    assert_equal(3, loop_def.portions.count)
    assert_equal(false, loop_def.ellipse?, 'ellipse?')
    assert_equal(false, loop_def.circle?, 'circle?')

    loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(@loop_b.reverse)

    assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)
    assert_equal(3, loop_def.portions.count)
    assert_equal(false, loop_def.ellipse?, 'ellipse?')
    assert_equal(false, loop_def.circle?, 'circle?')

  end

  private

  def assert_angles(ellipse_def, points, msg = nil)
    points.each_with_index do |point, index|
      angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, point)
      point_at_angle = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_point_at_angle(ellipse_def, angle_at_point)
      assert_equal(point, point_at_angle, msg + " index=#{index} angle=#{angle_at_point.radians.round(6)}°")
    end
  end

  def assert_ellipse_include_points(ellipse_def, points, msg = "")
    points.each_with_index do |point, index|
      assert_equal(true, Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_include_point?(ellipse_def, point), [ msg, "index=#{index}" ].join(' ') )
    end
  end

end
