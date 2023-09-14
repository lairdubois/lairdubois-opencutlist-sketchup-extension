module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/face_triangles_helper'
  require_relative '../../helper/entities_helper'
  require_relative '../../utils/path_utils'
  require_relative '../../utils/transformation_utils'
  require_relative '../../model/cutlist/drawing_def'
  require_relative '../../manipulator/face_manipulator'
  require_relative '../../manipulator/edge_manipulator'

  class CommonDecomposeDrawingWorker

    include FaceTrianglesHelper
    include EntitiesHelper

    FACE_VALIDATOR_NONE = 0
    FACE_VALIDATOR_SINGLE = 1
    FACE_VALIDATOR_COPLANAR = 2
    FACE_VALIDATOR_PARALLEL = 3

    EDGE_VALIDATOR_NONE = 0
    EDGE_VALIDATOR_STRAY_COPLANAR = 1

    def initialize(path, option = {})

      @path = path

      @input_face_path = option.fetch('input_face_path', nil)
      @input_edge_path = option.fetch('input_edge_path', nil)

      @use_bounds_min_as_origin = option.fetch('use_bounds_min_as_origin', false)

      @ignore_faces = option.fetch('ignore_faces', false)
      @face_validator = option.fetch('face_validator', FACE_VALIDATOR_NONE)

      @ignore_edges = option.fetch('ignore_edges', false)
      @edge_validator = option.fetch('edge_validator', EDGE_VALIDATOR_NONE)

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @path.is_a?(Array)
      return { :errors => [ 'default.error' ] } if @path.empty?

      # Extract drawing element
      drawing_element = @path.last

      return { :errors => [ 'default.error' ] } unless drawing_element.is_a?(Sketchup::Drawingelement)

      # Compute transformation to drawing element
      transformation = PathUtils::get_transformation(@path)

      # Extract first level of child entities
      if drawing_element.is_a?(Sketchup::Group)
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

          input_inner_transformation = PathUtils::get_transformation(@input_face_path - @path)
          input_inner_face_manipulator = FaceManipulator.new(input_face, input_inner_transformation)

          if input_inner_face_manipulator.normal.parallel?(Z_AXIS) || input_inner_face_manipulator.normal.parallel?(Y_AXIS)
            z_axis = drawing_def.input_face_manipulator.normal
            x_axis = X_AXIS.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis.cross(x_axis)
          elsif input_inner_face_manipulator.normal.parallel?(X_AXIS)
            z_axis = drawing_def.input_face_manipulator.normal
            x_axis = Y_AXIS.transform(transformation)
            x_axis.reverse! if TransformationUtils.flipped?(transformation)
            y_axis = z_axis.cross(x_axis)
          else
            x_axis, y_axis, z_axis, drawing_def.input_edge_manipulator = _get_input_axes(drawing_def.input_face_manipulator, nil)
          end

        end

      else

        # Get transformed X axis and reverse it if transformation is flipped to keep a right hand oriented system
        x_axis = X_AXIS.transform(transformation).normalize
        x_axis.reverse! if TransformationUtils.flipped?(transformation)

        # Use transformed Y axis to determine XY plane and compute Z as perpendicular to this plane
        y_axis = Y_AXIS.transform(transformation).normalize
        xy_plane = Geom.fit_plane_to_points(ORIGIN, Geom::Point3d.new(x_axis.to_a), Geom::Point3d.new(y_axis.to_a))
        z_axis = Geom::Vector3d.new(xy_plane[0..2])

        # Reset Y axis as cross product Z * X
        y_axis = z_axis * x_axis

      end

      ta = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
      tai = ta.inverse
      ttai = tai * transformation

      drawing_def.transformation = ta
      drawing_def.input_face_manipulator.transformation = tai * drawing_def.input_face_manipulator.transformation unless drawing_def.input_face_manipulator.nil?
      drawing_def.input_edge_manipulator.transformation = tai * drawing_def.input_edge_manipulator.transformation unless drawing_def.input_edge_manipulator.nil?

      # STEP 2 : Populate faces and edges

      # Faces
      unless @ignore_faces

        validator = nil
        if drawing_def.input_face_manipulator
          case @face_validator
          when FACE_VALIDATOR_SINGLE
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
          end
        end

        _populate_face_manipulators(drawing_def.face_manipulators, entities, ttai, &validator)

      end

      # Edges
      unless @ignore_edges

        validator = nil
        if drawing_def.input_face_manipulator
          case @edge_validator
          when EDGE_VALIDATOR_STRAY_COPLANAR
            validator = lambda { |edge_manipulator|
              if edge_manipulator.edge.faces.empty?
                point, vector = edge_manipulator.line
                vector.perpendicular?(drawing_def.input_face_manipulator.normal) && point.on_plane?(drawing_def.input_face_manipulator.plane)
              else
                false
              end
            }
          end
        end

        _populate_edge_manipulators(drawing_def.edge_manipulators, entities, ttai, &validator)

      end

      # STEP 3 : Compute bounds

      unless @ignore_faces
        drawing_def.face_manipulators.each do |face_manipulator|
          drawing_def.bounds.add(face_manipulator.outer_loop_points)
        end
      end
      unless @ignore_edges
        drawing_def.edge_manipulators.each do |edge_manipulator|
          drawing_def.bounds.add(edge_manipulator.points)
        end
      end

      # STEP 4 : Customize origin

      if @use_bounds_min_as_origin

        to = Geom::Transformation.translation(Geom::Vector3d.new(drawing_def.bounds.min.to_a))
        toi = to.inverse

        drawing_def.transformation *= to
        drawing_def.input_face_manipulator.transformation = toi * drawing_def.input_face_manipulator.transformation unless drawing_def.input_face_manipulator.nil?
        drawing_def.input_edge_manipulator.transformation = toi * drawing_def.input_edge_manipulator.transformation unless drawing_def.input_edge_manipulator.nil?

        min = drawing_def.bounds.min.transform(toi)
        max = drawing_def.bounds.max.transform(toi)
        drawing_def.bounds.clear
        drawing_def.bounds.add([ min, max ])

        unless @ignore_faces
          drawing_def.face_manipulators.each do |face_manipulator|
            face_manipulator.transformation = toi * face_manipulator.transformation
          end
        end
        unless @ignore_edges
          drawing_def.edge_manipulators.each do |edge_manipulator|
            edge_manipulator.transformation = toi * edge_manipulator.transformation
          end
        end

      end

      drawing_def
    end

    # -----

    private

    def  _get_input_axes(input_face_manipulator, input_edge_manipulator = nil)

      if input_edge_manipulator.nil? || !input_edge_manipulator.edge.used_by?(input_face_manipulator.face)
        input_edge_manipulator = EdgeManipulator.new(input_face_manipulator.longest_outer_edge, input_face_manipulator.transformation)
      end

      z_axis = input_face_manipulator.normal
      x_axis = input_edge_manipulator.line[1]
      x_axis.reverse! if input_edge_manipulator.reversed_in?(input_face_manipulator.face)
      y_axis = z_axis.cross(x_axis)

      [ x_axis, y_axis, z_axis, input_edge_manipulator ]
    end

    def _populate_face_manipulators(face_infos, entities, transformation = Geom::Transformation.new, &validator)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            manipulator = FaceManipulator.new(entity, transformation)
            face_infos.push(manipulator) if !block_given? || yield(manipulator)
          elsif entity.is_a?(Sketchup::Group)
            _populate_face_manipulators(face_infos, entity.entities, transformation * entity.transformation, &validator)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            _populate_face_manipulators(face_infos, entity.definition.entities, transformation * entity.transformation, &validator)
          end
        end
      end
    end

    def _populate_edge_manipulators(edge_infos, entities, transformation = Geom::Transformation.new, &validator)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Edge)
            manipulator = EdgeManipulator.new(entity, transformation)
            edge_infos.push(manipulator) if !block_given? || yield(manipulator)
          elsif entity.is_a?(Sketchup::Group)
            _populate_edge_manipulators(edge_infos, entity.entities, transformation * entity.transformation, &validator)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            _populate_edge_manipulators(edge_infos, entity.definition.entities, transformation * entity.transformation, &validator)
          end
        end
      end
    end

  end

end