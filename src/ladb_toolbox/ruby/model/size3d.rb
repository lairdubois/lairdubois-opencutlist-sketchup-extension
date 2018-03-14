module Ladb
  module Toolbox
    class Size3d

      attr_accessor :length, :width, :thickness

      def initialize(length = 0, width = 0, thickness = 0)
        @length = length
        @width = width
        @thickness = thickness
      end

      def area_m2
        @length.to_m * @width.to_m
      end

      def volume_m3
        area_m2 * @thickness.to_m
      end

      def to_s
        '(' + @length.to_l.to_s + ', ' + @width.to_l.to_s + ', ' + @thickness.to_l.to_s + ')'
      end

    end
  end
end
