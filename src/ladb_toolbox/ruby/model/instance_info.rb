require_relative '../utils/path_utils'

module Ladb
  module Toolbox
    class InstanceInfo

      attr_accessor :size
      attr_reader :path

      @crafted_volume
      @size

      def initialize(path = [])
        @path = path
      end

      # -----

      def entity
        @path.last
      end

      def serialized_path
        if @serialized_path
          return @serialized_path
        end
        @serialized_path = PathUtils.serialize_path(@path)
      end

      def transformation
        if @transformation
          return @transformation
        end
        @transformation = PathUtils.get_transformation(@path)
      end

      def scale
        if @scale
          return @scale
        end
        @scale = TransformationUtils::get_scale3d(transformation)
      end

      # -----

      def size
        if @size
          return @size
        end
        Size3d.new
      end

    end
  end
end