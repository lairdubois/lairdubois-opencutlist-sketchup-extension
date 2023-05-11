module Ladb::OpenCutList

  require_relative '../model/geom/scale3d'
  require_relative 'axis_utils'

  class TransformationUtils

    def self.get_scale3d(transformation, precision = 6)
      Scale3d.create_from_transformation(transformation, precision)
    end

    def self.flipped?(transformation)
      AxisUtils.flipped?(transformation.xaxis, transformation.yaxis, transformation.zaxis)
    end

    def self.skewed?(transformation)
      AxisUtils.skewed?(transformation.xaxis, transformation.yaxis, transformation.zaxis)
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

