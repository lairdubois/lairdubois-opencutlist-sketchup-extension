module Ladb::OpenCutList

  require 'digest'

  require_relative 'layer'

  class AbstractLayerDef

    attr_accessor :folder
    attr_reader :layer

    def initialize(layer)
      @layer = layer

      @folder = nil

    end

    # -----

    def create_layer
      raise 'Abstract method : Override it'
    end

  end


  class LayerDef < AbstractLayerDef

    def initialize(layer)
      super
    end

    # -----

    def create_layer
      Layer.new(self)
    end

  end

  class LayerFolderDef < AbstractLayerDef

    def initialize(layer)
      super
    end

    # -----

    def create_layer
      LayerFolder.new(self)
    end

  end

end