# The paneling corpus : CommonPanelingComputeWorker - the geometry of
# SmartReshapeTool's paneling action - on shapes given as PanelingMeshDef
# DATA, every check made on the returned polygons. Needs no model : runs in
# TestUp inside SketchUp, or outside it in plain ruby (Geom stand-ins) :
#
#   ruby test/headless/run.rb test/TC_Ladb_Worker_PanelingCompute.rb
#
# What it checks :
#   - one panel per selected face ;
#   - every panel closed : each edge bordered by exactly two of its polygons,
#     once split where a corner of another polygon lies on it ;
#   - no face too small for SketchUp to draw (Entities#add_face refuses
#     under SKETCHUP_MIN_FACE_AREA) ;
#   - every panel orientable : its polygons turned outward from the known
#     ground and up faces, one consistent winding ;
#   - every panel a valid manifold solid for Meshy, no two overlapping
#     (Meshy intersection under OVERLAP_MAX, residues thinner than the
#     tolerance ignored) ;
#   - with volume, the panels' total volume (liters).
# The SketchUp path - the mesh read back from faces, the panels drawn - is
# test/live/TC_Ladb_Tool_SmartReshapePaneling.rb.
#
# The shapes :
#   - prisms (cube, L, U, T, star) : an outline in XY (mm) extruded 300 up.
#     Faces : :bottom, :top, :side0, :side1… (:sideI on the outline edge from
#     point I to point I+1) ;
#   - the valley family (valley, ridge, vtilt) : a 500 cube whose top is two
#     slopes meeting along a valley diagonal, z 250 at (0, 0) and (500, 500),
#     500 at (0, 500) and (500, 0) - ridge is it mirrored in Z, vtilt turned
#     0.7 rad around (1, 2, 3). Faces : :bottom, :front (y 0), :back (y 500),
#     :left (x 0), :right (x 500), :slope_a (on the x 0 / y 500 side),
#     :slope_b (on the x 500 / y 0 side). Their reflex edge is the valley
#     diagonal, their degree 4 vertices its two ends ;
#   - solids given as points (mm) and loops (apex5) : a pentagonal prism
#     capped by five triangles meeting at a degree 5 apex, off centre, read
#     from a user model. Faces : :bottom, :roof1… :roof5, :wall1… :wall5.
#
# Named cases : the faces in extrusion order (:all = the mesh order), the
# default joint, miters / flats = the edges between two faces set to that
# joint, outward or inward. A case with known : 'why' is an open defect -
# reported KNOWN while it fails, FIXED? once it passes.
#
# Random corpus : every shape, seeded random selections (order shuffled),
# joints uniform flat, uniform miter or mixed per edge, both directions.
#
# From the Ruby console, the Claude Bridge or plain ruby (after the stand-ins) :
#   PanelingRegression.run                 # one line per named case
#   PanelingRegression.run_random          # failures and known ones + the score
#   PanelingRegression.random_spec(:valley, 50, false)  # one random case as a named case spec
begin
  require 'testup/testcase'
rescue LoadError
  # Console / bridge use : the runner below is all there is
end
require 'json'

require_relative '../src/ladb_opencutlist/ruby/worker/common/common_paneling_compute_worker'
require_relative '../src/ladb_opencutlist/ruby/lib/fiddle/meshy/meshy'

module PanelingRegression

  OCL = Ladb::OpenCutList
  WORKER = OCL::CommonPanelingComputeWorker
  MESH = OCL::PanelingMeshDef
  MESHY = OCL::Fiddle::Meshy

  FLAT = WORKER::JOINT_TYPE_FLAT
  MITER = WORKER::JOINT_TYPE_MITER

  THICKNESS = 18
  OVERLAP_MAX = 0.05  # cm³
  VOLUME_TOLERANCE = 0.01  # liters
  CUBIC_INCH_TO_LITER = 0.016387064
  MESHY_TOLERANCE = 0.001
  # Entities#add_face refuses a smaller face ("Points are not planar"), see
  # sketchup-api-quirks/quirks/add-face-min-area.md
  SKETCHUP_MIN_FACE_AREA = 8.66e-6 # in²

  STAR = (0...10).map { |i| r = i.even? ? 300 : 120; a = Math::PI / 2 + i * Math::PI / 5; [ 300 + r * Math.cos(a), 300 + r * Math.sin(a) ] }

  PRISMS = {
    cube: [ [ 0, 0 ], [ 500, 0 ], [ 500, 500 ], [ 0, 500 ] ],
    L: [ [ 0, 0 ], [ 500, 0 ], [ 500, 200 ], [ 200, 200 ], [ 200, 500 ], [ 0, 500 ] ],
    U: [ [ 0, 0 ], [ 600, 0 ], [ 600, 500 ], [ 400, 500 ], [ 400, 150 ], [ 200, 150 ], [ 200, 500 ], [ 0, 500 ] ],
    T: [ [ 0, 0 ], [ 600, 0 ], [ 600, 150 ], [ 400, 150 ], [ 400, 500 ], [ 200, 500 ], [ 200, 150 ], [ 0, 150 ] ],
    star: STAR,
  }.freeze
  PRISM_HEIGHT = 300

  # Loops counter-clockwise seen from outside
  VALLEY_FACES = {
    front: [ [ 500, 0, 0 ], [ 500, 0, 500 ], [ 0, 0, 250 ], [ 0, 0, 0 ] ],
    right: [ [ 500, 0, 500 ], [ 500, 0, 0 ], [ 500, 500, 0 ], [ 500, 500, 250 ] ],
    slope_a: [ [ 0, 500, 500 ], [ 0, 0, 250 ], [ 500, 500, 250 ] ],
    left: [ [ 0, 0, 0 ], [ 0, 0, 250 ], [ 0, 500, 500 ], [ 0, 500, 0 ] ],
    back: [ [ 0, 500, 0 ], [ 0, 500, 500 ], [ 500, 500, 250 ], [ 500, 500, 0 ] ],
    slope_b: [ [ 500, 0, 500 ], [ 500, 500, 250 ], [ 0, 0, 250 ] ],
    bottom: [ [ 500, 0, 0 ], [ 0, 0, 0 ], [ 0, 500, 0 ], [ 500, 500, 0 ] ],
  }.freeze
  VALLEYS = {
    valley: Geom::Transformation.new,
    ridge: Geom::Transformation.scaling(1, 1, -1),
    vtilt: Geom::Transformation.rotation(ORIGIN, Geom::Vector3d.new(1, 2, 3), 0.7),
  }.freeze

  # Points in mm, loops counter-clockwise seen from outside, face names in
  # loop order
  SOLIDS = {
    apex5: {
      points: [ [ 700.32, 0.0, -213.85 ], [ 0.0, 0.0, -213.85 ], [ -152.42, 671.32, -213.85 ], [ 310.91, 992.16, -213.85 ], [ 780.69, 497.55, -213.85 ],
                [ 310.91, 992.16, -43.03 ], [ -152.42, 671.32, -43.03 ], [ 332.78, 408.02, 292.02 ], [ 780.69, 497.55, -43.03 ], [ 700.32, 0.0, -43.03 ], [ 0.0, 0.0, -43.03 ] ],
      loops: [ [ 0, 1, 2, 3, 4 ], [ 5, 6, 7 ], [ 8, 7, 9 ], [ 5, 7, 8 ], [ 9, 7, 10 ], [ 6, 10, 7 ], [ 1, 0, 9, 10 ], [ 5, 8, 4, 3 ], [ 4, 8, 9, 0 ], [ 2, 6, 5, 3 ], [ 1, 10, 6, 2 ] ],
      names: [ :bottom, :roof1, :roof2, :roof3, :roof4, :roof5, :wall1, :wall2, :wall3, :wall4, :wall5 ],
    },
  }.freeze

  SHAPES = PRISMS.keys + VALLEYS.keys + SOLIDS.keys

  # Volumes : recorded from a verified run. The cube ones are checked by hand :
  # inward 75 - 0.464² x 0.264 = 18.16 L, outward 0.536² x 0.336 - 75 = 21.53 L.
  CASES = {}
  [
    [ :valley, 21.48, 25.66 ],
    [ :cube, 18.16, 21.53 ],
    [ :L, 14.92, 18.29 ],
    [ :U, 21.72, 26.25 ],
  ].each do |shape, volume_in, volume_out|
    [ FLAT, MITER ].each do |joint|
      CASES["#{shape}_all_#{joint}_in"] = { shape: shape, faces: :all, joint: joint, outward: false, volume: volume_in }
      CASES["#{shape}_all_#{joint}_out"] = { shape: shape, faces: :all, joint: joint, outward: true, volume: volume_out }
    end
  end
  CASES.merge!(
    # Reflex edge, flat : the second slope runs past the valley to the
    # first's offset plane
    'valley_slopes_flat_in' => { shape: :valley, faces: [ :slope_a, :slope_b ], joint: FLAT, outward: false },
    'valley_slopes_flat_out' => { shape: :valley, faces: [ :slope_a, :slope_b ], joint: FLAT, outward: true },
    # Partial selection across the valley : topology change across the thickness
    'valley_slopes_front_right_in' => { shape: :valley, faces: [ :front, :slope_a, :slope_b, :right ], joint: FLAT, outward: false },
    # Degree 4 vertex, mixed joints : slope_a stretched past the valley runs
    # into right's thickness, which it only meets at the valley end (500, 500)
    'ridge_degree4_mixed_in' => { shape: :ridge, faces: [ :slope_b, :slope_a, :right ], joint: FLAT, miters: [ [ :right, :slope_b ] ], outward: false },
    # Reflex outline corner, mixed joints (the L inner corner)
    'L_reflex_corner_mixed_in' => { shape: :L, faces: [ :bottom, :side2, :side3 ], joint: FLAT, miters: [ [ :bottom, :side2 ] ], outward: false },
    'L_reflex_corner_mixed_out' => { shape: :L, faces: [ :side3, :bottom, :side2 ], joint: MITER, flats: [ [ :side2, :side3 ] ], outward: true },
    # U arm ends : coplanar faces, the sides must not pair across the arms
    'U_arm_ends_in' => { shape: :U, faces: [ :top, :side2, :side6, :side4 ], joint: MITER, outward: false },
    'star_all_mixed_out' => { shape: :star, faces: :all, joint: MITER, flats: [ [ :side0, :top ], [ :side3, :bottom ], [ :side6, :side7 ] ], outward: true },
    # A fan trim triangle sharing the corner and running along the outline
    # edges : Clippy read it as a hole touching the outline on the ground
    # level (dropped), not on the up one - a side was missing
    'vtilt_fan_trim_on_outline_out' => { shape: :vtilt, faces: [ :right, :left, :back, :slope_a ], joint: FLAT, outward: true },
    # A section edge on two planes (the bisector of a zone and the first
    # slope's offset plane) : paired on both, it bordered two sides
    'valley_edge_on_two_planes_mixed_in' => { shape: :valley, faces: [ :back, :right, :front, :bottom, :slope_a, :slope_b ], joint: FLAT, outward: false,
                                              miters: [ [ :front, :slope_b ], [ :right, :back ], [ :right, :slope_b ], [ :slope_a, :left ], [ :left, :back ], [ :left, :bottom ] ] },
    # Degree 4 vertex : the zone touches the later panel's up level at a
    # point inside its section - yielding it would pinch that panel, the
    # other one yields
    'valley_degree4_zone_pinch_mixed_out' => { shape: :valley, faces: [ :slope_b, :back, :slope_a, :bottom, :left, :front ], joint: FLAT, outward: true,
                                               miters: [ [ :front, :right ], [ :front, :slope_b ], [ :right, :back ], [ :right, :slope_b ], [ :slope_a, :back ], [ :left, :back ], [ :left, :bottom ] ] },
    # Degree 4 vertex : the zone is a tetrahedron standing on a corner of the
    # up level ; that corner's vertical edge also lies on the zone's bisector
    # plane - the zone's ground edge paired with it, 300 mm away, across the
    # panel (rejected now by the mid level section)
    'valley_degree4_zone_on_corner_mixed_out' => { shape: :valley, faces: [ :bottom, :back, :slope_a, :front, :right, :left, :slope_b ], joint: FLAT, outward: true,
                                                   miters: [ [ :front, :slope_b ], [ :front, :bottom ], [ :right, :back ], [ :slope_a, :slope_b ], [ :slope_a, :back ], [ :left, :back ], [ :left, :bottom ], [ :back, :bottom ] ] },
    # Degree 5 apex : on roof1's plane, roof3's side climbs from roof2's
    # thickness to the roof5 fan plane across roof4's thickness - two apexes
    # between its ground and up edges, and roof4's thickness tapers through
    # both. With one apex only, the roof1 side was missing
    'apex5_two_apexes_side_in' => { shape: :apex5, faces: [ :roof4, :roof2, :roof3 ], joint: FLAT, outward: false },
    'apex5_two_apexes_side_out' => { shape: :apex5, faces: [ :roof4, :roof2, :roof3 ], joint: FLAT, outward: true },
    # Degree 5 apex, roof3 mitered with its fan faces roof4 and roof5 : the
    # two bisectors meet the face corner on the ground level, outside the
    # ground section (pulled back by roof2's thickness) - an apex there is
    # not on the panel, the bisector side climbs through two apexes instead.
    # Known : wall1 tapers to an apex 0.04 mm off its up level (offset planes
    # nearly concurrent at the wall1/wall5/roof4/roof5 corner), a 0.004 mm²
    # side SketchUp refuses to draw
    'apex5_fan_bisectors_corner_mixed_in' => { shape: :apex5, faces: [ :wall5, :roof5, :roof2, :roof3, :roof4, :wall1 ], joint: FLAT, outward: false, known: 'tiny taper face',
                                               miters: [ [ :bottom, :wall1 ], [ :bottom, :wall2 ], [ :roof1, :wall4 ], [ :roof1, :roof5 ], [ :roof1, :roof3 ], [ :roof2, :roof4 ], [ :roof4, :roof5 ], [ :roof5, :wall5 ] ] },
  )

  def self.point(x, y, z)
    Geom::Point3d.new(x.mm, y.mm, z.mm)
  end

  # The shape as data : [ PanelingMeshDef, { name => face index } ]
  def self.mesh(shape)
    if PRISMS.key?(shape)
      outline = PRISMS[shape]
      area = outline.each_with_index.inject(0.0) { |sum, ((x1, y1), i)| x2, y2 = outline[(i + 1) % outline.size]; sum + x1 * y2 - x2 * y1 }
      outline = outline.reverse if area < 0
      n = outline.size
      points = outline.map { |x, y| point(x, y, 0) } + outline.map { |x, y| point(x, y, PRISM_HEIGHT) }
      loops = [ (0...n).to_a.reverse, (n...2 * n).to_a ] + (0...n).map { |i| [ i, (i + 1) % n, n + (i + 1) % n, n + i ] }
      names = { bottom: 0, top: 1 }
      n.times { |i| names["side#{i}".to_sym] = 2 + i }
      # The side names follow the outline AS WRITTEN
      if area < 0
        names = { bottom: 0, top: 1 }
        n.times { |i| names["side#{i}".to_sym] = 2 + (n - 2 - i) % n }
      end
    elsif SOLIDS.key?(shape)
      solid = SOLIDS[shape]
      points = solid[:points].map { |x, y, z| point(x, y, z) }
      loops = solid[:loops]
      names = {}
      solid[:names].each_with_index { |name, index| names[name] = index }
    else
      t = VALLEYS[shape]
      points = []
      loops = []
      names = {}
      VALLEY_FACES.each do |name, face_points|
        loops << face_points.map { |x, y, z|
          p = point(x, y, z).transform(t)
          index = points.index { |other| other == p }
          index.nil? ? (points << p; points.size - 1) : index
        }
        names[name] = loops.size - 1
      end
      loops.each(&:reverse!) if signed_volume(points, loops) < 0 # Mirrored
    end
    [ MESH.new(points, loops), names ]
  end

  def self.signed_volume(points, loops)
    loops.inject(0.0) { |sum, loop| n = MESH.loop_normal(points, loop); p = points[loop.first]; sum + (p.x * n.x + p.y * n.y + p.z * n.z) / 6.0 }
  end

  # The edge key between two named faces
  def self.edge(mesh, names, n1, n2)
    edge = (mesh.face_edges(mesh.faces[names[n1]]) & mesh.face_edges(mesh.faces[names[n2]])).first
    raise "No edge between #{n1} and #{n2}" if edge.nil?
    edge
  end

  # -- Run --

  # [ face indices, joint types ] of +spec+ on +mesh+
  def self.selection(mesh, names, spec)
    face_indices = spec[:faces] == :all ? mesh.faces.map(&:index) : spec[:faces].map { |name| names[name] || raise("No face #{name}") }
    joint_types = {}
    { MITER => spec[:miters], FLAT => spec[:flats] }.each do |joint, pairs|
      (pairs || []).each { |n1, n2| joint_types[edge(mesh, names, n1, n2)] = joint }
    end
    [ face_indices, joint_types ]
  end

  def self.thickness(outward)
    THICKNESS.mm * (outward ? 1 : -1)
  end

  # [ mesh, names, panel defs, face indices ]
  def self.compute(spec)
    mesh, names = mesh(spec[:shape])
    face_indices, joint_types = selection(mesh, names, spec)
    panel_defs = WORKER.new(mesh, face_indices,
                            thickness: thickness(spec[:outward]),
                            joint_types: joint_types,
                            default_joint_type: spec[:joint]
    ).run
    [ mesh, names, panel_defs, face_indices ]
  end

  # { count:, selected:, open:, unoriented:, bad:, overlaps:, volume: }
  def self.run_case(spec)
    mesh, _, panel_defs, face_indices = compute(spec)
    check(mesh, panel_defs, face_indices.size, thickness(spec[:outward]))
  end

  def self.check(mesh, panel_defs, selected, thickness)
    result = { count: panel_defs.size, selected: selected, open: 0, unoriented: 0, tiny: 0, bad: 0, overlaps: [], volume: 0.0 }
    solids = []
    panel_defs.each_with_index do |panel_def, index|
      corners, loops = conform(panel_def)
      if open_edges(loops) > 0
        result[:open] += 1
        next
      end
      loops = orient(corners, loops, panel_def, mesh.faces[panel_def.face_index].normal, thickness)
      if loops.nil?
        result[:unoriented] += 1
        next
      end
      # A face SketchUp can't draw leaves the drawn panel open
      if loops.any? { |loop| Math.sqrt(newell(corners, loop).inject(0.0) { |sum, v| sum + v * v }) / 2 < SKETCHUP_MIN_FACE_AREA }
        result[:tiny] += 1
        next
      end
      triangles = loops.flat_map { |loop| triangulate(corners, loop) }
      meshy_mesh = {
        vertices: corners.flat_map { |corner| corner.to_a.map(&:to_f) },
        face_indices: triangles.flatten,
        tolerance: MESHY_TOLERANCE
      }
      output = MESHY.operate(operation: MESHY::OPERATION_UNION, validate: true, tolerance: MESHY_TOLERANCE, src_meshes: [ meshy_mesh ], cut_meshes: [])
      if output['errors'] || output['error']
        result[:bad] += 1
        next
      end
      result[:volume] += triangles_volume(corners.map { |corner| corner.to_a.map(&:to_f) }, triangles).abs
      solids << [ index, meshy_mesh, bounds(corners) ]
    end
    solids.combination(2).each do |(ia, a, ba), (ib, b, bb)|
      next unless bounds_overlap?(ba, bb)
      output = MESHY.operate(operation: MESHY::OPERATION_INTERSECTION, validate: false, tolerance: MESHY_TOLERANCE, src_meshes: [ a ], cut_meshes: [ b ])
      # A fragment thinner than the tolerance on average (2 V / A) is a residue
      # of faces flush within it - SketchUp merges them, Meshy snaps them apart
      volume = (output['fragments'] || []).inject(0.0) { |sum, fragment|
        points = fragment['vertices'].each_slice(3).to_a
        triangles = fragment['face_indices'].each_slice(3).to_a
        fragment_volume = triangles_volume(points, triangles).abs
        area = triangles_area(points, triangles)
        area > 0 && 2 * fragment_volume / area < MESHY_TOLERANCE ? sum : sum + fragment_volume
      }
      volume *= CUBIC_INCH_TO_LITER * 1000
      result[:overlaps] << "#{ia}/#{ib} #{volume.round(2)}cm³" if volume > OVERLAP_MAX
    end
    result[:volume] *= CUBIC_INCH_TO_LITER
    result
  end

  # -- Polygon soup to solid --

  # [ corners, loops ] : the panel's distinct corners (SketchUp tolerance), its
  # polygons as corner index loops, each edge split where another corner
  # lies on it - a conforming soup
  def self.conform(panel_def)
    corners = []
    fn_id = lambda { |point| corners.index { |corner| corner == point } || (corners << point; corners.size - 1) }
    loops = (panel_def.gd_polygons + panel_def.up_polygons + panel_def.sides).map { |polygon|
      loop = polygon.map(&fn_id).chunk_while { |a, b| a == b }.map(&:first)
      loop.pop while loop.size > 1 && loop.last == loop.first
      loop
    }
    loops = loops.map { |loop|
      loop.each_with_index.flat_map { |a, i|
        b = loop[(i + 1) % loop.size]
        pa = corners[a]
        pb = corners[b]
        line = [ pa, pa.vector_to(pb) ]
        inner = corners.each_index.select { |c| c != a && c != b && corners[c].on_line?(line) && pa.vector_to(corners[c]).dot(corners[c].vector_to(pb)) > 0 }
        [ a ] + inner.sort_by { |c| pa.distance(corners[c]).to_f }
      }
    }
    [ corners, loops ]
  end

  # The edges not bordered by exactly two loops
  def self.open_edges(loops)
    counts = Hash.new(0)
    loops.each { |loop| loop.each_with_index { |a, i| b = loop[(i + 1) % loop.size]; counts[[ a, b ].minmax] += 1 } }
    counts.count { |_, count| count != 2 }
  end

  def self.newell(points, loop)
    x = y = z = 0.0
    loop.each_with_index do |index, i|
      p1 = points[index]
      p2 = points[loop[(i + 1) % loop.size]]
      x += (p1[1] - p2[1]) * (p1[2] + p2[2])
      y += (p1[2] - p2[2]) * (p1[0] + p2[0])
      z += (p1[0] - p2[0]) * (p1[1] + p2[1])
    end
    [ x, y, z ]
  end

  # The loops turned outward, or nil when no consistent winding exists : the
  # ground ones against the thickness, the up ones along it, the others
  # agreeing with their neighbours across each edge
  def self.orient(corners, loops, panel_def, normal, thickness)
    points = corners.map { |corner| corner.to_a.map(&:to_f) }
    sign = thickness > 0 ? 1 : -1
    gd_count = panel_def.gd_polygons.size
    up_count = panel_def.up_polygons.size
    n = normal.to_a.map(&:to_f)
    directed = Hash.new { |hash, key| hash[key] = [] }
    loops.each_with_index { |loop, i| loop.each_with_index { |a, k| directed[[ a, loop[(k + 1) % loop.size] ]] << i } }
    keep = Array.new(loops.size)
    queue = []
    loops.each_index do |i|
      next if i >= gd_count + up_count
      wanted = i < gd_count ? -sign : sign
      newell = newell(points, loops[i])
      keep[i] = (newell[0] * n[0] + newell[1] * n[1] + newell[2] * n[2]) * wanted > 0
      queue << i
    end
    until queue.empty?
      i = queue.shift
      loop = keep[i] ? loops[i] : loops[i].reverse
      loop.each_with_index do |a, k|
        b = loop[(k + 1) % loop.size]
        # A neighbour must run b -> a once turned : as is if it runs b -> a, reversed if a -> b
        [ [ [ a, b ], false ], [ [ b, a ], true ] ].each do |edge, wanted|
          directed[edge].each do |j|
            next if j == i
            if keep[j].nil?
              keep[j] = wanted
              queue << j
            elsif keep[j] != wanted
              return nil
            end
          end
        end
      end
    end
    return nil if keep.any?(&:nil?)
    loops.each_with_index.map { |loop, i| keep[i] ? loop : loop.reverse }
  end

  # Ear clipping in the loop's plane, its winding kept. A corner lying on a
  # candidate ear blocks it, so that split edges stay conforming.
  def self.triangulate(corners, loop)
    points = corners.map { |corner| corner.to_a.map(&:to_f) }
    normal = newell(points, loop)
    k = normal.each_index.max_by { |i| normal[i].abs }
    u, v = [ [ 1, 2 ], [ 2, 0 ], [ 0, 1 ] ][k]
    u, v = v, u if normal[k] < 0
    pts = loop.map { |index| [ points[index][u], points[index][v] ] }
    fn_cross = lambda { |a, b, c| (pts[b][0] - pts[a][0]) * (pts[c][1] - pts[a][1]) - (pts[b][1] - pts[a][1]) * (pts[c][0] - pts[a][0]) }
    fn_blocks = lambda { |o, a, b, c|
      d1 = fn_cross.call(a, b, o)
      d2 = fn_cross.call(b, c, o)
      d3 = fn_cross.call(c, a, o)
      d1 >= -1e-12 && d2 >= -1e-12 && d3 >= -1e-12
    }
    remaining = (0...loop.size).to_a
    triangles = []
    while remaining.size > 3
      m = remaining.each_index.find { |i|
        a, b, c = remaining[i - 1], remaining[i], remaining[(i + 1) % remaining.size]
        fn_cross.call(a, b, c) > 1e-12 && remaining.none? { |o| o != a && o != b && o != c && pts[o] != pts[a] && pts[o] != pts[b] && pts[o] != pts[c] && fn_blocks.call(o, a, b, c) }
      }
      m ||= remaining.each_index.max_by { |i| fn_cross.call(remaining[i - 1], remaining[i], remaining[(i + 1) % remaining.size]) }
      a, b, c = remaining[m - 1], remaining[m], remaining[(m + 1) % remaining.size]
      triangles << [ loop[a], loop[b], loop[c] ] if fn_cross.call(a, b, c) > 1e-12
      remaining.delete_at(m)
    end
    triangles << remaining.map { |i| loop[i] } if fn_cross.call(*remaining) > 1e-12
    triangles
  end

  def self.triangles_volume(points, triangles)
    triangles.inject(0.0) { |sum, (a, b, c)|
      p, q, r = points[a], points[b], points[c]
      sum + (p[0] * (q[1] * r[2] - q[2] * r[1]) - p[1] * (q[0] * r[2] - q[2] * r[0]) + p[2] * (q[0] * r[1] - q[1] * r[0])) / 6.0
    }
  end

  def self.triangles_area(points, triangles)
    triangles.inject(0.0) { |sum, (a, b, c)|
      p, q, r = points[a], points[b], points[c]
      u = [ q[0] - p[0], q[1] - p[1], q[2] - p[2] ]
      v = [ r[0] - p[0], r[1] - p[1], r[2] - p[2] ]
      sum + Math.sqrt((u[1] * v[2] - u[2] * v[1])**2 + (u[2] * v[0] - u[0] * v[2])**2 + (u[0] * v[1] - u[1] * v[0])**2) / 2.0
    }
  end

  def self.bounds(corners)
    coordinates = corners.map { |corner| corner.to_a.map(&:to_f) }.transpose
    [ coordinates.map(&:min), coordinates.map(&:max) ]
  end

  def self.bounds_overlap?(a, b)
    (0..2).all? { |i| a[0][i] <= b[1][i] && b[0][i] <= a[1][i] }
  end

  # -----

  def self.failure(result, spec = {})
    return "#{result[:count]} panels for #{result[:selected]} faces" unless result[:count] == result[:selected]
    return "#{result[:open]} open" if result[:open] > 0
    return "#{result[:unoriented]} unoriented" if result[:unoriented] > 0
    return "#{result[:tiny]} with a face too small for SketchUp" if result[:tiny] > 0
    return "#{result[:bad]} invalid for Meshy" if result[:bad] > 0
    return "overlaps #{result[:overlaps].join(', ')}" if result[:overlaps].any?
    return "volume #{result[:volume].round(2)} L expected #{spec[:volume]}" if spec[:volume] && (result[:volume] - spec[:volume]).abs > VOLUME_TOLERANCE
    nil
  end

  # { name => [ failure or nil, result ] }
  def self.results(names = CASES.keys)
    results = {}
    names.each do |name|
      spec = CASES[name]
      result = run_case(spec)
      results[name] = [ failure(result, spec), result ]
    end
    results
  end

  def self.run(names = CASES.keys)
    results(names).map { |name, (failure, result)|
      status = if CASES[name][:known]
                 failure.nil? ? 'FIXED?' : "KNOWN(#{CASES[name][:known]} : #{failure})"
               else
                 failure.nil? ? 'PASS' : "FAIL(#{failure})"
               end
      "#{name} #{status} — #{result[:count]} panels, #{result[:volume].round(2)} L"
    }.join("\n")
  end

  # -- Random corpus --

  JOINT_MODES = [ :flat, :miter, :mixed ].freeze
  SEEDS = 30

  # Random cases failing on an open defect, reported KNOWN : key => why
  KNOWN_RANDOM = {}.freeze

  def self.random_key(shape, seed, outward)
    "#{shape} seed=#{seed} #{JOINT_MODES[seed % JOINT_MODES.size]} #{outward ? 'out' : 'in'}"
  end

  # The seeded random case, as a named case spec - to replay it alone through
  # run_case, or paste it into CASES
  def self.random_spec(shape, seed, outward)
    srand(seed * 31 + shape.to_s.size + (outward ? 7 : 0))
    mode = JOINT_MODES[seed % JOINT_MODES.size]
    mesh, names = mesh(shape)
    face_names = names.invert
    faces = mesh.faces
    selection = seed == 0 ? faces : faces.select { rand < 0.6 }
    selection = faces.sample(2) if selection.size < 2
    miters = []
    if mode == :mixed
      faces.flat_map { |face| mesh.face_edges(face) }.uniq.each do |edge|
        miters << mesh.edge_faces(edge).map { |face| face_names[face.index] } if rand < 0.5
      end
    end
    spec = {
      shape: shape,
      faces: selection.shuffle.map { |face| face_names[face.index] },
      joint: mode == :miter ? MITER : FLAT,
      outward: outward,
    }
    spec[:miters] = miters if miters.any?
    spec
  end

  # Seeded random cases : [ key, failure or nil ]
  def self.random_results(seeds: SEEDS, shapes: SHAPES)
    results = []
    shapes.each do |shape|
      seeds.times do |seed|
        [ false, true ].each do |outward|
          results << [ random_key(shape, seed, outward), failure(run_case(random_spec(shape, seed, outward))) ]
        end
      end
    end
    results
  end

  def self.run_random(seeds: SEEDS, shapes: SHAPES)
    results = random_results(seeds: seeds, shapes: shapes)
    lines = results.map { |key, failure|
      if KNOWN_RANDOM.key?(key)
        failure.nil? ? "#{key} FIXED?" : "#{key} KNOWN(#{KNOWN_RANDOM[key]} : #{failure})"
      elsif !failure.nil?
        "#{key} FAIL(#{failure})"
      end
    }.compact
    passed = results.count { |key, failure| failure.nil? && !KNOWN_RANDOM.key?(key) }
    (lines + [ "#{passed}/#{results.size - KNOWN_RANDOM.size} OK, #{KNOWN_RANDOM.size} known" ]).join("\n")
  end

end

if defined?(TestUp::TestCase)

  class TC_Ladb_Worker_PanelingCompute < TestUp::TestCase

    def test_cases
      PanelingRegression.results.each do |name, (failure, result)|
        next if PanelingRegression::CASES[name][:known]
        assert(failure.nil?, "#{name} : #{failure}\n#{result.inspect}")
      end
    end

    def test_random
      failures = PanelingRegression.random_results.reject { |key, failure| failure.nil? || PanelingRegression::KNOWN_RANDOM.key?(key) }
      assert(failures.empty?, failures.map { |key, failure| "#{key} : #{failure}" }.join("\n"))
    end

  end

end
