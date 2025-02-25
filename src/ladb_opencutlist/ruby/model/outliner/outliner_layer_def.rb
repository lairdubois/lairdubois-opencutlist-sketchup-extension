module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative 'outliner_layer'

  class OutlinerLayerDef < DataContainer

    attr_reader :layer, :folder_defs, :used_by_node_defs

    def initialize(layer)
      @layer = layer
      @used_by_node_defs = []
      fill
    end

    def fill
      @folder_defs = @layer.respond_to?(:folder) && @layer.folder ? [ @layer.folder ].flat_map { |folder|
        folder_defs = [ OutlinerLayerFolderDef.new(folder) ]
        folder_defs << OutlinerLayerFolderDef.new(folder_defs.last.layer_folder.folder) while folder_defs.last.layer_folder.folder
        folder_defs
      } : []
    end

    def visible?
      @layer.visible?
    end

    def computed_visible?
      visible? && @folder_defs.select { |folder_def| !folder_def.visible? }.empty?
    end

    # -----

    def add_used_by_node_def(node_def)
      @used_by_node_defs << node_def
    end

    def remove_used_by_node_def(node_def)
      @used_by_node_defs.delete(node_def)
    end

    def each_used_by
      @used_by_node_defs.each { |node_def| yield node_def }
    end

    # -----

    def invalidate
      @hashable = nil
    end

    def get_hashable
      @hashable = OutlinerLayer.new(self) if @hashable.nil?
      @hashable
    end

  end

  class OutlinerLayerFolderDef < DataContainer

    attr_reader :layer_folder

    def initialize(layer_folder)
      @layer_folder = layer_folder
    end

    def visible?
      @layer_folder.visible?
    end

    # -----

    def get_hashable
      @hashable = OutlinerLayerFolder.new(self) if @hashable.nil?
      @hashable
    end

  end

end