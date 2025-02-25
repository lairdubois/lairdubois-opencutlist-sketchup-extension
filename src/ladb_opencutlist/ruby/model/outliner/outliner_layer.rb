module Ladb::OpenCutList

  require_relative '../data_container'
  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class OutlinerLayer < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :name, :visible, :computed_visible, :color, :folders

    def initialize(_def)
      @_def = _def

      @name = _def.layer.name
      @visible = _def.visible?
      @computed_visible = _def.computed_visible?
      @color = ColorUtils.color_to_hex(_def.layer.color)

      @folders = _def.folder_defs.map { |layer_folder_def| layer_folder_def.get_hashable }

    end

  end

  class OutlinerLayerFolder < DataContainer

    include DefHelper
    include HashableHelper

    attr_reader :name, :visible

    def initialize(_def)
      @_def = _def

      @name = _def.layer_folder.name
      @visible = _def.visible?

    end

  end

end