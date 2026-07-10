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

    def initialize(face_id, material: nil, layer: nil, surface_info_def: nil, container_def: nil)
      @face_id = face_id                      # Original face persistent_id (debug / traceability)
      @material = material                    # Sketchup::Material (inheritance already resolved)
      @layer = layer                          # Sketchup::Layer
      @surface_info_def = surface_info_def    # SolidSurfaceInfoDef or nil
      @container_def = container_def          # DrawingContainerDef node the source face belongs to (nil if unknown)
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
    def self.from_drawing_def(drawing_def)
      return nil unless drawing_def.is_a?(DrawingDef)
      mesh_def = new
      fn_populate = lambda { |container_def|
        mesh_def._populate(container_def.face_manipulators, drawing_def.transformation, container_def: container_def)
        container_def.container_defs.each(&fn_populate)
      }
      fn_populate.call(drawing_def)
      mesh_def
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

    def _populate(face_manipulators, transformation = IDENTITY, container_def: nil)

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
          container_def: container_def
        )

        # Capture the segments of the curves bounding this face (single-edge curves
        # carry no welding information : ignored). Segments are stored in WORLD
        # coordinates.
        composed_transformation = transformation.nil? ? face_manipulator.transformation : transformation * face_manipulator.transformation
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