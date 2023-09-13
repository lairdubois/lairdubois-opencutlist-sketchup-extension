module Ladb::OpenCutList

  require_relative 'manipulator'
  require_relative '../utils//transformation_utils'

  class TransformationManipulator < Manipulator

    attr_accessor :transformation

    def initialize(transformation = Geom::Transformation.new)
      @transformation = transformation
      super()
    end

    # -----

    def reset_cache
      super
      @flipped = nil
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

    # -----

    def ==(other)
      return false unless other.is_a?(Manipulator)
      (@transformation * other.transformation.inverse).identity?
    end

  end

end
