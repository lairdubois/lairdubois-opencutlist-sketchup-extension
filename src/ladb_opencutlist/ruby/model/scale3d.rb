module Ladb::OpenCutList

  class Scale3d

    attr_accessor :x, :y, :z

    def initialize(x = 1, y = 1, z = 1)
      @x = x.to_l
      @y = y.to_l
      @z = z.to_l
    end

    # -----

    def x
      @x.to_l
    end

    def y
      @y.to_l
    end

    def z
      @z.to_l
    end

    # -----

    def identity?
      self.x == 1.to_l and self.y == 1.to_l and self.z == 1.to_l
    end

    def mult(scale)
      @x = self.x * scale.x
      @y = self.y * scale.y
      @z = self.z * scale.z
    end

    # -----

    def to_s
      'Scale3d(' + @x.to_f.to_s + ', ' + @y.to_f.to_s + ', ' + @z.to_f.to_s + ')'
    end

  end

end
