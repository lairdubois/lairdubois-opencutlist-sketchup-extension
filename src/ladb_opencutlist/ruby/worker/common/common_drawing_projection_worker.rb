module Ladb::OpenCutList

  require_relative '../../lib/clippy/clippy'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/drawing/drawing_projection_def'

  class CommonDrawingProjectionWorker

    MINIMAL_PATH_AREA = 1e-6

    ORIGIN_POSITION_DEFAULT = 0
    ORIGIN_POSITION_FACES_BOUNDS_MIN = 1
    ORIGIN_POSITION_EDGES_BOUNDS_MIN = 2
    ORIGIN_POSITION_BOUNDS_MIN = 3

    def initialize(drawing_def, settings = {})

      @drawing_def = drawing_def

      @origin_position = settings.fetch('origin_position', ORIGIN_POSITION_DEFAULT)
      @merge_holes = settings.fetch('merge_holes', false)  # Holes are moved to "hole" layer and all down layers holes are merged to their upper layer

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @drawing_def.is_a?(DrawingDef)
      return { :errors => [ "Can't load Clippy" ] } unless Clippy.available?

      faces_bounds = Geom::BoundingBox.new
      edges_bounds = Geom::BoundingBox.new
      bounds = Geom::BoundingBox.new

      face_manipulators = []
      edge_manipulators = []
      curve_manipulators = []

      @drawing_def.face_manipulators.each do |face_manipulator|
        next unless !face_manipulator.perpendicular?(Z_AXIS) && face_manipulator.angle_between(@drawing_def.input_normal) < Math::PI / 2.0  # Filter only exposed faces
        face_manipulators << face_manipulator
        faces_bounds.add(face_manipulator.outer_loop_points)
      end
      @drawing_def.edge_manipulators.each do |edge_manipulator|
        next unless edge_manipulator.line_vector.perpendicular?(Z_AXIS)
        edge_manipulators << edge_manipulator
        edges_bounds.add(edge_manipulator.points)
      end
      @drawing_def.curve_manipulators.each do |curve_manipulator|
        next unless curve_manipulator.plane_vector.parallel?(Z_AXIS)
        curve_manipulators << curve_manipulator
        edges_bounds.add(curve_manipulator.points)
      end

      bounds.add(faces_bounds.min, faces_bounds.max) unless faces_bounds.empty?
      bounds.add(edges_bounds.min, edges_bounds.max) unless edges_bounds.empty?

      root_depth = 0.0
      max_depth = @drawing_def.faces_bounds.depth

      z_max = faces_bounds.empty? ? bounds.max.z : faces_bounds.max.z

      upper_layer_def = PathsLayerDef.new(root_depth, [], [], DrawingProjectionLayerDef::TYPE_UPPER)

      plds = {}   # plds = Path Layer DefS
      plds[root_depth] = upper_layer_def

      # Extract faces loops
      face_manipulators.each do |face_manipulator|

        if face_manipulator.surface_manipulator
          f_depth = (z_max - face_manipulator.surface_manipulator.z_max) # Faces sharing the same "surface" are considered as a unique "box"
        else
          f_depth = (z_max - face_manipulator.z_max)
        end
        if face_manipulator.has_cuts_opening?
          # Face has cuts opening components glued to. So we extract its paths from mesh triangulation instead of loops.
          f_paths = face_manipulator.triangles.each_slice(3).to_a.map { |points| Clippy.points_to_rpath(points) }
        else
          f_paths = face_manipulator.loop_manipulators.map { |loop_manipulator| loop_manipulator.points }.map { |points| Clippy.points_to_rpath(points) }
        end

        pld = plds[f_depth.round(3)]
        if pld.nil?
          pld = PathsLayerDef.new(f_depth, f_paths, [], DrawingProjectionLayerDef::TYPE_DEFAULT)
          plds[f_depth.round(3)] = pld
        else
          pld.closed_paths.concat(f_paths) # Just concat, union will be call later in one unique call
        end

      end

      # Extract edges and curves
      edge_manipulators.each do |edge_manipulator|

        e_depth = (z_max - edge_manipulator.z_max)
        e_path = Clippy.points_to_rpath(edge_manipulator.points)

        pld = plds[e_depth.round(3)]
        if pld.nil?
          pld = PathsLayerDef.new(e_depth, [], [ e_path ], DrawingProjectionLayerDef::TYPE_DEFAULT)
          plds[e_depth.round(3)] = pld
        else
          pld.open_paths.push(e_path)
        end

      end
      curve_manipulators.each do |curve_manipulator|

        c_depth = (z_max - curve_manipulator.z_max)
        c_path = Clippy.points_to_rpath(curve_manipulator.points)

        pld = plds[c_depth.round(3)]
        if pld.nil?
          pld = PathsLayerDef.new(c_depth, [], [ c_path ], DrawingProjectionLayerDef::TYPE_DEFAULT)
          plds[c_depth.round(3)] = pld
        else
          pld.open_paths.push(c_path)
        end

      end

      # Sort on depth ASC
      splds = plds.values.sort_by { |layer_def| layer_def.depth }

      # Union paths on each layer
      splds.each do |layer_def|
        next if layer_def.closed_paths.one?
        layer_def.closed_paths, op = Clippy.execute_union(layer_def.closed_paths)
      end

      # Up to Down difference
      splds.each_with_index do |layer_def, index|
        next if layer_def.closed_paths.empty?
        splds[(index + 1)..-1].each do |lower_layer_def|
          next if lower_layer_def.nil? || lower_layer_def.closed_paths.empty? && lower_layer_def.open_paths.empty?
          lower_layer_def.closed_paths, lower_layer_def.open_paths = Clippy.execute_difference(lower_layer_def.closed_paths, lower_layer_def.open_paths, layer_def.closed_paths)
        end
      end

      if @merge_holes

        # Copy upper paths
        upper_paths = upper_layer_def.closed_paths

        # Union upper paths with lower paths
        merged_paths, op = Clippy.execute_union(upper_paths + splds[1..-1].map { |layer_def| layer_def.closed_paths }.flatten(1).compact)
        merged_polytree = Clippy.execute_polytree(merged_paths)

        # Extract outer paths (first children of pathtree)
        outer_paths = merged_polytree.children.map { |polypath| polypath.path }

        # Extract holes paths and reverse them to plain paths
        through_paths = Clippy.reverse_rpaths(Clippy.delete_rpaths_in(merged_paths, outer_paths))

        # Append "holes" layer def
        splds << PathsLayerDef.new(max_depth, through_paths, [], DrawingProjectionLayerDef::TYPE_HOLES)

        # Difference with outer and upper to extract holes to propagate
        mask_paths, op = Clippy.execute_difference(outer_paths, [], upper_paths)
        mask_polytree = Clippy.execute_polytree(mask_paths)
        mask_polyshapes = Clippy.polytree_to_polyshapes(mask_polytree)

        # Propagate down to up
        pldsr = splds.reverse[0...-1] # Exclude top layer
        mask_polyshapes.each do |mask_polyshape|
          lower_paths = []
          pldsr.each do |layer_def|
            next if layer_def.closed_paths.empty?
            next if Clippy.execute_intersection(layer_def.closed_paths, [], mask_polyshape.paths).first.empty?
            layer_def.closed_paths, op = Clippy.execute_union(lower_paths + layer_def.closed_paths) unless lower_paths.empty?
            lower_paths, op = Clippy.execute_intersection(layer_def.closed_paths, [], mask_polyshape.paths)
          end
        end

        # Changed upper layer to "outer"
        upper_layer_def.type = DrawingProjectionLayerDef::TYPE_OUTER
        upper_layer_def.closed_paths = outer_paths

      end

      # Output

      projection_def = DrawingProjectionDef.new(max_depth)

      splds.each do |layer_def|

        unless layer_def.open_paths.empty?

          polygons = []
          polylines = []
          layer_def.open_paths.each do |path|
            points = Clippy.rpath_to_points(path, z_max - layer_def.depth)
            if points.first == points.last
              points.reverse! unless Clippy.is_rpath_positive?(path)  # Force CCW
              polygons << DrawingProjectionPolygonDef.new(points[0...-1], true) # Closed paths are converted to polygon by removing the 'end point'
            else
              polylines << DrawingProjectionPolylineDef.new(points)
            end
          end
          # TODO : Reconnect closed input paths ?
          projection_def.layer_defs << DrawingProjectionLayerDef.new(layer_def.depth, DrawingProjectionLayerDef::TYPE_PATH, '', polygons + polylines)

        end

        unless layer_def.closed_paths.empty?

          polygons = layer_def.closed_paths.map { |path|
            next if Clippy.get_rpath_area(path).abs < MINIMAL_PATH_AREA # Ignore "artifact" paths generated by successive transformation / union / differences
            DrawingProjectionPolygonDef.new(Clippy.rpath_to_points(path, z_max - layer_def.depth), Clippy.is_rpath_positive?(path))
          }.compact
          projection_def.layer_defs << DrawingProjectionLayerDef.new(layer_def.depth, layer_def.type, '', polygons) unless polygons.empty?

        end

      end

      case @origin_position
      when ORIGIN_POSITION_FACES_BOUNDS_MIN
        origin = Geom::Point3d.new(faces_bounds.min.x, faces_bounds.min.y, faces_bounds.max.z)
      when ORIGIN_POSITION_EDGES_BOUNDS_MIN
        origin = Geom::Point3d.new(edges_bounds.min.x, edges_bounds.min.y, edges_bounds.max.z)
      when ORIGIN_POSITION_BOUNDS_MIN
        origin = Geom::Point3d.new(bounds.min.x, bounds.min.y, faces_bounds.max.z)
      else
        origin = Geom::Point3d.new(0, 0, faces_bounds.max.z)
      end

      projection_def.bounds.clear
      projection_def.bounds.add(
        Geom::Point3d.new(bounds.min.x, bounds.min.y, origin.z),
        Geom::Point3d.new(bounds.max.x, bounds.max.y, origin.z),
        origin
      )

      projection_def.translate_to!(origin)

      projection_def
    end

    # -----

    PathsLayerDef = Struct.new(:depth, :closed_paths, :open_paths, :type)

  end

end