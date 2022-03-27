module Ladb::OpenCutList

  class Point3dUtils

    def self.offset_toward_camera(view, points, offset = 0.01)  # Points is Array<Sketchup::Point3d>
      offset_direction = view.camera.direction.reverse!
      points.map { |point|
        point = point.position if point.respond_to?(:position)
        # Model.pixels_to_model converts argument to integers.
        size = view.pixels_to_model(2, point) * offset
        point.offset(offset_direction, size)
      }
    end

    def self.transform_points(points, transformation)  # Points is Array<Sketchup::Point3d>
      return false if transformation.nil?
      points.each { |point| point.transform!(transformation) }
      true
    end

  end

end

