module Ladb::OpenCutList::LGeom

  # https://github.com/thomthom/transformation-inspector/blob/master/src/tt_transformation/transformation_helper.rb

  require_relative 'transformation'

  module TransformationHelper

    # module Example
    #
    #   def self.inspect_flipped
    #     tr = Sketchup.active_model.selection[0].transformation
    #     tr.extend(TransformationHelper)
    #
    #     p tr.flipped_x?
    #     p tr.flipped_y?
    #     p tr.flipped_z?
    #   end
    #
    # end

    # @note Return angles in degrees
    # @return [Hash]
    def decompose_matrix
      {
        rotation: euler_angles.map(&:radians),
        scale: scaling,
      }
    end

    # @result [Array<Float, Float, Float>] rotation angles in radians
    def euler_angles
      LTransformation.euler_angles(self)
    rescue StandardError => error
      puts error
      [0.0, 0.0, 0.0]
    end

    # @param [Float]
    def x_scale
      scale = LTransformation.xscale(self)
      flipped_x? ? -scale : scale
    rescue StandardError => error
      puts error
      0.0
    end

    # @param [Float]
    def y_scale
      scale = LTransformation.yscale(self)
      flipped_y? ? -scale : scale
    rescue StandardError => error
      puts error
      0.0
    end

    # @param [Float]
    def z_scale
      scale = LTransformation.zscale(self)
      flipped_z? ? -scale : scale
    rescue StandardError => error
      puts error
      0.0
    end

    # @result [Array<Float, Float, Float>]
    def scaling
      [x_scale, y_scale, z_scale]
    end

    def flipped?
      dot_x, dot_y, dot_z = axes_dot_products
      flipped_dot?(dot_x, dot_y, dot_z)
    end

    def flipped_x?
      dot_x, dot_y, dot_z = axes_dot_products
      dot_x < 0 && flipped_dot?(dot_x, dot_y, dot_z)
    end

    def flipped_y?
      dot_x, dot_y, dot_z = axes_dot_products
      dot_y < 0 && flipped_dot?(dot_x, dot_y, dot_z)
    end

    def flipped_z?
      dot_x, dot_y, dot_z = axes_dot_products
      dot_z < 0 && flipped_dot?(dot_x, dot_y, dot_z)
    end

    private

    def axes_dot_products
      [
        xaxis.dot(X_AXIS),
        yaxis.dot(Y_AXIS),
        zaxis.dot(Z_AXIS)
      ]
    end

    def flipped_dot?(dot_x, dot_y, dot_z)
      dot_x * dot_y * dot_z < 0
    end

  end

end
