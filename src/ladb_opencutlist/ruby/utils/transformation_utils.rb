module Ladb::OpenCutList

  require_relative '../model/geom/scale3d'
  require_relative 'axis_utils'

  module TransformationUtils

    # Create transformation from origin point and axes vectors.
    #
    # Unlike native +Geom::Transformation.axes+ this method does not make the axes
    # orthogonal or normalize them but uses them as they are, allowing for scaled
    # and sheared transformations.
    #
    # @param origin [Geom::Point3d]
    # @param xaxis [Geom::Vector3d]
    # @param yaxis [Geom::Vector3d]
    # @param zaxis [Geom::Vector3d]
    #
    # @example
    #   # Skew Selected Group/Component
    #   # Select a group or component and run:
    #   e = Sketchup.active_model.selection.first
    #   e.transformation = Ladb::OpenCutList::TransformationUtils.create_from_axes(
    #     ORIGIN,
    #     Geom::Vector3d.new(2, 0.3, 0.3),
    #     Geom::Vector3d.new(0.3, 2, 0.3),
    #     Geom::Vector3d.new(0.3, 0.3, 2)
    #   )
    #
    # @raise [ArgumentError] if any of the provided axes are parallel.
    # @raise [ArgumentError] if any of the vectors are zero length.
    #
    # @return [Geom::Transformation]
    def self.create_from_axes(origin = ORIGIN, xaxis = ZAXIS, yaxis = YAXIS, zaxis = XAXIS)
      unless [ xaxis, yaxis, zaxis ].all?(&:valid?)
        raise ArgumentError, "Axes must not be zero length."
      end
      if xaxis.parallel?(yaxis) || yaxis.parallel?(zaxis) || zaxis.parallel?(xaxis)
        raise ArgumentError, "Axes must not be parallel."
      end

      Geom::Transformation.new([
                                 xaxis.x,  xaxis.y,  xaxis.z,  0,
                                 yaxis.x,  yaxis.y,  yaxis.z,  0,
                                 zaxis.x,  zaxis.y,  zaxis.z,  0,
                                 origin.x, origin.y, origin.z, 1
                               ])
    end

    # Create transformation from origin point and three angles.
    #
    # See +euler_angles+ for details on order of rotations.
    #
    # @param origin [Geom::Point3d]
    # @param x_angle [Float] Rotation in radians
    # @param y_angle [Float] Rotation in radians
    # @param z_angle [Float] Rotation in radians
    #
    # @example
    #   # Compose and Decompose Euler Angle Based Transformation
    #   tr = Ladb::OpenCutList::TransformationUtils.create_from_euler_angles(
    #     ORIGIN,
    #     45.degrees,
    #     45.degrees,
    #     45.degrees
    #   )
    #   Ladb::OpenCutList::TransformationUtils.euler_angles(tr).map(&:radians)
    #
    # @return [Geom::Transformation]
    def self.create_from_euler_angles(origin = ORIGIN, x_angle = 0, y_angle = 0, z_angle = 0)
      Geom::Transformation.new(origin) *
      Geom::Transformation.rotation(ORIGIN, Z_AXIS, z_angle) *
      Geom::Transformation.rotation(ORIGIN, Y_AXIS, y_angle) *
      Geom::Transformation.rotation(ORIGIN, X_AXIS, x_angle)
    end

    # Calculate extrinsic, chained XYZ rotation angles for transformation.
    #
    # Scaling, shearing and translation are all ignored.
    #
    # Note that rotations are not communicative, meaning the order they are
    # applied in matters.
    #
    # @param transformation [Geom::Transformation]
    #
    # @example
    #   # Compose and Decompose Euler Angle Based Transformation
    #   x_angle = -14.degrees
    #   y_angle = 7.degrees
    #   z_angle = 45.degrees
    #   transformation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, z_angle) *
    #     Geom::Transformation.rotation(ORIGIN, Y_AXIS, y_angle) *
    #     Geom::Transformation.rotation(ORIGIN, X_AXIS, x_angle)
    #   angles = Ladb::OpenCutList::TransformationUtils.euler_angles(transformation)
    #   angles.map(&:radians)
    #
    #   # Determine Angles of Selected Group/Component
    #   # Select a group or component and run:
    #   e = Sketchup.active_model.selection.first
    #   Ladb::OpenCutList::TransformationUtils.euler_angles(e.transformation).map(&:radians)
    #
    # @return [Array(Float, Float, Float)] X rotation, Y rotation and Z Rotation
    #   in radians.
    def self.euler_angles(transformation)
      a = remove_scaling(remove_shearing(transformation, false)).to_a

      x = Math.atan2(a[6], a[10])
      c2 = Math.sqrt(a[0]**2 + a[1]**2)
      y = Math.atan2(-a[2], c2)
      s = Math.sin(x)
      c1 = Math.cos(x)
      z = Math.atan2(s * a[8] - c1 * a[4], c1 * a[5] - s * a[9])

      [x, y, z]
    end

    # Return new transformation with scaling removed.
    #
    # All axes of the new transformation have the length 1, meaning that if the
    # transformation was sheared it will still scale volumes, areas and length not
    # parallel to coordinate axes.
    #
    # If transformation is flipped and allow_flip false, the X axis is reversed.
    # Otherwise axes keeps their direction.
    #
    # @param transformation [Geom::Transformation]
    # @param allow_flip [Boolean]
    #
    # @example
    #   # Mimic Context Menu > Reset Scale
    #   # Note that native Reset Scale also resets skew, not just scale.
    #   # Select a skewed group or component and run:
    #   e = Sketchup.active_model.selection.first
    #   e.transformation = Ladb::OpenCutList::TransformationUtils.remove_scaling(
    #     Ladb::OpenCutList::TransformationUtils.remove_shearing(e.transformation, false)
    #   )
    #
    # @return [Geom::Transformation]
    def self.remove_scaling(transformation, allow_flip = false)
      x_axis = xaxis(transformation).normalize
      x_axis.reverse! if flipped?(transformation) && !allow_flip
      create_from_axes(
        transformation.origin,
        x_axis,
        yaxis(transformation).normalize,
        zaxis(transformation).normalize
      )
    end

    # Return new transformation with shearing removed (made orthogonal).
    #
    # The X axis is considered to represent rotation and will remain the same as
    # in the original transformation. The Y axis of the new transformation will
    # however be made perpendicular to the X axis, and the Z axis will be made
    # perpendicular to both the other axes.
    #
    # Note that the SketchUp UI refers to shearing as skewing.
    #
    # @param transformation [Geom::Transformation]
    # @param preserve_determinant_value [Boolean]
    #   If +true+ the determinant value of the transformation, and thus the volume
    #   of an object transformed with it, is preserved. If +false+ lengths along
    #   axes are preserved (the behavior of SketchUp's native Context Menu >
    #   Reset Skew).
    #
    # @example
    #   # Mimic Context Menu > Reset Skew
    #   # Select a skewed group or component and run:
    #   e = Sketchup.active_model.selection.first
    #   e.transformation = Ladb::OpenCutList::TransformationUtils.remove_shearing(e.transformation, false)
    #
    #   # Reset Skewing While Retaining Volume
    #   # Select a skewed group or component and run:
    #   e = Sketchup.active_model.selection.first
    #   e.transformation = Ladb::OpenCutList::TransformationUtils.remove_shearing(e.transformation, true)
    #
    # @return [Geom::Transformation]
    def self.remove_shearing(transformation, preserve_determinant_value = false)
      xaxis = xaxis(transformation)
      yaxis = yaxis(transformation)
      zaxis = zaxis(transformation)

      new_yaxis = xaxis.normalize * yaxis * xaxis.normalize
      new_zaxis = new_yaxis.normalize * (xaxis.normalize * zaxis * xaxis.normalize) * new_yaxis.normalize

      unless preserve_determinant_value
        new_yaxis.length = yaxis.length
        new_zaxis.length = zaxis.length
      end

      create_from_axes(
        transformation.origin,
        xaxis,
        new_yaxis,
        new_zaxis
      )
    end


    # Get the X axis vector of a transformation.
    #
    #
    # Unlike native +Transformation#xaxis+ the length of this axis isn't normalized
    # but resamples the scaling along the axis.
    #
    # @param transformation [Geom::Transformation]
    #
    # @return [Geom::Vector3d]
    def self.xaxis(transformation)
      v = Geom::Vector3d.new(transformation.to_a.values_at(0..2))
      v.length /= transformation.to_a[15]

      v
    end

    # Get the Y axis vector of a transformation.
    #
    #
    # Unlike native +Transformation#yaxis+ the length of this axis isn't normalized
    # but resamples the scaling along the axis.
    #
    # @param transformation [Geom::Transformation]
    #
    # @return [Geom::Vector3d]
    def self.yaxis(transformation)
      v = Geom::Vector3d.new(transformation.to_a.values_at(4..6))
      v.length /= transformation.to_a[15]

      v
    end

    # Get the Z axis vector of a transformation.
    #
    # Unlike native +Transformation#zaxis+ the length of this axis isn't normalized
    # but resamples the scaling along the axis.
    # @param transformation [Geom::Transformation]
    #
    # @return [Geom::Vector3d]
    def self.zaxis(transformation)
      v = Geom::Vector3d.new(transformation.to_a.values_at(8..10))
      v.length /= transformation.to_a[15]

      v
    end


    def self.flipped?(transformation)
      AxisUtils.flipped?(transformation.xaxis, transformation.yaxis, transformation.zaxis)
    end

    def self.skewed?(transformation)
      AxisUtils.skewed?(transformation.xaxis, transformation.yaxis, transformation.zaxis)
    end


    def self.multiply(transformation1, transformation2)
      if transformation1.is_a?(Geom::Transformation)
        if transformation2.is_a?(Geom::Transformation)
          transformation1 * transformation2
        else
          transformation1
        end
      else
        if transformation2.is_a?(Geom::Transformation)
          transformation2
        else
          nil
        end
      end
    end

  end

end

