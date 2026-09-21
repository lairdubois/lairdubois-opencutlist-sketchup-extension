module Ladb::OpenCutList

  require 'digest'
  require_relative '../data_container'
  require_relative 'stretch_def'

  # Result of CommonStretchSplitWorker : the content of a selection split in sections along the
  # stretch axis, expressed in the 'edit' space (et : edit -> global).
  #
  # Pure data + pure computation : nothing here reads or writes the model, except the live
  # positions the preview helpers read from the split entities.
  #
  # A split def is valid until the model changes : once applied by CommonStretchApplyWorker (which
  # remaps and memoizes things on its container defs), compute a new one.
  class StretchSplitDef < DataContainer

    OPERATION_NONE = 0
    OPERATION_MOVE = 1
    OPERATION_SPLIT = 2

    attr_reader :drawing_def,               # DrawingDef of the whole content, NOT flattened, transformed to the edit space
                :axis,                      # Stretch axis in edit space (X_AXIS, Y_AXIS or Z_AXIS)
                :et,                        # Edit -> global transformation
                :det,                       # Drawing def -> edit transformation
                :eb,                        # Content bounds in edit space
                :epmin, :epmax,             # Bounds face centers along the axis, min and max
                :eps, :epe,                 # Bounds face centers : start (opposite of the grip) and end (the grip)
                :evpspe,                    # eps -> epe vector
                :reversed,                  # true if evpspe goes against the axis
                :max_compression_distance,  # Max compression of a plain (end grip) stretch
                :section_defs,              # Array<SectionDef>, sorted along the axis
                :gap_defs,                  # Array<[ SectionDef, SectionDef, distance ]> between sections that own matter
                :container_defs             # Array<ContainerDef>, root first

    def initialize(drawing_def:, axis:, et:, det:, eb:, epmin:, epmax:, eps:, epe:, evpspe:, reversed:, max_compression_distance:, section_defs:, gap_defs:, container_defs:)
      @drawing_def = drawing_def
      @axis = axis
      @et = et
      @det = det
      @eb = eb
      @epmin = epmin
      @epmax = epmax
      @eps = eps
      @epe = epe
      @evpspe = evpspe
      @reversed = reversed
      @max_compression_distance = max_compression_distance
      @section_defs = section_defs
      @gap_defs = gap_defs
      @container_defs = container_defs
    end

    def self.xyz_method(axis)
      { X_AXIS => :x, Y_AXIS => :y, Z_AXIS => :z }[axis]
    end

    def xyz_method
      StretchSplitDef.xyz_method(@axis)
    end

    def root_container_def
      @container_defs.first
    end

    # -----

    # The start (opposite) face center and the grip face center, in the global space.
    def start_point
      @eps.transform(@et)
    end

    def end_point
      @epe.transform(@et)
    end

    # The grip outward direction in the global space : offsetting the grip along it expands the
    # shape, offsetting it backward compresses the shape.
    def outward_direction
      @evpspe.transform(@et)
    end

    # -----

    # False when a section content oversizes its section along the axis (a curve crossing a
    # cutter) : the stretch would deform it.
    def sections_valid?
      xyz_method = self.xyz_method
      @section_defs.all? { |section_def| !section_def.bounds.valid? || section_def.min_xyz <= section_def.bounds.min.send(xyz_method) && section_def.max_xyz >= section_def.bounds.max.send(xyz_method) }
    end

    # -----

    # The translation coefficient of each section - in [0, 1], to be multiplied by the move
    # distance - for the interior handle of the given index (1 = the first interior section).
    # Below the handle point each gap takes '+1/L' of the move, above each takes '-1/U' : the shape
    # is stretched on one side and compressed on the other, so the overall dimension is preserved.
    # The handle sits in the matter of its section, hence every gap is clearly on one side or the
    # other. nil for a plain stretch or an out of range index.
    def interior_t_coefs(interior_index)
      gap_count = @section_defs.length - 1
      return nil if interior_index.nil? || gap_count < 1
      return nil unless interior_index >= 1 && interior_index <= gap_count - 1

      l = interior_index.to_f
      u = (gap_count - interior_index).to_f
      gap_coefs = (0...gap_count).map { |i| i < interior_index ? 1.0 / l : -1.0 / u }

      t_coefs = [ 0.0 ]
      gap_coefs.each { |gap_coef| t_coefs << t_coefs.last + gap_coef }
      t_coefs
    end

    # The largest interior move that keeps every compressed gap above the minimal distance.
    # 'way' is 1.0 when the move follows the axis, -1.0 otherwise. Gap deltas being linear in the
    # move distance, each gap that shrinks caps the move.
    def interior_max_distance(t_coefs, way)
      return nil unless @gap_defs.is_a?(Array) && !t_coefs.nil?
      @gap_defs.map { |gap_def|
        section_def0, section_def1, distance = gap_def
        coef = (t_coefs[section_def1.index] - t_coefs[section_def0.index]) * way
        next if coef >= 0
        [ (distance - 1.mm) / -coef, 0 ].max  # Keep 1mm to avoid geometry merge problems
      }.compact.min
    end

    # -----

    # The stretch of the grip from 'ps' to 'pe' (global space), silently clamped to the max
    # compression distance.
    # - centered : the shape is stretched on both sides (ignored by an interior stretch),
    # - measure_outside : the displayed measure line starts on the opposite face (overall dimension),
    # - interior_index : the interior handle moved, nil for a plain (end grip) stretch. An interior
    #   handle distributes the move over the gaps of both sides : the overall dimension is
    #   preserved, so the "centered" option and the outside measure have no meaning there.
    def stretch_def(ps, pe, centered: false, measure_outside: false, interior_index: nil)
      return nil unless ps.is_a?(Geom::Point3d) && pe.is_a?(Geom::Point3d)

      eti = @et.inverse

      v = ps.vector_to(pe)     # "Move" vector in global space
      ev = v.transform(eti)

      t_coefs = interior_index.nil? ? nil : interior_t_coefs(interior_index)

      factor = t_coefs.nil? && centered ? 2.0 : 1.0

      if t_coefs.nil?

        # Limit move to max compression distance
        compressed = ev.valid? && (@reversed ? ev.samedirection?(@axis) : !ev.samedirection?(@axis))
        if compressed && (v.length * factor > @max_compression_distance)
          pe = ps.offset(v, @max_compression_distance / factor)
          v = ps.vector_to(pe)
        end

      else

        # Both ways compress a gap : limit move to the largest one that keeps them all above the
        # minimal distance
        if ev.valid?
          way = ev.samedirection?(@axis) ? 1.0 : -1.0
          max_distance = interior_max_distance(t_coefs, way)
          if !max_distance.nil? && v.length > max_distance
            pe = ps.offset(v, max_distance)
            v = ps.vector_to(pe)
          end
        end

      end

      if factor > 1.0
        mv = v.reverse
        sv = v
        sv.length *= factor if sv.valid?
      else
        mv = Geom::Vector3d.new
        sv = v
      end

      emv = mv.transform(eti)   # "Move" vector in edit space
      esv = sv.transform(eti)   # "Stretch" vector in edit space

      # Compute move vectors for each section
      edvs = @section_defs.map { |section_def|
        edv = Geom::Vector3d.new(esv)
        if esv.valid?
          if t_coefs.nil?
            edv.length = edv.length * section_def.index / (@section_defs.length - 1) if @section_defs.length > 1
          elsif (coef = t_coefs[section_def.index]).nil? || coef <= 0
            edv = Geom::Vector3d.new   # Anchored section
          else
            edv.length = esv.length * coef
          end
        end
        [ section_def, edv ]
      }.to_h

      lps = measure_outside && interior_index.nil? ? start_point.offset(mv) : ps
      lpe = pe

      StretchDef.new(
        split_def: self,
        interior_index: interior_index,
        factor: factor,
        t_coefs: t_coefs,
        emv: emv,
        esv: esv,
        edvs: edvs,
        lps: lps,
        lpe: lpe
      )
    end

    # The plain (end grip) stretch that moves the grip face by 'distance' along its outward
    # direction : > 0 expands, < 0 compresses. The programmatic shortcut of #stretch_def.
    def stretch_def_by_distance(distance, centered: false)
      return nil unless (v = outward_direction).valid?
      ps = end_point
      stretch_def(ps, ps.offset(v, distance), centered: centered)
    end

    # Convert a "measure" - overall dimension if 'measure_outside', stretch delta otherwise - to the
    # matching stretch end point, starting from 'ps'.
    # The way is given by 'direction' if any, else by 'reference_point' (ps -> reference_point), else
    # by 'fallback_direction'. Pass an explicit 'direction' to let the sign of the measure drive the
    # way.
    # Returns nil or { end_point:, pmin:, pmax:, compression_distance:, max_compression_distance: }.
    def measure_def(ps, measure, reference_point, direction: nil, fallback_direction: nil, centered: false, measure_outside: false, interior_index: nil)
      return nil if (stretch_def = self.stretch_def(ps, reference_point, centered: centered, measure_outside: measure_outside, interior_index: interior_index)).nil?

      factor = stretch_def.factor
      max_compression_distance = @max_compression_distance
      measure_outside = measure_outside && interior_index.nil?

      if (v = direction).nil?
        v = stretch_def.lps.vector_to(stretch_def.lpe)
        v = fallback_direction unless v.valid?  # Fallback to the grip outward direction
      end
      return nil if v.nil? || !v.valid?

      pmin = @epmin.transform(@et)
      pmax = @epmax.transform(@et)

      if measure_outside
        real_distance = (measure - (pmax - pmin).length) / factor
        compression_distance = (real_distance * factor).abs
      else
        real_distance = measure
        compression_distance = real_distance.abs
        max_compression_distance = max_compression_distance / factor
      end

      unless interior_index.nil?
        # An interior stretch compresses gaps both ways : the max distance depends on the way
        t_coefs = interior_t_coefs(interior_index)
        way = v.transform(@et.inverse).samedirection?(@axis) ? 1.0 : -1.0
        way = -way if real_distance < 0
        interior_max_distance = interior_max_distance(t_coefs, way)
        max_compression_distance = interior_max_distance unless interior_max_distance.nil?
      end

      {
        end_point: ps.offset(v, real_distance),
        pmin: pmin,
        pmax: pmax,
        compression_distance: compression_distance,
        max_compression_distance: max_compression_distance,
      }
    end

    # -----

    SectionDef = Struct.new(
      :index,
      :min_xyz,
      :max_xyz,
      :bounds
    ) do

      def contains_point?(point, xyz_method)
        min_xyz <= point.send(xyz_method) && max_xyz >= point.send(xyz_method)
      end

      def contains_bounds?(bounds, xyz_method)
        min_xyz <= bounds.min.send(xyz_method) && max_xyz >= bounds.max.send(xyz_method)
      end

      def intersects_bounds?(bounds, xyz_method)
        min_xyz <= bounds.max.send(xyz_method) && max_xyz >= bounds.min.send(xyz_method)
      end

    end

    ContainerDef = Struct.new(
      :container,
      :transformation,
      :depth,
      :ref_transformation,
      :section_def,
      :operation,
      :entity_pos,
      :edge_defs,
      :cline_defs,
      :snap_defs,
      :parent,
      :children,
    ) do

      def initialize(
        container,
        transformation,
        depth,
        ref_transformation,
        section_def,
        operation,
        entity_pos = -1,
        edge_defs = [],
        cline_defs = [],
        snap_defs = [],
        parent = nil,
        children = []
      )
        super
        @md5 = nil
      end

      def definition
        return container.definition if container.respond_to?(:definition)
        nil
      end

      def entities
        return container.entities if container.respond_to?(:entities)
        return definition.entities unless definition.nil?
        nil
      end

      def group?
        unless (definition = self.definition).nil?
          return definition.group?
        end
        false
      end

      def component?
        unless (definition = self.definition).nil?
          return !definition.group?
        end
        false
      end

      def model?
        container.is_a?(Sketchup::Model)
      end

      def ref_position
        return nil if ref_transformation.nil?
        ORIGIN.transform(ref_transformation)
      end

      def container_transformation
        return container.transformation if container.respond_to?(:transformation)
        IDENTITY
      end

      def md5
        @md5
      end

      # 'section_coefs' holds the translation coefficient of each section, indexed by section index,
      # or nil when the sections translate proportionally to their index - the profile of a plain
      # stretch. Deltas must be measured on these coefficients and not on the section indices : the
      # profile of an interior handle move is not linear, so two containers anchored on both sides of
      # the moved section are deformed in opposite ways even though their index deltas match.
      def compute_md5(axis, section_coefs = nil)
        @md5 ||= begin
          data = []
          data << container.definition.persistent_id if container.respond_to?(:definition)

          sign = 1.0
          unless parent.nil?
            if (local_axis = axis.transform((transformation * container.transformation).inverse)).valid?
              data << (local_axis.angle_between(axis) % Math::PI).round(6) # Differentiating rotations but not perfect aligned mirrors
              data << local_axis.length.to_f.round(6) if operation == OPERATION_SPLIT  # Differentiating scaling
              sign = _axis_sign(local_axis)
            end
          end

          fn_coef = lambda { |sd|
            next 0.0 if sd.nil?
            next sd.index.to_f if section_coefs.nil?   # Proportional to the index : the linear profile of a plain stretch
            (section_coefs[sd.index] || 0.0).to_f
          }
          fn_delta = lambda { |other_section_def|
            # Signed delta anchored on the local axis way to be able to unify flipped elements
            delta = ((fn_coef.call(section_def) - fn_coef.call(other_section_def)) * sign).round(6)
            delta == 0.0 ? 0.0 : delta   # '-0.0' and '0.0' are equal but do not dump the same
          }

          if operation == OPERATION_SPLIT
            data << edge_defs.map { |edge_def|
              [
                edge_def.edge.persistent_id,
                fn_delta.call(edge_def.start_section_def),
                fn_delta.call(edge_def.end_section_def)
              ]
            } if edge_defs.any?
            data << cline_defs.map { |cline_def|
              [
                cline_def.cline.persistent_id,
                fn_delta.call(cline_def.start_section_def),
                fn_delta.call(cline_def.end_section_def)
              ]
            } if cline_defs.any?
            data << snap_defs.map { |snap_def|
              [
                snap_def.snap.persistent_id,
                fn_delta.call(snap_def.section_def)
              ]
            } if snap_defs.any?
          end

          # Children md5 alone carries no positional info. Under a SPLIT container, each child is translated
          # according to its own section, so two instances whose children fall in sections with different
          # "deltas" (relative to the container's anchor section) deform differently and must not share
          # their definition. This can't be caught by the edge deltas above when the container has no
          # direct edges (e.g. a component made only of sub-components).
          data << children.map { |container_def|
            [
              container_def.compute_md5(axis, section_coefs),
              if operation == OPERATION_SPLIT && !section_def.nil? && !container_def.section_def.nil?
                fn_delta.call(container_def.section_def)
              end
            ]
          }

          Digest::MD5.hexdigest(Marshal.dump(data))
        end
      end

      # Two instances of a same definition see the stretch axis - expressed in that definition space -
      # as a same vector up to its sign. Anchoring the section deltas on a sign read from that vector
      # alone therefore keeps them comparable between an instance and its mirrored twin : the delta
      # sign flips with the axis, their product does not.
      def _axis_sign(local_axis)
        [ local_axis.x, local_axis.y, local_axis.z ].each do |coord|
          next if coord.to_f.round(6) == 0.0
          return coord.to_f < 0 ? -1.0 : 1.0
        end
        1.0
      end

      def compute_entity_pos
        return if (entities = self.entities).nil?
        entity_positions = entities.each_with_index.to_h { |entity, index| [ entity, index ] }
        edge_defs.each do |edge_def|
          edge_def.entity_pos = entity_positions[edge_def.edge]
        end
        cline_defs.each do |cline_def|
          cline_def.entity_pos = entity_positions[cline_def.cline]
        end
        snap_defs.each do |snap_def|
          snap_def.entity_pos = entity_positions[snap_def.snap]
        end
        children.each do |container_def|
          container_def.entity_pos = entity_positions[container_def.container]
          container_def.compute_entity_pos
        end
      end

    end

    EdgeDef = Struct.new(
      :edge,
      :transformation,
      :ref_position,
      :start_section_def,
      :end_section_def,
      :operation,
      :entity_pos
    ) do

      def initialize(
        edge,
        transformation,
        ref_position,
        start_section_def,
        end_section_def,
        operation,
        entity_pos = -1
      )
        super
      end

      def transformation_inverse
        @transformation_inverse ||= transformation.inverse
      end

    end

    ClineDef = Struct.new(
      :cline,
      :transformation,
      :ref_start_position,
      :ref_end_position,
      :start_section_def,
      :end_section_def,
      :operation,
      :entity_pos
    ) do

      def initialize(
        cline,
        transformation,
        ref_start_position,
        ref_end_position,
        start_section_def,
        end_section_def,
        operation,
        entity_pos = -1
      )
        super
      end

      def transformation_inverse
        @transformation_inverse ||= transformation.inverse
      end

    end

    SnapDef = Struct.new(
      :snap,
      :transformation,
      :ref_position,
      :section_def,
      :operation,
      :entity_pos
    ) do

      def initialize(
        snap,
        transformation,
        ref_position,
        section_def,
        operation,
        entity_pos = -1
      )
        super
      end

      def transformation_inverse
        @transformation_inverse ||= transformation.inverse
      end

    end

  end

end
