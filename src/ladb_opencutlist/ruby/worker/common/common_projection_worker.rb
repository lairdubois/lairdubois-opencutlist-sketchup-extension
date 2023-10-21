module Ladb::OpenCutList

  require_relative 'common_decompose_drawing_worker'
  require_relative '../lib/clippy/clippy'

  class CommonProjectionWorker

    def initialize(drawing_def, option = {})

      @drawing_def = drawing_def

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)

      @group = Sketchup.active_model.entities.add_group if @group.nil?
      @group.entities.clear!

      # Only exposed faces
      exposed_face_manipulators = @drawing_def.face_manipulators.select do |face_manipulator|
        !face_manipulator.perpendicular?(@drawing_def.input_face_manipulator) && @drawing_def.input_face_manipulator.angle_between(face_manipulator) < Math::PI / 2.0
      end

      face_defs = []
      exposed_face_manipulators.each do |face_manipulator|

        face_def = {
          :loops => face_manipulator.loop_manipulators.map { |loop_manipulator| loop_manipulator.points },
          :depth => face_manipulator.data[:depth]
        }
        face_defs << face_def

      end

      top_layer_def = {
        :depth => 0.0,
        :coords => []
      }
      bottom_layer_def = {
        :depth => @drawing_def.bounds.max.z,
        :coords => []
      }

      layer_defs = {}
      layer_defs[0.0] = top_layer_def
      layer_defs[@drawing_def.bounds.max.z] = bottom_layer_def

      face_defs.each do |face_def|

        f_coords = []
        face_def[:loops].each { |points|
          f_coords << Clippy.points_to_coords(points)
        }

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

    # -----

    private


  end

  # -----

  class ProjectionDef

    def initialize
      @layers = []
    end

  end

  class ProjectionLayerDef

    attr_accessor :depth

    def initialize(depth)
      @depth = depth
    end

  end

end