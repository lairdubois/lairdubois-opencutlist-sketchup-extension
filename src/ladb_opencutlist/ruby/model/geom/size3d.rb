module Ladb::OpenCutList

  require_relative 'size2d'

  class Size3d < Size2d

    DEFAULT_NORMALS = [ X_AXIS, Y_AXIS, Z_AXIS ]

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

    def self.create_from_bounds(bounds, scale, auto_orient = false)
      if auto_orient
        ordered = [
            { :value => (bounds.width * scale.x).to_l, :normal => X_AXIS, :sub_sort_index => 2 },
            { :value => (bounds.height * scale.y).to_l, :normal => Y_AXIS, :sub_sort_index => 1 },
            { :value => (bounds.depth * scale.z).to_l, :normal => Z_AXIS, :sub_sort_index => 0 }
        ].sort_by { |item| [ item[:value], item[:sub_sort_index] ] }   # Added sub_sort_index as sort parameter to sort equals values in default axes order.
        Size3d.new(ordered[2][:value], ordered[1][:value], ordered[0][:value], [ ordered[2][:normal], ordered[1][:normal], ordered[0][:normal] ])
      else
        Size3d.new((bounds.width * scale.x).to_l, (bounds.height * scale.y).to_l, (bounds.depth * scale.z).to_l)
      end
    end

    # -----

    def increment_thickness(inc)
      @thickness += inc
      @thickness = @thickness.to_l
    end

    # -----

    def auto_oriented
      @normals != DEFAULT_NORMALS
    end

    def oriented_normal(axis)
      case axis
        when X_AXIS
          @normals[0]
        when Y_AXIS
          @normals[1]
        when Z_AXIS
          @normals[2]
        else
          raise 'Invalid axis'
      end
    end

    def normals_to_values
      r = {}
      r[@normals[0] == X_AXIS ? :x : @normals[0] == Y_AXIS ? :y : :z] = @length.to_f
      r[@normals[1] == X_AXIS ? :x : @normals[1] == Y_AXIS ? :y : :z] = @width.to_f
      r[@normals[2] == X_AXIS ? :x : @normals[2] == Y_AXIS ? :y : :z] = @thickness.to_f
      r
    end

    def normals_to_dimensions
      r = {}
      r[@normals[0] == X_AXIS ? :x : @normals[0] == Y_AXIS ? :y : :z] = 'length'
      r[@normals[1] == X_AXIS ? :x : @normals[1] == Y_AXIS ? :y : :z] = 'width'
      r[@normals[2] == X_AXIS ? :x : @normals[2] == Y_AXIS ? :y : :z] = 'thickness'
      r
    end

    def dimensions_to_normals
      r = {}
      r[:length] = @normals[0] == X_AXIS ? 'x' : @normals[0] == Y_AXIS ? 'y' : 'z'
      r[:width] = @normals[1] == X_AXIS ? 'x' : @normals[1] == Y_AXIS ? 'y' : 'z'
      r[:thickness] = @normals[2] == X_AXIS ? 'x' : @normals[2] == Y_AXIS ? 'y' : 'z'
      r
    end

    # -----

    # Returns square area normal to given axis
    def area_by_axis(axis)
      case axis
        when X_AXIS
          @width * @thickness
        when Y_AXIS
          @length * @thickness
        when Z_AXIS
          area
        else
          raise 'Invalid axis'
      end
    end

    # -----

    def volume
      area * @thickness
    end

    # -----

    def ==(o)
      super(o) && o.thickness == @thickness
    end

    def to_s
      'Size3d(' + @length.to_l.to_s + ', ' + @width.to_l.to_s + ', ' + @thickness.to_l.to_s + ')'
    end

  end

end
