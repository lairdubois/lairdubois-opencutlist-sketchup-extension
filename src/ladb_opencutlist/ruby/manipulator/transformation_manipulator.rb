module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative '../utils//transformation_utils'

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
      if @flipped.nil?
        @flipped = TransformationUtils.flipped?(@transformation)
      end
      @flipped
    end

    def skewed?
      if @skewed.nil?
        @skewed = TransformationUtils.skewed?(@transformation)
      end
      @skewed
    end

    # -----

    def ==(other)
      return false unless other.is_a?(Manipulator)
      (@transformation * other.transformation.inverse).identity?
    end

  end

end
