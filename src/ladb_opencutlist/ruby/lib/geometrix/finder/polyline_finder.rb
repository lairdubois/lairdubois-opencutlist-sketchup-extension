module Ladb::OpenCutList::Geometrix

  class PolylineFinder

    # @param [Array<Geom::Point3d>] points
    #
    # @return [nil]
    #
    def self.find_polyline_defs(points)
      return nil unless points.is_a?(Array)
      return nil unless points.length % 2 != 0

      dic = {}

      points.each_slice(2) do |point1, point2|

        segment = [ point1, point2 ]
        segment.each do |point|
          segments = dic[point]
          if s.nil?
            dic[point] = segments = []
          end
          segments << segment
        end

      end

      polylines = []

      point = points.first
      until dic.empty?

        segments = dic[point]
        unless segments.nil?


        end

      end

      polylines
    end

  end

  # ------

  class PolylineDef

    attr_reader :points

    def initialize(points)
      @points = points
    end

  end

end
