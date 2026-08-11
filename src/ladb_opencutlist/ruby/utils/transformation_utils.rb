module Ladb::OpenCutList

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

    # Decomposes a Geom::Transformation into translation, scaling, and Euler rotation angles.
    # Correctly handles:
    #   - non-uniform scaling
    #   - uniform scale factor stored in m[15]
    #   - mirror/reflection (detected via cross-product, sign assigned to X axis by convention)
    #
    # Returns: [ translation, scaling, rotation ]
    #   translation - [tx, ty, tz] in model units (inches)
    #   scaling     - [sx, sy, sz] (negative component indicates a mirror)
    #   rotation    - [rx, ry, rz] in radians (Euler XYZ intrinsic)
    #
    # Rotation extraction source:
    #   "Extracting Euler Angles from a Rotation Matrix", Mike Day, Insomniac Games
    #   http://www.insomniacgames.com/mike-day-extracting-euler-angles-from-a-rotation-matrix/
    def self.decompose(transformation)
      m = transformation.to_a.clone

      # --- Translation ---
      # Stored directly in elements [12, 13, 14] (last column, column-major layout)
      translation = m.values_at(12, 13, 14)

      # --- Scaling ---
      # m[15] holds a global uniform scale factor (often 1.0, but not always).
      # The per-axis scale is the norm of each column of the 3x3 sub-matrix,
      # multiplied by m[15] to account for the uniform factor.
      scaling    = Array.new(3)
      scaling[0] = m[15] * Math.sqrt(m[0]**2 + m[1]**2 + m[2]**2)
      scaling[1] = m[15] * Math.sqrt(m[4]**2 + m[5]**2 + m[6]**2)
      scaling[2] = m[15] * Math.sqrt(m[8]**2 + m[9]**2 + m[10]**2)

      # Normalise each column by its scale so the remaining 3x3 is a pure rotation matrix
      [0, 1, 2].each  { |i| m[i]    /= scaling[0] } unless scaling[0] == 0.0
      [4, 5, 6].each  { |i| m[i]    /= scaling[1] } unless scaling[1] == 0.0
      [8, 9, 10].each { |i| m[i]    /= scaling[2] } unless scaling[2] == 0.0
      m[15] = 1.0  # reset the uniform factor now that it has been absorbed

      # --- Mirror detection ---
      # For a proper rotation matrix, X cross Y must point in the same direction as Z.
      # If the dot product is negative, the basis is left-handed: a mirror is present.
      # By convention we assign the negative sign to the X axis (flip column 0).
      x_axis    = Geom::Vector3d.new(m[0], m[1], m[2])
      y_axis    = Geom::Vector3d.new(m[4], m[5], m[6])
      z_axis    = Geom::Vector3d.new(m[8], m[9], m[10])
      z_rebuilt = x_axis.cross(y_axis)

      if z_rebuilt.dot(z_axis) < 0
        scaling[0] = -scaling[0]   # mirror detected — negate X scale by convention
        m[0], m[1], m[2] = -m[0], -m[1], -m[2]  # flip X column to restore right-hand basis
      end

      # --- Rotation (Euler XYZ intrinsic, in radians) ---
      # After removing scale and mirror, m is a pure rotation matrix.
      # Layout (column-major → row-major reading):
      #   m[0]  m[4]  m[8]
      #   m[1]  m[5]  m[9]
      #   m[2]  m[6]  m[10]
      theta1 = Math.atan2(m[6], m[10])                        # rotation around X
      c2     = Math.sqrt(m[0]**2 + m[1]**2)
      theta2 = Math.atan2(-m[2], c2)                          # rotation around Y
      s1     = Math.sin(theta1)
      c1     = Math.cos(theta1)
      theta3 = Math.atan2(s1 * m[8] - c1 * m[4],
                          c1 * m[5] - s1 * m[9])             # rotation around Z

      # Negate angles: SketchUp's right-hand convention requires this sign flip
      rotation = [ theta1, theta2, theta3 ]

      [ translation, scaling, rotation ]
    end

    # Displays a Geom::Transformation in a human-readable format in the Ruby Console.
    # Usage: TransformationHelper.print_transform(my_transformation)
    #
    # Parameters:
    #   t         - Geom::Transformation to display
    #   label     - optional title shown above the output (default: "Transformation")
    #   precision - number of decimal places for all numeric values (default: 3)
    def self.print(t, label: "Transformation", precision: 3)
      fmt     = ->(v) { "%*.*f" % [8, precision, v] }
      fmt_lng = ->(v) { "%*.*f" % [8, precision, v.to_l.to_mm] }
      fmt_deg = ->(r) { "%*.2f°" % [8, r.radians] }

      # Raw matrix display (column-major → row-major for readability)
      m    = t.to_a
      rows = Array.new(4) { |r| Array.new(4) { |c| m[c * 4 + r] } }

      # Each value is formatted as "%*.*f" % [8, precision, v], so its width is:
      # max(8, precision + integer_digits + 1_dot) — but we fix field width to 8.
      # A row contains: 3 rotation values separated by "  " + " | " + 1 translation + " |"
      col_width  = [8, precision + 5].max   # at least 8 chars per value
      row_width  = col_width * 3 + 2 * 2    # 3 values + 2 separators of 2 spaces
      total_width = row_width + 3 + col_width + 2  # " │ " + translation + " │"

      puts "\n#{label}"
      puts "  ┌" + "─" * total_width + "┐"
      rows[0..2].each do |row|
        rotation_part = row[0..2].map { |v| fmt.(v) }.join("  ")
        puts "  │ #{rotation_part} │ #{fmt_lng.(row[3])} │"
      end
      puts "  └" + "─" * total_width + "┘"
      puts "  " + "─" * (total_width + 2)

      translation, scaling, rotation = decompose(t)

      tx, ty, tz = translation
      puts "  Translation : x=#{fmt_lng.(tx)}  y=#{fmt_lng.(ty)}  z=#{fmt_lng.(tz)}"

      sx, sy, sz = scaling
      mirror = sx < 0 || sy < 0 || sz < 0
      puts "  Scale       : x=#{fmt.(sx)}  y=#{fmt.(sy)}  z=#{fmt.(sz)}"
      puts "  Mirror      : #{mirror ? "yes (X axis by convention)" : "no"}"

      rx, ry, rz = rotation
      puts "  Rotation    : x=#{fmt_deg.(rx)}  y=#{fmt_deg.(ry)}  z=#{fmt_deg.(rz)}"

      puts "  Identity    : #{t.identity? ? "yes" : "no"}"
      puts ""
      nil
    end

  end

end

