module Ladb::OpenCutList::Kuix

  class Line < Lines3d

    attr_reader :start, :end

    def initialize(id = nil)
      super([

        [ 0, 0, 0 ],
        [ 1, 1, 1 ]

      ], false, id)

      @start = Point3d.new
      @end = Point3d.new

    end

    def do_layout(transformation)

      v = @end - @start

      tsx = 1
      tsy = 1
      tsz = 1
      if v.x < 0
        tsx = -1
        v.x = v.x.abs
      end
      if v.y < 0
        tsy = -1
        v.y = v.y.abs
      end
      if v.z < 0
        tsz = -1
        v.z = v.z.abs
      end

      self.pattern_transformation = Geom::Transformation.scaling(tsx, tsy, tsz)
      self.bounds.origin.copy!(@start)
      self.bounds.size.set!(v.x, v.y, v.z)

      super
    end

  end

end