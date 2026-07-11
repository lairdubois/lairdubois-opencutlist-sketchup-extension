module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../drawing/drawing_def'
  require_relative '../../utils/transformation_utils'

  # Group of source faces connected together by soft edges.
  # Instances carry no data: only their identity is used to restore edge softness after a boolean operation.
  class SolidSurfaceInfoDef < DataContainer
  end

  # Captures the segments (WORLD coordinates) of a source Sketchup::Curve, so that
  # surviving pieces can be re-welded into a curve after the boolean operation.
  # ArcCurve metadata (center, radius) is not restorable : pieces come back as
  # plain curves, as SketchUp native solid tools do.
  class SolidCurveInfoDef < DataContainer

    attr_reader :segments   # Array<[ Geom::Point3d, Geom::Point3d ]>, one per source edge

    def initialize
      @segments = []
    end

  end

  # Captures everything needed to reconstruct a source face after the boolean operation,
  # while the original Sketchup::Face may have been erased.
  class SolidFaceInfoDef < DataContainer

    attr_reader :face_id, :material, :layer, :surface_info_def, :container_def

    def initialize(face_id, material: nil, layer: nil, surface_info_def: nil, container_def: nil, virtual: false)
      @face_id = face_id                      # Original face persistent_id (debug / traceability)
      @material = material                    # Sketchup::Material (inheritance already resolved)
      @layer = layer                          # Sketchup::Layer
      @surface_info_def = surface_info_def    # SolidSurfaceInfoDef or nil
      @container_def = container_def          # DrawingContainerDef node the source face belongs to (nil if unknown)
      @virtual = virtual                      # Face of a glued cuts-opening container : closes the shell during the computation but is not rebuilt
    end

    def virtual?
      @virtual
    end

  end

  # Intermediate representation of a solid, expressed in WORLD coordinates,
  # decoupled from SketchUp entities (which may be erased afterwards).
  #
  # The geometry is always triangulated: the Meshy native lib only accepts triangles.
  # @face_ids holds one entry per triangle: the index of the corresponding SolidFaceInfoDef
  # in @face_info_defs. This provenance is propagated by Manifold through the boolean
  # operation and drives materials, layers and coplanar merging on reconstruction.
  #
  # Meshes are sent RAW to Meshy: validation, winding correction, plane
  # canonicalization, snapping and nudging all run natively in the lib.
  class SolidMeshDef < DataContainer

    # SketchUp merge tolerance (1/1000 inch): geometry closer than this cannot exist
    # as separate entities in SketchUp, so Manifold may treat it as coincident.
    # Absorbs near-coplanar faces that would otherwise leave sliver residues.
    TOLERANCE = 0.001

    attr_reader :vertices,        # Array<Float> flat [ x, y, z, x, y, z, ... ]
                :face_indices,    # Array<Integer> flat, 3 per triangle
                :face_ids,        # Array<Integer> 1 per triangle -> index in @face_info_defs
                :face_info_defs,  # Array<SolidFaceInfoDef>
                :curve_info_defs  # Array<SolidCurveInfoDef>

    def initialize
      @vertices = []
      @face_indices = []
      @face_ids = []
      @face_info_defs = []
      @curve_info_defs = []
      @vertex_index_map = {}
    end

    # -----

    # Collects the faces of the whole drawing def tree (sub containers included),
    # one populate pass per container node so that each face info carries its
    # source node (SolidFaceInfoDef#container_def). Manipulator coordinates are
    # expressed in the drawing def space : drawing_def.transformation is composed
    # so the mesh ends up in WORLD coordinates, the only space common to all
    # operands of a boolean operation.
    #
    # Glued cuts-opening containers (virtual machinings : SketchUp punches their
    # opening in the host face tessellation) are marked virtual, subtree
    # included : their faces close the shell for the computation but are not
    # meant to be rebuilt, and their instances are not operands.
    def self.from_drawing_def(drawing_def)
      return nil unless drawing_def.is_a?(DrawingDef)
      mesh_def = new
      fn_populate = lambda { |container_def, virtual|
        mesh_def._populate(container_def.face_manipulators, drawing_def.transformation, container_def: container_def, virtual: virtual)
        container_def.container_defs.each { |child_def| fn_populate.call(child_def, virtual || virtual_glued_container?(child_def.container)) }
      }
      fn_populate.call(drawing_def, false)
      mesh_def
    end

    # A glued cuts-opening container is a virtual machining : its geometry only
    # closes the shell (whose host face tessellation is punched by SketchUp),
    # the instance itself must survive the boolean operation, glued.
    def self.virtual_glued_container?(container)
      return false unless container.is_a?(Sketchup::ComponentInstance) || container.is_a?(Sketchup::Group)
      return false unless container.respond_to?(:glued_to) && !container.glued_to.nil?
      container.definition.behavior.cuts_opening?
    end

    # transformation : applied on top of each manipulator's own transformation
    def self.from_face_manipulators(face_manipulators, transformation: IDENTITY)
      mesh_def = new
      mesh_def._populate(face_manipulators, transformation)
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

    private

    def _populate(face_manipulators, transformation = IDENTITY, container_def: nil, virtual: false)

      transformation = nil if transformation.nil? || transformation.identity?

      surface_info_defs = _compute_surface_info_defs(face_manipulators)

      # The same Sketchup::Face may appear under several manipulators when a
      # definition is instanced more than once in the tree : curves and surfaces
      # are keyed by [ entity, context ] where context identifies the instance
      # through the manipulator transformation value.
      curve_info_defs_by_key = {}
      processed_curve_edge_keys = {}

      face_manipulators.each do |face_manipulator|
        face = face_manipulator.face
        context_key = face_manipulator.transformation.to_a

        face_index = @face_info_defs.length
        @face_info_defs << SolidFaceInfoDef.new(
          face.respond_to?(:persistent_id) ? face.persistent_id : nil,
          material: face_manipulator.material,
          layer: face_manipulator.layer,
          surface_info_def: surface_info_defs[[ face, context_key ]],
          container_def: container_def,
          virtual: virtual
        )

        composed_transformation = transformation.nil? ? face_manipulator.transformation : transformation * face_manipulator.transformation

        # Capture the segments of the curves bounding this face (single-edge curves
        # carry no welding information : ignored). Segments are stored in WORLD
        # coordinates. Virtual geometry is not rebuilt : nothing to capture.
        unless virtual
          face.edges.each do |edge|
            curve = edge.curve
            next if curve.nil? || curve.edges.length < 2
            edge_key = [ edge.entityID, context_key ]
            next if processed_curve_edge_keys.key?(edge_key)
            processed_curve_edge_keys[edge_key] = true
            curve_key = [ curve, context_key ]
            curve_info_def = curve_info_defs_by_key[curve_key]
            if curve_info_def.nil?
              curve_info_def = SolidCurveInfoDef.new
              curve_info_defs_by_key[curve_key] = curve_info_def
              @curve_info_defs << curve_info_def
            end
            curve_info_def.segments << [
              edge.start.position.transform(composed_transformation),
              edge.end.position.transform(composed_transformation)
            ]
          end
        end

        # A mirror transformation (negative determinant) reverses the winding of
        # the transformed triangles : re-reverse it so every face keeps its
        # outward orientation whatever container instance it comes from (nodes
        # of the same solid may be mirrored independently).
        flipped = TransformationUtils.flipped?(composed_transformation)

        mesh = face_manipulator.mesh
        mesh.polygons.each do |polygon|
          indices = polygon.map { |vertex_index|
            point = mesh.point_at(vertex_index.abs)
            point = point.transform(transformation) unless transformation.nil?
            _vertex_index(point)
          }
          next if indices.uniq.length < 3 # Skip degenerate triangles collapsed by vertex welding
          indices.reverse! if flipped
          @face_indices.concat(indices)
          @face_ids << face_index
        end

      end

    end

    # -----

    # Welds vertices within TOLERANCE : the same world point reached through
    # two different transformation chains (e.g. a host face and the glued
    # cuts-opening container punching it, each composing its own manipulator
    # transformations) drifts by a few double ulps, and Meshy validates the
    # shell topologically (per vertex INDEX) before any snapping — unwelded
    # duplicates read as open edges. Vertices are hashed by tolerance grid
    # cell ; the neighbor cells are scanned so that a pair straddling a cell
    # boundary is welded too, with a real distance gate so that two vertices
    # farther than TOLERANCE never weld.
    def _vertex_index(point)
      coordinates = point.to_a
      cell = coordinates.map { |v| (v / TOLERANCE).round }

      index = @vertex_index_map[cell]
      index = nil unless !index.nil? && _within_tolerance?(index, coordinates)
      if index.nil?
        (-1..1).each do |dx|
          (-1..1).each do |dy|
            (-1..1).each do |dz|
              next if dx == 0 && dy == 0 && dz == 0
              neighbor_index = @vertex_index_map[[ cell[0] + dx, cell[1] + dy, cell[2] + dz ]]
              next if neighbor_index.nil? || !_within_tolerance?(neighbor_index, coordinates)
              index = neighbor_index
              break
            end
            break unless index.nil?
          end
          break unless index.nil?
        end
      end

      if index.nil?
        index = vertex_count
        @vertex_index_map[cell] = index
        @vertices.concat(coordinates)
      end
      index
    end

    def _within_tolerance?(index, coordinates)
      dx = @vertices[index * 3] - coordinates[0]
      dy = @vertices[index * 3 + 1] - coordinates[1]
      dz = @vertices[index * 3 + 2] - coordinates[2]
      dx * dx + dy * dy + dz * dz <= TOLERANCE * TOLERANCE
    end

    # Flood fill over soft edges to group faces belonging to the same curved surface.
    # Runs per context (manipulator transformation value) so that two instances of
    # the same definition produce two distinct surfaces.
    # Returns Hash<[ Sketchup::Face, context_key ], SolidSurfaceInfoDef> (faces not
    # part of a surface are absent).
    def _compute_surface_info_defs(face_manipulators)

      surface_info_defs = {}

      face_manipulators.group_by { |face_manipulator| face_manipulator.transformation.to_a }.each do |context_key, context_face_manipulators|

        face_set = {}
        context_face_manipulators.each { |face_manipulator| face_set[face_manipulator.face] = true }

        face_set.each_key do |face|
          next if surface_info_defs.key?([ face, context_key ])
          next unless face.edges.any? { |edge| edge.soft? }

          surface_info_def = SolidSurfaceInfoDef.new
          stack = [ face ]
          until stack.empty?
            current_face = stack.pop
            current_key = [ current_face, context_key ]
            next if surface_info_defs.key?(current_key)
            surface_info_defs[current_key] = surface_info_def
            current_face.edges.each do |edge|
              next unless edge.soft?
              edge.faces.each do |connected_face|
                stack << connected_face if face_set.key?(connected_face) && !surface_info_defs.key?([ connected_face, context_key ])
              end
            end
          end

        end

      end

      surface_info_defs
    end

  end

end