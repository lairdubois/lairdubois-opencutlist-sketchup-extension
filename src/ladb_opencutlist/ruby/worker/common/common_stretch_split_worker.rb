module Ladb::OpenCutList

  require_relative 'common_drawing_decomposition_worker'
  require_relative '../../lib/kuix/geom/bounds3d'
  require_relative '../../model/drawing/drawing_def'
  require_relative '../../model/stretch/stretch_split_def'
  require_relative '../../utils/lock_utils'

  # Splits the content of the given instance paths in sections along a stretch axis : the
  # analysis half of a stretch, read only. Produces a StretchSplitDef, to be turned into a
  # StretchDef (StretchSplitDef#stretch_def) then applied by CommonStretchApplyWorker.
  #
  # - ipaths : the stretched instances, as full paths (selection path + instance),
  # - et : the 'edit' transformation (edit -> global), whose axes are the stretch axes,
  # - axis : the stretch axis in edit space (X_AXIS, Y_AXIS or Z_AXIS),
  # - grip_index : the Kuix::Bounds3d face that is pulled, its opposite face being the start,
  # - ratios : the cutters of the axis, in ]0, 1[ along the content edit bounds,
  # - eb : the content bounds in edit space, computed from the full decomposition if nil,
  # - root_split : true if the root container is only the instances holder (several stretched
  #   instances), defaults to 'ipaths.length != 1'.
  #
  # Returns nil if the content cannot be decomposed.
  class CommonStretchSplitWorker

    DRAWING_DEF_PARAMETERS = {
      ignore_surfaces: true,
      ignore_faces: false,
      ignore_edges: false,
      ignore_soft_edges: false,
      ignore_clines: false,
      ignore_snaps: false,
      container_validator: CommonDrawingDecompositionWorker::CONTAINER_VALIDATOR_ALL,
      flatten: false,
    }.freeze

    OPERATION_NONE = StretchSplitDef::OPERATION_NONE
    OPERATION_MOVE = StretchSplitDef::OPERATION_MOVE
    OPERATION_SPLIT = StretchSplitDef::OPERATION_SPLIT

    def initialize(ipaths,

                   et:,
                   axis:,
                   grip_index:,
                   ratios: [ 0.5 ],

                   eb: nil,
                   root_split: nil,
                   drawing_def_parameters: {}

    )

      @ipaths = Array(ipaths)

      @et = et
      @axis = axis
      @grip_index = grip_index
      @ratios = Array(ratios)

      @eb = eb
      @root_split = root_split.nil? ? @ipaths.length != 1 : root_split
      @drawing_def_parameters = DRAWING_DEF_PARAMETERS.merge(drawing_def_parameters)

    end

    # -----

    # The bounds of the given drawing def content, expressed in the 'et' edit space. Faces
    # bounds are preferred over edges, then clines, container by container.
    def self.compute_edit_bounds(drawing_def, et)
      return drawing_def.bounds if et == drawing_def.transformation
      eb = Geom::BoundingBox.new
      return eb unless drawing_def.is_a?(DrawingContainerDef)

      eti = et.inverse

      # TODO Improve the way to compute the edit bounds

      fn = lambda do |drawing_container_def|

        if drawing_container_def.faces_bounds.valid?
          eb.add(drawing_container_def.face_manipulators
                                      .flat_map { |manipulator| manipulator.outer_loop_manipulator.points
                                                                           .map { |point| point.transform(eti * drawing_def.transformation)} }
          ) if drawing_container_def.face_manipulators.any?
        elsif drawing_container_def.edges_bounds.valid?
          eb.add(drawing_container_def.edge_manipulators
                                      .flat_map { |manipulator| manipulator.points
                                                                           .map { |point| point.transform(eti * drawing_def.transformation)} }
          ) if drawing_container_def.edge_manipulators.any?
          eb.add(drawing_container_def.curve_manipulators
                                      .flat_map { |manipulator| manipulator.points
                                                                           .map { |point| point.transform(eti * drawing_def.transformation)} }
          ) if drawing_container_def.curve_manipulators.any?
        elsif drawing_container_def.clines_bounds.valid?
          eb.add(drawing_container_def.cline_manipulators
                                      .flat_map { |manipulator| manipulator.points
                                                                           .map { |point| point.transform(eti * drawing_def.transformation) } }
          ) if drawing_container_def.cline_manipulators.any?
        end

        drawing_container_def.container_defs.each do |child_drawing_container_def|
          fn.call(child_drawing_container_def)
        end

      end

      fn.call(drawing_def)

      eb
    end

    # -----

    def run
      return nil if @ipaths.empty? || @et.nil? || @axis.nil? || @grip_index.nil?
      return nil if (xyz_method = StretchSplitDef.xyz_method(@axis)).nil?

      et = @et

      # Compute a drawing_def that include all content
      return nil unless (drawing_def = CommonDrawingDecompositionWorker.new(@ipaths, **@drawing_def_parameters).run).is_a?(DrawingDef)

      eb = @eb.nil? ? CommonStretchSplitWorker.compute_edit_bounds(drawing_def, et) : @eb
      keb = Kuix::Bounds3d.new.copy!(eb)

      det = drawing_def.transformation.inverse * et
      deti = det.inverse

      # Transform drawing_def to be expressed in the edit space
      drawing_def.transform!(det)

      grip_index_s = Kuix::Bounds3d.face_opposite(@grip_index)
      grip_index_e = @grip_index

      eps = keb.face_center(grip_index_s).to_p
      epe = keb.face_center(grip_index_e).to_p
      evpspe = eps.vector_to(epe)

      reversed = evpspe.valid? && !evpspe.samedirection?(@axis)

      epmin = reversed ? epe : eps
      epmax = reversed ? eps : epe

      container_defs = []

      v_s = {}  # Vertex => DrawingContainerDef => SectionDef

      ratios = @ratios.sort
      ratios.uniq!
      ratios.reverse!.map! { |ratio| 1 - ratio } if reversed

      section_defs = ([ Float::INFINITY * (reversed ? 1 : -1) ] + ratios.map { |ratio| eps.send(xyz_method) + ratio * evpspe.length * (reversed ? -1 : 1) } + [ Float::INFINITY * (reversed ? -1 : 1) ]).each_cons(2).map.with_index { |min_max, index|
        StretchSplitDef::SectionDef.new(
          index,
          min_max.min,
          min_max.max,
          Geom::BoundingBox.new
        )
      }

      fn_store_vertex_section_def = lambda { |vertex, drawing_container_def, section_def|
        (v_s[vertex] ||= {})[drawing_container_def] = section_def
      }
      fn_fetch_vertex_section_def = lambda { |vertex, drawing_container_def|
        (v_s[vertex] ||= {})[drawing_container_def]
      }

      fn_analyse = lambda do |drawing_container_def, parent_section_def = nil, depth = 0|

        # Extract container
        # -----------------

        section_def = parent_section_def
        if section_def.nil?

          if drawing_container_def.is_root? && @root_split

            # No section_def if the root container is just the instance holder

            operation = OPERATION_SPLIT

          # Check if the container is locked. Locked containers are never deformed (no SPLIT),
          # but they are translated with the section containing their origin: the lock protects
          # the container's shape, not its position within the stretched assembly.
          elsif LockUtils.locked?(drawing_container_def.container)

            container_origin = ORIGIN.transform(drawing_container_def.transformation * drawing_container_def.container.transformation)
            section_def = section_defs.find { |section_def| section_def.contains_point?(container_origin, xyz_method) }

            # Add the container bounds to the section bounds so the locked container is taken into
            # account by the max compression distance. If it straddles a cutter, the section
            # oversize check rejects the cutter layout instead of silently translating it.
            section_def.bounds.add(drawing_container_def.bounds) if !section_def.nil? && drawing_container_def.bounds.valid?

            operation = OPERATION_MOVE

          # Check if the container is glued or always face camera to search the section according to its origin only
          elsif drawing_container_def.container.respond_to?(:glued_to) && drawing_container_def.container.glued_to ||
                drawing_container_def.container.respond_to?(:definition) && (drawing_container_def.container.definition.behavior.always_face_camera? || drawing_container_def.container.definition.behavior.no_scale_mask? == 0b1111111)   # 0b1111111 = 127 (all disabld)

            container_origin = ORIGIN.transform(drawing_container_def.transformation * drawing_container_def.container.transformation)
            section_def = section_defs.find { |section_def| section_def.contains_point?(container_origin, xyz_method) }

            # Container bounds are not considered in this case

            operation = OPERATION_MOVE

          else

            # Check if container bounds is entirely inside a section
            section_def = section_defs.find { |section_def| section_def.contains_bounds?(drawing_container_def.bounds, xyz_method) }
            if section_def.nil?

              container_origin = ORIGIN.transform(drawing_container_def.is_root? ? deti : drawing_container_def.transformation * drawing_container_def.container.transformation)
              min_max = [ drawing_container_def.bounds.min, drawing_container_def.bounds.max ].min_by { |point| (point.send(xyz_method) - container_origin.send(xyz_method)).abs }

              # Default container section_def is where the bounds extreme is the nearest origin
              section_def = section_defs.find { |section_def| section_def.contains_point?(min_max, xyz_method) }

              operation = OPERATION_SPLIT

            else

              # Add the container bounds to the section bounds
              section_def.bounds.add(drawing_container_def.bounds)

              operation = OPERATION_MOVE

            end

          end

        else
          operation = OPERATION_NONE
        end

        container_def = StretchSplitDef::ContainerDef.new(
          drawing_container_def.container,
          drawing_container_def.transformation,
          depth,
          drawing_container_def.container.respond_to?(:transformation) ? drawing_container_def.container.transformation : nil,
          section_def,
          operation
        )
        container_defs << container_def

        # Keep container section as entire parent section
        parent_section_def = section_def unless operation == OPERATION_SPLIT

        # Extract edges
        # -------------

        # 1. Iterate on curves

        drawing_container_def.curve_manipulators.each do |cm|

          # Treat curves as a whole undeformable entity

          section_def = parent_section_def
          section_def ||= fn_fetch_vertex_section_def.call(cm.curve.first_edge.start, drawing_container_def)
          section_def ||= fn_fetch_vertex_section_def.call(cm.curve.last_edge.end, drawing_container_def)
          section_def ||= section_defs.find { |s| s.intersects_bounds?(cm.bounds, xyz_method) }
          unless section_def.nil?
            cm.curve.edges.each do |edge|
              container_def.edge_defs << StretchSplitDef::EdgeDef.new(
                edge,
                cm.transformation,
                edge.start.position,
                section_def,
                section_def,
                if operation == OPERATION_SPLIT
                  OPERATION_MOVE
                else
                  OPERATION_NONE
                end
              )
              fn_store_vertex_section_def.call(edge.start, drawing_container_def, section_def)
              fn_store_vertex_section_def.call(edge.end, drawing_container_def, section_def)
            end
            section_def.bounds.add(cm.points)  # Add to section bounds
          end

        end

        # 2. Iterate on edges

        drawing_container_def.edge_manipulators.each do |em|

          next if !parent_section_def.nil? && em.edge.soft? # Minor optimization - skip soft edges if container grabbed

          if parent_section_def.nil?
            start_section_def = fn_fetch_vertex_section_def.call(em.edge.start, drawing_container_def)
            if start_section_def.nil?
              start_section_def = section_defs.find { |s| s.contains_point?(em.start_point, xyz_method) }
              fn_store_vertex_section_def.call(em.edge.start, drawing_container_def, start_section_def)
            end
            end_section_def = fn_fetch_vertex_section_def.call(em.edge.end, drawing_container_def)
            if end_section_def.nil?
              end_section_def = section_defs.find { |s| s.contains_point?(em.end_point, xyz_method) }
              fn_store_vertex_section_def.call(em.edge.end, drawing_container_def, end_section_def)
            end
          else
            start_section_def = end_section_def = parent_section_def
          end

          next if start_section_def.nil? || end_section_def.nil?  # TODO : this should not occur

          container_def.edge_defs << StretchSplitDef::EdgeDef.new(
            em.edge,
            em.transformation,
            em.edge.start.position,
            start_section_def,
            end_section_def,
            if operation == OPERATION_SPLIT
              start_section_def == end_section_def ? OPERATION_MOVE : OPERATION_SPLIT
            else
              OPERATION_NONE
            end
          )

          if parent_section_def.nil? &&
             start_section_def == end_section_def &&
             em.edge.start.edges.all? { |edge| edge.curve.nil? } && em.edge.end.edges.all? { |edge| edge.curve.nil? }
            start_section_def.bounds.add(em.points)  # Add to content bbox
          end

        end

        # 3. Iterate on finite clines

        drawing_container_def.cline_manipulators.each do |cm|

          next if cm.infinite?

          if parent_section_def.nil?
            start_section_def = section_defs.find { |s| s.contains_point?(cm.start_point, xyz_method) }
            end_section_def = section_defs.find { |s| s.contains_point?(cm.end_point, xyz_method) }
          else
            start_section_def = end_section_def = parent_section_def
          end

          container_def.cline_defs << StretchSplitDef::ClineDef.new(
            cm.cline,
            cm.transformation,
            cm.cline.start,
            cm.cline.end,
            start_section_def,
            end_section_def,
            if operation == OPERATION_SPLIT
              start_section_def == end_section_def ? OPERATION_MOVE : OPERATION_SPLIT
            else
              OPERATION_NONE
            end
          )

          if parent_section_def.nil? &&
             start_section_def == end_section_def
            start_section_def.bounds.add(cm.points)  # Add to content bbox
          end

        end

        # 4. Iterate on snaps

        drawing_container_def.snap_manipulators.each do |sm|

          if parent_section_def.nil?
            section_def = section_defs.find { |s| s.contains_point?(sm.position, xyz_method) }
          else
            section_def = parent_section_def
          end

          next if section_def.nil?  # TODO : this should not occur

          container_def.snap_defs << StretchSplitDef::SnapDef.new(
            sm.snap,
            sm.transformation,
            sm.snap.position,
            section_def,
            if operation == OPERATION_SPLIT
              OPERATION_MOVE
            else
              OPERATION_NONE
            end
          )

          if parent_section_def.nil?
            section_def.bounds.add(sm.position)  # Add to content bbox
          end

        end

        # 5. Iterate over children

        depth += 1
        drawing_container_def.container_defs.each do |child_drawing_container_def|
          child = fn_analyse.call(child_drawing_container_def, parent_section_def, depth)
          child.parent = container_def
          container_def.children << child
        end

        container_def
      end

      fn_analyse.call(drawing_def)

      # Compute gaps between sections that own matter. A run of empty sections counts as a single
      # physical gap, hence the 'each_cons' on the filtered list.
      el = [ eps, evpspe ]
      sd = section_defs
      sd = sd.reverse if reversed
      vsd = sd.select { |section_def| section_def.bounds.valid? && !section_def.bounds.empty? }
      gap_defs = vsd
        .each_cons(2).map { |section_def0, section_def1|
          [
            section_def0,
            section_def1,
            section_def0.bounds.max.project_to_line(el).transform(et).distance(section_def1.bounds.min.project_to_line(el).transform(et))
          ]
        }

      # Compute max compression distance
      if vsd.one?
        # TODO : Improve this case where there's only one section
        drawing_size = drawing_def.bounds.min.project_to_line(el).transform(et).distance(drawing_def.bounds.max.project_to_line(el).transform(et))
        section_size = vsd.first.bounds.min.project_to_line(el).transform(et).distance(vsd.first.bounds.max.project_to_line(el).transform(et))
        min_distance = drawing_size - section_size
      else
        min_distance = gap_defs.map { |gap_def| gap_def.last }.min
        min_distance = 0 if min_distance.nil?
      end
      max_compression_distance = [ (min_distance * (vsd.size - 1)) - 1.mm, 0 ].max # Keep 1mm to avoid geometry merge problems

      StretchSplitDef.new(
        drawing_def: drawing_def,
        axis: @axis,
        et: et,
        det: det,
        eb: eb,   # Expressed in 'Edit' space
        epmin: epmin,
        epmax: epmax,
        eps: eps,
        epe: epe,
        evpspe: evpspe,
        reversed: reversed,
        max_compression_distance: max_compression_distance,
        section_defs: section_defs,
        gap_defs: gap_defs,
        container_defs: container_defs
      )
    end

  end

end
