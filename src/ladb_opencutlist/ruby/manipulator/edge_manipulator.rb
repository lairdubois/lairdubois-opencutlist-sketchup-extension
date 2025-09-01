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
      @z_min = nil
      @z_max = nil
      @vertex_manipulators = nil
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
      return nil if infinite?
      @middle_point ||= Geom::linear_combination(0.5, start_point, 0.5, end_point)
      @middle_point
    end

    def third_points
      return nil if infinite?
      @third_points ||= [
        Geom::linear_combination(1 / 3.0, start_point, 2 / 3.0, end_point),
        Geom::linear_combination(2 / 3.0, start_point, 1 / 3.0, end_point),
      ]
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

    def z_min
      @z_min ||= points.min { |p1, p2| p1.z <=> p2.z }.z
      @z_min
    end

    def z_max
      @z_max ||= points.max { |p1, p2| p1.z <=> p2.z }.z
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

    def vertex_manipulators
      @vertex_manipulators ||= @edge.vertices.map { |vertex| VertexManipulator.new(vertex, @transformation) }
      @vertex_manipulators
    end

    # -----

    def nearest_vertex_manipulator_to(point)
      vertex_manipulators.min { |vm1, vm2| vm1.point.distance(point) <=> vm2.point.distance(point) }
    end

    # -----

    def to_s
      "EDGE from #{start_point} to #{end_point}"
    end

  end

end
