module Ladb::OpenCutList

  require_relative '../../constants'
  require_relative '../../helper/face_triangles_helper'
  require_relative '../../helper/entities_helper'
  require_relative '../../utils/path_utils'
  require_relative '../../utils/transformation_utils'
  require_relative '../../model/cutlist/drawing_def'

  class CommonDecomposeDrawingWorker

    include FaceTrianglesHelper
    include EntitiesHelper

    def initialize(path, option = {})

      @path = path

      @input_face_path = option.fetch('input_face_path', nil)
      @input_edge_path = option.fetch('input_edge_path', nil)

      @use_min_bounds_origin = option.fetch('use_min_bounds_origin', false)

      @ignore_faces = option.fetch('ignore_faces', false)
      @face_validator = option.fetch('face_validator', nil)

      @ignore_edges = option.fetch('ignore_edges', false)
      @edge_validator = option.fetch('edge_validator', nil)

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

      # Populate face infos
      _popultate_face_infos(drawing_def.face_infos, entities, transformation, &@face_validator) unless @ignore_faces

      # Populate edge infos
      _populate_edge_infos(drawing_def.edge_infos, entities, transformation, &@edge_validator) unless @ignore_edges

      origin = ORIGIN.transform(transformation)
      if @input_face_path

        input_face = @input_face_path.last
        input_edge = @input_edge_path.nil? ? nil : @input_edge_path.last
        input_transformation = PathUtils::get_transformation(@input_face_path)

        x_axis, y_axis, z_axis, active_edge, auto = _get_input_axes(input_face, input_edge, input_transformation)
        if auto

          input_normal = input_face.normal.transform(input_transformation)
          input_inner_transformation = PathUtils::get_transformation(@input_face_path - @path)
          input_inner_normal = input_face.normal.transform(input_inner_transformation)

          if input_inner_normal.parallel?(Z_AXIS)
            z_axis = input_normal
            x_axis = (z_axis.cross(X_AXIS).y < 0 ? X_AXIS.reverse : X_AXIS).transform(transformation)
            y_axis = z_axis.cross(x_axis)
            active_edge = nil
          elsif input_inner_normal.parallel?(X_AXIS)
            z_axis = input_normal
            x_axis = (z_axis.cross(Y_AXIS).y > 0 ? Y_AXIS.reverse : Y_AXIS).transform(transformation)
            y_axis = z_axis.cross(x_axis)
            active_edge = nil
          elsif input_inner_normal.parallel?(Y_AXIS)
            z_axis = input_normal
            x_axis = (z_axis.cross(X_AXIS).y > 0 ? X_AXIS.reverse : X_AXIS).transform(transformation)
            y_axis = z_axis.cross(x_axis)
            active_edge = nil
          end

        end

        drawing_def.active_face_info = FaceInfo.new(input_face, input_transformation) unless input_face.nil?
        drawing_def.active_edge_info = EdgeInfo.new(active_edge, input_transformation) unless active_edge.nil?

      else
        x_axis = X_AXIS.transform(transformation)
        y_axis = Y_AXIS.transform(transformation)
        z_axis = Z_AXIS.transform(transformation)
      end

      ta = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
      ta = ta * Geom::Transformation.scaling(-1, 1, 1) if TransformationUtils.flipped?(transformation)
      tai = ta.inverse

      # Compute bounds
      unless @ignore_faces
        drawing_def.face_infos.each do |face_info|
          drawing_def.bounds.add(face_info.face.outer_loop.vertices.map { |vertex| vertex.position.transform(tai * face_info.transformation) })
        end
      end
      unless @ignore_edges
        drawing_def.edge_infos.each do |edge_info|
          drawing_def.bounds.add(edge_info.edge.vertices.map { |vertex| vertex.position.transform(tai * edge_info.transformation) })
        end
      end

      if @use_min_bounds_origin
        to = Geom::Transformation.translation(Geom::Vector3d.new(drawing_def.bounds.min.to_a))
      else
        to = Geom::Transformation.new
      end
      toi = to.inverse
      tato = ta * to
      tatoi = tato.inverse

      min = drawing_def.bounds.min.transform(toi)
      max = drawing_def.bounds.max.transform(toi)
      drawing_def.bounds.clear
      drawing_def.bounds.add([ ORIGIN, min, max ])

      unless @ignore_faces
        drawing_def.face_infos.each do |face_info|
          face_info.transformation = tatoi * face_info.transformation
        end
      end
      unless @ignore_edges
        drawing_def.edge_infos.each do |edge_info|
          edge_info.transformation = tatoi * edge_info.transformation
        end
      end

      drawing_def.transformation = tato
      drawing_def.x_axis = x_axis
      drawing_def.y_axis = y_axis
      drawing_def.z_axis = z_axis
      drawing_def.active_face_info.transformation = tatoi * drawing_def.active_face_info.transformation unless drawing_def.active_face_info.nil?
      drawing_def.active_edge_info.transformation = tatoi * drawing_def.active_edge_info.transformation unless drawing_def.active_edge_info.nil?

      drawing_def
    end

    # -----

    private

    def  _get_input_axes(input_face, input_edge, input_transformation = nil)

      active_edge = input_edge
      if active_edge.nil? || !active_edge.used_by?(input_face)
        active_edge = _find_longest_outer_edge(input_face, input_transformation)
      end

      z_axis = input_face.normal
      z_axis = z_axis.transform(input_transformation).normalize unless input_transformation.nil?
      x_axis = active_edge.line[1]
      x_axis = x_axis.transform(input_transformation).normalize unless input_transformation.nil?
      x_axis.reverse! if active_edge.reversed_in?(input_face)
      y_axis = z_axis.cross(x_axis)

      [ x_axis, y_axis, z_axis, active_edge, active_edge != input_edge ]
    end

    def _popultate_face_infos(face_infos, entities, transformation = Geom::Transformation.new, &validator)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Face)
            face_infos.push(FaceInfo.new(entity, transformation)) if !block_given? || yield(entity, transformation)
          elsif entity.is_a?(Sketchup::Group)
            _popultate_face_infos(face_infos, entity.entities, transformation * entity.transformation, &validator)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            _popultate_face_infos(face_infos, entity.definition.entities, transformation * entity.transformation, &validator)
          end
        end
      end
    end

    def _populate_edge_infos(edge_infos, entities, transformation = Geom::Transformation.new, &validator)
      entities.each do |entity|
        if entity.visible? && _layer_visible?(entity.layer)
          if entity.is_a?(Sketchup::Edge)
            edge_infos.push(EdgeInfo.new(entity, transformation)) if !block_given? || yield(entity, transformation)
          elsif entity.is_a?(Sketchup::Group)
            _populate_edge_infos(edge_infos, entity.entities, transformation * entity.transformation, &validator)
          elsif entity.is_a?(Sketchup::ComponentInstance) && (entity.definition.behavior.cuts_opening? || entity.definition.behavior.always_face_camera?)
            _populate_edge_infos(edge_infos, entity.definition.entities, transformation * entity.transformation, &validator)
          end
        end
      end
    end

  end

end