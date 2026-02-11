module Ladb::OpenCutList

  class Manipulator

    attr_reader :transformation

    def initialize(transformation = IDENTITY)
      raise "transformation must be a Geom::Transformation." unless transformation.is_a?(Geom::Transformation)
      @transformation = transformation
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
