module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative '../utils/transformation_utils'
  require_relative '../helper/edge_segments_helper'

  class EdgeManipulator < Manipulator

    include EdgeSegmentsHelper

    attr_reader :edge

    def initialize(edge, transformation = Geom::Transformation.new)
      super(transformation)
      @edge = edge
    end

    # -----

    def reset_cache
      super
      @points = nil
      @line = nil
      @segment = nil
    end

    # -----

    def points(reset_cache = false)
      if @points.nil? || !reset_cache
        @points = @edge.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if TransformationUtils.flipped?(@transformation)
      end
      @points
    end

    def line(reset_cache = false)
      if @line.nil? || !reset_cache
        @line = [ points(reset_cache).first, points.last - points.first ]
      end
      @line
    end

    def segment(reset_cache = false)
      if @segment.nil? || !reset_cache
        @segment = _compute_edge_segment(@edge, @transformation)
      end
      @segment
    end

  end

end
