module Ladb::OpenCutList

  require_relative '../../lib/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/drawing/drawing_projection_def'

  class CommonDrawingProjectionWorker

    MINIMAL_PATH_AREA = 1e-6

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @option_down_to_top_union = settings.fetch('down_to_top_union', false)  # All down layers are merged to top layer
      @option_passthrough_holes = settings.fetch('passthrough_holes', false)  # All hole polygons detected in top layer are moved to bottom layer and merged to top layer

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      bounds_depth = @drawing_def.bounds.depth
      bounds_max = @drawing_def.bounds.max

      depth_top = 0.0
      depth_bottom = bounds_depth.round(6)

      z_max = bounds_max.z

      # Filter only exposed faces
      exposed_face_manipulators = @drawing_def.face_manipulators.select do |face_manipulator|
        !face_manipulator.perpendicular?(@drawing_def.input_normal) && face_manipulator.angle_between(@drawing_def.input_normal) < Math::PI / 2.0
      end

      # Populate face def (loops and depth)
      face_defs = []
      exposed_face_manipulators.each do |face_manipulator|

        if face_manipulator.parallel?(@drawing_def.input_normal) && bounds_depth > 0
          depth = bounds_max.distance_to_plane(face_manipulator.plane).round(6)
        else
          if face_manipulator.surface_manipulator
            depth = (z_max - face_manipulator.surface_manipulator.z_max).round(6) # Faces sharing the same "surface" are considered as a unique "box"
          else
            depth = (z_max - face_manipulator.z_max).round(6)
          end
        end

        face_def = {
          :depth => depth,
          :loops => face_manipulator.loop_manipulators.map { |loop_manipulator| loop_manipulator.points }
        }
        face_defs << face_def

      end

      top_layer_def = {
        :position => DrawingProjectionLayerDef::LAYER_POSITION_TOP,
        :depth => depth_top,
        :paths => []
      }
      bottom_layer_def = {
        :position => DrawingProjectionLayerDef::LAYER_POSITION_BOTTOM,
        :depth => depth_bottom,
        :paths => []
      }

      layer_defs = {}
      layer_defs[depth_top] = top_layer_def
      layer_defs[depth_bottom] = bottom_layer_def

      face_defs.each do |face_def|

        f_paths = face_def[:loops].map { |points| Clippy.points_to_rpath(points) }

        layer_def = layer_defs[face_def[:depth]]
        if layer_def.nil?
          layer_def = {
            :position => DrawingProjectionLayerDef::LAYER_POSITION_INSIDE,
            :depth => face_def[:depth],
            :paths => f_paths
          }
          layer_defs[face_def[:depth]] = layer_def
        else
          layer_def[:paths].concat(f_paths) # Just concat, union will be call later in one unique call
        end

      end

      # Sort on depth ASC
      ld = layer_defs.values.sort_by { |layer_def| layer_def[:depth] }

      # Union paths on each layer
      ld.each do |layer_def|
        next if layer_def[:paths].one?
        layer_def[:paths] = Clippy.compute_union(layer_def[:paths])
      end

      # Up to Down difference
      ld.each_with_index do |layer_def, index|
        next if layer_def[:paths].empty?
        ld[(index + 1)..-1].each do |lower_layer_def|
          next if lower_layer_def.nil? || lower_layer_def[:paths].empty?
          lower_layer_def[:paths] = Clippy.compute_difference(lower_layer_def[:paths], layer_def[:paths])
        end
      end

      if @option_down_to_top_union

        # Copy top paths
        min_top_paths = top_layer_def[:paths]

        # Union top paths with lower paths
        mid_top_paths = Clippy.compute_union(min_top_paths + ld[1..-1].map { |layer_def| layer_def[:paths] }.flatten(1).compact)

        # Extract passthrough holes and reverse them to plain path
        passthrough_paths = mid_top_paths.select { |path| !Clippy.is_rpath_positive?(path) }.each_slice(2).to_a.reverse.flatten(1)

        # Union top paths with lower paths
        max_top_paths = Clippy.compute_union(mid_top_paths + passthrough_paths)

        # Difference with max and min to extract holes to propagate
        mask_paths = Clippy.compute_difference(max_top_paths, min_top_paths)

        # Replace bottom layer paths
        bottom_layer_def[:paths] = passthrough_paths

        # Propagate down to up
        ldr = ld.reverse[0..-2] # Exclude top layer
        mask_paths.each do |mask_path|
          lower_paths = []
          ldr.each do |layer_def|
            next if layer_def[:paths].empty?
            next if Clippy.compute_intersection(layer_def[:paths], [ mask_path ]).empty?
            layer_def[:paths] = Clippy.compute_union(lower_paths + layer_def[:paths]) unless lower_paths.empty?
            lower_paths = Clippy.compute_intersection(layer_def[:paths], [ mask_path ])
          end
        end

        # Replace top layer paths
        top_layer_def[:paths] = max_top_paths

      end


      # if @option_down_to_top_union
      #
      #   # Down to Top union
      #   ld[1..-1].each do |lower_layer_def|
      #     next if lower_layer_def[:paths].empty?
      #     top_layer_def[:paths] = Clippy.compute_union(top_layer_def[:paths] + lower_layer_def[:paths])
      #   end
      #
      # end
      #
      # if @option_passthrough_holes
      #
      #   # Move top holes to bottom layer
      #   top_layer_def[:paths].each do |path|
      #     unless Clippy.is_rpath_positive?(path)
      #       bottom_layer_def[:paths] << path
      #     end
      #   end
      #   unless bottom_layer_def[:paths].empty?
      #
      #     # Bottom to Top union
      #     top_layer_def[:paths] = Clippy.compute_union(top_layer_def[:paths] + bottom_layer_def[:paths])
      #
      #   end
      #
      # end

      # Output

      projection_def = DrawingProjectionDef.new(z_max)

      ld.each do |layer_def|
        next if layer_def[:paths].empty?

        polygons = layer_def[:paths].map { |path|
          next if Clippy.get_rpath_area(path).abs < MINIMAL_PATH_AREA # Ignore "artifact" paths generated by successive transformation / union / differences
          DrawingProjectionPolygonDef.new(Clippy.rpath_to_points(path, z_max - layer_def[:depth]), Clippy.is_rpath_positive?(path))
        }.compact

        unless polygons.empty?
          projection_def.layer_defs << DrawingProjectionLayerDef.new(layer_def[:position], layer_def[:depth], polygons)
        end

      end

      projection_def
    end

  end

end