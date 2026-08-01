module Ladb::OpenCutList

  require_relative '../../model/solid/solid_rebuild_result_def'

  # Rebuilds a solid from a CONSTRUCTION drawing : every closed coplanar loop
  # its construction lines (CLines) draw becomes a face, and the faces enclosing
  # the drawing are oriented OUTWARD.
  #
  # Writes to the model, transactionally (its own model.start_operation /
  # commit_operation, unless wrap_operation: false — then the caller is expected
  # to own an enclosing operation ; on failure the caller must check
  # result.success? and abort its own operation itself). Nothing is modified
  # when the run fails.
  #
  # Sources are CLines, or any container (Group / ComponentInstance / Entities /
  # Model) to collect them from, recursively. They are all read in ONE space —
  # the only way sources living in different containers can be arranged
  # together — reached by accumulating each container's transformation on the
  # way down, starting from source_transformation. That start is what says
  # where the sources themselves are : IDENTITY (the default) puts the
  # accumulation in the space the sources' OWN transformations are expressed
  # in, which is the world only when they sit at the model root — a nested
  # source needs its parent path's transformation passed here for the reading
  # to be a world one.
  #
  # The result lands in a new Group at the model root, or in the target_entities
  # the caller provides — with its own target_transformation (local to the
  # space above, i.e. its full path transformation when that space is the
  # world), so the segments come back to that context's local space.
  #
  # The geometry actually built is reported as result.faces / result.edges,
  # whichever of the two targets it landed in : the caller needs both to hold
  # on to it (faces to work with, edges to erase it by, since erasing an edge
  # takes its faces with it).
  #
  # The loop finding itself is NOT reimplemented : Sketchup::Edge#find_faces is
  # the very engine SketchUp uses when you close a contour by hand, and it
  # already groups coplanar edges and walks their minimal cycles. What it needs
  # is a clean edge arrangement to work on, and what it leaves behind needs
  # sorting out — that is what this worker is about :
  #
  # - INFINITE CLINES (infinite: mode). A CLine drawn "to infinity" carries no
  #   endpoint (Sketchup::ConstructionLine#start / #end are nil), and a
  #   half-infinite one only carries the one it starts at. Such a line is
  #   clipped to the bounds of the FINITE drawing — no geometry lives outside
  #   them, so nothing a loop could use is lost — and the overhang it leaves
  #   past the real corners is a face less edge, removed by the pruning below.
  #
  # - CROSSINGS (see #_split_segments). SketchUp merges new geometry with what
  #   is already in the context, but only where a VERTEX is involved : a
  #   duplicate edge is absorbed, a collinear overlap is split at the shared
  #   ends, an endpoint landing on an edge splits it (a T junction) — and two
  #   edges CROSSING transversally (an X) are left intersecting with no vertex
  #   between them, so no loop closes there. Every transversal crossing is
  #   therefore computed and split up front. Two segments whose closest
  #   approach is below the tolerance count as crossing, and both are split at
  #   the MIDPOINT of that approach, so the two new vertices coincide exactly
  #   and SketchUp welds them. Parallel and collinear pairs are skipped : they
  #   are the cases SketchUp already handles, and their "intersection" is
  #   degenerate.
  #
  # - INTERIOR FACES (keep_inner_faces). #find_faces creates EVERY planar loop
  #   it can, not just the ones bounding the volume : a CLine crossing the
  #   inside of the drawing (a diagonal, a brace, the divider of a case) closes
  #   loops that partition the interior. They are told from the enclosing ones
  #   by the shell walk below, which reaches only what is visible from outside,
  #   and erased (kept, unoriented, in keep_inner_faces mode).
  #
  # - ORIENTATION (orient_faces). #find_faces orients each face on its own,
  #   with no regard for its neighbours : the result is a patchwork of fronts
  #   and backs. The shell walk fixes that as it goes, and it is the same walk
  #   that finds the outer shell, because both questions have one answer : the
  #   face reached from outside is an outer face, and the side it was reached
  #   from is its front.
  #
  # THE SHELL WALK (see #_walk_component). A seed face known to be on the
  # outside is found by RAY CASTING (see #_seed) : a ray fired from well
  # outside the drawing toward a point known to be on it, the nearest triangle
  # it hits is on the shell and its outward normal is the one facing the ray.
  # Rays grazing a face or hitting an edge are rejected and another direction
  # is tried, so the seed is never read off a degenerate hit.
  #
  # From that seed the walk crosses each edge to the neighbour bounding the
  # SAME outside, found by RADIAL ORDER around the edge : rotating around the
  # edge from the current face, through the half space its front faces, the
  # FIRST face met is the one the outside region ends on — any face met later
  # lies behind it, walled off from the outside. That single rule is what
  # keeps interior partitions out (they always come later in the rotation) AND
  # what orients the neighbour, since the side it was reached from is by
  # construction its front. On a plain manifold edge the rotation has one
  # candidate and the rule degenerates to "the other face, wound the other
  # way" — the ordinary consistent orientation.
  #
  # Each connected group of faces gets its own seed and its own walk, so a
  # drawing holding several separate volumes rebuilds them all, each oriented
  # outward from ITSELF (the volumes are summed as they come : a shell nested
  # inside another is not subtracted from it).
  #
  # In erase_sources mode the collected CLines are erased once the rebuild
  # succeeded. Beware that a container left EMPTY by that erase is deleted by
  # SketchUp itself : a group holding nothing but the construction drawing
  # disappears with it, and the caller's reference to it goes stale.
  #
  # A drawing that does not close is a legitimate outcome, not an error : the
  # walk simply stops at the naked edges, the surface it covers is still
  # oriented consistently and toward the side the ray came from, and the
  # result def reports naked_edge_count so the caller can point at what is
  # missing. The worker only fails when there is no CLine to read, or when no
  # loop closes at all.
  class CommonSolidRebuildFromClinesWorker

    INFINITE_CLIP = 'clip'.freeze     # Clip infinite CLines to the finite drawing bounds
    INFINITE_IGNORE = 'ignore'.freeze # Leave them out

    # Welding distance, in inches : SketchUp's own merge tolerance, the
    # distance below which it considers two points to be one. Used for the
    # crossing detection (two segments passing closer than this cross), for
    # the degenerate segment filter, and for the seed hit disambiguation —
    # anything the model itself would weld must be treated as coincident here
    # too, or the arrangement fed to #find_faces would disagree with the one
    # SketchUp ends up storing.
    TOLERANCE = 0.001

    # Below this, the Gram determinant of two segment directions is treated as
    # singular : they are parallel (or collinear), their "intersection" is
    # degenerate, and SketchUp merges those cases on its own anyway. Relative
    # to the two squared lengths, so it reads as an angle rather than as a
    # length — sin² of about 0.006°.
    PARALLEL_EPSILON = 1.0e-8

    # Below this angle (radians), a candidate face is taken to be coincident
    # with the one the rotation starts from rather than a hair away from it,
    # and is pushed to the END of the radial order : a duplicate face is never
    # the neighbour bounding the outside. See #_walk_component.
    ANGLE_EPSILON = 1.0e-7

    # Directions tried, in order, when ray casting for a shell seed. They are
    # deliberately irrational looking : an axis aligned drawing — most
    # woodworking ones — would see an axis aligned ray graze whole faces and
    # thread through edges, which is exactly what the seed must not be read
    # off. Normalized on use.
    SEED_DIRECTIONS = [
      [  0.5257,  0.3251,  0.7862 ],
      [ -0.7071,  0.4472,  0.5477 ],
      [  0.3015, -0.9045,  0.3015 ],
      [ -0.4082, -0.4082,  0.8165 ],
      [  0.8018,  0.5345, -0.2673 ],
      [ -0.2673,  0.8018, -0.5345 ],
      [  0.1543, -0.3086, -0.9258 ],
      [ -0.9258, -0.1543, -0.3086 ]
    ].freeze

    # Minimum |normal . ray direction| for a seed hit to be trusted : below
    # it the ray grazes the face, the hit point is numerical noise and so is
    # the side it says it came from.
    SEED_MIN_INCIDENCE = 0.05

    # How far inside its triangle a seed hit must land, in barycentric
    # coordinates : a hit on an edge or a corner belongs to several triangles
    # at once and cannot name the face it entered through.
    SEED_BARYCENTRIC_MARGIN = 1.0e-4

    def initialize(sources,

                   source_transformation: nil,

                   target_entities: nil,
                   target_transformation: nil,
                   name: nil,

                   infinite: INFINITE_CLIP,
                   tolerance: TOLERANCE,

                   keep_inner_faces: false,
                   prune_dangling_edges: true,
                   orient_faces: true,
                   erase_sources: false,

                   wrap_operation: true

    )

      @sources = sources.is_a?(Array) ? sources : [ sources ]
      @source_transformation = source_transformation.nil? ? Geom::Transformation.new : source_transformation

      @target_entities = target_entities
      @target_transformation = target_transformation
      @name = name

      @infinite = infinite
      @tolerance = tolerance.to_f

      @keep_inner_faces = keep_inner_faces
      @prune_dangling_edges = prune_dangling_edges
      @orient_faces = orient_faces
      @erase_sources = erase_sources

      @wrap_operation = wrap_operation

    end

    # -----

    def run
      result_def = SolidRebuildResultDef.new

      model = Sketchup.active_model
      if model.nil?
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      # Everything is read and computed BEFORE the operation opens : the
      # arrangement only depends on the sources, and a failure here must leave
      # the model untouched without an abort.
      @clines = []
      segments = _collect_segments(result_def)
      if segments.empty?
        result_def.errors << [ 'core.solid.rebuild.error.no_segment' ]
        return result_def
      end
      segments = _split_segments(segments, result_def)

      model.start_operation('OCL Solid Rebuild', true) if @wrap_operation
      begin

        entities = @target_entities
        if entities.nil?
          container = model.entities.add_group
          container.name = @name unless @name.nil?
          result_def.container = container
          result_def.created_entities << container
          entities = container.entities
          to_local = nil
        else
          to_local = @target_transformation.nil? ? nil : @target_transformation.inverse
        end

        # What the target already held : a caller provided context is not
        # required to be empty, and only the geometry THIS run builds may be
        # reported back — or erased by the caller later on. A freshly created
        # container simply starts with nothing on the list.
        preexisting_ids = {}
        entities.each { |entity| preexisting_ids[entity.entityID] = true }

        segments.each do |a, b|
          unless to_local.nil?
            a = a.transform(to_local)
            b = b.transform(to_local)
          end
          entities.add_line(a, b)
        end

        # Every closed coplanar loop of the arrangement becomes a face
        entities.grep(Sketchup::Edge).each { |edge| edge.find_faces if edge.valid? }

        faces = entities.grep(Sketchup::Face)
        return _rollback(result_def, model, [ 'core.solid.rebuild.error.no_face' ]) if faces.empty?

        # The shell walk : what is reachable from outside, and which way round
        orientations = _walk_shells(faces, result_def)
        inner_faces = faces.select { |face| !orientations.key?(face.entityID) }
        result_def.inner_face_count = inner_faces.length

        if @orient_faces
          reversed_count = 0
          faces.each do |face|
            next unless orientations[face.entityID] == -1
            face.reverse!
            reversed_count += 1
          end
          result_def.reversed_face_count = reversed_count
        end

        entities.erase_entities(inner_faces) if !@keep_inner_faces && !inner_faces.empty?

        # Face less edges : the overhang left by a clipped infinite CLine, and
        # any construction line the drawing never closed a loop on
        if @prune_dangling_edges
          dangling_edges = entities.grep(Sketchup::Edge).select { |edge| edge.faces.empty? }
          unless dangling_edges.empty?
            entities.erase_entities(dangling_edges)
            result_def.pruned_edge_count = dangling_edges.length
          end
        end

        _collect_built(entities, preexisting_ids, result_def)
        _measure(result_def)

        _erase_sources if @erase_sources

        model.commit_operation if @wrap_operation

      rescue => e
        _rollback(result_def, model, [ 'core.error.exception', { :error => e.message } ])
      end

      result_def
    end

    # -----

    private

    # Undoes whatever the run had built and records the error : the result of a
    # failed rebuild is nothing at all, never a half built shell.
    #
    # The operation is aborted when the worker owns it. When it does NOT
    # (wrap_operation: false), the caller is expected to abort its own — but
    # the container built here is erased anyway rather than left to that
    # promise : a caller that decides to carry on would otherwise be left with
    # a stray group nothing points at. Either way the result def is emptied :
    # an aborted operation deletes the very entities it would hand back.
    def _rollback(result_def, model, error)
      begin
        if @wrap_operation
          model.abort_operation
        elsif !result_def.container.nil? && result_def.container.valid?
          result_def.container.erase!
        end
      rescue
        # An abort failing has nothing left to tell : the error being recorded
        # is the one that matters
      end
      result_def.container = nil
      result_def.created_entities.clear
      result_def.faces.clear
      result_def.edges.clear
      result_def.errors << error
      result_def
    end

    # ----- Sources

    # Segments ([ Geom::Point3d, Geom::Point3d ] pairs) of every CLine
    # reachable from the sources, in the common space @source_transformation
    # opens (see the class doc) : the finite ones as they are, the infinite and
    # half-infinite ones clipped to the bounds of the finite drawing (see the
    # class doc, INFINITE CLINES). Fills the source counters of the result def,
    # and @clines with the collected CLines.
    def _collect_segments(result_def)

      finite = []
      infinite = []

      _each_cline(@sources, @source_transformation) do |cline, transformation|

        @clines << cline
        result_def.cline_count += 1

        start_point = cline.start
        end_point = cline.end

        unless start_point.nil? || end_point.nil?
          a = start_point.transform(transformation)
          b = end_point.transform(transformation)
          if a.distance(b).to_f <= @tolerance
            result_def.ignored_count += 1
          else
            finite << [ a, b ]
          end
          next
        end

        if @infinite == INFINITE_IGNORE
          result_def.ignored_count += 1
          next
        end

        direction = cline.direction.transform(transformation)
        if direction.length.to_f == 0
          result_def.ignored_count += 1
          next
        end
        direction.normalize!

        # A half-infinite CLine keeps the end it has : the parameter range is
        # bounded on that side, unbounded on the other
        if !start_point.nil?
          infinite << [ start_point.transform(transformation), direction, 0.0, Float::INFINITY ]
        elsif !end_point.nil?
          infinite << [ end_point.transform(transformation), direction, -Float::INFINITY, 0.0 ]
        else
          infinite << [ cline.position.transform(transformation), direction, -Float::INFINITY, Float::INFINITY ]
        end

      end

      return finite if infinite.empty?

      bounds = Geom::BoundingBox.new
      finite.each { |a, b| bounds.add(a) ; bounds.add(b) }
      if bounds.empty?
        # Nothing finite to clip against : an infinite line has no extent of
        # its own to give it one
        result_def.ignored_count += infinite.length
        return finite
      end

      infinite.each do |origin, direction, t_min, t_max|
        segment = _clip_to_bounds(origin, direction, t_min, t_max, bounds)
        if segment.nil?
          result_def.ignored_count += 1
        else
          finite << segment
          result_def.clipped_count += 1
        end
      end

      finite
    end

    # Yields [ ConstructionLine, accumulated Geom::Transformation ] for every
    # CLine reachable from the given sources, descending into the containers.
    def _each_cline(sources, transformation, &block)
      sources = sources.is_a?(Array) ? sources : [ sources ]
      sources.each do |source|
        case source
        when Sketchup::ConstructionLine
          yield source, transformation
        when Sketchup::Group, Sketchup::ComponentInstance
          _each_cline(source.definition.entities.to_a, transformation * source.transformation, &block)
        when Sketchup::Entities
          _each_cline(source.to_a, transformation, &block)
        when Sketchup::Model
          _each_cline(source.entities.to_a, transformation, &block)
        when Array
          _each_cline(source, transformation, &block)
        end
      end
    end

    # The part of the line (origin, unit direction, parameter range) lying
    # inside the given bounds, as a [ Geom::Point3d, Geom::Point3d ] segment —
    # the slab method, one axis at a time. nil when the line misses the box, or
    # only grazes it.
    def _clip_to_bounds(origin, direction, t_min, t_max, bounds)

      o = [ origin.x.to_f, origin.y.to_f, origin.z.to_f ]
      d = [ direction.x, direction.y, direction.z ]
      lo = [ bounds.min.x.to_f, bounds.min.y.to_f, bounds.min.z.to_f ]
      hi = [ bounds.max.x.to_f, bounds.max.y.to_f, bounds.max.z.to_f ]

      3.times do |i|
        if d[i].abs < 1.0e-12
          # Parallel to this slab : inside it for the whole line, or never
          return nil if o[i] < lo[i] - @tolerance || o[i] > hi[i] + @tolerance
        else
          t0 = (lo[i] - o[i]) / d[i]
          t1 = (hi[i] - o[i]) / d[i]
          t0, t1 = t1, t0 if t0 > t1
          t_min = t0 if t0 > t_min
          t_max = t1 if t1 < t_max
          return nil if t_min > t_max
        end
      end
      return nil if (t_max - t_min) <= @tolerance

      [
        Geom::Point3d.new(o[0] + d[0] * t_min, o[1] + d[1] * t_min, o[2] + d[2] * t_min),
        Geom::Point3d.new(o[0] + d[0] * t_max, o[1] + d[1] * t_max, o[2] + d[2] * t_max)
      ]
    end

    # ----- Arrangement

    # The given segments split at every TRANSVERSAL crossing, so that each one
    # meets its neighbours on a shared VERTEX — the only kind of meeting
    # SketchUp merges on its own (see the class doc, CROSSINGS). Two segments
    # count as crossing when their closest approach is within the tolerance
    # AND falls on both of them ; both are then split at the MIDPOINT of that
    # approach, so the two vertices coincide exactly whatever the near miss
    # was. A segment is only split where the crossing is INTERIOR to it : a
    # crossing at its own end is already a vertex.
    def _split_segments(segments, result_def)

      count = segments.length
      origins = []
      vectors = []
      boxes = []
      segments.each do |a, b|
        ax, ay, az = a.x.to_f, a.y.to_f, a.z.to_f
        bx, by, bz = b.x.to_f, b.y.to_f, b.z.to_f
        origins << [ ax, ay, az ]
        vectors << [ bx - ax, by - ay, bz - az ]
        boxes << [
          [ ax < bx ? ax : bx, ay < by ? ay : by, az < bz ? az : bz ],
          [ ax > bx ? ax : bx, ay > by ? ay : by, az > bz ? az : bz ]
        ]
      end

      splits = Array.new(count) { [] }

      (0...count).each do |i|
        p = origins[i] ; u = vectors[i]
        a = u[0] * u[0] + u[1] * u[1] + u[2] * u[2]
        length_i = Math.sqrt(a)
        ((i + 1)...count).each do |j|
          next unless _boxes_overlap(boxes[i], boxes[j])

          q = origins[j] ; v = vectors[j]
          c = v[0] * v[0] + v[1] * v[1] + v[2] * v[2]
          b = u[0] * v[0] + u[1] * v[1] + u[2] * v[2]
          denominator = a * c - b * b
          # Parallel or collinear : SketchUp merges those on its own, and the
          # closest approach is not a point
          next if denominator <= PARALLEL_EPSILON * a * c

          w = [ p[0] - q[0], p[1] - q[1], p[2] - q[2] ]
          d = u[0] * w[0] + u[1] * w[1] + u[2] * w[2]
          e = v[0] * w[0] + v[1] * w[1] + v[2] * w[2]
          s = (b * e - c * d) / denominator
          t = (a * e - b * d) / denominator

          length_j = Math.sqrt(c)
          # The crossing must fall ON both segments, ends included : a
          # crossing of the two supporting LINES beyond an end is not a
          # meeting of the drawing
          next if s * length_i < -@tolerance || (1.0 - s) * length_i < -@tolerance
          next if t * length_j < -@tolerance || (1.0 - t) * length_j < -@tolerance

          px = p[0] + s * u[0] ; py = p[1] + s * u[1] ; pz = p[2] + s * u[2]
          qx = q[0] + t * v[0] ; qy = q[1] + t * v[1] ; qz = q[2] + t * v[2]
          gx = px - qx ; gy = py - qy ; gz = pz - qz
          next if gx * gx + gy * gy + gz * gz > @tolerance * @tolerance

          point = Geom::Point3d.new((px + qx) / 2.0, (py + qy) / 2.0, (pz + qz) / 2.0)
          splits[i] << [ s, point ] if s * length_i > @tolerance && (1.0 - s) * length_i > @tolerance
          splits[j] << [ t, point ] if t * length_j > @tolerance && (1.0 - t) * length_j > @tolerance
          result_def.split_count += 1

        end
      end

      split_segments = []
      segments.each_with_index do |(a, b), index|
        points = splits[index]
        if points.empty?
          split_segments << [ a, b ]
          next
        end
        previous = a
        points.sort_by { |s, _point| s }.each do |_s, point|
          next if previous.distance(point).to_f <= @tolerance
          split_segments << [ previous, point ]
          previous = point
        end
        split_segments << [ previous, b ] if previous.distance(b).to_f > @tolerance
      end

      split_segments
    end

    def _boxes_overlap(box_a, box_b)
      3.times do |i|
        return false if box_a[1][i] < box_b[0][i] - @tolerance
        return false if box_b[1][i] < box_a[0][i] - @tolerance
      end
      true
    end

    # ----- Shell walk

    # entityID -> +1 / -1 for every face the walk reached, the sign saying
    # whether its current normal already points outward (+1) or must be
    # reversed (-1). Faces absent from the returned hash were never reached :
    # they are the interior ones. Fills shell_count.
    def _walk_shells(faces, result_def)
      orientations = {}
      components = _face_components(faces)
      result_def.shell_count = components.length
      components.each do |component|
        seed_face, seed_normal = _seed(component)
        next if seed_face.nil?
        _walk_component(seed_face, seed_normal, orientations)
      end
      orientations
    end

    # The given faces grouped into connected components (faces sharing an
    # edge). Each is walked from its own seed : a drawing may well hold several
    # separate volumes.
    def _face_components(faces)
      faces_by_id = {}
      faces.each { |face| faces_by_id[face.entityID] = face }

      seen = {}
      components = []
      faces.each do |face|
        next if seen[face.entityID]
        seen[face.entityID] = true
        stack = [ face ]
        component = []
        until stack.empty?
          current = stack.pop
          component << current
          current.edges.each do |edge|
            edge.faces.each do |neighbour|
              id = neighbour.entityID
              next if seen[id] || !faces_by_id.key?(id)
              seen[id] = true
              stack << neighbour
            end
          end
        end
        components << component
      end
      components
    end

    # [ face, outward Geom::Vector3d ] of a face of the given component known
    # to be on its OUTER shell, by ray casting from well outside toward a point
    # known to be on the surface : the nearest triangle hit is on the shell,
    # and the side it was hit from is its outside (see the class doc).
    #
    # A direction is given up on when its nearest hit is degenerate — the ray
    # grazing the face, landing on a triangle edge, or two distinct faces hit
    # at the same distance : such a hit cannot name the face it entered
    # through. The last resort, when no direction gives a clean hit, reads the
    # orientation off the component's own bounds : it is a guess, but a
    # component no ray can cleanly enter is degenerate to begin with.
    def _seed(faces)

      triangles = []
      bounds = Geom::BoundingBox.new
      faces.each do |face|
        normal = face.normal
        n = [ normal.x, normal.y, normal.z ]
        mesh = face.mesh
        (1..mesh.count_polygons).each do |index|
          points = mesh.polygon_points_at(index)
          next unless points.length == 3
          points.each { |point| bounds.add(point) }
          triangles << [ face, points.map { |point| [ point.x.to_f, point.y.to_f, point.z.to_f ] }, n ]
        end
      end
      return [ nil, nil ] if triangles.empty?

      # A point guaranteed to be ON the surface : the barycenter of its
      # largest triangle, so the ray cannot miss the component altogether
      target_triangle = triangles.max_by { |_face, points, _n| _triangle_area2(points) }[1]
      target = [
        (target_triangle[0][0] + target_triangle[1][0] + target_triangle[2][0]) / 3.0,
        (target_triangle[0][1] + target_triangle[1][1] + target_triangle[2][1]) / 3.0,
        (target_triangle[0][2] + target_triangle[1][2] + target_triangle[2][2]) / 3.0
      ]
      distance = bounds.diagonal.to_f * 2.0 + 1.0

      SEED_DIRECTIONS.each do |direction|

        length = Math.sqrt(direction[0] * direction[0] + direction[1] * direction[1] + direction[2] * direction[2])
        d = [ direction[0] / length, direction[1] / length, direction[2] / length ]
        origin = [ target[0] - d[0] * distance, target[1] - d[1] * distance, target[2] - d[2] * distance ]

        nearest = nil
        ambiguous = false
        triangles.each do |face, points, n|
          hit = _ray_triangle(origin, d, points)
          next if hit.nil?
          if nearest.nil? || hit[0] < nearest[0]
            ambiguous = !nearest.nil? && nearest[1].entityID != face.entityID && (nearest[0] - hit[0]).abs <= @tolerance
            nearest = [ hit[0], face, n, hit[1], hit[2] ]
          elsif nearest[1].entityID != face.entityID && (hit[0] - nearest[0]).abs <= @tolerance
            ambiguous = true
          end
        end
        next if nearest.nil? || ambiguous

        _t, face, n, u, v = nearest
        # Grazing hit : the side it reports is numerical noise
        next if (n[0] * d[0] + n[1] * d[1] + n[2] * d[2]).abs < SEED_MIN_INCIDENCE
        # Hit on a triangle edge or corner : it belongs to several triangles
        next if u < SEED_BARYCENTRIC_MARGIN || v < SEED_BARYCENTRIC_MARGIN || (u + v) > 1.0 - SEED_BARYCENTRIC_MARGIN

        normal = Geom::Vector3d.new(n[0], n[1], n[2])
        # Outward is the side the ray came from
        normal.reverse! if n[0] * d[0] + n[1] * d[1] + n[2] * d[2] > 0
        return [ face, normal ]

      end

      # Last resort : point the face the target sits on away from the
      # component's center
      face = triangles.max_by { |_face, points, _n| _triangle_area2(points) }[0]
      reference = bounds.center.vector_to(Geom::Point3d.new(target[0], target[1], target[2]))
      normal = face.normal
      normal = normal.reverse if reference.valid? && normal.dot(reference) < 0
      [ face, normal ]
    end

    # Distance along the ray at which it enters the given triangle, and the
    # barycentric coordinates of the hit ([ t, u, v ]), by Möller–Trumbore.
    # nil when the ray misses or runs in the triangle's plane. The barycentric
    # bounds are deliberately LOOSE : a hit landing on an edge is reported, and
    # rejected by the caller — silently dropping it would hand the seed to a
    # face BEHIND the real one.
    def _ray_triangle(origin, direction, points)
      a, b, c = points
      e1 = [ b[0] - a[0], b[1] - a[1], b[2] - a[2] ]
      e2 = [ c[0] - a[0], c[1] - a[1], c[2] - a[2] ]

      p = [
        direction[1] * e2[2] - direction[2] * e2[1],
        direction[2] * e2[0] - direction[0] * e2[2],
        direction[0] * e2[1] - direction[1] * e2[0]
      ]
      determinant = e1[0] * p[0] + e1[1] * p[1] + e1[2] * p[2]
      return nil if determinant.abs < 1.0e-12

      inverse = 1.0 / determinant
      s = [ origin[0] - a[0], origin[1] - a[1], origin[2] - a[2] ]
      u = (s[0] * p[0] + s[1] * p[1] + s[2] * p[2]) * inverse
      return nil if u < -SEED_BARYCENTRIC_MARGIN || u > 1.0 + SEED_BARYCENTRIC_MARGIN

      q = [
        s[1] * e1[2] - s[2] * e1[1],
        s[2] * e1[0] - s[0] * e1[2],
        s[0] * e1[1] - s[1] * e1[0]
      ]
      v = (direction[0] * q[0] + direction[1] * q[1] + direction[2] * q[2]) * inverse
      return nil if v < -SEED_BARYCENTRIC_MARGIN || (u + v) > 1.0 + SEED_BARYCENTRIC_MARGIN

      t = (e2[0] * q[0] + e2[1] * q[1] + e2[2] * q[2]) * inverse
      return nil if t <= 0

      [ t, u, v ]
    end

    def _triangle_area2(points)
      a, b, c = points
      ux = b[0] - a[0] ; uy = b[1] - a[1] ; uz = b[2] - a[2]
      vx = c[0] - a[0] ; vy = c[1] - a[1] ; vz = c[2] - a[2]
      nx = uy * vz - uz * vy
      ny = uz * vx - ux * vz
      nz = ux * vy - uy * vx
      Math.sqrt(nx * nx + ny * ny + nz * nz)
    end

    # Spreads the seed's orientation over the whole shell it belongs to,
    # crossing each edge to the neighbour bounding the same outside — the
    # first face met rotating around the edge from the current one, through
    # the half space its front faces. Fills the given orientations hash
    # (entityID -> +1 / -1) with every face reached.
    #
    # Around an edge, a face f is described by two directions perpendicular to
    # it : the direction t_f in which f's loop TRAVERSES the edge, and the
    # direction m_f = n_f x t_f in which f's material EXTENDS from it. The
    # rotation that carries m_f toward n_f — sweeping the half space f's front
    # faces, i.e. the outside — is the POSITIVE rotation about t_f, so the
    # neighbour bounding that same outside is the candidate whose own m
    # comes FIRST in that rotation.
    #
    # Its orientation follows for free : the outside ends just short of it, at
    # angle theta - epsilon, which is m rotated by -90° about t_f, that is
    # m x t_f. Taking that as the neighbour's normal makes it traverse the
    # shared edge in the direction opposite to f — the consistent winding a
    # closed shell needs — without ever having to state it.
    def _walk_component(seed_face, seed_normal, orientations)

      orientations[seed_face.entityID] = seed_face.normal.dot(seed_normal) >= 0 ? 1 : -1
      stack = [ seed_face ]

      until stack.empty?
        face = stack.pop
        sign = orientations[face.entityID]
        normal = sign > 0 ? face.normal : face.normal.reverse

        face.edges.each do |edge|

          candidates = edge.faces.select { |other| other.entityID != face.entityID }
          next if candidates.empty?

          traversal = _traversal(edge, face)
          next if traversal.nil?
          traversal.reverse! if sign < 0
          material = normal.cross(traversal)

          best_candidate = nil
          best_material = nil
          best_theta = nil
          candidates.each do |candidate|
            candidate_material = _material_direction(edge, candidate)
            next if candidate_material.nil?
            theta = Math.atan2(material.cross(candidate_material).dot(traversal), material.dot(candidate_material))
            theta += 2.0 * Math::PI if theta <= ANGLE_EPSILON
            next unless best_theta.nil? || theta < best_theta
            best_theta = theta
            best_candidate = candidate
            best_material = candidate_material
          end
          next if best_candidate.nil?
          next if orientations.key?(best_candidate.entityID)

          candidate_normal = best_material.cross(traversal)
          orientations[best_candidate.entityID] = best_candidate.normal.dot(candidate_normal) >= 0 ? 1 : -1
          stack << best_candidate

        end
      end

    end

    # Unit direction in which the given face's loop traverses the given edge,
    # for the face's CURRENT orientation. nil on a degenerate edge.
    def _traversal(edge, face)
      direction = edge.start.position.vector_to(edge.end.position)
      return nil unless direction.valid?
      direction.normalize!
      direction.reverse! if edge.reversed_in?(face)
      direction
    end

    # Unit direction, perpendicular to the given edge, in which the given
    # face's material extends from it. Independent of the face's orientation :
    # reversing it negates both the normal and the traversal, leaving their
    # cross product unchanged — which is why a candidate can be placed in the
    # radial order before anything is decided about which way round it goes.
    # Works on a hole's loop too, whose reversed winding puts the material on
    # the same side as the face's own. nil on a degenerate edge.
    def _material_direction(edge, face)
      traversal = _traversal(edge, face)
      return nil if traversal.nil?
      face.normal.cross(traversal)
    end

    # ----- Result

    # Reads the counters off the geometry THIS run built (see #_collect_built),
    # not off the whole target : a caller provided context may already hold
    # geometry of its own, which has no business in this rebuild's volume or
    # edge counts. The per edge face counts below are the exception, and
    # deliberately so — they are read from the model, so an edge shared with
    # pre-existing geometry is correctly seen as bounded by it.
    def _measure(result_def)

      edges = result_def.edges
      faces = result_def.faces

      result_def.edge_count = edges.length
      result_def.face_count = faces.length
      result_def.naked_edge_count = edges.count { |edge| edge.faces.length == 1 }
      result_def.non_manifold_edge_count = edges.count { |edge| edge.faces.length > 2 }

      # Divergence theorem over the oriented triangles : positive on a closed
      # shell wound outward, which is what the walk just made of it
      volume = 0.0
      faces.each do |face|
        mesh = face.mesh
        (1..mesh.count_polygons).each do |index|
          points = mesh.polygon_points_at(index)
          next unless points.length == 3
          ax, ay, az = points[0].x.to_f, points[0].y.to_f, points[0].z.to_f
          bx, by, bz = points[1].x.to_f, points[1].y.to_f, points[1].z.to_f
          cx, cy, cz = points[2].x.to_f, points[2].y.to_f, points[2].z.to_f
          volume += (ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)) / 6.0
        end
      end
      result_def.volume = volume

    end

    # Hands the geometry this run built back to the caller : the faces to work
    # with, and the edges to hold it by — erasing an edge takes its faces with
    # it, so the edge list alone is what a caller needs to undo the rebuild.
    #
    # Read as what the target holds MINUS what it held before, rather than as
    # what was added : the arrangement is not a list of additions but a
    # negotiation with the geometry engine — an added edge may be absorbed by
    # an existing one, split into several, or split one in two, and the faces
    # are found by SketchUp rather than created here.
    def _collect_built(entities, preexisting_ids, result_def)
      entities.each do |entity|
        next if preexisting_ids.key?(entity.entityID)
        case entity
        when Sketchup::Face
          result_def.faces << entity
        when Sketchup::Edge
          result_def.edges << entity
        end
      end
    end

    # Erases the collected CLines, grouped by the entities collection they live
    # in : the sources may span several containers.
    def _erase_sources
      clines_by_entities = {}
      @clines.each do |cline|
        next unless cline.valid?
        parent = cline.parent
        next if parent.nil?
        (clines_by_entities[parent.entities] ||= []) << cline
      end
      clines_by_entities.each { |entities, clines| entities.erase_entities(clines) }
    end

  end

end
