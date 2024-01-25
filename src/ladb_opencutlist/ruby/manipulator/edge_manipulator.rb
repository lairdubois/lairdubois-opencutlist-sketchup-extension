module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class EdgeManipulator < TransformationManipulator

    attr_reader :edge

    def initialize(edge, transformation = IDENTITY)
      super(transformation)
      @edge = edge
    end

    # -----

    def reset_cache
      super
      @points = nil
      @z_max = nil
      @line = nil
      @segment = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(EdgeManipulator)
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

    def z_max
      if @z_max.nil?
        @z_max = points.max { |p1, p2| p1.z <=> p2.z }.z
      end
      @z_max
    end

    def line
      if @line.nil?
        @line = [ start_point, end_point - start_point ]
      end
      @line
    end

    def line_point
      line[0]
    end

    def line_vector
      line[1]
    end

    def length
      (end_point - start_point).length
    end

    def segment
      if @segment.nil?
        @segment = points
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
