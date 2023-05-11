module Ladb::OpenCutList

  class Scale3d

    attr_accessor :x, :y, :z

    def initialize(x = 1.0, y = 1.0, z = 1.0)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end

    # -----

    def self.create_from_transformation(transformation, precision = 6)
      return Scale3d.new if transformation.nil?
      transformation_a = transformation.to_a
      vx = Geom::Vector3d.new(transformation_a[0], transformation_a[1], transformation_a[2])
      vy = Geom::Vector3d.new(transformation_a[4], transformation_a[5], transformation_a[6])
      vz = Geom::Vector3d.new(transformation_a[8], transformation_a[9], transformation_a[10])
      Scale3d.new(vx.length.to_f.round(precision), vy.length.to_f.round(precision), vz.length.to_f.round(precision))
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
