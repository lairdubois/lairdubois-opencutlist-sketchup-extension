module Ladb::OpenCutList

  class Scale3d

    attr_accessor :x, :y, :z

    def initialize(x = 1.0, y = 1.0, z = 1.0)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end

    # -----

    def x
      @x.to_f
    end

    def y
      @y.to_f
    end

    def z
      @z.to_f
    end

    # -----

    def identity?
      self.x == 1.0 && self.y == 1.0 && self.z == 1.0
    end

    def mult(scale)
      @x = self.x * scale.x
      @y = self.y * scale.y
      @z = self.z * scale.z
    end

    # -----

    def to_s
      'Scale3d(' + @x.to_s + ', ' + @y.to_s + ', ' + @z.to_s + ')'
    end

  end

end
