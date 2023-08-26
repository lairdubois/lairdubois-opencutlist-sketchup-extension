module Ladb::OpenCutList

  class FaceInfo

    attr_accessor :face, :transformation, :data

    def initialize(face, transformation)
      @face = face
      @transformation = transformation
      @data = {}
    end

  end

end