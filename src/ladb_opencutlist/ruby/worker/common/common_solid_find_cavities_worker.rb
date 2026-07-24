module Ladb::OpenCutList

  require_relative '../../lib/fiddle/meshy/meshy'
  require_relative '../../lib/geometrix/geometrix'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/solid/solid_mesh_def'
  require_relative '../../model/solid/solid_boolean_result_def'
  require_relative '../../model/solid/solid_cavity_fragment_def'

  # Finds the cavities enclosed by a set of panels — e.g. the interior volume
  # of a cabinet, one per compartment — powered by the Meshy native lib
  # (Manifold).
  #
  # Pure computation : consumes panel DrawingDefs — single or arrays, whose
  # face manipulators may span nested sub containers — and produces a
  # SolidBooleanResultDef whose fragment_defs are the cavities
  # (SolidCavityFragmentDef, carrying their openness), in WORLD coordinates.
  # No entity is read or written.
  #
  # Principle : the panels are subtracted from an envelope, splitting the
  # leftover space into disjoint bodies, told apart by face provenance (the
  # envelope faces carry the reserved face id 0). Two envelope modes :
  #
  # - ENVELOPE_HULL (default) : the envelope is the convex hull of the
  #   panels. The hull caps the openings flush with the panel edges, so the
  #   cavities of an OPEN enclosure (e.g. a cabinet without its front) are
  #   found too, closed by the caps. Open candidates are told apart by the
  #   STRUCTURE of their caps : a real compartment opens on at most
  #   max_opening_planes DOMINANT cap planes (1 for an open front, 2 for a
  #   through tube — see SolidCavityFragmentDef#opening_plane_count), while
  #   the outside world and the concavity pockets a NON-convex assembly
  #   leaves between itself and its hull face the envelope on many comparable
  #   planes and are filtered out. max_openness — the maximum fraction of the
  #   candidate surface lying on the caps — remains as an optional secondary
  #   cap (disabled by default).
  #
  # - ENVELOPE_BBOX : the envelope is the panels world bounds inflated by
  #   ENVELOPE_MARGIN. Only hermetically closed cavities are found : any
  #   opening connects the would-be cavity to the envelope boundary, and the
  #   single body carrying envelope faces is the outside world, dropped.
  #
  # ENVELOPE REDUCTION (hull mode, reduce_envelope option) : when a panel is
  # RECESSED behind an opening (e.g. shelves shallower than the sides, or a
  # cabinet back set forward from the case's true rear edge), the
  # compartments it separates communicate through the space in front of its
  # edge and would come out as a single merged cavity. Such a panel is
  # betrayed by its edge (chant) faces : they bound the cavity on a plane
  # that, extended, crosses the cavity interior, with envelope cap beyond it.
  # Chants merely lying on the same plane can be pure coincidence (e.g. a
  # large contour panel and an unrelated divider's free tip landing on the
  # same depth) : they are first split into sub-groups of chant triangles
  # that physically TOUCH each other (share a vertex, transitively), not
  # just coincide numerically — see #_reduction_group_components. A chant
  # is trusted when, within ONE such touching sub-group, any of :
  # - the SAME panel also bounds the cavity on BOTH its main faces (front
  #   and back — the two compartments it separates, e.g. a recessed shelf) ;
  # - SEVERAL DISTINCT panels make up the sub-group — that alone is strong
  #   evidence of an intentional, uniformly receding assembly (e.g. a shelf
  #   recessed together with the case's own top/bottom — a lone panel could
  #   never pass the BOTH-main-faces test above, since a contour panel's
  #   other main face faces outward, not another cavity) ;
  # - failing both, the pocket a reduction there would carve out (the
  #   envelope cap area beyond the plane) stays clear of the group's own
  #   (u, v) silhouette — walled in by other panels on its lateral sides
  #   rather than reaching the envelope's outer edge (e.g. a lone recessed
  #   back panel, walled by the sides/top/bottom) — see
  #   #_reduction_pocket_confined?.
  # Failing all three, this sub-group's chant is exposed by a
  # concave/notched footprint, not a recess, and reducing there would clip
  # away the real cavity instead of splitting it. A chant is further
  # trusted only when the sub-group's MERGED footprint (safe now that
  # touching, not mere plane coincidence, backs the grouping) is a SIDE face
  # (perpendicular to its WIDTH, running its full LENGTH — e.g. a shelf's
  # recessed front edge) rather than an END face (perpendicular to its
  # LENGTH, where the board simply stops — e.g. the
  # free tip of an L-shaped divider) : an END has no group-wide role, the
  # real panels already separate the compartments wherever the board
  # actually is, and extending its plane would clip an unrelated part of
  # the assembly it merely happens to cross (e.g. past another divider it
  # does not connect to) — see #_detect_reduction_planes /
  # #_reduction_side_plane?. Testing the sub-group's merged footprint rather
  # than each panel's own — safe only because touching already rules out
  # coincidence — lets a short member (e.g. a mullion shorter than the case
  # is deep, in a non-rectangular assembly) be judged alongside what it
  # actually connects to, instead of on its own possibly-misleading aspect
  # ratio. The envelope is then reduced by clipping it at
  # each remaining (SIDE) plane (keeping the panel side) and the open
  # cavities are recomputed : the caps recede to the most recessed panel
  # edge — the whole connected group is reduced to the depth of its
  # shallowest element — and each compartment comes out as its own cavity.
  #
  # Panels may overlap each other freely (the boolean absorbs overlaps, no
  # exact joinery needed) and gaps below the SketchUp merge tolerance are
  # sealed by Meshy's plane canonicalization.
  #
  # Each cavity fragment carries the indices (in the panel drawing defs list)
  # of the panels whose faces bound it (SolidFragmentDef#src_indices).
  class CommonSolidFindCavitiesWorker

    Meshy = Fiddle::Meshy

    ENVELOPE_HULL = 'hull'.freeze
    ENVELOPE_BBOX = 'bbox'.freeze

    # Bbox envelope inflation, in inches. Keeps the envelope planes well
    # clear of the panel planes, so that Meshy's plane canonicalization
    # (TOLERANCE scale) never merges an envelope face with a panel face.
    ENVELOPE_MARGIN = 1.0

    # A cavity boundary face is an edge face of its panel when its
    # normal departs from the panel dominant normal by more than 60°.
    REDUCTION_EDGE_DOT = 0.5

    # Minimum crossing depth, in inches, for an edge plane to trigger the
    # envelope reduction : recesses within snapping noise are ignored.
    REDUCTION_MIN_DEPTH = SolidMeshDef::TOLERANCE * 10

    # Minimum accumulated edge area, in square inches, for a plane to
    # trigger the envelope reduction. A real edge strip spans the panel
    # thickness across the cavity (square inches), while the degenerate
    # sliver triangles the boolean may leave where a panel face is flush
    # with the hull are many orders of magnitude below : without this
    # filter, such a sliver — whose arbitrary normal rarely matches any
    # panel plane — seeds a diagonal reduction plane that shreds the
    # cavity. Slivers being nudge artifacts, they also leak the panel
    # order into the result.
    REDUCTION_MIN_AREA = REDUCTION_MIN_DEPTH * REDUCTION_MIN_DEPTH

    def initialize(panel_drawing_defs,

                   envelope: ENVELOPE_HULL,
                   max_opening_planes: 2,
                   max_openness: 1.0,
                   reduce_envelope: true,
                   validate: true

    )

      @panel_drawing_defs = Array(panel_drawing_defs)

      @envelope = envelope
      @max_opening_planes = max_opening_planes
      @max_openness = max_openness
      @reduce_envelope = reduce_envelope
      @validate = validate

    end

    # -----

    def run
      result_def = SolidBooleanResultDef.new

      if @panel_drawing_defs.empty? || !@panel_drawing_defs.all? { |drawing_def| drawing_def.is_a?(DrawingDef) }
        result_def.errors << [ 'default.error' ]
        return result_def
      end
      unless Meshy.available?
        result_def.errors << [ 'core.error.exception', { :error => "Can't load Meshy" } ]
        return result_def
      end

      # Meshes are extracted in WORLD coordinates : each drawing def may have
      # its own transformation, the world is the only space common to all
      # operands, and the envelope is built in that space.
      panel_mesh_defs = @panel_drawing_defs.map { |drawing_def| SolidMeshDef.from_drawing_def(drawing_def) }

      # Curves are not propagated through Manifold (provenance is per-triangle
      # only) : collect their world-coordinates segments here for geometric
      # re-attribution if the cavities get rebuilt.
      panel_mesh_defs.each { |mesh_def| result_def.curve_info_defs.concat(mesh_def.curve_info_defs) }

      # Merge all face info registries into a single one, offsetting ids
      # accordingly. Id 0 is reserved for the envelope : it drives the
      # outside / openness filtering below. Panel id ranges are kept aside to
      # attribute each cavity to the panels bounding it.
      face_info_defs = [ SolidFaceInfoDef.new(nil, virtual: true) ]
      panel_id_ranges = []
      panel_meshes = []
      panel_mesh_defs.each_with_index do |mesh_def, panel_index|
        next if mesh_def.empty?
        id_offset = face_info_defs.length
        panel_meshes << mesh_def.to_meshy_hash(id_offset: id_offset)
        face_info_defs.concat(mesh_def.face_info_defs)
        panel_id_ranges << [ (id_offset...face_info_defs.length), panel_index ]
      end
      if panel_meshes.empty?
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      envelope_mesh = @envelope == ENVELOPE_BBOX ? _envelope_bbox_mesh(panel_meshes) : _envelope_hull_mesh(panel_meshes)
      if envelope_mesh.nil?
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      # The cavities are collected by TWO complementary passes :
      #
      # - The HERMETIC cavities (openness == 0) come from the direct
      #   subtraction : they are internal voids of the panel union, which
      #   Meshy computes exactly but whose fragment serialization does not
      #   round-trip (an exported void resolves into zero-volume membranes) —
      #   so they must be captured in the very operation that subtracts the
      #   panels. Joint imperfection residues never touch them : a residue
      #   reaching a cavity would be an opening.
      #
      # - The OPEN cavities (openness > 0, hull mode only) come from a
      #   union-then-subtraction : welding the panels together first lets the
      #   joints between imperfectly joined panels resolve INSIDE the union,
      #   so the subtraction cannot imprint them as razor-thin flaps on the
      #   cavities. This also makes the result independent of the panel
      #   order, which otherwise leaks into the output through the chained
      #   cut union and the canonical plane tie-breaks. An open assembly has
      #   no internal void, so nothing is lost by the fragment round-trip.
      #
      # A cavity is hermetic or open, never both : the two sets are disjoint
      # by construction.

      fn_collect = lambda { |output, hermetic|
        collected = []
        next collected unless output['fragments'].is_a?(Array)
        output['fragments'].each do |fragment|
          face_ids = fragment['face_ids']
          next unless face_ids.is_a?(Array) && !face_ids.empty?
          volume, total_area, envelope_area = _measure(fragment)
          # Sheet residue : a body whose mean thickness is below the SketchUp
          # merge tolerance is a collapsed joint imperfection, not a void
          next if total_area <= 0 || 2.0 * volume / total_area < SolidMeshDef::TOLERANCE
          openness = envelope_area / total_area
          if hermetic
            next if face_ids.include?(0)  # Envelope face : the outside world or an open cavity
            openness = 0.0                # No envelope face at all : hermetically closed
          else
            # openness == 1.0 would be a body bounded by the envelope only,
            # a pure hull artifact touching no panel
            next if openness <= 0 || openness >= 1.0 || openness > @max_openness
          end
          fragment_def = SolidCavityFragmentDef.new(
            fragment['vertices'], fragment['face_indices'], face_ids, face_info_defs,
            src_indices: _panel_indices(face_ids, panel_id_ranges),
            openness: openness
          )
          next if fragment_def.empty?
          # Structural filter : a real compartment opens on few flat openings,
          # the outside world and concavity pockets face the envelope on many
          # planes
          next if !hermetic && fragment_def.opening_plane_count > @max_opening_planes
          collected << fragment_def
        end
        collected
      }

      # Hermetic pass
      direct_output = Meshy.operate(
        :operation => Meshy::OPERATION_SUBTRACTION,
        :validate => @validate,
        :tolerance => SolidMeshDef::TOLERANCE,
        :src_meshes => [ envelope_mesh ],
        :cut_meshes => panel_meshes
      )
      return result_def if _report_errors(direct_output, result_def)
      result_def.fragment_defs.concat(fn_collect.call(direct_output, true))

      # Open pass (the bbox envelope only reveals hermetic cavities)
      if @envelope != ENVELOPE_BBOX
        union_output = Meshy.operate(
          :operation => Meshy::OPERATION_UNION,
          :validate => false,  # Operands were validated by the hermetic pass
          :tolerance => SolidMeshDef::TOLERANCE,
          :src_meshes => panel_meshes,
          :cut_meshes => []
        )
        return result_def if _report_errors(union_output, result_def)

        welded_meshes = (union_output['fragments'] || []).map { |fragment|
          {
            :vertices => fragment['vertices'],
            :face_indices => fragment['face_indices'],
            :face_ids => fragment['face_ids'],
            :tolerance => SolidMeshDef::TOLERANCE
          }
        }
        unless welded_meshes.empty?
          welded_output = Meshy.operate(
            :operation => Meshy::OPERATION_SUBTRACTION,
            :validate => false,
            :tolerance => SolidMeshDef::TOLERANCE,
            :src_meshes => [ envelope_mesh ],
            :cut_meshes => welded_meshes
          )
          return result_def if _report_errors(welded_output, result_def)
          open_fragment_defs = fn_collect.call(welded_output, false)

          # Envelope reduction : recessed panel edges detected on the open
          # cavities clip the envelope, and the open cavities are recomputed
          # against the reduced envelope — see the class doc.
          if @reduce_envelope && !open_fragment_defs.empty?
            reduction_planes = _detect_reduction_planes(open_fragment_defs, panel_id_ranges, panel_meshes, _panel_dominant_normals(panel_meshes), envelope_mesh)
            unless reduction_planes.empty?
              reduction_output = Meshy.operate(
                :operation => Meshy::OPERATION_INTERSECTION,
                :validate => false,
                :tolerance => SolidMeshDef::TOLERANCE,
                :src_meshes => [ envelope_mesh ],
                :cut_meshes => reduction_planes.map { |normal, d| _reduction_slab_mesh(normal, d, envelope_mesh) }
              )
              return result_def if _report_errors(reduction_output, result_def)
              reduced_envelope_meshes = (reduction_output['fragments'] || []).map { |fragment| _reduction_fragment_mesh(fragment) }
              unless reduced_envelope_meshes.empty?
                reduced_output = Meshy.operate(
                  :operation => Meshy::OPERATION_SUBTRACTION,
                  :validate => false,
                  :tolerance => SolidMeshDef::TOLERANCE,
                  :src_meshes => reduced_envelope_meshes,
                  :cut_meshes => welded_meshes
                )
                return result_def if _report_errors(reduced_output, result_def)
                open_fragment_defs = fn_collect.call(reduced_output, false)
              end
            end
          end

          result_def.fragment_defs.concat(open_fragment_defs)
        end
      end

      result_def
    end

    # -----

    private

    # Appends the given Meshy output errors (native exception or structured
    # per-mesh validation errors) to the result def as i18n tuples. Returns
    # true when the output carries errors.
    def _report_errors(output, result_def)
      if output['error']
        result_def.errors << [ 'core.error.exception', { :error => output['error'] } ]
      elsif output['errors'].is_a?(Array)
        output['errors'].each do |error|
          if error['count']
            result_def.errors << [ "core.solid.error.#{error['code']}", { :count => error['count'] } ]
          else
            result_def.errors << [ "core.solid.error.#{error['code']}" ]
          end
        end
      end
      !result_def.errors.empty?
    end

    # Axis aligned envelope box enclosing every cut mesh, inflated by
    # ENVELOPE_MARGIN, serialized to the mesh format expected by
    # Fiddle::Meshy.operate. Its 12 triangles all carry face id 0.
    def _envelope_bbox_mesh(cut_meshes)

      min = [ Float::INFINITY ] * 3
      max = [ -Float::INFINITY ] * 3
      cut_meshes.each do |mesh|
        mesh[:vertices].each_slice(3) do |point|
          3.times do |i|
            min[i] = point[i] if point[i] < min[i]
            max[i] = point[i] if point[i] > max[i]
          end
        end
      end

      x0, y0, z0 = min.map { |v| v - ENVELOPE_MARGIN }
      x1, y1, z1 = max.map { |v| v + ENVELOPE_MARGIN }

      _envelope_mesh_hash(
        [
          x0, y0, z0, x1, y0, z0, x1, y1, z0, x0, y1, z0,
          x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1
        ],
        [
          0, 2, 1, 0, 3, 2,
          4, 5, 6, 4, 6, 7,
          0, 1, 5, 0, 5, 4,
          2, 3, 7, 2, 7, 6,
          1, 2, 6, 1, 6, 5,
          3, 0, 4, 3, 4, 7
        ]
      )
    end

    # Convex hull of every cut mesh vertex, serialized to the mesh format
    # expected by Fiddle::Meshy.operate. Every triangle carries face id 0.
    # nil when the panels are degenerate (coplanar).
    def _envelope_hull_mesh(cut_meshes)

      points = []
      cut_meshes.each do |mesh|
        mesh[:vertices].each_slice(3) { |x, y, z| points << Geom::Point3d.new(x, y, z) }
      end

      triangles = Geometrix::HullFinder.find_convex_hull_triangle_indices(points)
      return nil if triangles.nil?

      # Compact : only the hull vertices are sent
      vertices = []
      indices_map = {}
      face_indices = triangles.flatten.map { |index|
        indices_map[index] ||= begin
          point = points[index]
          # to_f : Point3d coordinates are Lengths, which do not serialize as
          # JSON numbers
          vertices << point.x.to_f << point.y.to_f << point.z.to_f
          vertices.length / 3 - 1
        end
      }

      _envelope_mesh_hash(vertices, face_indices)
    end

    def _envelope_mesh_hash(vertices, face_indices)
      {
        :vertices => vertices,
        :face_indices => face_indices,
        :face_ids => Array.new(face_indices.length / 3, 0),
        :num_vertices => vertices.length / 3,
        :num_faces => face_indices.length / 3,
        :tolerance => SolidMeshDef::TOLERANCE
      }
    end

    # [ volume, total surface area, envelope (face id 0) surface area ] of the
    # given fragment, in one pass over its triangles. The envelope area drives
    # the openness (0.0 for a hermetically closed cavity, the opening ratio
    # for an open one), the volume / area ratio the sheet residue filter.
    def _measure(fragment)
      vertices = fragment['vertices']
      face_ids = fragment['face_ids']
      volume = 0.0
      envelope_area = 0.0
      total_area = 0.0
      fragment['face_indices'].each_slice(3).with_index do |(a, b, c), triangle_index|
        ax, ay, az = vertices[a * 3], vertices[a * 3 + 1], vertices[a * 3 + 2]
        bx, by, bz = vertices[b * 3], vertices[b * 3 + 1], vertices[b * 3 + 2]
        cx, cy, cz = vertices[c * 3], vertices[c * 3 + 1], vertices[c * 3 + 2]
        volume += (ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)) / 6.0
        ux = bx - ax ; uy = by - ay ; uz = bz - az
        vx = cx - ax ; vy = cy - ay ; vz = cz - az
        nx = uy * vz - uz * vy
        ny = uz * vx - ux * vz
        nz = ux * vy - uy * vx
        area = Math.sqrt(nx * nx + ny * ny + nz * nz) / 2.0
        total_area += area
        envelope_area += area if face_ids[triangle_index] == 0
      end
      [ volume.abs, total_area, envelope_area ]
    end

    # Indices of the panel drawing defs whose faces appear in the given
    # fragment face ids : the panels bounding the cavity.
    def _panel_indices(face_ids, panel_id_ranges)
      face_ids.uniq.map { |face_id|
        entry = panel_id_ranges.find { |id_range, _| id_range.cover?(face_id) }
        entry.nil? ? nil : entry.last
      }.compact.uniq.sort
    end

    # Area-weighted dominant face normal of each panel mesh ([ x, y, z ] unit
    # vector, or nil when degenerate), used to tell a panel edge (chant) face
    # from a main face. The two main faces of a board are opposite : normals
    # are accumulated up to sign.
    def _panel_dominant_normals(panel_meshes)
      panel_meshes.map do |mesh|
        vertices = mesh[:vertices]
        area_by_direction = Hash.new(0.0)
        mesh[:face_indices].each_slice(3) do |a, b, c|
          normal, area2 = _triangle_normal(vertices, a, b, c)
          next if normal.nil?
          normal = normal.map { |v| -v } if normal[0] < 0 || (normal[0] == 0 && (normal[1] < 0 || (normal[1] == 0 && normal[2] < 0)))
          key = normal.map { |v| (v * 1000).round }
          area_by_direction[key] += area2
        end
        max_entry = area_by_direction.max_by { |_, area2| area2 }
        key = max_entry.nil? ? nil : max_entry.first
        key.nil? ? nil : key.map { |v| v / 1000.0 }
      end
    end

    # Unit normal ([ x, y, z ]) and doubled area of the given triangle, nil
    # normal when degenerate.
    def _triangle_normal(vertices, a, b, c)
      ax, ay, az = vertices[a * 3], vertices[a * 3 + 1], vertices[a * 3 + 2]
      bx, by, bz = vertices[b * 3], vertices[b * 3 + 1], vertices[b * 3 + 2]
      cx, cy, cz = vertices[c * 3], vertices[c * 3 + 1], vertices[c * 3 + 2]
      ux = bx - ax ; uy = by - ay ; uz = bz - az
      vx = cx - ax ; vy = cy - ay ; vz = cz - az
      nx = uy * vz - uz * vy
      ny = uz * vx - ux * vz
      nz = ux * vy - uy * vx
      length = Math.sqrt(nx * nx + ny * ny + nz * nz)
      return [ nil, 0.0 ] if length == 0
      [ [ nx / length, ny / length, nz / length ], length ]
    end

    # Planes of the recessed panel edges bounding the given open cavities :
    # each is a chant plane (fragment boundary face NOT on its panel dominant
    # plane) that, extended, crosses the cavity interior with envelope cap
    # area beyond it. Returns [ [ normal, d ], ... ] where the normal (unit
    # [ x, y, z ], n.p = d on the plane) points toward the KEPT side — a
    # cavity face lies on the panel, so its outward normal points into it.
    def _detect_reduction_planes(fragment_defs, panel_id_ranges, panel_meshes, dominant_normals, envelope_mesh)
      planes = {}
      fragment_defs.each do |fragment_def|
        vertices = fragment_def.vertices
        face_ids = fragment_def.face_ids
        next if face_ids.nil?

        # Chant plane candidates of this fragment, and the plane offsets (in
        # each panel's own dominant axis) where that same panel bounds the
        # cavity on a MAIN face — front and back, when both are exposed
        main_plane_keys_by_panel = Hash.new { |h, k| h[k] = {} }
        triangle_mesh_position = {}
        candidates = {}
        fragment_def.face_indices.each_slice(3).with_index do |(a, b, c), triangle_index|
          face_id = face_ids[triangle_index]
          next if face_id == 0
          mesh_position = panel_id_ranges.find_index { |id_range, _| id_range.cover?(face_id) }
          next if mesh_position.nil?
          dominant_normal = dominant_normals[mesh_position]
          next if dominant_normal.nil?
          normal, area2 = _triangle_normal(vertices, a, b, c)
          next if normal.nil?
          dot = normal[0] * dominant_normal[0] + normal[1] * dominant_normal[1] + normal[2] * dominant_normal[2]
          if dot.abs >= REDUCTION_EDGE_DOT  # Main face plane, not a chant
            ax, ay, az = vertices[a * 3], vertices[a * 3 + 1], vertices[a * 3 + 2]
            offset = dominant_normal[0] * ax + dominant_normal[1] * ay + dominant_normal[2] * az
            main_plane_keys_by_panel[mesh_position][(offset / SolidMeshDef::TOLERANCE).round] = true
            next
          end
          d = normal[0] * vertices[a * 3] + normal[1] * vertices[a * 3 + 1] + normal[2] * vertices[a * 3 + 2]
          key = normal.map { |v| (v * 1000).round } << (d / SolidMeshDef::TOLERANCE).round
          candidate = candidates[key] ||= [ normal, d, 0.0, [] ]
          candidate[2] += area2 / 2.0
          candidate[3] << triangle_index
          triangle_mesh_position[triangle_index] = mesh_position
        end

        candidates.each do |key, (normal, d, area, triangle_indices)|
          next if planes.key?(key)
          # Degenerate boolean sliver, not a chant strip — see
          # REDUCTION_MIN_AREA
          next if area < REDUCTION_MIN_AREA
          # The cavity must extend on both sides of the extended plane —
          # beyond the chant (removed side, negative distances) and behind
          # it (kept side, where the panel and the compartments lie)
          beyond = false
          behind = false
          vertices.each_slice(3) do |x, y, z|
            distance = normal[0] * x + normal[1] * y + normal[2] * z - d
            beyond ||= distance < -REDUCTION_MIN_DEPTH
            behind ||= distance > REDUCTION_MIN_DEPTH
            break if beyond && behind
          end
          next unless beyond && behind
          # The removed side must carry envelope cap area : that is what
          # makes the crossing an opening recess rather than an interior
          # feature of the assembly
          cap_beyond = fragment_def.face_indices.each_slice(3).with_index.any? { |(a, b, c), triangle_index|
            next false unless face_ids[triangle_index] == 0
            x = (vertices[a * 3] + vertices[b * 3] + vertices[c * 3]) / 3.0
            y = (vertices[a * 3 + 1] + vertices[b * 3 + 1] + vertices[c * 3 + 1]) / 3.0
            z = (vertices[a * 3 + 2] + vertices[b * 3 + 2] + vertices[c * 3 + 2]) / 3.0
            normal[0] * x + normal[1] * y + normal[2] * z - d < -REDUCTION_MIN_DEPTH
          }
          next unless cap_beyond
          # Several panels merely lying on the same (normal, d) plane can be
          # pure coincidence (e.g. a large contour panel and an unrelated
          # divider's free tip that happen to sit at the same depth) : a
          # numeric match alone is not proof they belong to the same recess.
          # Physical CONTACT is — see #_reduction_group_components. Only ONE
          # touching sub-group needs to hold up on its own for the whole
          # plane to be trusted (the eventual clip still applies to the full
          # cross-section, unchanged — this only decides whether to trust
          # the plane at all).
          accepted = _reduction_group_components(triangle_indices, fragment_def).any? { |component|
            mesh_positions = component.map { |triangle_index| triangle_mesh_position[triangle_index] }.uniq
            # A genuine recessed panel (e.g. a shallow shelf) is exposed to
            # the cavity on BOTH its main faces — front and back, the two
            # compartments it separates ; a contour panel (side, top,
            # bottom...) can never satisfy that on its own (its other main
            # face faces outward, not another cavity). It is trusted
            # instead when SEVERAL DISTINCT, TOUCHING panels share this
            # exact plane (e.g. a shelf recessed together with the case's
            # own top/bottom) ; or, failing that, when its pocket stays
            # confined within the group's own silhouette — see
            # #_reduction_pocket_confined?. Failing all three, this
            # sub-group's chant is exposed by a concave/notched footprint,
            # not a recess : reducing the envelope there would clip away
            # the real cavity instead of splitting it.
            both_main_faces = mesh_positions.any? { |mesh_position| main_plane_keys_by_panel[mesh_position].size >= 2 }
            shared_by_group = mesh_positions.length >= 2
            next false unless both_main_faces || shared_by_group || _reduction_pocket_confined?(normal, d, fragment_def, envelope_mesh)
            # A SIDE face (e.g. a shelf's recessed front edge, running the
            # panel's full length) genuinely represents the depth every
            # element in the touching group recedes to. An END face (e.g.
            # an L-shaped divider's free tip, where the board simply stops)
            # has no such role : the real panels already separate the
            # compartments wherever the board actually is, and beyond its
            # tip nothing justifies a cut — extending its plane would clip
            # an unrelated part of the assembly it merely happens to cross
            # — see #_reduction_side_plane?. Tested on the sub-group's
            # MERGED footprint (safe now that touching, not mere plane
            # coincidence, backs the grouping) so a short member (e.g. a
            # mullion shorter than the case is deep, in a non-rectangular
            # assembly) is judged alongside what it actually connects to,
            # not on its own possibly-misleading aspect ratio.
            merged_mesh = { :vertices => mesh_positions.flat_map { |mesh_position| panel_meshes[mesh_position][:vertices] } }
            _reduction_side_plane?(normal, merged_mesh)
          }
          next unless accepted
          planes[key] = [ normal, d ]
        end

      end
      planes.values
    end

    # Splits the given candidate plane's chant triangles into groups that
    # physically TOUCH each other (share a vertex, transitively) rather than
    # merely lying on the same (normal, d) plane — which can also happen by
    # pure coincidence between panels that have nothing to do with each
    # other (e.g. a large contour panel and an unrelated divider's free tip
    # landing on the same depth). Vertex-sharing, not full edge-sharing : the
    # two sides of a genuine joint are not guaranteed to be triangulated
    # identically, so requiring a shared edge would be too strict. See
    # #_detect_reduction_planes.
    def _reduction_group_components(triangle_indices, fragment_def)
      vertices = fragment_def.vertices
      face_indices = fragment_def.face_indices

      parent = {}
      find = lambda { |i| parent[i] = find.call(parent[i]) unless parent[i] == i ; parent[i] }
      union = lambda { |i, j| pi, pj = find.call(i), find.call(j) ; parent[pi] = pj if pi != pj }
      triangle_indices.each { |triangle_index| parent[triangle_index] = triangle_index }

      triangles_by_vertex = Hash.new { |h, k| h[k] = [] }
      triangle_indices.each do |triangle_index|
        a, b, c = face_indices[triangle_index * 3, 3]
        [ a, b, c ].each do |vertex_index|
          vertex_key = [ vertices[vertex_index * 3], vertices[vertex_index * 3 + 1], vertices[vertex_index * 3 + 2] ].map { |v| (v / SolidMeshDef::TOLERANCE).round }
          triangles_by_vertex[vertex_key].each { |other| union.call(triangle_index, other) }
          triangles_by_vertex[vertex_key] << triangle_index
        end
      end

      triangle_indices.group_by { |triangle_index| find.call(triangle_index) }.values
    end

    # True when the given candidate plane's REMOVED pocket (the beyond-side
    # envelope cap area a reduction there would carve out) stays clear of
    # the group's own (u, v) silhouette (the envelope's own extent
    # perpendicular to the candidate normal) — walled in by other panels on
    # its lateral sides rather than reaching the envelope's outer edge.
    # Reaching that edge means the "recess" is actually the assembly's true
    # boundary there (a concave/notched footprint, open to the exterior),
    # not a step the whole group recedes to together. This is a cheap
    # bounding-box proxy, not an exact polygon containment test : for a
    # non-rectangular (e.g. L-shaped) envelope, a pocket could stay within
    # the overall bbox without being walled on its full perimeter — an
    # acceptable trade-off given how close to rectangular real cabinets are
    # in practice (see the class doc, ENVELOPE REDUCTION).
    def _reduction_pocket_confined?(normal, d, fragment_def, envelope_mesh)
      u, v = _reduction_plane_basis(normal)

      envelope_u0, envelope_u1 = _mesh_extent(envelope_mesh, u)
      envelope_v0, envelope_v1 = _mesh_extent(envelope_mesh, v)

      vertices = fragment_def.vertices
      face_ids = fragment_def.face_ids
      cap_u0 = cap_v0 = Float::INFINITY
      cap_u1 = cap_v1 = -Float::INFINITY
      fragment_def.face_indices.each_slice(3).with_index do |(a, b, c), triangle_index|
        next unless face_ids[triangle_index] == 0
        [ a, b, c ].each do |vertex_index|
          x, y, z = vertices[vertex_index * 3], vertices[vertex_index * 3 + 1], vertices[vertex_index * 3 + 2]
          next unless normal[0] * x + normal[1] * y + normal[2] * z - d < -REDUCTION_MIN_DEPTH
          pu = u[0] * x + u[1] * y + u[2] * z
          pv = v[0] * x + v[1] * y + v[2] * z
          cap_u0 = pu if pu < cap_u0 ; cap_u1 = pu if pu > cap_u1
          cap_v0 = pv if pv < cap_v0 ; cap_v1 = pv if pv > cap_v1
        end
      end
      return false if cap_u0 > cap_u1  # No beyond-side cap vertex at all

      cap_u0 >= envelope_u0 + REDUCTION_MIN_DEPTH && cap_u1 <= envelope_u1 - REDUCTION_MIN_DEPTH &&
        cap_v0 >= envelope_v0 + REDUCTION_MIN_DEPTH && cap_v1 <= envelope_v1 - REDUCTION_MIN_DEPTH
    end

    # Orthonormal basis [ u, v ] completing the given unit normal, seeded on
    # the axis the normal is least aligned with.
    def _reduction_plane_basis(normal)
      seed = [ [ 1.0, 0.0, 0.0 ], [ 0.0, 1.0, 0.0 ], [ 0.0, 0.0, 1.0 ] ][normal.map(&:abs).each_with_index.min.last]
      u = [
        normal[1] * seed[2] - normal[2] * seed[1],
        normal[2] * seed[0] - normal[0] * seed[2],
        normal[0] * seed[1] - normal[1] * seed[0]
      ]
      length = Math.sqrt(u[0] * u[0] + u[1] * u[1] + u[2] * u[2])
      u = u.map { |v| v / length }
      v = [
        normal[1] * u[2] - normal[2] * u[1],
        normal[2] * u[0] - normal[0] * u[2],
        normal[0] * u[1] - normal[1] * u[0]
      ]
      [ u, v ]
    end

    # [ min, max ] of the given mesh's vertices projected on the given axis.
    def _mesh_extent(mesh, axis)
      min = Float::INFINITY
      max = -Float::INFINITY
      mesh[:vertices].each_slice(3) do |x, y, z|
        p = axis[0] * x + axis[1] * y + axis[2] * z
        min = p if p < min
        max = p if p > max
      end
      [ min, max ]
    end

    # A rectangular board has, besides its thickness (dominant normal), a
    # LENGTH and a WIDTH — its two other real dimensions, unequal in
    # practice. Its non-main (chant) faces are either an END (perpendicular
    # to the length, at one of its two ends) or a SIDE (perpendicular to the
    # width, running the board's full length) — told apart by comparing the
    # panel's own extent along the given plane normal (large for an END, it
    # runs the board's length) to its extent along the plane's other in-plane
    # axis (large for a SIDE, the board's length lying IN the plane there).
    # See the class doc (ENVELOPE REDUCTION) for why the distinction matters.
    def _reduction_side_plane?(normal, panel_mesh)
      u, v = _reduction_plane_basis(normal)
      pn0, pn1 = _mesh_extent(panel_mesh, normal)
      pu0, pu1 = _mesh_extent(panel_mesh, u)
      pv0, pv1 = _mesh_extent(panel_mesh, v)
      (pn1 - pn0) <= [ pu1 - pu0, pv1 - pv0 ].max
    end

    # Box covering the envelope on the KEPT side of the given plane (unit
    # normal, n.p = d), serialized like the envelope meshes (face id 0) :
    # intersecting the envelope with these boxes clips it at the recessed
    # panel edges. Unbounded in the plane (full envelope extent) : only SIDE
    # planes reach here (see #_reduction_side_plane?), and the whole
    # connected group must recede together.
    def _reduction_slab_mesh(normal, d, envelope_mesh)

      u, v = _reduction_plane_basis(normal)

      # Envelope extent in that basis, inflated clear of the envelope planes
      u0, u1 = _mesh_extent(envelope_mesh, u)
      v0, v1 = _mesh_extent(envelope_mesh, v)
      _, n1 = _mesh_extent(envelope_mesh, normal)
      u0 -= ENVELOPE_MARGIN ; u1 += ENVELOPE_MARGIN
      v0 -= ENVELOPE_MARGIN ; v1 += ENVELOPE_MARGIN
      n1 += ENVELOPE_MARGIN

      vertices = []
      [ [ u0, v0, d ], [ u1, v0, d ], [ u1, v1, d ], [ u0, v1, d ],
        [ u0, v0, n1 ], [ u1, v0, n1 ], [ u1, v1, n1 ], [ u0, v1, n1 ] ].each do |pu, pv, pn|
        vertices << u[0] * pu + v[0] * pv + normal[0] * pn
        vertices << u[1] * pu + v[1] * pv + normal[1] * pn
        vertices << u[2] * pu + v[2] * pv + normal[2] * pn
      end

      _envelope_mesh_hash(
        vertices,
        [
          0, 2, 1, 0, 3, 2,
          4, 5, 6, 4, 6, 7,
          0, 1, 5, 0, 5, 4,
          2, 3, 7, 2, 7, 6,
          1, 2, 6, 1, 6, 5,
          3, 0, 4, 3, 4, 7
        ]
      )
    end

    # Meshy fragment, serialized back to the mesh format expected by
    # Fiddle::Meshy.operate (e.g. to feed a fragment of one operation as an
    # operand of the next).
    def _reduction_fragment_mesh(fragment)
      {
        :vertices => fragment['vertices'],
        :face_indices => fragment['face_indices'],
        :face_ids => fragment['face_ids'],
        :tolerance => SolidMeshDef::TOLERANCE
      }
    end

  end

end
