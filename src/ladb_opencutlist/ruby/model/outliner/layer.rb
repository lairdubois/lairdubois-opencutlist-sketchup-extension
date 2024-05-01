module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class Layer

    include DefHelper
    include HashableHelper

    attr_reader :name, :visible, :folder, :color

    def initialize(_def)
      @_def = _def

      @name = _def.layer.name
      @visible = _def.layer.visible?
      @color = ColorUtils.color_to_hex(_def.layer.color)

      @folders = _def.folder_defs.map { |layer_folder_def| layer_folder_def.create_layer_folder }

    end

  end

  class LayerFolder

    include DefHelper
    include HashableHelper

    attr_reader :name, :visible

    def initialize(_def)
      @_def = _def

      @name = _def.layer_folder.name
      @visible = _def.layer_folder.visible?

    end

  end

end