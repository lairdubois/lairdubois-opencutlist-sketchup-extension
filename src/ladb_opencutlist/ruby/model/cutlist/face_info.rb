module Ladb::OpenCutList

  require_relative '../data_container'

  class FaceInfo < DataContainer

    attr_accessor :face, :transformation, :data

    def initialize(face, transformation)
      @face = face
      @transformation = transformation
      @data = {}
    end

  end

end