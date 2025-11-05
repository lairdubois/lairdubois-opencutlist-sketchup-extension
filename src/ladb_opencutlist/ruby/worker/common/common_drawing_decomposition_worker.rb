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

    ORIGIN_POSITION_DEFAULT = 0 # = Drawing Element Origin
    ORIGIN_POSITION_FACES_BOUNDS_MIN = 1
    ORIGIN_POSITION_EDGES_BOUNDS_MIN = 2
    ORIGIN_POSITION_CLINES_BOUNDS_MIN = 3
    ORIGIN_POSITION_BOUNDS_MIN = 4

    FACE_VALIDATOR_ALL = 0
    FACE_VALIDATOR_ONE = 1
    FACE_VALIDATOR_COPLANAR = 2
    FACE_VALIDATOR_PARALLEL = 3
    FACE_VALIDATOR_EXPOSED = 4

    EDGE_VALIDATOR_ALL = 0
    EDGE_VALIDATOR_COPLANAR = 1
    EDGE_VALIDATOR_STRAY = 2
    EDGE_VALIDATOR_STRAY_COPLANAR = 3

    def initialize(path,

                   input_local_x_axis: X_AXIS,
                   input_local_y_axis: Y_AXIS,
                   input_local_z_axis: Z_AXIS,

                   input_plane_manipulator: nil,
                   input_line_manipulator: nil,

                   origin_position: ORIGIN_POSITION_DEFAULT,

                   ignore_faces: false,
                   ignore_surfaces: false,
                   face_validator: FACE_VALIDATOR_ALL,

                   ignore_edges: false,
                   ignore_soft_edges: true,
                   edge_validator: EDGE_VALIDATOR_ALL,

                   ignore_clines: true,

                   for_part: true,
                   recursive: true,
                   flatten: true

    )

      @path = path

      @input_local_x_axis = input_local_x_axis
      @input_local_y_axis = input_local_y_axis
      @input_local_z_axis = input_local_z_axis

      @input_plane_manipulator = input_plane_manipulator
      @input_line_manipulator = input_line_manipulator

      @origin_position = origin_position

      @ignore_faces = ignore_faces
      @ignore_surfaces = ignore_surfaces
      @face_validator = face_validator

      @ignore_edges = ignore_edges
      @ignore_soft_edges = ignore_soft_edges
      @edge_validator = edge_validator

      @ignore_clines = ignore_clines

      @for_part = for_part
      @recursive = recursive
      @flatten = flatten

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @path.is_a?(Array)
      return { :errors => [ 'default.error' ] } if (model = Sketchup.active_model).nil?

      # Extract drawing element
      drawing_element = @path.last
      drawing_element = model if drawing_element.nil?

      return { :errors => [ 'default.error' ] } unless drawing_element.is_a?(Sketchup::Drawingelement) || drawing_element.is_a?(Sketchup::Model)

      # Compute transformation to the drawing element
      transformation = origin_transformation = PathUtils::get_transformation(@path, IDENTITY)

      # Extract container path
      if drawing_element.is_a?(Sketchup::Group) || drawing_element.is_a?(Sketchup::ComponentInstance)
        container_path = @path
        container = drawing_element
      elsif drawing_element.is_a?(Sketchup::Face)
        container_path = @path[0...-1]
        container = @path.last
      else
        container_path = []
        container = model
      end

      # Adapt local axes if model.active_path is container_path
      if model.active_path == container_path

        origin_transformation *= Geom::Transformation.axes(
          ORIGIN.transform(model.edit_transform),
          X_AXIS.transform(model.edit_transform).normalize!,
          Y_AXIS.transform(model.edit_transform).normalize!,
          Z_AXIS.transform(model.edit_transform).normalize!
        )

        @input_local_x_axis = @input_local_x_axis.transform(origin_transformation).normalize!
        @input_local_y_axis = @input_local_y_axis.transform(origin_transformation).normalize!
        @input_local_z_axis = @input_local_z_axis.transform(origin_transformation).normalize!

      end

      # Extract the first level of child entities
      if drawing_element.respond_to?(:entities)
        entities = drawing_element.entities
      elsif drawing_element.respond_to?(:definition) && drawing_element.definition.respond_to?(:entities)
        entities = drawing_element.definition.entities
      else
        entities = [ drawing_element ]
      end

      # Create output data structure
      drawing_def = DrawingDef.new(container)

      # STEP 1 : Determine output axes

      origin = ORIGIN.transform(origin_transformation)
      if @input_plane_manipulator

        drawing_def.input_plane_manipulator = @input_plane_manipulator
        drawing_def.input_line_manipulator = @input_line_manipulator

        if @input_line_manipulator

          x_axis, y_axis, z_axis, drawing_def.input_line_manipulator = _get_input_axes(drawing_def.input_plane_manipulator, drawing_def.input_line_manipulator)

        else

          input_inner_plane_manipulator = PlaneManipulator.new(@input_plane_manipulator.face.plane, @input_plane_manipulator.transformation * transformation.inverse)

          if input_inner_plane_manipulator.normal.parallel?(@input_local_z_axis)

            z_axis = drawing_def.input_plane_manipulator.normal
            x_axis = @input_local_x_axis.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis * x_axis

            drawing_def.input_view = input_inner_plane_manipulator.normal.samedirection?(@input_local_z_axis) ? DrawingDef::INPUT_VIEW_TOP : DrawingDef::INPUT_VIEW_BOTTOM

          elsif input_inner_plane_manipulator.normal.parallel?(@input_local_y_axis)

            z_axis = drawing_def.input_plane_manipulator.normal
            x_axis = @input_local_x_axis.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis * x_axis

            drawing_def.input_view = input_inner_plane_manipulator.normal.samedirection?(@input_local_y_axis) ? DrawingDef::INPUT_VIEW_BACK : DrawingDef::INPUT_VIEW_FRONT

          elsif input_inner_plane_manipulator.normal.parallel?(@input_local_x_axis)

            z_axis = drawing_def.input_plane_manipulator.normal
            x_axis = @input_local_y_axis.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis * x_axis

            drawing_def.input_view = input_inner_plane_manipulator.normal.samedirection?(@input_local_x_axis) ? DrawingDef::INPUT_VIEW_RIGHT : DrawingDef::INPUT_VIEW_LEFT

          else
            x_axis, y_axis, z_axis, drawing_def.input_line_manipulator = _get_input_axes(drawing_def.input_plane_manipulator, nil)
          end

        end

      else

        # Get transformed Z axis
        z_axis = @input_local_z_axis.transform(transformation).normalize

        # Use transformed Y axis to determine YZ plane and compute X as perpendicular to this plane
        y_axis = @input_local_y_axis.transform(transformation).normalize
        yz_plane = Geom.fit_plane_to_points(ORIGIN, Geom::Point3d.new(y_axis.to_a), Geom::Point3d.new(z_axis.to_a))
        x_axis = Geom::Vector3d.new(yz_plane[0..2])

        # Reset Y axis as cross-product Z * X and keep a real orthonormal system
        y_axis = z_axis * x_axis

      end

      return { :errors => [ 'default.error' ] } unless x_axis.valid? && y_axis.valid? && z_axis.valid?

      ta = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
      tai = ta.inverse
      ttai = tai * transformation

      drawing_def.transformation = ta
      drawing_def.input_plane_manipulator.transformation = tai * drawing_def.input_plane_manipulator.transformation unless drawing_def.input_plane_manipulator.nil?
      drawing_def.input_line_manipulator.transformation = tai * drawing_def.input_line_manipulator.transformation unless drawing_def.input_line_manipulator.nil?

      # STEP 2 : Populate faces, edges and clines manipulators

      face_validator = nil
      if drawing_def.input_plane_manipulator
        case @face_validator
        when FACE_VALIDATOR_ONE
          face_validator = lambda { |face_manipulator|
            face_manipulator == drawing_def.input_plane_manipulator
          }
        when FACE_VALIDATOR_COPLANAR
          face_validator = lambda { |face_manipulator|
            face_manipulator.coplanar?(drawing_def.input_plane_manipulator)
          }
        when FACE_VALIDATOR_PARALLEL
          face_validator = lambda { |face_manipulator|
            face_manipulator.parallel?(drawing_def.input_plane_manipulator)
          }
        when FACE_VALIDATOR_EXPOSED
          face_validator = lambda { |face_manipulator|
            !face_manipulator.perpendicular?(drawing_def.input_plane_manipulator) && drawing_def.input_plane_manipulator.angle_between(face_manipulator) < Math::PI / 2.0
          }
        end
      end

      edge_validator = nil
      case @edge_validator
      when EDGE_VALIDATOR_COPLANAR
        edge_validator = lambda { |edge_manipulator|
          return false if drawing_def.input_plane_manipulator.nil?
          edge_manipulator.direction.perpendicular?(drawing_def.input_plane_manipulator.normal) && edge_manipulator.position.on_plane?(drawing_def.input_plane_manipulator.plane)
        }
      when EDGE_VALIDATOR_STRAY
        edge_validator = lambda { |edge_manipulator|
          edge_manipulator.edge.faces.empty?
        }
      when EDGE_VALIDATOR_STRAY_COPLANAR
        edge_validator = lambda { |edge_manipulator|
          return false if drawing_def.input_plane_manipulator.nil?
          if edge_manipulator.edge.faces.empty?
            edge_manipulator.direction.perpendicular?(drawing_def.input_plane_manipulator.normal) && edge_manipulator.position.on_plane?(drawing_def.input_plane_manipulator.plane)
          else
            false
          end
        }
      end

      _populate_manipulators(drawing_def, entities, ttai, face_validator, edge_validator)

      # STEP 3 : Customize origin

      if @origin_position != ORIGIN_POSITION_DEFAULT
        case @origin_position
        when ORIGIN_POSITION_FACES_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.faces_bounds.min) if drawing_def.faces_bounds.valid?
        when ORIGIN_POSITION_EDGES_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.edges_bounds.min) if drawing_def.edges_bounds.valid?
        when ORIGIN_POSITION_CLINES_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.clines_bounds.min) if drawing_def.clines_bounds.valid?
        when ORIGIN_POSITION_BOUNDS_MIN
          drawing_def.translate_to!(drawing_def.bounds.min)
        end
      end

      drawing_def
    end

    # -----

    private

    def _get_input_axes(input_plane_manipulator, input_line_manipulator = nil)

      if input_line_manipulator.nil? || !input_plane_manipulator.normal.perpendicular?(input_line_manipulator.direction)
        if input_plane_manipulator.respond_to?(:longest_outer_edge)
          input_line_manipulator = EdgeManipulator.new(input_plane_manipulator.longest_outer_edge, input_plane_manipulator.transformation)
        else
          input_line_manipulator = LineManipulator.new([ ORIGIN, X_AXIS ], input_plane_manipulator.transformation)
        end
      end

      z_axis = input_plane_manipulator.normal
      x_axis = input_line_manipulator.direction
      x_axis.reverse! if input_line_manipulator.respond_to?(:reversed_in?) && input_plane_manipulator.respond_to?(:face) && input_line_manipulator.reversed_in?(input_plane_manipulator.face)
      y_axis = (z_axis * x_axis).normalize

      [ x_axis, y_axis, z_axis, input_line_manipulator ]
    end

    def _populate_manipulators(drawing_container_def, entities, transformation = IDENTITY, face_validator = nil, edge_validator = nil)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            next if @ignore_faces
            manipulator = FaceManipulator.new(entity, transformation)
            if face_validator.nil? || face_validator.call(manipulator)
              unless @ignore_surfaces
                if manipulator.belongs_to_a_surface?
                  surface_manipulator = _get_surface_manipulator_by_face(drawing_container_def, entity, transformation)
                  if surface_manipulator.nil?
                    surface_manipulator = SurfaceManipulator.new(transformation).populate_from_face(entity)
                    drawing_container_def.add_manipulator(:surface_manipulators, surface_manipulator)
                  end
                  manipulator.surface_manipulator = surface_manipulator
                end
              end
              drawing_container_def.add_manipulator(:face_manipulators, manipulator)
            end
          elsif entity.is_a?(Sketchup::Edge)
            next if @ignore_edges || entity.soft? && @ignore_soft_edges
            manipulator = EdgeManipulator.new(entity, transformation)
            if edge_validator.nil? || edge_validator.call(manipulator)
              if entity.curve.nil? || entity.curve.edges.length < 2  # Exclude curves that contain only one edge.
                drawing_container_def.add_manipulator(:edge_manipulators, manipulator)
              else
                curve_manipulator = _get_curve_manipulator_by_edge(drawing_container_def, entity, transformation)
                if curve_manipulator.nil?
                  curve_manipulator = CurveManipulator.new(entity.curve, transformation)
                  drawing_container_def.add_manipulator(:curve_manipulators, curve_manipulator)
                end
              end
            end
          elsif entity.is_a?(Sketchup::ConstructionLine)
            next if @ignore_clines || entity.start.nil? # Exclude infinite Clines
            manipulator = ClineManipulator.new(entity, transformation)
            drawing_container_def.add_manipulator(:cline_manipulators, manipulator)
          elsif @recursive
            if entity.is_a?(Sketchup::Group)
              if @flatten
                child_drawing_container_def = drawing_container_def
              else
                child_drawing_container_def = drawing_container_def.add_container(entity, transformation)
              end
              _populate_manipulators(child_drawing_container_def, entity.entities, transformation * entity.transformation, face_validator, edge_validator)
            elsif entity.is_a?(Sketchup::ComponentInstance) && (!@for_part || entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
              if @flatten
                child_drawing_container_def = drawing_container_def
              else
                child_drawing_container_def = drawing_container_def.add_container(entity, transformation)
              end
              _populate_manipulators(child_drawing_container_def, entity.definition.entities, transformation * entity.transformation, face_validator, edge_validator)
            end
          end
        end
      end
    end

    def _get_surface_manipulator_by_face(drawing_container_def, face, transformation)
      drawing_container_def.surface_manipulators.each do |surface_manipulator|
        next unless surface_manipulator.transformation.equal?(transformation) # Check if same context
        return surface_manipulator if surface_manipulator.include?(face)
      end
      nil
    end

    def _get_curve_manipulator_by_edge(drawing_container_def, edge, transformation)
      drawing_container_def.curve_manipulators.each do |curve_manipulator|
        next unless curve_manipulator.transformation.equal?(transformation) # Check if same context
        return curve_manipulator if curve_manipulator.curve.equal?(edge.curve)
      end
      nil
    end

  end

end