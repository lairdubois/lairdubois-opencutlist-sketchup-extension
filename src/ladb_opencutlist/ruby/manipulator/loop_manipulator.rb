module Ladb::OpenCutList

  require_relative 'manipulator'

  class LoopManipulator < Manipulator

    attr_reader :loop

    def initialize(loop, transformation = Geom::Transformation.new)
      super(transformation)
      @loop = loop
    end

    # -----

    def reset_cache
      super
    end

    # -----


  end

end
