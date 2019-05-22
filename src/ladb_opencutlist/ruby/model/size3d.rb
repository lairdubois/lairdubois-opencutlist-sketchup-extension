module Ladb::OpenCutList

  require_relative 'size2d'

  class Size3d < Size2d

    DEFAULT_NORMALS = [X_AXIS, Y_AXIS, Z_AXIS ]

    attr_accessor :thickness

    def initialize(length = 0, width = 0, thickness = 0, normals = DEFAULT_NORMALS)
      if length.is_a? String
        s_length, s_width, s_thickness = StringUtils.split_dxdxd(length)
        length = s_length.to_l
        width = s_width.to_l
        thickness = s_thickness.to_l
      end
      super(length, width)
      @thickness = thickness
      @normals = normals
    end

    # -----

    def self.create_from_bounds(bounds, scale, auto_orient = true)
      if auto_orient
        ordered = [
            { :value => (bounds.width * scale.x).to_l, :normal => X_AXIS },
            { :value => (bounds.height * scale.y).to_l, :normal => Y_AXIS },
            { :value => (bounds.depth * scale.z).to_l, :normal => Z_AXIS }
        ].sort_by { |item| item[:value]}
        Size3d.new(ordered[2][:value], ordered[1][:value], ordered[0][:value], [ ordered[2][:normal], ordered[1][:normal], ordered[0][:normal] ])
      else
        Size3d.new((bounds.width * scale.x).to_l, (bounds.height * scale.y).to_l, (bounds.depth * scale.z).to_l)
      end
    end

    # -----

    def auto_oriented
      @normals != DEFAULT_NORMALS
    end

    def length_normal
      @normals[0]
    end

    def width_normal
      @normals[1]
    end

    def thickness_normal
      @normals[2]
    end

    # -----

    def volume
      area * @thickness
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
