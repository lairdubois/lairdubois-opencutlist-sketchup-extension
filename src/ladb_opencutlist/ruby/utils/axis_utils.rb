module Ladb::OpenCutList

  class AxisUtils

    def self.flipped?(x_axis, y_axis, z_axis)
      if skewed?(x_axis, y_axis, z_axis)
        (x_axis % X_AXIS) * (y_axis % Y_AXIS) * (z_axis % Z_AXIS) < 0
      else
        !(x_axis * y_axis).samedirection?(z_axis)
      end
    end

    def self.skewed?(x_axis, y_axis, z_axis)
      ![
        x_axis % y_axis,
        y_axis % z_axis,
        z_axis % x_axis
      ].all? { |p| p.abs < Float::EPSILON }
    end

  end

end

