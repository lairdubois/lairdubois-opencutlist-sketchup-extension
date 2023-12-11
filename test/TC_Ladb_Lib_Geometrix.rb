require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/lib/geometrix/geometrix'

class TC_Ladb_Lib_Geometrix < TestUp::TestCase

  DELTA = 1e-6

  def setup

    # Code to use in console to retrieve points from selected loop in SketchUp
    # Sketchup.active_model.selection.first.outer_loop.vertices.map { |vertex| "Geom::Point3d.new(#{vertex.position.to_a.join(', ')})" }.join(',')

    # Code to use in console to draw points
    # Sketchup.active_model.entities.add_edges(POINTS)

    @tx10_ty_5 = Geom::Transformation.translation(Geom::Vector3d.new(10, 5))

    # Triangle
    @triangle = [
      Geom::Point3d.new(0.0, 0.0, 0.0),Geom::Point3d.new(10.0, 0.0, 0.0),Geom::Point3d.new(0.0, 20.0, 0.0),
    ]

    # Circle
    # - center = 0,0
    # - radius = 10
    @circle_x0_y0_r10 = [
      Geom::Point3d.new(10.0, 0.0, 0.0),Geom::Point3d.new(9.659258262890683, 2.5881904510252074, 0.0),Geom::Point3d.new(8.660254037844387, 4.999999999999999, 0.0),Geom::Point3d.new(7.0710678118654755, 7.071067811865475, 0.0),Geom::Point3d.new(5.000000000000001, 8.660254037844386, 0.0),Geom::Point3d.new(2.5881904510252096, 9.659258262890681, 0.0),Geom::Point3d.new(6.123233995736766e-16, 10.0, 0.0),Geom::Point3d.new(-2.5881904510252065, 9.659258262890683, 0.0),Geom::Point3d.new(-4.999999999999998, 8.660254037844387, 0.0),Geom::Point3d.new(-7.071067811865475, 7.0710678118654755, 0.0),Geom::Point3d.new(-8.660254037844386, 5.0000000000000036, 0.0),Geom::Point3d.new(-9.659258262890681, 2.58819045102521, 0.0),Geom::Point3d.new(-10.0, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-9.659258262890685, -2.5881904510252034, 0.0),Geom::Point3d.new(-8.660254037844389, -4.999999999999998, 0.0),Geom::Point3d.new(-7.071067811865479, -7.071067811865471, 0.0),Geom::Point3d.new(-5.000000000000004, -8.660254037844384, 0.0),Geom::Point3d.new(-2.5881904510252154, -9.659258262890681, 0.0),Geom::Point3d.new(-1.8369701987210296e-15, -10.0, 0.0),Geom::Point3d.new(2.588190451025203, -9.659258262890685, 0.0),Geom::Point3d.new(4.999999999999993, -8.66025403784439, 0.0),Geom::Point3d.new(7.071067811865474, -7.071067811865477, 0.0),Geom::Point3d.new(8.660254037844384, -5.000000000000004, 0.0),Geom::Point3d.new(9.659258262890681, -2.588190451025216, 0.0)
    ]
    @circle_x10_y5_r10 = @circle_x0_y0_r10.map { |point| point.transform(@tx10_ty_5) }

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 0°
    @ellipse_x0_y0_xr20_yr10_a0 = [
      Geom::Point3d.new(19.99999999999998, 0.0, 0.0),Geom::Point3d.new(19.318516525781355, 2.5881904510252074, 0.0),Geom::Point3d.new(17.320508075688757, 4.999999999999999, 0.0),Geom::Point3d.new(14.142135623730937, 7.071067811865475, 0.0),Geom::Point3d.new(9.999999999999996, 8.660254037844386, 0.0),Geom::Point3d.new(5.176380902050416, 9.659258262890681, 0.0),Geom::Point3d.new(-8.881784197001252e-16, 10.0, 0.0),Geom::Point3d.new(-5.176380902050413, 9.659258262890683, 0.0),Geom::Point3d.new(-9.999999999999993, 8.660254037844387, 0.0),Geom::Point3d.new(-14.142135623730944, 7.0710678118654755, 0.0),Geom::Point3d.new(-17.320508075688764, 5.0000000000000036, 0.0),Geom::Point3d.new(-19.318516525781362, 2.58819045102521, 0.0),Geom::Point3d.new(-19.99999999999999, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-19.318516525781366, -2.5881904510252034, 0.0),Geom::Point3d.new(-17.320508075688767, -4.999999999999998, 0.0),Geom::Point3d.new(-14.142135623730951, -7.071067811865471, 0.0),Geom::Point3d.new(-10.000000000000004, -8.660254037844384, 0.0),Geom::Point3d.new(-5.176380902050431, -9.659258262890681, 0.0),Geom::Point3d.new(-5.329070518200751e-15, -10.0, 0.0),Geom::Point3d.new(5.1763809020504015, -9.659258262890685, 0.0),Geom::Point3d.new(9.999999999999979, -8.66025403784439, 0.0),Geom::Point3d.new(14.142135623730937, -7.071067811865477, 0.0),Geom::Point3d.new(17.320508075688753, -5.000000000000004, 0.0),Geom::Point3d.new(19.31851652578135, -2.588190451025216, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 45°
    @ellipse_x0_y0_xr20_yr10_a45 = [
      Geom::Point3d.new(14.142135623730933, 14.142135623730937, 0.0),Geom::Point3d.new(11.830127018922186, 15.490381056766577, 0.0),Geom::Point3d.new(8.711914807983142, 15.782982619848617, 0.0),Geom::Point3d.new(4.9999999999999885, 14.999999999999993, 0.0),Geom::Point3d.new(0.9473434549075259, 13.194792168823417, 0.0),Geom::Point3d.new(-3.1698729810778064, 10.490381056766578, 0.0),Geom::Point3d.new(-7.071067811865477, 7.071067811865474, 0.0),Geom::Point3d.new(-10.49038105676658, 3.1698729810778064, 0.0),Geom::Point3d.new(-13.194792168823417, -0.9473434549075259, 0.0),Geom::Point3d.new(-14.999999999999995, -4.9999999999999964, 0.0),Geom::Point3d.new(-15.782982619848626, -8.711914807983147, 0.0),Geom::Point3d.new(-15.490381056766577, -11.830127018922191, 0.0),Geom::Point3d.new(-14.142135623730944, -14.142135623730944, 0.0),Geom::Point3d.new(-11.830127018922195, -15.490381056766578, 0.0),Geom::Point3d.new(-8.711914807983149, -15.782982619848626, 0.0),Geom::Point3d.new(-5.000000000000001, -15.0, 0.0),Geom::Point3d.new(-0.947343454907533, -13.194792168823422, 0.0),Geom::Point3d.new(3.1698729810777957, -10.490381056766589, 0.0),Geom::Point3d.new(7.071067811865472, -7.071067811865479, 0.0),Geom::Point3d.new(10.490381056766571, -3.169872981077816, 0.0),Geom::Point3d.new(13.19479216882341, 0.9473434549075135, 0.0),Geom::Point3d.new(14.999999999999991, 4.999999999999991, 0.0),Geom::Point3d.new(15.78298261984862, 8.711914807983138, 0.0),Geom::Point3d.new(15.490381056766575, 11.83012701892218, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20
    # - yradius = 10
    # - angle = 90°
    @ellipse_x0_y0_xr20_yr10_a90 = [
      Geom::Point3d.new(-7.105427357601002e-15, 19.999999999999982, 0.0),Geom::Point3d.new(-2.5881904510252145, 19.31851652578136, 0.0),Geom::Point3d.new(-5.000000000000005, 17.320508075688753, 0.0),Geom::Point3d.new(-7.071067811865482, 14.142135623730937, 0.0),Geom::Point3d.new(-8.66025403784439, 9.999999999999993, 0.0),Geom::Point3d.new(-9.659258262890685, 5.176380902050413, 0.0),Geom::Point3d.new(-10.0, -5.329070518200751e-15, 0.0),Geom::Point3d.new(-9.659258262890681, -5.176380902050417, 0.0),Geom::Point3d.new(-8.660254037844386, -9.999999999999998, 0.0),Geom::Point3d.new(-7.071067811865471, -14.14213562373095, 0.0),Geom::Point3d.new(-4.9999999999999964, -17.320508075688764, 0.0),Geom::Point3d.new(-2.588190451025203, -19.318516525781366, 0.0),Geom::Point3d.new(7.105427357601002e-15, -19.999999999999993, 0.0),Geom::Point3d.new(2.5881904510252127, -19.318516525781366, 0.0),Geom::Point3d.new(5.000000000000005, -17.320508075688767, 0.0),Geom::Point3d.new(7.071067811865476, -14.142135623730951, 0.0),Geom::Point3d.new(8.660254037844387, -10.0, 0.0),Geom::Point3d.new(9.659258262890683, -5.176380902050427, 0.0),Geom::Point3d.new(10.000000000000002, -1.7763568394002505e-15, 0.0),Geom::Point3d.new(9.659258262890685, 5.176380902050408, 0.0),Geom::Point3d.new(8.660254037844387, 9.999999999999982, 0.0),Geom::Point3d.new(7.071067811865473, 14.14213562373094, 0.0),Geom::Point3d.new(5.0, 17.32050807568876, 0.0),Geom::Point3d.new(2.5881904510252083, 19.318516525781355, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 20mm
    # - yradius = 10mm
    # - angle = 45°
    @ellipse_x0_y0_xr20mm_yr10mm_a45 = [
      Geom::Point3d.new(0.5567769930602741, 0.5567769930602743, 0.0),Geom::Point3d.new(0.4657530322410317, 0.6098575219199448, 0.0),Geom::Point3d.new(0.3429887719678407, 0.6213772684979774, 0.0),Geom::Point3d.new(0.19685039370078738, 0.5905511811023623, 0.0),Geom::Point3d.new(0.03729698641368287, 0.5194800066465914, 0.0),Geom::Point3d.new(-0.12479814886133055, 0.4130071282191567, 0.0),Geom::Point3d.new(-0.27838849653013653, 0.2783884965301365, 0.0),Geom::Point3d.new(-0.4130071282191565, 0.12479814886133059, 0.0),Geom::Point3d.new(-0.5194800066465913, -0.03729698641368294, 0.0),Geom::Point3d.new(-0.5905511811023619, -0.19685039370078752, 0.0),Geom::Point3d.new(-0.6213772684979773, -0.3429887719678407, 0.0),Geom::Point3d.new(-0.6098575219199446, -0.46575303224103193, 0.0),Geom::Point3d.new(-0.5567769930602742, -0.5567769930602743, 0.0),Geom::Point3d.new(-0.4657530322410319, -0.6098575219199447, 0.0),Geom::Point3d.new(-0.3429887719678407, -0.6213772684979775, 0.0),Geom::Point3d.new(-0.19685039370078775, -0.590551181102362, 0.0),Geom::Point3d.new(-0.037296986413683036, -0.5194800066465917, 0.0),Geom::Point3d.new(0.12479814886133006, -0.41300712821915686, 0.0),Geom::Point3d.new(0.2783884965301364, -0.27838849653013653, 0.0),Geom::Point3d.new(0.41300712821915625, -0.12479814886133071, 0.0),Geom::Point3d.new(0.5194800066465911, 0.03729698641368251, 0.0),Geom::Point3d.new(0.5905511811023618, 0.1968503937007875, 0.0),Geom::Point3d.new(0.6213772684979771, 0.3429887719678405, 0.0),Geom::Point3d.new(0.6098575219199447, 0.46575303224103176, 0.0)
    ]

    # Ellipse
    # - center = 0,0
    # - xradius = 10.5
    # - yradius = 10
    # - angle = 0
    @ellipse_x0_y0_xr10_5_yr10_a0 = [
      Geom::Point3d.new(10.500000000000002, 0.0, 0.0),Geom::Point3d.new(10.142221176035218, 2.5881904510252074, 0.0),Geom::Point3d.new(9.093266739736611, 4.999999999999997, 0.0),Geom::Point3d.new(7.424621202458746, 7.0710678118654755, 0.0),Geom::Point3d.new(5.250000000000003, 8.660254037844382, 0.0),Geom::Point3d.new(2.717599973576471, 9.659258262890678, 0.0),Geom::Point3d.new(6.429395695523606e-16, 9.999999999999996, 0.0),Geom::Point3d.new(-2.7175999735764673, 9.65925826289068, 0.0),Geom::Point3d.new(-5.249999999999998, 8.660254037844384, 0.0),Geom::Point3d.new(-7.424621202458745, 7.071067811865476, 0.0),Geom::Point3d.new(-9.09326673973661, 5.0000000000000036, 0.0),Geom::Point3d.new(-10.142221176035218, 2.58819045102521, 0.0),Geom::Point3d.new(-10.500000000000002, 1.2246467991473533e-15, 0.0),Geom::Point3d.new(-10.14222117603522, -2.5881904510252034, 0.0),Geom::Point3d.new(-9.093266739736613, -4.9999999999999964, 0.0),Geom::Point3d.new(-7.424621202458751, -7.071067811865472, 0.0),Geom::Point3d.new(-5.250000000000006, -8.66025403784438, 0.0),Geom::Point3d.new(-2.7175999735764766, -9.659258262890678, 0.0),Geom::Point3d.new(-1.928818708657082e-15, -9.999999999999996, 0.0),Geom::Point3d.new(2.7175999735764638, -9.659258262890681, 0.0),Geom::Point3d.new(5.249999999999994, -8.660254037844387, 0.0),Geom::Point3d.new(7.424621202458745, -7.071067811865478, 0.0),Geom::Point3d.new(9.093266739736606, -5.000000000000004, 0.0),Geom::Point3d.new(10.142221176035218, -2.588190451025216, 0.0)
    ]

    # -----

    @loop_a = [
      Geom::Point3d.new(0.5391629164487989, 0.2002185585142479, 0.0),Geom::Point3d.new(0.5905511811023626, 0.19685039370078744, 0.0),Geom::Point3d.new(0.5905511811023625, 0.5905511811023625, 0.0),Geom::Point3d.new(0.1968503937007875, 0.5905511811023625, 0.0),Geom::Point3d.new(0.20021855851424797, 0.5391629164487989, 0.0),Geom::Point3d.new(0.21026542272083937, 0.4886539192509763, 0.0),Geom::Point3d.new(0.22681908168846993, 0.43988841245468924, 0.0),Geom::Point3d.new(0.24959629772266206, 0.393700787401575, 0.0),Geom::Point3d.new(0.2782073463420335, 0.3508813271619212, 0.0),Geom::Point3d.new(0.3121626845722255, 0.3121626845722255, 0.0),Geom::Point3d.new(0.3508813271619211, 0.27820734634203353, 0.0),Geom::Point3d.new(0.39370078740157494, 0.24959629772266206, 0.0),Geom::Point3d.new(0.43988841245468924, 0.22681908168846987, 0.0),Geom::Point3d.new(0.48865391925097634, 0.2102654227208393, 0.0)
    ]

    @loop_b = [
      Geom::Point3d.new(0.5391629164, 0.2002185585, 0.0),Geom::Point3d.new(0.4886539192, 0.2102654227, 0.0),Geom::Point3d.new(0.4398884124, 0.2268190816, 0.0),Geom::Point3d.new(0.3937007874, 0.2495962977, 0.0),Geom::Point3d.new(0.3508813271, 0.2782073463, 0.0),Geom::Point3d.new(0.3121626845, 0.3121626845, 0.0),Geom::Point3d.new(0.2782073463, 0.3508813271, 0.0),Geom::Point3d.new(0.2495962977, 0.3937007874, 0.0),Geom::Point3d.new(0.2268190816, 0.4398884124, 0.0),Geom::Point3d.new(0.2102654227, 0.4886539192, 0.0),Geom::Point3d.new(0.2002185585, 0.5391629164, 0.0),Geom::Point3d.new(0.1968503937, 0.5905511811, 0.0),Geom::Point3d.new(0.5905511811, 0.5905511811, 0.0),Geom::Point3d.new(0.5905511811, 0.1968503937, 0.0)
    ]

    @loop_c = [
      Geom::Point3d.new(26.132672152841984, -0.0003907759169052838, 1.6671440117299596e-08),Geom::Point3d.new(26.131360473960314, 0.0, 2.55351295663786e-15),Geom::Point3d.new(0.0, 0.0, 0.0),Geom::Point3d.new(-1.9410880019776755e-05, -1.2741444460977114, 6.805429186851342e-08),Geom::Point3d.new(34.222029201035234, -5.120675667034186, 1.7077875902327122e-07),Geom::Point3d.new(34.33251941468384, -4.802595152950198, 1.6129617719240485e-07),Geom::Point3d.new(34.42209590488205, -4.525618288978791, 1.5303883038608745e-07),Geom::Point3d.new(34.50640716774462, -4.246983227304566, 1.4473200671272224e-07),Geom::Point3d.new(34.5854227299801, -3.9667906772178747, 1.3637867446458785e-07),Geom::Point3d.new(34.65911403236431, -3.6851419109444152, 1.27981878317307e-07),Geom::Point3d.new(34.72745444006262, -3.4021387270419523, 1.1954466294650246e-07),Geom::Point3d.new(34.790419252257045, -3.1178834136060423, 1.1106996467002972e-07),Geom::Point3d.new(34.84798571107381, -2.832478711299387, 1.0256097382477236e-07),Geom::Point3d.new(34.90013300980903, -2.5460277762175587, 9.402073508635311e-08),Geom::Point3d.new(34.946842300449056, -2.258634142604329, 8.54523197757473e-08),Geom::Point3d.new(34.98809670048281, -1.9704016854304918, 7.685882585928283e-08),Geom::Point3d.new(35.02388129900378, -1.681434582849544, 6.824335307964446e-08),Geom::Point3d.new(35.054183162083156, -1.3918383653735624, 5.9159298682054384e-08),Geom::Point3d.new(35.07899133750964, -1.1017155308190567, 5.0700157738781115e-08),Geom::Point3d.new(35.09829685866675, -0.8111709405483598, 4.2296289914922625e-08),Geom::Point3d.new(35.11209274777365, -0.520311781719835, 3.362412115404112e-08),Geom::Point3d.new(35.12037401848844, -0.2292420950317311, 2.4945614351956635e-08),Geom::Point3d.new(35.122544866402, -0.0005252063238430082, 1.8126171563714877e-08)
    ]

    @loop_d = [
      Geom::Point3d.new(10.46633426, 6.77366297, 0.25000315672548057),Geom::Point3d.new(10.48173769, 6.77450272, 0.25000315672548057),Geom::Point3d.new(10.49216981, 6.77791658, 0.25000315672548057),Geom::Point3d.new(10.49724427, 6.77957718, 0.25000315672548057),Geom::Point3d.new(10.51090911, 6.78849214, 0.25000315672548057),Geom::Point3d.new(10.52180098, 6.80064005, 0.25000315672548057),Geom::Point3d.new(10.5291776, 6.81519305, 0.25000315672548057),Geom::Point3d.new(10.53253628, 6.83115938, 0.25000315672548057),Geom::Point3d.new(10.53164813, 6.84745096, 0.25000315672548057),Geom::Point3d.new(10.52657366, 6.86295755, 0.25000315672548057),Geom::Point3d.new(10.5176587, 6.8766224, 0.25000315672548057),Geom::Point3d.new(10.50551079, 6.88751426, 0.25000315672548057),Geom::Point3d.new(10.49095779, 6.89489089, 0.25000315672548057),Geom::Point3d.new(10.47499146, 6.89824957, 0.25000315672548057),Geom::Point3d.new(10.45869988, 6.89736141, 0.25000315672548057),Geom::Point3d.new(10.44319329, 6.89228694, 0.25000315672548057),Geom::Point3d.new(10.42952844, 6.88337199, 0.25000315672548057),Geom::Point3d.new(10.41863657, 6.87122408, 0.25000315672548057),Geom::Point3d.new(10.41125995, 6.85667107, 0.25000315672548057),Geom::Point3d.new(10.40790127, 6.84070474, 0.25000315672548057),Geom::Point3d.new(10.40878943, 6.82441316, 0.25000315672548057),Geom::Point3d.new(10.41386389, 6.80890657, 0.25000315672548057),Geom::Point3d.new(10.42277885, 6.79524173, 0.25000315672548057),Geom::Point3d.new(10.43492676, 6.78434986, 0.25000315672548057),Geom::Point3d.new(10.44947976, 6.77697323, 0.25000315672548057),Geom::Point3d.new(10.4654461, 6.77361456, 0.25000315672548057)
    ]

  end

  def test_ellipse_finder

    assert_not_ellipse(@triangle, 'triangle')

    assert_ellipse(@circle_x0_y0_r10, 0, 0, 10, 10, 0, true, 'circle_x0_y0_r10')
    assert_ellipse(@circle_x10_y5_r10, 10, 5, 10, 10, 0, true, 'circle_x10_y5_r10')
    assert_ellipse(@ellipse_x0_y0_xr20_yr10_a0, 0, 0, 20, 10, 0, false, 'ellipse_x0_y0_xr20_yr20_a0')
    assert_ellipse(@ellipse_x0_y0_xr20_yr10_a45, 0, 0, 20, 10, 45, false, 'ellipse_x0_y0_xr20_yr20_a45')
    assert_ellipse(@ellipse_x0_y0_xr20mm_yr10mm_a45, 0, 0, 20.mm, 10.mm, 45, false, 'ellipse_x0_y0_xr20mm_yr10mm_a45')
    assert_ellipse(@ellipse_x0_y0_xr10_5_yr10_a0, 0, 0, 10.5, 10, 0, false, 'ellipse_x0_y0_xr10_5_yr10_a0')

  end

  def test_loop_finder

    assert_loop(@triangle, 3, false, false, 'triangle')
    assert_loop(@circle_x0_y0_r10, 1, true, true, 'circle_x0_y0_r10')
    assert_loop(@ellipse_x0_y0_xr20mm_yr10mm_a45, 1, true, false, 'ellipse_x0_y0_xr20mm_yr20mm_a45')
    assert_loop(@loop_a, 3, false, false, 'loop_a')
    assert_loop(@loop_a.reverse, 3, false, false, 'loop_a.reverse')
    assert_loop(@loop_b, 3, false, false, 'loop_b')
    assert_loop(@loop_b.reverse, 3, false, false, 'loop_b.reverse')
    assert_loop(@loop_c, 7, false, false, 'loop_c')
    assert_loop(@loop_d, nil, nil, nil, 'loop_d')  # This loop doesn't returns unique arc portion if starts at index 22

  end

  private

  def assert_angles(ellipse_def, points, msg = nil)
    points.each_with_index do |point, index|
      angle_at_point = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_angle_at_point(ellipse_def, point)
      point_at_angle = Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_point_at_angle(ellipse_def, angle_at_point)
      assert_equal(point, point_at_angle, msg + " index=#{index} angle=#{angle_at_point.radians.round(6)}°")
    end
  end

  def assert_ellipse_include_points(ellipse_def, points, msg = '')
    points.each_with_index do |point, index|
      assert_equal(true, Ladb::OpenCutList::Geometrix::EllipseFinder.ellipse_include_point?(ellipse_def, point), [ msg, "index=#{index}" ].join(' ') )
    end
  end

  def assert_not_ellipse(points, msg = '')

    points.count.times do |index|

      prefix = "#{msg} index=#{index}"
      pts = points.rotate(index)

      ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(pts)

      assert_nil(ellipse_def, prefix)

    end

  end

  def assert_ellipse(points, center_x, center_y, xradius, yradius, angle, is_circular, msg = '')

    points.count.times do |index|

      prefix = "#{msg} index=#{index}"
      pts = points.rotate(index)

      ellipse_def = Ladb::OpenCutList::Geometrix::EllipseFinder.find_ellipse_def(pts)

      assert_instance_of(Ladb::OpenCutList::Geometrix::EllipseDef, ellipse_def)

      assert_in_delta(center_x, ellipse_def.center.x, DELTA, "#{prefix} center.x")
      assert_in_delta(center_y, ellipse_def.center.y, DELTA, "#{prefix} center.y")

      assert_in_delta(xradius, ellipse_def.xradius, DELTA, "#{prefix} xradius")
      assert_in_delta(yradius, ellipse_def.yradius, DELTA, "#{prefix} yradius")

      assert_in_delta(angle.degrees, ellipse_def.angle, DELTA, "#{prefix} angle")

      assert_equal(is_circular, ellipse_def.circular?, "#{prefix} circular?")

      assert_angles(ellipse_def, pts, "#{prefix} angles")
      assert_ellipse_include_points(ellipse_def, pts, "#{prefix} ellipse_include_point")

    end

  end

  def assert_loop(points, portion_count, is_ellipse, is_circle, msg = '')

    points.count.times do |index|

      prefix = "#{msg} index=#{index} point=#{points[index]}"
      pts = points.rotate(index)

      loop_def = Ladb::OpenCutList::Geometrix::LoopFinder.find_loop_def(pts)

      assert_instance_of(Ladb::OpenCutList::Geometrix::LoopDef, loop_def)

      assert_equal(portion_count, loop_def.portions.count, "#{prefix} portions.count") unless portion_count.nil?

      assert_equal(is_ellipse, loop_def.ellipse?, "#{prefix} ellipse?") unless is_ellipse.nil?
      assert_equal(is_circle, loop_def.circle?, "#{prefix} circle?") unless is_circle.nil?

    end

  end

end
