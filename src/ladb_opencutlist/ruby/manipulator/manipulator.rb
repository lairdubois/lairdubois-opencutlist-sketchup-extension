module Ladb::OpenCutList

  class Manipulator

    attr_reader :transformation,
                :container_path

    def initialize(transformation = IDENTITY, container_path = [])
      raise "transformation must be a Geom::Transformation." unless transformation.is_a?(Geom::Transformation)
      raise "container_path must be an Array." unless container_path.is_a?(Array)
      @container_path = container_path
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
      @flipped
    end

    def skewed?
      @skewed ||= TransformationUtils.skewed?(@transformation)
      @skewed
    end

    def container
      @container_path.last
    end

    # -----

    def ==(other)
      return false unless other.is_a?(Manipulator)
      (@transformation * other.transformation.inverse).identity? && @container_path == other.container_path
    end

  end

end
