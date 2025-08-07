module Ladb::OpenCutList::Geometrix

  class CentroidFinder

    def self.find_centroid(points)

      # Check valid points
      return nil if points.empty?

      sum_x = 0
      sum_y = 0
      sum_z = 0

      # Iterate over each point to add its coordinates.
      points.each do |point|
        sum_x += point.x
        sum_y += point.y
        sum_z += point.z
      end

      num_points = points.length

      # Centroid
      Geom::Point3d.new(
        sum_x.to_f / num_points,
        sum_y.to_f / num_points,
        sum_z.to_f / num_points
      )
    end

  end

end