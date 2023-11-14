module Ladb::OpenCutList

  require_relative 'transformation_manipulator'
  require_relative '../helper/edge_segments_helper'

  class EdgeManipulator < TransformationManipulator

    include EdgeSegmentsHelper

    attr_reader :edge

    def initialize(edge, transformation = IDENTITY)
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

    def ==(other)
      return false unless other.is_a?(EdgeSegmentsHelper)
      @edge == other.edge && super
    end

    # -----

    def start_point
      points.first
    end

    def end_point
      points.last
    end

    def points
      if @points.nil?
        @points = @edge.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if flipped?
      end
      @points
    end

    def line
      if @line.nil?
        @line = [ start_point, end_point - start_point ]
      end
      @line
    end

    def length
      (end_point - start_point).length
    end

    def segment
      if @segment.nil?
        @segment = _compute_edge_segment(@edge, @transformation)
      end
      @segment
    end

    # -----

    def reversed_in?(face)
      @edge.reversed_in?(face)
    end

    # -----

    def to_s
      "EDGE from #{start_point} to #{end_point}"
    end

  end

end
