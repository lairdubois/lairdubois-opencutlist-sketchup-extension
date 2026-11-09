module Ladb::OpenCutList

  require_relative '../lib/geometrix/geometrix'

  # Detects congruent solids from their point clouds : a cheap fingerprint
  # invariant by rotation and translation as a pre-filter, then an exact one
  # to one superposition test under a candidate transformation - typically one
  # FaceMatcherHelper#_face_manipulators_alignment_transformations answered.
  module SolidMatcherHelper

    # Fingerprint invariant by rotation AND translation : the sorted distances
    # from the point cloud's centroid. Cheap pre-filter that spares the
    # alignment search on all but the genuinely congruent candidates.
    #
    # Kept as raw lengths and compared with a tolerance rather than quantized
    # into a hashable key : two congruent solids are computed independently,
    # each carrying its own floating point noise - and any quantization
    # boundary they happened to straddle would silently cost the match.
    def _points_signature(points)
      centroid = Geometrix::PointFinder.find_centroid(points)
      points.map { |point| centroid.distance(point).to_f }.sort
    end

    def _points_signatures_match?(signature, other_signature)
      return false unless signature.length == other_signature.length
      signature.each_with_index.all? { |distance, index| (distance - other_signature[index]).abs <= SolidMeshDef::TOLERANCE }
    end

    # True when +other_points+, once transformed, is exactly +points+ - each
    # point matched one to one, within SketchUp's tolerance.
    def _points_sets_superpose?(points, other_points, t)
      return false unless points.length == other_points.length
      remaining = points.dup
      other_points.all? { |point|
        transformed_point = point.transform(t)
        index = remaining.index { |other_point| other_point == transformed_point }
        next false if index.nil?
        remaining.delete_at(index)
        true
      }
    end

    # The trace of the linear part : the higher, the closer to the identity
    # (3 for a pure translation).
    def _transformation_trace(transformation)
      a = transformation.to_a
      w = a[15]
      w = 1.0 if w.nil? || w == 0
      (a[0] + a[5] + a[10]) / w
    end

  end

end
