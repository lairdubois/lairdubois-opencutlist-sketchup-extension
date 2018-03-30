module Ladb::OpenCutList

  class TransformationUtils

    def self.get_scale3d(transformation)
      return Scale3d.new if transformation.nil?
      transformation_a = transformation.to_a
      vx = Geom::Vector3d.new(transformation_a[0], transformation_a[1], transformation_a[2])
      vy = Geom::Vector3d.new(transformation_a[4], transformation_a[5], transformation_a[6])
      vz = Geom::Vector3d.new(transformation_a[8], transformation_a[9], transformation_a[10])
      Scale3d.new(vx.length, vy.length, vz.length)
    end

  end

end

