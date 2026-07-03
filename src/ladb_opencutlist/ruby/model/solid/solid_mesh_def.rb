module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../drawing/drawing_def'
  require_relative '../../manipulator/face_manipulator'

  # Group of source faces connected together by soft edges.
  # Instances carry no data : only their identity is used to restore edge softness after a boolean operation.
  class SolidSurfaceInfoDef < DataContainer
  end

  # Captures everything needed to reconstruct a source face after the boolean operation,
  # while the original Sketchup::Face may have been erased.
  class SolidFaceInfoDef < DataContainer

    attr_reader :face_id, :material, :layer, :surface_info_def

    def initialize(face_id, material: nil, layer: nil, surface_info_def: nil)
      @face_id = face_id                      # Original face persistent_id (debug / traceability)
      @material = material                    # Sketchup::Material (inheritance already resolved)
      @layer = layer                          # Sketchup::Layer
      @surface_info_def = surface_info_def    # SolidSurfaceInfoDef or nil
    end

  end

  # Intermediate representation of a solid, expressed in WORLD coordinates,
  # decoupled from SketchUp entities (which may be erased afterwards).
  #
  # The geometry is always triangulated : the Meshy native lib only accepts triangles.
  # @face_ids holds one entry per triangle : the index of the corresponding SolidFaceInfoDef
  # in @face_info_defs. This provenance is propagated by Manifold through the boolean
  # operation and drives materials, layers and coplanar merging on reconstruction.
  class SolidMeshDef < DataContainer

    # SketchUp merge tolerance (1/1000 inch) : geometry closer than this cannot exist
    # as separate entities in SketchUp, so Manifold may treat it as coincident.
    # Absorbs near-coplanar faces that would otherwise leave sliver residues.
    TOLERANCE = 0.001

    attr_reader :vertices,        # Array<Float> flat [ x, y, z, x, y, z, ... ]
                :face_indices,    # Array<Integer> flat, 3 per triangle
                :face_ids,        # Array<Integer> 1 per triangle -> index in @face_info_defs
                :face_info_defs   # Array<SolidFaceInfoDef>

    def initialize
      @vertices = []
      @face_indices = []
      @face_ids = []
      @face_info_defs = []
      @vertex_index_map = {}
    end

    # -----

    def self.from_drawing_def(drawing_def)
      return nil unless drawing_def.is_a?(DrawingDef)
      from_face_manipulators(drawing_def.face_manipulators)
    end

    # transformation : parent -> world transformation of the entity
    def self.from_entity(entity, transformation: IDENTITY)
      return nil unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      inner_transformation = transformation * entity.transformation
      from_face_manipulators(entity.definition.entities.grep(Sketchup::Face).map { |face| FaceManipulator.new(face, inner_transformation, entity.material, entity.layer) })
    end

    def self.from_face_manipulators(face_manipulators)
      mesh_def = new
      mesh_def._populate(face_manipulators)
      mesh_def
    end

    # -----

    def empty?
      @face_indices.empty?
    end

    def triangle_count
      @face_indices.length / 3
    end

    def vertex_count
      @vertices.length / 3
    end

    # Signed volume (positive if triangles are consistently wound with outward normals)
    def volume
      volume = 0.0
      @face_indices.each_slice(3) do |i0, i1, i2|
        x0, y0, z0 = @vertices[i0 * 3], @vertices[i0 * 3 + 1], @vertices[i0 * 3 + 2]
        x1, y1, z1 = @vertices[i1 * 3], @vertices[i1 * 3 + 1], @vertices[i1 * 3 + 2]
        x2, y2, z2 = @vertices[i2 * 3], @vertices[i2 * 3 + 1], @vertices[i2 * 3 + 2]
        volume += x0 * (y1 * z2 - y2 * z1) - y0 * (x1 * z2 - x2 * z1) + z0 * (x1 * y2 - x2 * y1)
      end
      volume / 6.0
    end

    # Returns a list of i18n error tuples. Empty if the mesh is a valid closed solid.
    def validation_errors
      return [ [ 'core.solid.error.empty' ] ] if empty?

      # A watertight, consistently oriented triangle mesh has every directed edge
      # appearing exactly once, paired with its reverse.
      directed_edges = {}
      @face_indices.each_slice(3) do |i0, i1, i2|
        [ [ i0, i1 ], [ i1, i2 ], [ i2, i0 ] ].each do |edge|
          directed_edges[edge] = (directed_edges[edge] || 0) + 1
        end
      end

      duplicated_count = directed_edges.count { |edge, count| count > 1 }
      return [ [ 'core.solid.error.non_manifold_edges', { :count => duplicated_count } ] ] if duplicated_count > 0

      open_count = directed_edges.count { |edge, _| !directed_edges.key?(edge.reverse) }
      return [ [ 'core.solid.error.open_edges', { :count => open_count } ] ] if open_count > 0

      []
    end

    def manifold?
      validation_errors.empty?
    end

    # -----

    # Returns [ [ area2, [ nx, ny, nz, d ] ], ... ] : one plane per original face
    # (with n·p = d), computed from the largest triangle of the face for numerical
    # stability, weighted by that triangle's squared area.
    # The normal is canonically oriented (first significant component positive) so
    # that opposite-facing coplanar faces yield comparable planes.
    def weighted_face_planes
      best = {}
      @face_indices.each_slice(3).with_index do |(i0, i1, i2), triangle_index|

        x0, y0, z0 = @vertices[i0 * 3], @vertices[i0 * 3 + 1], @vertices[i0 * 3 + 2]
        x1, y1, z1 = @vertices[i1 * 3], @vertices[i1 * 3 + 1], @vertices[i1 * 3 + 2]
        x2, y2, z2 = @vertices[i2 * 3], @vertices[i2 * 3 + 1], @vertices[i2 * 3 + 2]

        nx = (y1 - y0) * (z2 - z0) - (z1 - z0) * (y2 - y0)
        ny = (z1 - z0) * (x2 - x0) - (x1 - x0) * (z2 - z0)
        nz = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
        area2 = nx * nx + ny * ny + nz * nz
        next if area2 == 0.0

        face_index = @face_ids[triangle_index]
        next if best.key?(face_index) && best[face_index][0] >= area2

        length = Math.sqrt(area2)
        nx /= length
        ny /= length
        nz /= length
        if nx < -1e-9 || (nx.abs <= 1e-9 && (ny < -1e-9 || (ny.abs <= 1e-9 && nz < 0)))
          nx, ny, nz = -nx, -ny, -nz
        end

        # Snap near-axis normals to the exact axis direction. Projection onto an exact
        # axis plane assigns the exact same coordinate (d) to every projected vertex of
        # every operand, achieving true exact coplanarity. A projection onto a plane
        # tilted by ~1e-16 (numerical noise of the source triangle) would leave ~1e-15
        # off-plane rounding residues, which Manifold's exact arithmetic still sees as
        # crossing surfaces, producing epsilon-thin residues.
        if ny.abs <= 1e-9 && nz.abs <= 1e-9
          nx, ny, nz = 1.0, 0.0, 0.0
        elsif nx.abs <= 1e-9 && nz.abs <= 1e-9
          nx, ny, nz = 0.0, 1.0, 0.0
        elsif nx.abs <= 1e-9 && ny.abs <= 1e-9
          nx, ny, nz = 0.0, 0.0, 1.0
        end

        best[face_index] = [ area2, [ nx, ny, nz, nx * x0 + ny * y0 + nz * z0 ] ]

      end
      best.values
    end

    def face_planes
      weighted_face_planes.map { |_, plane| plane }
    end

    # True if the plane is one of the exact axis-aligned planes produced by
    # weighted_face_planes' normal quantization.
    def self.axis_plane?(plane)
      nx, ny, nz, _ = plane
      (nx == 1.0 && ny == 0.0 && nz == 0.0) || (nx == 0.0 && ny == 1.0 && nz == 0.0) || (nx == 0.0 && ny == 0.0 && nz == 1.0)
    end

    # Builds a deduplicated plane set from all the given meshes : planes that are
    # identical within tolerance are represented once, by the instance backed by the
    # largest triangle. Snapping EVERY vertex of EVERY operand onto this canonical
    # set makes each face exactly planar and faces meant to be coplanar between
    # operands exactly coplanar.
    def self.canonical_planes(mesh_defs, tolerance: TOLERANCE)
      canonical = []
      mesh_defs.flat_map(&:weighted_face_planes).sort_by { |area2, _| -area2 }.each do |_, plane|
        nx, ny, nz, d = plane
        merged = canonical.any? { |cx, cy, cz, cd| nx * cx + ny * cy + nz * cz > 1.0 - 1e-8 && (d - cd).abs <= tolerance }
        canonical << plane unless merged
      end
      canonical
    end

    # Projects every vertex closer than tolerance to one of the given planes onto it,
    # so that faces meant to be coplanar with the other operand become EXACTLY coplanar.
    # Without this, boolean operations leave epsilon-thin residues (closed cavities,
    # slivers) between nearly coincident faces.
    # Iterated a few times so that vertices near several planes (shared edges, corners)
    # converge to the planes intersection.
    def snap_to_planes!(planes, tolerance = TOLERANCE)
      return if planes.empty? || empty?

      # Project onto non-axis planes first and exact-axis planes last : axis planes are
      # orthogonal to each other, so late axis projections do not disturb one another
      # and the vertex ends EXACTLY on every nearby axis plane (the only exactness
      # achievable in doubles, and the one coplanarity snapping relies on). A tilted
      # plane projected last would drag the vertex ~1e-14 off the axis planes.
      non_axis_planes, axis_planes = planes.partition { |plane| !SolidMeshDef.axis_plane?(plane) }
      planes = non_axis_planes + axis_planes

      (0...vertex_count).each do |vertex_index|
        x = @vertices[vertex_index * 3]
        y = @vertices[vertex_index * 3 + 1]
        z = @vertices[vertex_index * 3 + 2]
        3.times do
          planes.each do |nx, ny, nz, d|
            dist = x * nx + y * ny + z * nz - d
            next if dist == 0.0 || dist.abs > tolerance
            x -= dist * nx
            y -= dist * ny
            z -= dist * nz
          end
        end
        @vertices[vertex_index * 3] = x
        @vertices[vertex_index * 3 + 1] = y
        @vertices[vertex_index * 3 + 2] = z
      end
      nil
    end

    # If the mesh has at least one triangle lying on the given plane (its three
    # vertices within tolerance), returns +1.0 / -1.0 : the sign of the outward
    # normal of those triangles against the plane normal (area weighted).
    # Returns nil if no triangle lies on the plane.
    def outward_sign_on_plane(plane, tolerance = TOLERANCE)
      pnx, pny, pnz, pd = plane
      distances = (0...vertex_count).map { |vertex_index|
        @vertices[vertex_index * 3] * pnx + @vertices[vertex_index * 3 + 1] * pny + @vertices[vertex_index * 3 + 2] * pnz - pd
      }
      sum = 0.0
      @face_indices.each_slice(3) do |i0, i1, i2|
        next unless distances[i0].abs <= tolerance && distances[i1].abs <= tolerance && distances[i2].abs <= tolerance
        x0, y0, z0 = @vertices[i0 * 3], @vertices[i0 * 3 + 1], @vertices[i0 * 3 + 2]
        x1, y1, z1 = @vertices[i1 * 3], @vertices[i1 * 3 + 1], @vertices[i1 * 3 + 2]
        x2, y2, z2 = @vertices[i2 * 3], @vertices[i2 * 3 + 1], @vertices[i2 * 3 + 2]
        nx = (y1 - y0) * (z2 - z0) - (z1 - z0) * (y2 - y0)
        ny = (z1 - z0) * (x2 - x0) - (x1 - x0) * (z2 - z0)
        nz = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
        sum += nx * pnx + ny * pny + nz * pnz
      end
      return nil if sum == 0.0
      sum > 0.0 ? 1.0 : -1.0
    end

    # Translates every vertex lying within tolerance of the plane by offset along
    # the plane normal (offset may be negative).
    def offset_vertices_near_plane!(plane, offset, tolerance = TOLERANCE)
      nx, ny, nz, d = plane
      (0...vertex_count).each do |vertex_index|
        x = @vertices[vertex_index * 3]
        y = @vertices[vertex_index * 3 + 1]
        z = @vertices[vertex_index * 3 + 2]
        next if (x * nx + y * ny + z * nz - d).abs > tolerance
        @vertices[vertex_index * 3] = x + nx * offset
        @vertices[vertex_index * 3 + 1] = y + ny * offset
        @vertices[vertex_index * 3 + 2] = z + nz * offset
      end
      nil
    end

    # -----

    # Serialization to the mesh format expected by Fiddle::Meshy.operate.
    # id_offset shifts face ids so that several mesh defs can share a single
    # face info registry within one operation.
    def to_meshy_hash(id_offset: 0)
      {
        :vertices => @vertices,
        :face_indices => @face_indices,
        :face_ids => id_offset == 0 ? @face_ids : @face_ids.map { |id| id + id_offset },
        :num_vertices => vertex_count,
        :num_faces => triangle_count,
        :tolerance => TOLERANCE
      }
    end

    # -----

    def _populate(face_manipulators)

      surface_info_defs = _compute_surface_info_defs(face_manipulators)

      face_manipulators.each do |face_manipulator|
        face = face_manipulator.face

        face_index = @face_info_defs.length
        @face_info_defs << SolidFaceInfoDef.new(
          face.respond_to?(:persistent_id) ? face.persistent_id : nil,
          material: face_manipulator.material,
          layer: face_manipulator.layer,
          surface_info_def: surface_info_defs[face]
        )

        mesh = face_manipulator.mesh
        mesh.polygons.each do |polygon|
          indices = polygon.map { |vertex_index| _vertex_index(mesh.point_at(vertex_index.abs)) }
          next if indices.uniq.length < 3 # Skip degenerate triangles collapsed by vertex welding
          @face_indices.concat(indices)
          @face_ids << face_index
        end

      end

      # Manifold interprets winding as defining solidity : make sure normals point outward
      _flip! if volume < 0

    end

    # -----

    private

    def _vertex_index(point)
      key = point.to_a
      index = @vertex_index_map[key]
      if index.nil?
        index = vertex_count
        @vertex_index_map[key] = index
        @vertices.concat(key)
      end
      index
    end

    def _flip!
      @face_indices.each_slice(3).with_index do |(i0, i1, i2), triangle_index|
        @face_indices[triangle_index * 3 + 1] = i2
        @face_indices[triangle_index * 3 + 2] = i1
      end
    end

    # Flood fill over soft edges to group faces belonging to the same curved surface.
    # Returns Hash<Sketchup::Face, SolidSurfaceInfoDef> (faces not part of a surface are absent).
    def _compute_surface_info_defs(face_manipulators)

      surface_info_defs = {}
      face_set = {}
      face_manipulators.each { |face_manipulator| face_set[face_manipulator.face] = true }

      face_set.each_key do |face|
        next if surface_info_defs.key?(face)
        next unless face.edges.any? { |edge| edge.soft? }

        surface_info_def = SolidSurfaceInfoDef.new
        stack = [ face ]
        until stack.empty?
          current_face = stack.pop
          next if surface_info_defs.key?(current_face)
          surface_info_defs[current_face] = surface_info_def
          current_face.edges.each do |edge|
            next unless edge.soft?
            edge.faces.each do |connected_face|
              stack << connected_face if face_set.key?(connected_face) && !surface_info_defs.key?(connected_face)
            end
          end
        end

      end

      surface_info_defs
    end

  end

end