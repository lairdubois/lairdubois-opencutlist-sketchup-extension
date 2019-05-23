module Ladb::OpenCutList

  class FaceInfo

    attr_reader :face, :transformation

    @size

    def initialize(face, transformation)
      @face = face
      @transformation = transformation
    end

  end

end