module Ladb::OpenCutList

  # Detects congruent faces : two faces "match" if their loops can be superposed
  # by a rigid transformation (rotation + translation), whatever their position
  # and orientation in space.
  #
  # With mirror: true (default), a face also matches its mirrored counterpart,
  # i.e. the face "flipped over" (typically the two opposite big faces of a panel).
  #
  # Matching is done in two passes :
  # 1. a quantized, orientation independent signature (cyclic sequence of edge
  #    lengths and signed turn angles, reduced to its canonical rotation) used
  #    as a cheap pre-filter, hashable to group faces in O(n)
  # 2. an exact geometric verification : the alignment transformation is derived
  #    from the matching vertex correspondence and all loop points (outer and
  #    inner) are checked for superposition within SketchUp's tolerance
  module FaceMatcherHelper

    FACE_MATCHER_LENGTH_STEP = 1e-4   # Length quantization step (inches) used by signatures
    FACE_MATCHER_ANGLE_STEP = 1e-4    # Angle quantization step (radians) used by signatures

    # Returns the face manipulators from face_manipulators whose face is congruent
    # to reference_face_manipulator's face. The reference itself is excluded.
    def _find_matching_face_manipulators(reference_face_manipulator, face_manipulators, mirror: true)
      reference_signature = reference_face_manipulator.signature(mirror: mirror)
      return [] if reference_signature.nil?
      face_manipulators.select do |face_manipulator|
        next false if face_manipulator == reference_face_manipulator || face_manipulator.face == reference_face_manipulator.face
        face_manipulator.signature(mirror: mirror) == reference_signature &&
          _face_manipulators_congruent?(reference_face_manipulator, face_manipulator, mirror: mirror)
      end
    end

    # Full pairwise test : cheap signature compare, then geometric verification
    def _face_manipulators_match?(face_manipulator_a, face_manipulator_b, mirror: true)
      signature_a = face_manipulator_a.signature(mirror: mirror)
      return false if signature_a.nil?
      signature_a == face_manipulator_b.signature(mirror: mirror) &&
        _face_manipulators_congruent?(face_manipulator_a, face_manipulator_b, mirror: mirror)
    end

    # Tells how two faces match : :direct (superposable as is), :mirror
    # (superposable flipped over, e.g. the two opposite faces of a panel),
    # :both when the shape is achiral (a rectangle matches both ways),
    # nil when faces don't match.
    def _face_manipulators_match_kind(face_manipulator_a, face_manipulator_b)
      signature_a = face_manipulator_a.signature(mirror: true)
      return nil if signature_a.nil?
      return nil unless signature_a == face_manipulator_b.signature(mirror: true)
      direct = _face_variant_congruent?(face_manipulator_a, face_manipulator_b, false)
      mirrored = _face_variant_congruent?(face_manipulator_a, face_manipulator_b, true)
      return :both if direct && mirrored
      return :direct if direct
      return :mirror if mirrored
      nil
    end

    # The rigid transformation superposing face_manipulator_b onto
    # face_manipulator_a (both expressed in the same space), or nil when the
    # two faces are not congruent : what it takes to place a copy of B's
    # owner exactly where A is.
    #
    # With mirror: false, only a PROPER motion is ever returned - a mirrored
    # superposition is rejected rather than answered with a flipping
    # transformation, which would place a mirrored instance.
    def _face_manipulators_alignment_transformation(face_manipulator_a, face_manipulator_b, mirror: true)
      signature_a = face_manipulator_a.signature(mirror: mirror)
      return nil if signature_a.nil?
      return nil unless signature_a == face_manipulator_b.signature(mirror: mirror)
      transformation = _face_variant_alignment_transformation(face_manipulator_a, face_manipulator_b, false)
      return transformation unless transformation.nil?
      mirror ? _face_variant_alignment_transformation(face_manipulator_a, face_manipulator_b, true) : nil
    end

    # -- Signature (pre-filter) --

    # Orientation independent, hashable signature. Two congruent faces always
    # share the same signature. The converse is not guaranteed (quantization),
    # hence the geometric verification pass. Returns nil for degenerated faces.
    def _face_signature(face_manipulator, mirror: true)
      outer_points = face_manipulator.outer_loop_manipulator.points
      return nil if outer_points.length < 3
      normal = face_manipulator.normal
      inner_signatures = face_manipulator.inner_loop_manipulators.map { |loop_manipulator|
        _canonical_sequence(
          _loop_quantized_sequence(loop_manipulator.points, normal),
          mirror ? _loop_quantized_sequence(loop_manipulator.points.reverse, normal.reverse) : nil
        )
      }.sort
      [
        outer_points.length,
        inner_signatures.length,
        _canonical_sequence(
          _loop_quantized_sequence(outer_points, normal),
          mirror ? _loop_quantized_sequence(outer_points.reverse, normal.reverse) : nil
        ),
        inner_signatures
      ]
    end

    # -- Geometric verification --

    def _face_manipulators_congruent?(face_manipulator_a, face_manipulator_b, mirror: true)
      _face_variant_congruent?(face_manipulator_a, face_manipulator_b, false) ||
        mirror && _face_variant_congruent?(face_manipulator_a, face_manipulator_b, true)
    end

    private

    def _face_variant_congruent?(face_manipulator_a, face_manipulator_b, mirrored)
      !_face_variant_alignment_transformation(face_manipulator_a, face_manipulator_b, mirrored).nil?
    end

    # Tests one superposition kind and returns the transformation that achieves
    # it, or nil : mirrored = false tries to superpose B onto A as is (normals
    # aligned), mirrored = true tries with B flipped over (reversed traversal,
    # opposite normal).
    def _face_variant_alignment_transformation(face_manipulator_a, face_manipulator_b, mirrored)

      points_a = face_manipulator_a.outer_loop_manipulator.points
      return nil if points_a.length < 3
      sequence_a = _loop_sequence(points_a, face_manipulator_a.normal)

      points_b = face_manipulator_b.outer_loop_manipulator.points
      return nil unless points_b.length == points_a.length
      normal_b = face_manipulator_b.normal
      if mirrored
        points_b = points_b.reverse
        normal_b = normal_b.reverse
      end

      sequence_b = _loop_sequence(points_b, normal_b)
      points_a.length.times do |offset|
        next unless _sequences_match?(sequence_a, sequence_b, offset)
        t = _alignment_transformation(points_a, face_manipulator_a.normal, points_b, normal_b, offset)
        next unless _points_superpose?(points_a, points_b, offset, t)
        return t if _inner_loops_superpose?(face_manipulator_a, face_manipulator_b, t)
      end

      nil
    end

    # Intrinsic description of a loop : for each vertex, the outgoing edge length
    # and the turn angle, signed relatively to the given normal. Invariant by
    # rotation and translation ; only the start index and the traversal direction
    # depend on the face orientation.
    def _loop_sequence(points, normal)
      n = points.length
      Array.new(n) do |i|
        p_prev = points[(i - 1) % n]
        p = points[i]
        p_next = points[(i + 1) % n]
        v_in = p_prev.vector_to(p)
        v_out = p.vector_to(p_next)
        angle = v_in.angle_between(v_out)
        angle = -angle if (v_in * v_out) % normal < 0
        [ v_out.length.to_f, angle ]
      end
    end

    def _loop_quantized_sequence(points, normal)
      _loop_sequence(points, normal).map { |length, angle|
        [ (length / FACE_MATCHER_LENGTH_STEP).round, (angle / FACE_MATCHER_ANGLE_STEP).round ]
      }
    end

    # Smallest rotation of the sequence (and of its mirrored variant if given) :
    # removes the start index and traversal direction dependency.
    def _canonical_sequence(sequence, mirror_sequence = nil)
      candidates = (0...sequence.length).map { |k| sequence.rotate(k) }
      candidates.concat((0...mirror_sequence.length).map { |k| mirror_sequence.rotate(k) }) unless mirror_sequence.nil?
      candidates.min
    end

    def _sequences_match?(sequence_a, sequence_b, offset)
      sequence_a.each_with_index.all? do |(length, angle), i|
        other_length, other_angle = sequence_b[(i + offset) % sequence_b.length]
        (length - other_length).abs <= FACE_MATCHER_LENGTH_STEP && (angle - other_angle).abs <= FACE_MATCHER_ANGLE_STEP
      end
    end

    # Rigid transformation mapping points_b onto points_a assuming vertex i of A
    # corresponds to vertex i + offset of B, built from a frame at each
    # corresponding vertex (origin, outgoing edge as X axis, normal as Z axis).
    def _alignment_transformation(points_a, normal_a, points_b, normal_b, offset)
      _vertex_frame(points_a, 0, normal_a) * _vertex_frame(points_b, offset, normal_b).inverse
    end

    def _vertex_frame(points, index, normal)
      origin = points[index]
      x_axis = origin.vector_to(points[(index + 1) % points.length]).normalize
      Geom::Transformation.axes(origin, x_axis, normal * x_axis, normal)
    end

    def _points_superpose?(points_a, points_b, offset, t)
      points_a.each_with_index.all? { |point, i| point == points_b[(i + offset) % points_b.length].transform(t) }
    end

    # Checks that inner loops of B, once aligned onto A, superpose one to one
    # with inner loops of A (shape AND position within the face).
    def _inner_loops_superpose?(face_manipulator_a, face_manipulator_b, t)
      remaining = face_manipulator_a.inner_loop_manipulators.map(&:points)
      inner_loop_manipulators_b = face_manipulator_b.inner_loop_manipulators
      return false unless remaining.length == inner_loop_manipulators_b.length
      inner_loop_manipulators_b.each do |loop_manipulator|
        transformed_points = loop_manipulator.points.map { |point| point.transform(t) }
        index = remaining.index { |points| _loops_points_superpose?(points, transformed_points) }
        return false if index.nil?
        remaining.delete_at(index)
      end
      true
    end

    def _loops_points_superpose?(points_a, points_b)
      return false unless points_a.length == points_b.length
      n = points_a.length
      n.times do |offset|
        return true if points_a.each_with_index.all? { |point, i| point == points_b[(i + offset) % n] }
        return true if points_a.each_with_index.all? { |point, i| point == points_b[(offset - i) % n] }
      end
      false
    end

  end

end
