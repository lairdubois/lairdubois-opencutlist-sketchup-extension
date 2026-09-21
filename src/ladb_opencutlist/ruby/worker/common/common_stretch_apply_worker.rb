module Ladb::OpenCutList

  require_relative '../../helper/instance_paths_helper'
  require_relative '../../model/stretch/stretch_split_def'
  require_relative '../../model/stretch/stretch_def'
  require_relative '../../model/stretch/stretch_apply_result_def'
  require_relative '../../utils/lock_utils'
  require_relative '../../utils/path_utils'

  # Applies a StretchDef (see CommonStretchSplitWorker and StretchSplitDef#stretch_def) to the
  # model : the mutation half of a stretch.
  #
  # - selection_path : the path of the context holding the stretched instances (the path the
  #   split ipaths were built from, without the instances),
  # - selection_instances : the stretched instances,
  # - make_unique : the stretched definitions are made unique instead of propagating the stretch
  #   to their other instances,
  # - extern_instances_ref_positions : Instance => Point3d cache of the extern instances positions,
  #   to share between chained stretches of the same selection,
  # - wrap_operation : run in two operations of its own (a transparent one for the make_unique
  #   routine, then the stretch). With false, the caller owns the enclosing operation,
  # - transparent : the 'transparent' flag of these operations.
  #
  # Shared definitions are made unique when needed (the edited context visible through a locked
  # occurrence path, locked extern instances, groups, instances deformed differently). Otherwise
  # the extern instances of the stretched definitions are back translated so that they keep their
  # place. The selection may be remapped to made unique copies : read it back from the result.
  #
  # A StretchSplitDef is single use : its container defs are remapped and memoized here.
  class CommonStretchApplyWorker

    include InstancePathsHelper

    OPERATION_NONE = StretchSplitDef::OPERATION_NONE
    OPERATION_MOVE = StretchSplitDef::OPERATION_MOVE
    OPERATION_SPLIT = StretchSplitDef::OPERATION_SPLIT

    StretchedDefinitionDef = Struct.new(
      :ddv,
      :containers
    ) do

      def initialize(
        ddv,
        containers = []
      )
        super
      end

    end

    def initialize(stretch_def,

                   selection_path:,
                   selection_instances:,

                   make_unique: false,
                   extern_instances_ref_positions: {},

                   wrap_operation: true,
                   operation_name: 'OCL Stretch',
                   transparent: false

    )

      @stretch_def = stretch_def

      @selection_path = selection_path
      @selection_instances = selection_instances

      @make_unique = make_unique
      @extern_instances_ref_positions = extern_instances_ref_positions

      @wrap_operation = wrap_operation
      @operation_name = operation_name
      @transparent = transparent

    end

    # -----

    def run

      result_def = StretchApplyResultDef.new(@selection_path, @selection_instances)

      if !@stretch_def.is_a?(StretchDef) || !@selection_path.is_a?(Array) || !@selection_instances.is_a?(Array) || (model = Sketchup.active_model).nil?
        result_def.errors << [ 'default.error' ]
        return result_def
      end

      split_def = @stretch_def.split_def
      axis = split_def.axis
      t_coefs, emv, esv, edvs = @stretch_def.t_coefs, @stretch_def.emv, @stretch_def.esv, @stretch_def.edvs
      et, evpspe, container_defs = split_def.et, split_def.evpspe, split_def.container_defs

      # Prepare uniqueness data
      container_defs.first.compute_md5(axis, t_coefs)
      container_defs.first.compute_entity_pos

      # Divide in 2 operations to hide native make_unique group operations
      # The first operation set with "next_transparent = true"

      model.start_operation(@operation_name, true, true, @transparent) if @wrap_operation
      begin

        # Isolate context routine
        # -----------------------

        # If the edited context is visible through a locked occurrence path, make the selection
        # path unique first so the stretch cannot alter what the lock protects.
        unless (locked_aliased_level = _locked_aliased_context_level).nil?
          _isolate_locked_aliased_context(locked_aliased_level, container_defs)
        end

        # Make Unique routine
        # -------------------

        make_unique_o = @make_unique

        container_defs.group_by(&:definition)
                      .sort_by { |definition, container_defs| container_defs.map(&:depth).max }  # Ensure that lowest depth containers are processed first
                      .each do |definition, container_defs|

          next if definition.nil?

          count_stretched_instances = container_defs.size
          count_instances = definition.count_instances
          count_used_instances = definition.count_used_instances

          # Process extern instances
          if !make_unique_o && count_used_instances > count_stretched_instances

            # -- Extern instances exist

            # Extract definition instances
            definition_instances = definition.instances

            # Extract stretched instances
            stretched_instances = container_defs.map(&:container)

            if count_used_instances > count_instances

              selection_path_size = @selection_path.size

              # Retrieve all instance paths
              _instances_to_paths(definition_instances, (extern_instance_paths = []), model.entities)

              # Reduce to extern instances only
              extern_instance_paths.delete_if { |path|
                path.take(selection_path_size) == @selection_path &&
                stretched_instances.include?(path[selection_path_size])
              }

              # An instance is locked if AT LEAST ONE of its paths is locked: re-pointing it to the
              # stretched definition would also alter its occurrences under locked ancestors.
              locked_extern_instances = extern_instance_paths.select { |path| LockUtils.locked_path?(path) }.map! { |path| path.last }
              unlocked_extern_instances = extern_instance_paths.map { |path| path.last }.uniq - locked_extern_instances

              make_unique_e = locked_extern_instances.any?

            else

              locked_extern_instances, unlocked_extern_instances = LockUtils.partition_locked_extern_instances(definition, stretched_instances)

              # The Ruby API does not enforce locks: without make unique, locked extern instances
              # would be silently deformed and back translated.
              make_unique_e = locked_extern_instances.any?

            end

          else

            # -- No extern instances

            make_unique_e = false

          end

          # Groups with edges must be made unique because SketchUp make them unique when transform entities and this causing troubles with the stretching.
          make_unique_g = definition.group? && (!make_unique_o || container_defs.first.edge_defs.any? && count_stretched_instances > 1)

          container_defs.sort_by { |container_def| -container_def.operation }
                        .group_by(&:md5)
                        .each do |md5, container_defs|

            make_unique_d = make_unique_o && count_stretched_instances < count_used_instances
            make_unique_c = (make_unique_e || make_unique_g || make_unique_d || container_defs.size < count_stretched_instances) && container_defs.any? { |container_def| container_def.operation == OPERATION_SPLIT }

            if make_unique_c

              if definition.group?

                container_defs.each do |container_def|

                  new_container = container_def.container.make_unique
                  new_definition = new_container.definition

                  container_def.container = new_container
                  container_def.edge_defs.each do |edge_def|
                    edge_def.edge = new_definition.entities[edge_def.entity_pos]
                  end
                  container_def.cline_defs.each do |cline_def|
                    cline_def.cline = new_definition.entities[cline_def.entity_pos]
                  end
                  container_def.snap_defs.each do |snap_def|
                    snap_def.snap = new_definition.entities[snap_def.entity_pos]
                  end
                  container_def.children.each do |container_def|
                    container_def.container = new_definition.entities[container_def.entity_pos]
                  end

                end

              else

                container_def0 = container_defs.first

                new_container = container_def0.container.make_unique
                new_definition = new_container.definition

                container_def0.container = new_container

                container_defs.each do |container_def|
                  container_def.container.definition = new_definition
                  container_def.edge_defs.each do |edge_def|
                    edge_def.edge = new_definition.entities[edge_def.entity_pos]
                  end
                  container_def.cline_defs.each do |cline_def|
                    cline_def.cline = new_definition.entities[cline_def.entity_pos]
                  end
                  container_def.snap_defs.each do |snap_def|
                    snap_def.snap = new_definition.entities[snap_def.entity_pos]
                  end
                  container_def.children.each do |container_def|
                    container_def.container = new_definition.entities[container_def.entity_pos]
                  end
                end

                if make_unique_e && defined?(unlocked_extern_instances)
                  unlocked_extern_instances.each do |extern_instance|
                    extern_instance.definition = new_definition
                  end
                end

              end

              count_stretched_instances -= container_defs.size
              count_used_instances -= container_defs.size

            end

          end

        end

      rescue => e
        PLUGIN.dump_exception(e)
        model.abort_operation if @wrap_operation
        result_def.errors << [ 'core.error.exception', { :error => e.message } ]
        return result_def
      end
      model.commit_operation if @wrap_operation

      model.start_operation(@operation_name, true, false, @transparent) if @wrap_operation
      begin

        # Stretch routine
        # ---------------

        # Keep stretched definitions (and their instances) to avoid stretching the same definition twice
        stretched_definition_defs = {}

        # A sorting order is defined to ensure that the furthest edges are moved first
        sorting_order = (esv.valid? && esv.samedirection?(evpspe)) ? -1 : 1

        # Precompute the inverse of the selection path transformation (invariant within the loop)
        selection_path_t = PathUtils.get_transformation(@selection_path, IDENTITY)
        selection_path_ti = selection_path_t.inverse

        container_defs.each do |container_def|

          next if container_def.model?

          entities = container_def.entities
          container = container_def.container
          container_edv = edvs[container_def.section_def]

          # Stretch definition edges only once
          unless stretched_definition_defs.has_key?(container_def.definition)

            # Move edges
            # ----------

            container_def.edge_defs
                         .select { |edge_def| edge_def.operation == OPERATION_MOVE }
                         .group_by(&:start_section_def)
                         .sort_by { |section_def, _| section_def.index * sorting_order }.to_h # Sort edges to be sure that farthest points are moved first
                         .each do |section_def, edge_defs|

              edv = edvs[section_def]

              edge_def0 = edge_defs.first
              t = edge_def0.transformation

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == section_def && edv.valid?

              target_position0 = edge_def0.ref_position
              target_position0 = target_position0.offset(edv.transform(t.inverse)) if edv.valid?
              current_position0 = edge_def0.edge.start.position

              v = current_position0.vector_to(target_position0)

              entities.transform_entities(Geom::Transformation.translation(v), edge_defs.map(&:edge)) if v.valid?

            end

            # Move clines
            # -----------

            container_def.cline_defs
                         .each do |cline_def|

              t = cline_def.transformation

              # Compute Start point

              edv = edvs[cline_def.start_section_def]

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == cline_def.start_section_def && edv.valid?

              target_start = cline_def.ref_start_position
              target_start = target_start.offset(edv.transform(t.inverse)) if edv.valid?

              # Compute End point

              edv = edvs[cline_def.end_section_def]

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == cline_def.end_section_def && edv.valid?

              target_end = cline_def.ref_end_position
              target_end = target_end.offset(edv.transform(t.inverse)) if edv.valid?

              # Apply

              cline_def.cline.direction = target_start.vector_to(target_end)
              cline_def.cline.position = cline_def.cline.start = target_start
              cline_def.cline.end = target_end

            end

            # Move snaps
            # ----------

            container_def.snap_defs
                         .select { |snap_def| snap_def.operation == OPERATION_MOVE }
                         .group_by(&:section_def)
                         .each do |section_def, snap_defs|

              edv = edvs[section_def]

              snap_def0 = snap_defs.first
              t = snap_def0.transformation

              # Subtract container move
              edv -= container_edv
              edv.reverse! if container_def.section_def == section_def && edv.valid?

              target_position0 = snap_def0.ref_position
              target_position0 = target_position0.offset(edv.transform(t.inverse)) if edv.valid?
              current_position0 = snap_def0.snap.position

              v = current_position0.vector_to(target_position0)

              entities.transform_entities(Geom::Transformation.translation(v), snap_defs.map(&:snap)) if v.valid?

            end

            # Flag definition as stretched + keep edv converted to definition space
            ddv = container_edv
            unless ddv.nil?
              ddv += emv if container_def.depth <= 1 && @selection_instances.include?(container_def.container) # Apply "move" translation (if the centered option is enabled)
              if container_def.depth > 0
                ddv = ddv.transform((container_def.transformation * container_def.container_transformation).inverse)
              else
                # Root container: unlike children, its ContainerDef transformation is 'et' (edit -> world),
                # not a local -> edit map. The edit -> definition conversion must be composed from the live
                # path transformations: (path * container).inverse * et. Do NOT use 'det' here: the drawing_def
                # root transformation is orthonormalized by the decomposition worker (mirror stripped), so 'det'
                # carries a stray reflection for mirrored instances, while this composition stays consistent
                # with the edge moves whatever the rotation or mirror of the instance and its path.
                ddv = ddv.transform((selection_path_t * container_def.container_transformation).inverse * et)
              end
            end
            stretched_definition_defs[container_def.definition] = StretchedDefinitionDef.new(ddv)

          end

          # Keep stretched container def, if not make unique to be able to back transform extern instances
          stretched_definition_defs[container_def.definition].containers << container_def.container if !make_unique_o && container_def.component? && container_def.operation == OPERATION_SPLIT

          # Move container
          # --------------

          next if container_def.operation == OPERATION_NONE ||
                  container_def.section_def.nil?

          edv = container_edv

          # Subtract parent container move
          unless container_def.parent.nil? || container_def.parent.section_def.nil?
            edv -= edvs[container_def.parent.section_def]
            edv.reverse! if container_def.parent.section_def == container_def.section_def && edv.valid?
          end

          # Apply move translation (if the centered option is enabled)
          edv += emv if container_def.depth <= 1 && @selection_instances.include?(container_def.container)

          target_position = container_def.ref_position
          target_position = target_position.offset(edv.transform(if container_def.depth == 0
                                                                   selection_path_ti * container_def.transformation
                                                                 else
                                                                   container_def.transformation.inverse
                                                                 end)) if edv.valid?
          current_position = ORIGIN.transform(container.transformation)

          v = current_position.vector_to(target_position)

          if container.respond_to?(:glued_to) && container.glued_to
            # Deforming the host face of a glued instance makes SketchUp rewrite its
            # transformation in place to strip any mirror (det < 0). Re-impose the full
            # reference transformation at the target position, even when v is zero.
            container.transformation = Geom::Transformation.translation(container_def.ref_position.vector_to(target_position)) * container_def.ref_transformation
          else
            container.transform!(Geom::Transformation.translation(v)) if v.valid?
          end

        end

        # Apply back translation on extern instances if needed
        unless make_unique_o

          stretched_definition_defs.each do |definition, stretched_definition_def|

            if stretched_definition_def.containers.any?
              extern_instances = definition.instances - stretched_definition_def.containers
              if extern_instances.any?

                extern_instances.each do |extern_instance|

                  t = extern_instance.transformation

                  ref_position = @extern_instances_ref_positions[extern_instance] ||= ORIGIN.transform(t)

                  target_position = ref_position
                  target_position = target_position.offset(stretched_definition_def.ddv.transform(t)) if !stretched_definition_def.ddv.nil? && stretched_definition_def.ddv.valid?
                  current_position = ORIGIN.transform(t)

                  v = current_position.vector_to(target_position)

                  extern_instance.transform!(Geom::Transformation.translation(v)) if v.valid?

                end

              end
            end

          end

        end

      rescue => e
        PLUGIN.dump_exception(e)
        model.abort_operation if @wrap_operation
        result_def.errors << [ 'core.error.exception', { :error => e.message } ]
        return result_def
      end
      model.commit_operation if @wrap_operation

      result_def.selection_path = @selection_path
      result_def.selection_instances = @selection_instances
      result_def
    end

    private

    # Returns the 0-based index in the selection path of the first ancestor to make unique when the
    # edited context (the last path element's definition) is also visible through a locked
    # occurrence path, or nil if the context is safe. Occurrence paths that share the context
    # without any lock are left shared: the stretch is expected to propagate to them.
    def _locked_aliased_context_level
      path = @selection_path
      return nil if !path.is_a?(Array) || path.empty?
      return nil unless (context = path.last).respond_to?(:definition)

      _instances_to_paths(context.definition.instances, (occurrence_paths = []), Sketchup.active_model.entities)

      level = nil
      occurrence_paths.each do |occurrence_path|
        next if occurrence_path == path ||
                !LockUtils.locked_path?(occurrence_path)
        divergence = 0
        divergence += 1 while divergence < occurrence_path.size && divergence < path.size && occurrence_path[divergence] == path[divergence]
        level = level.nil? ? divergence : [ level, divergence ].min
      end
      level
    end

    # Make the selection path unique from 'level' down to its last element so that the stretch
    # edits a context that no locked occurrence can see (SketchUp locks are not enforced by the Ruby
    # API), then remap the selection and the container defs to the copies. make_unique preserves the
    # entity order, so copies are retrieved by index.
    def _isolate_locked_aliased_context(level, container_defs)
      path = @selection_path
      instances = @selection_instances

      child_positions = path.each_cons(2).map { |parent, child| parent.definition.entities.to_a.index(child) }
      instance_positions = instances.map { |instance| path.last.definition.entities.to_a.index(instance) }

      new_path = path.take(level)
      current = path[level]
      (level...path.size).each do |j|
        current.make_unique if current.definition.count_used_instances > 1
        new_path << current
        current = current.definition.entities[child_positions[j]] if j < path.size - 1
      end

      new_instances = instance_positions.map { |position| new_path.last.definition.entities[position] }

      mapping = instances.zip(new_instances).to_h
      container_defs.each do |container_def|
        container_def.container = mapping[container_def.container] if mapping.key?(container_def.container)
      end

      @selection_path = new_path
      @selection_instances = new_instances
    end

  end

end
