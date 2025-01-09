module Ladb::OpenCutList::Kuix

  class Bounds2d

    TOP_LEFT = 0
    TOP_CENTER = 1
    TOP_RIGHT = 2
    CENTER_RIGHT = 3
    BOTTOM_RIGHT = 4
    BOTTOM_CENTER = 5
    BOTTOM_LEFT = 6
    CENTER_LEFT = 7

    attr_reader :origin, :size

    def initialize(x = 0, y = 0, width = 0, height = 0)
      @origin = Point2d.new
      @size = Size2d.new
      set!(x, y, width, height)
    end

    def set!(x = 0, y = 0, width = 0, height = 0)
      @origin.set!(x, y)
      @size.set!(width, height)
    end

    def set_all!(value = 0)
      set!(value, value, value, value)
    end

    def copy!(bounds)
      @origin.copy!(bounds.origin)
      @size.copy!(bounds.size)
    end

    # -- Properties --

    def x
      @origin.x
    end

    def y
      @origin.y
    end

    def width
      @size.width
    end

    def height
      @size.height
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

    def center
      Point2d.new(
        x_min + (x_max - x_min) / 2,
        y_min + (y_max - y_min) / 2
      )
    end

    # -- Tests --

    def is_empty?
      @size.is_empty?
    end

    def inside?(x, y)
      x >= x_min && x <= x_max && y >= y_min && y <= y_max
    end

    # -- Manipulations --

    def union!(bounds)
      if is_empty?
        copy!(bounds)
      else
        set!(
          [ x_min, bounds.x_min ].min,
          [ y_min, bounds.x_min ].min,
          [ x_max, bounds.x_max ].max - x_min,
          [ y_max , bounds.y_max ].max - y_min
        )
      end
    end

    # -- Exports --

    def get_points
      [
        Geom::Point3d.new(x_min , y_min  , 0),
        Geom::Point3d.new(x_max , y_min  , 0),
        Geom::Point3d.new(x_max , y_max  , 0),
        Geom::Point3d.new(x_min , y_max  , 0)
      ]
    end

    # --

    def to_s
      "#{self.class.name} (origin=#{@origin}, size=#{@size})"
    end

  end

end