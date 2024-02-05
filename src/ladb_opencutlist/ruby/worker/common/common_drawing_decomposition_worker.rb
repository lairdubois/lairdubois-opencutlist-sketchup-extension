module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/layer_visibility_helper'
  require_relative '../../utils/path_utils'
  require_relative '../../utils/transformation_utils'
  require_relative '../../manipulator/face_manipulator'
  require_relative '../../manipulator/edge_manipulator'
  require_relative '../../manipulator/surface_manipulator'
  require_relative '../../manipulator/curve_manipulator'
  require_relative '../../model/drawing/drawing_def'

  class CommonDrawingDecompositionWorker

    include LayerVisibilityHelper

    ORIGIN_POSITION_DEFAULT = 0 # = Path Origin
    ORIGIN_POSITION_FACES_BOUNDS_MIN = 1
    ORIGIN_POSITION_EDGES_BOUNDS_MIN = 2
    ORIGIN_POSITION_BOUNDS_MIN = 3

    FACE_VALIDATOR_ALL = 0
    FACE_VALIDATOR_ONE = 1
    FACE_VALIDATOR_COPLANAR = 2
    FACE_VALIDATOR_PARALLEL = 3
    FACE_VALIDATOR_EXPOSED = 4

    EDGE_VALIDATOR_ALL = 0
    EDGE_VALIDATOR_COPLANAR = 1
    EDGE_VALIDATOR_STRAY = 2
    EDGE_VALIDATOR_STRAY_COPLANAR = 3

    def initialize(path, settings = {})

      @path = path

      @input_local_x_axis = settings.fetch('input_local_x_axis', X_AXIS)
      @input_local_y_axis = settings.fetch('input_local_y_axis', Y_AXIS)
      @input_local_z_axis = settings.fetch('input_local_z_axis', Z_AXIS)

      @input_face_path = settings.fetch('input_face_path', nil)
      @input_edge_path = settings.fetch('input_edge_path', nil)

      @origin_position = settings.fetch('origin_position', ORIGIN_POSITION_DEFAULT)

      @ignore_faces = settings.fetch('ignore_faces', false)
      @ignore_surfaces = settings.fetch('ignore_surfaces', false)
      @face_validator = settings.fetch('face_validator', FACE_VALIDATOR_ALL)

      @ignore_edges = settings.fetch('ignore_edges', false)
      @edge_validator = settings.fetch('edge_validator', EDGE_VALIDATOR_ALL)

    end

    # -----

    # def tr(group = nil, level = 0)
    #   if group.nil?
    #     SKETCHUP_CONSOLE.clear
    #     group = Sketchup.active_model
    #   end
    #   puts "#{''.rjust(level, ' ')}#{''.rjust(group.name.length, '-')}"
    #   puts "#{''.rjust(level, ' ')}#{group.name}#{Sketchup.active_model.active_path.is_a?(Array) && Sketchup.active_model.active_path.last == group ? ' (active)' : ''}"
    #   group.edit_transform.to_a.each_slice(4) { |row| puts "#{''.rjust(level + 1, ' ')}#{row.map { |v| v.to_mm.round(6) }.join(' ')}" } if group.respond_to?(:edit_transform)
    #   group.transformation.to_a.each_slice(4) { |row| puts "#{''.rjust(level + 1, ' ')}#{row.map { |v| v.to_mm.round(6) }.join(' ')}" } if group.respond_to?(:transformation)
    #   group.entities.grep(Sketchup::Edge).each { |edge| puts "#{''.rjust(level, ' ')}edge.x = #{edge.start.position.x}" }
    #   group.entities.grep(Sketchup::Edge).each { |edge| puts "#{''.rjust(level, ' ')}edge.x(t) = #{edge.start.position.transform(Sketchup.active_model.edit_transform.inverse).x}" } if Sketchup.active_model.edit_transform
    #   group.entities.grep(Sketchup::Group).each { |sub_group| tr(sub_group, level + 1) }
    # end

    def run
      return { :errors => [ 'default.error' ] } unless @path.is_a?(Array)
      return { :errors => [ 'default.error' ] } if Sketchup.active_model.nil?

      # Extract drawing element
      drawing_element = @path.last
      drawing_element = Sketchup.active_model if drawing_element.nil?

      return { :errors => [ 'default.error' ] } unless drawing_element.is_a?(Sketchup::Drawingelement) || drawing_element.is_a?(Sketchup::Model)

      # Compute transformation to drawing element
      transformation = PathUtils::get_transformation(@path, IDENTITY)

      # Extract first level of child entities
      if drawing_element.is_a?(Sketchup::Model) || drawing_element.is_a?(Sketchup::Group)
        entities = drawing_element.entities
      elsif drawing_element.is_a?(Sketchup::ComponentInstance)
        entities = drawing_element.definition.entities
      else
        entities = [ drawing_element ]
      end

      # Create output data structure
      drawing_def = DrawingDef.new

      # STEP 1 : Determine output axes

      origin = ORIGIN.transform(transformation)
      if @input_face_path

        input_face = @input_face_path.last
        input_edge = @input_edge_path.nil? ? nil : @input_edge_path.last
        input_transformation = PathUtils::get_transformation(@input_face_path)

        drawing_def.input_face_manipulator = FaceManipulator.new(input_face, input_transformation)
        drawing_def.input_edge_manipulator = input_edge.is_a?(Sketchup::Edge) ? EdgeManipulator.new(input_edge, input_transformation) : nil

        if input_edge

          x_axis, y_axis, z_axis, drawing_def.input_edge_manipulator = _get_input_axes(drawing_def.input_face_manipulator, drawing_def.input_edge_manipulator)

        else

          input_inner_transformation = PathUtils::get_transformation(@input_face_path - @path, IDENTITY)
          input_inner_face_manipulator = FaceManipulator.new(input_face, input_inner_transformation)

          if input_inner_face_manipulator.normal.parallel?(@input_local_z_axis) || input_inner_face_manipulator.normal.parallel?(@input_local_y_axis)
            z_axis = drawing_def.input_face_manipulator.normal
            x_axis = @input_local_x_axis.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis * x_axis
          elsif input_inner_face_manipulator.normal.parallel?(@input_local_x_axis)
            z_axis = drawing_def.input_face_manipulator.normal
            x_axis = @input_local_y_axis.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis * x_axis
          else
            x_axis, y_axis, z_axis, drawing_def.input_edge_manipulator = _get_input_axes(drawing_def.input_face_manipulator, nil)
          end

        end

      else

        # Get transformed Z axis
        z_axis = @input_local_z_axis.transform(transformation).normalize

        # Use transformed Y axis to determine YZ plane and compute X as perpendicular to this plane
        y_axis = @input_local_y_axis.transform(transformation).normalize
        yz_plane = Geom.fit_plane_to_points(ORIGIN, Geom::Point3d.new(y_axis.to_a), Geom::Point3d.new(z_axis.to_a))
        x_axis = Geom::Vector3d.new(yz_plane[0..2])

        # Reset Y axis as cross product Z * X and keep a real orthonormal system
        y_axis = z_axis * x_axis

      end

      ta = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
      tai = ta.inverse
      ttai = tai * transformation

      drawing_def.transformation = ta
      drawing_def.input_face_manipulator.transformation = tai * drawing_def.input_face_manipulator.transformation unless drawing_def.input_face_manipulator.nil?
      drawing_def.input_edge_manipulator.transformation = tai * drawing_def.input_edge_manipulator.transformation unless drawing_def.input_edge_manipulator.nil?

      # STEP 2 : Populate faces and edges manipulators

      # Faces
      unless @ignore_faces

        validator = nil
        if drawing_def.input_face_manipulator
          case @face_validator
          when FACE_VALIDATOR_ONE
            validator = lambda { |face_manipulator|
              face_manipulator == drawing_def.input_face_manipulator
            }
          when FACE_VALIDATOR_COPLANAR
            validator = lambda { |face_manipulator|
              face_manipulator.coplanar?(drawing_def.input_face_manipulator)
            }
          when FACE_VALIDATOR_PARALLEL
            validator = lambda { |face_manipulator|
              face_manipulator.parallel?(drawing_def.input_face_manipulator)
            }
          when FACE_VALIDATOR_EXPOSED
            validator = lambda { |face_manipulator|
              !face_manipulator.perpendicular?(drawing_def.input_face_manipulator) && drawing_def.input_face_manipulator.angle_between(face_manipulator) < Math::PI / 2.0
            }
          end
        end

        _populate_face_manipulators(drawing_def, entities, ttai, &validator)

      end

      # Edges
      unless @ignore_edges

        validator = nil

        case @edge_validator
        when EDGE_VALIDATOR_COPLANAR
          validator = lambda { |edge_manipulator|
            return false if drawing_def.input_face_manipulator.nil?
            point, vector = edge_manipulator.line
            vector.perpendicular?(drawing_def.input_face_manipulator.normal) && point.on_plane?(drawing_def.input_face_manipulator.plane)
          }
        when EDGE_VALIDATOR_STRAY
          validator = lambda { |edge_manipulator|
            edge_manipulator.edge.faces.empty?
          }
        when EDGE_VALIDATOR_STRAY_COPLANAR
          validator = lambda { |edge_manipulator|
            return false if drawing_def.input_face_manipulator.nil?
            if edge_manipulator.edge.faces.empty?
              point, vector = edge_manipulator.line
              vector.perpendicular?(drawing_def.input_face_manipulator.normal) && point.on_plane?(drawing_def.input_face_manipulator.plane)
            else
              false
            end
          }
        end

        _populate_edge_manipulators(drawing_def, entities, ttai, &validator)

      end

      # STEP 3 : Compute bounds

      drawing_def.bounds.clear
      unless @ignore_faces
        drawing_def.face_manipulators.each do |face_manipulator|
          drawing_def.faces_bounds.add(face_manipulator.outer_loop_points)
        end
        drawing_def.bounds.add(drawing_def.faces_bounds.min, drawing_def.faces_bounds.max)
      end
      unless @ignore_edges
        drawing_def.edge_manipulators.each do |edge_manipulator|
          drawing_def.edges_bounds.add(edge_manipulator.points)
        end
        drawing_def.curve_manipulators.each do |curve_manipulator|
          drawing_def.edges_bounds.add(curve_manipulator.points)
        end
        drawing_def.bounds.add(drawing_def.edges_bounds.min, drawing_def.edges_bounds.max)
      end

      # STEP 4 : Customize origin

      if @origin_position != ORIGIN_POSITION_DEFAULT
        case @origin_position
        when ORIGIN_POSITION_FACES_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.faces_bounds.min)
        when ORIGIN_POSITION_EDGES_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.edges_bounds.min)
        when ORIGIN_POSITION_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.bounds.min)
        end
      end

      drawing_def.input_normal = drawing_def.input_face_manipulator.normal if drawing_def.input_face_manipulator

      drawing_def
    end

    # -----

    private

    def _get_input_axes(input_face_manipulator, input_edge_manipulator = nil)

      if input_edge_manipulator.nil? || !input_edge_manipulator.edge.used_by?(input_face_manipulator.face)
        input_edge_manipulator = EdgeManipulator.new(input_face_manipulator.longest_outer_edge, input_face_manipulator.transformation)
      end

      z_axis = input_face_manipulator.normal
      x_axis = input_edge_manipulator.line[1].normalize
      x_axis.reverse! if input_edge_manipulator.reversed_in?(input_face_manipulator.face)
      y_axis = z_axis.cross(x_axis).normalize

      [ x_axis, y_axis, z_axis, input_edge_manipulator ]
    end

    def _populate_face_manipulators(drawing_def, entities, transformation = IDENTITY, &validator)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            manipulator = FaceManipulator.new(entity, transformation)

            if !block_given? || yield(manipulator)

              unless @ignore_surfaces

                # TODO : Quite slow
                if manipulator.belongs_to_a_surface?
                  surface_manipulator = _get_surface_manipulator_by_face(drawing_def, entity, transformation)
                  if surface_manipulator.nil?
                    surface_manipulator = SurfaceManipulator.new(transformation)
                    _populate_surface_manipulator(surface_manipulator, entity)
                    drawing_def.surface_manipulators.push(surface_manipulator)
                  end
                  manipulator.surface_manipulator = surface_manipulator
                end
                # TODO : Quite slow

              end

              drawing_def.face_manipulators.push(manipulator)

            end

          elsif entity.is_a?(Sketchup::Group)
            _populate_face_manipulators(drawing_def, entity.entities, transformation * entity.transformation, &validator)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            _populate_face_manipulators(drawing_def, entity.definition.entities, transformation * entity.transformation, &validator)
          end
        end
      end
    end

    def _populate_edge_manipulators(drawing_def, entities, transformation = IDENTITY, &validator)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Edge)
            manipulator = EdgeManipulator.new(entity, transformation)
            if !block_given? || yield(manipulator)
              if entity.curve.nil? || entity.curve.count_edges < 2  # Exclude curve that contains only one edge.
                drawing_def.edge_manipulators.push(manipulator)
              else
                curve_manipulator = _get_curve_manipulator_by_edge(drawing_def, entity, transformation)
                if curve_manipulator.nil?
                  curve_manipulator = CurveManipulator.new(entity.curve, transformation)
                  drawing_def.curve_manipulators.push(curve_manipulator)
                end
              end
            end
          elsif entity.is_a?(Sketchup::Group)
            _populate_edge_manipulators(drawing_def, entity.entities, transformation * entity.transformation, &validator)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            _populate_edge_manipulators(drawing_def, entity.definition.entities, transformation * entity.transformation, &validator)
          end
        end
      end
    end

    def _populate_surface_manipulator(surface_manipulator, face)
      explored_faces = Set.new
      faces_to_explore = [ face ]
      until faces_to_explore.empty?
        current_face = faces_to_explore.pop
        current_face.edges.each do |edge|
          next unless edge.soft?
          surface_manipulator.faces.push(current_face)
          edge.faces.each do |f|
            next if f == current_face
            next unless f.visible? && _layer_visible?(f.layer)
            next if explored_faces.include?(f)
            faces_to_explore.push(f)
          end
        end
        explored_faces.add(current_face)
      end
    end

    def _get_surface_manipulator_by_face(drawing_def, face, transformation)
      drawing_def.surface_manipulators.each do |surface_manipulator|
        next unless surface_manipulator.transformation.equal?(transformation) # Check if same context
        return surface_manipulator if surface_manipulator.include?(face)
      end
      nil
    end

    def _get_curve_manipulator_by_edge(drawing_def, edge, transformation)
      drawing_def.curve_manipulators.each do |curve_manipulator|
        next unless curve_manipulator.transformation.equal?(transformation) # Check if same context
        return curve_manipulator if curve_manipulator.curve.equal?(edge.curve)
      end
      nil
    end

  end

end