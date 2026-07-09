module Ladb::OpenCutList

  require_relative '../lib/fiddle/meshy/meshy'
  require_relative '../model/solid/solid_mesh_def'
  require_relative '../model/solid/solid_boolean_result_def'
  require_relative '../utils/transformation_utils'

  # Boolean operations on solids, powered by the Meshy native lib (Manifold).
  #
  # The whole geometric pipeline (validation, winding, plane canonicalization,
  # snapping, tilted-shared-plane nudging, boolean) runs in Meshy: the Ruby side
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

      # Curves are not propagated through Manifold (provenance is per-triangle only):
      # collect their world-coordinates segments here for geometric re-attribution
      # at rebuild time.
      (src_mesh_defs + cut_mesh_defs).each { |mesh_def| result_def.curve_info_defs.concat(mesh_def.curve_info_defs) }

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
                              restore_soft_edges: true,
                              restore_curves: true)

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
        glued_instances = _solid_clear_preserving_glued!(definition_entities)
        created_faces = _solid_fragments_to_geometry(
          result_def.fragment_defs,
          definition_entities,
          transformation: (src_transformation * src_entity.transformation).inverse,
          curve_info_defs: result_def.curve_info_defs,
          preserve_materials: preserve_materials,
          merge_coplanar: merge_coplanar,
          restore_soft_edges: restore_soft_edges,
          restore_curves: restore_curves
        )
        _solid_reglue_instances(glued_instances, created_faces)
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
                                     curve_info_defs: nil,
                                     preserve_materials: true,
                                     merge_coplanar: true,
                                     restore_soft_edges: true,
                                     restore_curves: true)

      transformation = nil if transformation.nil? || transformation.identity?

      # A mirror transformation (negative determinant) reverses the winding of the
      # transformed triangles: re-reverse it so faces keep their outward orientation.
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

      _solid_weld_curves(entities, face_infos, curve_info_defs, transformation: transformation) if restore_curves

      face_infos.keys.reject(&:deleted?)
    end

    # Restores curve welding on the rebuilt geometry :
    # - pieces of original curves, re-attributed geometrically (an edge belongs to a
    #   curve if its endpoints and midpoint all lie on the curve's source segments)
    # - intersection seams: chains of new edges between two faces that do not belong
    #   to the same original curved surface, as native solid tools produce.
    # Requires Sketchup::Entities#weld (SketchUp >= 2020.1) : silently skipped below.
    def _solid_weld_curves(entities, face_infos, curve_info_defs, transformation: nil)
      return unless entities.respond_to?(:weld)

      curve_info_defs = Array(curve_info_defs)

      # Only edges entirely bounded by faces created by this rebuild: never touch
      # pre-existing geometry.
      new_edges = entities.grep(Sketchup::Edge).select { |edge|
        !edge.deleted? && !edge.faces.empty? && edge.faces.all? { |face| face_infos.key?(face) }
      }
      return if new_edges.empty?

      tolerance = SolidMeshDef::TOLERANCE

      fn_distance_to_segment = lambda { |point, a, b|
        v = a.vector_to(b)
        c2 = v % v
        return point.distance(a).to_f if c2 == 0.0
        t = (a.vector_to(point) % v) / c2
        t = 0.0 if t < 0.0
        t = 1.0 if t > 1.0
        point.distance(Geom.linear_combination(1.0 - t, a, t, b)).to_f
      }
      fn_on_segments = lambda { |point, segments|
        segments.any? { |a, b| fn_distance_to_segment.call(point, a, b) <= tolerance }
      }

      # Welding is cosmetic : a failure must never abort the boolean operation.
      fn_weld = lambda { |edges|
        next if edges.length < 2
        begin
          entities.weld(edges)
        rescue => e
          # Ignored
        end
      }

      # Original curve pieces. Segments are captured in world coordinates : bring
      # them into the destination space (mirror is harmless on point pairs). Cut
      # pieces end on intersection vertices that still lie ON the source segments,
      # and Manifold may merge collinear sub-segments : each point is therefore
      # tested against the whole segment set of the curve.
      attributed_edges = {}
      unless curve_info_defs.empty?
        segment_sets = curve_info_defs.map { |curve_info_def|
          transformation.nil? ? curve_info_def.segments : curve_info_def.segments.map { |a, b| [ a.transform(transformation), b.transform(transformation) ] }
        }
        edges_by_curve_index = {}
        new_edges.each do |edge|
          start_point = edge.start.position
          end_point = edge.end.position
          mid_point = Geom.linear_combination(0.5, start_point, 0.5, end_point)
          segment_sets.each_with_index do |segments, index|
            next unless fn_on_segments.call(start_point, segments) &&
                        fn_on_segments.call(end_point, segments) &&
                        fn_on_segments.call(mid_point, segments)
            (edges_by_curve_index[index] ||= []) << edge
            attributed_edges[edge] = true
            break
          end
        end
        edges_by_curve_index.each_value(&fn_weld)
      end

      # Intersection seams : group by the set of original surfaces involved so that
      # a seam crossing several (possibly merged) planar faces stays one chain.
      # Plane/plane intersections are straight lines : nothing to weld.
      edges_by_seam_key = {}
      new_edges.each do |edge|
        next if attributed_edges.key?(edge)
        faces = edge.faces
        next unless faces.length == 2
        face_info_def_0 = face_infos[faces[0]]
        face_info_def_1 = face_infos[faces[1]]
        next if face_info_def_0.nil? || face_info_def_1.nil?
        surface_info_def_0 = face_info_def_0.surface_info_def
        surface_info_def_1 = face_info_def_1.surface_info_def
        next if surface_info_def_0.nil? && surface_info_def_1.nil?
        next if !surface_info_def_0.nil? && surface_info_def_0.equal?(surface_info_def_1) # Interior of a surface (softened, not a seam)
        seam_key = [ surface_info_def_0, surface_info_def_1 ].compact.map(&:object_id).sort
        (edges_by_seam_key[seam_key] ||= []) << edge
      end
      edges_by_seam_key.each_value(&fn_weld)

      nil
    end

    # Returns the component instances (and groups) glued to the given faces.
    def _solid_glued_instances(faces)
      instances = []
      faces.each do |face|
        next if face.deleted?
        instances.concat(face.get_glued_instances.to_a)
      end
      instances.uniq
    end

    # Clears the given entities except the instances glued to its faces, and
    # returns those instances, to be re-glued via _solid_reglue_instances once
    # the geometry is rebuilt.
    def _solid_clear_preserving_glued!(entities)
      glued_instances = _solid_glued_instances(entities.grep(Sketchup::Face)) & entities.to_a
      if glued_instances.empty?
        entities.clear!
      else
        entities.erase_entities(entities.to_a - glued_instances)
      end
      glued_instances
    end

    # Re-glues the given instances onto the rebuilt faces : an instance is glued to
    # the face whose plane carries the instance origin (the gluing plane) and whose
    # boundary contains it. Instances whose host area was cut away stay unglued.
    def _solid_reglue_instances(instances, faces)
      return if instances.empty?

      # The origin lies on the original gluing plane, but the rebuilt plane may
      # have been snapped away by up to the tolerance.
      tolerance = SolidMeshDef::TOLERANCE * 2

      instances.each do |instance|
        next if instance.deleted?
        next unless instance.respond_to?(:glued_to=) # Sketchup::Group#glued_to= requires SketchUp >= 2021.1
        origin = instance.transformation.origin
        host_face = faces.find { |face|
          next false if face.deleted?
          next false unless origin.distance_to_plane(face.plane).to_f <= tolerance
          [ Sketchup::Face::PointInside, Sketchup::Face::PointOnEdge, Sketchup::Face::PointOnVertex ].include?(face.classify_point(origin.project_to_plane(face.plane)))
        }
        next if host_face.nil?
        begin
          instance.glued_to = host_face
        rescue => e
          # Gluing is cosmetic : never fail the boolean operation for it
        end
      end
      nil
    end

    # Rebuilds fragments as new groups (one per fragment) inside the given
    # Sketchup::Entities. Fragment geometry is in world coordinates: transformation
    # (world -> destination local) is applied as the transformation of each group.
    #
    # Returns the Array<Sketchup::Group> created.
    def _solid_fragments_to_entities(fragment_defs, entities,
                                     transformation: IDENTITY,
                                     curve_info_defs: nil,
                                     preserve_materials: true,
                                     merge_coplanar: true,
                                     restore_soft_edges: true,
                                     restore_curves: true)

      groups = []
      fragment_defs.each do |fragment_def|
        next if fragment_def.empty?

        group = entities.add_group
        group.transformation = transformation

        _solid_fragments_to_geometry(
          [ fragment_def ],
          group.entities,
          transformation: nil,
          curve_info_defs: curve_info_defs,
          preserve_materials: preserve_materials,
          merge_coplanar: merge_coplanar,
          restore_soft_edges: restore_soft_edges,
          restore_curves: restore_curves
        )

        groups << group
      end

      groups
    end

  end

end