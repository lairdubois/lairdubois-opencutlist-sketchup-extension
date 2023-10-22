module Ladb::OpenCutList

  require_relative 'common_decompose_drawing_worker'
  require_relative '../../lib/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'

  class CommonProjectionWorker

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @option_down_to_up_union = settings.fetch('down_to_up_union', false)
      @option_passthrough_holes = settings.fetch('passthrough_holes', false)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      bounds_depth = @drawing_def.bounds.depth
      bounds_max = @drawing_def.bounds.max

      z_min = 0.0
      z_max = bounds_max.z

      # Only exposed faces
      exposed_face_manipulators = @drawing_def.face_manipulators.select do |face_manipulator|
        !face_manipulator.perpendicular?(@drawing_def.input_face_manipulator) && @drawing_def.input_face_manipulator.angle_between(face_manipulator) < Math::PI / 2.0
      end

      # Populate face def (loops and depth)
      face_defs = []
      exposed_face_manipulators.each do |face_manipulator|

        if face_manipulator.parallel?(@drawing_def.input_face_manipulator) && bounds_depth > 0
          depth = bounds_max.distance_to_plane(face_manipulator.plane).round(6)
        else
          depth = (z_max - face_manipulator.outer_loop_points.max { |p1, p2| p1.z <=> p2.z }.z).round(6)
        end

        face_def = {
          :depth => depth,
          :loops => face_manipulator.loop_manipulators.map { |loop_manipulator| loop_manipulator.points }
        }
        face_defs << face_def

      end

      top_layer_def = {
        :depth => z_min,
        :coords => []
      }
      bottom_layer_def = {
        :depth => z_max,
        :coords => []
      }

      layer_defs = {}
      layer_defs[z_min] = top_layer_def
      layer_defs[z_max] = bottom_layer_def

      face_defs.each do |face_def|

        f_coords = face_def[:loops].map { |points| Clippy.points_to_coords(points) }

        layer_def = layer_defs[face_def[:depth]]
        if layer_def.nil?
          layer_def = {
            :depth => face_def[:depth],
            :coords => f_coords
          }
          layer_defs[face_def[:depth]] = layer_def
        else

          Clippy.clear
          Clippy.append_subjects(layer_def[:coords])
          Clippy.append_clips(f_coords)

          layer_def[:coords] = Clippy.compute_union
        end

      end

      # Sort on depth ASC
      ld = layer_defs.values.sort_by { |layer_def| layer_def[:depth] }

      # Up to Down difference
      ld.each_with_index do |layer_def, index|
        next if layer_def[:coords].empty?
        ld[(index + 1)..-1].each do |lower_layer_def|
          next if lower_layer_def[:coords].empty?

          Clippy.clear
          Clippy.append_subjects(lower_layer_def[:coords])
          Clippy.append_clips(layer_def[:coords])

          lower_layer_def[:coords] = Clippy.compute_difference

        end
      end


      if @option_down_to_up_union

        # Down to Up union
        ld.each_with_index do |layer_def, index|
          next if layer_def[:coords].empty?
          ld[(index + 1)..-1].reverse.each do |lower_layer_def|
            next if lower_layer_def[:coords].empty?

            Clippy.clear
            Clippy.append_subjects(ld[index][:coords])
            Clippy.append_clips(lower_layer_def[:coords])

            ld[index][:coords] = Clippy.compute_union

          end
        end

      end


      if @option_passthrough_holes

        # Add top holes as bottom plain
        top_layer_def[:coords].each do |coords|

          points = Clippy.coords_to_points(coords)
          unless Clippy.ccw?(points)
            bottom_layer_def[:coords] << coords
          end

        end
        unless bottom_layer_def[:coords].empty?

          # Down to Up union
          ld.each_with_index do |layer_def, index|
            next if layer_def[:coords].empty?
            ld[(index + 1)..-1].reverse.each do |lower_layer_def|
              next if lower_layer_def[:coords].empty?

              Clippy.clear
              Clippy.append_subjects(ld[index][:coords])
              Clippy.append_clips(lower_layer_def[:coords])

              ld[index][:coords] = Clippy.compute_union

            end
          end

        end

      end

      # Output

      projection_def = ProjectionDef.new

      ld.each do |layer_def|
        next if layer_def[:coords].empty?

        projection_layer_def = ProjectionLayerDef.new(
          layer_def[:depth],
          layer_def[:coords].map { |coords| ProjectionPolygonDef.new(Clippy.coords_to_points(coords, z_max - layer_def[:depth])) }
        )
        projection_def.layer_defs << projection_layer_def

      end

      projection_def
    end

  end

  # -----

  class ProjectionDef

    attr_reader :layer_defs

    def initialize
      @layer_defs = []
    end

  end

  class ProjectionLayerDef

    attr_reader :depth, :polygon_defs

    def initialize(depth, polygon_defs)
      @depth = depth
      @polygon_defs = polygon_defs
    end

  end

  class ProjectionPolygonDef

    attr_reader :points

    def initialize(points)
      @points = points
    end

    def outer?
      if @is_outer.nil?
        @is_outer = Clippy.ccw?(@points)
      end
      @is_outer
    end

    def segments
      (@points + [ @points.first ]).each_cons(2).to_a.flatten
    end

    def loop_def
      if @loop_def.nil?
        @loop_def = Geometrix::LoopFinder.find_loop_def(points)
      end
      @loop_def
    end

  end

end