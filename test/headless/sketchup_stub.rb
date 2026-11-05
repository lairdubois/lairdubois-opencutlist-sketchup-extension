# A stand-in for the parts of the SketchUp Ruby API that pure geometry code
# uses - Geom, Length, the Numeric unit helpers - to run tests in plain ruby,
# outside SketchUp. NEVER load it inside SketchUp.
#
# Its tolerances are SketchUp's, measured on SketchUp 2026 (26.2) through the
# Claude Bridge, 2026-11-05 :
#   - Point3d#==, #on_plane?, #on_line? : euclidean distance < 0.001" ;
#   - Vector3d#== : same, on the components ;
#   - Vector3d#parallel? / #samedirection? : sine of the angle < 0.001 ;
#   - Vector3d#valid? : length > 1e-10 ;
#   - Geom.intersect_plane_plane : nil when the sine of the angle < 1e-10 ;
#   - Geom.intersect_line_line : nil when the sine of the angle < 1e-5, or
#     when the lines pass farther than 0.001" apart - else the middle of
#     their closest points ;
#   - Geom.intersect_line_plane : nil when |direction · normal| < 1e-6 (unit
#     vectors) ;
#   - Geom.point_in_polygon_2D : z ignored, border within 0.001" ;
#   - Vector3d#axes : x = Y_AXIS * z when z is parallel to Z, else Z_AXIS * z ;
#   - Length : ==, <, <=, >, >=, <=> tolerant to 0.001" ; a Float compared
#     to a Length is not ; any arithmetic gives a Float ; #zero? is exact.
# Point3d#x/y/z, #distance and Vector3d#length are Lengths ; #hash / #eql?
# are by identity.

module Sketchup

  def self.platform
    RUBY_PLATFORM =~ /mswin|mingw/ ? :platform_win : :platform_osx
  end

  def self.version
    '26.2.0'
  end

end

class Length < Numeric

  TOLERANCE = 0.001

  def initialize(value)
    @value = value.to_f
  end

  def to_f
    @value
  end

  def to_l
    self
  end

  def to_mm
    @value * 25.4
  end

  def to_i
    @value.to_i
  end

  def coerce(other)
    [ other.to_f, @value ]
  end

  def ==(other)
    return false unless other.respond_to?(:to_f)
    (@value - other.to_f).abs < TOLERANCE
  end

  def <=>(other)
    return nil unless other.respond_to?(:to_f)
    other = other.to_f
    return 0 if (@value - other).abs < TOLERANCE
    @value <=> other
  end

  def <(other)
    (self <=> other) < 0
  end

  def <=(other)
    (self <=> other) <= 0
  end

  def >(other)
    (self <=> other) > 0
  end

  def >=(other)
    (self <=> other) >= 0
  end

  def zero?
    @value.zero?
  end

  def +(other)
    @value + other.to_f
  end

  def -(other)
    @value - other.to_f
  end

  def *(other)
    @value * other.to_f
  end

  def /(other)
    @value / other.to_f
  end

  def -@
    -@value
  end

  def abs
    @value.abs
  end

  def round(*args)
    @value.round(*args)
  end

  def nan?
    @value.nan?
  end

  def inspect
    "#{@value}\""
  end

  def to_s
    inspect
  end

end

class Numeric

  def to_l
    Length.new(to_f)
  end

  def mm
    Length.new(to_f / 25.4)
  end

  def cm
    Length.new(to_f / 2.54)
  end

  def m
    Length.new(to_f / 0.0254)
  end

  def inch
    Length.new(to_f)
  end

  def to_mm
    to_f * 25.4
  end

  def to_cm
    to_f * 2.54
  end

end

module Geom

  TOLERANCE = 0.001

  # Shared by Point3d and Vector3d - unrelated classes in SketchUp
  module Coordinates

    attr_reader :x_f, :y_f, :z_f

    def initialize(*args)
      args = args.first if args.size == 1
      args = args.to_a if args.respond_to?(:to_a) && !args.is_a?(Array)
      x, y, z = args.empty? ? [ 0, 0, 0 ] : args
      @x_f = x.to_f
      @y_f = y.to_f
      @z_f = (z || 0).to_f
    end

    def to_a
      [ @x_f, @y_f, @z_f ]
    end

    def [](index)
      to_a[index]
    end

    def clone
      self.class.new(@x_f, @y_f, @z_f)
    end

    def ==(other)
      return false unless other.respond_to?(:to_a)
      ox, oy, oz = other.to_a.map(&:to_f)
      Math.sqrt((@x_f - ox)**2 + (@y_f - oy)**2 + (@z_f - (oz || 0.0))**2) < TOLERANCE
    end

  end

  class Point3d

    include Coordinates

    def x; Length.new(@x_f); end
    def y; Length.new(@y_f); end
    def z; Length.new(@z_f); end

    def x=(v); @x_f = v.to_f; end
    def y=(v); @y_f = v.to_f; end
    def z=(v); @z_f = v.to_f; end

    def vector_to(other)
      ox, oy, oz = other.to_a.map(&:to_f)
      Vector3d.new(ox - @x_f, oy - @y_f, oz - @z_f)
    end

    def distance(other)
      Length.new(_distance(other))
    end

    def _distance(other)
      ox, oy, oz = other.to_a.map(&:to_f)
      Math.sqrt((@x_f - ox)**2 + (@y_f - oy)**2 + (@z_f - oz)**2)
    end

    def +(vector)
      vx, vy, vz = vector.to_a.map(&:to_f)
      Point3d.new(@x_f + vx, @y_f + vy, @z_f + vz)
    end

    def -(other)
      ox, oy, oz = other.to_a.map(&:to_f)
      return Point3d.new(@x_f - ox, @y_f - oy, @z_f - oz) if other.is_a?(Vector3d)
      Vector3d.new(@x_f - ox, @y_f - oy, @z_f - oz)
    end

    def offset(vector, length = nil)
      vector = Vector3d.new(vector.to_a) unless vector.is_a?(Vector3d)
      vector = vector.normalize.scale(length.to_f) unless length.nil?
      self + vector
    end

    def transform(transformation)
      transformation = Transformation.new(transformation) unless transformation.is_a?(Transformation)
      Point3d.new(transformation._apply_point(to_a))
    end

    def transform!(transformation)
      @x_f, @y_f, @z_f = transform(transformation).to_a
      self
    end

    def project_to_plane(plane)
      point, normal = Geom._plane(plane)
      Point3d.new(Geom._project_on_plane(to_a, point, normal))
    end

    def distance_to_plane(plane)
      point, normal = Geom._plane(plane)
      Length.new(Geom._dot(Geom._sub(to_a, point), normal).abs)
    end

    def on_plane?(plane)
      point, normal = Geom._plane(plane)
      Geom._dot(Geom._sub(to_a, point), normal).abs < TOLERANCE
    end

    def on_line?(line)
      point, direction = Geom._line(line)
      Geom._distance_to_line(to_a, point, direction) < TOLERANCE
    end

    def inspect
      "Point3d(#{@x_f}, #{@y_f}, #{@z_f})"
    end

    def to_s
      "(#{@x_f}, #{@y_f}, #{@z_f})"
    end

  end

  class Vector3d

    include Coordinates

    def x; @x_f; end
    def y; @y_f; end
    def z; @z_f; end

    def length
      Length.new(_length)
    end

    def _length
      Math.sqrt(@x_f * @x_f + @y_f * @y_f + @z_f * @z_f)
    end

    def valid?
      _length > 1e-10
    end

    def normalize
      length = _length
      raise ArgumentError, 'Cannot normalize a zero length vector' if length <= 1e-10
      inv = 1.0 / length
      Vector3d.new(@x_f * inv, @y_f * inv, @z_f * inv)
    end

    def normalize!
      @x_f, @y_f, @z_f = normalize.to_a
      self
    end

    def unitvector?
      (_length - 1.0).abs < 1e-10
    end

    def scale(factor)
      Vector3d.new(@x_f * factor, @y_f * factor, @z_f * factor)
    end

    def reverse
      Vector3d.new(-@x_f, -@y_f, -@z_f)
    end

    def reverse!
      @x_f, @y_f, @z_f = -@x_f, -@y_f, -@z_f
      self
    end

    def -@
      reverse
    end

    def +(other)
      ox, oy, oz = other.to_a.map(&:to_f)
      Vector3d.new(@x_f + ox, @y_f + oy, @z_f + oz)
    end

    def -(other)
      ox, oy, oz = other.to_a.map(&:to_f)
      Vector3d.new(@x_f - ox, @y_f - oy, @z_f - oz)
    end

    # SketchUp : vector * vector is the cross product
    def *(other)
      return cross(other) if other.is_a?(Vector3d)
      scale(other.to_f)
    end

    def %(other)
      dot(other)
    end

    def dot(other)
      Geom._dot(to_a, other.to_a.map(&:to_f))
    end

    def cross(other)
      Vector3d.new(Geom._cross(to_a, other.to_a.map(&:to_f)))
    end

    def _sine_with(other)
      a = _length
      b = other._length
      return nil if a <= 1e-10 || b <= 1e-10
      Geom._length(Geom._cross(to_a, other.to_a)) / (a * b)
    end

    def parallel?(other)
      sine = _sine_with(other)
      !sine.nil? && sine < 0.001
    end

    def samedirection?(other)
      parallel?(other) && dot(other) > 0
    end

    def angle_between(other)
      a = normalize
      b = other.normalize
      Math.atan2(Geom._length(Geom._cross(a.to_a, b.to_a)), Geom._dot(a.to_a, b.to_a))
    end

    def transform(transformation)
      transformation = Transformation.new(transformation) unless transformation.is_a?(Transformation)
      Vector3d.new(transformation._apply_vector(to_a))
    end

    def transform!(transformation)
      @x_f, @y_f, @z_f = transform(transformation).to_a
      self
    end

    # As SketchUp answers it : x = Y x z when z is parallel to Z (sine under
    # 0.001), else Z x z - not AutoCAD's 1/64 rule
    def axes
      z = normalize
      x = z.parallel?(Vector3d.new(0, 0, 1)) ? Vector3d.new(0, 1, 0).cross(z) : Vector3d.new(0, 0, 1).cross(z)
      x = x.normalize
      y = z.cross(x).normalize
      [ x, y, z ]
    end

    def inspect
      "Vector3d(#{@x_f}, #{@y_f}, #{@z_f})"
    end

  end

  # A 4x4 matrix, column major as SketchUp's #to_a : the origin at 12..14
  class Transformation

    def initialize(arg = nil)
      @m = if arg.nil?
             [ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 ]
           elsif arg.is_a?(Transformation)
             arg.to_a
           elsif arg.is_a?(Array) && arg.size == 16
             arg.map(&:to_f)
           else
             x, y, z = arg.to_a.map(&:to_f) # A point or vector : a translation
             [ 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, x, y, z, 1.0 ]
           end
    end

    def self.axes(origin, x_axis, y_axis, z_axis)
      x, y, z, o = [ x_axis, y_axis, z_axis, origin ].map { |v| v.to_a.map(&:to_f) }
      new(x + [ 0.0 ] + y + [ 0.0 ] + z + [ 0.0 ] + o + [ 1.0 ])
    end

    def self.translation(vector)
      new(vector.to_a.map(&:to_f))
    end

    def self.scaling(*args)
      if args.size == 1
        s = args.first.to_f
        sx = sy = sz = s
        origin = [ 0.0, 0.0, 0.0 ]
      elsif args.size == 2
        origin = args[0].to_a.map(&:to_f)
        sx = sy = sz = args[1].to_f
      elsif args.size == 3
        sx, sy, sz = args.map(&:to_f)
        origin = [ 0.0, 0.0, 0.0 ]
      else
        origin = args[0].to_a.map(&:to_f)
        sx, sy, sz = args[1..3].map(&:to_f)
      end
      t = [ sx, 0.0, 0.0, 0.0, 0.0, sy, 0.0, 0.0, 0.0, 0.0, sz, 0.0,
            origin[0] * (1 - sx), origin[1] * (1 - sy), origin[2] * (1 - sz), 1.0 ]
      new(t)
    end

    def self.rotation(point, axis, angle)
      ux, uy, uz = Vector3d.new(axis.to_a).normalize.to_a
      c = Math.cos(angle)
      s = Math.sin(angle)
      t = 1 - c
      r = [
        [ t * ux * ux + c, t * ux * uy - s * uz, t * ux * uz + s * uy ],
        [ t * ux * uy + s * uz, t * uy * uy + c, t * uy * uz - s * ux ],
        [ t * ux * uz - s * uy, t * uy * uz + s * ux, t * uz * uz + c ]
      ]
      px, py, pz = point.to_a.map(&:to_f)
      # p' = R (p - P) + P
      tx = px - (r[0][0] * px + r[0][1] * py + r[0][2] * pz)
      ty = py - (r[1][0] * px + r[1][1] * py + r[1][2] * pz)
      tz = pz - (r[2][0] * px + r[2][1] * py + r[2][2] * pz)
      new([ r[0][0], r[1][0], r[2][0], 0.0, r[0][1], r[1][1], r[2][1], 0.0, r[0][2], r[1][2], r[2][2], 0.0, tx, ty, tz, 1.0 ])
    end

    def to_a
      @m.dup
    end

    def origin
      Point3d.new(@m[12] / @m[15], @m[13] / @m[15], @m[14] / @m[15])
    end

    def xaxis; Vector3d.new(@m[0], @m[1], @m[2]).normalize; end
    def yaxis; Vector3d.new(@m[4], @m[5], @m[6]).normalize; end
    def zaxis; Vector3d.new(@m[8], @m[9], @m[10]).normalize; end

    def identity?
      @m == Transformation.new.to_a
    end

    def _get(row, column)
      @m[column * 4 + row]
    end

    def *(other)
      return other.transform(self) if other.is_a?(Point3d)
      o = other.to_a
      r = Array.new(16, 0.0)
      4.times do |column|
        4.times do |row|
          r[column * 4 + row] = (0..3).inject(0.0) { |sum, k| sum + _get(row, k) * o[column * 4 + k] }
        end
      end
      Transformation.new(r)
    end

    def inverse
      m = (0..3).map { |row| (0..3).map { |column| _get(row, column) } }
      inv = (0..3).map { |i| (0..3).map { |j| i == j ? 1.0 : 0.0 } }
      4.times do |column|
        pivot = (column..3).max_by { |row| m[row][column].abs }
        m[column], m[pivot] = m[pivot], m[column]
        inv[column], inv[pivot] = inv[pivot], inv[column]
        f = m[column][column]
        raise ArgumentError, 'Singular transformation' if f.abs < 1e-15
        4.times { |j| m[column][j] /= f; inv[column][j] /= f }
        4.times do |row|
          next if row == column
          g = m[row][column]
          next if g.zero?
          4.times { |j| m[row][j] -= g * m[column][j]; inv[row][j] -= g * inv[column][j] }
        end
      end
      Transformation.new((0..3).flat_map { |column| (0..3).map { |row| inv[row][column] } })
    end

    def _apply_point(p)
      x, y, z = p
      w = _get(3, 0) * x + _get(3, 1) * y + _get(3, 2) * z + _get(3, 3)
      [
        (_get(0, 0) * x + _get(0, 1) * y + _get(0, 2) * z + _get(0, 3)) / w,
        (_get(1, 0) * x + _get(1, 1) * y + _get(1, 2) * z + _get(1, 3)) / w,
        (_get(2, 0) * x + _get(2, 1) * y + _get(2, 2) * z + _get(2, 3)) / w
      ]
    end

    def _apply_vector(v)
      x, y, z = v
      [
        _get(0, 0) * x + _get(0, 1) * y + _get(0, 2) * z,
        _get(1, 0) * x + _get(1, 1) * y + _get(1, 2) * z,
        _get(2, 0) * x + _get(2, 1) * y + _get(2, 2) * z
      ]
    end

  end

  # -- Helpers (arrays of 3 floats) --

  def self._dot(a, b)
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  end

  def self._cross(a, b)
    [ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] ]
  end

  def self._sub(a, b)
    [ a[0] - b[0], a[1] - b[1], a[2] - b[2] ]
  end

  def self._add(a, b)
    [ a[0] + b[0], a[1] + b[1], a[2] + b[2] ]
  end

  def self._scale(a, f)
    [ a[0] * f, a[1] * f, a[2] * f ]
  end

  def self._length(a)
    Math.sqrt(_dot(a, a))
  end

  def self._unit(a)
    _scale(a, 1.0 / _length(a))
  end

  # [ point, unit normal ] Arrays from [ Point3d, Vector3d ] or [ a, b, c, d ]
  def self._plane(plane)
    if plane.size == 4 && plane.all? { |v| v.is_a?(Numeric) }
      a, b, c, d = plane.map(&:to_f)
      normal = [ a, b, c ]
      length = _length(normal)
      normal = _scale(normal, 1.0 / length)
      [ _scale(normal, -d / length), normal ]
    else
      [ plane[0].to_a.map(&:to_f), _unit(plane[1].to_a.map(&:to_f)) ]
    end
  end

  # [ point, unit direction ] Arrays from [ Point3d, Vector3d ] or [ Point3d, Point3d ]
  def self._line(line)
    point = line[0].to_a.map(&:to_f)
    if line[1].is_a?(Vector3d)
      [ point, _unit(line[1].to_a.map(&:to_f)) ]
    else
      [ point, _unit(_sub(line[1].to_a.map(&:to_f), point)) ]
    end
  end

  def self._project_on_plane(p, point, normal)
    _sub(p, _scale(normal, _dot(_sub(p, point), normal)))
  end

  def self._distance_to_line(p, point, direction)
    v = _sub(p, point)
    _length(_sub(v, _scale(direction, _dot(v, direction))))
  end

  # -- API --

  def self.intersect_plane_plane(plane_1, plane_2)
    p1, n1 = _plane(plane_1)
    p2, n2 = _plane(plane_2)
    direction = _cross(n1, n2)
    return nil if _length(direction) < 1e-10
    d1 = _dot(n1, p1)
    d2 = _dot(n2, p2)
    # The line point closest to the origin
    c = _length(direction)**2
    point = _scale(_add(_scale(_cross(n2, direction), d1), _scale(_cross(direction, n1), d2)), 1.0 / c)
    [ Point3d.new(point), Vector3d.new(_unit(direction)) ]
  end

  def self.intersect_line_line(line_1, line_2)
    p1, d1 = _line(line_1)
    p2, d2 = _line(line_2)
    return nil if _length(_cross(d1, d2)) < 1e-5
    w = _sub(p1, p2)
    b = _dot(d1, d2)
    d = _dot(d1, w)
    e = _dot(d2, w)
    denominator = 1.0 - b * b
    s = (b * e - d) / denominator
    t = (e - b * d) / denominator
    q1 = _add(p1, _scale(d1, s))
    q2 = _add(p2, _scale(d2, t))
    return nil if _length(_sub(q1, q2)) >= TOLERANCE
    Point3d.new(_scale(_add(q1, q2), 0.5))
  end

  def self.intersect_line_plane(line, plane)
    p, d = _line(line)
    point, normal = _plane(plane)
    denominator = _dot(d, normal)
    return nil if denominator.abs < 1e-6
    t = _dot(_sub(point, p), normal) / denominator
    Point3d.new(_add(p, _scale(d, t)))
  end

  def self.linear_combination(weight_1, point_1, weight_2, point_2)
    a = point_1.to_a.map(&:to_f)
    b = point_2.to_a.map(&:to_f)
    result = _add(_scale(a, weight_1.to_f), _scale(b, weight_2.to_f))
    point_1.is_a?(Vector3d) ? Vector3d.new(result) : Point3d.new(result)
  end

  # z ignored ; a point within 0.001" of the border is on it
  def self.point_in_polygon_2D(point, polygon, check_border)
    px, py = point.to_a.map(&:to_f)
    pts = polygon.map { |p| p.to_a.map(&:to_f) }
    on_border = pts.each_with_index.any? { |a, i|
      b = pts[(i + 1) % pts.size]
      _segment_distance_2d(px, py, a[0], a[1], b[0], b[1]) < TOLERANCE
    }
    return check_border if on_border
    inside = false
    pts.each_with_index do |a, i|
      b = pts[i - 1]
      if (a[1] > py) != (b[1] > py) && px < (b[0] - a[0]) * (py - a[1]) / (b[1] - a[1]) + a[0]
        inside = !inside
      end
    end
    inside
  end

  def self._segment_distance_2d(px, py, ax, ay, bx, by)
    dx = bx - ax
    dy = by - ay
    l2 = dx * dx + dy * dy
    t = l2.zero? ? 0.0 : [ [ ((px - ax) * dx + (py - ay) * dy) / l2, 0.0 ].max, 1.0 ].min
    Math.sqrt((px - ax - t * dx)**2 + (py - ay - t * dy)**2)
  end

end

ORIGIN = Geom::Point3d.new(0, 0, 0)
X_AXIS = Geom::Vector3d.new(1, 0, 0)
Y_AXIS = Geom::Vector3d.new(0, 1, 0)
Z_AXIS = Geom::Vector3d.new(0, 0, 1)
IDENTITY = Geom::Transformation.new
