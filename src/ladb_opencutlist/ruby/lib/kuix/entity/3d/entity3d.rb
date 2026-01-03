module Ladb::OpenCutList::Kuix

  class Entity3d < Entity

    attr_reader :bounds, :extents
    attr_accessor :transformation

    def initialize(id = nil)
      super(id)

      # Bounds relative to parent
      @bounds = Bounds3d.new

      # Transformation relative to parent
      @transformation = IDENTITY

      # Bounding box in 3D world
      @extents = Geom::BoundingBox.new

    end

    # -- DOM --

    # Append a given entity to self and returns self
    def append(entity)
      throw 'Entity3d.append only supports Entity3d' unless entity.is_a?(Entity3d)
      super
    end

    # Prepend a given entity to self and returns self
    def prepend(entity)
      throw 'Entity3d.prepend only supports Entity3d' unless entity.is_a?(Entity3d)
      super
    end

    # -- LAYOUT --

    def do_layout(transformation)
      @extents.clear
      if @child
        @child.do_layout(transformation * @transformation)
        @extents.add(@child.extents)
      end
      if @next
        @next.do_layout(transformation)
        @extents.add(@next.extents)
      end
      self.invalidated = false
    end

  end

end