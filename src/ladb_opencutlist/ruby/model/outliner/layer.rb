module Ladb::OpenCutList

  require_relative '../../helper/def_helper'
  require_relative '../../helper/hashable_helper'
  require_relative '../../utils/color_utils'

  class AbstractLayer

    include DefHelper
    include HashableHelper

    attr_reader :name, :visible, :folder

    def initialize(_def)
      @_def = _def

      @name = _def.layer.name
      @visible = _def.layer.visible?

      @folder = _def.folder.create_layer unless _def.folder.nil?

    end

  end

  class Layer < AbstractLayer

    attr_reader :color

    def initialize(_def)
      super

      @color = ColorUtils.color_to_hex(_def.layer.color)

    end

  end

  class LayerFolder < AbstractLayer

    def initialize(_def)
      super
    end

  end

end