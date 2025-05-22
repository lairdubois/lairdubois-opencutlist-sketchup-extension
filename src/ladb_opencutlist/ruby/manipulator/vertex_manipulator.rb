module Ladb::OpenCutList

  require_relative 'transformation_manipulator'

  class VertexManipulator < TransformationManipulator

    attr_reader :vertex

    def initialize(vertex, transformation = IDENTITY)
      super(transformation)
      raise "vertex must be a Sketchup::Vertex." unless vertex.is_a?(Sketchup::Vertex)
      @vertex = vertex
    end

    # -----

    def reset_cache
      super
      @points = nil
      @segment = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(VertexManipulator)
      @vertex == other.vertex && super
    end

    # -----

    def point
      @point = @vertex.position.transform(@transformation) if @point.nil?
      @point
    end

    # -----

    def edge_manipulators
      @edge_manipulators = @vertex.edges.map { |edge| EdgeManipulator.new(edge, @transformation) } if @edge_manipulators.nil?
      @edge_manipulators
    end

    # -----

    def to_s
      "VERTEX position #{point}"
    end

  end

end
