module Ladb::OpenCutList

  require_relative '../lib/fiddle/meshy/meshy'
  require_relative '../model/solid/solid_mesh_def'
  require_relative '../model/solid/solid_boolean_result_def'
  require_relative '../utils/transformation_utils'

  # Boolean operations on solids, powered by the Meshy native lib (Manifold).
  #
  # The whole geometric pipeline (validation, winding, plane canonicalization,
  # snapping, tilted-shared-plane nudging, boolean) runs in Meshy : the Ruby side
  # only extracts meshes from SketchUp entities, carries the face metadata registry
  # (materials, layers, surfaces) and rebuilds the resulting geometry.
  #
  # Three levels of API :
  # - mesh level        : _solid_boolean_compute        (pure computation, no model write)
  # - drawing def level : _solid_boolean_compute_defs   (what tools consume)
  # - entity level      : _solid_boolean_apply!         (all-in-one, transactional)
  module SolidBooleanHelper

    OPERATION_UNION = 'union'.freeze
    OPERATION_SUBTRACTION = 'subtraction'.freeze
    OPERATION_INTERSECTION = 'intersection'.freeze

    # Runs the boolean operation on SolidMeshDef lists.
    # Returns a SolidBooleanResultDef. No entity is read or written.
    def _solid_boolean_compute(operation, src_mesh_defs, cut_mesh_defs, validate: true)

      src_mesh_defs = Array(src_mesh_defs)
      cut_mesh_defs = Array(cut_mesh_defs)

      result_def = SolidBooleanResultDef.new

      # Merge all face info registries into a single one, offsetting ids accordingly,
      # so that fragment face ids can be resolved whatever input mesh they come from.
      face_info_defs = []
      fn_serialize = lambda { |mesh_def|
        meshy_hash = mesh_def.to_meshy_hash(id_offset: face_info_defs.length)
        face_info_defs.concat(mesh_def.face_info_defs)
        meshy_hash
      }

      input = {
        :solver_type => 'manifold',
        :operation => operation,
        :validate => validate,
        :tolerance => SolidMeshDef::TOLERANCE,
        :src_meshes => src_mesh_defs.map(&fn_serialize),
        :cut_meshes => cut_mesh_defs.map(&fn_serialize)
      }

      # Debug : entrée réellement envoyée (meshes bruts, AVANT le snapping fait dans Meshy)
      # File.write(File.join(Fiddle::Meshy.lib_dir, 'input.json'), JSON.pretty_generate(input))

      output = Fiddle::Meshy.operate(input)

      # Debug : sortie brute de Manifold, AVANT reconstruction SketchUp
      # File.write(File.join(Fiddle::Meshy.lib_dir, 'output.json'), JSON.pretty_generate(output))

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
      elsif output['fragments'].is_a?(Array)
        output['fragments'].each do |fragment|
          fragment_def = SolidFragmentDef.new(fragment['vertices'], fragment['face_indices'], fragment['face_ids'], face_info_defs)
          result_def.fragment_defs << fragment_def unless fragment_def.empty?
        end
      end

      result_def
    end

    # Same as _solid_boolean_compute, but consumes DrawingDefs
    # (whose face manipulators already embed world transformations).
    def _solid_boolean_compute_defs(operation, src_drawing_def, cut_drawing_def, validate: true)
      _solid_boolean_compute(
        operation,
        [ SolidMeshDef.from_drawing_def(src_drawing_def) ],
        [ SolidMeshDef.from_drawing_def(cut_drawing_def) ],
        validate: validate
      )
    end

    # All-in-one, transactional: computes the operation and rebuilds the result
    # INSIDE src_entity, which keeps its identity (name, attributes, material, layer,
    # transformation, persistent id). If src_entity shares its definition with other
    # instances, it is made unique first.
    #
    #   src_entity          : Sketchup::Group | Sketchup::ComponentInstance
    #   cut_entities        : same, single entity or Array
    #   src_transformation  : parent -> world transformation of src_entity's parent (IDENTITY if at model root)
    #   cut_transformations : Array aligned with cut_entities (IDENTITY if omitted)
    #
    # On failure nothing is modified. src_entity is available in result.created_entities.
    def _solid_boolean_apply!(operation, src_entity, cut_entities,
                              src_transformation: IDENTITY,
                              cut_transformations: nil,
                              keep_cuts: false,
                              preserve_materials: true,
                              merge_coplanar: true,
                              restore_soft_edges: true)

      cut_entities = Array(cut_entities)

      src_mesh_def = SolidMeshDef.from_entity(src_entity, transformation: src_transformation)
      cut_mesh_defs = cut_entities.each_with_index.map { |cut_entity, index|
        SolidMeshDef.from_entity(cut_entity, transformation: cut_transformations.is_a?(Array) ? cut_transformations[index] : IDENTITY)
      }

      result_def = _solid_boolean_compute(operation, [ src_mesh_def ], cut_mesh_defs)
      return result_def unless result_def.success?

      model = src_entity.model
      model.start_operation('OCL Solid Boolean', true)
      begin

        # Rebuild the result inside the source entity to preserve its identity
        src_entity.make_unique if src_entity.definition.instances.length > 1
        definition_entities = src_entity.definition.entities
        definition_entities.clear!
        _solid_fragments_to_geometry(
          result_def.fragment_defs,
          definition_entities,
          transformation: (src_transformation * src_entity.transformation).inverse,
          preserve_materials: preserve_materials,
          merge_coplanar: merge_coplanar,
          restore_soft_edges: restore_soft_edges
        )
        result_def.created_entities << src_entity

        cut_entities.each { |cut_entity| cut_entity.parent.entities.erase_entities(cut_entity) unless cut_entity.deleted? } unless keep_cuts

        model.commit_operation

      rescue => e
        model.abort_operation
        result_def.errors << [ 'core.error.exception', { :error => e.message } ]
      end

      result_def
    end

    # Rebuilds fragments as raw geometry inside the given Sketchup::Entities
    # (e.g. the definition entities of the source solid, previously cleared).
    # Fragment geometry is in world coordinates: transformation (world -> destination
    # local) is applied to the points themselves.
    # Pre-existing faces in entities are left untouched (no material, no merge).
    #
    # Returns the Array<Sketchup::Face> created.
    def _solid_fragments_to_geometry(fragment_defs, entities,
                                     transformation: IDENTITY,
                                     preserve_materials: true,
                                     merge_coplanar: true,
                                     restore_soft_edges: true)

      transformation = nil if transformation.nil? || transformation.identity?

      # A mirror transformation (negative determinant) reverses the winding of the
      # transformed triangles : re-reverse it so faces keep their outward orientation.
      flipped = !transformation.nil? && TransformationUtils.flipped?(transformation)

      # Add faces one batch per original face: provenance is structural,
      # no geometric matching needed afterward.
      face_infos = {}
      processed_face_ids = {}
      entities.grep(Sketchup::Face).each { |face| processed_face_ids[face.entityID] = true }

      fragment_defs.each do |fragment_def|
        next if fragment_def.empty?
        fragment_def.each_triangle_batch do |face_info_def, triangles|

          mesh = Geom::PolygonMesh.new(triangles.length * 3, triangles.length)
          triangles.each do |points|
            points = points.map { |point| point.transform(transformation) } unless transformation.nil?
            points = points.reverse if flipped
            mesh.add_polygon(points)
          end

          material = preserve_materials && !face_info_def.nil? ? face_info_def.material : nil
          entities.add_faces_from_mesh(mesh, Geom::PolygonMesh::NO_SMOOTH_OR_HIDE, material)

          entities.grep(Sketchup::Face).each do |face|
            next if processed_face_ids.key?(face.entityID)
            processed_face_ids[face.entityID] = true
            face_infos[face] = face_info_def
            face.layer = face_info_def.layer if preserve_materials && !face_info_def.nil? && !face_info_def.layer.nil?
          end

        end
      end

      if merge_coplanar || restore_soft_edges
        edges_to_erase = []
        entities.grep(Sketchup::Edge).each do |edge|
          faces = edge.faces
          next unless faces.length == 2
          face_0, face_1 = faces
          next unless face_infos.key?(face_0) && face_infos.key?(face_1) # Never touch pre-existing geometry
          face_info_def_0 = face_infos[face_0]
          face_info_def_1 = face_infos[face_1]

          if merge_coplanar && face_0.material == face_1.material && face_0.layer == face_1.layer
            # Merge whatever original face they come from, as native solid tools do,
            # but never across a material or layer boundary.
            # Erase only if SketchUp will actually merge the two faces : same oriented
            # normal and truly coplanar within SketchUp tolerance, otherwise erasing
            # the edge would erase both faces and leave a hole.
            if face_0.normal.samedirection?(face_1.normal) && face_1.outer_loop.vertices.all? { |vertex| vertex.position.on_plane?(face_0.plane) }
              edges_to_erase << edge
              next
            end
          end

          if restore_soft_edges && !face_info_def_0.nil? && !face_info_def_1.nil? && !face_info_def_0.equal?(face_info_def_1) &&
             !face_info_def_0.surface_info_def.nil? && face_info_def_0.surface_info_def.equal?(face_info_def_1.surface_info_def)
            # Edge between two faces of the same original curved surface
            edge.soft = true
            edge.smooth = true
          end
        end
        entities.erase_entities(edges_to_erase) if edges_to_erase.any?
      end

      face_infos.keys.reject(&:deleted?)
    end

    # Rebuilds fragments as new groups (one per fragment) inside the given
    # Sketchup::Entities. Fragment geometry is in world coordinates: transformation
    # (world -> destination local) is applied as the transformation of each group.
    #
    # Returns the Array<Sketchup::Group> created.
    def _solid_fragments_to_entities(fragment_defs, entities,
                                     transformation: IDENTITY,
                                     preserve_materials: true,
                                     merge_coplanar: true,
                                     restore_soft_edges: true)

      groups = []
      fragment_defs.each do |fragment_def|
        next if fragment_def.empty?

        group = entities.add_group
        group.transformation = transformation

        _solid_fragments_to_geometry(
          [ fragment_def ],
          group.entities,
          transformation: nil,
          preserve_materials: preserve_materials,
          merge_coplanar: merge_coplanar,
          restore_soft_edges: restore_soft_edges
        )

        groups << group
      end

      groups
    end

  end

end