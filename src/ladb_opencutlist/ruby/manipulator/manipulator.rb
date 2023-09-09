module Ladb::OpenCutList

  class Manipulator

    attr_accessor :transformation, :data

    def initialize(transformation = Geom::Transformation.new)
      @transformation = transformation
      @data = {}
    end

    # -----

    def transformation=(transformation)
      @transformation = transformation
      reset_cache
    end

    def reset_cache
      # TODO implement it in sub classes
    end

  end

end
