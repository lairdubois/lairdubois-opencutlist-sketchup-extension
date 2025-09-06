module Ladb::OpenCutList

  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../lib/kuix/kuix'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/drawing/drawing_projection_def'
  require_relative '../../helper/layer0_caching_helper'

  class CommonDrawingProjectionWorker

    include Layer0CachingHelper

    MINIMAL_PATH_AREA = 1e-6

    ORIGIN_POSITION_DEFAULT = 0
    ORIGIN_POSITION_FACES_BOUNDS_MIN = 1
    ORIGIN_POSITION_EDGES_BOUNDS_MIN = 2
    ORIGIN_POSITION_BOUNDS_MIN = 3

    Clippy = Fiddle::Clippy

    def initialize(drawing_def,

                   origin_position: ORIGIN_POSITION_DEFAULT,
                   merge_holes: false,
                   merge_holes_overflow: 0,
                   compute_shell: false,
                   include_borders_layers: false,

                   mask: nil

    )

      @drawing_def = drawing_def

      @origin_position = origin_position
      @merge_holes = merge_holes                    # Holes are moved to the "hole" layer, and all down layers holes are merged to their upper layer
      @merge_holes_overflow = (@merge_holes ? merge_holes_overflow : 0).to_l
      @compute_shell = compute_shell                # In addition to layers, shell def (outer + holes shapes) is computed.
      @include_borders_layers = include_borders_layers

      @mask = mask

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
        next unless !face_manipulator.normal.perpendicular?(Z_AXIS) && face_manipulator.normal.angle_between(Z_AXIS) < Math::PI / 2.0  # Filter only exposed faces
        face_manipulators << face_manipulator
        faces_bounds.add(face_manipulator.outer_loop_manipulator.points)
      end
      @drawing_def.edge_manipulators.each do |edge_manipulator|
        next unless edge_manipulator.direction.perpendicular?(Z_AXIS)
        edge_manipulators << edge_manipulator
        edges_bounds.add(edge_manipulator.points)
      end
      @drawing_def.curve_manipulators.each do |curve_manipulator|
        next unless curve_manipulator.normal.parallel?(Z_AXIS)
        curve_manipulators << curve_manipulator
        edges_bounds.add(curve_manipulator.points)
      end

      bounds.add(faces_bounds) unless faces_bounds.empty?
      bounds.add(edges_bounds) unless edges_bounds.empty?

      root_depth = 0.0
      max_depth = @drawing_def.faces_bounds.depth

      z_max = faces_bounds.empty? ? bounds.max.z : faces_bounds.max.z

      upper_layer_def = PathsLayerDef.new(root_depth, [], [], [], [], DrawingProjectionLayerDef::TYPE_UPPER)

      plds = {}   # plds = Path Layer DefS
      plds[root_depth.to_s] = upper_layer_def

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

        pld = plds[(key = f_depth.round(3).to_s)]
        if pld.nil?
          plds[key] = PathsLayerDef.new(f_depth, f_paths, [], [], [], DrawingProjectionLayerDef::TYPE_DEFAULT)
        else
          pld.closed_paths.concat(f_paths) # Just concat, union will be call later in one unique call
        end

      end

      # Extract edges and curves
      edge_manipulators.each do |edge_manipulator|

        e_depth = (z_max - edge_manipulator.z_max)
        e_path = Clippy.points_to_rpath(edge_manipulator.points)
        e_su_layer = edge_manipulator.edge.layer == cached_layer0 ? nil : edge_manipulator.edge.layer

        key = [ e_depth.round(3), e_su_layer ].compact.join('_')
        pld = plds[key]
        if pld.nil?
          plds[key] = PathsLayerDef.new(e_depth, [], [ e_path ], [], [], DrawingProjectionLayerDef::TYPE_DEFAULT, e_su_layer)
        else
          pld.open_paths.push(e_path)
        end

      end
      curve_manipulators.each do |curve_manipulator|

        c_depth = (z_max - curve_manipulator.z_max)
        c_path = Clippy.points_to_rpath(curve_manipulator.points)
        c_su_layer = curve_manipulator.curve.first_edge.layer == cached_layer0 ? nil : curve_manipulator.curve.first_edge.layer

        key = [ c_depth.round(3), c_su_layer ].compact.join('_')
        pld = plds[key]
        if pld.nil?
          plds[key] = PathsLayerDef.new(c_depth, [], [ c_path ], [], [], DrawingProjectionLayerDef::TYPE_DEFAULT, c_su_layer)
        else
          pld.open_paths.push(c_path)
        end

      end

      # Sort on depth ASC
      splds = plds.values.sort_by { |layer_def| [ layer_def.depth.round(3), layer_def.su_layer.nil? ? 1 : 0 ] }

      # Union paths on each layer
      splds.each do |layer_def|
        next if layer_def.closed_paths.one?
        layer_def.closed_paths, op = Clippy.execute_union(closed_subjects: layer_def.closed_paths)
      end

      # Intersect with the mask if it exists
      unless @mask.nil?

        mask_paths = [ Clippy.points_to_rpath(@mask) ]
        splds.each do |layer_def|
          layer_def.closed_paths, op = Clippy.execute_intersection(closed_subjects: layer_def.closed_paths, clips: mask_paths)
        end

        mask_bounds = Geom::BoundingBox.new.add(@mask).add(Geom::Point3d.new(@mask.first.x, @mask.first.y, z_max))
        faces_bounds = faces_bounds.intersect(mask_bounds) unless faces_bounds.empty?
        edges_bounds = edges_bounds.intersect(mask_bounds) unless edges_bounds.empty?

        bounds = Geom::BoundingBox.new
        bounds.add(faces_bounds)
        bounds.add(edges_bounds)

      end

      # Up to Down difference
      splds.each_with_index do |layer_def, index|
        next if layer_def.closed_paths.empty?
        splds[(index + 1)..-1].each do |lower_layer_def|
          next if lower_layer_def.nil? || lower_layer_def.closed_paths.empty? && lower_layer_def.open_paths.empty?
          lower_layer_def.closed_paths, lower_layer_def.open_paths = Clippy.execute_difference(closed_subjects: lower_layer_def.closed_paths, open_subjects: lower_layer_def.open_paths, clips: layer_def.closed_paths)
          lower_layer_def.closed_paths.delete_if { |path| Clippy.get_rpath_area(path).abs < MINIMAL_PATH_AREA } # Ignore "artifact" paths generated by successive transformation / union / differences
        end
      end

      if @merge_holes || @compute_shell

        # Copy upper paths
        upper_paths = upper_layer_def.closed_paths

        # Union upper paths with lower paths
        merged_paths, op = Clippy.execute_union(closed_subjects: upper_paths + splds[1..-1].flat_map { |layer_def| layer_def.closed_paths }.compact)
        merged_paths.delete_if { |path| Clippy.get_rpath_area(path).abs < MINIMAL_PATH_AREA } # Ignore "artifact" paths generated by successive transformation / union / differences
        merged_polytree = Clippy.execute_polytree(closed_subjects: merged_paths)

      end

      if @merge_holes

        # Extract outer paths (first children of polytree)
        outer_paths = merged_polytree.children.map { |polypath| polypath.path }

        # Extract holes paths and reverse them to plain paths
        through_paths = Clippy.reverse_rpaths(Clippy.delete_rpaths_in(merged_paths, outer_paths))

        # Append "holes" layer def
        splds << PathsLayerDef.new(max_depth, through_paths, [], [], [], DrawingProjectionLayerDef::TYPE_HOLES)

        # Difference with outer and upper to extract holes to propagate
        mask_paths, op = Clippy.execute_difference(closed_subjects: outer_paths, clips: upper_paths)
        mask_polytree = Clippy.execute_polytree(closed_subjects: mask_paths)
        mask_polyshapes = Clippy.polytree_to_polyshapes(mask_polytree)

        # Propagate down to up
        pldsr = splds.reverse[0...-1] # Exclude top layer
        mask_polyshapes.each do |mask_polyshape|
          lower_paths = []
          merged_lower_paths = []
          pldsr.each do |layer_def|
            next if layer_def.closed_paths.empty?
            next if (intersection = Clippy.execute_intersection(closed_subjects: layer_def.closed_paths, clips: mask_polyshape.paths)).first.empty?
            if @merge_holes_overflow > 0

              layer_border_inflate_paths = []

              layer_def.closed_paths.each do |path|

                border_defs = []

                fn_compute_point_in_defs = lambda { |x, y|
                  merged_lower_paths.map { |lower_path| PathVertexInDef.new(Clippy.is_point_on_polygon(x, y, lower_path), lower_path) } +
                  outer_paths.map { |outer_path| PathVertexInDef.new(Clippy.is_point_on_polygon(x, y, outer_path), outer_path) }
                }
                fn_mid_point_on_borders = lambda { |x1, y1, x2, y2|
                  return true if merged_lower_paths.index { |lower_path| Clippy.is_mid_point_on_polygon(x1, y1, x2, y2, lower_path) }
                  return true if outer_paths.index { |outer_path| Clippy.is_mid_point_on_polygon(x1, y1, x2, y2, outer_path) }
                  false
                }

                fn_extract_border = lambda { |segment_defs|
                  return [] if segment_defs.length < 3

                  start_gate_index = segment_defs.index { |segment_def| segment_def.is_start_gate }
                  if start_gate_index.nil?

                    border_defs << PathBorderDef.new(segment_defs, true)

                    return []
                  else
                    segment_defs.rotate!(start_gate_index)
                    end_gate_index = segment_defs.index { |segment_def| segment_def.is_end_gate }
                    if end_gate_index.nil?
                      return [] # Invalid border, no end gate
                    else

                      border_defs << PathBorderDef.new(segment_defs[0..end_gate_index], false) if end_gate_index > 1

                      return segment_defs[(end_gate_index + 1)..-1]
                    end
                  end

                }

                vertex_defs = path.each_slice(2).to_a.map { |x, y| PathVertexDef.new(x, y, fn_compute_point_in_defs.call(x, y)) }
                segment_defs = (vertex_defs + [ vertex_defs.first ]).each_cons(2).to_a.map { |start_vertex_def, end_vertex_def|
                  if start_vertex_def.is_on? && end_vertex_def.is_on?

                    if fn_mid_point_on_borders.call(start_vertex_def.x, start_vertex_def.y, end_vertex_def.x, end_vertex_def.y)
                      PathSegmentDef.new(start_vertex_def, end_vertex_def, false, false, true)
                    else
                      [
                        PathSegmentDef.new(start_vertex_def, end_vertex_def, false, true, false),
                        PathSegmentDef.new(start_vertex_def, end_vertex_def, true, false, false)
                      ]
                    end

                  elsif start_vertex_def.is_on? || end_vertex_def.is_on?
                    PathSegmentDef.new(start_vertex_def, end_vertex_def, end_vertex_def.is_on?, start_vertex_def.is_on?, false)
                  end
                }.compact.flatten(1)

                until segment_defs.empty?
                  segment_defs = fn_extract_border.call(segment_defs)
                end

                border_defs.each { |border_def|

                  border_path = border_def.path

                  if border_def.is_loop
                    layer_def.border_closed_paths << border_path
                  else
                    layer_def.border_open_paths << border_path
                  end

                  border_inflate_paths = Clippy.inflate_paths(
                    paths: [ border_path ],
                    delta: @merge_holes_overflow,
                    join_type: Clippy::JOIN_TYPE_MITER,
                    end_type: border_def.is_loop ? Clippy::END_TYPE_JOINED : Clippy::END_TYPE_BUTT
                  )
                  border_inflate_paths_inner, op = Clippy.execute_intersection(closed_subjects: border_inflate_paths, clips: merged_lower_paths)
                  border_inflate_paths_outer, op = Clippy.execute_difference(closed_subjects: border_inflate_paths, clips: outer_paths)
                  border_inflate_paths, op = Clippy.execute_union(closed_subjects: border_inflate_paths_inner, clips: border_inflate_paths_outer)

                  layer_border_inflate_paths, op = Clippy.execute_union(closed_subjects: layer_border_inflate_paths, clips: border_inflate_paths)

                }

              end

              merged_lower_paths, op = Clippy.execute_union(closed_subjects: merged_lower_paths, clips: layer_def.closed_paths)
              merged_lower_paths, op = Clippy.execute_intersection(closed_subjects: merged_lower_paths, clips: mask_polyshape.paths)

              layer_def.closed_paths, op = Clippy.execute_union(closed_subjects: layer_def.closed_paths, clips: layer_border_inflate_paths)
              # layer_def.closed_paths = layer_border_inflate_paths

            else
              if lower_paths.any?
                layer_def.closed_paths, op = Clippy.execute_union(closed_subjects: lower_paths, clips: layer_def.closed_paths)
                lower_paths, op = Clippy.execute_intersection(closed_subjects: layer_def.closed_paths, clips: mask_polyshape.paths)
              else
                lower_paths = intersection.first
              end
            end
          end
        end

        # Remove or clear closed path in upper layer
        if upper_layer_def.open_paths.any?
          upper_layer_def.closed_paths = []
        else
          splds.delete(upper_layer_def)
        end

        # Insert "outer" layer (after upper_layer)
        splds.insert(1, PathsLayerDef.new(max_depth, outer_paths, [], [], [], DrawingProjectionLayerDef::TYPE_OUTER))

      end

      # Output

      projection_def = DrawingProjectionDef.new(@drawing_def, max_depth)

      # -- Layers

      splds.each do |pld|

        unless pld.open_paths.empty?

          polygons = []
          polylines = []
          pld.open_paths.each do |path|
            points = Clippy.rpath_to_points(path, z_max - pld.depth)
            if points.first == points.last
              points.reverse! unless Clippy.is_rpath_positive?(path)  # Force CCW
              polygons << DrawingProjectionPolygonDef.new(points[0...-1], true) # Closed paths are converted to polygon by removing the 'end point'
            else
              polylines << DrawingProjectionPolylineDef.new(points)
            end
          end
          name = pld.su_layer.nil? ? nil : pld.su_layer.name
          color = pld.su_layer.nil? ? nil : pld.su_layer.color
          # TODO : Reconnect closed input paths ?
          projection_def.layer_defs << DrawingProjectionLayerDef.new(pld.depth, DrawingProjectionLayerDef::TYPE_OPEN_PATHS, polylines, name, color) unless polylines.empty?
          projection_def.layer_defs << DrawingProjectionLayerDef.new(pld.depth, DrawingProjectionLayerDef::TYPE_CLOSED_PATHS, polygons, name, color) unless polygons.empty?

        end

        unless pld.closed_paths.empty?

          polygons = pld.closed_paths.map { |path|
            next if Clippy.get_rpath_area(path).abs < MINIMAL_PATH_AREA # Ignore "artifact" paths generated by successive transformation / union / differences
            DrawingProjectionPolygonDef.new(Clippy.rpath_to_points(path, z_max - (pld.type == DrawingProjectionLayerDef::TYPE_OUTER ? 0 : pld.depth)), Clippy.is_rpath_positive?(path))
          }.compact
          projection_def.layer_defs << DrawingProjectionLayerDef.new(pld.depth, pld.type, polygons) unless polygons.empty?

        end

        if @include_borders_layers

          unless pld.border_closed_paths.empty?

            polygons = pld.border_closed_paths.map { |path|
              points = Clippy.rpath_to_points(path, z_max - pld.depth)
              points.reverse! unless Clippy.is_rpath_positive?(path)  # Force CCW
              DrawingProjectionPolygonDef.new(points, true)
            }
            projection_def.layer_defs << DrawingProjectionLayerDef.new(pld.depth, DrawingProjectionLayerDef::TYPE_BORDERS, polygons) unless polygons.empty?

          end

          unless pld.border_open_paths.empty?

            polylines = pld.border_open_paths.map { |path|
              points = Clippy.rpath_to_points(path, z_max - pld.depth)
              DrawingProjectionPolylineDef.new(points)
            }
            projection_def.layer_defs << DrawingProjectionLayerDef.new(pld.depth, DrawingProjectionLayerDef::TYPE_BORDERS, polylines) unless polylines.empty?

          end
          
        end

      end

      # -- Shell

      if @compute_shell

        projection_def.shell_def = DrawingProjectionShellDef.new

        merged_polyshapes = Clippy.polytree_to_polyshapes(merged_polytree)
        merged_polyshapes.each do |polyshape|

          shape_def = DrawingProjectionShapeDef.new

          polyshape.paths.each_with_index do |path, index|
            points = Clippy.rpath_to_points(path)
            if index == 0 # index = 0 is outer
              shape_def.outer_poly_def = DrawingProjectionPolygonDef.new(points, true)
            else
              shape_def.holes_poly_defs << DrawingProjectionPolygonDef.new(points.reverse, true)
            end
          end

          projection_def.shell_def.shape_defs << shape_def

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

      # Convert 3D bounds to Kuix 2D bounds to inflate it if an overflow is defined
      bounds_2d = Kuix::Bounds2d.new.copy!(bounds)
      bounds_2d.inflate_all!(@merge_holes_overflow) if @merge_holes_overflow > 0

      projection_def.bounds.clear
      projection_def.bounds.add(
        Geom::Point3d.new(bounds_2d.min.x, bounds_2d.min.y, origin.z),
        Geom::Point3d.new(bounds_2d.max.x, bounds_2d.max.y, origin.z),
        origin
      )

      projection_def.translate_to!(origin)

      projection_def
    end

    # -----

    PathsLayerDef = Struct.new(:depth, :closed_paths, :open_paths, :border_closed_paths, :border_open_paths, :type, :su_layer)
    PathBorderDef = Struct.new(:segment_defs, :is_loop) do
      def path
        segment_defs.map { |segment_def|
          next unless segment_def.is_start_gate || segment_def.is_border
          [ segment_def.end_vertex_def.x, segment_def.end_vertex_def.y ]
        }.compact.flatten(1)
      end
    end
    PathSegmentDef = Struct.new(:start_vertex_def, :end_vertex_def, :is_start_gate, :is_end_gate, :is_border)
    PathVertexDef = Struct.new(:x, :y, :in_defs) do
      def is_on?
        in_defs.select { |in_def| in_def.is_on }.any?
      end
    end
    PathVertexInDef = Struct.new(:is_on, :path)

  end

end