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

    # Returns the face manipulators from face_manipulators whose face is congruent to
    # reference_face_manipulator's face. The reference itself is excluded.
    #
    # @param reference_face_manipulator [FaceManipulator] the face manipulator to match against
    # @param face_manipulators [Array<FaceManipulator>] the candidate face manipulators to filter
    # @param mirror [Boolean] whether to also match mirrored (symmetric) faces
    # @return [Array<FaceManipulator>] the face manipulators congruent to the reference
    def _find_matching_face_manipulators(reference_face_manipulator, face_manipulators, mirror: true)
      reference_signature = reference_face_manipulator.signature(mirror: mirror)
      return [] if reference_signature.nil?
      face_manipulators.select do |face_manipulator|
        next false if face_manipulator == reference_face_manipulator || face_manipulator.face == reference_face_manipulator.face
        face_manipulator.signature(mirror: mirror) == reference_signature &&
          _face_manipulators_congruent?(reference_face_manipulator, face_manipulator, mirror: mirror)
      end
    end

    # Full pairwise test : cheap signature compare, then geometric verification.
    #
    # @param face_manipulator_a [FaceManipulator] the first face manipulator
    # @param face_manipulator_b [FaceManipulator] the second face manipulator
    # @param mirror [Boolean] whether to also match mirrored (symmetric) faces
    # @return [Boolean] true if the two faces are congruent
    def _face_manipulators_match?(face_manipulator_a, face_manipulator_b, mirror: true)
      signature_a = face_manipulator_a.signature(mirror: mirror)
      return false if signature_a.nil?
      signature_a == face_manipulator_b.signature(mirror: mirror) &&
        _face_manipulators_congruent?(face_manipulator_a, face_manipulator_b, mirror: mirror)
    end

    # Tells how two faces match.
    #
    # @param face_manipulator_a [FaceManipulator] the first face manipulator
    # @param face_manipulator_b [FaceManipulator] the second face manipulator
    # @return [Symbol, nil] :direct (superposable as is), :mirror (superposable
    #   flipped over, e.g. the two opposite faces of a panel), :both when the
    #   shape is achiral (a rectangle matches both ways), nil when faces don't match
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
    # face_manipulator_a (both expressed in the same space) : what it takes to
    # place a copy of B's owner exactly where A is.
    #
    # With mirror: false, only a PROPER motion is ever returned - a mirrored
    # superposition is rejected rather than answered with a flipping
    # transformation, which would place a mirrored instance.
    #
    # @param face_manipulator_a [FaceManipulator] the reference face manipulator
    # @param face_manipulator_b [FaceManipulator] the face manipulator to align onto the reference
    # @param mirror [Boolean] whether a mirrored (flipped over) superposition may be returned
    # @return [Geom::Transformation, nil] the alignment transformation, or nil when the two faces are not congruent
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
    # hence the geometric verification pass.
    #
    # @param face_manipulator [FaceManipulator] the face manipulator to compute the signature of
    # @param mirror [Boolean] whether to fold the mirrored variant into the signature
    # @return [Array, nil] the signature, or nil for degenerated faces
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

    # @param face_manipulator_a [FaceManipulator] the first face manipulator
    # @param face_manipulator_b [FaceManipulator] the second face manipulator
    # @param mirror [Boolean] whether a mirrored (flipped over) superposition also counts as congruent
    # @return [Boolean] true if the two faces are geometrically congruent
    def _face_manipulators_congruent?(face_manipulator_a, face_manipulator_b, mirror: true)
      _face_variant_congruent?(face_manipulator_a, face_manipulator_b, false) ||
        mirror && _face_variant_congruent?(face_manipulator_a, face_manipulator_b, true)
    end

    private

    # @param face_manipulator_a [FaceManipulator] the first face manipulator
    # @param face_manipulator_b [FaceManipulator] the second face manipulator
    # @param mirrored [Boolean] whether to test the mirrored (flipped over) variant
    # @return [Boolean] true if that superposition variant exists
    def _face_variant_congruent?(face_manipulator_a, face_manipulator_b, mirrored)
      !_face_variant_alignment_transformation(face_manipulator_a, face_manipulator_b, mirrored).nil?
    end

    # Tests one superposition kind and returns the transformation that achieves
    # it : mirrored = false tries to superpose B onto A as is (normals
    # aligned), mirrored = true tries with B flipped over (reversed traversal,
    # opposite normal).
    #
    # @param face_manipulator_a [FaceManipulator] the reference face manipulator
    # @param face_manipulator_b [FaceManipulator] the face manipulator to align onto the reference
    # @param mirrored [Boolean] whether to try the flipped over variant of B
    # @return [Geom::Transformation, nil] the alignment transformation, or nil when that variant doesn't superpose
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
    #
    # @param points [Array<Geom::Point3d>] the loop's points, in order
    # @param normal [Geom::Vector3d] the normal used to sign the turn angles
    # @return [Array<Array(Float, Float)>] one [edge_length, signed_angle] pair per vertex
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

    # @param points [Array<Geom::Point3d>] the loop's points, in order
    # @param normal [Geom::Vector3d] the normal used to sign the turn angles
    # @return [Array<Array(Integer, Integer)>] the loop sequence, quantized to FACE_MATCHER_LENGTH_STEP / FACE_MATCHER_ANGLE_STEP
    def _loop_quantized_sequence(points, normal)
      _loop_sequence(points, normal).map { |length, angle|
        [ (length / FACE_MATCHER_LENGTH_STEP).round, (angle / FACE_MATCHER_ANGLE_STEP).round ]
      }
    end

    # Smallest rotation of the sequence (and of its mirrored variant if given) :
    # removes the start index and traversal direction dependency.
    #
    # @param sequence [Array] the sequence to canonicalize
    # @param mirror_sequence [Array, nil] the mirrored variant of the sequence, if any
    # @return [Array] the smallest rotation among all candidates
    def _canonical_sequence(sequence, mirror_sequence = nil)
      candidates = (0...sequence.length).map { |k| sequence.rotate(k) }
      candidates.concat((0...mirror_sequence.length).map { |k| mirror_sequence.rotate(k) }) unless mirror_sequence.nil?
      candidates.min
    end

    # @param sequence_a [Array<Array(Integer, Integer)>] the reference quantized sequence
    # @param sequence_b [Array<Array(Integer, Integer)>] the candidate quantized sequence
    # @param offset [Integer] the index offset to apply to sequence_b before comparing
    # @return [Boolean] true if every element of sequence_a matches, within tolerance, the corresponding offset element of sequence_b
    def _sequences_match?(sequence_a, sequence_b, offset)
      sequence_a.each_with_index.all? do |(length, angle), i|
        other_length, other_angle = sequence_b[(i + offset) % sequence_b.length]
        (length - other_length).abs <= FACE_MATCHER_LENGTH_STEP && (angle - other_angle).abs <= FACE_MATCHER_ANGLE_STEP
      end
    end

    # Rigid transformation mapping points_b onto points_a assuming vertex i of A
    # corresponds to vertex i + offset of B, built from a frame at each
    # corresponding vertex (origin, outgoing edge as X axis, normal as Z axis).
    #
    # @param points_a [Array<Geom::Point3d>] the reference loop's points
    # @param normal_a [Geom::Vector3d] the reference loop's normal
    # @param points_b [Array<Geom::Point3d>] the loop's points to map onto the reference
    # @param normal_b [Geom::Vector3d] the normal of the loop to map onto the reference
    # @param offset [Integer] the vertex correspondence offset between A and B
    # @return [Geom::Transformation] the transformation mapping points_b onto points_a
    def _alignment_transformation(points_a, normal_a, points_b, normal_b, offset)
      _vertex_frame(points_a, 0, normal_a) * _vertex_frame(points_b, offset, normal_b).inverse
    end

    # @param points [Array<Geom::Point3d>] the loop's points
    # @param index [Integer] the index of the vertex to build the frame at
    # @param normal [Geom::Vector3d] the normal used as the frame's Z axis
    # @return [Geom::Transformation] the frame at that vertex (origin, outgoing edge as X axis, normal as Z axis)
    def _vertex_frame(points, index, normal)
      origin = points[index]
      x_axis = origin.vector_to(points[(index + 1) % points.length]).normalize
      Geom::Transformation.axes(origin, x_axis, normal * x_axis, normal)
    end

    # @param points_a [Array<Geom::Point3d>] the reference loop's points
    # @param points_b [Array<Geom::Point3d>] the loop's points to test, once transformed
    # @param offset [Integer] the vertex correspondence offset between A and B
    # @param t [Geom::Transformation] the transformation to apply to points_b
    # @return [Boolean] true if every transformed point of B superposes exactly on the corresponding point of A
    def _points_superpose?(points_a, points_b, offset, t)
      points_a.each_with_index.all? { |point, i| point == points_b[(i + offset) % points_b.length].transform(t) }
    end

    # Checks that inner loops of B, once aligned onto A, superpose one to one
    # with inner loops of A (shape AND position within the face).
    #
    # @param face_manipulator_a [FaceManipulator] the reference face manipulator
    # @param face_manipulator_b [FaceManipulator] the face manipulator whose inner loops are aligned onto the reference
    # @param t [Geom::Transformation] the alignment transformation to apply to B's inner loops
    # @return [Boolean] true if B's inner loops superpose one to one with A's inner loops
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

    # @param points_a [Array<Geom::Point3d>] the reference loop's points
    # @param points_b [Array<Geom::Point3d>] the candidate loop's points
    # @return [Boolean] true if points_b superposes points_a for some rotation offset, in either traversal direction
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
