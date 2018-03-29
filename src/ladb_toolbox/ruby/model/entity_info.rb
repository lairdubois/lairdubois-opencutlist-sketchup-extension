module Ladb
  module Toolbox
    class EntityInfo

      attr_reader :entity, :path, :volume, :bounds

      def initialize(path = [], volume = 0, bounds = Geom::BoundingBox.new)
        @entity = path.last
        @path = path
        @volume = volume
        @bounds = bounds
      end

    end
  end
end