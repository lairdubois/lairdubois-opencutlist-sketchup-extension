module Ladb::OpenCutList

  class Manipulator

    attr_reader :transformation,
                :material,
                :layer

    def initialize(transformation = IDENTITY, material = nil, layer = nil)
      raise "transformation must be a Geom::Transformation." unless transformation.is_a?(Geom::Transformation)
      @transformation = transformation
      raise "material must be a Sketchup::Material." unless material.nil? || material.is_a?(Sketchup::Material)
      @material = material
      raise "layer must be a Sketchup::Layer." unless layer.nil? || layer.is_a?(Sketchup::Layer)
      @layer = layer
    end

    # -----

    def reset_cache
      @flipped = nil
      @skewed = nil
    end

    # -----

    def transformation=(transformation)
      @transformation = transformation
      reset_cache
    end

    def flipped?
      @flipped ||= TransformationUtils.flipped?(@transformation)
    end

    def skewed?
      @skewed ||= TransformationUtils.skewed?(@transformation)
    end

    # -----

    def ==(other)
      return false unless other.is_a?(Manipulator)
      (@transformation * other.transformation.inverse).identity?
    end

  end

end
