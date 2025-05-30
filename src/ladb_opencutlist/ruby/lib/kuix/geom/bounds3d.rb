module Ladb::OpenCutList::Kuix

  class Bounds3d

    TOP = 0
    BOTTOM = 1
    LEFT = 2
    RIGHT = 3
    FRONT = 4
    BACK = 5

    TOP_LEFT = 0
    TOP_CENTER = 1
    TOP_RIGHT = 2
    CENTER_RIGHT = 3
    BOTTOM_RIGHT = 4
    BOTTOM_CENTER = 5
    BOTTOM_LEFT = 6
    CENTER_LEFT = 7

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
      if bounds.is_a?(Geom::BoundingBox)
        @origin.copy!(bounds.min)
        @size.copy!(bounds)
      else
        @origin.copy!(bounds.origin)
        @size.copy!(bounds.size)
      end
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
      when TOP_LEFT
        Point2d.new(x_min, y_min)
      when TOP_CENTER
        Point2d.new(x_min + (x_max - x_min) / 2, y_min)
      when TOP_RIGHT
        Point2d.new(x_max, y_min)
      when CENTER_RIGHT
        Point2d.new(x_max, y_min + (y_max - y_min) / 2)
      when BOTTOM_RIGHT
        Point2d.new(x_max, y_max)
      when BOTTOM_CENTER
        Point2d.new(x_min + (x_max - x_min) / 2, y_max)
      when BOTTOM_LEFT
        Point2d.new(x_min, y_max)
      when CENTER_LEFT
        Point2d.new(x_min, y_min + (y_max - y_min) / 2)
      else
        throw "Invalid corner index (index=#{index})"
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

    def y_section
      Bounds3d.new(x_min, center.y, z_min, width, 0, depth)
    end

    def z_section
      Bounds3d.new(x_min, y_min, center.z, width, height, 0)
    end

    # -- Tests --

    def is_empty?
      @size.is_empty?
    end

    def inside?(x, y, z)
      x >= x_min && x <= x_max && y >= y_min && y <= y_max && z >= z_min && z <= z_max
    end

    # -- Manipulations --

    def add!(point)
      set!(
        [ x_min, point.x ].min,
        [ y_min, point.y ].min,
        [ z_min, point.z ].min
      )
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
          Geom::Point3d.new(x_max , y_min  , z_min),
          Geom::Point3d.new(x_max , y_min  , z_max),
          Geom::Point3d.new(x_min , y_min  , z_max)
        ]
      when BACK
        [
          Geom::Point3d.new(x_min , y_max  , z_min),
          Geom::Point3d.new(x_max , y_max  , z_min),
          Geom::Point3d.new(x_max , y_max  , z_max),
          Geom::Point3d.new(x_min , y_max  , z_max)
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

    def to_s
      "#{self.class.name} (origin=#{@origin}, size=#{@size})"
    end

  end

end