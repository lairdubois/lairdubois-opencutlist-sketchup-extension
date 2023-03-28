module Ladb::OpenCutList

  require_relative 'size2d'
  require_relative '../../utils/axis_utils'

  class Size3d < Size2d

    DEFAULT_AXES = [ X_AXIS, Y_AXIS, Z_AXIS ]

    attr_accessor :thickness, :axes

    def initialize(length = 0, width = 0, thickness = 0, axes = DEFAULT_AXES)
      if length.is_a?(String)    # String representation of a size "LxLxL"
        s_length, s_width, s_thickness = StringUtils.split_dxdxd(length)
        length = s_length.to_l
        width = s_width.to_l
        thickness = s_thickness.to_l
      elsif length.is_a?(Array) && length.length >= 3  # Array(3) of inch float
        a_size = length
        length = a_size[0].to_l
        width = a_size[1].to_l
        thickness = a_size[2].to_l
      end
      super(length, width)
      @thickness = thickness
      @axes = axes
    end

    # -----

    def self.create_from_bounds(bounds, scale, auto_orient = false)
      if auto_orient
        ordered = [
            { :value => (bounds.width * scale.x).to_l, :axis => X_AXIS, :sub_sort_index => 2 },
            { :value => (bounds.height * scale.y).to_l, :axis => Y_AXIS, :sub_sort_index => 1 },
            { :value => (bounds.depth * scale.z).to_l, :axis => Z_AXIS, :sub_sort_index => 0 }
        ].sort_by { |item| [ item[:value], item[:sub_sort_index] ] }   # Added sub_sort_index as sort parameter to sort equals values in default axes order.
        Size3d.new(ordered[2][:value], ordered[1][:value], ordered[0][:value], [ ordered[2][:axis], ordered[1][:axis], ordered[0][:axis] ])
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

    def auto_oriented?
      @axes != DEFAULT_AXES
    end

    def axes_flipped?
      AxisUtils.flipped?(@axes[0], @axes[1], @axes[2])
    end

    def oriented_axis(axis)
      case axis
        when X_AXIS
          @axes[0]
        when Y_AXIS
          @axes[1]
        when Z_AXIS
          @axes[2]
        else
          raise 'Invalid axis'
      end
    end

    def oriented_transformation
      Geom::Transformation.axes(ORIGIN, @axes[0], @axes[1], @axes[2])
    end

    def axes_to_values
      r = {}
      r[@axes[0] == X_AXIS ? :x : @axes[0] == Y_AXIS ? :y : :z] = @length.to_f
      r[@axes[1] == X_AXIS ? :x : @axes[1] == Y_AXIS ? :y : :z] = @width.to_f
      r[@axes[2] == X_AXIS ? :x : @axes[2] == Y_AXIS ? :y : :z] = @thickness.to_f
      r
    end

    def axes_to_dimensions
      r = {}
      r[@axes[0] == X_AXIS ? :x : @axes[0] == Y_AXIS ? :y : :z] = 'length'
      r[@axes[1] == X_AXIS ? :x : @axes[1] == Y_AXIS ? :y : :z] = 'width'
      r[@axes[2] == X_AXIS ? :x : @axes[2] == Y_AXIS ? :y : :z] = 'thickness'
      r
    end

    def dimensions_to_axes
      r = {}
      r[:length] = @axes[0] == X_AXIS ? 'x' : @axes[0] == Y_AXIS ? 'y' : 'z'
      r[:width] = @axes[1] == X_AXIS ? 'x' : @axes[1] == Y_AXIS ? 'y' : 'z'
      r[:thickness] = @axes[2] == X_AXIS ? 'x' : @axes[2] == Y_AXIS ? 'y' : 'z'
      r
    end

    # -----

    # Returns square area axis to given axis
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
