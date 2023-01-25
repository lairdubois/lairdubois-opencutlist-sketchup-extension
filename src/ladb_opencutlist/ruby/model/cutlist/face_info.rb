module Ladb::OpenCutList

  class FaceInfo

    attr_reader :face, :transformation

    def initialize(face, transformation)
      @face = face
      @transformation = transformation
    end

  end

end