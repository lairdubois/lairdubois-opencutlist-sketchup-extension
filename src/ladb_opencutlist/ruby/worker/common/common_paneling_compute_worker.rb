module Ladb::OpenCutList

  require 'set'
  require_relative '../../lib/fiddle/clippy/clippy'
  require_relative '../../model/paneling/paneling_mesh_def'

  # Computes the panels that line the faces of a solid : the geometry half of
  # SmartReshapeTool's paneling action. Pure geometry : reads a
  # PanelingMeshDef, knows no SketchUp entity.
  #
  # - mesh : the solid, a PanelingMeshDef (its faces outward),
  # - face_indices : the faces to panel, in EXTRUSION ORDER - with a flat
  #   joint, the first of two neighbours runs to the other's plane, the
  #   second stops against the first's thickness,
  # - thickness : signed, positive outward (along the face normals), negative
  #   inward,
  # - joint_types : Hash edge key (PanelingMeshDef.edge_key) => JOINT_TYPE_FLAT
  #   or JOINT_TYPE_MITER,
  # - default_joint_type : the joint type of the edges not in joint_types.
  #
  # Returns an Array of PanelDef, one per face it could panel, in order, its
  # points in the mesh's space :
  # - face_index : the face it lines,
  # - gd_polygons : the sections on the face plane (Array of Array<Geom::Point3d>),
  # - up_polygons : the sections on the face plane offset by the thickness,
  # - sides : the side faces, as corner Arrays.
  #
  # The panel of a face is bounded by the planes of its neighbours, and around
  # the reflex corners and the vertices shared with no edge, by the zones it
  # gives up to the panel it would otherwise overlap - see #_get_corner_yields.
  class CommonPanelingComputeWorker

    JOINT_TYPE_FLAT = 'flat'.freeze
    JOINT_TYPE_MITER = 'miter'.freeze

    PanelDef = Struct.new(:face_index, :gd_polygons, :up_polygons, :sides)

    def initialize(mesh,
                   face_indices,

                   thickness:,
                   joint_types: {},
                   default_joint_type: JOINT_TYPE_FLAT

    )

      @mesh = mesh
      @faces = face_indices.map { |index| mesh.faces[index] } # PanelingMeshDef::Face, named fm / sfm below as the face manipulators they come from
      @selection = Set.new(@faces)

      @thickness = thickness
      @joint_types = joint_types
      @default_joint_type = default_joint_type

    end

    # -----

    def run
      return [] unless @mesh.is_a?(PanelingMeshDef)

      thickness = @thickness

      order = {}
      @faces.each_with_index { |fm, index| order[fm] = index }

      corner_yields = _get_corner_yields(thickness, order)

      extruded_faces = Set.new
      panel_defs = []
      @faces.each do |sfm|

        gd_plane = [ sfm.position, sfm.normal ]
        up_plane = [ sfm.position.offset(sfm.normal, thickness), sfm.normal ]

        # 1. The sections on the ground and up planes

        constraints = _get_constraints(sfm, thickness, extruded_faces)

        corner_trims = corner_yields.key?(sfm) ? corner_yields[sfm] : []

        gd_polygons = _compute_section(sfm, constraints, gd_plane, corner_trims, thickness)
        up_polygons = thickness.zero? ? [] : _compute_section(sfm, constraints, up_plane, corner_trims, thickness)

        next if gd_polygons.flatten(1).size < 3 || up_polygons.flatten(1).size < 3

        # 2. The side faces : one or more per constraint plane the panel
        # touches. Sections may gain corners (apexes on a level).

        side_planes = []
        (constraints.flat_map { |plane, fan_planes| [ plane ] + fan_planes } + corner_trims.flat_map { |_, half_spaces| half_spaces.map { |point, normal, _| [ point, normal ] } }).compact.each do |plane|
          next if plane[1].parallel?(sfm.normal) # A level itself, not a side
          side_planes << plane unless side_planes.any? { |other| other[1].parallel?(plane[1]) && plane[0].on_plane?(other) }
        end
        md_plane = [ sfm.position.offset(sfm.normal, thickness / 2.0), sfm.normal ]
        md_polygons = _compute_section(sfm, constraints, md_plane, corner_trims, thickness)
        sections = {}
        fn_section_at = lambda { |height|
          sections[height.to_f.round(9)] ||= _compute_section(sfm, constraints, [ sfm.position.offset(sfm.normal, height), sfm.normal ], corner_trims, thickness)
        }
        sides = _get_sides_points(side_planes, gd_polygons, up_polygons, md_polygons, gd_plane, thickness, fn_section_at)

        panel_defs << PanelDef.new(sfm.index, gd_polygons, up_polygons, sides)

        extruded_faces << sfm

      end

      panel_defs
    end

    # -----

    def _get_joint_type_miter?(edge)
      (@joint_types.key?(edge) ? @joint_types[edge] : @default_joint_type) == JOINT_TYPE_MITER
    end

    # Same rule as the tool : two selected faces are mitered when the edge
    # they share is ; sharing a vertex only, the first edge of that vertex
    # decides.
    def _get_faces_joint_type_miter?(face_1, face_2)
      return false unless face_1 == face_2 || @selection.include?(face_1) && @selection.include?(face_2)
      shared_edge = (@mesh.face_edges(face_1) & @mesh.face_edges(face_2)).first
      return _get_joint_type_miter?(shared_edge) unless shared_edge.nil?
      shared_vertex = (face_1.loop & face_2.loop).first
      return _get_joint_type_miter?(@mesh.vertex_edges(shared_vertex).first) unless shared_vertex.nil?
      false
    end

    # The constraints bounding the panel of +sfm+, in its outer loop order :
    # Array of [ edge plane, fan planes ], one per outer loop edge. The edge
    # plane comes from the neighbour across the edge, the fan planes from the
    # faces that only share the edge's START vertex with +sfm+ (in fan order) —
    # see #_compute_section for how each kind bounds the panel.
    #
    # A neighbour contributes the bisector plane when mitered, its plane offset
    # by the thickness when it is already extruded, its own plane otherwise. A
    # vertex fan face too : its bisector runs through the line where both
    # planes meet, as an edge neighbour's does along their edge.
    def _get_constraints(sfm, thickness, extruded_faces)

      face = sfm
      vertices = face.loop
      count = vertices.size

      edges = vertices.each_with_index.map { |vertex, index| @mesh.common_edge(vertex, vertices[(index + 1) % count]) }
      neighbours = edges.map { |edge| edge.nil? ? nil : @mesh.edge_faces(edge).find { |f| f != face } }

      fn_plane = lambda { |neighbour, point|
        fm = neighbour
        if _get_faces_joint_type_miter?(fm, sfm)
          normal = sfm.normal - fm.normal
          normal.valid? ? [ point, normal.normalize ] : nil
        elsif extruded_faces.include?(fm)
          [ fm.position.offset(fm.normal, thickness), fm.normal ]
        else
          fm.plane
        end
      }

      vertices.each_with_index.map { |vertex, index|
        point = @mesh.points[vertex]
        fan_planes = _get_vertex_fan(vertex, edges[index - 1], neighbours[index - 1], neighbours[index], face).map { |neighbour| fn_plane.call(neighbour, point) }.compact
        [ neighbours[index].nil? ? nil : fn_plane.call(neighbours[index], point), fan_planes ]
      }
    end

    # The faces around +vertex+ met walking from +from_face+ (reached through
    # +from_edge+) to +to_face+, both excluded.
    def _get_vertex_fan(vertex, from_edge, from_face, to_face, face)
      fan = []
      return fan if from_edge.nil? || from_face.nil? || to_face.nil?

      current_edge = from_edge
      current_face = from_face
      @mesh.vertex_faces(vertex).size.times do
        next_edge = @mesh.face_edges(current_face).find { |edge| edge != current_edge && edge.include?(vertex) }
        break if next_edge.nil?
        next_face = @mesh.edge_faces(next_edge).find { |f| f != current_face }
        break if next_face.nil? || next_face == to_face || next_face == face
        fan << next_face
        current_edge = next_edge
        current_face = next_face
      end

      fan
    end

    # True if the edge between the faces of +x_fm+ and +y_fm+ is convex.
    def _edge_convex?(x_fm, y_fm, edge)
      direction = @mesh.edge_direction_in(edge, y_fm)
      inside = y_fm.normal.cross(direction) # Points into the face of +y_fm+
      x_fm.normal.dot(inside) < 0
    end

    # The half space +x_fm+'s panel keeps against +y_fm+'s across +edge+, as
    # [ point, normal, sign ] : X is kept when sign * normal · (X - point) >= 0.
    # Same joint rules as #_get_constraints, with the extrusion order
    # read from +order+ (Hash face => index), so that it can be
    # asked about any pair, not only the panel being computed.
    def _get_half_space(x_fm, y_fm, edge, thickness, order)
      convex = _edge_convex?(x_fm, y_fm, edge)
      if _get_faces_joint_type_miter?(y_fm, x_fm)
        normal = x_fm.normal - y_fm.normal
        return nil unless normal.valid?
        [ @mesh.points[edge[0]], normal, convex ? 1 : -1 ]
      else
        offset = order.key?(y_fm) && order[y_fm] < order[x_fm] ? thickness : 0
        point = offset == 0 ? y_fm.position : y_fm.position.offset(y_fm.normal, offset)
        [ point, y_fm.normal, convex ? -1 : 1 ]
      end
    end

    # The zones panels give up around the REFLEX corners of the selection, as
    # Hash face => Array of [ corner point, half spaces ] (a zone
    # is the intersection of its half spaces).
    #
    # At a reflex corner, a panel P is the UNION of what its two edge
    # constraints allow : stretched past its neighbour X's edge by its other
    # constraint, it runs into X's thickness. When the three joints around the
    # corner are not consistent (e.g. two miters and a flat), X claims part of
    # that zone too, and the two overlap. One of them gives the overlap up : X
    # when the overlap shows on one of X's levels (it chamfers X's corner),
    # else P when it shows on one of P's (a notch), never a panel that would
    # only lose a zone touching its levels by a line — that would pinch it.
    def _get_corner_yields(thickness, order)

      fn_slab = lambda { |fm|
        min, max = [ 0, thickness ].minmax
        [
          [ fm.position.offset(fm.normal, max), fm.normal, -1 ],
          [ fm.position.offset(fm.normal, min), fm.normal, 1 ]
        ]
      }
      fn_not = lambda { |half_space| [ half_space[0], half_space[1], -half_space[2] ] }
      fn_levels = lambda { |fm| [ [ fm.position, fm.normal ], [ fm.position.offset(fm.normal, thickness), fm.normal ] ] }
      radius = 10 * [ thickness.abs.to_f, 1.0 ].max

      yields = Hash.new { |hash, key| hash[key] = [] }
      @selection.each do |sfm|

        face = sfm
        vertices = face.loop
        count = vertices.size
        next if count < 3

        edges = vertices.each_with_index.map { |vertex, index| @mesh.common_edge(vertex, vertices[(index + 1) % count]) }
        fn_neighbour = lambda { |edge| edge.nil? ? nil : @mesh.edge_faces(edge).find { |f| f != face } }

        vertices.each_with_index do |vertex, index|

          previous_edge = edges[index - 1]
          next_edge = edges[index]
          next if previous_edge.nil? || next_edge.nil?

          # Reflex corner of the face outline ?
          previous_direction = @mesh.points[vertices[index - 1]].vector_to(@mesh.points[vertex])
          next_direction = @mesh.points[vertex].vector_to(@mesh.points[vertices[(index + 1) % count]])
          next unless previous_direction.cross(next_direction).dot(face.normal) < 0

          q_fm = fn_neighbour.call(previous_edge)
          r_fm = fn_neighbour.call(next_edge)
          next if q_fm.nil? || r_fm.nil? || q_fm == r_fm

          p_q = _get_half_space(sfm, q_fm, previous_edge, thickness, order)
          p_r = _get_half_space(sfm, r_fm, next_edge, thickness, order)
          next if p_q.nil? || p_r.nil?

          qr_edge = @mesh.vertex_edges(vertex).find { |edge| @mesh.edge_faces(edge).include?(q_fm) && @mesh.edge_faces(edge).include?(r_fm) }
          point = @mesh.points[vertex]

          [ [ q_fm, r_fm, p_q, p_r, previous_edge ], [ r_fm, q_fm, p_r, p_q, next_edge ] ].each do |x_fm, other_fm, p_x, p_other, x_edge|
            next unless @selection.include?(x_fm)

            # The overlap : P stretched by its other constraint into X's
            # thickness, where X keeps the material against P and the other
            half_spaces = fn_slab.call(sfm) + fn_slab.call(x_fm) + [ p_other, fn_not.call(p_x) ]
            next if (x_p = _get_half_space(x_fm, sfm, x_edge, thickness, order)).nil?
            half_spaces << x_p
            unless qr_edge.nil?
              next if (x_other = _get_half_space(x_fm, other_fm, qr_edge, thickness, order)).nil?
              half_spaces << x_other
            end

            if fn_levels.call(x_fm).any? { |level| !_get_zone_rpath(point, half_spaces, level, radius).nil? }
              yields[x_fm] << [ point, half_spaces ]
            elsif fn_levels.call(sfm).any? { |level| !_get_zone_rpath(point, half_spaces, level, radius).nil? }
              yields[sfm] << [ point, half_spaces ]
            end

          end

        end

      end

      # Panels sharing only a vertex (e.g. around a degree 4 vertex at the
      # end of a valley) : a panel stretched past a reflex edge can run into
      # the thickness of a panel it only meets at that vertex, whose fan trim
      # is a local triangle that does not exclude it. The overlap is the
      # intersection of the two slabs and of what each corner keeps. The
      # later panel gives it up when it shows on one of its levels, else the
      # earlier one - never a panel the zone would pinch : touching one of its
      # levels inside its section by a point or a line only.
      sections = {}
      fn_section = lambda { |fm, level|
        sections[[ fm, level[0] ]] ||= begin
          extruded = Set.new(order.keys.select { |other| order[other] < order[fm] })
          _compute_section(fm, _get_constraints(fm, thickness, extruded), level)
        end
      }
      fn_pinches = lambda { |fm, point, half_spaces|
        zone_vertices = nil
        fn_levels.call(fm).any? { |level|
          next false unless _get_zone_rpath(point, half_spaces, level, radius).nil? # A notch
          zone_vertices ||= _get_zone_vertices(half_spaces)
          touching = zone_vertices.select { |vertex| vertex.on_plane?(level) && vertex.distance(point) <= radius }
          next false if touching.empty?
          x_axis, y_axis, z_axis = level[1].axes
          ti = Geom::Transformation.axes(level[0], x_axis, y_axis, z_axis).inverse
          polygons = fn_section.call(fm, level).map { |polygon| polygon.map { |p| p.transform(ti) } }
          touching.any? { |vertex|
            vertex = vertex.transform(ti)
            polygons.any? { |polygon| Geom.point_in_polygon_2D(vertex, polygon, false) }
          }
        }
      }
      @selection.each do |sfm|
        sfm.loop.each do |vertex|
          @mesh.vertex_faces(vertex).each do |x_face|

            x_fm = x_face
            next if x_fm.nil? || x_fm == sfm || !@selection.include?(x_fm)
            next if order[x_fm] < order[sfm] # Each pair once, from the earlier panel
            next if @mesh.vertex_edges(vertex).any? { |edge| @mesh.edge_faces(edge).include?(sfm) && @mesh.edge_faces(edge).include?(x_face) }

            next if (p_corners = _get_corner_half_spaces(sfm, vertex, thickness, order)).nil?
            next if (x_corners = _get_corner_half_spaces(x_fm, vertex, thickness, order)).nil?

            point = @mesh.points[vertex]
            p_corners.product(x_corners).each do |p_half_spaces, x_half_spaces|
              half_spaces = fn_slab.call(sfm) + fn_slab.call(x_fm) + p_half_spaces + x_half_spaces
              yielders = [ x_fm, sfm ].select { |fm| fn_levels.call(fm).any? { |level| !_get_zone_rpath(point, half_spaces, level, radius).nil? } }
              yielder = yielders.find { |fm| !fn_pinches.call(fm, point, half_spaces) } || yielders.first
              yields[yielder] << [ point, half_spaces ] unless yielder.nil?
            end

          end
        end
      end

      yields
    end

    # What the panel of +fm+ keeps at its outline corner +vertex+, as an
    # Array of half space lists (see #_get_half_space) whose union
    # is the corner : one list at a convex corner, one per edge at a reflex
    # corner. Fan planes (faces met at the vertex only) trim the corner : they
    # keep the side away from the corner point. Nil when the corner can't be
    # read.
    def _get_corner_half_spaces(fm, vertex, thickness, order)

      face = fm
      vertices = face.loop
      count = vertices.size
      return nil if count < 3 || (index = vertices.index(vertex)).nil?

      previous_vertex = vertices[index - 1]
      next_vertex = vertices[(index + 1) % count]
      previous_edge = @mesh.common_edge(previous_vertex, vertex)
      next_edge = @mesh.common_edge(vertex, next_vertex)
      return nil if previous_edge.nil? || next_edge.nil?

      fn_neighbour_face = lambda { |edge| @mesh.edge_faces(edge).find { |f| f != face } }
      q_face = fn_neighbour_face.call(previous_edge)
      r_face = fn_neighbour_face.call(next_edge)
      return nil if q_face.nil? || r_face.nil? || q_face == r_face

      p_q = _get_half_space(fm, q_face, previous_edge, thickness, order)
      p_r = _get_half_space(fm, r_face, next_edge, thickness, order)
      return nil if p_q.nil? || p_r.nil?

      # The corner on each level, and the two edge lines from it
      corners = [ 0, thickness ].map { |offset|
        level_plane = [ fm.position.offset(fm.normal, offset), fm.normal ]
        q_line = Geom.intersect_plane_plane(level_plane, [ p_q[0], p_q[1] ])
        r_line = Geom.intersect_plane_plane(level_plane, [ p_r[0], p_r[1] ])
        corner = q_line.nil? || r_line.nil? ? nil : Geom.intersect_line_line(q_line, r_line)
        corner.nil? ? nil : [ corner, q_line, r_line ]
      }.compact
      q_direction = @mesh.points[vertex].vector_to(@mesh.points[previous_vertex])
      r_direction = @mesh.points[vertex].vector_to(@mesh.points[next_vertex])

      previous_direction = @mesh.points[previous_vertex].vector_to(@mesh.points[vertex])
      next_direction = @mesh.points[vertex].vector_to(@mesh.points[next_vertex])
      reflex = previous_direction.cross(next_direction).dot(face.normal) < 0

      point = @mesh.points[vertex]
      fan_half_spaces = []
      _get_vertex_fan(vertex, previous_edge, q_face, r_face, face).each do |c_face|
        break if reflex
        c_fm = c_face
        if _get_faces_joint_type_miter?(c_fm, fm)
          normal = fm.normal - c_fm.normal
          next unless normal.valid?
          plane_point = point
        else
          normal = c_fm.normal
          plane_point = order.key?(c_fm) && order[c_fm] < order[fm] ? c_fm.position.offset(c_fm.normal, thickness) : c_fm.position
        end
        fan_plane = [ plane_point, normal ]
        # The fan line trims the corner on a level where it crosses both edges
        # of the corner (a miter line often passes through the ground corner) ;
        # otherwise its trim triangle lies outside the panel
        sign = nil
        corners.each do |corner, q_line, r_line|
          distance = normal.dot(plane_point.vector_to(corner))
          next if distance.abs < 1e-6
          q_point = Geom.intersect_line_plane(q_line, fan_plane)
          r_point = Geom.intersect_line_plane(r_line, fan_plane)
          next if q_point.nil? || r_point.nil?
          next unless corner.vector_to(q_point).dot(q_direction) > 0 && corner.vector_to(r_point).dot(r_direction) > 0
          sign = distance > 0 ? -1 : 1
          break
        end
        fan_half_spaces << [ plane_point, normal, sign ] unless sign.nil?
      end

      if reflex
        [ [ p_q ] + fan_half_spaces, [ p_r ] + fan_half_spaces ]
      else
        [ [ p_q, p_r ] + fan_half_spaces ]
      end
    end

    # The intersection of +half_spaces+ (see #_get_half_space) on
    # +level_plane+ within +radius+ of +point+, as a Clippy rpath in the frame
    # #_compute_section uses for that level, or nil when empty or flat.
    def _get_zone_rpath(point, half_spaces, level_plane, radius)

      origin, normal = level_plane
      x_axis, y_axis, z_axis = normal.axes
      ti = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis).inverse

      center = point.project_to_plane(level_plane).transform(ti)
      cu, cv = center.x.to_f, center.y.to_f
      zone = [ cu - radius, cv - radius, cu + radius, cv - radius, cu + radius, cv + radius, cu - radius, cv + radius ]
      flush_sides = []
      half_spaces.each do |hs_point, hs_normal, hs_sign|
        # sign * normal · (X - point) >= 0 on the level frame : a * u + b * v + c >= 0
        a = hs_sign * hs_normal.dot(x_axis)
        b = hs_sign * hs_normal.dot(y_axis)
        c = hs_sign * hs_normal.dot(hs_point.vector_to(origin))
        norm = Math.sqrt(a * a + b * b)
        if norm < 1e-9
          # Parallel to the level : keeps all of it, or nothing
          return nil if c < -1e-9
          if c < 1e-6
            # Bounded by the level itself : on one side only, else the zone is
            # flat, squeezed onto the level
            flush_sides << (hs_sign * hs_normal.dot(z_axis) > 0)
            return nil if flush_sides.uniq.size > 1
          end
          next
        end
        gu, gv = a / norm, b / norm                   # Towards the kept side
        du, dv = -gv, gu                              # Along the boundary
        distance = (a * cu + b * cv + c) / norm
        qu, qv = cu - distance * gu, cv - distance * gv # Center projected on the boundary
        size = 4 * radius + distance.abs
        rect = [
          qu - du * size, qv - dv * size,
          qu + du * size, qv + dv * size,
          qu + du * size + gu * size, qv + dv * size + gv * size,
          qu - du * size + gu * size, qv - dv * size + gv * size
        ]
        zone_paths, _ = Fiddle::Clippy.execute(
          clip_type: Fiddle::Clippy::CLIP_TYPE_INTERSECTION,
          fill_type: Fiddle::Clippy::FILL_TYPE_NON_ZERO,
          closed_subjects: [ zone ],
          clips: [ rect ]
        )
        zone = zone_paths.first
        return nil if zone.nil?
      end
      return nil if zone.size < 6 || Fiddle::Clippy.get_rpath_area(zone).abs < 1e-4

      zone
    end

    # The panel section in +level_plane+ : Array of polygons (Array<Geom::Point3d>).
    #
    # Each edge plane cuts the level plane along a line ; the raw outline joins
    # consecutive lines in the loop order, which keeps concave outlines right.
    # An edge that does not bind (swallowed by its neighbours) makes the raw
    # outline fold back on itself into a negatively wound loop, that Clippy
    # drops with the POSITIVE fill rule.
    #
    # A fan plane may only trim the corner it belongs to, never grow it : it
    # takes off the triangle between the corner and the points where its line
    # crosses the two edge lines. That triangle lies outside the outline when
    # the fan line passes beyond the corner. This is what clips a panel
    # stretched past a concave edge by the faces its stretch runs into.
    def _compute_section(sfm, constraints, level_plane, corner_trims = [], thickness = 0)

      origin, normal = level_plane
      x_axis, y_axis, z_axis = normal.axes
      t = Geom::Transformation.axes(origin, x_axis, y_axis, z_axis)
      ti = t.inverse

      fn_line = lambda { |plane| plane.nil? ? nil : Geom.intersect_plane_plane(level_plane, plane) }

      # [ edge line, fan lines at its start corner ]
      entries = []
      pending_fan_lines = []
      constraints.each do |plane, fan_planes|
        pending_fan_lines.concat(fan_planes.map { |fan_plane| fn_line.call(fan_plane) }.compact)
        next if (line = fn_line.call(plane)).nil?
        next if entries.any? && line[1].parallel?(entries.last[0][1])
        entries << [ line, pending_fan_lines ]
        pending_fan_lines = []
      end
      entries.first[1].concat(pending_fan_lines) if entries.any?
      while entries.size > 1 && entries.last[0][1].parallel?(entries.first[0][1])
        entries.first[1].concat(entries.pop[1])
      end
      return [] if entries.size < 3

      points = entries.each_with_index.map { |entry, index| Geom.intersect_line_line(entries[index - 1][0], entry[0]) }
      return [] if points.any?(&:nil?)

      # Corner trims
      triangles = []
      entries.each_with_index do |(line, fan_lines), index|
        previous_line = entries[index - 1][0]
        fan_lines.each do |fan_line|
          p1 = Geom.intersect_line_line(previous_line, fan_line)
          p2 = Geom.intersect_line_line(fan_line, line)
          triangles << [ points[index], p1, p2 ] unless p1.nil? || p2.nil?
        end
      end

      fn_to_rpath = lambda { |pts| pts.flat_map { |point| point = point.transform(ti); [ point.x.to_f, point.y.to_f ] } }

      rpath = fn_to_rpath.call(points)
      rpath = Fiddle::Clippy.reverse_rpath(rpath) unless Fiddle::Clippy.is_rpath_positive?(fn_to_rpath.call(@mesh.loop_points(sfm)))

      paths, _ = Fiddle::Clippy.execute(
        clip_type: Fiddle::Clippy::CLIP_TYPE_UNION,
        fill_type: Fiddle::Clippy::FILL_TYPE_POSITIVE,
        closed_subjects: [ rpath ]
      )
      # A clip shares edges with the outline only up to rounding, Clippy may
      # then read it as a hole touching the outline : grown by a hair, it cuts
      # a notch
      fn_grow = lambda { |rpath| Fiddle::Clippy.inflate_paths(paths: [ rpath ], delta: 1e-4, join_type: Fiddle::Clippy::JOIN_TYPE_MITER, miter_limit: 100.0) }

      clips = triangles.map { |triangle| fn_to_rpath.call(triangle) }
                       .select { |rpath| Fiddle::Clippy.get_rpath_area(rpath).abs > 1e-6 }
                       .flat_map { |rpath| fn_grow.call(rpath) }

      # Corner zones given up to a neighbour — see #_get_corner_yields
      radius = 10 * [ thickness.abs.to_f, 1.0 ].max
      corner_trims.each do |point, half_spaces|
        next if (zone = _get_zone_rpath(point, half_spaces, level_plane, radius)).nil?
        clips.concat(fn_grow.call(zone))
      end

      paths, _ = Fiddle::Clippy.execute(
        clip_type: Fiddle::Clippy::CLIP_TYPE_DIFFERENCE,
        fill_type: Fiddle::Clippy::FILL_TYPE_NON_ZERO,
        closed_subjects: paths,
        clips: clips
      ) if clips.any? && paths.any?

      # Clippy keeps corners SketchUp would merge, and the trims leave corners
      # in the middle of an edge : drop them, a side face pairs whole edges
      paths.select { |path| Fiddle::Clippy.is_rpath_positive?(path) && Fiddle::Clippy.get_rpath_area(path) > 1e-6 }
           .map { |path|
             polygon = []
             path.each_slice(2) do |x, y|
               point = Geom::Point3d.new(x, y, 0).transform(t)
               polygon << point unless polygon.any? && polygon.last == point
             end
             polygon.pop while polygon.size > 1 && polygon.last == polygon.first
             loop do
               index = polygon.each_index.find { |i| polygon.size > 3 && polygon[i].on_line?([ polygon[i - 1], polygon[i - 1].vector_to(polygon[(i + 1) % polygon.size]) ]) }
               break if index.nil?
               polygon.delete_at(index)
             end
             polygon
           }
           .select { |polygon| polygon.size >= 3 }
           .each { |polygon|
             # A zone touching the level along a line only (no area) still
             # needs its corners on the section edges, for the sides
             corner_trims.each do |point, half_spaces|
               vertices = _get_zone_vertices(half_spaces).select { |vertex| vertex.on_plane?(level_plane) && vertex.distance(point) <= radius }
               next if vertices.size < 2 || !_get_zone_rpath(point, half_spaces, level_plane, radius).nil?
               vertices.each do |vertex|
                 index = polygon.each_index.find { |i|
                   p1, p2 = polygon[i], polygon[(i + 1) % polygon.size]
                   vertex != p1 && vertex != p2 && vertex.on_line?([ p1, p1.vector_to(p2) ]) && p1.vector_to(vertex).dot(vertex.vector_to(p2)) > 0
                 }
                 polygon.insert(index + 1, vertex) unless index.nil?
               end
             end
           }
    end

    # The corners of the zone bounded by +half_spaces+ (see
    # #_get_half_space) : the points where three of their planes
    # meet, kept by all of them.
    def _get_zone_vertices(half_spaces)
      planes = half_spaces.map { |point, normal, _| [ point, normal.normalize ] }
      vertices = []
      planes.combination(3) do |a, b, c|
        next if (line = Geom.intersect_plane_plane(a, b)).nil?
        next if (vertex = Geom.intersect_line_plane(line, c)).nil?
        next unless half_spaces.all? { |point, normal, sign| sign * normal.normalize.dot(point.vector_to(vertex)) >= -1e-6 }
        vertices << vertex unless vertices.any? { |other| other == vertex }
      end
      vertices
    end

    # The side faces of the panel, as Array of corner Arrays, one or more per
    # plane in +side_planes+ (a plane may carry several, e.g. the ends of the
    # two arms of a U).
    #
    # Each section edge lying on a side plane at the ground level pairs with
    # the one facing it at the up level : the two are linked end to end by the
    # planes of the adjacent sides. An edge left alone tapers to an apex
    # between the levels, where its plane meets the planes of its two adjacent
    # sides : the panel changes its topology across its thickness there, and
    # the apex is shared with these adjacent sides, whose ends are then linked
    # through it. An apex lying ON a level is inserted in that section's edge
    # (+gd_polygons+ / +up_polygons+ are updated in place), so build the
    # level faces after this. Each side is convex, its
    # corners are sorted around their centroid.
    #
    # A pairing is kept only if the side it makes crosses the mid level
    # (+md_polygons+, the section halfway between the levels) along a single
    # edge of that section : a level segment lying on two planes (e.g. a
    # corner's edge on a zone bisector through it) would otherwise pair with
    # a far segment, across the panel.
    #
    # Two corners may also be linked through TWO apexes, when a third plane
    # runs between their adjacent ones (e.g. an apex fan face and an earlier
    # panel's thickness both crossing the side) : the side then has a corner
    # more. Every apex strictly between the levels must lie on the boundary of
    # the section at its height (+fn_section_at+ : height => polygons), else
    # the planes meet outside the panel.
    def _get_sides_points(side_planes, gd_polygons, up_polygons, md_polygons, gd_plane, thickness, fn_section_at = nil)

      fn_center = lambda { |points|
        Geom::Point3d.new(
          points.map(&:x).inject(:+) / points.size,
          points.map(&:y).inject(:+) / points.size,
          points.map(&:z).inject(:+) / points.size
        )
      }
      fn_same_plane = lambda { |p1, p2| p1[1].parallel?(p2[1]) && p1[0].on_plane?(p2) }
      fn_segments = lambda { |polygons, plane|
        segments = []
        polygons.each do |polygon|
          polygon.each_with_index do |point, index|
            next_point = polygon[(index + 1) % polygon.size]
            segments << [ point, next_point ] if point != next_point && point.on_plane?(plane) && next_point.on_plane?(plane)
          end
        end
        segments
      }
      fn_height = lambda { |point| point.vector_to(point.project_to_plane(gd_plane)).dot(gd_plane[1]) * -1 }
      height_min, height_max = [ 0, thickness ].minmax

      # True if the convex side through +points+ on +plane+ crosses the mid
      # level along one edge of the mid section
      md_height = thickness / 2.0
      fn_on_md_section = lambda { |plane, points|
        next true if md_polygons.empty?
        crossings = []
        points.combination(2) do |p1, p2|
          h1 = fn_height.call(p1) - md_height
          h2 = fn_height.call(p2) - md_height
          if h1.abs < 1e-9
            crossings << p1
          elsif h1 * h2 < 0
            crossings << Geom.linear_combination(h2 / (h2 - h1), p1, h1 / (h1 - h2), p2)
          end
        end
        crossings << points.last if (fn_height.call(points.last) - md_height).abs < 1e-9
        next true if crossings.size < 2
        c1, c2 = crossings.combination(2).max_by { |a, b| a.distance(b) }
        next true if c1 == c2
        fn_segments.call(md_polygons, plane).any? { |m1, m2|
          direction = m1.vector_to(m2).normalize
          length = m1.distance(m2)
          [ c1, c2 ].all? { |c|
            abscissa = m1.vector_to(c).dot(direction)
            c.on_line?([ m1, direction ]) && abscissa >= -1e-3 && abscissa <= length + 1e-3
          }
        }
      }

      # True if +point+ lies on the boundary of the section at its height
      # (on a level : that level's section, as completed so far - e.g. a fan
      # bisector through the face corner meets its neighbours there, but that
      # corner lies outside a section pulled back by an earlier panel)
      fn_on_section_boundary = lambda { |point|
        height = fn_height.call(point)
        if (height - 0).abs < 1e-6
          polygons = gd_polygons
        elsif (height - thickness).abs < 1e-6
          polygons = up_polygons
        else
          next true if fn_section_at.nil?
          polygons = fn_section_at.call(height)
        end
        polygons.any? { |polygon|
          polygon.each_with_index.any? { |p1, index|
            p2 = polygon[(index + 1) % polygon.size]
            point == p1 || point.on_line?([ p1, p1.vector_to(p2) ]) && p1.vector_to(point).dot(point.vector_to(p2)) >= 0
          }
        }
      }

      sides = nil
      3.times do

        sides = []   # [ plane, points ]
        apexes = []  # [ apex, segment ]
        tapers = []  # [ plane, segment, apexes ] : candidates, a segment may lie on two planes

        side_planes.each do |plane|

          other_planes = side_planes.reject { |other| fn_same_plane.call(other, plane) }

          # The point where +plane_a+ and +plane_b+ meet on this plane between
          # the levels (+strict+ : not on a level), on the panel's boundary,
          # and not on the line of +p1+ +p2+ (no taper, e.g. p1 or p2 itself,
          # through a plane holding both) — or nil
          fn_apex_point = lambda { |plane_a, plane_b, p1, p2, strict|
            next nil if fn_same_plane.call(plane_a, plane_b)
            next nil if (line = Geom.intersect_plane_plane(plane_a, plane_b)).nil?
            next nil if (point = Geom.intersect_line_plane(line, plane)).nil?
            margin = strict ? -1e-3 : 1e-6
            height = fn_height.call(point)
            next nil unless height >= height_min - margin && height <= height_max + margin
            next nil if point.on_line?([ p1, p1.vector_to(p2) ])
            next nil unless fn_on_section_boundary.call(point)
            point
          }

          # The apexes linking +p1+ to +p2+ on this plane between the levels
          # (+strict+ : not on a level) : one where their adjacent planes meet,
          # else two through a third plane between them - both strictly
          # between the levels : a level corner there is a segment pairing,
          # not a taper. Nil if none.
          fn_apex = lambda { |p1, p2, strict|
            p1_planes = other_planes.select { |other| p1.on_plane?(other) }
            p2_planes = other_planes.select { |other| p2.on_plane?(other) }
            center = fn_center.call([ p1, p2 ])
            apex = p1_planes.product(p2_planes).map { |p1_plane, p2_plane|
              fn_apex_point.call(p1_plane, p2_plane, p1, p2, strict)
            }.compact.min_by { |point| point.distance(center) }
            next [ apex ] unless apex.nil?
            p1_planes.product(p2_planes).flat_map { |p1_plane, p2_plane|
              other_planes.map { |c_plane|
                next nil if fn_same_plane.call(c_plane, p1_plane) || fn_same_plane.call(c_plane, p2_plane)
                next nil if (a1 = fn_apex_point.call(p1_plane, c_plane, p1, p2, true)).nil?
                next nil if (a2 = fn_apex_point.call(c_plane, p2_plane, p1, p2, true)).nil?
                next nil if a1 == a2
                [ a1, a2 ]
              }.compact
            }.min_by { |a1, a2| a1.distance(center) + a2.distance(center) }
          }

          # Two corners facing each other across the side : on the plane of the
          # same adjacent side, or on adjacent sides meeting at apexes between
          # them. Returns the apexes ([] when direct), or nil.
          fn_link = lambda { |gd_point, up_point|
            next [] if other_planes.any? { |other| gd_point.on_plane?(other) && up_point.on_plane?(other) }
            fn_apex.call(gd_point, up_point, true)
          }

          gd_segments = fn_segments.call(gd_polygons, plane)
          up_segments = fn_segments.call(up_polygons, plane)

          alone_segments = []
          used_up_segments = []
          gd_segments.each do |gd_segment|
            side_apexes = nil
            up_segment = up_segments.find { |segment|
              next false if used_up_segments.include?(segment)
              # Each ground corner to the up corner it links to most directly
              links = gd_segment.map { |gd_point|
                segment.map { |up_point| fn_link.call(gd_point, up_point) }.compact.min_by(&:size)
              }
              next false if links.any?(&:nil?)
              side_apexes = links.flatten(1)
              fn_on_md_section.call(plane, gd_segment + segment + side_apexes)
            }
            if up_segment.nil?
              alone_segments << gd_segment
            else
              used_up_segments << up_segment
              sides << [ plane, gd_segment + up_segment + side_apexes ]
            end
          end
          alone_segments.concat(up_segments - used_up_segments)

          alone_segments.each do |segment|
            next if (taper_apexes = fn_apex.call(segment[0], segment[1], false)).nil?
            tapers << [ plane, segment, taper_apexes ]
          end

        end

        # A section edge borders one side only : when it lies on two planes
        # (e.g. a miter and the level of the panel it bisects with), keep the
        # side tapering to an apex strictly between the levels
        fn_same_segment = lambda { |s1, s2| (s1[0] == s2[0] && s1[1] == s2[1]) || (s1[0] == s2[1] && s1[1] == s2[0]) }
        fn_on_level = lambda { |point| [ 0, thickness ].any? { |level| (fn_height.call(point) - level).abs < 1e-6 } }
        taper_segments = []
        tapers.sort_by { |_, _, taper_apexes| taper_apexes.any? { |apex| fn_on_level.call(apex) } ? 1 : 0 }.each do |plane, segment, taper_apexes|
          next if taper_segments.any? { |other| fn_same_segment.call(other, segment) }
          taper_segments << segment
          taper_apexes.each { |apex| apexes << [ apex, segment ] }
          sides << [ plane, segment + taper_apexes ]
        end

        # Adjacent sides share the apex
        apexes.each do |apex, segment|
          sides.each do |plane, points|
            next if points.any? { |point| point == apex }
            points << apex if apex.on_plane?(plane) && segment.any? { |end_point| points.any? { |point| point == end_point } }
          end
        end


        # An apex ON a level splits the section edge it lies on : the sides on
        # either side of it need that corner
        inserted = false
        apexes.each do |apex, _|
          [ [ gd_polygons, 0 ], [ up_polygons, thickness ] ].each do |polygons, level|
            next unless (fn_height.call(apex) - level).abs < 1e-6
            polygons.each do |polygon|
              index = polygon.each_index.find { |i|
                p1, p2 = polygon[i], polygon[(i + 1) % polygon.size]
                apex != p1 && apex != p2 && apex.on_line?([ p1, p1.vector_to(p2) ]) && p1.vector_to(apex).dot(apex.vector_to(p2)) > 0
              }
              next if index.nil?
              polygon.insert(index + 1, apex)
              inserted = true
            end
          end
        end
        break unless inserted

      end

      sides = sides.map { |plane, points|

        points = points.each_with_object([]) { |point, a| a << point unless a.any? { |other| other == point } }
        next nil if points.size < 3

        centroid = fn_center.call(points)
        x_axis = centroid.vector_to(points.first)
        next nil unless x_axis.valid?
        x_axis.normalize!
        y_axis = plane[1].cross(x_axis)
        next nil unless y_axis.valid?
        y_axis.normalize!

        points.sort_by { |point|
          v = centroid.vector_to(point)
          Math.atan2(v.dot(y_axis), v.dot(x_axis))
        }
      }.compact

      # A section edge borders one side only : a side whose every section edge
      # another side already borders is redundant (paired on a plane that
      # only grazes the panel along these edges, e.g. a zone bisector)
      fn_same_segment = lambda { |s1, s2| (s1[0] == s2[0] && s1[1] == s2[1]) || (s1[0] == s2[1] && s1[1] == s2[0]) }
      fn_segments_of = lambda { |points| points.each_with_index.map { |point, index| [ point, points[(index + 1) % points.size] ] } }
      level_segments = (gd_polygons + up_polygons).flat_map { |points| fn_segments_of.call(points) }
      sides_level_segments = sides.map { |points| fn_segments_of.call(points).select { |segment| level_segments.any? { |other| fn_same_segment.call(other, segment) } } }
      fn_count = lambda { |segment| sides_level_segments.count { |segments| segments.any? { |other| fn_same_segment.call(other, segment) } } }
      loop do
        index = sides_level_segments.each_index.find { |i| sides_level_segments[i].any? && sides_level_segments[i].all? { |segment| fn_count.call(segment) > 1 } }
        break if index.nil?
        sides.delete_at(index)
        sides_level_segments.delete_at(index)
      end

      # Close the shell : a side touching no level by a whole edge (e.g. a
      # zone face between apexes) is a loop of the edges bordered once
      edges = [] # [ p1, p2, count ]
      (gd_polygons + up_polygons + sides).each do |points|
        points.each_with_index do |p1, index|
          p2 = points[(index + 1) % points.size]
          next if p1 == p2
          edge = edges.find { |q1, q2, _| (q1 == p1 && q2 == p2) || (q1 == p2 && q2 == p1) }
          edge.nil? ? edges << [ p1, p2, 1 ] : edge[2] += 1
        end
      end
      open_edges = edges.select { |_, _, count| count == 1 }.map { |p1, p2, _| [ p1, p2 ] }
      until open_edges.empty?
        loop_points = open_edges.shift
        loop do
          index = open_edges.index { |p1, p2| p1 == loop_points.last || p2 == loop_points.last }
          break if index.nil?
          p1, p2 = open_edges.delete_at(index)
          next_point = p1 == loop_points.last ? p2 : p1
          break if next_point == loop_points.first
          loop_points << next_point
        end
        next if loop_points.size < 3
        normal = nil
        loop_points.combination(3).each do |a, b, c|
          normal = a.vector_to(b).cross(a.vector_to(c))
          break if normal.valid? && normal.length > 1e-6
          normal = nil
        end
        next if normal.nil?
        next unless loop_points.all? { |point| point.on_plane?([ loop_points.first, normal ]) }
        sides << loop_points
      end

      sides
    end

  end

end
