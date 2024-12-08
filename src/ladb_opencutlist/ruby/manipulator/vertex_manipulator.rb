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
      @z_max = nil
      @segment = nil
    end

    # -----

    def ==(other)
      return false unless other.is_a?(VertexManipulator)
      @vertex == other.vertex && super
    end

    # -----

    def point
      if @point.nil?
        @point = @vertex.position.transform(@transformation)
      end
      @point
    end

    # -----

    def to_s
      "VERTEX position #{point}"
    end

  end

end
