module Ladb::OpenCutList::Kuix

  class Bounds3d

    BOTTOM  = 0
    TOP     = 1
    LEFT    = 2
    RIGHT   = 3
    FRONT   = 4
    BACK    = 5

    LEFT_FRONT_BOTTOM = 0
    RIGHT_FRONT_BOTTOM = 1
    LEFT_BACK_BOTTOM = 2
    RIGHT_BACK_BOTTOM = 3
    LEFT_FRONT_TOP = 4
    RIGHT_FRONT_TOP = 5
    LEFT_BACK_TOP = 6
    RIGHT_BACK_TOP = 7

    attr_reader :origin, :size

    def initialize(x = 0, y = 0, z = 0, width = 0, height = 0, depth = 0)
      @origin = Point3d.new
      @size = Size3d.new
      set!(x, y, z, width, height, depth)
    end

    def set!(x = 0, y = 0, z = 0, width = 0, height = 0, depth = 0)
      @origin.set!(x, y, z)
      @size.set!(width, height, depth)
      self
    end

    def set_all!(value = 0)
      set!(value, value, value, value, value, value)
    end

    def copy!(bounds)
      @origin.copy!(bounds.min) if bounds.respond_to?(:min)
      @size.copy!(bounds)
      self
    end

    # -- Properties --

    def x
      @origin.x
    end

    def y
      @origin.y
    end

    def z
      @origin.z
    end

    def width
      @size.width
    end

    def height
      @size.height
    end

    def depth
      @size.depth
    end

    def dim_by_axis(axis)
      case axis
      when X_AXIS then width
      when Y_AXIS then height
      when Z_AXIS then depth
      else
        throw "Invalid dim_by_axis axis (axis=#{axis})"
      end
    end

    def x_min
      @origin.x
    end

    def x_max
      @origin.x + @size.width
    end

    def y_min
      @origin.y
    end

    def y_max
      @origin.y + @size.height
    end

    def z_min
      @origin.z
    end

    def z_max
      @origin.z + @size.depth
    end

    def corner(index)
      case index
      when LEFT_FRONT_BOTTOM
        Point3d.new(x_min, y_min, z_min)
      when RIGHT_FRONT_BOTTOM
        Point3d.new(x_max, y_min, z_min)
      when LEFT_BACK_BOTTOM
        Point3d.new(x_min, y_max, z_min)
      when RIGHT_BACK_BOTTOM
        Point3d.new(x_max, y_max, z_min)
      when LEFT_FRONT_TOP
        Point3d.new(x_min, y_min, z_max)
      when RIGHT_FRONT_TOP
        Point3d.new(x_max, y_min, z_max)
      when LEFT_BACK_TOP
        Point3d.new(x_min, y_max, z_max)
      when RIGHT_BACK_TOP
        Point3d.new(x_max, y_max, z_max)
      else
        throw "Invalid corner index (index=#{index})"
      end
    end

    def face_center(index)
      case index
      when TOP
        Point3d.new(
          x_min + (x_max - x_min) / 2,
          y_min + (y_max - y_min) / 2,
          z_max
        )
      when BOTTOM
        Point3d.new(
          x_min + (x_max - x_min) / 2,
          y_min + (y_max - y_min) / 2,
          z_min
        )
      when LEFT
        Point3d.new(
          x_min,
          y_min + (y_max - y_min) / 2,
          z_min + (z_max - z_min) / 2
        )
      when RIGHT
        Point3d.new(
          x_max,
          y_min + (y_max - y_min) / 2,
          z_min + (z_max - z_min) / 2
        )
      when FRONT
        Point3d.new(
          x_min + (x_max - x_min) / 2,
          y_min,
          z_min + (z_max - z_min) / 2
        )
      when BACK
        Point3d.new(
          x_min + (x_max - x_min) / 2,
          y_max,
          z_min + (z_max - z_min) / 2
        )
      else
        throw "Invalid face_center index (index=#{index})"
      end
    end

    def self.face_opposite(index)
      case index
      when BOTTOM then TOP
      when TOP then BOTTOM
      when LEFT then RIGHT
      when RIGHT then LEFT
      when FRONT then BACK
      when BACK then FRONT
      else
        throw "Invalid face_opposite index (index=#{index})"
      end
    end

    def self.faces_by_axis(axis)
      case axis
      when X_AXIS then [ LEFT, RIGHT ]
      when Y_AXIS then [ FRONT, BACK ]
      when Z_AXIS then [ BOTTOM, TOP ]
      else
        throw "Invalid faces_by_axis axis (axis=#{axis})"
      end
    end

    def self.axis_by_face(face)
      case face
      when LEFT, RIGHT then X_AXIS
      when FRONT, BACK then Y_AXIS
      when BOTTOM, TOP then Z_AXIS
      else
        throw "Invalid axis_by_face face (face=#{face})"
      end
    end

    def min
      Point3d.new(
        x_min,
        y_min,
        z_min
      )
    end

    def max
      Point3d.new(
        x_max,
        y_max,
        z_max
      )
    end

    def center
      Point3d.new(
        x_min + (x_max - x_min) / 2,
        y_min + (y_max - y_min) / 2,
        z_min + (z_max - z_min) / 2
      )
    end

    def x_section
      Bounds3d.new(center.x, y_min, z_min, 0, height, depth)
    end

    def x_section_min
      Bounds3d.new(x_min, y_min, z_min, 0, height, depth)
    end

    def x_section_max
      Bounds3d.new(x_max, y_min, z_min, 0, height, depth)
    end

    def y_section
      Bounds3d.new(x_min, center.y, z_min, width, 0, depth)
    end

    def y_section_min
      Bounds3d.new(x_min, y_min, z_min, width, 0, depth)
    end

    def y_section_max
      Bounds3d.new(x_min, y_max, z_min, width, 0, depth)
    end

    def z_section
      Bounds3d.new(x_min, y_min, center.z, width, height, 0)
    end

    def z_section_min
      Bounds3d.new(x_min, y_min, z_min, width, height, 0)
    end

    def z_section_max
      Bounds3d.new(x_min, y_min, z_max, width, height, 0)
    end

    def section(index)
      case index
      when TOP
        z_section_max
      when BOTTOM
        z_section_min
      when LEFT
        x_section_min
      when RIGHT
        x_section_max
      when FRONT
        y_section_min
      when BACK
        y_section_max
      else
        throw "Invalid section index (index=#{index})"
      end
    end

    def section_by_axis(axis)
      case axis
      when X_AXIS then x_section
      when Y_AXIS then y_section
      when Z_AXIS then z_section
      else
        throw "Invalid section_by_axis axis (axis=#{axis})"
      end
    end

    # -- Tests --

    def is_empty?
      @size.is_empty?
    end

    def inside?(x, y, z)
      x >= x_min && x <= x_max && y >= y_min && y <= y_max && z >= z_min && z <= z_max
    end

    # -- Manipulations --

    def add!(points)
      points = [ points ] unless points.is_a?(Array)
      points.each do |point|
        old_min = min
        old_max = max
        @origin.set!(
          [ old_min.x, point.x ].min,
          [ old_min.y, point.y ].min,
          [ old_min.z, point.z ].min
        )
        @size.set!(
          [ old_max.x, point.x ].max - x_min,
          [ old_max.y, point.y ].max - y_min,
          [ old_max.z, point.z ].max - z_min
        )
      end
      self
    end

    def translate!(dx, dy, dz)
      @origin.translate!(dx, dy, dz)
      self
    end

    def union!(bounds)
      if is_empty?
        copy!(bounds)
      else
        set!(
          [ x_min, bounds.x_min ].min,
          [ y_min, bounds.y_min ].min,
          [ z_min, bounds.z_min ].min,
          [ x_max, bounds.x_max ].max - x_min,
          [ z_max , bounds.z_max ].max - z_min,
          [ y_max , bounds.y_max ].max - y_min
        )
      end
      self
    end

    def inflate!(dx, dy, dz)
      @origin.x -= dx
      @size.width += dx * 2
      @origin.y -= dy
      @size.height += dy * 2
      @origin.z -= dz
      @size.depth += dz * 2
      self
    end

    def inflate_all!(d)
      inflate!(d, d, d)
    end

    # -- Exports --

    def get_quad(index)
      case index
      when BOTTOM
        [
          Geom::Point3d.new(x_min , y_min  , z_min),
          Geom::Point3d.new(x_max , y_min  , z_min),
          Geom::Point3d.new(x_max , y_max  , z_min),
          Geom::Point3d.new(x_min , y_max  , z_min)
        ]
      when TOP
        [
          Geom::Point3d.new(x_min , y_min  , z_max),
          Geom::Point3d.new(x_max , y_min  , z_max),
          Geom::Point3d.new(x_max , y_max  , z_max),
          Geom::Point3d.new(x_min , y_max  , z_max)
        ]
      when LEFT
        [
          Geom::Point3d.new(x_min , y_min  , z_min),
          Geom::Point3d.new(x_min , y_max  , z_min),
          Geom::Point3d.new(x_min , y_max  , z_max),
          Geom::Point3d.new(x_min , y_min  , z_max)
        ]
      when RIGHT
        [
          Geom::Point3d.new(x_max , y_min  , z_min),
          Geom::Point3d.new(x_max , y_max  , z_min),
          Geom::Point3d.new(x_max , y_max  , z_max),
          Geom::Point3d.new(x_max , y_min  , z_max)
        ]
      when FRONT
        [
          Geom::Point3d.new(x_min , y_min  , z_min),
          Geom::Point3d.new(x_min , y_min  , z_max),
          Geom::Point3d.new(x_max , y_min  , z_max),
          Geom::Point3d.new(x_max , y_min  , z_min)
        ]
      when BACK
        [
          Geom::Point3d.new(x_min , y_max  , z_min),
          Geom::Point3d.new(x_min , y_max  , z_max),
          Geom::Point3d.new(x_max , y_max  , z_max),
          Geom::Point3d.new(x_max , y_max  , z_min)
        ]
      else
        throw "Invalid size index (index=#{index})"
      end
    end

    def get_quads
      quads = []
      quads.concat(get_quad(LEFT)) if height > 0 && depth > 0
      quads.concat(get_quad(RIGHT)) if width > 0 && height > 0 && depth > 0
      quads.concat(get_quad(FRONT)) if width > 0 && depth > 0
      quads.concat(get_quad(BACK)) if width > 0 && height > 0 && depth > 0
      quads.concat(get_quad(BOTTOM)) if width > 0 && height > 0
      quads.concat(get_quad(TOP)) if width > 0 && height > 0 && depth > 0
      quads
    end

    # --

    def to_b
      Geom::BoundingBox.new.add([ min, max ])
    end

    def to_s
      "#{self.class.name} (origin=#{@origin}, size=#{@size})"
    end

  end

end