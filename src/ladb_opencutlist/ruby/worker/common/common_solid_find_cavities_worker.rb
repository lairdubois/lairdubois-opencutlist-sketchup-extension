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
  #   panels, eroded by a hair so that no hull face ends up coplanar with the
  #   panel faces it was built on (see ENVELOPE_HULL_EROSION). The hull caps
  #   the openings flush with the panel edges, so the cavities of an OPEN
  #   enclosure (e.g. a cabinet without its front) are found too, closed by
  #   the caps. Open candidates are told apart by the
  #   STRUCTURE of their caps : a real compartment opens on at most
  #   max_opening_planes DOMINANT cap planes (1 for an open front, 2 for a
  #   through tube — see SolidCavityFragmentDef#opening_plane_count), while
  #   the outside world and the concavity pockets a NON-convex assembly
  #   leaves between itself and its hull face the envelope on many comparable
  #   planes and are filtered out. A cap structure alone does not always tell
  #   them apart, though — a notched cabinet's L-shaped cavity and the pocket
  #   its notch leaves OUTSIDE score the same on the caps — so a candidate
  #   must also be ENCLOSED : walled on two opposing sides, which a
  #   compartment is by definition and a pocket wrapping a corner is not (see
  #   SolidCavityFragmentDef#walled_on_facing_planes?). max_openness — the
  #   maximum fraction of the candidate surface lying on the caps — remains as
  #   an optional secondary cap (disabled by default).
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
  # ratio.
  #
  # That shape test is only a PROXY, though, for the question that actually
  # decides : does this chant make an OPENING recede, or does it cut ACROSS
  # the cavity ? Every candidate must answer the first — its plane has to be
  # antiparallel to one of the cavity's own DOMINANT openings, that opening
  # lying beyond it (see #_reduction_recedes_opening?) — and that is what a
  # recess IS, whatever the board's proportions. It admits the divider set
  # back from the front of a case deeper than it is high, whose recessed
  # chant is perpendicular to its own longest dimension and which the shape
  # test reads as an END ; and it rejects the lateral tip of a stub shelf,
  # which the shape test reads as a SIDE as soon as the board is deeper than
  # it is long, and whose plane would amputate everything beside the shelf
  # instead of receding anything. The shape test then only has to arbitrate
  # the weaker group- and pocket-based evidence, where the concave/notched
  # footprint family lives : the panel bounding the cavity on BOTH main
  # faces has already demonstrated it separates two compartments, and needs
  # no proxy on top.
  #
  # Each cavity is then clipped at the remaining planes IT exposed (keeping
  # the panel side) : its caps recede to the recessed panel edge — the whole
  # connected group is reduced to the depth of its shallowest element — and
  # each compartment comes out as its own cavity.
  #
  # The clip is applied to the CAVITY, not to the shared envelope : a recessed
  # panel is evidence about the cavity whose openings it bounds, and about no
  # other. Reducing the envelope instead let a plane found in one compartment
  # eat into every other compartment it happened to cross — a shelf recessed
  # on one side of a divider stealing that depth from the cabinet's other
  # side, which borders no recessed panel at all. Clipping the cavity yields
  # the same volume — (reduced envelope − panels) restricted to that connected
  # component — with the blast radius the evidence actually supports, and the
  # sub-compartments a clip splits off simply come out as the fragments of
  # that operation.
  #
  # A cavity is clipped at ONE plane per round, the LEAST receding one, and
  # what the clip leaves goes back through the detection until no plane is
  # found (REDUCTION_MAX_PASSES). Recesses of different depths regularly live
  # in the SAME cavity — a case whose divider is recessed 50 mm, carrying a
  # shelf recessed 100 mm on one side only, is a single cavity, since the
  # space in front of the divider joins its two sides — and a clip is
  # unbounded in its own plane, so applying both at once would recede the
  # shelf-free side to 100 too. The shallowest recess is precisely the one
  # that PARTITIONS : cutting at 50 splits the two sides apart, and the 100
  # plane is then found on the side that actually carries the shelf.
  #
  # BEVELED EDGES (hull mode, reduce_envelope option) : an edge PROFILED at
  # an angle — a mitred front, a chamfer, a moulding — leaves the cavity
  # FLARING outward over the profile's depth : the hull caps the opening on
  # the panels' outermost points, and the profile faces themselves become the
  # walls of a funnel that has nothing to do with the usable volume (a part
  # drawn in there grows wings into it). Such a face is betrayed by its TILT :
  # it is neither the panel's main face nor perpendicular to it — see
  # REDUCTION_MAIN_DOT / REDUCTION_EDGE_DOT. A genuinely slanted panel (a
  # lectern's front) is not caught, since the slant IS its own dominant
  # normal. Each opening is then receded to the FOOT of the bevels flaring
  # toward it (the deepest point where the flare starts, i.e. the last full
  # cross section), by a plane perpendicular to that cap, clipping the cavity
  # exactly like a recessed chant does — see #_detect_bevel_planes.
  # A profile with RIGHT angles (rebate, shoulder) exposes a plain chant
  # instead, already handled by the recess detection above.
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

    # Hull envelope erosion, in inches. A hull face is very often EXACTLY
    # coplanar with the panel faces it was built on — a flush back, a flat
    # side, any convex part of the assembly. The subtraction then traps a
    # wafer-thin sheet of "cavity" between the two, spread over the whole
    # panel ring, which the cavity carries along as a flange (and which no
    # smaller offset would cure : Meshy canonicalizes planes within the mesh
    # tolerance, snapping them back together). Pulling every hull face just
    # past that tolerance puts the envelope boundary strictly INSIDE the
    # panel material there, so the ring is subtracted away for good — see
    # #_erode_hull_vertices. Measured on a mitred case (a flush back, hull
    # face exactly on the panel ends), the flange survives every erosion
    # below one TOLERANCE and disappears from one TOLERANCE on — the
    # canonicalization threshold — so the factor keeps a margin above it
    # rather than sitting on that discontinuity. The openings' caps recede by
    # the same amount in exchange, a few hundredths of a millimetre.
    ENVELOPE_HULL_EROSION = SolidMeshDef::TOLERANCE * 1.5

    # Below this, the Gram determinant of the planes a vertex is being put
    # back on is treated as singular — their normals are too close to tell
    # apart, and the exact combination would blow up on the noise between
    # them. See #_restore_plane_offset.
    RESTORE_MIN_DETERMINANT = 1.0e-6

    # Safety bound on the reduction rounds : a cavity is clipped at ONE plane
    # per round and what survives goes back through the detection, so an
    # assembly needs as many rounds as it nests recesses (a case whose divider
    # is recessed, holding a shelf recessed deeper still, takes two) plus a
    # last one to find nothing. Nesting that deep is not a thing in furniture,
    # and each round can only shrink a cavity, so this merely caps a
    # pathological input.
    REDUCTION_MAX_PASSES = 8

    # Clip plane erosion, in inches : how far past the detected plane the
    # cavity is actually cut, toward the KEPT side. A reduction plane is read
    # off the cavity's own faces, so it is EXACTLY coplanar with the chant (or
    # the bevel foot) that produced it. Cutting right there leaves the chant
    # face on the cut plane, facing the clip box's own face, and the boolean
    # keeps that stand-off as a zero-volume flap hanging off the reduced
    # cavity — the same coplanarity trap ENVELOPE_HULL_EROSION cures on the
    # hull, and it stays out of the volume but pollutes the cavity bounds.
    # Cutting a hair deeper puts the chant strictly on the removed side. The
    # compartment loses that hair of depth in exchange, a few hundredths of a
    # millimetre.
    REDUCTION_CLIP_EROSION = SolidMeshDef::TOLERANCE * 1.5

    # A cavity boundary face is an edge (chant) face of its panel when its
    # normal departs from the panel dominant normal by more than 60°, and a
    # main face when it departs by less than about 14°. In between, it is a
    # BEVELED edge — still an edge of the board, but tilted (mitred front,
    # chamfer, moulding facet) : see the class doc, BEVELED EDGES. Only the
    # band that used to be read as a main face is diverted there : what
    # already qualified as a chant keeps going down the recess path, where a
    # bevel too shallow to leave that band is rejected anyway (a contour
    # panel exposes a single main face to the cavity).
    REDUCTION_EDGE_DOT = 0.5
    REDUCTION_MAIN_DOT = 0.97

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

    # Maximum dot product between a reduction plane's normal and an opening
    # cap's normal for that plane to be read as RECEDING that opening : the
    # two must be ANTIPARALLEL — a cap normal points out of the cavity, a
    # reduction normal toward the kept side — within about 8°. A recess read
    # against a SLANTED opening (a lectern's front, any non-flush hull cap)
    # falls outside the band and is not reduced at all : an assembly whose
    # opening is not flat gives no plane to recede it to.
    # See #_reduction_recedes_opening?.
    REDUCTION_OPENING_DOT = -0.99

    # Minimum share of a cavity's total cap area for one cap plane to be
    # treated as an OPENING a beveled edge may recede. A cavity leaking
    # through an incidental hole — two edge profiles that do not mitre into
    # each other leave one at every corner — faces the envelope there on a
    # few square millimetres, orders of magnitude below its real openings ;
    # letting such a facet recede would clip the envelope on a plane the
    # assembly never justified, since the clip applies to the whole cross
    # section. Same spirit as SolidCavityFragmentDef#opening_plane_count,
    # which reads the openings off the DOMINANT cap planes.
    REDUCTION_BEVEL_CAP_RATIO = 0.05

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
      @envelope_restore_planes = []

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
          # Enclosure filter : a compartment is walled on two opposing sides,
          # a concavity pocket only wraps a corner of the assembly — see
          # SolidCavityFragmentDef#walled_on_facing_planes?
          next if !hermetic && !fragment_def.walled_on_facing_planes?
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
          # Only the open cavities need it : a hermetic one is bounded by
          # panels alone, it never touches the hull
          _restore_envelope_vertices(welded_output['fragments'])
          open_fragment_defs = fn_collect.call(welded_output, false)

          # Envelope reduction : the recessed panel edges detected on an open
          # cavity clip THAT cavity, shallowest recess first, the survivors
          # going back through the detection — see the class doc.
          if @reduce_envelope && !open_fragment_defs.empty?
            dominant_normals = _panel_dominant_normals(panel_meshes)
            REDUCTION_MAX_PASSES.times do
              reduction_planes_per_fragment = _detect_reduction_planes(open_fragment_defs, panel_id_ranges, panel_meshes, dominant_normals, envelope_mesh)
              reduced_fragment_defs = []
              clipped_any = false
              open_fragment_defs.each_with_index do |fragment_def, index|
                normal, d = _shallowest_reduction_plane(reduction_planes_per_fragment[index], fragment_def)
                if normal.nil?
                  reduced_fragment_defs << fragment_def
                  next
                end
                reduction_output = Meshy.operate(
                  :operation => Meshy::OPERATION_INTERSECTION,
                  :validate => false,
                  :tolerance => SolidMeshDef::TOLERANCE,
                  :src_meshes => [ _reduction_fragment_mesh(fragment_def) ],
                  :cut_meshes => [ _reduction_slab_mesh(normal, d, envelope_mesh) ]
                )
                return result_def if _report_errors(reduction_output, result_def)
                _restore_clipped_vertices(reduction_output['fragments'], normal, d)
                clipped = fn_collect.call(reduction_output, false)
                if clipped.empty?
                  # Nothing left of the cavity : the reduction has nothing to
                  # say here, keep it as it came out of the subtraction rather
                  # than losing it
                  reduced_fragment_defs << fragment_def
                else
                  # In place, so the cavity order stays the panel order the
                  # subtraction produced
                  reduced_fragment_defs.concat(clipped)
                  clipped_any = true
                end
              end
              open_fragment_defs = reduced_fragment_defs
              # A clip strictly shrinks its cavity and takes away the very
              # faces its plane was read from, so a round that clips nothing
              # is the fixed point
              break unless clipped_any
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

      eroded_vertices = _erode_hull_vertices(vertices, face_indices)
      @envelope_restore_planes = _envelope_restore_planes(vertices, eroded_vertices, face_indices)

      _envelope_mesh_hash(eroded_vertices, face_indices)
    end

    # [ normal, ERODED offset, ORIGINAL offset ] per distinct hull face, the
    # two offsets read on the same triangle before and after the erosion —
    # what #_restore_envelope_vertices needs to put a cavity's caps back where
    # the panels really end. Empty when the hull was not eroded.
    #
    # Both offsets share one normal : the erosion being a uniform scale, it
    # leaves every face parallel to itself.
    def _envelope_restore_planes(vertices, eroded_vertices, face_indices)
      return [] if eroded_vertices.equal?(vertices)

      planes = {}
      face_indices.each_slice(3) do |a, b, c|
        normal, _area2 = _triangle_normal(eroded_vertices, a, b, c)
        next if normal.nil?
        d_eroded = normal[0] * eroded_vertices[a * 3] + normal[1] * eroded_vertices[a * 3 + 1] + normal[2] * eroded_vertices[a * 3 + 2]
        key = normal.map { |v| (v * 1000).round } << (d_eroded / SolidMeshDef::TOLERANCE).round
        next if planes.key?(key)
        d_original = normal[0] * vertices[a * 3] + normal[1] * vertices[a * 3 + 1] + normal[2] * vertices[a * 3 + 2]
        planes[key] = [ normal, d_eroded, d_original ]
      end
      planes.values
    end

    # Pulls every face of the given hull (flat vertices, triangle indices)
    # inward by at least ENVELOPE_HULL_EROSION, by scaling its vertices
    # toward their centroid — which lies inside the hull, being a convex
    # combination of its own vertices. A uniform scale moves each face by an
    # offset proportional to ITS distance to the centroid, so the ratio is
    # set on the CLOSEST face : every face then recedes by at least the
    # erosion, the farthest ones by proportionally more (a few tenths of a
    # millimetre at worst, on an assembly far longer than it is wide).
    # Returned unchanged when the hull is too flat for the erosion to remain
    # a small perturbation — such an assembly encloses no cavity anyway.
    def _erode_hull_vertices(vertices, face_indices)
      count = vertices.length / 3
      return vertices if count == 0

      cx = cy = cz = 0.0
      vertices.each_slice(3) { |x, y, z| cx += x ; cy += y ; cz += z }
      cx /= count ; cy /= count ; cz /= count

      distance_min = Float::INFINITY
      face_indices.each_slice(3) do |a, b, c|
        normal, _area2 = _triangle_normal(vertices, a, b, c)
        next if normal.nil?
        distance = (normal[0] * (vertices[a * 3] - cx) + normal[1] * (vertices[a * 3 + 1] - cy) + normal[2] * (vertices[a * 3 + 2] - cz)).abs
        distance_min = distance if distance < distance_min
      end
      return vertices if distance_min == Float::INFINITY || distance_min < ENVELOPE_HULL_EROSION * 10

      ratio = 1.0 - ENVELOPE_HULL_EROSION / distance_min
      eroded = []
      vertices.each_slice(3) do |x, y, z|
        eroded << cx + (x - cx) * ratio << cy + (y - cy) * ratio << cz + (z - cz) * ratio
      end
      eroded
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
    # area beyond it. Returns ONE [ [ normal, d ], ... ] list PER given
    # fragment def, in the same order, where the normal (unit [ x, y, z ],
    # n.p = d on the plane) points toward the KEPT side — a cavity face lies
    # on the panel, so its outward normal points into it.
    #
    # The lists are kept apart on purpose : a plane is evidence about the
    # cavity that exposed it and about no other, so it only ever clips that
    # one — see the class doc, ENVELOPE REDUCTION.
    def _detect_reduction_planes(fragment_defs, panel_id_ranges, panel_meshes, dominant_normals, envelope_mesh)
      fragment_defs.map do |fragment_def|
        planes = {}
        vertices = fragment_def.vertices
        face_ids = fragment_def.face_ids
        next [] if face_ids.nil?

        # Chant plane candidates of this fragment, and the plane offsets (in
        # each panel's own dominant axis) where that same panel bounds the
        # cavity on a MAIN face — front and back, when both are exposed
        main_plane_keys_by_panel = Hash.new { |h, k| h[k] = {} }
        triangle_mesh_position = {}
        candidates = {}
        # The cavity's openings ([ normal, offset, area ] per envelope cap
        # plane) and the tilted edge faces flaring toward them
        # ([ triangle index, normal, area ]) — see #_detect_bevel_planes
        cap_planes = {}
        bevel_triangles = []
        fragment_def.face_indices.each_slice(3).with_index do |(a, b, c), triangle_index|
          face_id = face_ids[triangle_index]
          normal, area2 = _triangle_normal(vertices, a, b, c)
          next if normal.nil?
          if face_id == 0  # Envelope cap : an opening of the cavity
            d = normal[0] * vertices[a * 3] + normal[1] * vertices[a * 3 + 1] + normal[2] * vertices[a * 3 + 2]
            key = normal.map { |v| (v * 1000).round } << (d / SolidMeshDef::TOLERANCE).round
            cap_plane = cap_planes[key] ||= [ normal, d, 0.0 ]
            cap_plane[2] += area2 / 2.0
            next
          end
          mesh_position = panel_id_ranges.find_index { |id_range, _| id_range.cover?(face_id) }
          next if mesh_position.nil?
          dominant_normal = dominant_normals[mesh_position]
          next if dominant_normal.nil?
          dot = normal[0] * dominant_normal[0] + normal[1] * dominant_normal[1] + normal[2] * dominant_normal[2]
          if dot.abs >= REDUCTION_MAIN_DOT  # Main face plane, not an edge
            ax, ay, az = vertices[a * 3], vertices[a * 3 + 1], vertices[a * 3 + 2]
            offset = dominant_normal[0] * ax + dominant_normal[1] * ay + dominant_normal[2] * az
            main_plane_keys_by_panel[mesh_position][(offset / SolidMeshDef::TOLERANCE).round] = true
            next
          end
          if dot.abs >= REDUCTION_EDGE_DOT  # Beveled edge face
            # Deliberately NOT registered as a main plane above : a tilted
            # face spans a whole range of offsets on the panel's dominant
            # axis, so the single offset it would contribute is arbitrary —
            # two of them would fake the "bounds the cavity on both its main
            # faces" evidence a genuine recess must produce.
            bevel_triangles << [ triangle_index, normal, area2 / 2.0 ]
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
          # The plane must make one of the cavity's own OPENINGS recede : that
          # is what tells a recess from a chant that merely cuts ACROSS the
          # cavity (a stub shelf's lateral tip, where the board just ends and
          # nothing beyond it justifies a cut) — see
          # #_reduction_recedes_opening?
          next unless _reduction_recedes_opening?(normal, d, cap_planes)
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
            # not a recess : reducing there would clip away
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
            #
            # A shape test can only ever be a PROXY, though — it reads the
            # board's length off its own bounds, and a board deeper than it is
            # long has the two swapped. The panel that bounds the cavity on
            # BOTH main faces needs none of it : it demonstrably separates two
            # compartments, and the plane demonstrably recedes an opening
            # (checked above), which is the whole definition of a recess. The
            # shape test stays as the last line of defence for the weaker
            # group- and pocket-based evidence, where the concave/notched
            # footprint family lives.
            merged_mesh = { :vertices => mesh_positions.flat_map { |mesh_position| panel_meshes[mesh_position][:vertices] } }
            both_main_faces || _reduction_side_plane?(normal, merged_mesh)
          }
          next unless accepted
          planes[key] = [ normal, d ]
        end

        # Beveled edges : each opening recedes to the foot of the bevels
        # flaring toward it — a criterion of its own, needing none of the
        # evidence collected above. Those guards tell a recess from a
        # concave/notched footprint, an ambiguity a flare simply does not
        # have : a wall that widens as it reaches an opening is a profiled
        # edge, whatever the assembly's footprint.
        _detect_bevel_planes(fragment_def, bevel_triangles, cap_planes).each do |normal, d|
          key = normal.map { |v| (v * 1000).round } << (d / SolidMeshDef::TOLERANCE).round
          planes[key] ||= [ normal, d ]
        end

        _merge_close_reduction_planes(planes.values)
      end
    end

    # The given planes with the parallel ones closer than REDUCTION_MIN_DEPTH
    # to each other merged into their DEEPEST member (the one keeping the
    # least).
    #
    # Such a pair never describes two different recesses : anything that close
    # is below the recess the detection is willing to act on at all. It does
    # happen, though — the parts of a cabinet are commonly drawn against the
    # cavities of the previous ones, and every cavity is receded by a hair
    # (ENVELOPE_HULL_EROSION, REDUCTION_CLIP_EROSION), so a whole level of
    # nesting can sit a few hundredths of a millimetre behind the one before
    # it. Keeping only the shallowest would then cut EXACTLY on the faces of
    # the other, leaving the boolean a zero-volume membrane over them — which
    # bridges whatever that panel was separating, and the compartments it
    # splits come back merged (the very thing the reduction is for). Keeping
    # the deepest puts the cut clear of every panel of the group.
    def _merge_close_reduction_planes(planes)
      merged = []
      planes.each do |normal, d|
        twin = merged.find { |other_normal, other_d|
          normal[0] * other_normal[0] + normal[1] * other_normal[1] + normal[2] * other_normal[2] > 0.9999 &&
            (d - other_d).abs < REDUCTION_MIN_DEPTH
        }
        if twin.nil?
          merged << [ normal, d ]
        elsif d > twin[1]
          twin[1] = d
        end
      end
      merged
    end

    # Moves the vertices the subtraction left on an ERODED hull face back onto
    # the hull face as it was BUILT, undoing ENVELOPE_HULL_EROSION on the
    # RESULT of the boolean — which has already run, and keeps all of the
    # clearance it needed. Same doctrine as #_restore_clipped_vertices, and
    # the same reason : a hull face passes exactly through the outermost panel
    # points, so an un-eroded cap is exactly where the panels end, and a part
    # drawn flush with the cavity gets the cabinet's true inner dimension
    # instead of one erosion less at each end.
    #
    # A vertex may sit on several hull faces at once — the corner where two
    # openings meet — and each of them wants it on its own restored plane :
    # the correction is the combination that satisfies them all, found by
    # solving the small system its normals make (see #_restore_plane_offset).
    def _restore_envelope_vertices(fragments)
      return if @envelope_restore_planes.nil? || @envelope_restore_planes.empty?
      return unless fragments.is_a?(Array)

      fragments.each do |fragment|
        vertices = fragment['vertices']
        next unless vertices.is_a?(Array)
        index = 0
        while index < vertices.length

          x = vertices[index] ; y = vertices[index + 1] ; z = vertices[index + 2]
          corrections = []
          @envelope_restore_planes.each do |normal, d_eroded, d_original|
            projection = normal[0] * x + normal[1] * y + normal[2] * z
            next if (projection - d_eroded).abs > SolidMeshDef::TOLERANCE
            corrections << [ normal, d_original - projection ]
            # A non degenerate corner meets three faces at most
            break if corrections.length == 3
          end

          unless corrections.empty?
            offset = _restore_plane_offset(corrections)
            vertices[index] += offset[0]
            vertices[index + 1] += offset[1]
            vertices[index + 2] += offset[2]
          end

          index += 3
        end
      end
    end

    # The smallest move putting a point back on all of the given restored
    # planes at once : +corrections+ is [ unit normal, distance still to
    # cover along it ], and the move is sought in the space the normals span
    # (any component orthogonal to them would move the point along the faces
    # for nothing). Solving the resulting Gram system by Cramer's rule.
    #
    # Near parallel normals make that system singular — two hull facets barely
    # tilted against each other. Their corrections then say nearly the same
    # thing, so the largest one alone is applied rather than a blown up
    # combination of both.
    def _restore_plane_offset(corrections)
      normals = corrections.map { |normal, _distance| normal }
      distances = corrections.map { |_normal, distance| distance }

      coefficients = case normals.length
                     when 1
                       distances
                     when 2
                       _restore_solve_2(normals, distances)
                     else
                       _restore_solve_3(normals, distances)
                     end
      if coefficients.nil?
        index = (0...distances.length).max_by { |i| distances[i].abs }
        coefficients = Array.new(distances.length, 0.0)
        coefficients[index] = distances[index]
      end

      offset = [ 0.0, 0.0, 0.0 ]
      normals.each_with_index do |normal, index|
        3.times { |axis| offset[axis] += coefficients[index] * normal[axis] }
      end
      offset
    end

    def _restore_solve_2(normals, distances)
      cosine = normals[0][0] * normals[1][0] + normals[0][1] * normals[1][1] + normals[0][2] * normals[1][2]
      determinant = 1.0 - cosine * cosine
      return nil if determinant.abs < RESTORE_MIN_DETERMINANT
      [
        (distances[0] - cosine * distances[1]) / determinant,
        (distances[1] - cosine * distances[0]) / determinant
      ]
    end

    def _restore_solve_3(normals, distances)
      gram = Array.new(3) { |i| Array.new(3) { |j| normals[i][0] * normals[j][0] + normals[i][1] * normals[j][1] + normals[i][2] * normals[j][2] } }
      determinant = _restore_determinant_3(gram)
      return nil if determinant.abs < RESTORE_MIN_DETERMINANT
      (0..2).map { |column|
        substituted = Array.new(3) { |i| Array.new(3) { |j| j == column ? distances[i] : gram[i][j] } }
        _restore_determinant_3(substituted) / determinant
      }
    end

    def _restore_determinant_3(m)
      m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
        m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
        m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
    end

    # Moves the vertices a clip left ON its plane back onto the plane that was
    # DETECTED, undoing REDUCTION_CLIP_EROSION on the RESULT of the boolean —
    # which has already run, and keeps every bit of the clearance it needed.
    #
    # The erosion is a numerical device, and it must not show in the cavity :
    # a cavity is what gets DRAWN in (see the Smart Draw separator tool), a
    # part drawn flush with it lands a hair behind the recess that justified
    # the clip, and its own edge is then a recess a hair deeper still. The
    # next clip has to clear THAT one, so it recedes by another erosion, and
    # every part drawn in the same compartment comes out a little smaller
    # than the one before — three shelves in a row, three sizes, and nothing
    # the user can do about it. Snapped back, a part drawn flush lands
    # exactly on the recess plane, its edge merges with it (see
    # #_merge_close_reduction_planes) and the next clip lands where the
    # previous one did.
    #
    # Vertices are moved along the plane normal, so a face perpendicular to
    # the clip - the walls of any compartment - simply gets that much longer.
    # A face meeting the clip at an angle (a bevelled edge) ends up bent by
    # the erosion, a few hundredths of a millimetre : below anything the
    # cavity is used for.
    def _restore_clipped_vertices(fragments, normal, d)
      return unless fragments.is_a?(Array)
      clip_d = d + REDUCTION_CLIP_EROSION
      fragments.each do |fragment|
        vertices = fragment['vertices']
        next unless vertices.is_a?(Array)
        index = 0
        while index < vertices.length
          distance = normal[0] * vertices[index] + normal[1] * vertices[index + 1] + normal[2] * vertices[index + 2] - clip_d
          if distance.abs <= SolidMeshDef::TOLERANCE
            vertices[index] -= normal[0] * REDUCTION_CLIP_EROSION
            vertices[index + 1] -= normal[1] * REDUCTION_CLIP_EROSION
            vertices[index + 2] -= normal[2] * REDUCTION_CLIP_EROSION
          end
          index += 3
        end
      end
    end

    # The LEAST receding of the given planes for the given cavity — the one
    # whose removed side is the thinnest slice of it — as [ normal, d ], or
    # nil when there is none.
    #
    # Only that one is applied, and the pieces it leaves are detected again :
    # the planes of one cavity are not necessarily about the same part of it,
    # and a clip is unbounded in its own plane (see #_reduction_slab_mesh), so
    # applying them together lets the deepest recess impose its depth on
    # compartments that never saw it — a case whose divider is recessed 50,
    # holding a shelf recessed 100 on one side only, is a single cavity (the
    # space in front of the divider joins both sides) exposing both planes,
    # and clipping it at both puts its far side at 100 too. Cutting at 50
    # first splits that side off, and the 100 plane is then found on the side
    # that actually carries the shelf — see the class doc.
    def _shallowest_reduction_plane(planes, fragment_def)
      return nil if planes.nil? || planes.empty?
      shallowest = nil
      shallowest_depth = nil
      planes.each do |normal, d|
        projection_min = nil
        fragment_def.vertices.each_slice(3) do |x, y, z|
          projection = normal[0] * x + normal[1] * y + normal[2] * z
          projection_min = projection if projection_min.nil? || projection < projection_min
        end
        next if projection_min.nil?
        depth = d - projection_min
        next unless shallowest_depth.nil? || depth < shallowest_depth
        shallowest = [ normal, d ]
        shallowest_depth = depth
      end
      shallowest
    end

    # Planes receding the OPENINGS of the given cavity to the FOOT of the
    # beveled edges flaring toward them — see the class doc, BEVELED EDGES.
    # Same [ [ normal, d ], ... ] contract as one entry of
    # #_detect_reduction_planes (the normal points toward the KEPT side), so
    # both feed the same cavity clipping.
    #
    # +bevel_triangles+ are the fragment's tilted edge faces
    # ([ triangle index, normal, area ]), +cap_planes+ its envelope cap
    # planes ([ normal, offset, area ], the normal pointing OUT of the
    # cavity). A bevel has a say on an opening when it FLARES toward it (the
    # cavity widens on the way out : the wall's outward normal leans back
    # inside) and REACHES it — an edge profile elsewhere in the cavity (a
    # chamfered shelf front, deep inside) says nothing about where that
    # opening is. The whole flare recedes to its deepest foot : a group is
    # only as usable as its most receded member, the same doctrine the
    # recessed chants follow.
    def _detect_bevel_planes(fragment_def, bevel_triangles, cap_planes)
      return [] if bevel_triangles.empty?

      vertices = fragment_def.vertices
      face_indices = fragment_def.face_indices

      fn_projection = lambda { |vertex_index, axis|
        axis[0] * vertices[vertex_index * 3] + axis[1] * vertices[vertex_index * 3 + 1] + axis[2] * vertices[vertex_index * 3 + 2]
      }

      total_cap_area = cap_planes.inject(0.0) { |sum, (_key, cap_plane)| sum + cap_plane[2] }
      return [] if total_cap_area <= 0

      planes = []
      cap_planes.each do |_key, (cap_normal, cap_d, cap_area)|
        # Hull facet residue or incidental leak, not an opening
        next if cap_area < REDUCTION_MIN_AREA || cap_area < total_cap_area * REDUCTION_BEVEL_CAP_RATIO

        areas = {}
        bevel_triangles.each do |triangle_index, normal, area|
          next unless normal[0] * cap_normal[0] + normal[1] * cap_normal[1] + normal[2] * cap_normal[2] < 0
          next unless face_indices[triangle_index * 3, 3].any? { |vertex_index| fn_projection.call(vertex_index, cap_normal) > cap_d - REDUCTION_MIN_DEPTH }
          areas[triangle_index] = area
        end
        next if areas.empty?

        # Where the flare starts, measured on the surviving TOUCHING groups
        # only : a boolean sliver — the degenerate triangle a panel face
        # flush with the hull leaves behind, whose normal is arbitrary and
        # whose provenance may put it anywhere — would otherwise drag the
        # foot to a depth nothing in the assembly justifies. Same
        # REDUCTION_MIN_AREA doctrine as the chant candidates : a real
        # profile strip runs the edge's full length, orders of magnitude
        # above.
        foot = Float::INFINITY
        _reduction_group_components(areas.keys, fragment_def).each do |component|
          next if component.inject(0.0) { |sum, triangle_index| sum + areas[triangle_index] } < REDUCTION_MIN_AREA
          component.each do |triangle_index|
            face_indices[triangle_index * 3, 3].each do |vertex_index|
              projection = fn_projection.call(vertex_index, cap_normal)
              foot = projection if projection < foot
            end
          end
        end
        next if foot == Float::INFINITY

        # Flush profile (or noise) : nothing to recede
        next if cap_d - foot < REDUCTION_MIN_DEPTH

        planes << [ cap_normal.map { |v| -v }, -foot ]
      end
      planes
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

    # Whether the given plane (unit normal pointing toward the KEPT side,
    # n.p = d) makes one of the cavity's own OPENINGS recede : a cap plane
    # (cap_planes, [ normal, offset, area ] per distinct plane) antiparallel
    # to it (REDUCTION_OPENING_DOT), lying on the REMOVED side, and weighing
    # at least REDUCTION_BEVEL_CAP_RATIO of the cavity's whole cap area.
    # Required of every reduction plane — see the class doc.
    #
    # This is what a recess IS — a panel set back BEHIND an opening — read
    # off the cavity itself rather than guessed from the panel's proportions,
    # which #_reduction_side_plane? can only do as long as a board is longer
    # along its opening than it is deep. It also subsumes the weaker test it
    # replaced (SOME cap area beyond the plane, whatever its orientation),
    # which a chant cutting across the cavity passes just by having the
    # cavity's real opening somewhere off to its side. The minor caps are
    # left out for the very reason #_detect_bevel_planes leaves them out : an
    # incidental leak faces the envelope on a few square millimetres and
    # would justify receding the whole cross section on a plane the assembly
    # never asked for.
    def _reduction_recedes_opening?(normal, d, cap_planes)
      total_area = cap_planes.values.reduce(0.0) { |sum, cap_plane| sum + cap_plane[2] }
      return false if total_area <= 0
      cap_planes.values.any? { |cap_normal, cap_d, area|
        next false if area / total_area < REDUCTION_BEVEL_CAP_RATIO
        dot = normal[0] * cap_normal[0] + normal[1] * cap_normal[1] + normal[2] * cap_normal[2]
        next false unless dot <= REDUCTION_OPENING_DOT
        # The normals being antiparallel, the cap's own offset reads -cap_d on
        # this plane's axis : the opening must sit beyond the plane, on the
        # side the clip removes
        -cap_d - d < -REDUCTION_MIN_DEPTH
      }
    end

    # Box covering the envelope on the KEPT side of the given plane (unit
    # normal, n.p = d), serialized like the envelope meshes (face id 0) :
    # intersecting a cavity with these boxes clips it at the recessed panel
    # edges, the new faces inheriting the cap id. Unbounded in the plane (full
    # envelope extent, so any cavity is covered) : only planes that represent
    # a group-wide depth reach here (see #_reduction_side_plane? /
    # #_reduction_recedes_opening?), and the whole connected group must recede
    # together.
    def _reduction_slab_mesh(normal, d, envelope_mesh)

      u, v = _reduction_plane_basis(normal)

      # Cut a hair inside the kept side, clear of the very face this plane was
      # read from — see REDUCTION_CLIP_EROSION
      d += REDUCTION_CLIP_EROSION

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

    # Cavity fragment, serialized back to the mesh format expected by
    # Fiddle::Meshy.operate, so the cavity of one operation can be an operand
    # of the next. Face ids are carried over : the clipped cavity still knows
    # which panel bounds it where, and the slabs it is cut by bring in id 0
    # (envelope cap) for the new faces, keeping #openness meaningful.
    def _reduction_fragment_mesh(fragment_def)
      {
        :vertices => fragment_def.vertices,
        :face_indices => fragment_def.face_indices,
        :face_ids => fragment_def.face_ids,
        :tolerance => SolidMeshDef::TOLERANCE
      }
    end

  end

end
