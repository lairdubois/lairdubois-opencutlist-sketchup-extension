module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class LoopManipulator < TransformationManipulator

    attr_reader :loop

    def initialize(loop, transformation = IDENTITY)
      super(transformation)
      raise "loop must be a Sketchup::Loop." unless loop.is_a?(Sketchup::Loop)
      @loop = loop
    end

    # -----

    def reset_cache
      super
      @points = nil
      @segments = nil
      @vertex_manipulators = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(LoopManipulator)
      @loop == other.loop && super
    end

    # -----

    def points
      if @points.nil?
        @points = @loop.vertices.map { |vertex| vertex.position.transform(@transformation) }
        @points.reverse! if flipped?
      end
      @points
    end

    def segments
      @segments = points.each_cons(2).to_a.flatten(1) if @segments.nil?
      @segments
    end

    # -----

    def vertex_manipulators
      @vertex_manipulators = @loop.vertices.map { |vertex| VertexManipulator.new(vertex, @transformation) } if @vertex_manipulators.nil?
      @vertex_manipulators
    end

    # -----

    def nearest_vertex_manipulator_to(point)
      vertex_manipulators.min { |vm1, vm2| vm1.point.distance(point) <=> vm2.point.distance(point) }
    end

    # -----

    def to_s
      [
        "LOOP",
        "- #{@loop.count_edges} edges",
      ].join("\n")
    end

  end

end
