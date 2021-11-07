module Ladb::OpenCutList

  require_relative 'layer0_caching_helper'

  module LayerVisibilityHelper

    include Layer0CachingHelper

    def _layer_folder_visible?(folder)
      return true if folder.nil?
      folder.visible? && _layer_folder_visible?(folder.folder)
    end

    def _layer_visible?(layer, from_root = false)
      (layer.visible? || (!from_root && layer.equal?(self.cached_layer0))) &&    # Layer0 hide entities only on root scene
          _layer_folder_visible?(self.cached_layer0.respond_to?(:folder) ? layer.folder : nil)
    end

  end

end