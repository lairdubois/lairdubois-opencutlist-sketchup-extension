module Ladb::OpenCutList

  require_relative 'manipulator'

  class VertexManipulator < Manipulator

    attr_reader :vertex

    def initialize(vertex, transformation = IDENTITY, material = nil)
      raise "vertex must be a Sketchup::Vertex." unless vertex.is_a?(Sketchup::Vertex)
      super(transformation, material)
      @vertex = vertex
    end

    # -----

    def reset_cache
      super
      @points = nil
      @edge_manipulators = nil
      @face_manipulators = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(VertexManipulator)
      @vertex == other.vertex && super
    end

    # -----

    def point
      @point ||= @vertex.position.transform(@transformation)
    end

    # -----

    def edge_manipulators
      @edge_manipulators ||= @vertex.edges.map { |edge| EdgeManipulator.new(edge, @transformation, material) }
    end

    def face_manipulators
      @face_manipulators ||= @vertex.faces.map { |face| FaceManipulator.new(face, @transformation, material) }
    end

    # -----

    def to_s
      "VERTEX position #{point}"
    end

  end

end
