# Probes of the Geom / Length behaviours sketchup_stub.rb stands in for : the
# same expression evaluated in SketchUp and on the stub must print the same
# lines. Their SketchUp answer is stub_probes.expected.txt (SketchUp 2026, 26.2).
#
#   ruby test/headless/check_stub.rb      # the stub against the expected answer
#
# On a new SketchUp version, from its Ruby console or the Claude Bridge :
#   File.write('test/headless/stub_probes.expected.txt', eval(File.read('test/headless/stub_probes.rb')) + "\n")
# then compare with git diff before trusting the stub again.
P = Geom::Point3d; V = Geom::Vector3d
fr = lambda { |v|
  case v
  when Geom::Point3d, Geom::Vector3d then [v.class.name.split('::').last] + v.to_a.map { |x| x.round(9) }
  when Array then v.map { |e| fr.call(e) }
  when Float then v.round(9)
  when Length then ['L', v.to_f.round(9)]
  else v
  end
}
srand(7)
rp = lambda { P.new(rand * 20 - 10, rand * 20 - 10, rand * 20 - 10) }
rv = lambda { V.new(rand * 2 - 1, rand * 2 - 1, rand * 2 - 1) }
o = P.new(0,0,0)
r = []
r << [:classes, [P.new(1,2,3).x.class.name, V.new(1,2,3).x.class.name, o.distance(P.new(1,0,0)).class.name, V.new(1,0,0).length.class.name, V.new(1,0,0).dot(V.new(1,0,0)).class.name, (P.new(1,0,0) - o).class.name, (o - V.new(1,0,0)).class.name, (o + V.new(1,0,0)).class.name, (V.new(1,0,0) * V.new(0,1,0)).class.name, (V.new(1,0,0) - V.new(0,1,0)).class.name, 18.mm.class.name, (18.mm * -1).class.name, (18.mm.abs).class.name]]
[0.00099, 0.00101].each { |d| r << [:pt_eq, d, o == P.new(d,0,0), o == P.new(d/1.5,d/1.5,0)] }
[0.00099, 0.00101].each { |d| r << [:on_plane, d, P.new(5,5,d).on_plane?([o, V.new(0,0,3)]), P.new(5,5,-d).on_plane?([0,0,1,0])] }
[0.00099, 0.00101].each { |d| r << [:on_line, d, P.new(5,d,0).on_line?([o, V.new(2,0,0)]), P.new(5,d,0).on_line?([o, P.new(1,0,0)])] }
[0.00099, 0.00101].each { |a| r << [:parallel, a, V.new(1,0,0).parallel?(V.new(Math.cos(Math.asin(a)), a, 0)), V.new(1,0,0).samedirection?(V.new(-1, a, 0)), V.new(1,0,0).parallel?(V.new(-1, 0, 0))] }
[1e-10 * 0.9, 1e-10 * 1.1].each { |l| r << [:valid, V.new(l,0,0).valid?] }
[0.00099, 0.00101].each { |d| r << [:len, 1.0.to_l == 1.0 + d, 1.0.to_l < 1.0 + d, (1.0.to_l <=> 1.0 + d), 1.0 + d > 1.0.to_l, 0 == (d / 2).to_l, (d / 2).to_l.zero?] }
r << [:axes, [V.new(0,0,1), V.new(1,0,0), V.new(0.01,0.01,1), V.new(0.02,0,1), V.new(0.3,0.4,0.866), V.new(-1,-2,-3)].map { |v| v.axes }]
r << [:offset, o.offset(V.new(0,0,2), 3), o.offset(V.new(0,0,2)), o.offset(V.new(0,0,2), -3)]
r << [:proj, P.new(1,2,3).project_to_plane([P.new(0,0,1), V.new(1,1,2)])]
r << [:normalize, V.new(1e-9,0,0).normalize, V.new(3,4,0).normalize]
40.times { |i|
  a = [rp.call, rv.call]; b = [rp.call, rv.call]
  r << [:ipp, i, Geom.intersect_plane_plane(a, b).nil?]
  l = Geom.intersect_plane_plane(a, b)
  r << [:ipp_on, i, l && l[0].on_plane?(a) && l[0].on_plane?(b), l && l[1].parallel?(a[1] * b[1])]
  c = [rp.call, rv.call]
  r << [:ilp, i, Geom.intersect_line_plane(c, a)]
  d = [c[0].offset(rv.call, 0.0003), rv.call]
  r << [:ill, i, Geom.intersect_line_line(c, [c[0].offset(c[1], 2).offset(rv.call, 0.0004), rv.call]), Geom.intersect_line_line(c, d)]
  t = Geom::Transformation.axes(rp.call, *rv.call.axes)
  r << [:tr, i, P.new(1,2,3).transform(t), P.new(1,2,3).transform(t.inverse), V.new(1,2,3).transform(t), (t * t.inverse).to_a.map { |x| x.round(9) }]
}
rt = Geom::Transformation.rotation(ORIGIN, V.new(1, 2, 3), 0.7)
r << [:rot, P.new(500, 0, 250).transform(rt), Geom::Transformation.scaling(1, 1, -1).to_a, Geom::Transformation.scaling(-1, 1, 1) * P.new(1, 2, 3), Geom::Transformation.translation([0, 0, 5]).to_a]
sq = [P.new(0,0,0),P.new(10,0,0),P.new(10,10,0),P.new(0,10,0)]
r << [:pip, [P.new(5,5,9), P.new(0.0009,5,0), P.new(-0.0009,5,0), P.new(0.0011,5,0), P.new(-0.0011,5,0), P.new(11,5,0)].map { |p| [Geom.point_in_polygon_2D(p, sq, false), Geom.point_in_polygon_2D(p, sq, true)] }]
r << [:lin, Geom.linear_combination(0.25, P.new(0,0,0), 0.75, P.new(4,4,4))]
r.map { |e| fr.call(e).inspect }.join("\n")
