module Ladb::OpenCutList

  class Point3dUtils

    def self.transform_points(points, transformation)  # Points is Array<Sketchup::Point3d>
      return false if transformation.nil?
      points.each { |point| point.transform!(transformation) }
      true
    end

  end

end

