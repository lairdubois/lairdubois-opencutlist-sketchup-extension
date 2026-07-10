module Ladb::OpenCutList

  require_relative 'common_solid_boolean_worker'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/solid/solid_mesh_def'
  require_relative '../../utils/transformation_utils'

  # Applies a solid boolean operation to the model, transactionally.
  #
  # Consumes the same DrawingDefs as CommonSolidBooleanWorker — single or
  # arrays, faces possibly spread over nested sub containers (drawing defs must
  # be built with their container tree preserved, i.e. NOT flattened) — and :
  # - computes the operation (delegated to CommonSolidBooleanWorker, unless a
  #   precomputed result_def obtained from the SAME drawing def lists is given),
  # - erases the operand faces in every container they span, making shared
  #   definitions unique on the way down so other instances are never modified,
  # - rebuilds each fragment inside the container it comes from : the sub
  #   container node when all its src faces originate from a single one (face
  #   provenance, SolidFaceInfoDef#container_def), so nested hierarchies are
  #   preserved ; otherwise the root container of its first src drawing def
  #   (SolidFragmentDef#src_indices). Containers keep their identity (name,
  #   attributes, material, layer, transformation, persistent id),
  # - erases the containers left empty (consumed srcs and sub containers) and
  #   the cut containers (unless keep_cuts).
  #
  # On failure nothing is modified. Rebuilt containers (or created faces when
  # the result lands at the model root) are available in result.created_entities.
  class CommonSolidBooleanApplyWorker

    # Temporary dictionary used to track entities through make_unique :
    # attributes survive the definition cloning, entity references do not.
    TRACKING_DICTIONARY = 'ladb_opencutlist_csg'.freeze
    TRACKING_FACE_KEY = 'operand'.freeze
    TRACKING_CONTAINER_KEY = 'container'.freeze

    def initialize(src_drawing_defs, cut_drawing_defs,

                   operation: CommonSolidBooleanWorker::OPERATION_UNION,
                   validate: true,
                   result_def: nil,

                   keep_cuts: false,
                   preserve_materials: true,
                   merge_coplanar: true,
                   restore_soft_edges: true,
                   restore_curves: true

    )

      @src_drawing_defs = Array(src_drawing_defs)
      @cut_drawing_defs = Array(cut_drawing_defs)

      @operation = operation
      @validate = validate
      @result_def = result_def

      @keep_cuts = keep_cuts
      @preserve_materials = preserve_materials
      @merge_coplanar = merge_coplanar
      @restore_soft_edges = restore_soft_edges
      @restore_curves = restore_curves

    end

    # -----

    def run
      if @src_drawing_defs.empty? || !(@src_drawing_defs + @cut_drawing_defs).all? { |drawing_def| drawing_def.is_a?(DrawingDef) }
        result_def = SolidBooleanResultDef.new
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      result_def = @result_def
      result_def = CommonSolidBooleanWorker.new(@src_drawing_defs, @cut_drawing_defs, operation: @operation, validate: @validate).run if result_def.nil?
      return result_def unless result_def.is_a?(SolidBooleanResultDef) && result_def.success?

      if (model = Sketchup.active_model).nil?
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      model.start_operation('OCL Solid Boolean', true)
      begin

        @model = model
        @resolved_instances = {}    # DrawingContainerDef -> (possibly cloned) instance resolved by the erase cascade
        @glued_by_container = {}    # container instance (or nil for model root) -> instances to re-glue
        @operand_instances = []     # resolved sub container instances, parents first

        src_containers = @src_drawing_defs.map { |drawing_def| drawing_def.container }

        # Group the operand trees by root container : one erase pass per
        # container, so that faces coming from several drawing defs sharing the
        # same container are handled by a single make_unique cascade.
        passes = {}
        fn_pass = lambda { |container|
          passes[container] ||= {
            :root_node => { :faces => [], :children => [], :erase_tokens => [] }
          }
        }
        fn_add_tree = lambda { |drawing_def|
          _append_container_def_to_node(drawing_def, fn_pass.call(drawing_def.container)[:root_node])
        }

        @src_drawing_defs.each(&fn_add_tree)

        # Cut consumption. A cut root container is erased wholesale, except when
        # it shares its container with a src (its faces join the pass), when its
        # faces live at the model root (same), or when it is nested inside a src
        # container (erased through the pass, after the possible make_unique).
        standalone_cut_containers = []
        nested_cut_containers_by_pass = {}
        unless @keep_cuts
          @cut_drawing_defs.each do |drawing_def|
            container = drawing_def.container
            if (container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)) && !src_containers.include?(container)
              host_container = nil
              if container.parent.is_a?(Sketchup::ComponentDefinition)
                host_container = src_containers.find { |src_container|
                  (src_container.is_a?(Sketchup::Group) || src_container.is_a?(Sketchup::ComponentInstance)) &&
                    !src_container.deleted? && src_container.definition == container.parent
                }
              end
              if host_container.nil?
                standalone_cut_containers << container
              else
                (nested_cut_containers_by_pass[fn_pass.call(host_container)] ||= []) << container
              end
            else
              fn_add_tree.call(drawing_def)
            end
          end
        end

        # Tag operand faces and sub container instances : attributes survive
        # make_unique cloning, entity references do not.
        tagged_faces = []
        tagged_instances = []
        begin

          passes.each do |container, pass|
            _tag_node(pass[:root_node], tagged_faces, tagged_instances)
            (nested_cut_containers_by_pass[pass] || []).each do |cut_container|
              pass[:root_node][:erase_tokens] << _tag_instance(cut_container, tagged_instances)
            end
          end

          # Erase standalone cut containers first
          standalone_cut_containers.each { |container| container.erase! unless container.deleted? }

          # Run the erase passes
          passes.each do |container, pass|
            if container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
              next if container.deleted?
              container.make_unique if container.definition.instances.length > 1
              entities = container.definition.entities
              owner = container
            else
              entities = model.entities
              owner = nil
            end
            _erase_node(entities, pass[:root_node], owner)
          end

        ensure
          # Untag whatever remains tagged (original definitions kept by other instances)
          tagged_faces.each { |face| face.delete_attribute(TRACKING_DICTIONARY) unless face.deleted? }
          tagged_instances.each { |instance| instance.delete_attribute(TRACKING_DICTIONARY) unless instance.deleted? }
        end

        # Rebuild each fragment inside the container node it comes from (face
        # provenance), falling back to the root container of its first src
        # drawing def when the node is ambiguous. Fragment geometry is in world
        # coordinates.
        src_node_owners = {}
        fn_register_nodes = lambda { |container_def, drawing_def|
          src_node_owners[container_def] = drawing_def
          container_def.container_defs.each { |child_def| fn_register_nodes.call(child_def, drawing_def) }
        }
        @src_drawing_defs.each { |drawing_def| fn_register_nodes.call(drawing_def, drawing_def) }

        fragments_by_target = {}
        result_def.fragment_defs.each do |fragment_def|
          target_container_def = _fragment_source_container_def(fragment_def, src_node_owners)
          target_container_def = @src_drawing_defs[fragment_def.src_indices.first || 0] if target_container_def.nil?
          next if target_container_def.nil?
          (fragments_by_target[target_container_def] ||= []) << fragment_def
        end

        created_faces_by_container = {}
        fragments_by_target.each do |target_container_def, fragment_defs|
          owner, entities, transformation = _resolve_rebuild_target(target_container_def, src_node_owners)
          next if entities.nil?
          created_faces = _solid_fragments_to_geometry(
            fragment_defs,
            entities,
            transformation: transformation,
            curve_info_defs: result_def.curve_info_defs,
            preserve_materials: @preserve_materials,
            merge_coplanar: @merge_coplanar,
            restore_soft_edges: @restore_soft_edges,
            restore_curves: @restore_curves
          )
          (created_faces_by_container[owner] ||= []).concat(created_faces)
          if owner.nil?
            result_def.created_entities.concat(created_faces)
          else
            result_def.created_entities << owner unless result_def.created_entities.include?(owner)
          end
        end

        # Re-glue the instances that were glued onto erased faces
        created_faces_by_container.each do |owner, created_faces|
          glued_instances = @glued_by_container[owner]
          _solid_reglue_instances(glued_instances, created_faces) unless glued_instances.nil?
        end

        # Erase the operand containers left empty (fully consumed solids) :
        # children first, so that a parent emptied by its children is caught too.
        @operand_instances.reverse_each do |instance|
          next if instance.deleted?
          instance.erase! if instance.definition.entities.size == 0
        end
        src_containers.uniq.each do |container|
          next unless container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
          next if container.deleted?
          container.erase! if container.definition.entities.size == 0
        end

        model.commit_operation

      rescue => e
        model.abort_operation
        result_def.errors << [ 'core.error.exception', { :error => e.message } ]
      end

      result_def
    end

    private

    # Merges the faces and sub container tree of the given DrawingContainerDef
    # into the given node ({ :faces, :children, :erase_tokens }).
    def _append_container_def_to_node(container_def, node)
      node[:faces].concat(container_def.face_manipulators.map(&:face)).uniq!
      container_def.container_defs.each do |child_def|
        child_node = { :container_def => child_def, :container => child_def.container, :faces => [], :children => [], :erase_tokens => [] }
        _append_container_def_to_node(child_def, child_node)
        node[:children] << child_node
      end
      node
    end

    def _tag_instance(instance, tagged_instances)
      token = instance.get_attribute(TRACKING_DICTIONARY, TRACKING_CONTAINER_KEY)
      if token.nil?
        token = instance.persistent_id.to_s
        instance.set_attribute(TRACKING_DICTIONARY, TRACKING_CONTAINER_KEY, token)
        tagged_instances << instance
      end
      token
    end

    def _tag_node(node, tagged_faces, tagged_instances)
      node[:faces].each do |face|
        next if face.deleted?
        face.set_attribute(TRACKING_DICTIONARY, TRACKING_FACE_KEY, true)
        tagged_faces << face
      end
      node[:children].each do |child_node|
        instance = child_node[:container]
        child_node[:token] = instance.nil? || instance.deleted? ? nil : _tag_instance(instance, tagged_instances)
        _tag_node(child_node, tagged_faces, tagged_instances)
      end
      nil
    end

    # Erases the tagged operand faces of the given entities, then recurses into
    # the tagged sub container instances (made unique first when their
    # definition is shared, so other instances are never modified). The resolved
    # instances are memoized per node (@resolved_instances) : they are the
    # rebuild targets of the fragments attributed to their node, and are erased
    # after the rebuild if they end up empty. Tagged cut containers are erased.
    # Glued instances are collected per container (@glued_by_container) for
    # re-gluing onto the geometry rebuilt in the same container.
    def _erase_node(entities, node, owner)

      faces = entities.grep(Sketchup::Face).select { |face| face.get_attribute(TRACKING_DICTIONARY, TRACKING_FACE_KEY) }
      faces.each { |face| face.delete_attribute(TRACKING_DICTIONARY) }
      glued = _solid_erase_faces!(entities, faces)
      (@glued_by_container[owner] ||= []).concat(glued) unless glued.empty?

      return if node[:children].empty? && node[:erase_tokens].empty?

      instances_by_token = {}
      entities.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        token = entity.get_attribute(TRACKING_DICTIONARY, TRACKING_CONTAINER_KEY)
        instances_by_token[token] = entity unless token.nil?
      end

      node[:children].each do |child_node|
        child_instance = instances_by_token[child_node[:token]]
        next if child_instance.nil? || child_instance.deleted?
        child_instance.delete_attribute(TRACKING_DICTIONARY)
        child_instance.make_unique if child_instance.definition.instances.length > 1
        @resolved_instances[child_node[:container_def]] = child_instance
        @operand_instances << child_instance
        _erase_node(child_instance.definition.entities, child_node, child_instance)
      end

      node[:erase_tokens].each do |token|
        instance = instances_by_token[token]
        instance.erase! unless instance.nil? || instance.deleted?
      end

      nil
    end

    # Returns the single src container node (DrawingContainerDef or DrawingDef)
    # the fragment src faces come from, nil when the provenance is missing or
    # spans several nodes (the caller then falls back to the src root container).
    def _fragment_source_container_def(fragment_def, src_node_owners)
      face_ids = fragment_def.face_ids
      return nil if face_ids.nil?
      source_container_def = nil
      face_ids.uniq.each do |face_id|
        face_info_def = fragment_def.face_info_defs[face_id]
        next if face_info_def.nil?
        container_def = face_info_def.container_def
        next if container_def.nil? || !src_node_owners.key?(container_def)   # Cut imprint faces do not drive attribution
        return nil if !source_container_def.nil? && !source_container_def.equal?(container_def)
        source_container_def = container_def
      end
      source_container_def
    end

    # Resolves the rebuild target of the given container node :
    # [ owner (container instance or nil for model root), entities, world -> local transformation ].
    # Sub container nodes are resolved through the instances memoized by the
    # erase cascade (make_unique may have cloned the original ones) ; when the
    # instance is gone, the fragment falls back to the src root container.
    def _resolve_rebuild_target(container_def, src_node_owners)
      if container_def.is_a?(DrawingDef)
        drawing_def = container_def
        container = drawing_def.container
        transformation = (drawing_def.transformation * drawing_def.container_transformation).inverse
        if container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
          return [ nil, nil, nil ] if container.deleted?
          [ container, container.definition.entities, transformation ]
        else
          [ nil, @model.entities, transformation ]
        end
      else
        instance = @resolved_instances[container_def]
        if instance.nil? || instance.deleted?
          _resolve_rebuild_target(src_node_owners[container_def], src_node_owners)
        else
          drawing_def = src_node_owners[container_def]
          [ instance, instance.definition.entities, (drawing_def.transformation * container_def.transformation * instance.transformation).inverse ]
        end
      end
    end

    # -- Model rebuild primitives --

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

      # Original curve pieces. Segments are captured in world coordinates: bring
      # them into the destination space (mirror is harmless on point pairs). Cut
      # pieces end on intersection vertices that still lie ON the source segments,
      # and Manifold may merge collinear sub-segments: each point is therefore
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

      # Intersection seams: group by the set of original surfaces involved so that
      # a seam crossing several (possibly merged) planar faces stays one chain.
      # Plane/plane intersections are straight lines: nothing to weld.
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

    # Erases the given faces and the edges that only bound them. Every other
    # entity is preserved: nested instances and groups, construction geometry,
    # dimensions, texts, standalone edges, faces not involved in the operation
    # (and the edges they share with erased faces).
    # Instances glued to the erased faces are preserved too and returned, to be
    # re-glued via _solid_reglue_instances once the geometry is rebuilt.
    def _solid_erase_faces!(entities, faces)
      faces = faces.reject(&:deleted?)
      return [] if faces.empty?

      glued_instances = _solid_glued_instances(faces) & entities.to_a

      face_set = {}
      faces.each { |face| face_set[face] = true }
      edges = faces.flat_map(&:edges).uniq.select { |edge| edge.faces.all? { |edge_face| face_set.key?(edge_face) } }

      entities.erase_entities(faces + edges)

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

  end

end