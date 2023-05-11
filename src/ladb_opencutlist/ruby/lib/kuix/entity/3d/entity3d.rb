module Ladb::OpenCutList::Kuix

  class Entity3d < Entity

    attr_reader :bounds
    attr_accessor :transformation

    def initialize(id = nil)
      super(id)

      @bounds = Bounds3d.new

      @transformation = Geom::Transformation.new

    end

    # -- DOM --

    # Append given entity to self and returns self
    def append(entity)
      throw 'Entity3d.append only supports Entity3d' unless entity.is_a?(Entity3d)
      super
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @child.do_layout(transformation * @transformation) if @child
      @next.do_layout(transformation) if @next
      self.invalidated = false
    end

  end

end