module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../drawing/drawing_def'
  require_relative '../../manipulator/face_manipulator'

  # Group of source faces connected together by soft edges.
  # Instances carry no data: only their identity is used to restore edge softness after a boolean operation.
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
  # The geometry is always triangulated: the Meshy native lib only accepts triangles.
  # @face_ids holds one entry per triangle: the index of the corresponding SolidFaceInfoDef
  # in @face_info_defs. This provenance is propagated by Manifold through the boolean
  # operation and drives materials, layers and coplanar merging on reconstruction.
  #
  # Meshes are sent RAW to Meshy : validation, winding correction, plane
  # canonicalization, snapping and nudging all run natively in the lib.
  class SolidMeshDef < DataContainer

    # SketchUp merge tolerance (1/1000 inch): geometry closer than this cannot exist
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

    # transformation: parent -> world transformation of the entity
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