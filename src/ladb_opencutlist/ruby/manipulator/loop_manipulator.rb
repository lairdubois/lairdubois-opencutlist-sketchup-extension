module Ladb::OpenCutList

  require_relative 'manipulator'

  class LoopManipulator < Manipulator

    attr_reader :loop

    def initialize(loop, transformation = IDENTITY, container_path = [])
      super(transformation, container_path)
      raise "loop must be a Sketchup::Loop." unless loop.is_a?(Sketchup::Loop)
      @loop = loop
    end

    # -----

    def reset_cache
      super
      @points = nil
      @bounds = nil
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

    def bounds
      @bounds ||= Geom::BoundingBox.new.add(points)
      @bounds
    end

    def segments
      @segments ||= points.each_cons(2).to_a.flatten(1)
      @segments
    end

    # -----

    def vertex_manipulators
      @vertex_manipulators ||= @loop.vertices.map { |vertex| VertexManipulator.new(vertex, @transformation, @container_path) }
      @vertex_manipulators
    end

    # -----

    def nearest_vertex_manipulator_to(point, allows_collinear = false)
      manipulators = vertex_manipulators
      if !allows_collinear && manipulators.length >= 3
        manipulators = manipulators.select.with_index { |vm, index|
          vm_prev = manipulators[(index - 1) % manipulators.length]
          vm_next = manipulators[(index + 1) % manipulators.length]
          !vm.point.vector_to(vm_prev.point).parallel?(vm.point.vector_to(vm_next.point))
        }
      end
        manipulators.min { |vm1, vm2| vm1.point.distance(point) <=> vm2.point.distance(point) }
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
