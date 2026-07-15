module Ladb::OpenCutList

  require_relative 'common_solid_boolean_worker'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/solid/solid_mesh_def'
  require_relative '../../utils/lock_utils'
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
  # - preserves shared definitions : src root containers sharing a definition
  #   before the operation keep sharing ONE definition after, when the
  #   operation leaves them identical (same result in their own local space,
  #   canonical signature comparison). When the definition has other,
  #   non-operand instances, the identical srcs are reattached to the
  #   representative's made-unique definition (ComponentInstance#definition=,
  #   SketchUp >= 2022 ; otherwise distinct definitions, as before). Srcs whose
  #   identical local cut environment is provable up front are additionally
  #   excluded from the computation itself (one Manifold pass per placement,
  #   see _plan_shared_computation),
  # - erases the containers left empty (consumed srcs and sub containers) and
  #   the cut containers (unless keep_cuts),
  # - leaves glued cuts-opening containers (virtual machinings) out of the
  #   operation : their geometry only closes the shell during the computation,
  #   the instances are re-glued onto the rebuilt faces, and erased when their
  #   host area was cut away ; a machining sliced by the operation is
  #   materialized instead (its surviving geometry becomes real geometry and
  #   its instance is erased).
  #
  # SketchUp locks are NOT enforced by the Ruby API : the worker enforces
  # them itself (shared semantic, see LockUtils). A locked src — root
  # container locked or reachable through a
  # locked occurrence path, or any locked operand sub container — fails the
  # operation up front (except in keep_srcs mode, where srcs are untouched).
  # A locked cut is consumed by the computation but kept in the model, as in
  # keep_cuts. A definition displayed by a locked external instance is never
  # rebuilt in place : the locked externals always keep their original
  # geometry (see make_unique: false below and _plan_shared_definitions).
  # Locked virtual machinings are not handled.
  #
  # In make_unique: false mode the definitions shared with instances external
  # to the operation are NOT made unique : they are rebuilt in place, so every
  # instance — external ones included — displays the result. A definition
  # targeted by several operand instances with DIFFERENT results cannot be
  # rebuilt in place : those instances fall back to make_unique, as in the
  # default mode. A definition displayed by a locked external instance falls
  # back too : rebuilding it in place would bypass the lock.
  #
  # In keep_srcs mode the src containers are left untouched : the whole result
  # is rebuilt inside a NEW component whose instance is added to the parent of
  # the src[0] root container, at the same place, with the same name, material
  # and layer. The sub container hierarchy is not recreated (flat geometry),
  # except the virtual machinings, copied and re-glued onto the rebuilt faces.
  # Cuts are consumed as usual (unless keep_cuts), except those living inside
  # or sharing a src container : erasing them would modify the kept srcs.
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

                   keep_srcs: false,
                   keep_cuts: false,
                   make_unique: true,
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

      @keep_srcs = keep_srcs
      @keep_cuts = keep_cuts
      @make_unique = make_unique
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

      # Locked operands fail the operation before anything is computed : the
      # operation rewrites their content and locks are not enforced by the
      # API. Locked CUTS are not an error : their geometry feeds the
      # computation but their container is kept, as in keep_cuts mode.
      locked_names = _locked_operand_names
      unless locked_names.empty?
        result_def = SolidBooleanResultDef.new
        result_def.errors << [ 'core.solid.error.locked_instances', { :list => locked_names.join(', ') } ]
        return result_def
      end

      result_def = @result_def
      if result_def.nil?
        # Srcs provably identical to a representative (same definition, same
        # local cut environment) are excluded from the computation : the shared
        # definition planning attaches them to their representative's result.
        # Not applicable in keep_srcs mode (every fragment is rebuilt) nor on a
        # precomputed result_def (obtained from the full src list).
        @precomputed_shared = @keep_srcs ? {} : _plan_shared_computation
        @computed_src_drawing_defs = @src_drawing_defs.reject { |drawing_def| @precomputed_shared.key?(drawing_def) }
        result_def = CommonSolidBooleanWorker.new(@computed_src_drawing_defs, @cut_drawing_defs, operation: @operation, validate: @validate).run
      else
        @precomputed_shared = {}
        @computed_src_drawing_defs = @src_drawing_defs
      end
      return result_def unless result_def.is_a?(SolidBooleanResultDef) && result_def.success?

      if (model = Sketchup.active_model).nil?
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      model.start_operation('OCL Solid Boolean', true)
      begin

        if @keep_srcs
          _apply_to_new_container(result_def, model)
          model.commit_operation
          return result_def
        end

        @resolved_instances = {}          # DrawingContainerDef -> (possibly cloned) instance resolved by the erase cascade
        @glued_by_container = {}          # container instance (or nil for model root) -> instances to re-glue
        @operand_instances = []           # resolved sub container instances, parents first
        @materialized_container_defs = [] # virtual nodes materialized by the current rebuild call

        src_containers = @src_drawing_defs.map { |drawing_def| drawing_def.container }

        # Register the src container nodes (rebuild targets, with their tree
        # path) and attribute the fragments to them (face provenance, falling
        # back to the root container of their first src drawing def when the
        # provenance is ambiguous). Needed up front : the shared definition
        # planning below compares the per-src attributed results.
        src_node_owners = {}
        src_node_paths = {}
        fn_register_nodes = lambda { |container_def, drawing_def, path|
          src_node_owners[container_def] = drawing_def
          src_node_paths[container_def] = path
          container_def.container_defs.each_with_index { |child_def, child_index| fn_register_nodes.call(child_def, drawing_def, path + [ child_index ]) }
        }
        @src_drawing_defs.each { |drawing_def| fn_register_nodes.call(drawing_def, drawing_def, []) }

        fragments_by_target = {}
        result_def.fragment_defs.each do |fragment_def|
          target_container_def = _fragment_source_container_def(fragment_def, src_node_owners)
          target_container_def = @computed_src_drawing_defs[fragment_def.src_indices.first || 0] if target_container_def.nil?
          next if target_container_def.nil?
          (fragments_by_target[target_container_def] ||= []) << fragment_def
        end

        # Plan the shared definition preservation : srcs sharing a definition
        # and left identical by the operation are handled by a single pass on
        # a representative, the others are dropped (and reattached in Case B).
        shared_plan = _plan_shared_definitions(result_def, fragments_by_target, src_node_owners, src_node_paths)
        dropped_drawing_defs = shared_plan[:dropped_drawing_defs]
        effective_src_containers = @src_drawing_defs.reject { |drawing_def| dropped_drawing_defs.key?(drawing_def) }.map { |drawing_def| drawing_def.container }

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

        @src_drawing_defs.each { |drawing_def| fn_add_tree.call(drawing_def) unless dropped_drawing_defs.key?(drawing_def) }

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
                host_container = effective_src_containers.find { |src_container|
                  (src_container.is_a?(Sketchup::Group) || src_container.is_a?(Sketchup::ComponentInstance)) &&
                    !src_container.deleted? && src_container.definition == container.parent
                }
              end
              if host_container.nil?
                # A locked standalone cut (or one reachable through a locked
                # occurrence path) is kept : erasing it would bypass the lock
                standalone_cut_containers << container unless LockUtils.effectively_locked?(container)
              elsif !container.locked?
                # Same for a locked nested cut : never tagged for erase (its
                # possible make_unique clone inherits the lock through the
                # definition cloning)
                (nested_cut_containers_by_pass[fn_pass.call(host_container)] ||= []) << container
              end
            else
              fn_add_tree.call(drawing_def)
            end
          end
        end

        # make_unique: false fallback planning. A definition written by several
        # distinct operand instances holds several different results and cannot
        # be rebuilt in place : root containers of such a definition keep the
        # make_unique behavior (@conflicting_root_definitions, srcs sharing a
        # definition with different result signatures), and a nested child
        # conflicting with ANY other writer — sibling child nodes or an
        # effective src root — is made unique too (@conflicting_definitions).
        @conflicting_root_definitions = {}
        @conflicting_definitions = {}
        unless @make_unique
          root_instances_by_definition = {}
          all_instances_by_definition = {}
          fn_count = lambda { |registry, instance|
            (registry[instance.definition] ||= {})[instance] = true if (instance.is_a?(Sketchup::Group) || instance.is_a?(Sketchup::ComponentInstance)) && !instance.deleted?
          }
          effective_src_containers.each { |container| fn_count.call(root_instances_by_definition, container) ; fn_count.call(all_instances_by_definition, container) }
          fn_count_children = lambda { |node|
            node[:children].each do |child_node|
              fn_count.call(all_instances_by_definition, child_node[:container]) unless child_node[:container].nil?
              fn_count_children.call(child_node)
            end
          }
          passes.each_value { |pass| fn_count_children.call(pass[:root_node]) }
          # A definition displayed by a locked external instance cannot be
          # rebuilt in place either : the operand falls back to make_unique
          # and the locked externals keep the original definition.
          locked_cache = {}
          fn_locked_extern = lambda { |definition, instances|
            definition.instances.any? { |instance| !instance.deleted? && !instances.key?(instance) && LockUtils.effectively_locked?(instance, locked_cache) }
          }
          root_instances_by_definition.each { |definition, instances| @conflicting_root_definitions[definition] = true if instances.length > 1 || fn_locked_extern.call(definition, instances) }
          all_instances_by_definition.each { |definition, instances| @conflicting_definitions[definition] = true if instances.length > 1 || fn_locked_extern.call(definition, instances) }
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
              # Case A shared srcs : every instance displays the rebuilt
              # definition, making it unique would break the sharing.
              # make_unique: false : rebuilt in place (external instances
              # follow), unless several srcs write different results to the
              # definition (fallback to make_unique).
              container.make_unique if container.definition.instances.length > 1 && !shared_plan[:skip_make_unique_containers].key?(container) && (@make_unique || @conflicting_root_definitions.key?(container.definition))
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

        # Reattach the shared identical srcs to the representative definition
        # (Case B : made unique by its erase pass, since other instances exist)
        shared_plan[:reassignments].each do |instance, representative|
          next if instance.deleted? || representative.deleted?
          instance.definition = representative.definition
        end

        # Rebuild each fragment inside the container node it comes from (face
        # provenance, attributed up front). Fragment geometry is in world
        # coordinates. Fragments of the dropped (shared) srcs are not rebuilt :
        # their instances display the representative's rebuilt definition.
        created_faces_by_container = {}
        materialized_by_owner = {}
        fragments_by_target.each do |target_container_def, fragment_defs|
          next if dropped_drawing_defs.key?(src_node_owners[target_container_def])
          owner, entities, transformation = _resolve_rebuild_target(target_container_def, src_node_owners, model)
          next if entities.nil?
          @materialized_container_defs = []
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
          (materialized_by_owner[owner] ||= []).concat(@materialized_container_defs) unless @materialized_container_defs.empty?
          if owner.nil?
            result_def.created_entities.concat(created_faces)
          else
            result_def.created_entities << owner unless result_def.created_entities.include?(owner)
          end
        end

        # The other shared srcs display the representative's rebuilt definition
        shared_plan[:shared_members].each do |representative, others|
          next if representative.deleted? || !result_def.created_entities.include?(representative)
          others.each do |container|
            next if container.deleted? || result_def.created_entities.include?(container)
            result_def.created_entities << container
          end
        end

        # Erase the machinings materialized by the operation (sliced by the
        # cut) : their surviving geometry is now real, re-gluing the instance
        # would punch its full opening over it. Matched among the collected
        # glued instances by definition and transformation, so make_unique
        # clones are caught too. Excluded from re-gluing.
        materialized_by_owner.each do |owner, container_defs|
          glued_instances = @glued_by_container[owner]
          next if glued_instances.nil?
          container_defs.uniq.each do |container_def|
            original = container_def.container
            next if original.nil? || !original.respond_to?(:definition)
            instance = glued_instances.find { |glued_instance|
              !glued_instance.deleted? &&
                glued_instance.definition == original.definition &&
                glued_instance.transformation.to_a == original.transformation.to_a
            }
            next if instance.nil?
            glued_instances.delete(instance)
            instance.erase!
          end
        end

        # Re-glue the instances that were glued onto erased faces
        created_faces_by_container.each do |owner, created_faces|
          glued_instances = @glued_by_container[owner]
          _solid_reglue_instances(glued_instances, created_faces) unless glued_instances.nil?
        end

        # Erase the orphan virtual machinings : a cuts-opening instance whose
        # host area was cut away (no face welcomed it back) is meaningless.
        @glued_by_container.each_value do |glued_instances|
          glued_instances.each do |instance|
            next if instance.deleted?
            next unless instance.definition.behavior.cuts_opening?
            glued_to = begin; instance.glued_to; rescue; nil; end
            instance.erase! if glued_to.nil?
          end
        end

        # Erase the operand containers left empty (fully consumed solids) :
        # children first, so that a parent emptied by its children is caught too.
        @operand_instances.reverse_each do |instance|
          next if instance.deleted? || instance.locked?
          instance.erase! if instance.definition.entities.size == 0
        end
        src_containers.uniq.each do |container|
          next unless container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
          next if container.deleted? || container.locked?
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

    # Rebuilds the whole operation result inside a NEW component (keep_srcs
    # mode), leaving the src containers untouched. The component definition is
    # named after the src[0] root container, its instance is added to the same
    # parent, at the same place, with the same name, material and layer. The
    # sub container hierarchy is not recreated : the result is rebuilt as flat
    # geometry, except the virtual machinings (glued cuts-opening instances),
    # copied and re-glued onto the rebuilt faces — unless materialized by the
    # operation (their surviving geometry is already rebuilt as real geometry)
    # or orphaned (host area cut away : no face welcomes the copy back).
    def _apply_to_new_container(result_def, model)

      drawing_def = @src_drawing_defs.first
      container = drawing_def.container
      src_containers = @src_drawing_defs.map { |src_drawing_def| src_drawing_def.container }

      # Consume the cuts. Cuts living inside (or sharing) a src container are
      # left untouched : erasing them would modify the kept srcs.
      unless @keep_cuts
        @cut_drawing_defs.each do |cut_drawing_def|
          cut_container = cut_drawing_def.container
          if cut_container.is_a?(Sketchup::Group) || cut_container.is_a?(Sketchup::ComponentInstance)
            next if cut_container.deleted? || src_containers.include?(cut_container)
            next if cut_container.parent.is_a?(Sketchup::ComponentDefinition) && src_containers.any? { |src_container|
              (src_container.is_a?(Sketchup::Group) || src_container.is_a?(Sketchup::ComponentInstance)) &&
                !src_container.deleted? && src_container.definition == cut_container.parent
            }
            next if LockUtils.effectively_locked?(cut_container) # Locked cut : consumed by the computation but kept
            cut_container.erase!
          else
            # Model root cut : erase its root faces and its sub containers
            _solid_erase_faces!(model.entities, cut_drawing_def.face_manipulators.map(&:face))
            cut_drawing_def.container_defs.each do |child_def|
              child_container = child_def.container
              next if child_container.nil? || child_container.deleted?
              next if SolidMeshDef.virtual_glued_container?(child_container)
              next if LockUtils.effectively_locked?(child_container) # Locked cut : consumed by the computation but kept
              child_container.erase!
            end
          end
        end
      end

      if container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
        parent_entities = container.parent.entities
        instance_transformation = container.transformation
        instance_name = container.name
        definition_name = container.is_a?(Sketchup::ComponentInstance) ? container.definition.name : container.name
        material = container.material
        layer = container.layer
      else
        parent_entities = model.entities
        instance_transformation = drawing_def.transformation * drawing_def.container_transformation
        instance_name = nil
        definition_name = nil
        material = nil
        layer = nil
      end

      # World -> new definition local space. The instance sits in the same
      # slot as the src[0] container : the mapping is the same as a rebuild
      # inside the src[0] definition itself.
      transformation = (drawing_def.transformation * drawing_def.container_transformation).inverse

      new_definition = model.definitions.add(definition_name.to_s) # Name collisions are suffixed by SketchUp

      @materialized_container_defs = []
      created_faces = _solid_fragments_to_geometry(
        result_def.fragment_defs,
        new_definition.entities,
        transformation: transformation,
        curve_info_defs: result_def.curve_info_defs,
        preserve_materials: @preserve_materials,
        merge_coplanar: @merge_coplanar,
        restore_soft_edges: @restore_soft_edges,
        restore_curves: @restore_curves
      )

      # Copy the virtual machinings of the src trees into the new component
      copied_instances = []
      fn_copy_virtual_containers = lambda { |parent_def, root_drawing_def|
        parent_def.container_defs.each do |child_def|
          child_container = child_def.container
          next if child_container.nil? || child_container.deleted?
          if SolidMeshDef.virtual_glued_container?(child_container)
            next if @materialized_container_defs.include?(child_def)
            copied_instance = new_definition.entities.add_instance(
              child_container.definition,
              transformation * root_drawing_def.transformation * child_def.transformation * child_container.transformation
            )
            copied_instance.name = child_container.name unless child_container.name.to_s.empty?
            copied_instance.material = child_container.material
            copied_instance.layer = child_container.layer
            copied_instances << copied_instance
          else
            fn_copy_virtual_containers.call(child_def, root_drawing_def)
          end
        end
      }
      @src_drawing_defs.each { |src_drawing_def| fn_copy_virtual_containers.call(src_drawing_def, src_drawing_def) }

      _solid_reglue_instances(copied_instances, created_faces)
      copied_instances.each do |copied_instance|
        next if copied_instance.deleted?
        glued_to = begin; copied_instance.glued_to; rescue; nil; end
        copied_instance.erase! if glued_to.nil?
      end

      if new_definition.entities.size == 0
        # Empty result (e.g. subtraction consumed everything) : no container created
        model.definitions.remove(new_definition) if model.definitions.respond_to?(:remove)
        return
      end

      instance = parent_entities.add_instance(new_definition, instance_transformation)
      instance.name = instance_name unless instance_name.nil? || instance_name.empty?
      instance.material = material unless material.nil?
      instance.layer = layer unless layer.nil?

      result_def.created_entities << instance

      nil
    end

    # Plans the shared definition preservation : groups the src root containers
    # by definition, compares their attributed results in their own local
    # space (_shared_result_signature) and, per subset of identical results :
    # - drops the non-representative drawing defs (single erase pass on the
    #   representative, whose rebuilt definition is displayed by every member),
    # - Case A, every live instance of the definition is a member : the
    #   representative erase pass skips make_unique, the definition is rebuilt
    #   in place for all,
    # - Case B, other instances exist : the representative is made unique by
    #   its erase pass, the other members are reattached to its new definition
    #   (ComponentInstance#definition=, SketchUp >= 2022 : otherwise the subset
    #   falls back to distinct definitions, as before).
    # In make_unique: false mode, a subset covering EVERY src of its definition
    # is rebuilt in place whatever the extra instances (Case B collapses into
    # Case A : externals follow the result, no reattachment). A partial subset
    # keeps the Case B behavior : the definition holds several different
    # results and cannot be shared with the external instances.
    # Srcs fused by the operation (multi src fragments) and srcs whose
    # container is also a cut container never share.
    def _plan_shared_definitions(result_def, fragments_by_target, src_node_owners, src_node_paths)

      plan = { :dropped_drawing_defs => {}, :skip_make_unique_containers => {}, :reassignments => [], :shared_members => {} }

      # Src root containers grouped by shared definition. A container picked
      # twice as src disqualifies its group.
      groups = {}
      @src_drawing_defs.each do |drawing_def|
        container = drawing_def.container
        next unless container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
        next if container.deleted?
        (groups[container.definition] ||= []) << drawing_def
      end
      groups = groups.select { |definition, drawing_defs| drawing_defs.length > 1 && drawing_defs.map { |drawing_def| drawing_def.container }.uniq.length == drawing_defs.length }
      return plan if groups.empty?

      # Srcs fused together by the operation cannot share
      unshareable = {}
      result_def.fragment_defs.each do |fragment_def|
        src_indices = fragment_def.src_indices
        next if src_indices.nil? || src_indices.uniq.length < 2
        src_indices.uniq.each do |src_index|
          drawing_def = @computed_src_drawing_defs[src_index]
          unshareable[drawing_def] = true unless drawing_def.nil?
        end
      end

      cut_containers = @cut_drawing_defs.map { |cut_drawing_def| cut_drawing_def.container }

      # Fragments attributed to each src root drawing def, with the tree path
      # of their target node
      fragment_paths_by_drawing_def = {}
      fragments_by_target.each do |target_container_def, fragment_defs|
        drawing_def = src_node_owners[target_container_def]
        next if drawing_def.nil?
        path = src_node_paths[target_container_def] || []
        list = (fragment_paths_by_drawing_def[drawing_def] ||= [])
        fragment_defs.each { |fragment_def| list << [ fragment_def, path ] }
      end

      groups.each do |definition, drawing_defs|

        candidates = drawing_defs.reject { |drawing_def| unshareable.key?(drawing_def) || cut_containers.include?(drawing_def.container) }

        # Partition the candidates by result signature : only subsets of 2+
        # identical results can share. Srcs excluded from the computation
        # (_plan_shared_computation) have no fragments to compare : they join
        # their representative's subset, identical by construction.
        by_signature = {}
        candidates.each do |drawing_def|
          next if @precomputed_shared.key?(drawing_def)
          signature = _shared_result_signature(drawing_def, fragment_paths_by_drawing_def[drawing_def] || [])
          (by_signature[signature] ||= []) << drawing_def
        end

        by_signature.each_value do |shared_drawing_defs|
          candidates.each do |drawing_def|
            representative_drawing_def = @precomputed_shared[drawing_def]
            shared_drawing_defs << drawing_def if !representative_drawing_def.nil? && shared_drawing_defs.include?(representative_drawing_def)
          end
          next if shared_drawing_defs.length < 2
          shared_containers = shared_drawing_defs.map { |drawing_def| drawing_def.container }

          extra_instances = definition.instances.reject { |instance| instance.deleted? || shared_containers.include?(instance) }
          if extra_instances.empty?
            plan[:skip_make_unique_containers][shared_containers.first] = true
          elsif !@make_unique && shared_drawing_defs.length == drawing_defs.length && extra_instances.none? { |instance| LockUtils.effectively_locked?(instance) }
            # make_unique: false and the subset covers every src of the
            # definition : single writer, the shared definition is rebuilt in
            # place and the extra (external) instances follow the result — no
            # make_unique, no reattachment (Case B collapses into Case A).
            # Unless an extra instance is locked : it must keep the original
            # definition, the subset keeps the Case B reattachment below.
            plan[:skip_make_unique_containers][shared_containers.first] = true
          else
            # Reattaching requires ComponentInstance#definition= (SketchUp >= 2022)
            next unless shared_containers.all? { |shared_container| shared_container.respond_to?(:definition=) }
            shared_containers[1..-1].each { |shared_container| plan[:reassignments] << [ shared_container, shared_containers.first ] }
          end

          shared_drawing_defs[1..-1].each { |drawing_def| plan[:dropped_drawing_defs][drawing_def] = true }
          plan[:shared_members][shared_containers.first] = shared_containers[1..-1]
        end

      end

      plan
    end

    # Exact plane key of a quantized coplanar triangle batch : gcd-reduced
    # SIGNED integer normal + offset (signed : opposite facing coplanar faces
    # never merge). nil when every triangle is degenerate after quantization.
    def _quantized_plane_key(quantized_triangles)
      quantized_triangles.each do |q0, q1, q2|
        ux = q1[0] - q0[0] ; uy = q1[1] - q0[1] ; uz = q1[2] - q0[2]
        vx = q2[0] - q0[0] ; vy = q2[1] - q0[1] ; vz = q2[2] - q0[2]
        nx = uy * vz - uz * vy
        ny = uz * vx - ux * vz
        nz = ux * vy - uy * vx
        next if nx == 0 && ny == 0 && nz == 0
        gcd = nx.gcd(ny).gcd(nz)
        return [ nx / gcd, ny / gcd, nz / gcd, (nx * q0[0] + ny * q0[1] + nz * q0[2]) / gcd ]
      end
      nil
    end

    # Canonical sorted keys of the given net directed boundary edges. Manifold
    # may imprint T-vertices (collinear mid-edge vertices, placement dependent
    # world-space intersections) differently on geometrically identical
    # results : collinear chains are collapsed so that two identical local
    # boundaries sign identically whatever the imprints. Coordinates are
    # quantized integers : the collinearity test is exact. Vertices shared by
    # several loops (2+ in/out edges) are conservatively kept.
    def _canonical_boundary_keys(edge_counts)

      edges = []
      edge_counts.each { |(a, b), count| count.times { edges << [ a, b ] } }

      fn_collinear_forward = lambda { |a, v, b|
        d1x = v[0] - a[0] ; d1y = v[1] - a[1] ; d1z = v[2] - a[2]
        d2x = b[0] - v[0] ; d2y = b[1] - v[1] ; d2z = b[2] - v[2]
        d1y * d2z == d1z * d2y && d1z * d2x == d1x * d2z && d1x * d2y == d1y * d2x &&
          d1x * d2x + d1y * d2y + d1z * d2z > 0
      }

      loop do
        in_indices = {}
        out_indices = {}
        edges.each_with_index do |(a, b), index|
          (in_indices[b] ||= []) << index
          (out_indices[a] ||= []) << index
        end
        merged = false
        in_indices.each do |vertex, incoming|
          outgoing = out_indices[vertex]
          next unless incoming.length == 1 && !outgoing.nil? && outgoing.length == 1
          a = edges[incoming.first][0]
          b = edges[outgoing.first][1]
          next if a == vertex || b == vertex || a == b
          next unless fn_collinear_forward.call(a, vertex, b)
          edges.delete_at([ incoming.first, outgoing.first ].max)
          edges.delete_at([ incoming.first, outgoing.first ].min)
          edges << [ a, b ]
          merged = true
          break
        end
        break unless merged
      end

      edges.map { |a, b| "#{a.join(',')}>#{b.join(',')}" }.sort
    end

    # Canonical signature of the result attributed to the given src root
    # drawing def, expressed in its own local space : two instances of the same
    # definition with equal signatures rebuild to the same local content.
    # Covers everything the rebuild consumes : target node path, quantized
    # directed BOUNDARY edges per coplanar same-attribute batch group (the
    # interior tessellation diagonals and coplanar batch seams cancel out in
    # pairs, the collinear chains are collapsed — _canonical_boundary_keys —
    # so the signature is independent of the triangulation and batch partition
    # Manifold chose and of its placement dependent T-vertex imprints ;
    # winding corrected on mirror
    # transformations), material, layer, virtual flag and surface partition
    # (first-appearance indices over the sorted batches). Quantization may only
    # produce false NEGATIVES (borderline rounding -> distinct definitions, as
    # before).
    def _shared_result_signature(drawing_def, fragment_paths)

      transformation = (drawing_def.transformation * drawing_def.container_transformation).inverse
      transformation = nil if transformation.identity?
      flipped = !transformation.nil? && TransformationUtils.flipped?(transformation)
      tolerance = SolidMeshDef::TOLERANCE

      # Net directed edge counts, accumulated per (path, plane, material,
      # layer, virtual, surface) group : an interior diagonal — or, in
      # merge_coplanar mode, a seam between two coplanar batches the rebuild
      # will merge anyway — is traversed once in each direction and cancels
      # out, whatever the accumulation order. Manifold partitions the result
      # triangles by face provenance, which is placement dependent (cut
      # imprint areas) : without the coplanar grouping, two geometrically
      # identical results could sign differently.
      batch_index = 0
      grouped_edge_counts = {}
      fragment_paths.each do |fragment_def, path|
        path_key = path.join('.')
        fragment_def.each_triangle_batch do |face_info_def, triangles|
          material_id = face_info_def.nil? || face_info_def.material.nil? ? 0 : face_info_def.material.object_id
          layer_id = face_info_def.nil? || face_info_def.layer.nil? ? 0 : face_info_def.layer.object_id
          virtual = !face_info_def.nil? && face_info_def.virtual? ? 1 : 0
          surface_info_def = face_info_def.nil? ? nil : face_info_def.surface_info_def

          quantized_triangles = triangles.map { |points|
            points = points.map { |point| point.transform(transformation) } unless transformation.nil?
            points = points.reverse if flipped
            points.map { |point| point.to_a.map { |v| (v / tolerance).round } }
          }

          batch_index += 1
          group_id = @merge_coplanar ? _quantized_plane_key(quantized_triangles) : batch_index
          edge_counts = (grouped_edge_counts[[ path_key, group_id, material_id, layer_id, virtual, surface_info_def ]] ||= {})

          quantized_triangles.each do |quantized|
            [ [ 0, 1 ], [ 1, 2 ], [ 2, 0 ] ].each do |index_a, index_b|
              a = quantized[index_a]
              b = quantized[index_b]
              reverse_count = edge_counts[[ b, a ]]
              if !reverse_count.nil? && reverse_count > 0
                edge_counts[[ b, a ]] = reverse_count - 1
              else
                edge_counts[[ a, b ]] = (edge_counts[[ a, b ]] || 0) + 1
              end
            end
          end

        end
      end

      records = grouped_edge_counts.map { |(path_key, _, material_id, layer_id, virtual, surface_info_def), edge_counts|
        [ "#{path_key}|#{_canonical_boundary_keys(edge_counts).join(';')}|#{material_id}|#{layer_id}|#{virtual}", surface_info_def ]
      }

      records.sort_by! { |key, _| key }
      surface_indices = {}
      records.map { |key, surface_info_def|
        surface_index = surface_info_def.nil? ? -1 : (surface_indices[surface_info_def] ||= surface_indices.length)
        "#{key}|#{surface_index}"
      }.join("\n")
    end

    # Excludes from the boolean computation the srcs provably identical to a
    # representative BEFORE computing anything : same definition, same root
    # material and layer, isolated (tolerance inflated bounds) from every
    # other src (no possible fusion), rigidly placed relative to the
    # representative, and with the same relevant cuts (bounds overlap) in
    # local space (_local_cut_signature). Boolean operations commute with
    # rigid motions : the representative's result stands for every excluded
    # src. The exclusions feed _plan_shared_definitions, which attaches the
    # excluded srcs to their representative's shared subset — an excluded src
    # has no fragments, so its representative MUST end up shareable : isolation
    # guarantees it (never fused into a multi src fragment, never a cut).
    # Returns { excluded drawing_def => representative drawing_def }.
    def _plan_shared_computation

      exclusions = {}
      return exclusions if @src_drawing_defs.length < 2

      # Src root containers grouped by shared definition, as in
      # _plan_shared_definitions
      groups = {}
      @src_drawing_defs.each do |drawing_def|
        container = drawing_def.container
        next unless container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
        next if container.deleted?
        (groups[container.definition] ||= []) << drawing_def
      end
      groups = groups.select { |definition, drawing_defs| drawing_defs.length > 1 && drawing_defs.map { |drawing_def| drawing_def.container }.uniq.length == drawing_defs.length }
      return exclusions if groups.empty?

      margin = SolidMeshDef::TOLERANCE * 2
      fn_world_bounds = lambda { |drawing_def|
        bounds = Geom::BoundingBox.new
        local_bounds = drawing_def.bounds
        if local_bounds.valid?
          (0..7).each { |corner_index| bounds.add(local_bounds.corner(corner_index).transform(drawing_def.transformation)) }
        end
        bounds
      }
      fn_overlap = lambda { |bounds_a, bounds_b|
        bounds_a.valid? && bounds_b.valid? &&
          bounds_a.min.x <= bounds_b.max.x + margin && bounds_b.min.x <= bounds_a.max.x + margin &&
          bounds_a.min.y <= bounds_b.max.y + margin && bounds_b.min.y <= bounds_a.max.y + margin &&
          bounds_a.min.z <= bounds_b.max.z + margin && bounds_b.min.z <= bounds_a.max.z + margin
      }

      src_bounds = {}
      @src_drawing_defs.each { |drawing_def| src_bounds[drawing_def] = fn_world_bounds.call(drawing_def) }
      cut_bounds = {}
      @cut_drawing_defs.each { |drawing_def| cut_bounds[drawing_def] = fn_world_bounds.call(drawing_def) }

      cut_containers = @cut_drawing_defs.map { |cut_drawing_def| cut_drawing_def.container }
      cut_mesh_defs = {}

      groups.each do |definition, drawing_defs|

        candidates = drawing_defs.select { |drawing_def|
          !cut_containers.include?(drawing_def.container) &&
            @src_drawing_defs.none? { |other_drawing_def| !other_drawing_def.equal?(drawing_def) && fn_overlap.call(src_bounds[drawing_def], src_bounds[other_drawing_def]) }
        }
        next if candidates.length < 2

        by_key = {}
        candidates.each do |drawing_def|
          relevant_cut_defs = @cut_drawing_defs.select { |cut_drawing_def| fn_overlap.call(src_bounds[drawing_def], cut_bounds[cut_drawing_def]) }
          container = drawing_def.container
          key = [
            _local_cut_signature(drawing_def, relevant_cut_defs, cut_mesh_defs),
            container.material.nil? ? 0 : container.material.object_id,
            container.layer.nil? ? 0 : container.layer.object_id
          ]
          (by_key[key] ||= []) << drawing_def
        end

        by_key.each_value do |shared_drawing_defs|
          next if shared_drawing_defs.length < 2
          representative_drawing_def = shared_drawing_defs.first
          shared_drawing_defs[1..-1].each do |drawing_def|
            exclusions[drawing_def] = representative_drawing_def if _rigidly_related?(representative_drawing_def, drawing_def)
          end
        end

      end

      exclusions
    end

    # Canonical signature of the given cut drawing defs expressed in the given
    # src drawing def local space, built on the SAME canonicalization as
    # _shared_result_signature (quantized directed boundary edges per source
    # face, material, layer, virtual flag, surface partition), plus the cut
    # curve segments. Cut mesh defs are memoized in cut_mesh_defs (world
    # coordinates, one tessellation per cut whatever the number of candidates).
    def _local_cut_signature(drawing_def, cut_drawing_defs, cut_mesh_defs)

      transformation = (drawing_def.transformation * drawing_def.container_transformation).inverse
      transformation = nil if transformation.identity?
      flipped = !transformation.nil? && TransformationUtils.flipped?(transformation)
      tolerance = SolidMeshDef::TOLERANCE

      records = []
      curve_keys = []
      cut_drawing_defs.each do |cut_drawing_def|

        mesh_def = (cut_mesh_defs[cut_drawing_def] ||= SolidMeshDef.from_drawing_def(cut_drawing_def))
        vertices = mesh_def.vertices
        face_ids = mesh_def.face_ids
        face_info_defs = mesh_def.face_info_defs

        quantized_cache = {}
        fn_quantized = lambda { |vertex_index|
          quantized_cache[vertex_index] ||= begin
            point = Geom::Point3d.new(vertices[vertex_index * 3], vertices[vertex_index * 3 + 1], vertices[vertex_index * 3 + 2])
            point = point.transform(transformation) unless transformation.nil?
            point.to_a.map { |v| (v / tolerance).round }
          end
        }

        edge_counts_by_face_id = {}
        mesh_def.face_indices.each_slice(3).with_index do |triangle_indices, triangle_index|
          edge_counts = (edge_counts_by_face_id[face_ids[triangle_index]] ||= {})
          quantized = triangle_indices.map { |vertex_index| fn_quantized.call(vertex_index) }
          quantized = quantized.reverse if flipped
          [ [ 0, 1 ], [ 1, 2 ], [ 2, 0 ] ].each do |index_a, index_b|
            a = quantized[index_a]
            b = quantized[index_b]
            reverse_count = edge_counts[[ b, a ]]
            if !reverse_count.nil? && reverse_count > 0
              edge_counts[[ b, a ]] = reverse_count - 1
            else
              edge_counts[[ a, b ]] = (edge_counts[[ a, b ]] || 0) + 1
            end
          end
        end

        edge_counts_by_face_id.each do |face_id, edge_counts|
          face_info_def = face_info_defs[face_id]
          material_id = face_info_def.nil? || face_info_def.material.nil? ? 0 : face_info_def.material.object_id
          layer_id = face_info_def.nil? || face_info_def.layer.nil? ? 0 : face_info_def.layer.object_id
          virtual = !face_info_def.nil? && face_info_def.virtual? ? 1 : 0
          surface_info_def = face_info_def.nil? ? nil : face_info_def.surface_info_def
          boundary_keys = _canonical_boundary_keys(edge_counts)
          records << [ "#{boundary_keys.join(';')}|#{material_id}|#{layer_id}|#{virtual}", surface_info_def ]
        end

        mesh_def.curve_info_defs.each do |curve_info_def|
          segment_keys = curve_info_def.segments.map { |segment_points|
            segment_points.map { |point|
              point = point.transform(transformation) unless transformation.nil?
              point.to_a.map { |v| (v / tolerance).round }
            }.sort.flatten.join(',')
          }.sort
          curve_keys << segment_keys.join(';')
        end

      end

      records.sort_by! { |key, _| key }
      surface_indices = {}
      signature_lines = records.map { |key, surface_info_def|
        surface_index = surface_info_def.nil? ? -1 : (surface_indices[surface_info_def] ||= surface_indices.length)
        "#{key}|#{surface_index}"
      }
      signature_lines.concat(curve_keys.sort)
      signature_lines.join("\n")
    end

    # True when drawing def b's root container placement is a rigid motion
    # (rotation / translation / mirror : no scale, no shear) of a's : the only
    # relative placements where a world-space boolean computation is
    # guaranteed to produce the same local result for both.
    def _rigidly_related?(drawing_def_a, drawing_def_b)
      ta = drawing_def_a.transformation * drawing_def_a.container_transformation
      tb = drawing_def_b.transformation * drawing_def_b.container_transformation
      m = (tb * ta.inverse).to_a
      return false if m[3].abs > 1e-9 || m[7].abs > 1e-9 || m[11].abs > 1e-9 || (m[15] - 1.0).abs > 1e-9
      x = Geom::Vector3d.new(m[0], m[1], m[2])
      y = Geom::Vector3d.new(m[4], m[5], m[6])
      z = Geom::Vector3d.new(m[8], m[9], m[10])
      (x.length - 1.0).abs <= 1e-6 && (y.length - 1.0).abs <= 1e-6 && (z.length - 1.0).abs <= 1e-6 &&
        (x % y).abs <= 1e-6 && (y % z).abs <= 1e-6 && (z % x).abs <= 1e-6
    end

    # Names of the locked operand instances, refused up front : src root
    # containers (locked or reachable through a locked occurrence path — the
    # operation rewrites their definition) and their non-virtual sub
    # containers (locked directly — their faces are erased). Virtual glued
    # containers (machinings) are not operands. Empty in keep_srcs mode : the
    # srcs are left untouched.
    def _locked_operand_names
      names = []
      return names if @keep_srcs
      fn_check_children = lambda { |container_def|
        container_def.container_defs.each do |child_def|
          child_container = child_def.container
          next if child_container.nil? || child_container.deleted?
          next if SolidMeshDef.virtual_glued_container?(child_container)
          if child_container.locked?
            names << _instance_display_name(child_container)
          else
            fn_check_children.call(child_def)
          end
        end
      }
      locked_cache = {}
      @src_drawing_defs.each do |drawing_def|
        container = drawing_def.container
        next unless container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
        next if container.deleted?
        if LockUtils.effectively_locked?(container, locked_cache)
          names << _instance_display_name(container)
        else
          fn_check_children.call(drawing_def)
        end
      end
      names.uniq
    end

    def _instance_display_name(instance)
      name = instance.name.to_s
      name = instance.definition.name.to_s if name.empty? && instance.respond_to?(:definition)
      name
    end

    # Merges the faces and sub container tree of the given DrawingContainerDef
    # into the given node ({ :faces, :children, :erase_tokens }).
    # Glued cuts-opening containers are not operands : their subtree is skipped,
    # the instances survive the operation (re-glued or erased as orphans later).
    def _append_container_def_to_node(container_def, node)
      node[:faces].concat(container_def.face_manipulators.map(&:face)).uniq!
      container_def.container_defs.each do |child_def|
        next if SolidMeshDef.virtual_glued_container?(child_def.container)
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
        # make_unique: false : the shared child definition is rebuilt in place,
        # unless another operand instance also writes it (fallback). The
        # conflict map is keyed by definition : it holds through the possible
        # parent cloning (make_unique is shallow, children keep their definition).
        child_instance.make_unique if child_instance.definition.instances.length > 1 && (@make_unique || @conflicting_definitions.key?(child_instance.definition))
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
        next if face_info_def.virtual?   # Virtual machining faces do not drive attribution
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
    def _resolve_rebuild_target(container_def, src_node_owners, model)
      if container_def.is_a?(DrawingDef)
        drawing_def = container_def
        container = drawing_def.container
        transformation = (drawing_def.transformation * drawing_def.container_transformation).inverse
        if container.is_a?(Sketchup::Group) || container.is_a?(Sketchup::ComponentInstance)
          return [ nil, nil, nil ] if container.deleted?
          [ container, container.definition.entities, transformation ]
        else
          [ nil, model.entities, transformation ]
        end
      else
        instance = @resolved_instances[container_def]
        if instance.nil? || instance.deleted?
          _resolve_rebuild_target(src_node_owners[container_def], src_node_owners, model)
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

        # Virtual machining geometry (glued cuts-opening containers) is not
        # rebuilt : the glued instance survives and punches its opening again.
        # The holes it leaves in the host faces are filled back below. Nodes
        # sliced by the operation are materialized instead : their geometry is
        # rebuilt as-is and their instance erased by the caller.
        fill_plan = _solid_virtual_fill_plan(fragment_def)

        fragment_def.each_triangle_batch do |face_info_def, triangles|
          next if !fill_plan.nil? && !face_info_def.nil? && face_info_def.virtual? && fill_plan[:virtual_nodes].key?(face_info_def.container_def)

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

        next if fill_plan.nil?
        @materialized_container_defs.concat(fill_plan[:materialized_nodes].keys) unless @materialized_container_defs.nil?
        fill_plan[:loops].each do |points, face_info_def|
          points = points.map { |point| point.transform(transformation) } unless transformation.nil?
          begin
            face = entities.add_face(points)
          rescue => e
            next # Unfillable seam : leave the hole rather than abort the operation
          end
          next if face.nil?
          processed_face_ids[face.entityID] = true
          face_infos[face] = face_info_def
          if preserve_materials && !face_info_def.nil?
            face.material = face_info_def.material unless face_info_def.material.nil?
            face.layer = face_info_def.layer unless face_info_def.layer.nil?
          end
          # Orient like the adjacent rebuilt face so the coplanar merge below
          # can absorb the fill into the host face
          neighbor = face.edges.flat_map(&:faces).find { |other_face| !other_face.equal?(face) && face_infos.key?(other_face) }
          face.reverse! if !neighbor.nil? && !face.normal.samedirection?(neighbor.normal)
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

        # Degenerate remnants : Manifold may emit a sliver triangle thinner
        # than the SketchUp merge tolerance (e.g. bridging a corner and a
        # nearby hole rim) ; SketchUp partially collapses it on creation and
        # the merge cascade leaves it as a zero area face bounded by two
        # coincident edges. A face with less than 3 edges is never a
        # legitimate piece of the shell : erase it, with the edges bounding
        # only such faces.
        degenerate_faces = face_infos.keys.select { |face| !face.deleted? && face.edges.length < 3 }
        unless degenerate_faces.empty?
          degenerate_entities = []
          degenerate_faces.each do |face|
            degenerate_entities.concat(face.edges.select { |edge| edge.faces.all? { |edge_face| degenerate_faces.include?(edge_face) } })
            degenerate_entities << face
          end
          entities.erase_entities(degenerate_entities)
        end
      end

      _solid_weld_curves(entities, face_infos, curve_info_defs, transformation: transformation) if restore_curves

      face_infos.keys.reject(&:deleted?)
    end

    # Analyses the virtual geometry of a fragment (faces of glued cuts-opening
    # containers, not meant to be rebuilt), one verdict PER virtual node so that
    # an intact machining and a sliced one coexisting in the fragment are
    # handled independently :
    # - nil when the fragment holds no virtual face, otherwise
    # - { :loops =>, :virtual_nodes =>, :materialized_nodes => } where
    #   - virtual_nodes are the container defs whose seams with the real
    #     triangles all chain into closed loops : their faces are skipped and
    #     the holes they leave are filled by :loops ([ points, face_info_def ]
    #     tuples, attributed to the adjacent real face info so the coplanar
    #     merge absorbs them),
    #   - materialized_nodes are the container defs whose seams do not close
    #     (machining sliced by the operation) : their surviving geometry is
    #     rebuilt as real geometry, and the caller erases their glued instance
    #     (a standard machining cut in half is not a machining anymore).
    def _solid_virtual_fill_plan(fragment_def)
      face_ids = fragment_def.face_ids
      return nil if face_ids.nil?

      # Directed edges of real triangles (their winding orients the fill loops),
      # undirected edge keys of virtual triangles, grouped by virtual node
      real_edges = {}
      virtual_edge_keys_by_node = {}
      fragment_def.face_indices.each_slice(3).with_index do |triangle_indices, triangle_index|
        face_info_def = fragment_def.face_info_defs[face_ids[triangle_index]]
        i0, i1, i2 = triangle_indices
        if !face_info_def.nil? && face_info_def.virtual?
          virtual_edge_keys = (virtual_edge_keys_by_node[face_info_def.container_def] ||= {})
          [ [ i0, i1 ], [ i1, i2 ], [ i2, i0 ] ].each { |a, b| virtual_edge_keys[a < b ? [ a, b ] : [ b, a ]] = true }
        else
          [ [ i0, i1 ], [ i1, i2 ], [ i2, i0 ] ].each { |a, b| real_edges[[ a, b ]] = face_info_def }
        end
      end
      return nil if virtual_edge_keys_by_node.empty?

      points = fragment_def.points
      plan = { :loops => [], :virtual_nodes => {}, :materialized_nodes => {} }
      virtual_edge_keys_by_node.each do |container_def, virtual_edge_keys|

        # Seam edges of this node : real directed edges whose undirected key is
        # also traversed by one of its virtual triangles
        seam_next = {}
        materialize = false
        real_edges.each do |(a, b), face_info_def|
          next unless virtual_edge_keys.key?(a < b ? [ a, b ] : [ b, a ])
          if seam_next.key?(a)    # Non-manifold seam vertex
            materialize = true
            break
          end
          seam_next[a] = [ b, face_info_def ]
        end
        materialize = true if seam_next.empty?

        # Chain the seams into loops ; any open chain materializes the node.
        # A closed but NON-PLANAR loop does too : it means the operation sliced
        # the machining (the seam spans the host plane AND the cut plane) and
        # such a hole cannot be filled by a single face anyway.
        loops = []
        until materialize || seam_next.empty?
          start_index = seam_next.each_key.first
          loop_points = []
          loop_face_info_def = nil
          current_index = start_index
          loop do
            next_edge = seam_next.delete(current_index)
            if next_edge.nil?   # Open chain
              materialize = true
              break
            end
            loop_points << points[current_index]
            loop_face_info_def ||= next_edge[1]
            current_index = next_edge[0]
            break if current_index == start_index
          end
          break if materialize
          if loop_points.length < 3 || !_solid_points_coplanar?(loop_points)
            materialize = true
            break
          end
          loops << [ loop_points, loop_face_info_def ]
        end

        if materialize
          plan[:materialized_nodes][container_def] = true
        else
          plan[:virtual_nodes][container_def] = true
          plan[:loops].concat(loops)
        end

      end

      plan
    end

    # True when all the given points lie on a single plane (within the solid
    # tolerance). Degenerate point sets (all collinear) are not coplanar.
    def _solid_points_coplanar?(points)
      origin = points[0]
      first_vector = nil
      normal = nil
      points.each do |point|
        vector = origin.vector_to(point)
        next unless vector.valid?
        if first_vector.nil?
          first_vector = vector
        else
          cross = first_vector * vector
          if cross.valid?
            normal = cross
            break
          end
        end
      end
      return false if normal.nil?
      plane = [ origin, normal.normalize ]
      tolerance = SolidMeshDef::TOLERANCE
      points.all? { |point| point.distance_to_plane(plane).to_f <= tolerance }
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
      # Weld chains the given edges by connectivity : a group can produce
      # several disconnected chains, and a chain of a single edge still becomes
      # a 1-edge Curve. Explode those, a curve must hold at least 2 edges.
      fn_weld = lambda { |edges|
        next if edges.length < 2
        begin
          curves = entities.weld(edges)
          curves.each { |curve| curve.first_edge.explode_curve if !curve.deleted? && curve.count_edges < 2 }
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

      # Intersection seams: group by the pair of original surfaces involved.
      # A planar face has no surface : its face info is its identity, so that
      # the seams a curved surface shares with two DIFFERENT planar faces are
      # never chained into a single (non-planar) curve — e.g. a notch cut into
      # a cylinder : the arc (surface/wall) must not weld with the straight
      # sides (surface/bottom) they touch at the notch corners.
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
        seam_key = [ surface_info_def_0 || face_info_def_0, surface_info_def_1 || face_info_def_1 ].map(&:object_id).sort
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
    # the face whose plane is the instance gluing plane (its local XY plane : the
    # face normal is parallel to the instance Z axis and the plane carries the
    # instance origin) and whose boundary contains the origin — the origin may sit
    # on an edge shared with a perpendicular face, whose plane carries it too.
    # Instances whose host area was cut away stay unglued.
    def _solid_reglue_instances(instances, faces)
      return if instances.empty?

      # The origin lies on the original gluing plane, but the rebuilt plane may
      # have been snapped away by up to the tolerance.
      tolerance = SolidMeshDef::TOLERANCE * 2

      instances.each do |instance|
        next if instance.deleted?
        next unless instance.respond_to?(:glued_to=) # Sketchup::Group#glued_to= requires SketchUp >= 2021.1
        origin = instance.transformation.origin
        zaxis = instance.transformation.zaxis
        host_face = faces.find { |face|
          next false if face.deleted?
          next false unless face.normal.parallel?(zaxis)
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