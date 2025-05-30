module Ladb::OpenCutList::Kuix

  class Point2d

    attr_accessor :x, :y

    def initialize(x = 0, y = 0)
      set!(x, y)
    end

    def set!(x = 0, y = 0)
      @x = x
      @y = y
      self
    end

    def set_all!(value = 0)
      set!(value, value)
    end

    def copy!(point)
      set!(
        point.respond_to?(:x) ? point.x : 0,
        point.respond_to?(:y) ? point.y : 0
      )
    end

    # -- Operations --

    def +(point)
      set!(x + point.x, y + point.y)
    end

    def -(point)
      set!(x - point.x, y - point.y)
    end

    # -- Manipulations --

    def translate!(dx, dy)
      @x += dx
      @y += dy
      self
    end

    # --

    def to_s
      "#{self.class.name} (x=#{@x}, y=#{@y})"
    end

    def to_p
      Geom::Point3d.new(@x, @y, 0)
    end

  end

end