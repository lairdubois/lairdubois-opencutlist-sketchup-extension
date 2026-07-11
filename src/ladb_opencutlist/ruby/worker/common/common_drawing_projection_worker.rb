module Ladb::OpenCutList

  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../lib/geometrix/geometrix'
  require_relative '../../lib/kuix/kuix'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/drawing/drawing_projection_def'
  require_relative '../../helper/layer0_caching_helper'
  require_relative '../../helper/material_attributes_caching_helper'

  class CommonDrawingProjectionWorker

    include Layer0CachingHelper
    include MaterialAttributesCachingHelper

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

      face_manipulator_defs = []
      edge_manipulators = []
      curve_manipulators = []

      part_z_min = nil  # Bottom of the part itself : machining faces are excluded (a machining protruding below the part must not inflate the depth)

      @drawing_def.face_manipulators.each do |face_manipulator|
        angle = (face_manipulator.normal.angle_between(Z_AXIS) - Geometrix::HALF_PI).round(4)
        material_attribute = _get_material_attributes(face_manipulator.material)
        if material_attribute.type == MaterialAttributes::TYPE_MACHINING
          if angle > 0
            face_manipulator_defs << FaceManipulatorDef.new(face_manipulator, FACE_TYPE_SOLID, true)
          elsif angle < 0
            face_manipulator_defs << FaceManipulatorDef.new(face_manipulator, FACE_TYPE_CUTTING, true)
          end
        else
          f_z_min = face_manipulator.bounds.min.z
          part_z_min = f_z_min if part_z_min.nil? || f_z_min < part_z_min
          if angle > 0
            # Down-facing part faces mark where the part matter ends : machining floors pose nothing below them
            face_manipulator_defs << FaceManipulatorDef.new(face_manipulator, FACE_TYPE_BOTTOM, false)
          elsif angle < 0  # Filter only exposed --> Do not use Sketchup perpendicular? function because it may be too lazy
            face_manipulator_defs << FaceManipulatorDef.new(face_manipulator, FACE_TYPE_SOLID, false)
            faces_bounds.add(face_manipulator.outer_loop_manipulator.points)
          end
        end
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

      z_max = faces_bounds.empty? ? bounds.max.z : faces_bounds.max.z

      root_depth = 0.0
      max_depth = part_z_min.nil? ? @drawing_def.faces_bounds.depth : z_max - part_z_min

      upper_layer_def = PathsLayerDef.new(root_depth, DrawingProjectionLayerDef::TYPE_UPPER)

      plds = {}   # plds = Path Layer DefS
      plds[root_depth.to_s] = upper_layer_def

      # Extract faces loops
      face_manipulator_defs.each do |face_manipulator_def|

        face_manipulator = face_manipulator_def.face_manipulator

        if face_manipulator.surface_manipulator
          f_depth = (z_max - face_manipulator.surface_manipulator.bounds.max.z) # Faces sharing the same "surface" are considered as a unique "box"
        else
          f_depth = (z_max - face_manipulator.bounds.max.z)
        end
        if face_manipulator_def.machining?
          if face_manipulator_def.face_type == FACE_TYPE_SOLID
            next if f_depth.round(3) >= max_depth.round(3)  # Floor at or below the part bottom : through machining, no floor layer
            next if f_depth.round(3) <= 0                   # Floor at or above the part top : the volume doesn't dig into the part
          else
            next if f_depth.round(3) >= max_depth.round(3)  # Top at or below the part bottom : the volume doesn't dig into the part
            f_depth = 0.0 if f_depth < 0                    # Top above the part top : the machining enters the part through its upper face
          end
        elsif face_manipulator_def.face_type == FACE_TYPE_BOTTOM
          next if f_depth.round(3) >= max_depth.round(3)    # Part bottom faces : no matter below the part anyway
        end
        # Machining floors and part bottoms are down-facing : their projected
        # loops wind negatively, reverse them so every extracted path is
        # positively oriented (up-facing loops already are) — paths from
        # several faces are combined in single boolean calls below, mixed
        # windings would cancel each other where they overlap.
        f_reverse = face_manipulator_def.face_type == FACE_TYPE_BOTTOM || face_manipulator_def.machining? && face_manipulator_def.face_type == FACE_TYPE_SOLID
        if face_manipulator.has_cuts_opening?
          # Face has cuts opening components glued to. So we extract its paths from mesh triangulation instead of loops.
          f_paths = face_manipulator.triangles.each_slice(3)
                                    .to_a
                                    .map! { |points| Clippy.points_to_rpath(f_reverse ? points.reverse : points) }
        else
          f_paths = face_manipulator.loop_manipulators
                                    .map(&:points)
                                    .map! { |points| Clippy.points_to_rpath(f_reverse ? points.reverse : points) }
        end

        key = f_depth.round(3).to_s
        pld = plds[key] ||= PathsLayerDef.new(f_depth, DrawingProjectionLayerDef::TYPE_DEFAULT)
        if face_manipulator_def.face_type == FACE_TYPE_SOLID
          if face_manipulator_def.machining?
            pld.machining_closed_paths.concat(f_paths) # Machining floors are kept aside : they also cut every layer above their depth
          else
            pld.closed_paths.concat(f_paths) # Just concat, union will be call later in one unique call
          end
        elsif face_manipulator_def.face_type == FACE_TYPE_CUTTING
          pld.cutting_closed_paths.concat(f_paths)
        elsif face_manipulator_def.face_type == FACE_TYPE_BOTTOM
          pld.bottom_closed_paths.concat(f_paths)
        end

      end

      # Extract edges and curves
      edge_manipulators.each do |edge_manipulator|

        e_depth = (z_max - edge_manipulator.bounds.max.z)
        e_path = Clippy.points_to_rpath(edge_manipulator.points)
        e_su_layer = edge_manipulator.layer == cached_layer0 ? nil : edge_manipulator.layer

        key = [ e_depth.round(3), e_su_layer ].compact.join('_')
        pld = plds[key] ||= PathsLayerDef.new(e_depth, DrawingProjectionLayerDef::TYPE_DEFAULT, su_layer: e_su_layer)
        pld.open_paths.push(e_path)

      end
      curve_manipulators.each do |curve_manipulator|

        c_depth = (z_max - curve_manipulator.bounds.max.z)
        c_path = Clippy.points_to_rpath(curve_manipulator.points)
        c_su_layer = curve_manipulator.layer == cached_layer0 ? nil : curve_manipulator.layer

        key = [ c_depth.round(3), c_su_layer ].compact.join('_')
        pld = plds[key] ||= PathsLayerDef.new(c_depth, DrawingProjectionLayerDef::TYPE_DEFAULT, su_layer: c_su_layer)
        pld.open_paths.push(c_path)

      end

      # Sort on depth ASC
      splds = plds.values.sort_by { |layer_def| [ layer_def.depth.round(3), layer_def.su_layer.nil? ? 1 : 0 ] }

      # Union paths + Diff with cutting and machining paths on each layer.
      # A machining volume removes the matter between its top face and its
      # floor, but only where it is open to the sky : a machining buried under
      # upper matter (suspended inside the part) is inert. Layers are swept top
      # to bottom :
      # - a machining top "opens" the machining on the region not covered by
      #   the matter of the layers above, and cuts its own layer on that
      #   opening,
      # - a machining floor is served by the DEEPEST machining top above it
      #   covering it (its own volume top for closed volumes) : where that top
      #   is open, the floor cuts every upper layer and poses its solid on its
      #   own layer ; elsewhere it is inert. The posed solid is further
      #   restricted to where the part actually has matter at that depth
      #   (matter_paths) : a machining traversing a local thickness (e.g. the
      #   upper arm of a C shaped part) poses nothing in the void below it,
      # - a top also cuts every layer below on its "through" region — its
      #   opening not covered by any deeper machining floor, where the
      #   machining does not stop inside the part.

      fn_rounded_depth = lambda { |layer_def| layer_def.depth.round(3) }
      fn_deeper_floor_layer_defs = lambda { |depth|
        splds.select { |layer_def| fn_rounded_depth.call(layer_def) > depth && layer_def.machining_closed_paths.any? }
      }

      splds.each do |layer_def|
        layer_def.machining_closed_paths, op = Clippy.execute_union(closed_subjects: layer_def.machining_closed_paths) if layer_def.machining_closed_paths.size > 1
      end

      top_records = []         # { :depth, :raw_paths, :open_paths } of the machining tops swept so far
      upper_through_paths = [] # Through cuts of the machining tops strictly above the current layer
      covered_paths = []       # Matter of the layers strictly above the current layer
      matter_paths = []        # Part matter present just below the current depth : up-facing part
                               # faces (re)start it, down-facing part faces end it. Machining floors
                               # only pose their solid where it exists (nothing is posed in the void
                               # under a traversed local thickness, nor outside the part outline).

      # Active region of a machining floor : parts of its outline attributed to
      # the deepest machining top covering them (its own volume top for closed
      # volumes), kept where that top is open. Regions covered by a raw top
      # strictly between limit_depth and the floor belong to a volume starting
      # below the current layer : excluded (they cannot cut it, and their
      # openness — not swept yet — will rule their own floor when reached).
      fn_floor_activity = lambda { |floor_layer_def, limit_depth|
        floor_depth = fn_rounded_depth.call(floor_layer_def)
        remaining_paths = floor_layer_def.machining_closed_paths
        hidden_top_paths = splds.select { |layer_def|
          (d = fn_rounded_depth.call(layer_def)) > limit_depth && d < floor_depth
        }.flat_map(&:cutting_closed_paths)
        remaining_paths, op = Clippy.execute_difference(closed_subjects: remaining_paths, clips: hidden_top_paths) if hidden_top_paths.any?
        activity_paths = []
        top_records.reverse_each do |top_record|
          break if remaining_paths.empty?
          next if top_record[:depth] > limit_depth
          served_paths, op = Clippy.execute_intersection(closed_subjects: remaining_paths, clips: top_record[:raw_paths])
          next if served_paths.empty?
          remaining_paths, op = Clippy.execute_difference(closed_subjects: remaining_paths, clips: top_record[:raw_paths])
          unless top_record[:open_paths].empty?
            open_served_paths, op = Clippy.execute_intersection(closed_subjects: served_paths, clips: top_record[:open_paths])
            activity_paths += open_served_paths
          end
        end
        activity_paths
      }

      splds.each do |layer_def|
        depth = fn_rounded_depth.call(layer_def)
        deeper_floor_layer_defs = fn_deeper_floor_layer_defs.call(depth)

        # Fold this layer's part matter events : down-facing faces end the
        # matter, up-facing faces (re)start it
        matter_paths, op = Clippy.execute_difference(closed_subjects: matter_paths, clips: layer_def.bottom_closed_paths) if layer_def.bottom_closed_paths.any? && matter_paths.any?
        matter_paths += layer_def.closed_paths

        # Opening of this layer's machining tops : their region not covered by upper matter
        top_paths = layer_def.cutting_closed_paths
        top_paths, op = Clippy.execute_difference(closed_subjects: top_paths, clips: covered_paths) if top_paths.any? && covered_paths.any?
        top_records << { :depth => depth, :raw_paths => layer_def.cutting_closed_paths, :open_paths => top_paths } if layer_def.cutting_closed_paths.any?

        closed_paths = layer_def.closed_paths
        unless layer_def.machining_closed_paths.empty?
          # Machining floors pose their solid on their active region only, where part matter exists
          machining_paths = fn_floor_activity.call(layer_def, depth)
          machining_paths, op = Clippy.execute_intersection(closed_subjects: machining_paths, clips: matter_paths) if machining_paths.any?
          closed_paths += machining_paths
        end
        unless closed_paths.empty?
          closed_paths, op = Clippy.execute_union(closed_subjects: closed_paths) if closed_paths.size > 1
          # Deeper machining floors cut this layer on their active region
          floor_cutting_paths = deeper_floor_layer_defs.flat_map { |floor_layer_def| fn_floor_activity.call(floor_layer_def, depth) }
          cutting_paths = top_paths + floor_cutting_paths + upper_through_paths
          closed_paths, op = Clippy.execute_difference(closed_subjects: closed_paths, clips: cutting_paths) if cutting_paths.any?
          layer_def.closed_paths = closed_paths
        end

        # Through region of this layer's tops : their opening not stopped by a deeper floor
        if top_paths.any?
          deeper_floor_paths = deeper_floor_layer_defs.flat_map(&:machining_closed_paths)
          if deeper_floor_paths.any?
            through_paths, op = Clippy.execute_difference(closed_subjects: top_paths, clips: deeper_floor_paths)
          else
            through_paths = top_paths
          end
          upper_through_paths += through_paths
        end

        covered_paths += layer_def.closed_paths

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
        splds << PathsLayerDef.new(max_depth, DrawingProjectionLayerDef::TYPE_HOLES, closed_paths: through_paths)

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
                segment_defs = (vertex_defs + [ vertex_defs.first ]).each_cons(2).to_a.map! { |start_vertex_def, end_vertex_def|
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
        splds.insert(1, PathsLayerDef.new(max_depth, DrawingProjectionLayerDef::TYPE_OUTER, closed_paths: outer_paths))

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

    FACE_TYPE_SOLID = 0
    FACE_TYPE_CUTTING = 1
    FACE_TYPE_BOTTOM = 2

    FaceManipulatorDef = Struct.new(:face_manipulator, :face_type, :machining) do
      def machining?
        machining
      end
    end

    PathsLayerDef = Struct.new(:depth, :type, :su_layer, :closed_paths, :open_paths, :cutting_closed_paths, :machining_closed_paths, :bottom_closed_paths, :border_closed_paths, :border_open_paths) do
      def initialize(depth, type, su_layer: nil, closed_paths: [], open_paths: [], cutting_closed_paths: [], machining_closed_paths: [], bottom_closed_paths: [], border_closed_paths: [], border_open_paths: [])
        super(depth, type, su_layer, closed_paths, open_paths, cutting_closed_paths, machining_closed_paths, bottom_closed_paths, border_closed_paths, border_open_paths)
      end
    end
    PathBorderDef = Struct.new(:segment_defs, :is_loop) do
      def path
        @path ||= segment_defs.map { |segment_def|
          next unless segment_def.is_start_gate || segment_def.is_border
          [ segment_def.end_vertex_def.x, segment_def.end_vertex_def.y ]
        }.compact.flatten(1)
      end
    end
    PathSegmentDef = Struct.new(:start_vertex_def, :end_vertex_def, :is_start_gate, :is_end_gate, :is_border)
    PathVertexDef = Struct.new(:x, :y, :in_defs) do
      def is_on?
        @is_on ||= in_defs.select { |in_def| in_def.is_on }.any?
      end
    end
    PathVertexInDef = Struct.new(:is_on, :path)

  end

end