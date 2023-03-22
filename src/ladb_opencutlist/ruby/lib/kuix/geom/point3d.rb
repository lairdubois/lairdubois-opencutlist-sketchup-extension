module Ladb::OpenCutList::Kuix

  class Point3d

    attr_accessor :x, :y, :z

    def initialize(x = 0, y = 0, z = 0)
      set!(x, y, z)
    end

    def set!(x = 0, y = 0, z = 0)
      @x = x
      @y = y
      @z = z
    end

    def set_all!(value = 0)
      set!(value, value, value)
    end

    def copy!(point)
      set!(point.x, point.y, point.z)
    end

    # -- Manipulations --

    def translate!(dx, dy, dz)
      @x += dx
      @y += dy
      @z += dz
    end

    # --

    def to_s
      "#{self.class.name} (x=#{@x}, y=#{@y}, z=#{@z})"
    end

    def to_p
      Geom::Point3d.new(@x, @y, @z)
    end

  end

end