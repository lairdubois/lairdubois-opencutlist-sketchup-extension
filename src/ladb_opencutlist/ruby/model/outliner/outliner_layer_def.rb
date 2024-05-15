module Ladb::OpenCutList

  require_relative 'outliner_layer'

  class OutlinerLayerDef

    attr_reader :layer, :folder_defs

    def initialize(layer)
      @layer = layer
      @folder_defs = layer.respond_to?(:folder) && layer.folder ? [ layer.folder ].flat_map { |folder|
        folder_defs = [ OutlinerLayerFolderDef.new(folder) ]
        folder_defs << OutlinerLayerFolderDef.new(folder_defs.last.layer_folder.folder) while folder_defs.last.layer_folder.folder
        folder_defs
      } : []
    end

    # -----

    def create_hashable
      OutlinerLayer.new(self)
    end

  end

  class OutlinerLayerFolderDef

    attr_reader :layer_folder

    def initialize(layer_folder)
      @layer_folder = layer_folder
    end

    # -----

    def create_hashable
      @hashable = OutlinerLayerFolder.new(self) if @hashable.nil?
      @hashable
    end

  end

end