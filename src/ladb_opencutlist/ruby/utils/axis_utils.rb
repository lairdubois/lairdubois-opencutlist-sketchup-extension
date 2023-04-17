module Ladb::OpenCutList

  class AxisUtils

    def self.flipped?(x_axis, y_axis, z_axis)
      x_axis.cross(y_axis) != z_axis
    end

    def self.skewed?(x_axis, y_axis, z_axis)
      ![
        x_axis % y_axis,
        y_axis % z_axis,
        z_axis % x_axis
      ].all? { |p| p == 0 }
    end

  end

end

