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
      self
    end

    def set_all!(value = 0)
      set!(value, value, value)
    end

    def copy!(point)
      set!(
        point.respond_to?(:x) ? point.x : 0,
        point.respond_to?(:y) ? point.y : 0,
        point.respond_to?(:z) ? point.z : 0
      )
    end

    # -- Operations --

    def +(point)
      set!(x + point.x, y + point.y, z + point.z)
    end

    def -(point)
      set!(x - point.x, y - point.y, z - point.z)
    end

    # -- Manipulations --

    def translate!(dx, dy, dz)
      set!(x + dx, y + dy, z + dz)
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