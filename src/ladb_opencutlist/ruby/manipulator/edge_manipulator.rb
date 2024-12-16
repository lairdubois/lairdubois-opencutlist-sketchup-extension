module Ladb::OpenCutList

  require_relative 'transformation_manipulator'
  require_relative 'line_manipulator'

  class EdgeManipulator < LineManipulator

    attr_reader :edge

    def initialize(edge, transformation = IDENTITY)
      super(edge.line, transformation)
      raise "edge must be a Sketchup::Edge." unless edge.is_a?(Sketchup::Edge)
      @edge = edge
    end

    # -----

    def reset_cache
      super
      @middle_point = nil
      @third_points = nil
      @points = nil
      @z_max = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(EdgeManipulator)
      @edge == other.edge && super
    end

    # -----

    def infinite?
      false
    end

    def start_point
      points.first
    end

    def end_point
      points.last
    end

    def middle_point
      if @middle_point.nil?
        v = end_point - start_point
        @middle_point = start_point.offset(v, v.length / 2.0)
      end
      @middle_point
    end

    def third_points
      if @third_points.nil?
        v = end_point - start_point
        @third_points = [ start_point.offset(v, v.length / 3.0), start_point.offset(v, v.length / 3.0 * 2) ]
      end
      @third_points
    end

    def points
      if @points.nil?
        @points = @edge.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if flipped?
      end
      @points
    end

    alias_method :segment, :points

    def z_max
      @z_max = points.max { |p1, p2| p1.z <=> p2.z }.z if @z_max.nil?
      @z_max
    end

    def length
      (end_point - start_point).length
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
