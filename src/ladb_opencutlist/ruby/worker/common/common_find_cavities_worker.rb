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
  # Panels may overlap each other freely (the boolean absorbs overlaps, no
  # exact joinery needed) and gaps below the SketchUp merge tolerance are
  # sealed by Meshy's plane canonicalization.
  #
  # Each cavity fragment carries the indices (in the panel drawing defs list)
  # of the panels whose faces bound it (SolidFragmentDef#src_indices).
  class CommonFindCavitiesWorker

    Meshy = Fiddle::Meshy

    ENVELOPE_HULL = 'hull'.freeze
    ENVELOPE_BBOX = 'bbox'.freeze

    # Bbox envelope inflation, in inches. Keeps the envelope planes well
    # clear of the panel planes, so that Meshy's plane canonicalization
    # (TOLERANCE scale) never merges an envelope face with a panel face.
    ENVELOPE_MARGIN = 1.0

    def initialize(panel_drawing_defs,

                   envelope: ENVELOPE_HULL,
                   max_opening_planes: 2,
                   max_openness: 1.0,
                   validate: true

    )

      @panel_drawing_defs = Array(panel_drawing_defs)

      @envelope = envelope
      @max_opening_planes = max_opening_planes
      @max_openness = max_openness
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
        next unless output['fragments'].is_a?(Array)
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
          result_def.fragment_defs << fragment_def
        end
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
      fn_collect.call(direct_output, true)

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
          fn_collect.call(welded_output, false)
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

  end

end
