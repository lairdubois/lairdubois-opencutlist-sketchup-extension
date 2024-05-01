module Ladb::OpenCutList

  require_relative 'layer'

  class LayerDef

    attr_reader :layer, :folder_defs

    def initialize(layer)
      @layer = layer
      @folder_defs = layer.respond_to?(:folder) && layer.folder ? [ layer.folder ].flat_map { |folder|
        folder_defs = [ LayerFolderDef.new(folder) ]
        folder_defs << LayerFolderDef.new(folder_defs.last.layer_folder.folder) while folder_defs.last.layer_folder.folder
        folder_defs
      } : []
    end

    # -----

    def create_layer
      Layer.new(self)
    end

  end

  class LayerFolderDef

    attr_reader :layer_folder

    def initialize(layer_folder)
      @layer_folder = layer_folder
    end

    # -----

    def create_layer_folder
      LayerFolder.new(self)
    end

  end

end