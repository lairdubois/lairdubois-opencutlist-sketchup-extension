Step = Struct.new(:point, :t)
CircleArc = Struct.new(:center, :radius, :start_step, :end_step)
EllipseDef = Struct.new(:center, :xradius, :yradius, :angle)
EllipseArcDef = Struct.new(:ellipse_def, :start_angle, :end_angle)

def point_at_t(ellipse_def, t)
  Geom::Point3d.new(ellipse_def.xradius * Math.cos(t), ellipse_def.yradius * Math.sin(t))
end

def point_and_i_at_dk(ellipse_def, ts, dks, dk)
  i = dks.find_index { |v| v >= dk }
  [ point_at_t(ellipse_def, ts[i]), i ]
end

def curvature_at_t(ellipse_def, t)
  (ellipse_def.xradius * ellipse_def.yradius) / Math.sqrt((ellipse_def.xradius**2 * Math.sin(t)**2 + ellipse_def.yradius**2 * Math.cos(t)**2)**3)
end

def draw_center_radius(center, p1, p2)
  Sketchup.active_model.entities.add_cpoint(center)
  Sketchup.active_model.entities.add_cline(center, p1)
  Sketchup.active_model.entities.add_cline(center, p2)
end

centerx = 0.0
centery = 0.0
xradius = 5.0
yradius = 3.0
angle = 0.0
start_angle = 0.0
end_angle = 360.0
key_count = 100
arc_count = 8

prompts = [ "centerx", "centery", "xradius", "yradius", "angle", "start_angle", "end_angle", "key_count", "arc_count" ]
defaults = [ centerx, centery, xradius, yradius, angle, start_angle, end_angle, key_count, arc_count ]
centerx, centery, xradius, yradius, angle, start_angle, end_angle, key_count, arc_count = UI.inputbox(prompts, defaults, "Settings")

ellipse_def = EllipseDef.new(Geom::Point3d.new(centerx, centery), xradius, yradius, angle)
ellipse_arc_def = EllipseArcDef.new(ellipse_def, start_angle, end_angle)

ts = []
ks = []

# Compute curvature at key points
half_pi = Math::PI / 2
(0..key_count).each do |i|
  t = half_pi * i / key_count
  ts << t
  ks << curvature_at_t(ellipse_def, t)
end

# Integrate
dks = ks.dup
(1...dks.length).each { |i| dks[i] += dks[i - 1] }
max = dks.max
dks.map! { |dk| dk / max }

# Clear model
Sketchup.active_model.entities.clear!

# Compute step points
ps = []
(0..arc_count).each do |v|
  p, i = point_and_i_at_dk(ellipse_def, ts, dks, v / arc_count.to_f)
  ps << Step.new(p, ts[i])
end

# Compute arcs
as = []
ps.each_cons(2) do |step_a, step_b|

  p1 = step_a.point
  p2 = point_at_t(ellipse_def, step_a.t + (step_b.t - step_a.t) / 2)
  p3 = step_b.point

  cx = -((p3.x**2 - p2.x**2 + p3.y**2 - p2.y**2) / (2 * (p3.y - p2.y)) - (p2.x**2 - p1.x**2 + p2.y**2 - p1.y**2) / (2 * (p2.y - p1.y))) / ((p2.x - p1.x) / (p2.y - p1.y) - (p3.x - p2.x) / (p3.y - p2.y))
  cy = -(p2.x - p1.x) / (p2.y - p1.y) * cx + (p2.x**2 - p1.x**2 + p2.y**2 - p1.y**2) / (2 * (p2.y - p1.y))
  center = Geom::Point3d.new(cx, cy)

  radius = (p1 - center).length

  as << CircleArc.new(center, radius, step_a, step_b)
end

as2 = as.dup
t = Geom::Transformation.scaling(ORIGIN, -1.0, 1.0, 1.0)
as.reverse.each do |arc|
  as2 << CircleArc.new(
    arc.center.transform(t),
    arc.radius,
    Step.new(arc.end_step.point.transform(t), arc.end_step.t + Math::PI / 2),
    Step.new(arc.start_step.point.transform(t), arc.start_step.t + Math::PI / 2)
  )
end

as3 = as2.dup
t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, Math::PI)
as2.each do |arc|
  as3 << CircleArc.new(
    arc.center.transform(t),
    arc.radius,
    Step.new(arc.start_step.point.transform(t), arc.start_step.t + Math::PI),
    Step.new(arc.end_step.point.transform(t), arc.end_step.t + Math::PI)
  )
end

transformation = Geom::Transformation.translation(Geom::Vector3d.new(centerx, centery)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, angle.degrees)
as3.each do |arc|
  arc.center = arc.center.transform(transformation)
  arc.start_step.point = arc.start_step.point.transform(transformation)
  arc.end_step.point = arc.end_step.point.transform(transformation)
end

SKETCHUP_CONSOLE.clear
puts "-----"
puts "centerx = #{centerx}"
puts "centery = #{centery}"
puts "xradius = #{xradius}"
puts "yradius = #{yradius}"
puts "angle = #{angle}"
puts "-----"
puts "key_count = #{key_count}"
puts "arc_count = #{arc_count}"
puts "-----"

t_start = ellipse_arc_def.start_angle.degrees
t_end = ellipse_arc_def.end_angle.degrees

start_point = point_at_t(ellipse_def, t_start)
end_point = point_at_t(ellipse_def, t_end)

Sketchup.active_model.entities.add_cline(Geom::Point3d.new(centerx, centery), as.first.start_step.point)
Sketchup.active_model.entities.add_cline(Geom::Point3d.new(centerx, centery), as.last.end_step.point)

start_drawn = false
last_arc = nil
as3.each_with_index do |arc, i|

  next if arc.end_step.t < t_start

  puts "arc #{i} => center = (#{arc.center.x.to_f.round(1)}, #{arc.center.y.to_f.round(1)}) start = (#{arc.start_step.point.x.to_f.round(1)}, #{arc.start_step.point.y.to_f.round(1)}) end = (#{arc.end_step.point.x.to_f.round(1)}, #{arc.end_step.point.y.to_f.round(1)})"

  if start_drawn
    Sketchup.active_model.entities.add_cpoint(arc.start_step.point)
    Sketchup.active_model.entities.add_text("start#{i}", arc.start_step.point, (arc.start_step.point - ORIGIN).normalize)
  else
    Sketchup.active_model.entities.add_cpoint(start_point)
    Sketchup.active_model.entities.add_text("DEBUT", start_point, (start_point - ORIGIN).normalize)
    draw_center_radius(arc.center, start_point, arc.end_step.point)
    start_drawn = true
  end

  draw_center_radius(arc.center, arc.start_step.point, arc.end_step.point)

  if arc.end_step.t >= t_end
    last_arc = arc
    break
  end

end
Sketchup.active_model.entities.add_cpoint(end_point)
Sketchup.active_model.entities.add_text("FIN", end_point, (end_point - ORIGIN).normalize)
draw_center_radius(last_arc.center, last_arc.start_step.point, end_point)
"👍"