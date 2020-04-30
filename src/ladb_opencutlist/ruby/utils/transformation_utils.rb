module Ladb::OpenCutList

  require_relative '../model/geom/scale3d'

  class TransformationUtils

    def self.get_scale3d(transformation)
      return Scale3d.new if transformation.nil?
      transformation_a = transformation.to_a
      vx = Geom::Vector3d.new(transformation_a[0], transformation_a[1], transformation_a[2])
      vy = Geom::Vector3d.new(transformation_a[4], transformation_a[5], transformation_a[6])
      vz = Geom::Vector3d.new(transformation_a[8], transformation_a[9], transformation_a[10])
      Scale3d.new(vx.length, vy.length, vz.length)
    end

    def self.flipped?(transformation)
      transformation.xaxis.cross(transformation.yaxis) != transformation.zaxis
    end

    def self.multiply(transformation1, transformation2)
      if transformation1.nil?
        if transformation2.nil?
          nil
        else
          transformation2
        end
      else
        if transformation2.nil?
          transformation1
        else
          transformation1 * transformation2
        end
      end
    end

  end

end

