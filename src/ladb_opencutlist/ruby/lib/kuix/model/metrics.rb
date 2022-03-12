module Ladb::OpenCutList::Kuix

  require_relative 'point'
  require_relative 'size'

  class Metrics

    attr_reader :origin, :size

    def initialize(x = 0, y = 0, width = 0, height = 0)
      @origin = Point.new
      @size = Size.new
      set(x, y, width, height)
    end

    def set(x = 0, y = 0, width = 0, height = 0)
      @origin.set(x, y)
      @size.set(width, height)
    end

    def to_s
      "#{self.class.name} (origin=#{@origin}, size=#{@size})"
    end

    def is_empty?
      @size.width == 0 || @size.height == 0
    end

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

    def left
      @origin.x
    end

    def right
      @origin.x + @size.width
    end

    def top
      @origin.y
    end

    def bottom
      @origin.y + @size.height
    end

    def inside?(x, y)
      x >= left && x <= right && y >= top && y <= bottom
    end

    def add(x, y, width, height)
      # if is_empty?
      #   set(x, y, width, height)
      # else
        right = [@origin.x + @size.width, x + width].max
        bottom = [@origin.y + @size.height, y + height].max
        set(
          [ @origin.x, x ].min,
          [ @origin.y, y ].min,
          right - @origin.x,
          bottom - @origin.y
        )
      # end
    end

    def get_points
      [
        Geom::Point3d.new(@origin.x               , @origin.y                 , 0),
        Geom::Point3d.new(@origin.x + @size.width , @origin.y                 , 0),
        Geom::Point3d.new(@origin.x + @size.width , @origin.y + @size.height  , 0),
        Geom::Point3d.new(@origin.x               , @origin.y + @size.height  , 0)
      ]
    end

  end

end