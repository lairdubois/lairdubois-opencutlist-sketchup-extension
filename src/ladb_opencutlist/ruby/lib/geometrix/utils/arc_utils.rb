module Ladb::OpenCutList::Geometrix

  module ArcUtils

    # The number of segments to draw an arc of the given radius with : its
    # segments no longer than max_segment_length - within the given bounds,
    # even to keep the arc symmetrical.
    #
    # @param [Float] radius
    # @param [Integer] min_num_segments
    # @param [Integer] max_num_segments
    # @param [Float] max_segment_length in inches - 2 mm by default
    # @param [Float] arc_angle in radians
    #
    # @return [Integer]
    #
    def self.num_segments_by_radius(radius,
                                    min_num_segments: 8,
                                    max_num_segments: 24,
                                    max_segment_length: 2 / 25.4,
                                    arc_angle: TWO_PI
    )
      radius = radius.to_f
      max_segment_length = max_segment_length.to_f
      if radius <= 0 || max_segment_length >= radius * 2
        segments = min_num_segments   # A chord can't be that long : as few as allowed
      else
        segments = (arc_angle / (2 * Math.asin(max_segment_length / (radius * 2)))).ceil
      end

      # Compat Ruby 2.2 (no Numeric#clamp)
      segments = [ [ segments, min_num_segments ].max, max_num_segments ].min

      segments += 1 if segments.odd?
      segments
    end

  end

end
