module Ladb
  module Toolbox
    class Size3d

      attr_accessor :length, :width, :thickness

      def initialize(length = 0, width = 0, thickness = 0)
        @length = length
        @width = width
        @thickness = thickness
      end

      # -----

      def self.create_from_bounds(bounds, scale, auto_orient = true)
        if auto_orient
          ordered = [(bounds.width * scale.x).to_l, (bounds.height * scale.y).to_l, (bounds.depth * scale.z).to_l].sort
          Size3d.new(ordered[2], ordered[1], ordered[0])
        else
          Size3d.new((bounds.width * scale.x).to_l, (bounds.height * scale.y).to_l, (bounds.depth * scale.z).to_l)
        end
      end

      # -----

      def area
        @length * @width
      end

      def volume
        area * @thickness
      end

      def area_m2
        @length.to_m * @width.to_m
      end

      def volume_m3
        area_m2 * @thickness.to_m
      end

      # -----

      def to_s
        'Size3d(' + @length.to_l.to_s + ', ' + @width.to_l.to_s + ', ' + @thickness.to_l.to_s + ')'
      end

    end
  end
end
