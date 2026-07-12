module Ladb::OpenCutList

  module AxisUtils

    def self.flipped?(x_axis, y_axis, z_axis)
      (x_axis * y_axis) % z_axis < 0
    end

    def self.skewed?(x_axis, y_axis, z_axis)
      x_norm = x_axis.normalize
      y_norm = y_axis.normalize
      z_norm = z_axis.normalize
      ![
        x_norm % y_norm,
        y_norm % z_norm,
        z_norm % x_norm
      ].all? { |p| p.abs < 1e-6 }
    end

  end

end

