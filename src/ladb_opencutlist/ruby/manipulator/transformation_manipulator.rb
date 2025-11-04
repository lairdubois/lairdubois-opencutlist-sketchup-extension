module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative '../utils/transformation_utils'

  class TransformationManipulator < Manipulator

    attr_accessor :transformation

    def initialize(transformation = IDENTITY)
      @transformation = transformation
      super()
    end

    # -----

    def reset_cache
      super
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

    # -----

    def ==(other)
      return false unless other.is_a?(TransformationManipulator)
      (@transformation * other.transformation.inverse).identity?
    end

  end

end
