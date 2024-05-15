module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class OutlinerLayer

    include DefHelper
    include HashableHelper

    attr_reader :name, :layer_visible, :visible, :folder, :color

    def initialize(_def)
      @_def = _def

      @name = _def.layer.name
      @layer_visible = _def.layer_visible?
      @visible = _def.visible?
      @color = ColorUtils.color_to_hex(_def.layer.color)

      @folders = _def.folder_defs.map { |layer_folder_def| layer_folder_def.create_hashable }

    end

  end

  class OutlinerLayerFolder

    include DefHelper
    include HashableHelper

    attr_reader :name, :visible

    def initialize(_def)
      @_def = _def

      @name = _def.layer_folder.name
      @visible = _def.layer_folder_visible?

    end

  end

end