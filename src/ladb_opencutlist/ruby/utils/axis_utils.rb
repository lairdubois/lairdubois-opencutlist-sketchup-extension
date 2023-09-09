module Ladb::OpenCutList

  class AxisUtils

    def self.flipped?(x_axis, y_axis, z_axis)
      x_axis.dot(X_AXIS) * y_axis.dot(Y_AXIS) * z_axis.dot(Z_AXIS) < 0
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

